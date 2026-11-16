import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../models/pose_frame.dart';
import '../../models/rep_event.dart';

/// Image-based support estimates for the live knee diagnostic.
enum KneeContactState { touching, lifted, unknown }

enum KneeContactIssue {
  none,
  missingReference,
  missingJoints,
  ambiguous,
  outsideReference,
  stabilizing,
}

enum KneeCalibrationIssue {
  none,
  noVisiblePose,
  insufficientSamples,
  unstable,
  invalidTarget,
}

class KneeContactSideReading {
  const KneeContactSideReading({
    this.state = KneeContactState.unknown,
    this.issue = KneeContactIssue.none,
    this.missingJoints = const [],
    this.clearance,
    this.kneeAngle,
  });

  final KneeContactState state;
  final KneeContactIssue issue;
  final List<BodyLandmark> missingJoints;

  /// Signed knee distance from the wrist–ankle line, divided by its length.
  /// Positive points toward the shoulder. This is an image-space proxy,
  /// not a measured distance from the physical floor.
  final double? clearance;
  final double? kneeAngle;
}

class KneeContactReading {
  const KneeContactReading({
    this.left = const KneeContactSideReading(),
    this.right = const KneeContactSideReading(),
  });

  final KneeContactSideReading left;
  final KneeContactSideReading right;

  KneeContactState get state {
    if (left.state == KneeContactState.touching ||
        right.state == KneeContactState.touching) {
      return KneeContactState.touching;
    }
    if (left.state == KneeContactState.lifted &&
        right.state == KneeContactState.lifted) {
      return KneeContactState.lifted;
    }
    return KneeContactState.unknown;
  }
}

/// Compares live 2D joints with two postures labelled by the current user.
///
/// The same camera position must be used for both references and the test.
/// It needs no completed repetition. It estimates similarity to the user's
/// knee-up/knee-down postures, rather than measuring physical floor contact.
/// Missing, ambiguous, or unfamiliar positions remain unknown. A new verdict
/// needs three samples spanning 250 ms. Camera changes must clear calibration.
class KneeContactTracker {
  final _left = _KneeContactHold();
  final _right = _KneeContactHold();
  final _samples = Queue<_KneeContactSample>();
  final _references = <KneeContactState, (_KneeReference, _KneeReference)>{};
  Duration? _lastAt;
  double? _imageWidth;
  double? _imageHeight;
  KneeCalibrationIssue _lastCalibrationIssue = KneeCalibrationIssue.none;

  KneeCalibrationIssue get lastCalibrationIssue => _lastCalibrationIssue;

  bool get hasLiftedReference =>
      _references.containsKey(KneeContactState.lifted);
  bool get hasTouchingReference =>
      _references.containsKey(KneeContactState.touching);

  /// At least one side differs more than its observed calibration noise.
  bool get hasSeparableReferences {
    final up = _references[KneeContactState.lifted];
    final down = _references[KneeContactState.touching];
    if (up == null || down == null) return false;
    return _KneeComparison(up.$1, down.$1).isSeparable ||
        _KneeComparison(up.$2, down.$2).isSeparable;
  }

  KneeContactReading update(PoseFrame frame, Duration at) {
    if (frame.imageWidth.isFinite &&
        frame.imageHeight.isFinite &&
        frame.imageWidth > 0 &&
        frame.imageHeight > 0) {
      if (_imageWidth != null &&
          (_imageWidth != frame.imageWidth ||
              _imageHeight != frame.imageHeight)) {
        resetCalibration();
      }
      _imageWidth = frame.imageWidth;
      _imageHeight = frame.imageHeight;
    }
    final previous = _lastAt;
    if (previous != null &&
        (at < previous || at - previous > const Duration(milliseconds: 750))) {
      reset();
    }
    _lastAt = at;
    final leftFeatures = _kneeContactFeatures(frame, true);
    final rightFeatures = _kneeContactFeatures(frame, false);
    if (leftFeatures != null && rightFeatures != null && previous != at) {
      _samples.add(_KneeContactSample(at, leftFeatures, rightFeatures));
    }
    while (_samples.isNotEmpty &&
        at - _samples.first.at > const Duration(milliseconds: 1200)) {
      _samples.removeFirst();
    }
    final leftRaw = _measureKneeContact(frame, true);
    final rightRaw = _measureKneeContact(frame, false);
    final (leftState, leftIssue) = _classify(leftFeatures, true);
    final (rightState, rightIssue) = _classify(rightFeatures, false);
    return KneeContactReading(
      left: _left.update(
        KneeContactSideReading(
          state: leftState,
          issue: leftIssue,
          missingJoints: leftFeatures == null
              ? _missingKneeContactJoints(frame, true)
              : const [],
          clearance: leftRaw.clearance,
          kneeAngle: leftRaw.kneeAngle,
        ),
        at,
      ),
      right: _right.update(
        KneeContactSideReading(
          state: rightState,
          issue: rightIssue,
          missingJoints: rightFeatures == null
              ? _missingKneeContactJoints(frame, false)
              : const [],
          clearance: rightRaw.clearance,
          kneeAngle: rightRaw.kneeAngle,
        ),
        at,
      ),
    );
  }

  /// Saves a stable recent posture. False preserves existing references.
  bool calibrate(KneeContactState target) {
    if (target == KneeContactState.unknown) {
      _lastCalibrationIssue = KneeCalibrationIssue.invalidTarget;
      return false;
    }
    if (_samples.isEmpty || _samples.last.at != _lastAt) {
      _lastCalibrationIssue = KneeCalibrationIssue.noVisiblePose;
      return false;
    }
    if (_samples.length < 5 ||
        _samples.last.at - _samples.first.at <
            const Duration(milliseconds: 750)) {
      _lastCalibrationIssue = KneeCalibrationIssue.insufficientSamples;
      return false;
    }
    final left = _KneeReference.from(_samples.map((s) => s.left).toList());
    final right = _KneeReference.from(_samples.map((s) => s.right).toList());
    if (left.radius > .20 || right.radius > .20) {
      _lastCalibrationIssue = KneeCalibrationIssue.unstable;
      return false;
    }
    _references[target] = (left, right);
    _lastCalibrationIssue = KneeCalibrationIssue.none;
    reset();
    return true;
  }

  (KneeContactState, KneeContactIssue) _classify(
    List<double>? features,
    bool left,
  ) {
    if (features == null) {
      return (KneeContactState.unknown, KneeContactIssue.missingJoints);
    }
    final touching = _references[KneeContactState.touching];
    final lifted = _references[KneeContactState.lifted];
    if (touching == null || lifted == null) {
      return (KneeContactState.unknown, KneeContactIssue.missingReference);
    }
    final down = left ? touching.$1 : touching.$2;
    final up = left ? lifted.$1 : lifted.$2;
    final comparison = _KneeComparison(up, down);
    if (!comparison.isSeparable) {
      return (KneeContactState.unknown, KneeContactIssue.ambiguous);
    }
    final position = comparison.position(features);
    if ((position - comparison.gap / 2).abs() <= comparison.deadband) {
      return (KneeContactState.unknown, KneeContactIssue.ambiguous);
    }
    final downDistance = _kneeFeatureDistance(features, down.center);
    final upDistance = _kneeFeatureDistance(features, up.center);
    final separation = _kneeFeatureDistance(down.center, up.center);
    final isDown = position > comparison.gap / 2;
    final winner = isDown ? down : up;
    final distance = isDown ? downDistance : upDistance;
    final support = math.max(.12, math.max(separation * .7, winner.radius * 3));
    if (distance > support) {
      return (KneeContactState.unknown, KneeContactIssue.outsideReference);
    }
    return (
      isDown ? KneeContactState.touching : KneeContactState.lifted,
      KneeContactIssue.none,
    );
  }

  void reset() {
    _left.reset();
    _right.reset();
    _samples.clear();
    _lastAt = null;
  }

  void resetCalibration() {
    _references.clear();
    _lastCalibrationIssue = KneeCalibrationIssue.none;
    reset();
  }
}

class _KneeContactSample {
  const _KneeContactSample(this.at, this.left, this.right);
  final Duration at;
  final List<double> left;
  final List<double> right;
}

class _KneeReference {
  const _KneeReference(this.center, this.radius, this.samples);
  factory _KneeReference.from(List<List<double>> samples) {
    final center = List<double>.filled(6, 0);
    for (final sample in samples) {
      for (var i = 0; i < center.length; i++) {
        center[i] += sample[i] / samples.length;
      }
    }
    final radius = samples
        .map((s) => _kneeFeatureDistance(s, center))
        .reduce(math.max);
    return _KneeReference(center, radius, samples);
  }
  final List<double> center;
  final double radius;
  final List<List<double>> samples;

  double projectedNoise(List<double> axis) {
    var squared = 0.0;
    for (final sample in samples) {
      var projection = 0.0;
      for (var i = 0; i < center.length; i++) {
        projection += (sample[i] - center[i]) * axis[i];
      }
      squared += projection * projection;
    }
    return math.sqrt(squared / samples.length);
  }
}

/// Compares the reference separation with noise along that same direction.
/// Unrelated joint jitter does not erase a small, consistent knee movement.
class _KneeComparison {
  factory _KneeComparison(_KneeReference up, _KneeReference down) {
    final gap =
        _kneeFeatureDistance(up.center, down.center) *
        math.sqrt(up.center.length);
    final axis = [
      for (var i = 0; i < up.center.length; i++)
        gap > 0 ? (down.center[i] - up.center[i]) / gap : 0.0,
    ];
    final noise = math.max(up.projectedNoise(axis), down.projectedNoise(axis));
    // Prototype sensitivity in shoulder-width units. The floor and two-sigma
    // margin are heuristics; they do not establish physical contact accuracy.
    final deadband = math.max(.02, noise * 2);
    return _KneeComparison._(up.center, axis, gap, deadband);
  }

  const _KneeComparison._(this.origin, this.axis, this.gap, this.deadband);

  final List<double> origin;
  final List<double> axis;
  final double gap;
  final double deadband;

  bool get isSeparable => gap > deadband * 2;

  /// The two reference centers map to zero and [gap] respectively.
  double position(List<double> features) {
    var projected = 0.0;
    for (var i = 0; i < axis.length; i++) {
      projected += (features[i] - origin[i]) * axis[i];
    }
    return projected;
  }
}

double _kneeFeatureDistance(List<double> a, List<double> b) {
  var squared = 0.0;
  for (var i = 0; i < a.length; i++) {
    squared += (a[i] - b[i]) * (a[i] - b[i]);
  }
  return math.sqrt(squared / a.length);
}

Keypoint? _contactPoint(PoseFrame frame, BodyLandmark landmark) {
  final p = frame[landmark];
  if (!frame.imageWidth.isFinite ||
      !frame.imageHeight.isFinite ||
      frame.imageWidth <= 0 ||
      frame.imageHeight <= 0 ||
      p == null ||
      !p.likelihood.isFinite ||
      p.likelihood < .65 ||
      !p.x.isFinite ||
      !p.y.isFinite ||
      p.x < 0 ||
      p.x > frame.imageWidth ||
      p.y < 0 ||
      p.y > frame.imageHeight) {
    return null;
  }
  return p;
}

List<double>? _kneeContactFeatures(PoseFrame frame, bool left) {
  final leftShoulder = _contactPoint(frame, BodyLandmark.leftShoulder);
  final rightShoulder = _contactPoint(frame, BodyLandmark.rightShoulder);
  final wrist = _contactPoint(
    frame,
    left ? BodyLandmark.leftWrist : BodyLandmark.rightWrist,
  );
  final hip = _contactPoint(
    frame,
    left ? BodyLandmark.leftHip : BodyLandmark.rightHip,
  );
  final knee = _contactPoint(
    frame,
    left ? BodyLandmark.leftKnee : BodyLandmark.rightKnee,
  );
  final ankle = _contactPoint(
    frame,
    left ? BodyLandmark.leftAnkle : BodyLandmark.rightAnkle,
  );
  if (leftShoulder == null ||
      rightShoulder == null ||
      wrist == null ||
      hip == null ||
      knee == null ||
      ankle == null) {
    return null;
  }
  final dx = rightShoulder.x - leftShoulder.x;
  final dy = rightShoulder.y - leftShoulder.y;
  final width = math.sqrt(dx * dx + dy * dy);
  if (width <
      math.max(15, math.min(frame.imageWidth, frame.imageHeight) * .025)) {
    return null;
  }
  return [
    for (final point in [hip, knee, ankle]) ...[
      (point.x - wrist.x) / width,
      (point.y - wrist.y) / width,
    ],
  ];
}

List<BodyLandmark> _missingKneeContactJoints(PoseFrame frame, bool left) => [
  for (final landmark in [
    BodyLandmark.leftShoulder,
    BodyLandmark.rightShoulder,
    left ? BodyLandmark.leftWrist : BodyLandmark.rightWrist,
    left ? BodyLandmark.leftHip : BodyLandmark.rightHip,
    left ? BodyLandmark.leftKnee : BodyLandmark.rightKnee,
    left ? BodyLandmark.leftAnkle : BodyLandmark.rightAnkle,
  ])
    if (_contactPoint(frame, landmark) == null) landmark,
];

class _KneeContactHold {
  KneeContactState _candidate = KneeContactState.unknown;
  Duration? _since;
  Duration? _lastAt;
  int _samples = 0;

  KneeContactSideReading update(KneeContactSideReading raw, Duration at) {
    if (raw.state == KneeContactState.unknown || raw.state != _candidate) {
      _candidate = raw.state;
      _since = at;
      _samples = 0;
    }
    if (_lastAt != at) _samples++;
    _lastAt = at;
    final stable =
        _samples >= 3 &&
        at - (_since ?? at) >= const Duration(milliseconds: 250);
    return KneeContactSideReading(
      state: stable ? raw.state : KneeContactState.unknown,
      issue: raw.state != KneeContactState.unknown && !stable
          ? KneeContactIssue.stabilizing
          : raw.issue,
      missingJoints: raw.missingJoints,
      clearance: raw.clearance,
      kneeAngle: raw.kneeAngle,
    );
  }

  void reset() {
    _candidate = KneeContactState.unknown;
    _since = null;
    _lastAt = null;
    _samples = 0;
  }
}

KneeContactSideReading _measureKneeContact(PoseFrame frame, bool left) {
  final shoulder = _contactPoint(
    frame,
    left ? BodyLandmark.leftShoulder : BodyLandmark.rightShoulder,
  );
  final wrist = _contactPoint(
    frame,
    left ? BodyLandmark.leftWrist : BodyLandmark.rightWrist,
  );
  final hip = _contactPoint(
    frame,
    left ? BodyLandmark.leftHip : BodyLandmark.rightHip,
  );
  final knee = _contactPoint(
    frame,
    left ? BodyLandmark.leftKnee : BodyLandmark.rightKnee,
  );
  final ankle = _contactPoint(
    frame,
    left ? BodyLandmark.leftAnkle : BodyLandmark.rightAnkle,
  );
  if (shoulder == null ||
      wrist == null ||
      hip == null ||
      knee == null ||
      ankle == null) {
    return const KneeContactSideReading();
  }

  final angle = angleDegrees(hip, knee, ankle);
  final dx = ankle.x - wrist.x;
  final dy = ankle.y - wrist.y;
  final lengthSquared = dx * dx + dy * dy;
  final minimum = math.max(
    30.0,
    math.min(frame.imageWidth, frame.imageHeight) * .05,
  );
  if (lengthSquared < minimum * minimum) {
    return KneeContactSideReading(kneeAngle: angle);
  }
  double across(Keypoint p) =>
      (dx * (p.y - wrist.y) - dy * (p.x - wrist.x)) / lengthSquared;
  final shoulderHeight = across(shoulder);
  return KneeContactSideReading(
    clearance: shoulderHeight.abs() < .01
        ? null
        : across(knee) * shoulderHeight.sign,
    kneeAngle: angle,
  );
}

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
    this.handsBelowShoulders = false,
    this.tilt,
    this.hipY,
    this.torsoDrop,
    this.hipAngle,
    this.kneeHandGap,
    this.ankleKneeGap,
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

  /// Both wrists are visible below the shoulder midpoint in the upright image.
  final bool handsBelowShoulders;

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

  /// Ankle midpoint minus knee midpoint, in shoulder widths. Near 0 means
  /// straight legs, as in a plank. Negative means the ankles sit above the
  /// knees in the image: shins lifted or folded, as in a knee push-up.
  /// Null unless a knee, an ankle, and both shoulders are visible.
  final double? ankleKneeGap;

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
    handsBelowShoulders:
        leftWrist != null &&
        rightWrist != null &&
        width >= 1e-6 &&
        leftWrist.y > leftShoulder.y &&
        rightWrist.y > rightShoulder.y,
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
    ankleKneeGap: _overWidth(
      width,
      _midY(usable(BodyLandmark.leftAnkle), usable(BodyLandmark.rightAnkle)),
      _midY(usable(BodyLandmark.leftKnee), usable(BodyLandmark.rightKnee)),
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

/// Coarse inclination of the phone screen to the floor from its gravity sensor.
enum PushupPhoneBand { unknown, near60, near80 }

PushupPhoneBand pushupPhoneBand(
  double? degrees, {
  PushupPhoneBand previous = PushupPhoneBand.unknown,
}) {
  if (degrees == null || !degrees.isFinite || degrees < 45 || degrees > 90) {
    return PushupPhoneBand.unknown;
  }
  if (previous == PushupPhoneBand.near60 && degrees < 72) return previous;
  if (previous == PushupPhoneBand.near80 && degrees > 68) return previous;
  return degrees < 70 ? PushupPhoneBand.near60 : PushupPhoneBand.near80;
}

/// Screen-plane signals. A fully extended forearm plus upper arm gives the
/// person's local scale even when the shoulders overlap in a side view.
enum PushupSpanSignal {
  elbow,
  weakerElbow,
  elbowDifference,
  shoulderTilt,
  hipAngle,
  kneeAngle,
  handShoulderY,
  handShoulderX,
  hipShoulderY,
  hipShoulderX,
  kneeWristY,
  ankleKneeY,
  hipWristY,
  noseShoulderY,
  wristWidth,
  shoulderWidth,
}

enum PushupSpanStat { low, high, middle, start, bottom, finish }

class _SpanSample {
  const _SpanSample(this.at, this.signals, this.arms);
  final Duration at;
  final List<double?> signals;
  final _SpanArms? arms;
}

typedef _SpanArms = ({
  double weaker,
  double stronger,
  double leftShoulderY,
  double rightShoulderY,
  double leftWristY,
  double rightWristY,
  double length,
});

/// Stores joint spans in two dimensions in an upright image. Distances are
/// relative to the visible arm, independent of crop, resolution and mirroring.
_SpanSample _spanSample(PoseFrame frame, Duration at) {
  Keypoint? joint(BodyLandmark name) {
    final p = frame[name];
    return p != null && p.likelihood >= 0.6 && p.x.isFinite && p.y.isFinite
        ? p
        : null;
  }

  double? length(Keypoint? a, Keypoint? b) {
    if (a == null || b == null) return null;
    final dx = a.x - b.x, dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double? armLength(Keypoint? s, Keypoint? e, Keypoint? w) {
    final upper = length(s, e), lower = length(e, w);
    return upper == null || lower == null ? null : upper + lower;
  }

  final s1 = joint(BodyLandmark.leftShoulder),
      s2 = joint(BodyLandmark.rightShoulder);
  final e1 = joint(BodyLandmark.leftElbow), e2 = joint(BodyLandmark.rightElbow);
  final w1 = joint(BodyLandmark.leftWrist), w2 = joint(BodyLandmark.rightWrist);
  final h1 = joint(BodyLandmark.leftHip), h2 = joint(BodyLandmark.rightHip);
  final k1 = joint(BodyLandmark.leftKnee), k2 = joint(BodyLandmark.rightKnee);
  final a1 = joint(BodyLandmark.leftAnkle), a2 = joint(BodyLandmark.rightAnkle);
  final nose = joint(BodyLandmark.nose);
  final el = angleDegrees(s1, e1, w1), er = angleDegrees(s2, e2, w2);
  final scale = _average(armLength(s1, e1, w1), armLength(s2, e2, w2));
  double? gap(double? a, double? b) {
    if (a == null || b == null || scale == null || scale < 1) return null;
    return (a - b) / scale;
  }

  double? x(Keypoint? a, Keypoint? b) => _average(a?.x, b?.x);
  final wy = _midY(w1, w2), sy = _midY(s1, s2);
  final hy = _midY(h1, h2), ky = _midY(k1, k2);
  final arms = el == null || er == null || scale == null || scale < 2
      ? null
      : (
          weaker: math.min(el, er),
          stronger: math.max(el, er),
          leftShoulderY: s1!.y,
          rightShoulderY: s2!.y,
          leftWristY: w1!.y,
          rightWristY: w2!.y,
          length: scale,
        );
  return _SpanSample(at, [
    _average(el, er),
    el == null || er == null ? null : math.min(el, er),
    el == null || er == null ? null : (el - er).abs(),
    s1 == null || s2 == null || length(s1, s2)! < 1
        ? null
        : math.atan2((s1.y - s2.y).abs(), (s1.x - s2.x).abs()) * 180 / math.pi,
    _average(angleDegrees(s1, h1, k1), angleDegrees(s2, h2, k2)),
    _average(angleDegrees(h1, k1, a1), angleDegrees(h2, k2, a2)),
    gap(wy, sy),
    gap(x(w1, w2), x(s1, s2))?.abs(),
    gap(hy, sy),
    gap(x(h1, h2), x(s1, s2))?.abs(),
    gap(ky, wy),
    gap(_midY(a1, a2), ky),
    gap(hy, wy),
    gap(nose?.y, sy),
    gap(w1?.x, w2?.x)?.abs(),
    gap(s1?.x, s2?.x)?.abs(),
  ], arms);
}

/// At most six seconds of local spans. Stores scalar evidence only.
class PushupSpanHistory {
  final _samples = ListQueue<_SpanSample>();
  void reset() => _samples.clear();

  void add(PoseFrame frame, Duration at) {
    if (_samples.isNotEmpty) {
      final elapsed = at - _samples.last.at;
      if (elapsed.isNegative || elapsed > const Duration(milliseconds: 350)) {
        reset();
      } else if (elapsed < const Duration(milliseconds: 35)) {
        return;
      }
    }
    _samples.add(_spanSample(frame, at));
    while (_samples.isNotEmpty &&
        at - _samples.first.at > const Duration(seconds: 6)) {
      _samples.removeFirst();
    }
  }

  /// A soft rejection may earn points only after an observed top, flexion
  /// in both arms, and a return to extension on the actual closing image.
  /// Both shoulders must descend and rise relative to the image AND hands.
  bool observedReturn(
    PoseFrame frame,
    Duration start,
    Duration end, {
    double lockout = 165,
    double maxBent = 130,
    double travel = .12,
    Duration? notBefore,
  }) {
    final finish = _samples.isNotEmpty && _samples.last.at == end
        ? _samples.last.arms
        : _spanSample(frame, end).arms;
    if (finish == null || finish.weaker < lockout) return false;
    bool lowered(_SpanArms top, _SpanArms bottom) {
      final need = travel * top.length;
      final leftDrop = bottom.leftShoulderY - top.leftShoulderY;
      final rightDrop = bottom.rightShoulderY - top.rightShoulderY;
      return leftDrop >= need &&
          rightDrop >= need &&
          leftDrop - (bottom.leftWristY - top.leftWristY) >= need &&
          rightDrop - (bottom.rightWristY - top.rightWristY) >= need;
    }

    final tops = <_SpanArms>[];
    _SpanArms? bottom, restored;
    for (final sample in _samples) {
      if (sample.at < start || sample.at >= end) continue;
      final arms = sample.arms;
      if (arms == null) continue;
      if (restored != null) {
        final reDescent =
            arms.stronger < lockout - 8 ||
            arms.leftShoulderY - restored.leftShoulderY >
                .06 * restored.length ||
            arms.rightShoulderY - restored.rightShoulderY >
                .06 * restored.length;
        if (reDescent) {
          tops.clear();
          tops.add(restored);
          bottom = restored = null;
        }
      }
      if (arms.weaker >= lockout) tops.add(arms);
      if ((notBefore == null || sample.at >= notBefore) &&
          arms.stronger <= maxBent &&
          tops.any((top) => lowered(top, arms))) {
        bottom = arms;
        restored = null;
      }
      if (restored == null &&
          bottom != null &&
          arms.weaker >= lockout &&
          lowered(arms, bottom)) {
        restored = arms;
      }
    }
    if (restored != null &&
        (finish.leftShoulderY - restored.leftShoulderY >
                .06 * restored.length ||
            finish.rightShoulderY - restored.rightShoulderY >
                .06 * restored.length)) {
      return false;
    }
    return bottom != null && lowered(finish, bottom);
  }

  Duration? primaryWindowStart(Duration end, Duration? previousPrimary) {
    if (_samples.isEmpty) return null;
    var start = end - const Duration(milliseconds: 1600);
    if (start < _samples.first.at) start = _samples.first.at;
    if (previousPrimary != null && previousPrimary > start) {
      start = previousPrimary;
    }
    return start;
  }

  /// Features in enum order, exposed to the offline replay so it trains on
  /// exactly the evidence available at the time the app emits the verdict.
  List<double?>? evidence({
    required Duration start,
    required Duration bottom,
    required Duration end,
    double? phoneAngleDegrees,
  }) {
    if (start >= bottom || bottom >= end || _samples.isEmpty) return null;
    final frames = _samples.where((f) => f.at >= start && f.at <= end).toList();
    if (frames.length < 3 ||
        frames.first.at - start > const Duration(milliseconds: 250)) {
      return null;
    }
    final startEnd = start + (bottom - start) ~/ 3;
    final bottomStart = bottom - (bottom - start) ~/ 3;
    final bottomEnd = bottom + (end - bottom) ~/ 3;
    final finishStart = end - (end - bottom) ~/ 3;

    // A vertical movement projects onto the screen at approximately sin(pitch).
    // This only adjusts distances along screen y, never measured joint angles.
    final yScale = switch (pushupPhoneBand(phoneAngleDegrees)) {
      PushupPhoneBand.near60 => 1.1547005383792517,
      PushupPhoneBand.near80 => 1.0154266118857451,
      PushupPhoneBand.unknown => 1.0,
    };
    final values = <double?>[];
    for (final signal in PushupSpanSignal.values) {
      final projectY = switch (signal) {
        PushupSpanSignal.handShoulderY ||
        PushupSpanSignal.hipShoulderY ||
        PushupSpanSignal.kneeWristY ||
        PushupSpanSignal.ankleKneeY ||
        PushupSpanSignal.hipWristY ||
        PushupSpanSignal.noseShoulderY => true,
        _ => false,
      };
      final all = <double>[],
          top = <double>[],
          down = <double>[],
          back = <double>[];
      for (final f in frames) {
        final raw = f.signals[signal.index];
        if (raw == null) continue;
        final value = projectY ? raw * yScale : raw;
        all.add(value);
        if (f.at <= startEnd) top.add(value);
        if (f.at >= bottomStart && f.at <= bottomEnd) down.add(value);
        if (f.at >= finishStart) back.add(value);
      }
      all.sort();
      double? quantile(List<double> sorted, double p) =>
          sorted.isEmpty ? null : sorted[((sorted.length - 1) * p).round()];
      values.addAll([
        quantile(all, .15),
        quantile(all, .85),
        quantile(all, .5),
        quantile(top..sort(), .5),
        quantile(down..sort(), .5),
        quantile(back..sort(), .5),
      ]);
    }
    return values;
  }

  RejectReason? reasonFor({
    required Duration start,
    required Duration bottom,
    required Duration end,
    double? phoneAngleDegrees,
  }) {
    final values = evidence(
      start: start,
      bottom: bottom,
      end: end,
      phoneAngleDegrees: phoneAngleDegrees,
    );
    return values == null ? null : pushupSpanFeedback(values);
  }
}

/// Feedback from the tree selected on group-separated development recordings.
/// A leaf proposing a normal rep abstains. The primary judge awards reps.
RejectReason? pushupSpanFeedback(List<double?> values) {
  double? observed(PushupSpanSignal signal, PushupSpanStat statistic) =>
      values[signal.index * PushupSpanStat.values.length + statistic.index];
  // Use the same below-range missing value as the fitted tree. Each label
  // additionally requires direct observation of its relevant joints below.
  double value(PushupSpanSignal signal, PushupSpanStat statistic) =>
      observed(signal, statistic) ?? -999;
  RejectReason? classify() {
    if (value(PushupSpanSignal.handShoulderY, PushupSpanStat.low) <= 0.964062) {
      if (value(PushupSpanSignal.weakerElbow, PushupSpanStat.bottom) <=
          159.763618) {
        if (value(PushupSpanSignal.handShoulderX, PushupSpanStat.bottom) <=
            0.127116) {
          if (value(PushupSpanSignal.weakerElbow, PushupSpanStat.low) <=
              116.798538) {
            if (value(PushupSpanSignal.wristWidth, PushupSpanStat.low) <=
                1.323812) {
              if (value(
                    PushupSpanSignal.noseShoulderY,
                    PushupSpanStat.bottom,
                  ) <=
                  0.192277) {
                return RejectReason.insufficientDepth;
              }
              return null;
            }
            return null;
          }
          if (value(PushupSpanSignal.kneeAngle, PushupSpanStat.low) <=
              24.8202) {
            if (value(PushupSpanSignal.elbow, PushupSpanStat.middle) <=
                158.290329) {
              return RejectReason.kneesDown;
            }
            return null;
          }
          if (value(PushupSpanSignal.elbowDifference, PushupSpanStat.high) <=
              28.691241) {
            return RejectReason.insufficientDepth;
          }
          return RejectReason.shouldersNotLevel;
        }
        if (value(PushupSpanSignal.ankleKneeY, PushupSpanStat.start) <=
            -0.006071) {
          if (value(PushupSpanSignal.weakerElbow, PushupSpanStat.start) <=
              153.736923) {
            return RejectReason.incompleteExtension;
          }
          if (value(PushupSpanSignal.hipShoulderX, PushupSpanStat.high) <=
              0.080789) {
            return null;
          }
          return RejectReason.shouldersNotLevel;
        }
        if (value(PushupSpanSignal.kneeWristY, PushupSpanStat.middle) <=
            -0.657224) {
          if (value(PushupSpanSignal.kneeAngle, PushupSpanStat.finish) <=
              124.951843) {
            return null;
          }
          return RejectReason.insufficientDepth;
        }
        return RejectReason.shouldersNotLevel;
      }
      if (value(PushupSpanSignal.hipShoulderX, PushupSpanStat.bottom) <=
          0.084989) {
        if (value(PushupSpanSignal.weakerElbow, PushupSpanStat.low) <=
            146.419411) {
          return RejectReason.insufficientDepth;
        }
        if (value(PushupSpanSignal.hipShoulderY, PushupSpanStat.high) <=
            0.319789) {
          if (value(PushupSpanSignal.shoulderTilt, PushupSpanStat.middle) <=
              1.762552) {
            return RejectReason.kneesDown;
          }
          return RejectReason.insufficientDepth;
        }
        return null;
      }
      return null;
    }
    return null;
  }

  final reason = classify();
  final elbow = observed(PushupSpanSignal.elbow, PushupSpanStat.low);
  final elbowReturn = observed(PushupSpanSignal.elbow, PushupSpanStat.finish);
  final tilt = observed(PushupSpanSignal.shoulderTilt, PushupSpanStat.high);
  final knee = observed(PushupSpanSignal.kneeAngle, PushupSpanStat.low);
  final kneeWrist = observed(PushupSpanSignal.kneeWristY, PushupSpanStat.high);
  final top = observed(PushupSpanSignal.handShoulderY, PushupSpanStat.start);
  final down = observed(PushupSpanSignal.handShoulderY, PushupSpanStat.bottom);
  final hasDirectEvidence = switch (reason) {
    RejectReason.incompleteExtension =>
      elbowReturn != null && elbowReturn < 170,
    RejectReason.shouldersNotLevel => tilt != null && tilt >= 7,
    RejectReason.kneesDown =>
      (knee != null && knee < 150) ||
          (kneeWrist != null && kneeWrist.abs() <= .45),
    RejectReason.armsStraight => elbow != null && elbow > 144,
    RejectReason.insufficientDepth =>
      top != null &&
          down != null &&
          top - down >= .035 &&
          top - down < .49 &&
          elbow != null &&
          elbow > 80 &&
          elbow < 165,
    _ => false,
  };
  return hasDirectEvidence ? reason : null;
}

const _mlpJoints = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28];
const _mlpEdges = [
  (1, 2),
  (3, 4),
  (5, 6),
  (7, 8),
  (9, 10),
  (11, 12),
  (1, 3),
  (2, 4),
  (3, 5),
  (4, 6),
  (1, 7),
  (2, 8),
  (7, 9),
  (8, 10),
  (9, 11),
  (10, 12),
  (1, 5),
  (2, 6),
];

class _MlpFrame {
  const _MlpFrame(this.milliseconds, this.points);
  final int milliseconds;
  final List<double> points;
}

/// The frozen model sees up to 1.6 seconds ending at each accepted proposal.
/// Missing joints stay missing, and the previous proposal bounds the next
/// window. Angle inputs are deliberately absent from this recorded-video model.
class PushupMlpHistory {
  final _frames = ListQueue<_MlpFrame>();
  int? _previousProposal;

  void reset() {
    _frames.clear();
    _previousProposal = null;
  }

  void add(PoseFrame frame, Duration now) {
    final milliseconds = now.inMilliseconds;
    if (_frames.isNotEmpty && milliseconds <= _frames.last.milliseconds) {
      if (milliseconds == _frames.last.milliseconds) return;
      reset();
    }
    final points = List<double>.filled(26, double.nan);
    for (var i = 0; i < _mlpJoints.length; i++) {
      final point = frame[BodyLandmark.values[_mlpJoints[i]]];
      if (point == null ||
          !point.likelihood.isFinite ||
          point.likelihood < .55 ||
          !point.x.isFinite ||
          !point.y.isFinite) {
        continue;
      }
      points[2 * i] = point.x;
      points[2 * i + 1] = point.y;
    }
    _frames.add(_MlpFrame(milliseconds, points));
    while (_frames.isNotEmpty &&
        _frames.first.milliseconds < milliseconds - 1600) {
      _frames.removeFirst();
    }
  }

  /// Exposed for replay parity. Does not advance the last-proposal boundary.
  Float32List featuresAt(Duration now) {
    final end = now.inMilliseconds;
    final start = math.max(end - 1600, (_previousProposal ?? -1) + 1);
    final samples = _frames
        .where((f) => f.milliseconds >= start && f.milliseconds <= end)
        .toList();
    if (samples.isEmpty) {
      samples.add(_MlpFrame(end, List.filled(26, double.nan)));
    }
    return _mlpFeatures(samples);
  }

  /// Extracts one causal proposal window and advances its shared boundary.
  Float32List featuresForProposal(Duration now) {
    final features = featuresAt(now);
    _previousProposal = now.inMilliseconds;
    return features;
  }

  /// Normal probability. The caller owns proposal timing and phone-motion veto.
  double classifyAt(Duration now) =>
      PushupMlpModel.normalProbability(featuresForProposal(now));
}

double _mlpQuantile(Iterable<double> values, double fraction) {
  final ordered = values.where((v) => v.isFinite).toList()..sort();
  if (ordered.isEmpty) return double.nan;
  final position = (ordered.length - 1) * fraction;
  final below = position.floor(), above = position.ceil();
  return ordered[below] +
      (ordered[above] - ordered[below]) * (position - below);
}

double _mlpDistance(List<double> points, int a, int b) {
  final x = points[2 * a] - points[2 * b];
  final y = points[2 * a + 1] - points[2 * b + 1];
  return math.sqrt(x * x + y * y);
}

Float32List _mlpFeatures(List<_MlpFrame> frames) {
  final centres = List.generate(2, (axis) {
    final shoulder = _mlpQuantile(
      frames.expand((f) => [f.points[2 + axis], f.points[4 + axis]]),
      .5,
    );
    return shoulder.isFinite
        ? shoulder
        : _mlpQuantile(
            frames.expand(
              (f) => List.generate(13, (i) => f.points[2 * i + axis]),
            ),
            .5,
          );
  });
  var scale = _mlpQuantile(
    frames.expand((frame) {
      final p = frame.points;
      final x = (p[14] + p[16] - p[2] - p[4]) / 2;
      final y = (p[15] + p[17] - p[3] - p[5]) / 2;
      return [_mlpDistance(p, 1, 2), math.sqrt(x * x + y * y)];
    }),
    .75,
  );
  if (!scale.isFinite || scale < 2) {
    scale = _mlpQuantile(
      frames.expand(
        (f) =>
            _mlpEdges.map((edge) => _mlpDistance(f.points, edge.$1, edge.$2)),
      ),
      .75,
    );
  }
  if (!scale.isFinite || scale < 2) scale = double.nan;
  final mirror =
      _mlpQuantile(frames.map((f) => f.points[4] - f.points[2]), .5) < 0;
  final values = <List<double>>[];
  for (final frame in frames) {
    final row = List<double>.filled(62, double.nan);
    for (var i = 0; i < 13; i++) {
      row[2 * i] =
          (frame.points[2 * i] - centres[0]) / scale * (mirror ? -1 : 1);
      row[2 * i + 1] = (frame.points[2 * i + 1] - centres[1]) / scale;
    }
    for (var i = 0; i < _mlpEdges.length; i++) {
      final (a, b) = _mlpEdges[i];
      row[26 + 2 * i] = row[2 * b] - row[2 * a];
      row[27 + 2 * i] = row[2 * b + 1] - row[2 * a + 1];
    }
    values.add(row);
  }
  final binRows = List.generate(6, (_) => <List<double>>[]);
  final duration = frames.last.milliseconds - frames.first.milliseconds;
  for (var i = 0; i < frames.length; i++) {
    final bin = math.min(
      5,
      (frames[i].milliseconds - frames.first.milliseconds) *
          6 ~/
          (duration + 1),
    );
    binRows[bin].add(values[i]);
  }
  final features = Float32List(466);
  void put(int index, double value) {
    features[index] = value.isNaN ? -7 : value.clamp(-5.0, 5.0);
  }

  for (var bin = 0; bin < 6; bin++) {
    for (var feature = 0; feature < 62; feature++) {
      put(
        bin * 62 + feature,
        _mlpQuantile(binRows[bin].map((v) => v[feature]), .5),
      );
    }
  }
  for (var feature = 0; feature < 62; feature++) {
    final column = values.map((v) => v[feature]);
    put(372 + feature, _mlpQuantile(column, .9) - _mlpQuantile(column, .1));
  }
  for (var joint = 0; joint < 31; joint++) {
    put(
      434 + joint,
      values.where((v) => v[2 * joint].isFinite).length / values.length,
    );
  }
  put(465, duration / 1000);
  return features;
}

/// Dense 466→64→32→1 ReLU/sigmoid network, trained on grouped web footage.
/// Arrays retain the exported float64 scaler and float32 weight precision.
class PushupMlpModel {
  static final _bytes = ByteData.sublistView(base64Decode(_pushupMlpArrays));
  static final _mean = List.generate(
    466,
    (i) => _bytes.getFloat64(i * 8, Endian.little),
  );
  static final _scale = List.generate(
    466,
    (i) => _bytes.getFloat64((466 + i) * 8, Endian.little),
  );
  static final _parameters = Float32List.fromList(
    List.generate(32001, (i) => _bytes.getFloat32(7456 + i * 4, Endian.little)),
  );

  static double normalProbability(List<double> features) {
    final input = _scaledPoseFeatures(features, _mean, _scale);
    final first = _densePoseLayer(input, _parameters, 64, 0, 31904, relu: true);
    final second = _densePoseLayer(
      first,
      _parameters,
      32,
      29824,
      31968,
      relu: true,
    );
    final output = _densePoseLayer(
      second,
      _parameters,
      1,
      31872,
      32000,
      relu: false,
    )[0];
    return 1 / (1 + math.exp(-output));
  }
}

/// Frozen 466→32→16→1 knee-support veto fitted to web and native pose windows.
class PushupKneeModel {
  static const threshold = 0.9204565286636353;
  static final _bytes = ByteData.sublistView(base64Decode(_pushupKneeArrays));
  static final _mean = List.generate(
    466,
    (i) => _bytes.getFloat64(i * 8, Endian.little),
  );
  static final _scale = List.generate(
    466,
    (i) => _bytes.getFloat64((466 + i) * 8, Endian.little),
  );
  static final _parameters = Float32List.fromList(
    List.generate(15489, (i) => _bytes.getFloat32(7456 + i * 4, Endian.little)),
  );

  static double probability(List<double> features) {
    final input = _scaledPoseFeatures(features, _mean, _scale);
    final first = _densePoseLayer(input, _parameters, 32, 0, 15440, relu: true);
    final second = _densePoseLayer(
      first,
      _parameters,
      16,
      14912,
      15472,
      relu: true,
    );
    final output = _densePoseLayer(
      second,
      _parameters,
      1,
      15424,
      15488,
      relu: false,
    )[0];
    return 1 / (1 + math.exp(-output));
  }

  static bool rejects(List<double> features) =>
      probability(features) > threshold;
}

Float32List _scaledPoseFeatures(
  List<double> features,
  List<double> mean,
  List<double> scale,
) {
  if (features.length != 466) {
    throw ArgumentError('Expected 466 pose features');
  }
  final input = Float32List.fromList(features);
  for (var i = 0; i < input.length; i++) {
    // Separate writes reproduce in-place float32 StandardScaler rounding.
    input[i] = input[i] - mean[i];
    input[i] = input[i] / scale[i];
    input[i] = input[i].clamp(-6.0, 6.0);
  }
  return input;
}

Float32List _densePoseLayer(
  Float32List input,
  Float32List parameters,
  int outputs,
  int weightStart,
  int biasStart, {
  required bool relu,
}) {
  final result = Float32List(outputs);
  for (var column = 0; column < outputs; column++) {
    var sum = 0.0;
    for (var row = 0; row < input.length; row++) {
      sum += input[row] * parameters[weightStart + row * outputs + column];
    }
    result[column] = sum;
    result[column] = result[column] + parameters[biasStart + column];
    if (relu && result[column] < 0) result[column] = 0;
  }
  return result;
}

// BEGIN FROZEN PUSHUP MLP ARRAYS
// Source binary-model.npz SHA-256 ef3c99bc3cf8087788658ee528b7142fdcc41f9c89ea54ec64a073765b7b022c
// Float64 mean/scale then float32 W0/W1/W2/b0/b1/b2, little-endian.
// Regenerate with tools/diagnose/export_pushup_mlp_dart.py.
const _pushupMlpArrays =
    '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'
    'yCWcvbJptz1HoCO8musHPk8sdb2ONKA7ek45vdKBUr2x14y9VVSiPXmvpjyc1yK9XsR0vSpOZD3T7Hi9IjLdPXxqnb094EM8XpVr'
    'vSuNyD0h08c9W9eEPfhmu70QogQ8bfF2Pauag70NvD07kRStPF5Z571s6dC9aen9OusGkz2WBso7c+wgO7n+oL1cqB88b+KAvZbL'
    'sL3RnJW94PIGvvXTwz1+IAW9M3DPvUqZvrwNhxu9OssJPRxaFT0bUpI9VmAivRtPyr3tBra9T6QTPDKfzrzMxGw9Q/NuvUXPIr2E'
    'UR0+w2JPvL9ihr1gk4Q9B4LIvQX7dj1W8pS9uOezvBkMiL22pjO9L5Klvc+MCb0kky09mhW5vWqZ1D2dT7U9FXTTPab/iDk6ZNG9'
    'n6EGPgBcPj3fm+q9asGwPFn1i71Io6y9NvAJPZdAs70RkD69ykGtvUIpyb0Bpao9kCDEPbWdnL3hHkq93GipPXYz5LuJnsS9Gopt'
    'PHWSz735m9084f8NvjLjrryfS449G/9jPb39Tr2Z1oS9ry3hPZLmljsriLU7p7QhPRQuGTzWCgG9sdk8PBWgAT3idW696HznvZaw'
    'pD3eur086ONuPWKxyz01qFS8TzU0vZ7BLb1BgRw8lstXPfIJUrz8xCo9c6v1PJLmkz1qgGA9vTIVveHehj0mz+69uZWWPYl5172A'
    'hDA7xME1vXNhQb2Hnxs97pvdvfdkAb6trfy9ZV1gPXqzwL1KYiI+fduBPdhJjr10naU93KI+vDlHFLzxf+m9LjjNvdDNGb2BZ469'
    'Fu4evbkf0Lym0c89xNwavnjBgb2oo6y8ioThvETYAL6WkjC8Dd+SPap+hjyiiPC97tCTvApoLTz0YC490f7svGo/Uj2mL9i9gC3K'
    'vH3csj0I62C99eWlPcjn7D22Hc49Shk3vaEn7r0aIHA9NmpSvW39B77AsAW9jBrOvELbiL2Pu2i8WdidvAYXIj7Umre9ssfGOtoE'
    'zz3hOu+7zOA/vGl23Tpeb6a9ZZW1PRQX2rtXC5E99HJSPNofXzuvCL+94A+hvWO2pLyqBZ49LQllvNk4dj33cEC8BjrZPa/FSr0e'
    'mIw9BZAqvc+9aDwicsE9ts6PPWCi1jw2gwm6ZV53PcA1mblB+gC9pL0xPalgE72FREk99+/cPWsfOzwXe149ecRAvXXPF71j+zI9'
    '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'
    'ZkHUPTfkor0x41M9aCZqO/SKNz1Nqok9Npi8PByxl73rRMQ8HD+IPft49r0xSoW9KJq/PQFnuL2MwJa9R084vUIkQL2c2j491JSN'
    'vOo4rjyL4oE9Nk8KPWpxhb0nfII7hHyPvS5ojT1sG4c9DQ3tOw4MJz3kNoo7YzvAPZFVlD2Ht3k9Exgju1L0cL0ILnk9RtRZPW6H'
    'U73mg7W9hMFZvDZhxL2iSda6jXtjuZV9GDwx6fk9yJfKPXMhwT1/NpQ9vNqgPaPGEjxusAm+OlqbvN9cjby4IBQ9wtCiPY4XgD24'
    'VRm9GyTAPemsBjwYUJS9ME+zPTsmRrwuy0I9G5FFPBPnVb0yvr88GwovvTRr1j1WHbq9wXXwvVrwQr2bQ4o9hcWsvVUXpLw86Oa6'
    '88KKPYteBj0F+6g9BZi2vTnQxzspzX29TrQYvo3bsjwwwt091DgAPuIMa73XWa+9WIe3vHVRK72gGKu9YOAbPfEB0byiBAi8i9mF'
    'Pe8PEbyejq09jcbsvNtgl7uQiJ29Cc03vSrsH7uuoM+9DdLEPf8Up70K5847vV50vX1t7j11IVE9cI/QvBqIDL4QHZE99NurvOSp'
    'Ab6WUmW9ZIEpPe7zh70DE2u7tbmiPdGvEr4EuSi9NrWRu6urX71aTYM8tJmROyFyHDwpGle8uVu7vOqlCj05r3O9OHesPDRXkT3a'
    '3oW9zzCmPT6zmD0nqUI9r4r9vaD7dL2SeW28vIOiPVBUEjwUYC+41wglPYAtQ7x9kAa8rpLjPVtTv7wu+Ck955M2vVgX+jxENRi7'
    'h9GlPUOU2TvwpyS9TVvpPRqlVL3ndI69z8NFPU/Jiz2Cx5q8rnC8PC2ilL2zIee78a+XvSTzuTufkau8VqVzvIqkmTzOsYQ9NvQs'
    'vbNS1T1AQRa97T0jPN+9ND2kcFE9kcQvPLQsOr1cVx49Mk7EPF71Mr0KAfo8b46KvHBz+b1Zzdk7CvMFPZtOXD2wCca8L9iKPSR1'
    'Pr1AgH09DmToO0ObmTmbmUK9h91hPJS6QT1j0JQ9PenEPaqDnTy5v969QoGVu0h6gz0N4Ao7brucvVBAcD1QhXk8SJijPGlaqb2Q'
    'NDW9URIJvWhbrz1CGKO9n52evXsKT71fcdG9Paf2vFOwd7wuLRu9LjomvTVEcj19PI29VJ+6vHgj870Bu2A99nOjvb5fUz1zxbq8'
    'k44jPbmVFz7NmPC8UfiBvVb3Nj2ZHou8hqLkPQoqyD1YUiA9Cmn4PVk9Rr3CR5k9dIkwPUcupD0c3Xk8+usTPDPazj08haQ98iFv'
    'vQFxTr0Ck1C9i+CCPUwAmLyFP8C8NPTFvTzJB71HbgO9vRqivav2UD05upA9J/cxPfmlDD0BD4E86twbPTfRXj02H5m9DL0WPly9'
    'kr3LjhI9nyKEPCNxwz2ezRm9Dkv1PLoUq73dcOC8nbOgPZqJ6z1SZhm9sVhqvTUg07y8T3a5zk/SvUWbKj3ypAW9C2qpPOtWDj22'
    'qpm8dD3JvaChozx+JfQ9EtWXveLJZb1MNCU728+zPPwK1LxYxAw9NzvTPSFlOj0JhJi9O6mUvP0bCLyETZM9NwyHu+Xt0T2J0qY9'
    'S1CLu0ZgyT1H5bM9ShQhPdxHZD26t9w90B5FvTJpkr0jI8g9wHrAvfHjOj0ZNc48jIlPPcRN9T1dbp+9/fHtOzV7k7vRe5a5T9uv'
    'vUYnUT3B69i9BePbuyopvT1Pxwi+Aj+/vR6St72GIx2+u7wXvdppqD0xFYE9ISkivXSUmz14F60969RvPbhU0L0uGtA9avmcPbAE'
    'zzwFBzq9kKmuvQ9u7rziu5W9QcTcOxcApj2qU3W9KiucvWklw7sSptE9M6KmvSnohrxS8Ju9TWNvPZvSkz2cxa08eBgKPvgKW71R'
    'H7e9mdB0Pev3Pz3Kq7K912L+vINiz71iY0q9l7fzvWR1LbwQ75Q8eMw6vVLZsjvP4R+9QznIvF8R3b13HZs9uZyWO72UyT1Uzvq9'
    'ieDNu/9IYL0wlrE93VOePXfMfDvZ1lw8bM5JPWGPoj2qMXm7D2XhPLTllj3H0fE8ZbtRPY5Ngb0jgOI9G2ekuqdlbj03b2o9nvvl'
    'PYtxbr2Yjsg9isVBPSNeqjyALGg9xnZKPanu5jyVcaI9nmilPfX/mT2W4qc9xnybPVXFu7zAJ7a9TouRPURqa7u1uJ89OBZaveIk'
    'Cj6uVli9PZyDvDSk3L0Jtr299LRMvWmOHzvudfM9ZHAQvMnndbyIX4E9eupWPYr3mLyR8oQ8qu+AuwFVvb32Os49VG1xPXy1GT7o'
    'zv09WUnVuxb/tL1eodq9qrGnPUxsUz0HlV495EAKva7pljxV5m+8SHKCvc0ou7zKcvu895T/vLNj17uOvCg8X2v0ve1kiDsqyQm9'
    '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'
    'sX6oPbWD0717kkA9vD++vTgCTL0tc7y9/P0jPVLPv71Agtw80FHuPdIbwLsvaZ4931GxPUqT67xYOsC8N42JvbwvHrx9L7q9P4nj'
    'PS1uOD1mNYi9ZrtyPcNlrb0pBdc8JwHPvfL05zv03oQ9MAMSPuRg1D27hru98HSHPevFAbuN/gG9QRAJOw498Tx3bIK8TLcIPObj'
    'Rb3bTee9XpURvUuq6zu9Tbi9D03LPE/zrb1YuWU94A3aPQaIZz1AzJ09QwFWvbCGuT0Rhck8uo1TPWPrDz2XMKU5/mWyvV/apb2E'
    'Bje97/GQvW6Giry2CJg70VnOuyqG/j3LeQs9lkaoPMlgG73cmd+8xx14vOwPqz3VPiM9tjFtPUkyfr3jvnW91nohvQbNHb2ypKU9'
    'NfiLPRcUyjsKya491aurPdN0pr327ze9vfRgvaeU87yXFam9RtbkPcP85bz3OTM9RurfO5zPtj2Dyso9i7f7u0qlHL3Q3RU9vGxs'
    'vXaZBD4lTaw9BD2EvbTjCLzCXaI7MfxBu5aFjTxHPoC9582rPF+sxT1GmSQ9SMJwvSu2UL0KGl26Sq2hPXAvhL2Wdso80YLjuw7c'
    'PT2SiLM95iiBPLTLJbl1fLi9S0/rPABtkL0ESKO8scfWugVwVj3kqwA905GNPU17Mz0QwTE9hDC/PHGmsz3xi947z/EovZV1Ez2P'
    '6jw9a7sOvZyuHj2yYJW9kv3YuwYS+ztWPDO9V8TTPedK6z3de4W8oN8qvXRrlb0NZku87dgXPXKvm7vjxo29HFfAvZqa3z0331i9'
    'Ri5wPW0+8T3erA091QKovKUYTDyQYgA+o/K0vUht9jls7sc9wEeAvfTNeL3Vidq9lGefvY8iNz2jOho7s4ZSvTSP5TwKcgA+lLEG'
    'vl2xsb0ifMG9LN95vYnTUT0lWoS9CDKDPXjqiLpR5nM9+giiPV07xb28wWc9XOqwPacJgD1LBU89zMD5PbUHrLwipQc++leFvb6B'
    '4DyRBka9QyzrvWmSsj3NwQA9S0OEPWIMqD2kkKU9CfhSPF1JjL350oe9bSGGOp6ub720hDU9CbErPTcJNT0MNkw8R6WOvcqklj0T'
    '5ZC7YAOsvZT9B70gzIY9MjWpPTF3CL2aj4e9bIx5PHeZqr1BWf48kuZ/vAeKkrw0MxS92no4vezEBD2GfDc9Ec7NvTO1rr3zeC69'
    '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'
    'DRKvvTIASb3YY549IRCXPf2IJ72jJ7Q9uBCIvS8HJL1Ek7q9RdTxvBLQ+Lydvpe8yLWAu9fp9rugaQk97BBpPdvuoD3k9129v52C'
    'PNDbjD0weZC8AxrdPQpUJT17Pk09lVq+vA6hlz0OAII9jsDoPK8k5LyLXkU9HVVOvakd8DyMLLA90GGnPVpPhD0LXlw9kYhzPEfQ'
    '7jywjge9BSFyvWDArrwwK+M8x6ZdPXskmz0r6zo9+6zUPCc0Hb1eZoO8pHnZPOnQN7xTlKA749gZPG9c4D0SaW88YqBpu8+GgT3m'
    '2p299hK7Pf9Efj36z2i8zAE6PVB4nb2keMk87DtpPUfDgT0k/LW9Zf0pvLYKGb1i2609vjTcPTCDgb1nQi88Sz9UvTQHHb44s9o8'
    'nObhPQpzDL2DBRQ9YefRvfBdqj335LQ9nvBxPV4mtjygtIO9zKmfPY9lGj1UWz49vdsyPVYt6L3T1RE+LJ/9vZ/hlz3qRVi94J7N'
    'PT8nOzzlxbg9utzIPH1WrrtV7Jo9DbQtPbMwmL2BE9I9/XXGveOz2L3J97w9BMkGvbNdg71Vgoo7Cbg3PZn/v718YhO+GSOUPA+0'
    'kb0ZnRu8KMK3vQXDhL2kWwu8PEkdPGflmb3LELK9kdUrPbgXsb3dCGS98LsZPc2gdz0ZRoK9omlovJnPqr1J7Ye9A50OPSU1k7zo'
    'Eji90uFZPZfGp73/zRa94DA1vS1lNr0DkA0+AEStvfAhzr0Wu/I94JvhOuGLpj3djFe9sr71vU+CqjwtMoq9w+06PfI1cj3VH469'
    '1m15PepSxD3o1sK9GBuAvaXXd72KImm9FYzaPPyePT1HOqA9sfRJvZYSxjxUBYW8giPIvewWR70gR4O8Kpv3vVm2zL0ROB09X12I'
    'PdrU9L2dQ9c9JL6cPGzK0b3p//K9SqiqPG3uzD19gak9G7kMPGm3gj3vH6y9Mb+lvPljVr2XuHU9h7CXPF8AkD2fO9U9jy6UPc4L'
    'ED2mXqU9MjJDvR7gazstBCQ9BPjMvCvnr7ykJqM9q5T0PJKP1rsjJl29zz50PW1QYzw8M429ZkcyvYOqOD2G6gI9o2iQPVxAWb20'
    'b8W7+ROdvEr2lT0Cley9ydAtPWZzrL1VWyQ+y3wEPdWXjzzCsvQ9+PmCvAkW/T2KPB++UXlfO0k+9TxUzo89MYm8OtHvkb1n1g+8'
    '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'
    'GoLWvVLazz1j/OA8bC40vUFQyD2z9+W7VsrJvQk2K70+xPQ83ZytvI9Yfr0xya89jfXEvX2/cr2ZSW69IHU3vSs4kzxRpGW96YaD'
    'PI3Enb0Ggci9AQJXPdkfhj0JwGo8cwGMPUUZOr0g1KK9y2/NPWr3jD3kst48wWHHvcHkyb2AL9I9ivyFvNtWQ738LtS96ivBO11t'
    'vD3F98m7MIeyPeeEozy4SIg9JTOPvQ/KHTvhppS9Ddq5vciyaL0V2lq9/BtdPD3w5TxFQOa7FGUpPWG4ib0QRgY9PtnNuV5bqj3P'
    'QcY9P/kevMfuv70y3lS9QohovZmKZL1IxYc8rRE7vcGwbr0rPQg+0mliPUP93L0Jw5q9/vSjvdukzL3I1ZY86IhyPD1q7Lxe1zk9'
    '0920vT1gpr0FbLY9Vjlgvamnqb2561o9LjiHPQRkrb0aaGy9lNkJPQFKETztBzO9efn8Pb3mbT1WEpa9gXvFvQxeSrxOelW9WSDC'
    'vUFWUb13yyo9L67XO9dWZr1OkLQ9DLFQPGw8r73zCoe9Z9i0vQ0NAj3TN447tSNhPOn7Or2Mkc+8V0qBPR7dGT0eQeQ62d5XvZGW'
    'VD0mzwo9jCGWvXRa+juKyy497Bs4PXNjf70CdEw75HQ9vfPkqT2OLai9YYwovUQB0z2jFHw9JWnUvUwGiLzNsOi8LKIivGhBkz3R'
    'e429mgl0PMyTmLsdSh09egZyPfkTvT10Phk9dA2XvZDwqj02Bzc9fCJuO5R/qLxdVxE9Ii6JvdtLhj0C1xc7R/9FPShoq70KBsC8'
    'g47qPC67CD2nRcU9V/x+PZ52tD3jUPK9vkr1PIqea71cqq885a6WOxHUmj1ySPk82MjYPRPZqb1kbQc8ccA0PHDJZzvxpBu85rvR'
    'vYY6/jzLjqU8IMGivE1em7z7gcU98Ut0vMrtpj3KFY09uOShPVr+rz2OTOg9WU6wPG50l72F0GQ8lFdXvGUkk7xf7469tMtTPOI0'
    'kT0WVj+8Ota1vbvyfb1qXeo8fE+wPb1B5zy+bZo9eju5vTlwAT1w1VW9SzwYvQADPjzgEoq92B+RPRAnALvt4ws9LvpKPaWLKb3R'
    'M2a8+s3RvcUpyT3Q9v+9vcgoPUvywL2XPJC8nfW1vfQ5Dbwwb7Y9zCMXPQgs9L1Tmxu8nqpouw0OFL2Lzwq9phsEPSHwzb3NjlG8'
    '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'
    'Hz6O2WM838+BPQ==';
// END FROZEN PUSHUP MLP ARRAYS

// BEGIN FROZEN PUSHUP KNEE ARRAYS
// Source native-knee-model.npz SHA-256 542d8651d1a8d4aadc58bcd0b8cf05634e9f69112f6d9a61c580905fb80e69c5
// Float64 mean/scale then float32 W0/W1/W2/b0/b1/b2, little-endian.
// Regenerate with tools/diagnose/export_pushup_knee_dart.py.
const _pushupKneeArrays =
    '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'
    'qU16m+vB7j+3nNYvETDuP/e9i3+h2e0/GPipbfD77j+OFpsD2A3vP3F44soqee0/QmqTzZG17T9+7+JOYdruP/mV5x5Hzu4/p/BJ'
    'FPdC7j82/TthT0XuPy4ioT1L9e0/wram5wbm7T+kQJLTZ37tP8HK+AGduu0/y3NGsa/i9T+3S2UZG+biPypLAxk9DeU/wHl5zueb'
    '4D9Sy/VHPELiP825jzUmk+M/+l3zlS764j/nxFeMi67nP3mSMGg9sus/nyOBAFaQ7D9U/Gv/tl7rP6aS35xUQPE/0K1cHqZQ9j9x'
    'ZNKdvsf1P4uSik4SL/Y/V79Ej1pd7j82k/p28QrxP8Sg3sNf7+8/wKmxCCze8D+NY0Ob/aLyP4JMADrKbfU/JmrU5XY99D/45umR'
    'TgT2P3D+YLwSe/Q/u8R7D1cZ9z9Jg/JnG0v1Pz1uL76FEfc/GGibTiwl5T/myMdcVvjhP3FzdTJCN/E/p+LI6cr96j/UH5nE7hb+'
    'P67M9mfdRPc/W3Ovkxnq8D//uSP2tbXvP1TKI/2DWPU/I3qnonYR9D9e+6n33+X1P3l+nJed9PQ/ODJUo3ni6D9Z9hV4D1TsPxBS'
    'hrHj2eo/CpAhfLhZ7D+j8SNwk5TzP96JAVjj0vU/9QPlFwuW8z/jR3PiMw31P6HciqLwLvA/XZUukiti8T9e40J5Y6vtP6aPILjb'
    'M/E/bI7ODKai8z9ehXgBSqz0P74f5O8+n/M/dg2vXxDT9D9FxdqPYQP1P/6rpvsv/PQ/P2Ai1wzq9D9RfnDeajv1P0RSvDIWV/I/'
    'W2TwnUAZ9z+jMJRoB1X0P6CXCNdv6/Y/dxwU0bh/5T+Ty4dDnEvnP6UWSPbVEeI/X1JxAHF24z8jsd9v46jkP5ly6GmZgOM/sZrv'
    'dAyL6D8fQP8KXersPzx9T3asve8/hG+GrTU27j+ZhDp4XOLzP+iP1eSr5vk/Xm9KkCrs+D8YFQp1QGD5P5Zr55CaefE/Dpx9mxJ1'
    '8z+T4DrTF53yPwNg8xrPcvM/f+r9PciD8z/Va6zTP3L2P8EeeJGHMPU/HBrl7ZUA9z86yWA2QbH0PxE+v4JcYvc/pjp/WdXq9T8z'
    'nyk8MMH3PxVn9XpY3uY/ZHdPDgy24z8taC7aFhfzP4FZmKEOE+4/FR6B1QebAECc5WWru935P+sv6jUzwfM/2ZQM4e6H8j/OPq1t'
    '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'
    'Ye4nvOzd8TxcdjM9PbeHPewiPL3wMSo9n1AHPm96bzwrPy09/ej3PKnQqz3Kh9I8UJ7FPFP2W7xH6u09gisCO4uWmL2HDw28+CAR'
    'vVmSur058q+892JwvBoWw72UYou9qCyLvTm5RrxWjoY8BA+VvTghwjxrFQC9VDSwPUvXoD0DuIY9YvIRvQH8Xz3265s9GgSIvRIU'
    'hD1o76s9KjhNvb98cD0UJn29mDyFvfYzYD3iDeW7zfIjPKCXLb3BVJc95UAjPWFrv7xMcME9qlQyvfR2bL2woUe9LmJbu01rvz3T'
    'RJU9RK6vPWLUar2sE589f3RkPUV0BjzAUAy80X8NPYFSJz3VGHa9Y9HWOn8e5z3rWIc8/ruAvbneN738zHY9/T11vM8+gT3QAle9'
    '6wT7vMr44D2ESbM96vULPspPrzw9+pq8WuihvcQ/3730fp69USymO2Fd2T37RpA9YrcwOc4fHLwgc609YvwEPZAUHr0LZrW9VbCj'
    'PVWXyT3yWZo8SshDPURqjz1qwc89BjgrvYmB3b1mWI49cjQMPUEzkTxioM48Ogz+vD8aNz2zlKE9pX56Oj3InbtudaK992/mPGT4'
    'Dj5wPic9QGHGu1WXmT3G5ra8xeJ7PXCuhj1Vcw89FE5DuyZh1LzZNje9vbQHPSE577tdZh8+bWRtPV12ZbzkEDO8wMTxvNy2871W'
    'bx096isxPXOa/TyI2e88/OnaPcjhdz30TiM9Iq3+vDw8VL242jY7iYPVPOa32j3jgMW8m6fMva34Yj3lhsu8Y9uOO0lItTqtnS69'
    'xPYCvqyCXb0wJgm9Q3XwvTEo5z3rnqy95sGUve/DT71nqS480AlAPTP4sDuWdky80yHPPR6LKj35IcM9MP93PU+AtT1vOwI8XtHS'
    'Pb9e2byPbuk9O2ffvOTn4zxnBoi8W6RaPNlwf73WNqM9EooJPVidaj3e9+a8NNw1vXVULz0GbIU8WlQPPaIiwT1Sg5I9zHt1PU+z'
    'kT2YX4I9IOq2PWmW+TyxFz29NT2avR4YfD0T0528wiHvvfOQA72Gamo9aMucPbMYEz3ER4M9TQgDPltFMT1o4T+9vdQ/vXnbpz2e'
    'bh+8JU+yPLbYT71yPqS9nF4ZPKZIaD1b3mY7BJTSvBksib13zCE9MM+OvCzX+byJCyc8cS/fPBWh9zv4sIe99X8XPbDkpruTFam8'
    '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'
    'InntPMyUkb2f6Qu9MRKtvfsJhjyjU4c9M0GJPbCBIr3M1de6YQMKPXhdHbwaeQo8KQ2tvQXd6Lt6AhK+5nXfvfC41ry0WxK9GBZ5'
    'Pdf7Hz1u5ri97ga/PKmSy70AHtS9z7x4u3rlf7y9zZA9WbsjvRpntD2AlKK9kDwtO6gst70a8bU8E5pavYVkfDyaCTi9ZSibPNr3'
    'ATyQeKk9HqkcvHnbK71seZ0945TXvYXPaL0cAcO9kPS4PSuYbL1VVww9P3IwPT307rw89KE9igqavHf7gb1NY/M7GocNvum4ADw7'
    'mre8+74dO/ZoGL3OGQu93uSbPBSybLxHqx29erB/PXqIwTx4nyQ9/YIGPRgdLL0O2sy9cBrGOsaKjj3DJqi8dyeIPVl7Yj3b23y8'
    '1+a6vTW2mDz14hs9o0TFvYU83r00mae85qgiPWTy4730FUe8/pSju9hBvb2b5jq9ZWjEvbxjMrwmU6I9/9ycPZ0imLzleVs9rq5k'
    'PP0Fqb11SGS9xvNZvVoPhr2OwZy9CMwDvq5LLz349Ds9+YAPvFSHVDwGHGS9rp6Au6T0sT3tx0S8hZ0CvWom1T3Lahg865O7vAcG'
    'fz1pmjI9a6CsPZp3j70p26E9UjFqPJGfKT1oko49YipqvFs6OL0pxOk7NLOAvaO6I74vDcQ9aV+GvS2l9TxC0Qk8pJePPR/hWz33'
    'bZ29tkgDPTbGebvpPqg8MnhwvQrboTzhXDg8fsTkPKzVZL1iFA89GmKBPeJ/ALt6DtA8INzlvbehhD1kTbi8uOSrvZpMxj1CNFu9'
    'sBcMPfNQrr3sT0m9qLHvvPByKryfnVG9HI9uvUM/WzwPp3W9xBCivQhvw70FEf286vNyvG74sTzzOSg89ByqvNZmFbuKhL09Y93U'
    'vDE7kj2RbLe9c0KcPBRAFb7P/9O93tawPMlYr73f6608OCwMvSoWaj0npdu76u2Cvb+I3zzJ7q47psn1O+gkYj3DgnU9t94nPWi2'
    'DL1Nzes9TPo7PF8mH7xORYu98WqQPde5TL2C9tm8g4YJPT0wBr5mku68128pvaDmnLzFzos74gcGvPeQobucgyU9kvgIPrNdEj03'
    '4ei6nbfvPYbVID6Eika9eal/vG6IKD2ruY+9aenWPSMUkzvvtKA98oo7vehUxLqIOKE8H4lfOzDziL1SQuO8m1WDvKtp1T3AVL69'
    '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'
    'cHIKPHIdNzwPG6k9obDbPXFsw7zOidk7ap96PYTkkL3oIM09MAW6vYXSob10/xQ9raSnPbPmWz38Wpc9hN6uPTxEtb3mvE29YK2Y'
    'PTebnz3hRn49nhPqPXZ31b1i8Do99G+kPXxbtjxYnxo9Ij2fvWmvZD0v40g9e3m3PYvQ/r1jD5E9d0syPeojPr2gtHC9EngTuzzp'
    '1LtoP0W8Bm1lPNocTL1jTIa9uwiMvUJmdz0h4ZY9QETjvYD/nry4QoO9nsZ9PWe+D7uG3ZA9WgKRPVZ8fDzuA7Y9yauHPVvkZrzB'
    'AGY97ZOJvcC7Wj2ag1C70KBPPUJVdj0kr2G8BqvHvPUOAr3Y7CW92aGLPKuU1Lu9kM68sYqCvdH0ob3x4Y69LRomvOhSJT2uYya6'
    'IBeVvbvcl7yTXso90Oy1vcQVQb1i7Ya97zMCPcm3JT1+xFu9rRjQPL7fbj0PDF+8T9q+vOM5pj0r3vm7EHhFPVX3pT1M8Jc9etsY'
    'vOAllb3Uq4W9C8jdPc+Hd71F1s08ZtWOO8tDf70LCaC7uCLSPRi1Aj0FmpU9lzLOPZcqUTyLFKA90Zt8vXZCdbxwz6W6S6S+vOW6'
    '2jz3EXA75TuPvaF0hb2sAYs8ouaDPTb0Kz1xEZI9dLF/PS1lmz1RX6E90y51vTDZhT1zL069PHR2Pa+sWz3m/8s93O4wPb0J7T3c'
    'Yls9ictqO+lm4Dz8xO89gFEXPdYO1z0wYcW9HATRPc3lrDy1wCC9NvKqvDT41jx33vi8lErXPPocnD2CDaW9i1SjvRPTiT2qXU88'
    '2cHjvQYDvr3XmTM9+YDnvMun8jyLdCe9dCA4vcGujj0BzhM8PlnjvYnlgD12v7S81y7dveGUKb0AqOm8FaFkPf4Da71JD3Y94unF'
    'PdyTyT1V/Gw9VUmMPf6Qhb2aZM69KPVdvStaiLzq92I8w6qSPX1u7TxoV1E9aLNNPFN6Xzwztyw8zrqcPRxtJT08emO9zZcyvbfZ'
    'nz0f3uS9ZFHevd6MX7xfvFW9OEMXPcAJnT3/boU8r43pPLJAP70IMHg9pxyfvMm32r0ntH09UNlGPRS93T257Mc8HkMfvXELgL28'
    'pLO7buROPUub7LwfjTy9z4CPvIOFOL2qW329FV3NvMmA/rxORHE8rzhQvM/jwrzmNrK7RljsPYBwErzUKgQ8Kj1ZPfTYq70mdxm9'
    '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'
    '5lriPC49Cr2fMJm9u3OtPLuFsT35m7A9ZlCHvVMYkb1zc3+8JAN9vdhog73mAwS+2+YGPq680juml0g9YDeGvefHxLv2qKu9WafL'
    'OpQoZ7wOHq68E/iFvWOK/T2gObY87pCZPVnxQ72Enio9M8KaPcTDeDzgx6S9f5FSPdFgZDwIaoQ96vXKvT0lAT6Dv9Q8C/fTvDFH'
    'nL08DUy9yX2Cvc2ajr2XELo9WgQZPG6Kb70+UpE96wyjvWk0FL1PPXK8hnjxO6H9kLyQKwE+9gyyvX4IhT3WIYU9topfvP1qLr3M'
    'ENc9RIoDPa5avb20yhU+85lRPVWYnT0iiPU8edbrvSkPgj18Qi4959ufPXNlBz2WKf69nhh6u4rPpz0a9Ms9RR93POq/vrw2wk+9'
    'IzsIvQWDIT3cFDq9GF8qPUw1lr2wYx+8GljePATMwLyKEZS8ecV8vLMg4Tz4PLu8PyD8PBPYlr1Jios9+yewPbGZy7qDwiM9cDJF'
    'PbJ5TD20+S49OHpfvbomrLshbY89dQJfvSIiADwGNiA+nZmTPf/SJTx7WeQ9Pyk8vU+dED7dfT8+27Z3vdrO6TyW50S+DQVfPd25'
    'dzynSIw8dbQfPqWhTT1TYQW+OomfvBHGw7ze03w9wHHoPYGhUz2gdBO+3RwCPmjYwLyRCYE96GY/vYrQGb1UPWA99/ZrPXi2ojzJ'
    'aE6+1DwAvi7FFz0HADO9EnIwvc5lDz3qWNU98aLlPRQtHTxfbBq+zUqnvcrbxD1Vb8W89pjhvNF9QL2dZ7i9H38CvtWRuT37gYG9'
    '1edVvbcML75UFZc8P6aeO+pbY7zaYPG971GLPZd+yL37Qp294CKgvT6iCD34zhg8EWt7u7UOMz1qZpI8P8uJvUWU4r25op290Rsk'
    'PXZBML5qD849ZRNSOoiWAD0oz8e8yXrHPfE6Ab31NX49KVaZPEO9Mj0mLRi8SlkcPe91sj3wK9S9ZJm9vcHzZT1DrIC986N2vcO8'
    'ur1CCFU9/CLsvEwwpb1dopW8y9yBvRoAaz3xDqI9UgyLvAkUwL0oMCi9N/aWPXGQ0bwYbg49UokCvff0oLxPMme9E6jsvfF1Ez1p'
    'wGy9KcEKPTdOJD0MI2s6m+rNvIlW4z29UvQ8TJ+bvWXRjz1TH8u8N5WMvUs3V73Fnq68WxyhPLyKC71kyig8gXfJvcyQfD2VcLW7'
    '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'
    '79Qqvq96ir1pb3k92tgGvRoxSj1gYHM9CeLoPb1CLr2O7wC9KXlTvQPivjzJ76S8HuIsPQopCL6EnpE9oClCvkShjb0M6aw7TJLE'
    'vSViL75OGB49m3QQPbMw+TxPvIg8dRhru9nVD75UhRa+ZYnjPTnysTstiCw+PjxcPSGb7D2FcVa9TcvrvGeNVb3CrZI9hI6ZPYtx'
    'Xj0UfDu951oKvuCfl73aS1w9XmKxPbOKnTzlXzM9K+lIPWAKtjxV0We9uaicvaSXCz32QD47rxZyvBw1/DxtDlA9lKu1vB7pTzxA'
    'A9K9tInlvNyEbT35W8U8Fsy1PN6dCjwEpCe9di4XPSS6wLzSnVs9HPRuOxjFgz25XPe9e2YCPa7AAL6lDPI9qwA5PUYhe71VB5I9'
    '2QV6PQhltbtFrHq8X0ULvSkcC74ehpk87N6YPU5EDTzPJH88KeUSPcKVRzzqpfa8s/0tvaUbDj58mAm+FK0oPPaL4Dzuy9I95rZ2'
    'PDP+OD1ZzwS+v9G1vZ25cT07x8W8+ywKPoI72D3uvR+7BPQqvGIYIjv8Ms29qMfRO6W++bxKswg+TIOaPDJMCj03NqC8HL7KvQez'
    '9jvhZ6y8b1D4vKsEOL0Zdbi8LL5XPKwJYb2WTdo9PbeBvcalLjy2NRC+n4oHvqCxPDyu72S8lrF7vUnpQTw/18493pmaPEdwf73j'
    'poU8IToVvNArsj3YPty7mEmBPHE4lb3qvYG8nSchPA9r1z01F7w8hC/1vQS8Uz3Ddca9d0eRvUKHJL029LS9ugNTvcDNszq9pWS3'
    'RNx7PI39RDxxp5y9AdFbPBvoEb0+zk29C3PsPFttbL1GkiA83wqIvKeImj0MSgO+tyUevLr+uz1CtOI7VdT6u7euzb39MVA9nrEA'
    'vtQoIr0EAIw9Jmu+PMB+UbyKnim9rIUau6lsIb3eRoG9ZLWKvEH0rb2S09a9pTXZvVrsZ70i1nK9E/laPaoIPLwvlzE+cjvzvWPQ'
    '4TzuFGq95gXuO1wgyr3Driw+GA6IPWu69ju5Plc9TGbwOaIIIz2WuZI9dA7WvSF28zw4YQA+x95mvRho8bx+twS++LnHvCqRhbuZ'
    '4xg9cJ6qvXikQT2p4I29ydOxvFb7ibxJx3U9mC0rPbL7oz12Xz+9B6QfPNyA/Ly+a6c9qvfLvAaB6TutXi89b3auuV8y3719CBO+'
    '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';
// END FROZEN PUSHUP KNEE ARRAYS
