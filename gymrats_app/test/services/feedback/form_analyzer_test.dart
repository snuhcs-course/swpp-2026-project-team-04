import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/feedback/form_analyzer.dart';

FormReport report({
  List<RepRecord> reps = const [],
  List<FormSample> samples = const [],
  List<FormPose> poses = const [],
  FormPose? leftFlarePose,
  FormPose? rightFlarePose,
  FormPose? handsPose,
  FormPose? headPose,
}) => FormReport(
  endedAt: DateTime(2026, 10, 11),
  opponentName: 'RepBot',
  roundLength: const Duration(seconds: 60),
  reps: reps,
  samples: samples,
  poses: poses,
  leftFlarePose: leftFlarePose,
  rightFlarePose: rightFlarePose,
  handsPose: handsPose,
  headPose: headPose,
);

RepRecord rep(
  int index, {
  double depth = 1.5,
  RejectReason? reason,
  Duration? descent,
}) => RepRecord(
  index: index,
  valid: reason == null,
  at: Duration(seconds: index * 2),
  reason: reason,
  maxDepth: depth,
  descent: descent,
);

List<FormSample> arms(
  double left,
  double right, {
  int count = 20,
  double depth = 1.2,
}) => [
  for (var i = 0; i < count; i++)
    FormSample(
      at: Duration(milliseconds: i * 100),
      depth: depth,
      leftElbow: left,
      rightElbow: right,
    ),
];

void main() {
  const analyzer = FormAnalyzer();

  List<String> titles(FormReport r) => [
    for (final f in analyzer.analyze(r)) f.title,
  ];

  FormFinding? find(FormReport r, String title) =>
      analyzer.analyze(r).where((f) => f.title == title).firstOrNull;

  test('uneven arms are an imbalance, naming the more bent side', () {
    final finding = find(report(samples: arms(140, 165)), '좌우 불균형')!;
    expect(finding.kind, FindingKind.issue);
    expect(finding.detail, contains('25°'));
    expect(finding.detail, contains('왼팔'));
    expect(finding.fix, isNotNull);
  });

  test('even arms are praised, not flagged', () {
    final r = report(samples: arms(160, 165));
    expect(titles(r), isNot(contains('좌우 불균형')));
    expect(find(r, '양팔 균형')!.kind, FindingKind.good);
  });

  test('time at the top does not hide a gap while the head is down', () {
    final r = report(
      samples: [
        ...arms(170, 170, count: 40, depth: 0.1),
        ...arms(120, 160, count: 10, depth: 1.2),
      ],
    );
    final finding = find(r, '좌우 불균형')!;
    expect(finding.detail, contains('40°'));
    expect(finding.detail, contains('왼팔'));
  });

  test('a gap only at the top is not an imbalance', () {
    final r = report(samples: arms(100, 160, count: 20, depth: 0.1));
    expect(titles(r), isNot(contains('좌우 불균형')));
    expect(titles(r), isNot(contains('양팔 균형')));
  });

  test('too few samples with both arms says nothing about balance', () {
    final r = report(samples: arms(120, 170, count: 9));
    expect(titles(r), isNot(contains('좌우 불균형')));
    expect(titles(r), isNot(contains('양팔 균형')));
  });

  test('shallower late reps are a loss of depth', () {
    final r = report(
      reps: [
        for (final (i, d) in [1.7, 1.6, 1.3, 1.2].indexed) rep(i + 1, depth: d),
      ],
    );
    final finding = find(r, '후반 깊이 감소')!;
    expect(finding.detail, contains('1.65'));
    expect(finding.detail, contains('1.25'));
  });

  test('steady depth, or too few reps, has no depth finding', () {
    final steady = report(
      reps: [for (var i = 1; i <= 6; i++) rep(i, depth: 1.5)],
    );
    expect(titles(steady), isNot(contains('후반 깊이 감소')));
    final few = report(reps: [rep(1, depth: 1.8), rep(2, depth: 1.0)]);
    expect(titles(few), isNot(contains('후반 깊이 감소')));
  });

  test('cheats are listed with their count and a fix', () {
    final r = report(
      reps: [
        rep(1, reason: RejectReason.kneesDown),
        rep(2, reason: RejectReason.kneesDown),
        rep(3, reason: RejectReason.notFloorPushUp),
      ],
    );
    final knees = find(r, '무릎 대고 함 2회')!;
    expect(knees.kind, FindingKind.issue);
    expect(knees.fix, contains('무릎'));
    expect(find(r, '바닥 푸시업 아님 1회'), isNotNull);
    expect(titles(r).first, '무릎 대고 함 2회');
  });

  test('a clean battle gets good points and no issues', () {
    final r = report(
      reps: [for (var i = 1; i <= 6; i++) rep(i)],
      samples: arms(160, 162),
    );
    final findings = analyzer.analyze(r);
    expect(findings.where((f) => f.kind == FindingKind.issue), isEmpty);
    expect(titles(r), containsAll(['정확도 100%', '양팔 균형', '자세 유지']));
  });

  test('hidden arms say nothing about the elbow angle', () {
    final r = report(reps: [rep(1)]);
    expect(titles(r), isNot(contains('팔꿈치 각도')));
  });

  test('fast descents on half the reps are feedback and still counted', () {
    final r = report(
      reps: [
        for (var i = 1; i <= 4; i++)
          rep(
            i,
            descent: Duration(milliseconds: i.isEven ? 180 : 500),
          ),
      ],
    );
    final finding = find(r, '내려가는 속도')!;
    expect(finding.kind, FindingKind.issue);
    expect(finding.detail, contains('4회 중 2회'));
    expect(finding.detail, contains('인정'));
    expect(finding.detail, contains('0.18'));
    expect(finding.fix, isNotNull);
  });

  test('one fast descent, or fewer than four, says nothing', () {
    final one = report(
      reps: [
        rep(1, descent: const Duration(milliseconds: 150)),
        for (var i = 2; i <= 6; i++)
          rep(i, descent: const Duration(milliseconds: 700)),
      ],
    );
    expect(titles(one), isNot(contains('내려가는 속도')));
    final few = report(
      reps: [
        for (var i = 1; i <= 3; i++)
          rep(i, descent: const Duration(milliseconds: 100)),
      ],
    );
    expect(titles(few), isNot(contains('내려가는 속도')));
  });

  test('flared elbows, wide hands, and a leading head are named', () {
    final pose = FormPose(
      at: const Duration(seconds: 2),
      points: {
        'leftShoulder': FormPoint(-0.5, 0),
        'rightShoulder': FormPoint(0.5, 0),
        'leftElbow': FormPoint(-1.6, 0.2),
        'nose': FormPoint(0, -0.4),
      },
    );
    final r = report(
      samples: [
        for (var i = 0; i < 12; i++)
          FormSample(
            at: Duration(milliseconds: i * 100),
            depth: 1.2,
            shoulderDrop: 0.6,
            leftSpread: 1.2,
            rightSpread: 0.4,
            handSpan: 2.4,
          ),
      ],
      leftFlarePose: pose,
      handsPose: pose,
      headPose: pose,
    );
    final flare = find(r, '팔꿈치 벌어짐')!;
    expect(flare.detail, contains('왼팔꿈치'));
    expect(flare.detail, contains('1.2'));
    expect(flare.pose, same(pose));
    expect(flare.highlight, ['leftElbow']);
    expect(find(r, '손 간격')!.detail, contains('2.4'));
    expect(find(r, '고개가 먼저 내려감')!.detail, contains('0.60'));
  });

  test('the stick figure is the arm the sentence names', () {
    final left = FormPose(
      at: const Duration(seconds: 1),
      points: {
        'leftShoulder': FormPoint(-0.5, 0),
        'rightShoulder': FormPoint(0.5, 0),
        'leftElbow': FormPoint(-1.4, 0.2),
        'nose': FormPoint(0, -0.2),
      },
    );
    final right = FormPose(
      at: const Duration(seconds: 2),
      points: {
        'leftShoulder': FormPoint(-0.5, 0),
        'rightShoulder': FormPoint(0.5, 0),
        'rightElbow': FormPoint(1.6, 0.2),
        'nose': FormPoint(0, -0.2),
      },
    );
    final r = report(
      samples: [
        for (var i = 0; i < 12; i++)
          FormSample(
            at: Duration(milliseconds: i * 100),
            depth: 1.2,
            leftSpread: 0.4,
            rightSpread: 1.3,
          ),
      ],
      leftFlarePose: left,
      rightFlarePose: right,
    );
    final flare = find(r, '팔꿈치 벌어짐')!;
    expect(flare.detail, contains('오른팔꿈치'));
    expect(flare.pose, same(right));
    expect(flare.highlight, ['rightElbow']);
  });

  test('a head drop with still shoulders says nothing', () {
    final r = report(
      samples: [
        for (var i = 0; i < 12; i++)
          FormSample(
            at: Duration(milliseconds: i * 100),
            depth: 1.5,
            shoulderDrop: 0.05,
          ),
      ],
    );
    expect(titles(r), isNot(contains('고개가 먼저 내려감')));
  });

  test('a deep push-up with a slightly closer nose says nothing', () {
    final r = report(
      samples: [
        for (var i = 0; i < 12; i++)
          FormSample(
            at: Duration(milliseconds: i * 100),
            depth: 2.1,
            shoulderDrop: 1.5,
          ),
      ],
    );
    expect(titles(r), isNot(contains('고개가 먼저 내려감')));
  });

  test('mild spread, narrow hands, and a short head lead say nothing', () {
    final r = report(
      samples: [
        for (var i = 0; i < 12; i++)
          FormSample(
            at: Duration(milliseconds: i * 100),
            depth: 1.2,
            shoulderDrop: 1.0,
            leftSpread: 0.4,
            rightSpread: 0.4,
            handSpan: 1.3,
          ),
      ],
    );
    expect(titles(r), isNot(contains('팔꿈치 벌어짐')));
    expect(titles(r), isNot(contains('손 간격')));
    expect(titles(r), isNot(contains('고개가 먼저 내려감')));
  });

  test('a figure with too few joints is not attached', () {
    final r = report(
      samples: [
        for (var i = 0; i < 12; i++)
          FormSample(
            at: Duration(milliseconds: i * 100),
            handSpan: 2.5,
          ),
      ],
      handsPose: FormPose(
        at: const Duration(seconds: 1),
        points: {
          'leftShoulder': FormPoint(-0.5, 0),
          'rightShoulder': FormPoint(0.5, 0),
          'leftWrist': FormPoint(-1.2, 0.8),
        },
      ),
    );
    expect(find(r, '손 간격')!.pose, isNull);
  });

  test('visible arms give the lowest and mean elbow angle', () {
    final note = find(report(samples: arms(150, 170)), '팔꿈치 각도')!;
    expect(note.detail, contains('최소 150°'));
    expect(note.detail, contains('평균 160°'));
  });
}
