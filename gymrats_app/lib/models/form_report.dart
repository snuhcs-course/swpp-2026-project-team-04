// AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
import 'dart:math' as math;

import 'pose_frame.dart';
import 'rep_event.dart';

/// Head drop, in shoulder widths, at which the arms are in the rep rather
/// than locked out. The form rules and the snapshot picker share it, so
/// the stick figure is from the same part of the rep the sentence describes.
const formWorkingDepth = 0.6;

/// Coaching lines for the front-view rules. A rep is never rejected for
/// crossing one. The snapshot picker uses the same lines, so a figure is
/// kept only for a moment the rule can talk about.
const formMaxElbowSpread = 0.85;

/// Wrist-to-wrist distance, in shoulder widths, above which the hands are
/// wide enough to mention. A floor camera enlarges the hands, which sit
/// closer than the shoulders, so this line is well past a normal grip.
const formMaxHandSpan = 2.2;
const formMaxHeadLead = 0.5;

/// Shoulder drop, in shoulder widths, below which the head-lead rule stays
/// quiet. A baseline that never moves would make every push-up look like
/// the head went first.
const formMinShoulderDrop = 0.3;

/// The extra head drop has to be at least this fraction of the shoulder
/// drop as well. A floor camera enlarges the nose, which is closer than
/// the shoulders, so a small extra on a deep push-up is not a nod.
const formHeadLeadRatio = 0.5;

/// Body measurements at one moment of a round, for the form report.
///
/// Only numbers derived from the landmarks are kept, never the image. Null
/// means the body part was not reliably seen at that moment.
class FormSample {
  const FormSample({
    required this.at,
    this.depth,
    this.leftElbow,
    this.rightElbow,
    this.tilt,
    this.torsoDrop,
    this.hipAngle,
    this.shoulderDrop,
    this.leftSpread,
    this.rightSpread,
    this.handSpan,
  });

  /// Time into the round.
  final Duration at;

  /// Head drop below the top pose, in shoulder widths.
  final double? depth;

  /// Shoulder–elbow–wrist angles of the user's own left and right arm.
  final double? leftElbow;
  final double? rightElbow;

  /// Shoulder line away from horizontal, in degrees.
  final double? tilt;

  /// Hips below the shoulders, in shoulder widths.
  final double? torsoDrop;

  /// Shoulder–hip–knee angle, in degrees.
  final double? hipAngle;

  /// How far the shoulders dropped below the top pose, in shoulder widths.
  final double? shoulderDrop;

  /// How far each elbow sits outside its shoulder, in shoulder widths.
  final double? leftSpread;
  final double? rightSpread;

  /// Wrist-to-wrist distance, in shoulder widths.
  final double? handSpan;

  Map<String, Object?> toJson() => {
    'ms': at.inMilliseconds,
    'depth': depth,
    'leftElbow': leftElbow,
    'rightElbow': rightElbow,
    'tilt': tilt,
    'torsoDrop': torsoDrop,
    'hipAngle': hipAngle,
    'shoulderDrop': shoulderDrop,
    'leftSpread': leftSpread,
    'rightSpread': rightSpread,
    'handSpan': handSpan,
  };

  factory FormSample.fromJson(Map<String, Object?> json) => FormSample(
    at: Duration(milliseconds: json['ms']! as int),
    depth: _double(json['depth']),
    leftElbow: _double(json['leftElbow']),
    rightElbow: _double(json['rightElbow']),
    tilt: _double(json['tilt']),
    torsoDrop: _double(json['torsoDrop']),
    hipAngle: _double(json['hipAngle']),
    shoulderDrop: _double(json['shoulderDrop']),
    leftSpread: _double(json['leftSpread']),
    rightSpread: _double(json['rightSpread']),
    handSpan: _double(json['handSpan']),
  );
}

/// One joint of a [FormPose], in shoulder widths from the shoulder midpoint.
///
/// [x] is the user's own view: their left is negative, matching the mirrored
/// front-camera preview. [y] grows downward, as on the screen.
class FormPoint {
  const FormPoint(this.x, this.y);

  final double x;
  final double y;

  List<double> toJson() => [x, y];

  factory FormPoint.fromJson(Object? json) {
    final pair = json! as List;
    return FormPoint((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
  }
}

/// A stick figure of one moment. Joints that were not visible are absent.
///
/// Coordinates are body-relative, never pixels and never the camera image.
/// At most the shoulders, arms, nose, hips, and knees are kept.
class FormPose {
  const FormPose({required this.at, required this.points, this.repIndex});

  /// Joints worth drawing. Fingers, feet, and the face besides the nose
  /// are left out.
  static const kept = [
    BodyLandmark.nose,
    BodyLandmark.leftShoulder,
    BodyLandmark.rightShoulder,
    BodyLandmark.leftElbow,
    BodyLandmark.rightElbow,
    BodyLandmark.leftWrist,
    BodyLandmark.rightWrist,
    BodyLandmark.leftHip,
    BodyLandmark.rightHip,
    BodyLandmark.leftKnee,
    BodyLandmark.rightKnee,
  ];

  final Duration at;

  /// The rep this moment belongs to, when it is that rep's deepest frame.
  final int? repIndex;

  /// Landmark name to a point. Both shoulders are always present.
  final Map<String, FormPoint> points;

  FormPose copyWith({int? repIndex}) =>
      FormPose(at: at, repIndex: repIndex ?? this.repIndex, points: points);

  /// The pose in [frame], or null when the shoulders are not both visible
  /// or fewer than four joints are reliable.
  ///
  /// [mirror] flips x so a front-camera preview and this figure put the
  /// user's left on the same side. Points farther than four shoulder
  /// widths from the shoulders are dropped.
  static FormPose? capture(
    PoseFrame frame, {
    required Duration at,
    required bool mirror,
    required double minLikelihood,
    int? repIndex,
  }) {
    bool seen(Keypoint? keypoint) =>
        keypoint != null && keypoint.likelihood >= minLikelihood;
    final left = frame[BodyLandmark.leftShoulder];
    final right = frame[BodyLandmark.rightShoulder];
    if (!seen(left) || !seen(right)) return null;
    final midX = (left!.x + right!.x) / 2;
    final midY = (left.y + right.y) / 2;
    final width = _distance(left, right);
    if (width < 1e-6) return null;

    final points = <String, FormPoint>{};
    for (final landmark in kept) {
      final keypoint = frame[landmark];
      if (!seen(keypoint)) continue;
      final x = ((mirror ? midX - keypoint!.x : keypoint!.x - midX) / width);
      final y = (keypoint.y - midY) / width;
      if (x.abs() > 4 || y.abs() > 4) continue;
      points[landmark.name] = FormPoint(_round(x), _round(y));
    }
    if (points.length < 4 ||
        !points.containsKey(BodyLandmark.leftShoulder.name) ||
        !points.containsKey(BodyLandmark.rightShoulder.name)) {
      return null;
    }
    return FormPose(at: at, repIndex: repIndex, points: points);
  }

  Map<String, Object?> toJson() => {
    'ms': at.inMilliseconds,
    'rep': repIndex,
    'points': {for (final e in points.entries) e.key: e.value.toJson()},
  };

  factory FormPose.fromJson(Map<String, Object?> json) => FormPose(
    at: Duration(milliseconds: json['ms']! as int),
    repIndex: json['rep'] as int?,
    points: {
      for (final e in (json['points']! as Map).entries)
        e.key as String: FormPoint.fromJson(e.value),
    },
  );
}

double _distance(Keypoint a, Keypoint b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

double _round(double v) => (v * 100).roundToDouble() / 100;

/// One judged rep, as the form report keeps it.
class RepRecord {
  const RepRecord({
    required this.index,
    required this.valid,
    required this.at,
    this.reason,
    this.maxDepth,
    this.minElbowAngle,
    this.maxTilt,
    this.descent,
  });

  /// [event] closed at [at] into the round.
  factory RepRecord.fromEvent(RepEvent event, Duration at) => RepRecord(
    index: event.index,
    valid: event.valid,
    at: at,
    reason: event.reason,
    maxDepth: event.maxDepth,
    minElbowAngle: event.minElbowAngle,
    maxTilt: event.maxTilt,
    descent: event.descent,
  );

  final int index;
  final bool valid;

  /// Time into the round when the rep closed.
  final Duration at;
  final RejectReason? reason;
  final double? maxDepth;
  final double? minElbowAngle;
  final double? maxTilt;

  /// Time from the start of the attempt until the bottom. Null when the
  /// head never got there.
  final Duration? descent;

  Map<String, Object?> toJson() => {
    'index': index,
    'valid': valid,
    'ms': at.inMilliseconds,
    'reason': reason?.name,
    'maxDepth': maxDepth,
    'minElbowAngle': minElbowAngle,
    'maxTilt': maxTilt,
    'descentMs': descent?.inMilliseconds,
  };

  /// A reason this version does not know is read as no reason.
  factory RepRecord.fromJson(Map<String, Object?> json) => RepRecord(
    index: json['index']! as int,
    valid: json['valid']! as bool,
    at: Duration(milliseconds: json['ms']! as int),
    reason: RejectReason.values
        .where((r) => r.name == json['reason'])
        .firstOrNull,
    maxDepth: _double(json['maxDepth']),
    minElbowAngle: _double(json['minElbowAngle']),
    maxTilt: _double(json['maxTilt']),
    descent: switch (json['descentMs']) {
      final num ms => Duration(milliseconds: ms.round()),
      _ => null,
    },
  );
}

/// Everything measured of the user in one finished battle. Saved on the
/// device only; the feedback is computed from it when it is shown.
class FormReport {
  const FormReport({
    required this.endedAt,
    required this.opponentName,
    required this.roundLength,
    required this.reps,
    required this.samples,
    this.poses = const [],
    this.leftFlarePose,
    this.rightFlarePose,
    this.handsPose,
    this.headPose,
  });

  final DateTime endedAt;

  /// e.g. "RepBot".
  final String opponentName;
  final Duration roundLength;
  final List<RepRecord> reps;
  final List<FormSample> samples;

  /// Deepest moment of each judged rep, when the shoulders were visible.
  final List<FormPose> poses;

  /// The moment each elbow sat furthest outside its shoulder, the hands
  /// were widest, and the head led the shoulders the most. Null when that
  /// part was not seen past the line the rule uses.
  final FormPose? leftFlarePose;
  final FormPose? rightFlarePose;
  final FormPose? handsPose;
  final FormPose? headPose;

  /// File name and identity: the end time is unique per battle.
  String get id => endedAt.millisecondsSinceEpoch.toString();

  int get validReps => reps.where((r) => r.valid).length;
  int get invalidReps => reps.length - validReps;

  Map<String, Object?> toJson() => {
    'version': 1,
    'endedAt': endedAt.millisecondsSinceEpoch,
    'opponentName': opponentName,
    'roundMs': roundLength.inMilliseconds,
    'reps': [for (final r in reps) r.toJson()],
    'samples': [for (final s in samples) s.toJson()],
    'poses': [for (final p in poses) p.toJson()],
    'leftFlarePose': leftFlarePose?.toJson(),
    'rightFlarePose': rightFlarePose?.toJson(),
    'handsPose': handsPose?.toJson(),
    'headPose': headPose?.toJson(),
  };

  factory FormReport.fromJson(Map<String, Object?> json) => FormReport(
    endedAt: DateTime.fromMillisecondsSinceEpoch(json['endedAt']! as int),
    opponentName: json['opponentName']! as String,
    roundLength: Duration(milliseconds: json['roundMs']! as int),
    reps: [
      for (final r in json['reps']! as List)
        RepRecord.fromJson((r as Map).cast<String, Object?>()),
    ],
    samples: [
      for (final s in json['samples']! as List)
        FormSample.fromJson((s as Map).cast<String, Object?>()),
    ],
    poses: [
      for (final p in json['poses'] as List? ?? const [])
        FormPose.fromJson((p as Map).cast<String, Object?>()),
    ],
    leftFlarePose: _pose(json['leftFlarePose']),
    rightFlarePose: _pose(json['rightFlarePose']),
    handsPose: _pose(json['handsPose']),
    headPose: _pose(json['headPose']),
  );
}

FormPose? _pose(Object? json) => json == null
    ? null
    : FormPose.fromJson((json as Map).cast<String, Object?>());

double? _double(Object? value) => (value as num?)?.toDouble();
