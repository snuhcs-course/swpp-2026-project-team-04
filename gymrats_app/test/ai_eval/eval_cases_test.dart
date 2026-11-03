import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/rep_judge_demo.dart';
import 'package:gymrats_app/models/rep_event.dart';

import 'eval_cases.dart';
import 'eval_plan.dart';
import 'eval_scorer.dart';

void main() {
  group('evalSetFor', () {
    test('reads the set from the kind and the position letter', () {
      expect(
        evalSetFor(CaseKind.normal, 'A, about 50cm, 67°'),
        EvalSet.normalA,
      );
      expect(evalSetFor(CaseKind.knees, 'A, 50cm'), EvalSet.kneelingBow);
      expect(evalSetFor(CaseKind.halfRepHeadNod, 'B'), EvalSet.halfRepHeadNod);
      expect(
        evalSetFor(CaseKind.unlabelled, 'B-target-50cm-75to80deg'),
        EvalSet.noLockout,
      );
      expect(evalSetFor(CaseKind.knees, 'C, 약 100cm, 대략'), EvalSet.kneePushUp);
      expect(
        evalSetFor(CaseKind.bellyDown, ' c, about 100cm'),
        EvalSet.bellyDown,
      );
      expect(
        evalSetFor(CaseKind.normal, 'D, not measured, 79°'),
        EvalSet.normalD,
      );
      expect(
        evalSetFor(CaseKind.armsStraight, 'D'),
        EvalSet.kneelingStraightArms,
      );
    });

    test('a kind at a position the standard does not use is an error', () {
      expect(
        () => evalSetFor(CaseKind.normal, 'B'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => evalSetFor(CaseKind.phoneMoved, 'A'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => evalSetFor(CaseKind.normal, ''),
        throwsA(isA<FormatException>()),
      );
      // A word that starts with a position letter is not a position.
      expect(
        () => evalSetFor(CaseKind.normal, 'about 50cm'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => evalSetFor(CaseKind.bellyDown, 'Close, 100cm'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('loadEvalCases', () {
    test('a missing folder holds no cases', () {
      expect(loadEvalCases('test/ai_eval/no_such_folder'), isEmpty);
    });

    test('the frozen set has four people with the eight sets each', () {
      final cases = loadEvalCases();
      expect(cases.length, 32);
      final byPerson = <String, List<LoadedEvalCase>>{};
      for (final c in cases) {
        byPerson.putIfAbsent(c.person, () => []).add(c);
      }
      expect(byPerson.keys.toSet(), {'HS', 'JP', 'SWH', 'HSW'});
      for (final entry in byPerson.entries) {
        final sets = entry.value.map((c) => c.set).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
        expect(sets, EvalSet.values, reason: '${entry.key} sets');
      }
    });

    test('every case is labelled rep by rep, as many reps as it holds', () {
      for (final c in loadEvalCases()) {
        final label = c.recording.label;
        expect(label.perRep, isNotNull, reason: '${c.id} has no perRep');
        expect(
          label.perRep!.length,
          label.reps,
          reason: '${c.id} perRep length',
        );
        expect(c.labelled, label.perRep);
        final expected = label.expected;
        expect(expected, isNotNull, reason: '${c.id} has no expected');
        expect(
          c.labelled.where((r) => r == null).length,
          expected!.valid,
          reason: '${c.id} valid reps in perRep vs expected',
        );
      }
    });

    test('set 4 is labelled with its last rep counted', () {
      for (final c in loadEvalCases().where(
        (c) => c.set == EvalSet.noLockout,
      )) {
        expect(c.labelled.last, isNull, reason: c.id);
        expect(
          c.labelled.take(c.labelled.length - 1),
          everyElement(RejectReason.incompleteExtension),
          reason: c.id,
        );
      }
    });
  });

  group('setTable', () {
    test('has one row per set that has a case', () {
      final loaded = loadEvalCases().where((c) => c.person == 'HS');
      final table = setTable([for (final c in loaded) scoreCase(c)]);
      final lines = table.split('\n');
      expect(lines.length, 2 + EvalSet.values.length);
      expect(lines[2], startsWith('| 1 | Normal push-ups | A |'));
      expect(lines.last, startsWith('| 8 |'));
    });
  });

  group('scoreCase', () {
    test('keeps the label and replays the judge over the recording', () {
      final loaded = loadEvalCases().first;
      final scored = scoreCase(loaded);
      expect(scored.id, loaded.id);
      expect(scored.person, loaded.person);
      expect(scored.set, loaded.set);
      expect(scored.labelled, loaded.labelled);
      expect(scored.judged, isNotEmpty);
    });

    test('the case table has one row per case with its errors', () {
      final loaded = loadEvalCases().take(2).toList();
      final table = caseTable([for (final c in loaded) (c, scoreCase(c))]);
      final lines = table.split('\n');
      expect(lines.length, 2 + loaded.length);
      expect(lines[2], contains('| ${loaded.first.id} |'));
      expect(lines[0], contains('| Live |'));
    });

    test('the error column names what differs from the label', () {
      final loaded = loadEvalCases().first;
      final scored = scoreCase(loaded);
      final ok = EvalCase(
        id: scored.id,
        person: scored.person,
        set: scored.set,
        labelled: scored.labelled,
        judged: scored.labelled,
      );
      expect(caseTable([(loaded, ok)]).split('\n')[2], endsWith('| ok |'));
      final counted = EvalCase(
        id: scored.id,
        person: scored.person,
        set: scored.set,
        labelled: [null, RejectReason.kneesDown],
        judged: [null, null],
      );
      expect(
        caseTable([(loaded, counted)]).split('\n')[2],
        endsWith('| false count |'),
      );
      final missed = EvalCase(
        id: scored.id,
        person: scored.person,
        set: scored.set,
        labelled: [null, null],
        judged: [RejectReason.kneesDown, null],
      );
      expect(
        caseTable([(loaded, missed)]).split('\n')[2],
        endsWith('| missed rep |'),
      );
      final reason = EvalCase(
        id: scored.id,
        person: scored.person,
        set: scored.set,
        labelled: [RejectReason.kneesDown, null],
        judged: [RejectReason.bellyDown, null],
      );
      expect(
        caseTable([(loaded, reason)]).split('\n')[2],
        endsWith('| wrong reason |'),
      );
    });
  });
}
