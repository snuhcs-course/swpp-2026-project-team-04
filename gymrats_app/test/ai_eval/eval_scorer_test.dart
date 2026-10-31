import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/rep_event.dart';

import 'eval_plan.dart';
import 'eval_scorer.dart';

const _knees = RejectReason.kneesDown;
const _lockout = RejectReason.incompleteExtension;
const _arms = RejectReason.armsStraight;

EvalCase _case(
  EvalSet set,
  List<RejectReason?> judged, {
  String person = 'JP',
  List<RejectReason?>? labelled,
}) => EvalCase(
  id: '${person}_${set.number}',
  person: person,
  set: set,
  labelled: labelled ?? set.expectedPerRep(10),
  judged: judged,
);

void main() {
  group('EvalSet.expectedPerRep', () {
    test('a normal set expects every rep counted', () {
      expect(EvalSet.normalA.expectedPerRep(10), List.filled(10, null));
    });

    test('a cheat set expects every rep rejected with its reason', () {
      expect(EvalSet.kneePushUp.expectedPerRep(3), [_knees, _knees, _knees]);
      expect(EvalSet.kneelingStraightArms.expectedPerRep(2), [_arms, _arms]);
    });

    test('set 4 expects reps - 1 lockout rejections, then one counted', () {
      expect(EvalSet.noLockout.expectedPerRep(10), [
        ...List.filled(9, _lockout),
        null,
      ]);
    });

    test('sets keep the positions of the recording standard', () {
      expect(
        [for (final s in EvalSet.values) s.position.code].join(),
        'AABBCCDD',
      );
      expect(EvalSet.byNumber(8), EvalSet.kneelingStraightArms);
    });
  });

  group('align', () {
    test('a rep the judge never closed does not shift later reps', () {
      final pairs = align([null, _knees, null], [null, null]);
      expect(pairs.length, 3);
      expect(pairs[1].$1?.reason, _knees);
      expect(pairs[1].$2, isNull);
    });

    test('an extra judged rep has no labelled partner', () {
      final pairs = align([null], [null, _knees]);
      expect(pairs.where((p) => p.$1 == null).single.$2?.reason, _knees);
    });
  });

  group('EvalTally', () {
    test('a perfect run passes every metric', () {
      final t = EvalTally()
        ..add(_case(EvalSet.normalA, List.filled(10, null)))
        ..add(_case(EvalSet.kneelingBow, List.filled(10, _knees)))
        ..add(_case(EvalSet.noLockout, [...List.filled(9, _lockout), null]));
      expect(t.normalReps, 11, reason: 'set 4 adds its last rep to M1');
      expect(t.incorrectReps, 19);
      expect((t.m1, t.m2, t.m3), (1.0, 1.0, 1.0));
      expect(t.passes, isTrue);
    });

    test('a counted cheat rep fails M2 and M3', () {
      final t = EvalTally()
        ..add(_case(EvalSet.kneePushUp, [...List.filled(9, _knees), null]));
      expect(t.m2, 0.9);
      expect(t.m3, 0.9);
    });

    test('a wrong reason still counts for M2 but not M3', () {
      final t = EvalTally()
        ..add(
          _case(EvalSet.kneelingStraightArms, [
            ...List.filled(5, _arms),
            ...List.filled(5, _knees),
          ]),
        );
      expect(t.m2, 1.0);
      expect(t.m3, 0.5);
      expect(t.passes, isFalse);
    });

    test('an unclosed cheat rep is not counted but has no reason', () {
      final t = EvalTally()
        ..add(_case(EvalSet.noLockout, [...List.filled(8, _lockout), null]));
      expect(t.incorrectReps, 9);
      expect(t.incorrectNotCounted, 9);
      expect(t.incorrectRightReason, 8);
      expect(t.normalCounted, 1);
    });

    test('a missed good rep lowers M1', () {
      final t = EvalTally()
        ..add(_case(EvalSet.normalD, [...List.filled(8, null), _lockout]));
      expect(t.m1, 0.8);
      expect(t.m2, isNull);
      expect(t.passes, isFalse);
    });

    test('extra judged reps are reported apart from M1-M3', () {
      final t = EvalTally()
        ..add(
          _case(EvalSet.normalA, [null, null, null], labelled: [null, null]),
        );
      expect(t.m1, 1.0);
      expect(t.extraCounted, 1);
    });

    test('the record sheet label wins over the plan', () {
      // A knee touched in rep 2 of a normal set: the label says so.
      final t = EvalTally()
        ..add(
          _case(
            EvalSet.normalA,
            [null, _knees, null],
            labelled: [null, _knees, null],
          ),
        );
      expect((t.m1, t.m2, t.m3), (1.0, 1.0, 1.0));
    });
  });

  group('EvalReport', () {
    test('splits the metrics by position and person', () {
      final report = EvalReport([
        _case(EvalSet.normalA, List.filled(10, null), person: 'HS'),
        _case(EvalSet.normalD, List.filled(10, _knees), person: 'JP'),
      ]);
      expect(report.caseCount, 2);
      expect(report.byPosition[PhonePosition.a]!.m1, 1.0);
      expect(report.byPosition[PhonePosition.d]!.m1, 0.0);
      expect(report.byPerson['JP']!.m1, 0.0);
      expect(report.overall.m1, 0.5);
    });

    test('prints the metric table with thresholds and results', () {
      final md = EvalReport([
        _case(EvalSet.normalA, List.filled(10, null)),
        _case(EvalSet.kneelingBow, List.filled(10, _knees)),
      ]).toMarkdown();
      expect(
        md,
        contains('| M1 Count accuracy | 100.0% (10/10) | ≥ 90.0% | pass |'),
      );
      expect(
        md,
        contains('| M3 Right reason | 100.0% (10/10) | ≥ 80.0% | pass |'),
      );
      expect(md, contains('| Position A |'));
      expect(md, contains('| JP |'));
    });

    test('a metric with no reps reads as no data', () {
      final md = EvalReport([_case(EvalSet.normalA, List.filled(10, null))])
          .toMarkdown();
      expect(
        md,
        contains('| M2 Rejection rate | – (0/0) | ≥ 90.0% | no data |'),
      );
    });
  });
}
