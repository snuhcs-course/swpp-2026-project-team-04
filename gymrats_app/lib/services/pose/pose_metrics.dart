import 'dart:math' as math;

import '../../models/pose_frame.dart';

/// Measurements from one frame.
///
/// Angles are unchanged by rotating or mirroring the image. Null means the
/// landmarks needed for that value were not reliable.
class PoseMetrics {
  const PoseMetrics({
    this.elbowAngle,
    this.leftElbowAngle,
    this.rightElbowAngle,
    this.noseY,
    this.shoulderWidth,
    this.tilt,
    this.hipY,
    this.torsoDrop,
    this.hipAngle,
    this.kneeHandGap,
    this.hipHandGap,
    this.shoulderY,
    this.leftElbowSpread,
    this.rightElbowSpread,
    this.handSpan,
  });

  /// Shoulder–elbow–wrist angle in degrees. 180 is a straight arm.
  ///
  /// Both arms are averaged when both are visible; otherwise the visible arm
  /// is used.
  final double? elbowAngle;

  /// Vertical position of the nose in the upright image, in pixels. Grows
  /// as the head goes down.
  final double? noseY;

  /// Distance between the shoulders, in pixels. Scales the head drop so the
  /// depth does not depend on how far away the phone is.
  final double? shoulderWidth;

  /// Absolute tilt of the shoulder line away from horizontal, in degrees.
  ///
  /// This is the front-view stand-in for a body line: the hips are hidden
  /// behind the torso, so sag cannot be measured from this camera angle.
  final double? tilt;

  /// Each arm's shoulder–elbow–wrist angle, for the left/right comparison
  /// in the form report. Left and right are the user's own sides.
  final double? leftElbowAngle;
  final double? rightElbowAngle;

  /// Vertical position of the hip midpoint, in pixels. Null when no hip is
  /// visible, which is usual from the front.
  final double? hipY;

  /// How far the hips sit below the shoulders, in shoulder widths. See
  /// [torsoDropOf].
  final double? torsoDrop;

  // AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
  /// Shoulder–hip–knee angle in degrees. 180 is a straight body. Null unless
  /// a full shoulder, hip, and knee are visible on at least one side.
  final double? hipAngle;

  /// Knee midpoint minus wrist midpoint, in shoulder widths. Near 0 means
  /// the knees sit on the same floor line as the hands, as in a knee
  /// push-up. Largely negative means the knees are far behind the hands.
  /// Null unless the knees, a wrist, and both shoulders are visible.
  final double? kneeHandGap;

  /// Hip midpoint minus wrist midpoint, in shoulder widths. Near 0 means
  /// the hips have dropped to the hands. Null unless a hip, a wrist, and
  /// both shoulders are visible.
  final double? hipHandGap;

  /// Vertical position of the shoulder midpoint, in pixels. Null unless
  /// both shoulders are visible.
  final double? shoulderY;

  /// How far each elbow sits outside its own shoulder, in shoulder widths.
  /// Zero when that elbow is tucked toward the chest or has crossed the
  /// midline. Null when it was not seen. This is the horizontal part a
  /// front camera can see, not the 3D angle from the torso.
  final double? leftElbowSpread;
  final double? rightElbowSpread;

  /// Distance between the wrists, in shoulder widths. Null unless both
  /// wrists and both shoulders are visible.
  final double? handSpan;
}

/// Vertical distance from the shoulder midpoint down to the hip midpoint,
/// divided by the shoulder width.
///
/// Seen from a phone on the floor, a body in a plank points at the camera,
/// so the hips sit just behind the shoulders and the value stays small. A
/// standing or wall-leaning body is upright in the image, and the value is
/// about the torso length, over twice the shoulder width.
///
/// Null unless both shoulders and at least one hip are given.
double? torsoDropOf({
  required Keypoint? leftShoulder,
  required Keypoint? rightShoulder,
  required Keypoint? leftHip,
  required Keypoint? rightHip,
}) {
  if (leftShoulder == null || rightShoulder == null) return null;
  final hipY = _midY(leftHip, rightHip);
  if (hipY == null) return null;
  final dx = leftShoulder.x - rightShoulder.x;
  final dy = leftShoulder.y - rightShoulder.y;
  final width = math.sqrt(dx * dx + dy * dy);
  if (width < 1e-6) return null;
  return (hipY - (leftShoulder.y + rightShoulder.y) / 2) / width;
}

/// [point] minus [origin], in units of [width]. Null when any of them is
/// missing.
double? _overWidth(double width, double? point, double? origin) {
  if (point == null || origin == null || width < 1e-6) return null;
  return (point - origin) / width;
}

double? _midY(Keypoint? a, Keypoint? b) => switch ((a, b)) {
  (final a?, final b?) => (a.y + b.y) / 2,
  (final a?, null) => a.y,
  (null, final b?) => b.y,
  _ => null,
};

double? _average(double? a, double? b) => switch ((a, b)) {
  (final a?, final b?) => (a + b) / 2,
  (final a?, null) => a,
  (null, final b?) => b,
  _ => null,
};

/// Angle at [b] between [a], [b], and [c], in degrees. 2D, so it ignores z.
double? angleDegrees(Keypoint? a, Keypoint? b, Keypoint? c) {
  if (a == null || b == null || c == null) return null;
  final ux = a.x - b.x;
  final uy = a.y - b.y;
  final vx = c.x - b.x;
  final vy = c.y - b.y;
  final norm = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
  if (norm < 1e-8) return null;
  final cos = ((ux * vx + uy * vy) / norm).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

bool _usable(Keypoint? keypoint, double minLikelihood) =>
    keypoint != null && keypoint.likelihood >= minLikelihood;

/// Reads elbow angles, nose height, shoulder width, shoulder tilt, and the
/// hip measurements from [frame].
///
/// A landmark below [minLikelihood] is ignored, even if its coordinates sit
/// inside the image.
PoseMetrics measurePose(PoseFrame frame, {double minLikelihood = 0.6}) {
  final nose = frame[BodyLandmark.nose];
  final leftShoulder = frame[BodyLandmark.leftShoulder];
  final rightShoulder = frame[BodyLandmark.rightShoulder];

  double? armAngle(Keypoint? shoulder, Keypoint? elbow, Keypoint? wrist) {
    if (!_usable(shoulder, minLikelihood) ||
        !_usable(elbow, minLikelihood) ||
        !_usable(wrist, minLikelihood)) {
      return null;
    }
    return angleDegrees(shoulder, elbow, wrist);
  }

  final left = armAngle(
    leftShoulder,
    frame[BodyLandmark.leftElbow],
    frame[BodyLandmark.leftWrist],
  );
  final right = armAngle(
    rightShoulder,
    frame[BodyLandmark.rightElbow],
    frame[BodyLandmark.rightWrist],
  );
  final elbow = _average(left, right);
  final noseY = _usable(nose, minLikelihood) ? nose!.y : null;

  Keypoint? usable(BodyLandmark landmark) {
    final keypoint = frame[landmark];
    return _usable(keypoint, minLikelihood) ? keypoint : null;
  }

  final leftHip = usable(BodyLandmark.leftHip);
  final rightHip = usable(BodyLandmark.rightHip);
  final hipAngle = _average(
    angleDegrees(
      usable(BodyLandmark.leftShoulder),
      leftHip,
      usable(BodyLandmark.leftKnee),
    ),
    angleDegrees(
      usable(BodyLandmark.rightShoulder),
      rightHip,
      usable(BodyLandmark.rightKnee),
    ),
  );

  if (!_usable(leftShoulder, minLikelihood) ||
      !_usable(rightShoulder, minLikelihood)) {
    return PoseMetrics(
      elbowAngle: elbow,
      leftElbowAngle: left,
      rightElbowAngle: right,
      noseY: noseY,
      hipY: _midY(leftHip, rightHip),
      hipAngle: hipAngle,
    );
  }

  final dx = leftShoulder!.x - rightShoulder!.x;
  final dy = leftShoulder.y - rightShoulder.y;
  final width = math.sqrt(dx * dx + dy * dy);
  final midX = (leftShoulder.x + rightShoulder.x) / 2;
  double? spread(Keypoint? elbow, Keypoint shoulder) {
    if (!_usable(elbow, minLikelihood) || width < 1e-6) return null;
    final shoulderSide = shoulder.x - midX;
    final elbowSide = elbow!.x - midX;
    if (shoulderSide.abs() < 1e-6) {
      return (elbow.x - shoulder.x).abs() / width;
    }
    if (elbowSide * shoulderSide < 0) return 0;
    final outside = elbowSide.abs() - shoulderSide.abs();
    return outside > 0 ? outside / width : 0;
  }

  final leftWrist = usable(BodyLandmark.leftWrist);
  final rightWrist = usable(BodyLandmark.rightWrist);
  return PoseMetrics(
    elbowAngle: elbow,
    leftElbowAngle: left,
    rightElbowAngle: right,
    noseY: noseY,
    shoulderWidth: width,
    tilt: math.atan2(dy.abs(), dx.abs()) * 180 / math.pi,
    shoulderY: (leftShoulder.y + rightShoulder.y) / 2,
    leftElbowSpread: spread(usable(BodyLandmark.leftElbow), leftShoulder),
    rightElbowSpread: spread(usable(BodyLandmark.rightElbow), rightShoulder),
    handSpan: leftWrist == null || rightWrist == null || width < 1e-6
        ? null
        : (leftWrist.x - rightWrist.x).abs() / width,
    hipY: _midY(leftHip, rightHip),
    kneeHandGap: _overWidth(
      width,
      _midY(usable(BodyLandmark.leftKnee), usable(BodyLandmark.rightKnee)),
      _midY(leftWrist, rightWrist),
    ),
    hipHandGap: _overWidth(
      width,
      _midY(leftHip, rightHip),
      _midY(leftWrist, rightWrist),
    ),
    torsoDrop: torsoDropOf(
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftHip: leftHip,
      rightHip: rightHip,
    ),
    hipAngle: hipAngle,
  );
}

/// Smooths measurements with a time-constant exponential moving average.
///
/// `alpha = 1 - exp(-dt / tau)`, so a slower camera does not make the value
/// lag more in real time. A missing sample keeps the previous value.
///
/// Only the values the rep count depends on are smoothed. The hip values
/// are left out and read raw.
class MetricSmoother {
  MetricSmoother({this.tau = const Duration(milliseconds: 65)});

  final Duration tau;
  double? _elbow;
  double? _noseY;
  double? _shoulderWidth;
  double? _tilt;
  double? _shoulderY;

  PoseMetrics update(PoseMetrics raw, Duration dt) {
    final alpha = tau.inMicroseconds == 0
        ? 1.0
        : 1 - math.exp(-dt.inMicroseconds / tau.inMicroseconds);
    _elbow = _blend(_elbow, raw.elbowAngle, alpha);
    _noseY = _blend(_noseY, raw.noseY, alpha);
    _shoulderWidth = _blend(_shoulderWidth, raw.shoulderWidth, alpha);
    _tilt = _blend(_tilt, raw.tilt, alpha);
    _shoulderY = _blend(_shoulderY, raw.shoulderY, alpha);
    return PoseMetrics(
      elbowAngle: _elbow,
      noseY: _noseY,
      shoulderWidth: _shoulderWidth,
      tilt: _tilt,
      shoulderY: _shoulderY,
    );
  }

  void reset() {
    _elbow = null;
    _noseY = null;
    _shoulderWidth = null;
    _tilt = null;
    _shoulderY = null;
  }

  static double? _blend(double? previous, double? sample, double alpha) {
    if (sample == null) return previous;
    if (previous == null) return sample;
    return previous + alpha * (sample - previous);
  }
}
