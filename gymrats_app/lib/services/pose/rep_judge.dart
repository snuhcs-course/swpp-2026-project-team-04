import '../../models/pose_frame.dart';
import '../../models/rep_event.dart';
import 'pose_metrics.dart';

/// Returns monotonic elapsed time. Injected so tests can control time.
typedef RepClock = Duration Function();

/// Thresholds for the front-view push-up rep judge.
class RepJudgeConfig {
  const RepJudgeConfig({
    this.minLikelihood = 0.6,
    this.topAngle = 155,
    this.enterAngle = 140,
    this.bottomAngle = 100,
    this.bottomSpanRatio = 0.7,
    this.topHold = const Duration(milliseconds: 300),
    this.minRepDuration = const Duration(milliseconds: 650),
    this.maxShoulderTilt = 15,
    this.partialRiseAngle = 130,
    this.reDescentDrop = 20,
    this.maxFrameGap = const Duration(milliseconds: 500),
    this.maxAttempt = const Duration(seconds: 12),
    this.smoothingTau = const Duration(milliseconds: 65),
  });

  /// Minimum ML Kit likelihood for a landmark to be used.
  final double minLikelihood;

  /// Elbow angle that counts as the top (arms extended), in degrees.
  final double topAngle;

  /// Elbow angle below which a descent has started. Below [topAngle], so
  /// noise around the top does not start and finish a rep.
  final double enterAngle;

  /// Elbow angle that counts as the bottom of the push-up.
  final double bottomAngle;

  /// Span, relative to the top pose, that also counts as the bottom.
  ///
  /// A front view barely changes the elbow angle when the elbows stay tucked,
  /// so the shoulder-to-wrist distance is a second depth signal.
  final double bottomSpanRatio;

  /// How long the top pose must be held before counting can start.
  final Duration topHold;

  /// Reps faster than this are rejected.
  final Duration minRepDuration;

  /// Shoulder line steeper than this, in degrees, rejects the rep.
  final double maxShoulderTilt;

  /// Rising past this angle and then dropping again is an incomplete lockout.
  final double partialRiseAngle;

  /// How far the elbow must bend again, after [partialRiseAngle], to reject.
  final double reDescentDrop;

  /// A longer gap between frames discards the attempt in progress.
  final Duration maxFrameGap;

  /// An attempt still open after this long is discarded.
  final Duration maxAttempt;

  /// Time constant of the measurement smoothing.
  final Duration smoothingTau;
}

/// Where the user is in a push-up.
enum RepPhase {
  /// Waiting for a stable top pose.
  idle,

  /// Arms extended. The next descent can count.
  up,

  /// Moving down, bottom not reached yet.
  descending,

  /// Bottom reached. Waiting for the arms to extend.
  bottom,

  /// Landmarks were lost. The top pose has to be found again.
  lost,
}

/// Live numbers for the debug overlay.
class JudgeSnapshot {
  const JudgeSnapshot({
    required this.phase,
    this.elbowAngle,
    this.spanRatio,
    this.tilt,
  });

  static const initial = JudgeSnapshot(phase: RepPhase.idle);

  final RepPhase phase;

  /// Smoothed elbow angle, in degrees.
  final double? elbowAngle;

  /// Span relative to the calibrated top pose once that exists, otherwise
  /// the raw shoulder-to-wrist ratio.
  final double? spanRatio;

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
  double? _baselineSpan;
  double _minElbow = 180;
  double _minSpan = 1;
  double _maxTilt = 0;
  double _peakElbow = 0;
  bool _rosePastPartial = false;
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
    _baselineSpan = null;
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
    _baselineSpan = null;
    _smoother.reset();
  }

  /// Judges [frame] and maybe closes one rep.
  RepUpdate update(PoseFrame frame) {
    final now = _clock();
    if (_lastAt != null && now - _lastAt! > config.maxFrameGap) {
      abandon();
    }
    final dt = _lastAt == null ? Duration.zero : now - _lastAt!;
    _lastAt = now;

    final raw = measurePose(frame, minLikelihood: config.minLikelihood);
    if (raw.elbowAngle == null) {
      abandon();
      return RepUpdate(snapshot: _snapshot(null, null));
    }

    final smoothed = _smoother.update(raw, dt);
    final elbow = smoothed.elbowAngle!;
    final span = smoothed.spanRatio;
    final tilt = smoothed.tilt;
    final relative = _relative(span);

    if (_phase == RepPhase.descending || _phase == RepPhase.bottom) {
      if (elbow < _minElbow) _minElbow = elbow;
      if (relative != null && relative < _minSpan) _minSpan = relative;
      if (tilt != null && tilt > _maxTilt) _maxTilt = tilt;
      final started = _attemptStarted;
      if (started != null && now - started > config.maxAttempt) {
        _clearAttempt();
        _phase = RepPhase.idle;
        _topSince = null;
        return RepUpdate(snapshot: _snapshot(smoothed, relative));
      }
    }

    final event = _advance(now, elbow, span, relative, tilt);
    return RepUpdate(snapshot: _snapshot(smoothed, relative), event: event);
  }

  RepEvent? _advance(
    Duration now,
    double elbow,
    double? span,
    double? relative,
    double? tilt,
  ) {
    if (_phase == RepPhase.idle || _phase == RepPhase.lost) {
      _holdTop(now, elbow, span);
      return null;
    }

    if (_phase == RepPhase.up && elbow < config.enterAngle) {
      _beginAttempt(now, elbow, relative, tilt);
    }

    if (_phase == RepPhase.descending) {
      final deep =
          elbow <= config.bottomAngle ||
          (relative != null && relative <= config.bottomSpanRatio);
      if (deep) {
        _phase = RepPhase.bottom;
        _peakElbow = elbow;
        _rosePastPartial = false;
      } else if (elbow >= config.topAngle) {
        final event = _reject(RejectReason.insufficientDepth, now);
        _finishAtTop(span);
        return event;
      }
    }

    if (_phase == RepPhase.bottom) {
      if (elbow >= config.topAngle) {
        final event = _complete(now);
        _finishAtTop(span);
        return event;
      }
      if (elbow > _peakElbow) _peakElbow = elbow;
      if (elbow >= config.partialRiseAngle) _rosePastPartial = true;
      if (_rosePastPartial && _peakElbow - elbow >= config.reDescentDrop) {
        final event = _reject(RejectReason.incompleteExtension, now);
        _rosePastPartial = false;
        _peakElbow = elbow;
        return event;
      }
    }
    return null;
  }

  void _holdTop(Duration now, double elbow, double? span) {
    if (elbow >= config.topAngle) {
      _topSince ??= now;
      if (now - _topSince! >= config.topHold) {
        _baselineSpan = span;
        _phase = RepPhase.up;
        _topSince = null;
      }
    } else {
      _topSince = null;
    }
  }

  void _beginAttempt(
    Duration now,
    double elbow,
    double? relative,
    double? tilt,
  ) {
    _phase = RepPhase.descending;
    _attemptStarted = now;
    _minElbow = elbow;
    _minSpan = relative ?? 1;
    _maxTilt = tilt ?? 0;
    _peakElbow = elbow;
    _rosePastPartial = false;
  }

  void _finishAtTop(double? span) {
    _phase = RepPhase.up;
    _clearAttempt();
    if (span != null) _baselineSpan = span;
  }

  RepEvent _complete(Duration now) {
    final started = _attemptStarted ?? now;
    final RejectReason? reason;
    if (now - started < config.minRepDuration) {
      reason = RejectReason.tooFast;
    } else if (_maxTilt > config.maxShoulderTilt) {
      reason = RejectReason.shouldersNotLevel;
    } else {
      reason = null;
    }
    return _emit(now, reason);
  }

  RepEvent _reject(RejectReason reason, Duration now) => _emit(now, reason);

  RepEvent _emit(Duration now, RejectReason? reason) {
    return RepEvent(
      index: _nextIndex++,
      valid: reason == null,
      reason: reason,
      at: now,
      minElbowAngle: _minElbow,
      minSpanRatio: _minSpan,
      maxTilt: _maxTilt,
    );
  }

  void _clearAttempt() {
    _attemptStarted = null;
    _rosePastPartial = false;
    _peakElbow = 0;
  }

  double? _relative(double? span) {
    final baseline = _baselineSpan;
    if (span == null || baseline == null || baseline < 1e-6) return null;
    return span / baseline;
  }

  JudgeSnapshot _snapshot(PoseMetrics? smoothed, double? relative) =>
      JudgeSnapshot(
        phase: _phase,
        elbowAngle: smoothed?.elbowAngle,
        spanRatio: relative ?? smoothed?.spanRatio,
        tilt: smoothed?.tilt,
      );
}
