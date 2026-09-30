import 'dart:math' as math;

import '../../models/pose_frame.dart';

/// Measurements from one frame.
///
/// Angles and ratios are unchanged by rotating or mirroring the image.
/// Null means the landmarks needed for that value were not reliable.
class PoseMetrics {
  const PoseMetrics({this.elbowAngle, this.spanRatio, this.tilt});

  /// Shoulder–elbow–wrist angle in degrees. 180 is a straight arm.
  ///
  /// Both arms are averaged when both are visible; otherwise the visible arm
  /// is used.
  final double? elbowAngle;

  /// Distance from the shoulder midpoint to the wrist midpoint, divided by
  /// the shoulder width. Smaller means the hands are closer to the shoulders.
  final double? spanRatio;

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

/// Reads elbow angle, span, and shoulder tilt from [frame].
///
/// A landmark below [minLikelihood] is ignored, even if its coordinates sit
/// inside the image.
PoseMetrics measurePose(PoseFrame frame, {double minLikelihood = 0.6}) {
  final leftShoulder = frame[BodyLandmark.leftShoulder];
  final rightShoulder = frame[BodyLandmark.rightShoulder];
  final leftElbow = frame[BodyLandmark.leftElbow];
  final rightElbow = frame[BodyLandmark.rightElbow];
  final leftWrist = frame[BodyLandmark.leftWrist];
  final rightWrist = frame[BodyLandmark.rightWrist];

  double? armAngle(Keypoint? shoulder, Keypoint? elbow, Keypoint? wrist) {
    if (!_usable(shoulder, minLikelihood) ||
        !_usable(elbow, minLikelihood) ||
        !_usable(wrist, minLikelihood)) {
      return null;
    }
    return angleDegrees(shoulder, elbow, wrist);
  }

  final left = armAngle(leftShoulder, leftElbow, leftWrist);
  final right = armAngle(rightShoulder, rightElbow, rightWrist);
  final double? elbow = switch ((left, right)) {
    (final l?, final r?) => (l + r) / 2,
    (final l?, null) => l,
    (null, final r?) => r,
    _ => null,
  };

  if (!_usable(leftShoulder, minLikelihood) ||
      !_usable(rightShoulder, minLikelihood)) {
    return PoseMetrics(elbowAngle: elbow);
  }

  final dx = leftShoulder!.x - rightShoulder!.x;
  final dy = leftShoulder.y - rightShoulder.y;
  final shoulderWidth = math.sqrt(dx * dx + dy * dy);
  final tilt = math.atan2(dy.abs(), dx.abs()) * 180 / math.pi;

  final wrists = [
    if (_usable(leftWrist, minLikelihood)) leftWrist!,
    if (_usable(rightWrist, minLikelihood)) rightWrist!,
  ];
  double? span;
  if (shoulderWidth > 1e-6 && wrists.isNotEmpty) {
    final midX = (leftShoulder.x + rightShoulder.x) / 2;
    final midY = (leftShoulder.y + rightShoulder.y) / 2;
    var wristX = 0.0;
    var wristY = 0.0;
    for (final wrist in wrists) {
      wristX += wrist.x;
      wristY += wrist.y;
    }
    wristX /= wrists.length;
    wristY /= wrists.length;
    final dist = math.sqrt(
      math.pow(wristX - midX, 2) + math.pow(wristY - midY, 2),
    );
    span = dist / shoulderWidth;
  }

  return PoseMetrics(elbowAngle: elbow, spanRatio: span, tilt: tilt);
}

/// Smooths measurements with a time-constant exponential moving average.
///
/// `alpha = 1 - exp(-dt / tau)`, so a slower camera does not make the value
/// lag more in real time. A missing sample keeps the previous value.
class MetricSmoother {
  MetricSmoother({this.tau = const Duration(milliseconds: 65)});

  final Duration tau;
  double? _elbow;
  double? _span;
  double? _tilt;

  PoseMetrics update(PoseMetrics raw, Duration dt) {
    final alpha = tau.inMicroseconds == 0
        ? 1.0
        : 1 - math.exp(-dt.inMicroseconds / tau.inMicroseconds);
    _elbow = _blend(_elbow, raw.elbowAngle, alpha);
    _span = _blend(_span, raw.spanRatio, alpha);
    _tilt = _blend(_tilt, raw.tilt, alpha);
    return PoseMetrics(elbowAngle: _elbow, spanRatio: _span, tilt: _tilt);
  }

  void reset() {
    _elbow = null;
    _span = null;
    _tilt = null;
  }

  static double? _blend(double? previous, double? sample, double alpha) {
    if (sample == null) return previous;
    if (previous == null) return sample;
    return previous + alpha * (sample - previous);
  }
}
