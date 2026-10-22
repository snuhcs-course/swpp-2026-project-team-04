// AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
import 'dart:math' as math;

import '../../models/form_report.dart';
import '../../models/reject_reason_korean.dart';
import '../../models/rep_event.dart';

/// A prepared side-view example of one fault. Not the user's own frame.
enum FormDemo {
  shallow,
  lockout,
  tilted,
  knees,
  straightArms,
  belly,
  upright,
  flare,
  wideHands,
  headFirst,
  uneven,
  fastDrop,
}

/// How a finding reads on the feedback screen.
enum FindingKind {
  /// Something to fix.
  issue,

  /// Something done well.
  good,

  /// A measurement or a limit of what could be seen, neither good nor bad.
  note,
}

/// One rule's verdict on a battle, in Korean for the feedback screen.
class FormFinding {
  const FormFinding({
    required this.kind,
    required this.title,
    required this.detail,
    this.fix,
    this.pose,
    this.highlight = const [],
    this.demo,
  });

  final FindingKind kind;

  /// e.g. "좌우 불균형".
  final String title;

  /// What was measured, with the numbers.
  final String detail;

  /// How to correct it. Null for good points and notes.
  final String? fix;

  /// The moment this finding is about, when that moment was visible.
  final FormPose? pose;

  /// Landmark names to draw in amber on [pose].
  final List<String> highlight;

  /// Side-view example for this fault. Null for praise, notes, and a
  /// moved phone, which is not a body position.
  final FormDemo? demo;
}

/// Thresholds of the form rules.
class FormRules {
  const FormRules({
    this.minSamples = 10,
    this.maxElbowGap = 15,
    this.workingDepth = formWorkingDepth,
    this.minRepsForTrend = 4,
    this.maxDepthLoss = 0.25,
    this.fastDescent = const Duration(milliseconds: 300),
    this.maxElbowSpread = formMaxElbowSpread,
    this.maxHandSpan = formMaxHandSpan,
    this.maxHeadLead = formMaxHeadLead,
    this.goodAccuracy = 0.9,
  });

  /// A rule over samples needs at least this many samples with its values.
  final int minSamples;

  /// Mean left/right elbow difference above this, in degrees, is uneven.
  final double maxElbowGap;

  /// Head drop, in shoulder widths, at or above which the arms are in the
  /// rep. Straighter arms at the top are left out of the balance rule, or
  /// the time spent locked out would hide a real gap.
  final double workingDepth;

  /// Late depth and descent speed need at least this many reps.
  final int minRepsForTrend;

  /// The second half of the valid reps averaging this much shallower than
  /// the first half, in shoulder widths, is a loss of depth.
  final double maxDepthLoss;

  /// A descent from the start of the attempt to the bottom shorter than
  /// this is fast. The rep still counts. The rule speaks only when at
  /// least half of the timed reps are this fast.
  final Duration fastDescent;

  /// Mean elbow distance outside its shoulder, in shoulder widths, above
  /// which the arm is flared. The front camera cannot see the 3D angle.
  final double maxElbowSpread;

  /// Mean wrist-to-wrist distance, in shoulder widths, above which the
  /// hands are wide enough to mention.
  final double maxHandSpan;

  /// Mean extra head drop beyond the shoulders, in shoulder widths, above
  /// which the head led the chest.
  final double maxHeadLead;

  /// Accuracy at or above this is praised.
  final double goodAccuracy;
}

/// Turns a [FormReport] into findings with fixed rules. Pure Dart, on the
/// device; a rule without enough data says nothing rather than guess.
class FormAnalyzer {
  const FormAnalyzer({this.rules = const FormRules()});

  final FormRules rules;

  List<FormFinding> analyze(FormReport report) {
    final issues = [
      ..._rejections(report),
      ?_imbalance(report),
      ?_lateDepthLoss(report),
      ?_fastDescent(report),
      ?_flare(report),
      ?_handWidth(report),
      ?_headLead(report),
    ];
    return [
      ...issues,
      ..._goodPoints(report, hasIssues: issues.isNotEmpty),
      ?_elbowNote(report),
    ];
  }

  /// Samples taken while the head was down, so the top of the push-up is
  /// not part of the arm comparison.
  Iterable<FormSample> _working(FormReport report) => [
    for (final s in report.samples)
      if (s.depth != null && s.depth! >= rules.workingDepth) s,
  ];

  /// Mean |left − right| elbow angle over the working samples with both
  /// arms seen. Null with fewer than [FormRules.minSamples] such samples.
  double? elbowGap(FormReport report) {
    final gaps = [
      for (final s in _working(report))
        if (s.leftElbow != null && s.rightElbow != null)
          (s.leftElbow! - s.rightElbow!).abs(),
    ];
    if (gaps.length < rules.minSamples) return null;
    return gaps.reduce((a, b) => a + b) / gaps.length;
  }

  List<FormFinding> _rejections(FormReport report) {
    final counts = <RejectReason, int>{};
    for (final rep in report.reps) {
      final reason = rep.reason;
      if (reason != null) counts[reason] = (counts[reason] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final MapEntry(key: reason, value: count) in sorted)
        FormFinding(
          kind: FindingKind.issue,
          title: '${_titles[reason]} $count회',
          detail: '${reason.koreanMessage} — 이 이유로 $count회가 카운트되지 않았어요.',
          fix: _fixes[reason],
          pose: _poseFor(report, reason),
          highlight: _rejectHighlight[reason] ?? const <String>[],
          demo: _demos[reason],
        ),
    ];
  }

  FormFinding? _imbalance(FormReport report) {
    final both = [
      for (final s in _working(report))
        if (s.leftElbow != null && s.rightElbow != null) s,
    ];
    final gap = elbowGap(report);
    if (gap == null || gap <= rules.maxElbowGap) return null;
    final leftMean =
        both.map((s) => s.leftElbow!).reduce((a, b) => a + b) / both.length;
    final rightMean =
        both.map((s) => s.rightElbow!).reduce((a, b) => a + b) / both.length;
    final bentSide = leftMean < rightMean ? '왼팔' : '오른팔';
    return FormFinding(
      kind: FindingKind.issue,
      title: '좌우 불균형',
      detail:
          '양팔 각도가 평균 ${gap.toStringAsFixed(0)}° 달라요. '
          '$bentSide을 더 굽혔어요.',
      fix: '손을 어깨 바로 아래 같은 거리에 두고, 양손에 체중을 똑같이 실어요.',
      demo: FormDemo.uneven,
    );
  }

  FormFinding? _lateDepthLoss(FormReport report) {
    final depths = [
      for (final r in report.reps)
        if (r.valid && r.maxDepth != null) r.maxDepth!,
    ];
    if (depths.length < rules.minRepsForTrend) return null;
    final half = depths.length ~/ 2;
    double mean(Iterable<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
    final early = mean(depths.take(half));
    final late = mean(depths.skip(depths.length - half));
    if (early - late < rules.maxDepthLoss) return null;
    return FormFinding(
      kind: FindingKind.issue,
      title: '후반 깊이 감소',
      detail:
          '전반 평균 ${early.toStringAsFixed(2)} → 후반 '
          '${late.toStringAsFixed(2)} (어깨 너비 기준 머리 하강).',
      fix: '지치면 속도를 줄이더라도 매번 같은 깊이까지 내려가요.',
      demo: FormDemo.shallow,
    );
  }

  /// Speaks when at least half of the reps that reached the bottom got
  /// there quicker than [FormRules.fastDescent]. Fewer timed reps say
  /// nothing. The reps themselves stay counted.
  FormFinding? _fastDescent(FormReport report) {
    final descents = [
      for (final r in report.reps)
        if (r.descent != null) r.descent!,
    ];
    if (descents.length < rules.minRepsForTrend) return null;
    final fast = [
      for (final d in descents)
        if (d < rules.fastDescent) d,
    ];
    if (fast.length * 2 < descents.length) return null;
    final fastest = fast.reduce((a, b) => a < b ? a : b);
    return FormFinding(
      kind: FindingKind.issue,
      title: '내려가는 속도',
      detail:
          '바닥까지 내려간 ${descents.length}회 중 ${fast.length}회가 '
          '${_seconds(rules.fastDescent)}초보다 짧아요. 횟수는 그대로 인정됐고, '
          '가장 빠른 하강은 ${_seconds(fastest)}초예요.',
      fix: '떨어지듯 내려가지 말고, 팔과 몸에 힘을 유지한 채 내려가요.',
      demo: FormDemo.fastDrop,
    );
  }

  /// Elbows sitting far outside the shoulders while the head is down.
  /// Quiet when an arm was barely seen. The rep still counts.
  FormFinding? _flare(FormReport report) {
    final left = _mean([
      for (final s in _working(report))
        if (s.leftSpread != null) s.leftSpread!,
    ]);
    final right = _mean([
      for (final s in _working(report))
        if (s.rightSpread != null) s.rightSpread!,
    ]);
    final worse = switch ((left, right)) {
      (final left?, final right?) => left > right ? left : right,
      (final left?, null) => left,
      (null, final right?) => right,
      _ => null,
    };
    if (worse == null || worse <= rules.maxElbowSpread) return null;
    final side = switch ((left, right)) {
      (final left?, final right?) when (left - right).abs() < 0.25 => '양 팔꿈치',
      (final left?, final right?) => left > right ? '왼팔꿈치' : '오른팔꿈치',
      (final _?, null) => '왼팔꿈치',
      _ => '오른팔꿈치',
    };
    final highlight = side == '양 팔꿈치'
        ? const ['leftElbow', 'rightElbow']
        : side == '왼팔꿈치'
        ? const ['leftElbow']
        : const ['rightElbow'];
    final pose = switch (side) {
      '왼팔꿈치' => report.leftFlarePose,
      '오른팔꿈치' => report.rightFlarePose,
      _ =>
        (left ?? -1) >= (right ?? -1)
            ? (report.leftFlarePose ?? report.rightFlarePose)
            : (report.rightFlarePose ?? report.leftFlarePose),
    };
    return FormFinding(
      kind: FindingKind.issue,
      title: '팔꿈치 벌어짐',
      detail:
          '내려가는 동안 $side가 어깨 밖으로 평균 '
          '${worse.toStringAsFixed(1)}배 어깨너비만큼 나가 있어요. '
          '정면에서는 팔이 뒤로 빠진 정도는 보이지 않아요.',
      fix: '팔꿈치를 옆이 아니라 몸통 쪽으로 접어요.',
      pose: _shown(pose),
      highlight: highlight,
      demo: FormDemo.flare,
    );
  }

  /// Hands planted much wider than the shoulders. Quiet when the wrists
  /// were barely seen. The rep still counts.
  FormFinding? _handWidth(FormReport report) {
    final spans = [
      for (final s in report.samples)
        if (s.handSpan != null) s.handSpan!,
    ];
    final mean = _mean(spans);
    if (mean == null || mean <= rules.maxHandSpan) return null;
    return FormFinding(
      kind: FindingKind.issue,
      title: '손 간격',
      detail:
          '양손 간격이 어깨너비의 평균 ${mean.toStringAsFixed(1)}배예요. '
          '어깨보다 훨씬 넓어요.',
      fix: '손을 어깨보다 조금만 넓게 짚어요. 너무 넓으면 어깨에 부담이 커져요.',
      pose: _shown(report.handsPose),
      highlight: const ['leftWrist', 'rightWrist'],
      demo: FormDemo.wideHands,
    );
  }

  /// The nose dropped well ahead of shoulders that themselves moved.
  /// Quiet when the shoulders stayed put, or when the extra is only the
  /// amount a closer nose picks up from a floor camera. The rep still counts.
  FormFinding? _headLead(FormReport report) {
    final leads = <double>[];
    final drops = <double>[];
    for (final s in _working(report)) {
      final drop = s.shoulderDrop;
      final depth = s.depth;
      if (depth == null || drop == null || drop < formMinShoulderDrop) {
        continue;
      }
      leads.add(depth - drop);
      drops.add(drop);
    }
    final mean = _mean(leads);
    final dropMean = _mean(drops);
    if (mean == null ||
        dropMean == null ||
        mean <= rules.maxHeadLead ||
        mean <= dropMean * formHeadLeadRatio) {
      return null;
    }
    return FormFinding(
      kind: FindingKind.issue,
      title: '고개가 먼저 내려감',
      detail:
          '머리가 어깨보다 평균 ${mean.toStringAsFixed(2)}배 어깨너비만큼 '
          '더 내려갔어요.',
      fix: '고개만 숙이지 말고, 가슴과 같이 내려가요.',
      pose: _shown(report.headPose),
      highlight: const ['nose'],
      demo: FormDemo.headFirst,
    );
  }

  /// Null when there are fewer than [FormRules.minSamples] values.
  double? _mean(List<double> values) {
    if (values.length < rules.minSamples) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// The deepest saved moment of a rep rejected for [reason].
  FormPose? _poseFor(FormReport report, RejectReason reason) {
    FormPose? best;
    var bestDepth = double.negativeInfinity;
    for (final rep in report.reps) {
      if (rep.reason != reason) continue;
      final pose = report.poses
          .where((p) => p.repIndex == rep.index)
          .firstOrNull;
      final depth = rep.maxDepth ?? 0;
      if (pose != null && depth >= bestDepth) {
        best = pose;
        bestDepth = depth;
      }
    }
    return _shown(best);
  }

  /// A figure with too few joints is not shown.
  FormPose? _shown(FormPose? pose) =>
      pose != null && pose.points.length >= 4 ? pose : null;

  List<FormFinding> _goodPoints(FormReport report, {required bool hasIssues}) {
    final judged = report.reps.length;
    final accuracy = judged == 0 ? null : report.validReps / judged;
    final gap = elbowGap(report);
    return [
      if (accuracy != null &&
          report.validReps >= 5 &&
          accuracy >= rules.goodAccuracy)
        FormFinding(
          kind: FindingKind.good,
          title: '정확도 ${(accuracy * 100).round()}%',
          detail: '$judged회 중 ${report.validReps}회가 카운트됐어요.',
        ),
      if (gap != null && gap <= rules.maxElbowGap)
        FormFinding(
          kind: FindingKind.good,
          title: '양팔 균형',
          detail: '양팔 각도 차이가 평균 ${gap.toStringAsFixed(0)}°로 고르게 밀었어요.',
        ),
      if (!hasIssues && judged > 0)
        const FormFinding(
          kind: FindingKind.good,
          title: '자세 유지',
          detail: '경기 내내 고칠 점이 보이지 않았어요.',
        ),
    ];
  }

  /// The min and mean elbow angle, when enough of the arms were seen.
  /// With less than that, the rule stays quiet: the chart already says
  /// the arms were not in frame.
  FormFinding? _elbowNote(FormReport report) {
    final angles = [
      for (final s in report.samples) ...[?s.leftElbow, ?s.rightElbow],
    ];
    if (angles.length < rules.minSamples) return null;
    final low = angles.reduce(math.min);
    final mean = angles.reduce((a, b) => a + b) / angles.length;
    return FormFinding(
      kind: FindingKind.note,
      title: '팔꿈치 각도',
      detail:
          '보인 구간에서 최소 ${low.toStringAsFixed(0)}°, 평균 '
          '${mean.toStringAsFixed(0)}°. 정면에서는 팔이 덜 굽어 보여서 깊이는 '
          '머리 하강으로 판정해요.',
    );
  }

  static const _titles = {
    RejectReason.insufficientDepth: '깊이 부족',
    RejectReason.incompleteExtension: '팔 덜 폄',
    RejectReason.shouldersNotLevel: '어깨 기울어짐',
    RejectReason.tooFast: '너무 빠름',
    RejectReason.kneesDown: '무릎 대고 함',
    RejectReason.armsStraight: '팔 안 굽힘',
    RejectReason.bellyDown: '배 대고 함',
    RejectReason.notFloorPushUp: '바닥 푸시업 아님',
    RejectReason.phoneMoved: '폰이 움직임',
  };

  static const _demos = {
    RejectReason.insufficientDepth: FormDemo.shallow,
    RejectReason.incompleteExtension: FormDemo.lockout,
    RejectReason.shouldersNotLevel: FormDemo.tilted,
    RejectReason.kneesDown: FormDemo.knees,
    RejectReason.armsStraight: FormDemo.straightArms,
    RejectReason.bellyDown: FormDemo.belly,
    RejectReason.notFloorPushUp: FormDemo.upright,
  };

  static const _fixes = {
    RejectReason.insufficientDepth: '가슴이 바닥에 가까워질 때까지 내려간 뒤 올라와요.',
    RejectReason.incompleteExtension: '올라올 때 팔꿈치를 끝까지 펴고 다음 회로 넘어가요.',
    RejectReason.shouldersNotLevel: '양손 위치를 맞추고 한쪽으로 기울지 않게 내려가요.',
    RejectReason.tooFast: '내려가고 올라오는 데 각각 반 박자씩 써요.',
    RejectReason.kneesDown: '무릎을 펴고 발끝으로 버텨요. 힘들면 횟수를 줄여요.',
    RejectReason.armsStraight: '등을 둥글게 말고, 엉덩이를 낮춘 채 팔을 굽혀 내려가요.',
    RejectReason.bellyDown: '배와 엉덩이에 힘을 줘 몸을 일자로 들고 내려가요.',
    RejectReason.notFloorPushUp: '벽이나 높은 곳 말고 바닥에 손을 짚고 해요.',
    RejectReason.phoneMoved: '폰을 세워 두고, 흔들리지 않게 고정한 뒤 해요.',
  };

  static const _rejectHighlight = {
    RejectReason.insufficientDepth: ['nose'],
    RejectReason.incompleteExtension: ['leftElbow', 'rightElbow'],
    RejectReason.shouldersNotLevel: ['leftShoulder', 'rightShoulder'],
    RejectReason.kneesDown: ['leftKnee', 'rightKnee'],
    RejectReason.armsStraight: [
      'leftElbow',
      'rightElbow',
      'leftHip',
      'rightHip',
    ],
    RejectReason.bellyDown: ['leftHip', 'rightHip'],
    RejectReason.notFloorPushUp: ['leftHip', 'rightHip'],
    RejectReason.phoneMoved: <String>[],
  };
}

/// 0.30 becomes "0.3", 0.18 stays "0.18".
String _seconds(Duration d) {
  final text = (d.inMilliseconds / 1000).toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}
