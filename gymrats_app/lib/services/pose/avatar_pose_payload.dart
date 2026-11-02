import 'dart:math' as math;

import '../../models/pose_frame.dart';

/// ML Kit image coordinates, NOT metric world coordinates. Use the same width
/// for x/y/z to preserve directions and aspect ratio. The renderer only uses
/// relative vectors; hip centering avoids large image-space offsets. Preserve
/// the original hip position separately for screen-relative root translation.
Map<String, Object?> avatarPosePayload(
  PoseFrame? frame, {
  required bool mirror,
}) {
  if (frame == null ||
      !frame.hasPerson ||
      !frame.imageWidth.isFinite ||
      !frame.imageHeight.isFinite ||
      frame.imageWidth <= 0 ||
      frame.imageHeight <= 0) {
    return {'landmarks': null, 'screenAnchor': null, 'mirror': mirror};
  }
  final left = frame[BodyLandmark.leftHip];
  final right = frame[BodyLandmark.rightHip];
  final cx = left != null && right != null ? (left.x + right.x) / 2 : 0.0;
  final cy = left != null && right != null ? (left.y + right.y) / 2 : 0.0;
  final cz = left != null && right != null ? (left.z + right.z) / 2 : 0.0;
  final width = frame.imageWidth;
  return {
    'mirror': mirror,
    'screenAnchor':
        left != null &&
            right != null &&
            cx.isFinite &&
            cy.isFinite &&
            left.likelihood.isFinite &&
            right.likelihood.isFinite &&
            left.likelihood >= .6 &&
            right.likelihood >= .6 &&
            cx >= 0 &&
            cx <= width &&
            cy >= 0 &&
            cy <= frame.imageHeight
        ? {
            'x': cx / width,
            'y': cy / frame.imageHeight,
            'imageAspect': width / frame.imageHeight,
          }
        : null,
    'landmarks': [
      for (final landmark in BodyLandmark.values)
        if (frame[landmark] case final point?
            when point.x.isFinite &&
                point.y.isFinite &&
                point.z.isFinite &&
                point.likelihood.isFinite &&
                cx.isFinite &&
                cy.isFinite &&
                cz.isFinite)
          {
            'x': (point.x - cx) / width,
            'y': (point.y - cy) / width,
            'z': (point.z - cz) / width,
            'visibility': point.likelihood.clamp(0.0, 1.0),
          }
        else
          null,
    ],
  };
}

/// Tracks how far the user has lowered their shoulders relative to an
/// automatically calibrated "top" position.
///
/// Depth is the shoulder midpoint's downward image-y displacement from the
/// reference, divided by the reference shoulder width. Returns `null` for
/// frames without reliable shoulders and while the initial top is being
/// calibrated, and a smoothed depth >= 0 otherwise.
class ShoulderDepthTracker {
  ShoulderDepthTracker();

  static const double minLikelihood = 0.6;
  static const double minShoulderWidth = 10;

  /// Calibration needs this many stable samples spread over this long.
  static const int calibrationMinSamples = 5;
  static const Duration calibrationMinSpan = Duration(milliseconds: 450);
  static const Duration calibrationWindow = Duration(milliseconds: 1500);

  /// Samples within these tolerances of the median count as stable.
  static const double calibrationYTolerance = 0.1; // of median width
  static const double calibrationWidthTolerance = 0.15; // of median width

  /// Without a valid frame for longer than this, the baseline is discarded.
  static const Duration lossTimeout = Duration(seconds: 1);

  /// Depth changes smaller than this are treated as stationary jitter.
  static const double deadzone = 0.03;
  static const double maxDepth = 1.5;

  /// Smoothing time constant and the largest step fed to the filter.
  static const double smoothingTau = 0.08; // seconds
  static const double maxFilterDt = 0.1; // seconds

  /// Baseline drift: only after the user has stayed near the top this long,
  /// and then only slowly.
  static const double driftNearBaseline = 0.08; // of reference width
  static const double driftMaxDepth = 0.05;
  static const Duration driftStableTime = Duration(seconds: 1);
  static const double driftTimeConstant = 5.0; // seconds

  /// Causal median over this many reliable samples rejects isolated spikes.
  static const int medianWindow = 3;

  final List<_Sample> _calibration = [];
  final List<double> _medianY = [];
  final List<double> _medianWidth = [];

  double? _refY;
  double? _refWidth;
  double _depth = 0;
  Duration? _lastTime;
  Duration? _lastValidTime;
  Duration _stableNearTop = Duration.zero;

  bool get isCalibrated => _refY != null;
  double? get referenceY => _refY;
  double? get referenceWidth => _refWidth;

  void reset() {
    _calibration.clear();
    _refY = null;
    _refWidth = null;
    _depth = 0;
    _lastTime = null;
    _lastValidTime = null;
    _stableNearTop = Duration.zero;
    _medianY.clear();
    _medianWidth.clear();
  }

  double? update(PoseFrame? frame, Duration now) {
    var dt = Duration.zero;
    final last = _lastTime;
    if (last != null && now > last) dt = now - last;
    if (last == null || now > last) _lastTime = now;

    final lastValid = _lastValidTime;
    if (lastValid != null && now - lastValid > lossTimeout) {
      reset();
      _lastTime = now;
    }

    final shoulders = _reliableShoulders(frame);
    if (shoulders == null) return null;
    final (rawY, rawWidth) = shoulders;
    _lastValidTime = now;

    final refY = _refY;
    final refWidth = _refWidth;
    if (refY == null || refWidth == null) {
      if (!_isPushUpSetup(frame!, rawY, rawWidth)) {
        _calibration.clear();
        return null;
      }
      return _calibrate(rawY, rawWidth, now) ? 0.0 : null;
    }

    final (y, width) = _filtered(rawY, rawWidth);

    final raw = ((y - refY) / refWidth).clamp(0.0, maxDepth);
    final target = raw < deadzone ? 0.0 : raw;

    final dtSec = math.min(dt.inMicroseconds / 1e6, maxFilterDt);
    final alpha = 1 - math.exp(-dtSec / smoothingTau);
    _depth += (target - _depth) * alpha;
    if (_depth < 0.005) _depth = 0;

    _maybeDrift(y, width, dt, dtSec);
    return _depth;
  }

  /// Pushes a reliable sample and returns the median of the last
  /// [medianWindow] samples, so one-frame outliers never reach the filter.
  (double, double) _filtered(double y, double width) {
    _medianY.add(y);
    _medianWidth.add(width);
    while (_medianY.length > medianWindow) {
      _medianY.removeAt(0);
      _medianWidth.removeAt(0);
    }
    return (_median(_medianY), _median(_medianWidth));
  }

  /// Fills the median buffer with the reference so the first spike after
  /// calibration is outvoted.
  void _seedMedian(double y, double width) {
    _medianY
      ..clear()
      ..addAll(List.filled(medianWindow - 1, y));
    _medianWidth
      ..clear()
      ..addAll(List.filled(medianWindow - 1, width));
  }

  (double, double)? _reliableShoulders(PoseFrame? frame) {
    if (frame == null || !frame.hasPerson) return null;
    final l = frame[BodyLandmark.leftShoulder];
    final r = frame[BodyLandmark.rightShoulder];
    if (l == null || r == null) return null;
    if (!_usable(l) || !_usable(r)) return null;
    final width = math.sqrt(
      (l.x - r.x) * (l.x - r.x) + (l.y - r.y) * (l.y - r.y),
    );
    if (!width.isFinite || width < minShoulderWidth) return null;
    return ((l.y + r.y) / 2, width);
  }

  /// Avoid using a standing or approaching person as the push-up top. In a
  /// ready plank the wrists are below the shoulders, and wrists and ankles
  /// are at roughly the same image height. No elbow angle is used.
  bool _isPushUpSetup(PoseFrame frame, double shoulderY, double width) {
    final lw = frame[BodyLandmark.leftWrist];
    final rw = frame[BodyLandmark.rightWrist];
    final la = frame[BodyLandmark.leftAnkle];
    final ra = frame[BodyLandmark.rightAnkle];
    if (lw == null ||
        rw == null ||
        la == null ||
        ra == null ||
        !_usable(lw) ||
        !_usable(rw) ||
        !_usable(la) ||
        !_usable(ra)) {
      return false;
    }
    final wristY = (lw.y + rw.y) / 2;
    final ankleY = (la.y + ra.y) / 2;
    return wristY - shoulderY > width * 0.15 &&
        (wristY - ankleY).abs() < width * 1.2;
  }

  bool _usable(Keypoint k) =>
      k.x.isFinite &&
      k.y.isFinite &&
      k.likelihood.isFinite &&
      k.likelihood >= minLikelihood;

  /// Adds a sample; returns true once a stable top has been established.
  bool _calibrate(double y, double width, Duration now) {
    _calibration
      ..add(_Sample(now, y, width))
      ..removeWhere((s) => now - s.time > calibrationWindow || s.time > now);
    if (_calibration.length < calibrationMinSamples) return false;

    final medY = _median(_calibration.map((s) => s.y));
    final medW = _median(_calibration.map((s) => s.width));
    final inliers = _calibration
        .where(
          (s) =>
              (s.y - medY).abs() <= calibrationYTolerance * medW &&
              (s.width - medW).abs() <= calibrationWidthTolerance * medW,
        )
        .toList();
    if (inliers.length < calibrationMinSamples) return false;

    var first = inliers.first.time;
    var lastT = inliers.first.time;
    for (final s in inliers) {
      if (s.time < first) first = s.time;
      if (s.time > lastT) lastT = s.time;
    }
    if (lastT - first < calibrationMinSpan) return false;

    _refY = _median(inliers.map((s) => s.y));
    _refWidth = _median(inliers.map((s) => s.width));
    _depth = 0;
    _stableNearTop = Duration.zero;
    _calibration.clear();
    _seedMedian(_refY!, _refWidth!);
    return true;
  }

  /// Lets the top baseline follow slow posture/camera changes, but only after
  /// sustained data close to the current baseline and never during a hold.
  void _maybeDrift(double y, double width, Duration dt, double dtSec) {
    final refY = _refY!;
    final refWidth = _refWidth!;
    final near =
        (y - refY).abs() <= driftNearBaseline * refWidth &&
        (width - refWidth).abs() <= calibrationWidthTolerance * refWidth;
    if (!near || _depth > driftMaxDepth) {
      _stableNearTop = Duration.zero;
      return;
    }
    _stableNearTop += dt;
    if (_stableNearTop < driftStableTime) return;
    final k = math.min(1.0, dtSec / driftTimeConstant);
    _refY = refY + (y - refY) * k;
    _refWidth = refWidth + (width - refWidth) * k;
  }

  static double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

class _Sample {
  const _Sample(this.time, this.y, this.width);

  final Duration time;
  final double y;
  final double width;
}

/// Visual-only image-plane knee height estimate, separately per leg.
class LiveKneeTracker {
  final _left = _KneeFilter();
  final _right = _KneeFilter();
  double get left => _left.amount;
  double get right => _right.amount;

  void reset() {
    _left.reset();
    _right.reset();
  }

  void update(PoseFrame? frame, Duration now, {bool readyForBaseline = false}) {
    bool usable(Keypoint? p) =>
        p != null &&
        p.x.isFinite &&
        p.y.isFinite &&
        p.likelihood.isFinite &&
        p.likelihood >= .6;
    final ls = frame?[BodyLandmark.leftShoulder];
    final rs = frame?[BodyLandmark.rightShoulder];
    final lw = frame?[BodyLandmark.leftWrist];
    final rw = frame?[BodyLandmark.rightWrist];
    double? width;
    if (usable(ls) && usable(rs)) {
      width = math.sqrt(math.pow(ls!.x - rs!.x, 2) + math.pow(ls.y - rs.y, 2));
      if (width < 10) width = null;
    }
    final wrists = [lw, rw].where(usable).cast<Keypoint>().toList();
    final wristY = wrists.isEmpty
        ? null
        : wrists.map((p) => p.y).reduce((a, b) => a + b) / wrists.length;
    double? gap(BodyLandmark side) {
      final knee = frame?[side];
      if (!usable(knee) || width == null || wristY == null) return null;
      return (knee!.y - wristY) / width;
    }

    _left.update(gap(BodyLandmark.leftKnee), now, readyForBaseline);
    _right.update(gap(BodyLandmark.rightKnee), now, readyForBaseline);
  }
}

class _KneeFilter {
  Duration? _lastReliable;
  Duration? _lastUpdate;
  double amount = 0;
  double? _baseline;
  final _samples = <double>[];
  Duration? _start;
  void reset() {
    _lastReliable = null;
    _lastUpdate = null;
    amount = 0;
    _baseline = null;
    _samples.clear();
    _start = null;
  }

  void update(double? gap, Duration now, bool readyForBaseline) {
    final previous = _lastUpdate;
    final seconds = previous == null
        ? 0.0
        : ((now - previous).inMicroseconds / 1e6).clamp(0.0, .25);
    _lastUpdate = now;
    if (gap == null || !gap.isFinite) {
      if (_lastReliable == null ||
          now - _lastReliable! > const Duration(seconds: 1)) {
        amount *= math.exp(-seconds / .35);
        if (amount < .005) amount = 0;
      }
      return;
    }
    _lastReliable = now;
    if (_baseline == null) {
      if (!readyForBaseline) {
        _samples.clear();
        _start = null;
        return;
      }
      _start ??= now;
      _samples.add(gap);
      if (_samples.length > 15) _samples.removeAt(0);
      if (_samples.length >= 5 &&
          now - _start! >= const Duration(milliseconds: 400)) {
        final sorted = [..._samples]..sort();
        _baseline = sorted[sorted.length ~/ 2];
        _samples.clear();
      }
      return;
    }
    // Ignore ordinary landmark jitter near this person's straight-leg setup.
    final target = ((gap - _baseline! - .18) / .35).clamp(0.0, 1.0);
    final alpha = 1 - math.exp(-seconds / .20);
    amount += (target - amount) * alpha;
  }
}
