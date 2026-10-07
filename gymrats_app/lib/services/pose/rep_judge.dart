import 'dart:math' as math;

import '../../models/pose_frame.dart';
import '../../models/rep_event.dart';
import 'pose_metrics.dart';

/// Returns monotonic elapsed time. Injected so tests can control time.
typedef RepClock = Duration Function();

/// Thresholds for the front-view push-up rep judge.
///
/// Depth is how far the nose has dropped below the top pose, in top-pose
/// shoulder widths. With the phone on the floor in front of the user, a
/// full push-up measured about 1.4 to 1.9 on test recordings.
class RepJudgeConfig {
  const RepJudgeConfig({
    this.minLikelihood = 0.6,
    this.topAngle = 155,
    this.topHold = const Duration(milliseconds: 300),
    this.enterDepth = 0.35,
    this.topDepth = 0.25,
    this.shallowDepth = 0.8,
    this.bottomDepth = 1.1,
    this.partialDepth = 0.6,
    this.reDescentDepth = 0.4,
    this.minRepDuration = const Duration(milliseconds: 300),
    this.maxShoulderTilt = 15,
    this.maxFrameGap = const Duration(milliseconds: 500),
    this.maxAttempt = const Duration(seconds: 12),
    this.smoothingTau = const Duration(milliseconds: 65),
    this.baselineTau = const Duration(milliseconds: 500),
  });

  /// Minimum ML Kit likelihood for a landmark to be used.
  final double minLikelihood;

  /// Elbow angle that counts as extended arms, in degrees.
  final double topAngle;

  /// How long extended arms must be seen before counting can start.
  final Duration topHold;

  /// Depth that starts an attempt.
  final double enterDepth;

  /// Depth at or below which the head is back at the top.
  final double topDepth;

  /// An attempt that returns to the top without reaching this depth was
  /// not a push-up (a nod, standing up) and is dropped without a verdict.
  final double shallowDepth;

  /// Depth that counts as the bottom of the push-up.
  final double bottomDepth;

  /// Rising above this depth after the bottom, then going down again
  /// without a lockout, is an incomplete lockout.
  final double partialDepth;

  /// How far the head must go down again, after [partialDepth], to reject.
  final double reDescentDepth;

  /// Reps faster than this are rejected.
  final Duration minRepDuration;

  /// Shoulder line steeper than this, in degrees, rejects the rep.
  final double maxShoulderTilt;

  /// Longer without a usable frame discards the attempt in progress.
  final Duration maxFrameGap;

  /// An attempt still open after this long is discarded.
  final Duration maxAttempt;

  /// Time constant of the measurement smoothing.
  final Duration smoothingTau;

  /// Time constant with which the top pose follows the user between reps.
  final Duration baselineTau;
}

/// Where the user is in a push-up.
enum RepPhase {
  /// Waiting for extended arms.
  idle,

  /// At the top. The next descent can count.
  up,

  /// Moving down, bottom not reached yet.
  descending,

  /// Bottom reached. Waiting for the return to the top.
  bottom,

  /// The head was lost. Extended arms have to be seen again.
  lost,
}

/// Live numbers for the debug overlay.
class JudgeSnapshot {
  const JudgeSnapshot({
    required this.phase,
    this.elbowAngle,
    this.depth,
    this.tilt,
  });

  static const initial = JudgeSnapshot(phase: RepPhase.idle);

  final RepPhase phase;

  /// Smoothed elbow angle, in degrees. Null while the arms are not visible.
  final double? elbowAngle;

  /// Head drop below the top pose, in shoulder widths. Null until the top
  /// pose is known.
  final double? depth;

  /// Smoothed shoulder tilt, in degrees.
  final double? tilt;
}

/// The result of feeding one frame to [RepJudge].
class RepUpdate {
  const RepUpdate({required this.snapshot, this.event});

  final JudgeSnapshot snapshot;

  /// Set only on the frame that closes a rep.
  final RepEvent? event;
}

/// Counts front-view push-ups from pose landmarks.
///
/// From the front, the elbow angle barely changes and the hands leave the
/// frame or drop in likelihood near the bottom, so depth comes from the head:
/// the nose drops by more than a shoulder width while the face stays
/// visible. The arms are used where they are reliable, at the top: extended
/// arms start counting, and a visible bent arm blocks the lockout.
///
/// Pure Dart: depends only on [PoseFrame], so tests drive it with synthetic
/// frames and an injected clock. The pose model itself is not part of this
/// class; it only interprets keypoints.
///
/// The body-line check is the shoulder tilt. From the front the hips are
/// hidden, so a sagging torso cannot be seen and is not judged here.
class RepJudge {
  RepJudge({this.config = const RepJudgeConfig(), RepClock? clock})
    : _clock = clock ?? _stopwatchClock(),
      _smoother = MetricSmoother(tau: config.smoothingTau);

  final RepJudgeConfig config;
  final RepClock _clock;
  final MetricSmoother _smoother;

  RepPhase _phase = RepPhase.idle;
  Duration? _lastAt;
  Duration? _topSince;
  Duration? _attemptStarted;
  double? _topNoseY;
  double? _topWidth;
  double _maxDepth = 0;
  double _highestSinceBottom = 0;
  double? _minElbow;
  double _maxTilt = 0;
  double? _previousTilt;
  int _nextIndex = 1;

  static RepClock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// Clears the state machine and the rep index.
  void reset() {
    _phase = RepPhase.idle;
    _lastAt = null;
    _topSince = null;
    _clearAttempt();
    _topNoseY = null;
    _topWidth = null;
    _nextIndex = 1;
    _smoother.reset();
  }

  /// Drops the attempt in progress without forgetting reps already emitted.
  ///
  /// Used when the camera hiccups: the next rep keeps the following index.
  void abandon() {
    _phase = RepPhase.lost;
    _topSince = null;
    _clearAttempt();
    _topNoseY = null;
    _topWidth = null;
    _smoother.reset();
  }

  /// Judges [frame] and maybe closes one rep.
  RepUpdate update(PoseFrame frame) {
    final now = _clock();
    final gap = _lastAt == null ? Duration.zero : now - _lastAt!;
    if (gap > config.maxFrameGap) abandon();

    final raw = measurePose(frame, minLikelihood: config.minLikelihood);
    // Arms and shoulders come and go; without the head there is no depth.
    if (raw.noseY == null) {
      return RepUpdate(snapshot: JudgeSnapshot(phase: _phase));
    }
    final dt = gap > config.maxFrameGap ? Duration.zero : gap;
    _lastAt = now;

    final smoothed = _smoother.update(raw, dt);
    final elbow = raw.elbowAngle == null ? null : smoothed.elbowAngle;
    final tilt = raw.tilt == null ? null : smoothed.tilt;

    if (_phase == RepPhase.idle || _phase == RepPhase.lost) {
      _holdTop(now, elbow, smoothed);
      return RepUpdate(snapshot: _snapshot(elbow, smoothed, tilt));
    }

    final depth = _depth(smoothed)!;
    if (_phase == RepPhase.up) {
      _followTop(elbow, depth, smoothed, dt);
      if (depth >= config.enterDepth) _beginAttempt(now, depth);
    }

    if (_phase == RepPhase.descending || _phase == RepPhase.bottom) {
      _maxDepth = math.max(_maxDepth, depth);
      if (elbow != null) _minElbow = math.min(_minElbow ?? elbow, elbow);
      // A single-frame spike from a shoulder near the edge is not a tilt.
      if (tilt != null && _previousTilt != null) {
        _maxTilt = math.max(_maxTilt, math.min(tilt, _previousTilt!));
      }
      if (now - _attemptStarted! > config.maxAttempt) {
        _clearAttempt();
        _phase = RepPhase.idle;
        _topSince = null;
        _previousTilt = tilt;
        return RepUpdate(snapshot: _snapshot(elbow, smoothed, tilt));
      }
    }
    _previousTilt = tilt;

    final event = _advance(now, depth, elbow);
    return RepUpdate(snapshot: _snapshot(elbow, smoothed, tilt), event: event);
  }

  RepEvent? _advance(Duration now, double depth, double? elbow) {
    if (_phase == RepPhase.descending) {
      if (depth >= config.bottomDepth) {
        _phase = RepPhase.bottom;
        _highestSinceBottom = depth;
      } else if (depth <= config.topDepth) {
        final event = _maxDepth >= config.shallowDepth
            ? _emit(now, RejectReason.insufficientDepth)
            : null;
        _finishAtTop();
        return event;
      }
    }

    if (_phase == RepPhase.bottom) {
      _highestSinceBottom = math.min(_highestSinceBottom, depth);
      final armsExtended = elbow == null || elbow >= config.topAngle;
      if (depth <= config.topDepth && armsExtended) {
        final event = _complete(now);
        _finishAtTop();
        return event;
      }
      if (_highestSinceBottom <= config.partialDepth &&
          depth - _highestSinceBottom >= config.reDescentDepth) {
        final event = _emit(now, RejectReason.incompleteExtension);
        _beginAttempt(now, depth);
        return event;
      }
    }
    return null;
  }

  void _holdTop(Duration now, double? elbow, PoseMetrics smoothed) {
    if (elbow == null) return;
    if (elbow < config.topAngle || smoothed.shoulderWidth == null) {
      _topSince = null;
      return;
    }
    _topSince ??= now;
    if (now - _topSince! >= config.topHold) {
      _topNoseY = smoothed.noseY;
      _topWidth = smoothed.shoulderWidth;
      _phase = RepPhase.up;
      _topSince = null;
    }
  }

  /// Moves the top pose towards the current one while the arms are seen
  /// extended, so the user may shift on the mat between reps.
  void _followTop(
    double? elbow,
    double depth,
    PoseMetrics smoothed,
    Duration dt,
  ) {
    if (elbow == null || elbow < config.topAngle) return;
    if (depth >= config.enterDepth) return;
    final alpha = config.baselineTau.inMicroseconds == 0
        ? 1.0
        : 1 - math.exp(-dt.inMicroseconds / config.baselineTau.inMicroseconds);
    _topNoseY = _topNoseY! + alpha * (smoothed.noseY! - _topNoseY!);
    final width = smoothed.shoulderWidth;
    if (width != null) _topWidth = _topWidth! + alpha * (width - _topWidth!);
  }

  void _beginAttempt(Duration now, double depth) {
    _phase = RepPhase.descending;
    _attemptStarted = now;
    _maxDepth = depth;
    _highestSinceBottom = depth;
    _minElbow = null;
    _maxTilt = 0;
  }

  void _finishAtTop() {
    _phase = RepPhase.up;
    _clearAttempt();
  }

  RepEvent _complete(Duration now) {
    final RejectReason? reason;
    if (now - _attemptStarted! < config.minRepDuration) {
      reason = RejectReason.tooFast;
    } else if (_maxTilt > config.maxShoulderTilt) {
      reason = RejectReason.shouldersNotLevel;
    } else {
      reason = null;
    }
    return _emit(now, reason);
  }

  RepEvent _emit(Duration now, RejectReason? reason) => RepEvent(
    index: _nextIndex++,
    valid: reason == null,
    reason: reason,
    at: now,
    maxDepth: _maxDepth,
    minElbowAngle: _minElbow,
    maxTilt: _maxTilt,
  );

  void _clearAttempt() {
    _attemptStarted = null;
    _maxDepth = 0;
    _highestSinceBottom = 0;
    _minElbow = null;
    _maxTilt = 0;
    _previousTilt = null;
  }

  double? _depth(PoseMetrics smoothed) {
    final top = _topNoseY;
    final width = _topWidth;
    final nose = smoothed.noseY;
    if (top == null || width == null || width < 1e-6 || nose == null) {
      return null;
    }
    return (nose - top) / width;
  }

  JudgeSnapshot _snapshot(double? elbow, PoseMetrics smoothed, double? tilt) =>
      JudgeSnapshot(
        phase: _phase,
        elbowAngle: elbow,
        depth: _depth(smoothed),
        tilt: tilt,
      );
}
