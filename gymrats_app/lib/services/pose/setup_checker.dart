import 'dart:math' as math;

import '../../models/exercise_type.dart';
import '../../models/pose_frame.dart';

/// Returns monotonic elapsed time. Injected so tests can control time.
typedef Clock = Duration Function();

/// All thresholds used by the pose setup step.
class SetupConfig {
  const SetupConfig({
    this.minLikelihood = 0.6,
    this.frameMargin = 0.03,
    this.minBodySizeRatio = 0.35,
    this.maxBodySizeRatio = 0.9,
    this.readyDelay = const Duration(milliseconds: 1500),
    this.dropDelay = const Duration(milliseconds: 500),
    this.detectorFailureTimeout = const Duration(seconds: 3),
  });

  /// Minimum ML Kit likelihood for a landmark to count as visible.
  final double minLikelihood;

  /// Margin inside the frame edges, as a fraction of width and height.
  final double frameMargin;

  /// Body size below this fraction of the frame means "too far".
  ///
  /// Body size is the larger of box height / frame height and
  /// box width / frame width, so lying poses are measured correctly.
  final double minBodySizeRatio;

  /// Body size above this fraction of the frame means "too close".
  final double maxBodySizeRatio;

  /// How long the pose must stay valid before Ready is reported.
  final Duration readyDelay;

  /// How long the pose must stay invalid before Ready is cleared.
  final Duration dropDelay;

  /// How long pose detection may keep failing before an error is shown.
  final Duration detectorFailureTimeout;
}

/// Result of checking one frame, in the order the checks run.
enum SetupReason { noPerson, tooClose, tooFar, missingParts, ready }

/// Body parts named in "not visible" messages.
enum BodyPart {
  head('head'),
  shoulders('shoulders'),
  elbows('elbows'),
  hands('hands'),
  hips('hips'),
  knees('knees'),
  feet('feet');

  const BodyPart(this.label);

  final String label;
}

/// Setup state after the latest frame.
class SetupStatus {
  const SetupStatus({
    required this.reason,
    required this.isReady,
    required this.readyProgress,
    this.missingParts = const [],
  });

  static const initial = SetupStatus(
    reason: SetupReason.noPerson,
    isReady: false,
    readyProgress: 0,
  );

  /// Evaluation of the latest frame only.
  final SetupReason reason;

  /// Stable Ready state: set after [SetupConfig.readyDelay] of valid frames
  /// and cleared after [SetupConfig.dropDelay] of invalid frames.
  final bool isReady;

  /// Progress towards Ready, from 0 to 1.
  final double readyProgress;

  /// Parts that are not visible when [reason] is [SetupReason.missingParts].
  final List<BodyPart> missingParts;

  /// Message telling the user what to do next.
  String get message {
    if (isReady) return 'Ready! Press Start.';
    switch (reason) {
      case SetupReason.noPerson:
        return 'No one detected. Step into the camera view.';
      case SetupReason.tooClose:
        return 'Move back a little.';
      case SetupReason.tooFar:
        return 'Move closer to the camera.';
      case SetupReason.missingParts:
        return '${_capitalize(_joinParts(missingParts))} not visible.';
      case SetupReason.ready:
        return 'Hold still...';
    }
  }

  static String _joinParts(List<BodyPart> parts) {
    final labels = parts.map((p) => p.label).toList();
    if (labels.length <= 1) return labels.join();
    return '${labels.sublist(0, labels.length - 1).join(', ')} and ${labels.last}';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Where to place the phone for [exercise].
String placementGuideFor(ExerciseType exercise) {
  switch (exercise) {
    case ExerciseType.pushUp:
      return 'Place the phone on the floor, facing your side, about 2 m away.';
    case ExerciseType.sitUp:
      return 'Place the phone on the floor, facing your side, about 1.5 m away.';
    case ExerciseType.pullUp:
      return 'Place the phone at chest height, facing you, about 2.5 m away.';
  }
}

typedef _PartLandmarks = ({
  BodyPart part,
  BodyLandmark left,
  BodyLandmark right,
});

const _shoulders = (
  part: BodyPart.shoulders,
  left: BodyLandmark.leftShoulder,
  right: BodyLandmark.rightShoulder,
);
const _elbows = (
  part: BodyPart.elbows,
  left: BodyLandmark.leftElbow,
  right: BodyLandmark.rightElbow,
);
const _hands = (
  part: BodyPart.hands,
  left: BodyLandmark.leftWrist,
  right: BodyLandmark.rightWrist,
);
const _hips = (
  part: BodyPart.hips,
  left: BodyLandmark.leftHip,
  right: BodyLandmark.rightHip,
);
const _knees = (
  part: BodyPart.knees,
  left: BodyLandmark.leftKnee,
  right: BodyLandmark.rightKnee,
);
const _feet = (
  part: BodyPart.feet,
  left: BodyLandmark.leftAnkle,
  right: BodyLandmark.rightAnkle,
);

/// Required parts per exercise, besides the nose.
const Map<ExerciseType, List<_PartLandmarks>> _requiredParts = {
  ExerciseType.pushUp: [_shoulders, _elbows, _hands, _hips, _knees, _feet],
  ExerciseType.sitUp: [_shoulders, _hips, _knees, _feet],
  ExerciseType.pullUp: [_shoulders, _elbows, _hands, _hips],
};

/// Exercises that need both body sides visible (front view).
const _bothSidesRequired = {ExerciseType.pullUp};

/// Decides whether the user is placed well enough to start [exercise].
///
/// Pure Dart: depends only on `models/`, so it can be tested with synthetic
/// frames and an injected [Clock].
class SetupChecker {
  SetupChecker({
    required this.exercise,
    this.config = const SetupConfig(),
    Clock? clock,
  }) : _clock = clock ?? _stopwatchClock();

  final ExerciseType exercise;
  final SetupConfig config;
  final Clock _clock;

  Duration? _validSince;
  Duration? _invalidSince;
  bool _isReady = false;

  static Clock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// Whether [keypoint] passes the likelihood and frame margin checks.
  bool isVisible(Keypoint? keypoint, PoseFrame frame) {
    if (keypoint == null || keypoint.likelihood < config.minLikelihood) {
      return false;
    }
    final marginX = frame.imageWidth * config.frameMargin;
    final marginY = frame.imageHeight * config.frameMargin;
    return keypoint.x >= marginX &&
        keypoint.x <= frame.imageWidth - marginX &&
        keypoint.y >= marginY &&
        keypoint.y <= frame.imageHeight - marginY;
  }

  /// Checks [frame] and updates the stable Ready state.
  SetupStatus update(PoseFrame frame) {
    final now = _clock();
    final (reason, missing) = _evaluate(frame);

    if (reason == SetupReason.ready) {
      _invalidSince = null;
      _validSince ??= now;
      if (!_isReady && now - _validSince! >= config.readyDelay) {
        _isReady = true;
      }
    } else {
      _validSince = null;
      if (_isReady) {
        _invalidSince ??= now;
        if (now - _invalidSince! >= config.dropDelay) {
          _isReady = false;
          _invalidSince = null;
        }
      }
    }

    return SetupStatus(
      reason: reason,
      isReady: _isReady,
      readyProgress: _progress(now),
      missingParts: missing,
    );
  }

  /// Clears the stability timers, e.g. after the camera restarts.
  void reset() {
    _validSince = null;
    _invalidSince = null;
    _isReady = false;
  }

  double _progress(Duration now) {
    if (_isReady) return 1;
    final since = _validSince;
    if (since == null) return 0;
    final ratio =
        (now - since).inMicroseconds / config.readyDelay.inMicroseconds;
    return ratio.clamp(0.0, 1.0);
  }

  (SetupReason, List<BodyPart>) _evaluate(PoseFrame frame) {
    final visible = frame.keypoints.values
        .where((k) => isVisible(k, frame))
        .toList();
    if (visible.isEmpty) return (SetupReason.noPerson, const []);

    final size = _bodySizeRatio(visible, frame);
    if (size > config.maxBodySizeRatio) return (SetupReason.tooClose, const []);
    if (size < config.minBodySizeRatio) return (SetupReason.tooFar, const []);

    final missing = _missingParts(frame);
    if (missing.isNotEmpty) return (SetupReason.missingParts, missing);
    return (SetupReason.ready, const []);
  }

  double _bodySizeRatio(List<Keypoint> visible, PoseFrame frame) {
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final k in visible) {
      minX = math.min(minX, k.x);
      maxX = math.max(maxX, k.x);
      minY = math.min(minY, k.y);
      maxY = math.max(maxY, k.y);
    }
    return math.max(
      (maxY - minY) / frame.imageHeight,
      (maxX - minX) / frame.imageWidth,
    );
  }

  List<BodyPart> _missingParts(PoseFrame frame) {
    bool seen(BodyLandmark l) => isVisible(frame[l], frame);
    final required = _requiredParts[exercise]!;
    final headMissing = !seen(BodyLandmark.nose);

    List<BodyPart> missingFor(bool Function(_PartLandmarks) partSeen) => [
      if (headMissing) BodyPart.head,
      for (final p in required)
        if (!partSeen(p)) p.part,
    ];

    if (_bothSidesRequired.contains(exercise)) {
      return missingFor((p) => seen(p.left) && seen(p.right));
    }

    final left = missingFor((p) => seen(p.left));
    final right = missingFor((p) => seen(p.right));
    if (left.length != right.length) {
      return left.length < right.length ? left : right;
    }
    // Same count: report the side the detector is more confident about.
    double confidence(BodyLandmark Function(_PartLandmarks) pick) => required
        .map((p) => frame[pick(p)]?.likelihood ?? 0)
        .fold(0.0, (a, b) => a + b);
    return confidence((p) => p.left) >= confidence((p) => p.right)
        ? left
        : right;
  }
}
