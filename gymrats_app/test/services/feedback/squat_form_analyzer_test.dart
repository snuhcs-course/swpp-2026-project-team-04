import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/services/feedback/form_analyzer.dart';
import 'package:gymrats_app/services/feedback/form_summary.dart';

import '../../support/form_report_fixtures.dart';

FormReport _withDepths(
  List<double> depths, {
  ExerciseType exercise = ExerciseType.squat,
}) => FormReport(
  endedAt: DateTime(2026, 11, 14),
  opponentName: 'RepBot',
  exercise: exercise,
  roundLength: const Duration(seconds: 30),
  reps: [
    for (var i = 0; i < depths.length; i++)
      RepRecord(
        index: i + 1,
        valid: true,
        at: Duration(seconds: i * 2),
        maxDepth: depths[i],
      ),
  ],
  samples: const [],
);

List<FormSample> _arms(double left, double right, {double depth = 1.2}) => [
  for (var i = 0; i < 12; i++)
    FormSample(
      at: Duration(milliseconds: i * 100),
      depth: depth,
      leftElbow: left,
      rightElbow: right,
    ),
];

FormReport _pushUpArms(List<FormSample> samples) => FormReport(
  endedAt: DateTime(2026, 11, 14),
  opponentName: 'RepBot',
  roundLength: const Duration(seconds: 30),
  reps: const [],
  samples: samples,
);

void main() {
  const analyzer = FormAnalyzer();

  group('UAT-4 squat run: 4 full and 2 shallow squats', () {
    final findings = analyzer.analyze(squatReport());
    final issues = [
      for (final f in findings)
        if (f.kind == FindingKind.issue) f,
    ];

    test('the shallow squats are the one issue, with a tip', () {
      final shallow = issues.single;
      expect(shallow.code, 'reject.shallowSquat');
      expect(shallow.count, 2);
      expect(shallow.title, '얕은 스쿼트 2회');
      expect(shallow.detail, contains('2회가 카운트되지 않았어요'));
      expect(shallow.fix, contains('허벅지'));
      expect(shallow.highlight, containsAll(['leftKnee', 'rightKnee']));
      expect(shallow.demo, isNull);
    });

    test('push-up rules on arms, hands and head stay quiet for a squat', () {
      final titles = [for (final f in findings) f.title];
      for (final pushUpOnly in [
        '좌우 불균형',
        '팔꿈치 벌어짐',
        '손 간격',
        '고개가 먼저 내려감',
        '팔꿈치 각도',
        '양팔 균형',
      ]) {
        expect(titles, isNot(contains(pushUpOnly)));
      }
    });

    test('the list-row summary carries the squat issue code', () {
      final summary = summarizeForm(squatReport());
      expect(summary.validReps, 4);
      expect(summary.invalidReps, 2);
      expect(summary.issues, {'reject.shallowSquat': 2});
      expect(summary.topIssue, '얕은 스쿼트 2회');
    });
  });

  test('not standing back up is its own squat issue with a tip', () {
    final findings = analyzer.analyze(squatReport(shallow: 0, standUp: 3));
    final standUp = findings.single;
    expect(standUp.kind, FindingKind.issue);
    expect(standUp.code, 'reject.standUpFully');
    expect(standUp.title, '덜 일어남 3회');
    expect(standUp.fix, contains('끝까지 펴고'));
  });

  test('a rejected squat shows its deepest saved figure', () {
    final base = squatReport(full: 0, shallow: 1);
    final report = FormReport(
      endedAt: base.endedAt,
      opponentName: base.opponentName,
      exercise: ExerciseType.squat,
      roundLength: base.roundLength,
      reps: base.reps,
      samples: base.samples,
      poses: const [
        FormPose(
          at: Duration(seconds: 1),
          repIndex: 1,
          points: {
            'leftShoulder': FormPoint(-0.5, 0),
            'rightShoulder': FormPoint(0.5, 0),
            'leftHip': FormPoint(-0.4, 1.2),
            'rightHip': FormPoint(0.4, 1.2),
            'leftKnee': FormPoint(-0.5, 1.8),
          },
        ),
      ],
    );
    expect(analyzer.analyze(report).first.pose?.repIndex, 1);
  });

  test('clean squats earn praise and no issue', () {
    final findings = analyzer.analyze(squatReport(full: 6, shallow: 0));
    expect(findings.map((f) => f.kind), everyElement(FindingKind.good));
    expect(findings.map((f) => f.title), ['정확도 100%', '자세 유지']);
  });

  test('even arms in a squat earn no push-up praise', () {
    final base = squatReport(full: 6, shallow: 0);
    final report = FormReport(
      endedAt: base.endedAt,
      opponentName: base.opponentName,
      exercise: ExerciseType.squat,
      roundLength: base.roundLength,
      reps: base.reps,
      samples: [
        for (var i = 0; i < 20; i++)
          FormSample(
            at: Duration(milliseconds: i * 100),
            depth: 0.8,
            leftElbow: 170,
            rightElbow: 168,
          ),
      ],
    );
    final titles = [for (final f in analyzer.analyze(report)) f.title];
    expect(titles, ['정확도 100%', '자세 유지']);
    expect(analyzer.armBalance(report), ArmBalance.unknown);
  });

  test('even push-up arms still earn the balance praise', () {
    final titles = [
      for (final f in analyzer.analyze(_pushUpArms(_arms(90, 100)))) f.title,
    ];
    expect(titles, contains('양팔 균형'));
  });

  group('late depth', () {
    test('squats losing more than 0.15 of the thigh late are flagged', () {
      final report = _withDepths([0.95, 0.95, 0.78, 0.78]);
      expect(analyzer.depthTrend(report), DepthTrend.dropped);
      final finding = analyzer.analyze(report).first;
      expect(finding.code, 'depth_loss');
      expect(finding.detail, contains('0.95 → 후반 0.78'));
      expect(finding.detail, contains('허벅지'));
      expect(finding.fix, contains('허벅지'));
    });

    test('squats losing less than 0.15 kept their depth', () {
      final report = _withDepths([0.95, 0.95, 0.85, 0.85]);
      expect(analyzer.depthTrend(report), DepthTrend.kept);
      expect(
        analyzer.analyze(report).map((f) => f.code),
        isNot(contains('depth_loss')),
      );
    });

    test('a push-up keeps its 0.25 line for the same drop', () {
      final report = _withDepths([
        1.5,
        1.5,
        1.3,
        1.3,
      ], exercise: ExerciseType.pushUp);
      expect(analyzer.depthLossLimit(ExerciseType.pushUp), 0.25);
      expect(analyzer.depthTrend(report), DepthTrend.kept);
    });

    test('a push-up losing 0.25 is dropped, the same as its finding', () {
      final report = _withDepths([
        1.5,
        1.5,
        1.25,
        1.25,
      ], exercise: ExerciseType.pushUp);
      expect(analyzer.depthTrend(report), DepthTrend.dropped);
      expect(analyzer.analyze(report).first.title, '후반 깊이 감소');
      expect(analyzer.analyze(report).first.detail, contains('머리 하강'));
    });

    test('fewer than four counted reps is too few to tell', () {
      final report = _withDepths([0.9, 0.5, 0.4]);
      expect(analyzer.depthHalves(report), isNull);
      expect(analyzer.depthTrend(report), DepthTrend.tooFew);
    });

    test('the middle rep of an odd count is in neither half', () {
      final halves = analyzer.depthHalves(_withDepths([1, 1, 9, 0.5, 0.5]))!;
      expect(halves.early, 1);
      expect(halves.late, 0.5);
    });
  });

  group('arm balance', () {
    test('a squat never judges the arms', () {
      expect(analyzer.armBalance(squatReport()), ArmBalance.unknown);
    });

    test('push-up arms within 15° are even', () {
      expect(analyzer.armBalance(_pushUpArms(_arms(90, 100))), ArmBalance.even);
    });

    test('the more bent arm is named, as in the imbalance finding', () {
      final left = _pushUpArms(_arms(60, 100));
      expect(analyzer.armBalance(left), ArmBalance.leftDeeper);
      expect(analyzer.analyze(left).first.detail, contains('왼팔을 더 굽혔어요'));
      final right = _pushUpArms(_arms(100, 60));
      expect(analyzer.armBalance(right), ArmBalance.rightDeeper);
      expect(analyzer.analyze(right).first.detail, contains('오른팔을 더 굽혔어요'));
    });

    test('too few samples, or arms seen only at the top, is unknown', () {
      expect(analyzer.armBalance(_pushUpArms(const [])), ArmBalance.unknown);
      expect(
        analyzer.armBalance(_pushUpArms(_arms(60, 100, depth: 0.1))),
        ArmBalance.unknown,
      );
    });
  });
}
