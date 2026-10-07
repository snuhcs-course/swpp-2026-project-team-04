import 'dart:math' as math;

import '../../models/pose_frame.dart';

/// Measurements from one frame.
///
/// Angles are unchanged by rotating or mirroring the image. Null means the
/// landmarks needed for that value were not reliable.
class PoseMetrics {
  const PoseMetrics({
    this.elbowAngle,
    this.noseY,
    this.shoulderWidth,
    this.tilt,
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
}

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

/// Reads elbow angle, nose height, shoulder width, and shoulder tilt from
/// [frame].
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
  final double? elbow = switch ((left, right)) {
    (final l?, final r?) => (l + r) / 2,
    (final l?, null) => l,
    (null, final r?) => r,
    _ => null,
  };
  final noseY = _usable(nose, minLikelihood) ? nose!.y : null;

  if (!_usable(leftShoulder, minLikelihood) ||
      !_usable(rightShoulder, minLikelihood)) {
    return PoseMetrics(elbowAngle: elbow, noseY: noseY);
  }

  final dx = leftShoulder!.x - rightShoulder!.x;
  final dy = leftShoulder.y - rightShoulder.y;
  return PoseMetrics(
    elbowAngle: elbow,
    noseY: noseY,
    shoulderWidth: math.sqrt(dx * dx + dy * dy),
    tilt: math.atan2(dy.abs(), dx.abs()) * 180 / math.pi,
  );
}

/// Smooths measurements with a time-constant exponential moving average.
///
/// `alpha = 1 - exp(-dt / tau)`, so a slower camera does not make the value
/// lag more in real time. A missing sample keeps the previous value.
class MetricSmoother {
  MetricSmoother({this.tau = const Duration(milliseconds: 65)});

  final Duration tau;
  double? _elbow;
  double? _noseY;
  double? _shoulderWidth;
  double? _tilt;

  PoseMetrics update(PoseMetrics raw, Duration dt) {
    final alpha = tau.inMicroseconds == 0
        ? 1.0
        : 1 - math.exp(-dt.inMicroseconds / tau.inMicroseconds);
    _elbow = _blend(_elbow, raw.elbowAngle, alpha);
    _noseY = _blend(_noseY, raw.noseY, alpha);
    _shoulderWidth = _blend(_shoulderWidth, raw.shoulderWidth, alpha);
    _tilt = _blend(_tilt, raw.tilt, alpha);
    return PoseMetrics(
      elbowAngle: _elbow,
      noseY: _noseY,
      shoulderWidth: _shoulderWidth,
      tilt: _tilt,
    );
  }

  void reset() {
    _elbow = null;
    _noseY = null;
    _shoulderWidth = null;
    _tilt = null;
  }

  static double? _blend(double? previous, double? sample, double alpha) {
    if (sample == null) return previous;
    if (previous == null) return sample;
    return previous + alpha * (sample - previous);
  }
}
