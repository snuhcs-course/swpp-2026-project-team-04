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
    this.noiseFloor = const Duration(milliseconds: 100),
    this.maxShoulderTilt = 15,
    this.maxFrameGap = const Duration(milliseconds: 500),
    this.maxAttempt = const Duration(seconds: 12),
    this.smoothingTau = const Duration(milliseconds: 65),
    this.baselineTau = const Duration(milliseconds: 500),
    this.minCheatFrames = 3,
    this.maxTorsoDrop = 1.2,
    this.kneeBentAngle = 0,
    this.adoptHipAngle = 160,
    this.defaultKneeHip = 155,
    this.hipFoldWide = 25,
    this.baselineFrames = 3,
    this.hipFoldFromSetup = 20,
    this.straightArmAngle = 160,
    this.minKneeHandGap = -0.22,
    this.maxKneeHandGap = 1.0,
    this.maxHipHandGap = 0.45,
    this.minHipOnFloorGap = -0.08,
    this.minBellyTorsoDrop = 1.1,
    this.minShoulderDrop = 0.7,
    this.bowHipHandGap = -0.6,
    this.bowTorsoDrop = 0.3,
    this.maxShinLiftGap = -0.2,
    this.bowHipRise = -1.5,
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

  /// The shoulders must also drop this far below the top, in top-pose
  /// shoulder widths, for the bottom to count. A head nod moves the nose
  /// alone: on the H1 recordings the valid reps dropped the shoulders 0.75
  /// or more, and half reps with a head nod 0.57 to 0.90. 0.67 was tried
  /// for two slightly shallow reps of a later set and not kept: it left
  /// 0.02 above the highest head nod still caught here, and ten rejected
  /// reps then fell through to the knee and arm checks instead. Without a
  /// shoulder measurement the nose depth decides alone.
  final double minShoulderDrop;

  /// Rising above this depth after the bottom, then going down again
  /// without a lockout, is an incomplete lockout.
  final double partialDepth;

  /// How far the head must go down again, after [partialDepth], to reject.
  final double reDescentDepth;

  /// An attempt that returns to the top sooner than this is dropped, with
  /// no count and no reason. A real push-up cannot finish that quickly;
  /// the dip is tracking noise. How fast a real descent was is form
  /// feedback, not a reason to reject the rep.
  final Duration noiseFloor;

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

  /// Upright body, belly, and the sharp knee fold need the body part in at
  /// least this many frames. A knee latch from the setup baseline is one
  /// frame. Hidden parts never reject a rep.
  final int minCheatFrames;

  /// With the hips seen, a torso drop above this in every such frame means
  /// an upright body, as against a wall. See [torsoDropOf].
  final double maxTorsoDrop;

  /// A shoulder–hip–knee angle below this for [minCheatFrames] frames, in
  /// degrees, is a knee push-up. 0 turns the check off, the default: from
  /// the front the hips are hidden and ML Kit guesses them, so on the H1
  /// recordings this check rejected 13 of 29 normal reps. It was the only
  /// check that caught 4 of the 9 kneeling-bow reps; [bowHipHandGap] now
  /// catches them.
  final double kneeBentAngle;

  // AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
  /// One straight-arm top at or above this, in degrees, is a normal plank
  /// and becomes the personal baseline. Kneeling tops on the two floor
  /// recordings stayed at or below 154°, and real planks stayed at or
  /// above 163°, so a kneeling start cannot set the baseline.
  final double adoptHipAngle;

  /// With no personal baseline yet, a straight-arm top below this is knees.
  /// Someone who kneels from the first frame never produces [adoptHipAngle].
  final double defaultKneeHip;

  /// Degrees more folded than the personal baseline that count as knees
  /// while fewer than [baselineFrames] normal tops have been seen.
  final double hipFoldWide;

  /// Normal tops kept before the knee line tightens to [hipFoldFromSetup].
  /// The value is not refreshed after this, so a later kneel cannot move it.
  final int baselineFrames;

  /// Degrees more folded than the personal baseline, once [baselineFrames]
  /// normal tops have been seen. One such frame at the top is enough.
  final double hipFoldFromSetup;

  /// A rep that reaches the bottom with the elbows still at or above this
  /// never bent the arms. The cat-pose reps did that: the head dropped
  /// while the elbows stayed around 170°. A real rep on that recording
  /// bent to about 105–140°.
  final double straightArmAngle;

  /// [PoseMetrics.kneeHandGap] inside this range means the knees are on the
  /// floor next to the hands. On the floor-camera recording a real plank's
  /// knees still sat 0.28 to 0.47 shoulder widths behind the hands, and the
  /// short kneeling stretch sat about 0.18 to 0.21. The near edge is -0.22
  /// so that plank is not rejected.
  final double minKneeHandGap;
  final double maxKneeHandGap;

  /// [PoseMetrics.hipHandGap] at or below this, and at or above
  /// [minHipOnFloorGap], means the hips came down to the hands.
  /// [minCheatFrames] such frames and a torso drop of [minBellyTorsoDrop]
  /// somewhere in the attempt are the belly on the floor. On the H1
  /// recordings normal reps' hips reached -0.06, so the gap alone is not
  /// enough.
  final double maxHipHandGap;
  final double minHipOnFloorGap;

  /// Torso drop, in shoulder widths, of a belly on the floor. Belly reps on
  /// the H1 recordings reached 1.13 to 1.30 and normal reps 1.08 at most.
  /// Knee reps reached 1.10 (a kneeling bow) and 1.64 (straight arms on the
  /// knees), but without three frames of hips at the hands.
  final double minBellyTorsoDrop;

  /// At the attempt's deepest frame, hips at or above this
  /// [PoseMetrics.hipHandGap] with a torso drop at or below [bowTorsoDrop]
  /// are a kneeling bow: the hips sat back over the heels while the head
  /// went down. On the H2 recordings 16 of 20 bow reps read -1.21 to
  /// -0.74 with a torso drop of 0.0 or less; the other 4 read -0.52 to
  /// -0.37. Normal reps read -0.54 at most with a torso drop under 0.3
  /// (-0.79 only with 0.75), reps far from the phone -0.13 to -0.16, and
  /// knee push-ups -0.14 to -0.32.
  final double bowHipHandGap;
  final double bowTorsoDrop;

  /// Shins lifted at the top are a knee push-up: [PoseMetrics.ankleKneeGap]
  /// at or below this in at least half of the last straight-arm top frames
  /// before the descent, and in at least [minCheatFrames] of them. A top
  /// frame with hidden ankles counts as not lifted. On the H2 recordings,
  /// the median over each rep's top frames (head within 0.3 shoulder widths
  /// of its highest, elbows at 150° or more): normal reps -0.14 to +0.02,
  /// knee push-ups of the session-2 and session-3 sets -0.27 to -0.19
  /// (other windows read a little lower); session 1's knee set read -0.21
  /// to -0.04 and is caught by the knee line instead. Only the last frames
  /// count: walking back from the phone between reps reads -0.56. During
  /// the descent the readings overlap, so they are not used. -0.21 to
  /// -0.19 change only three reps: two knee reps at -0.21, and rep 6 of an
  /// unlabelled set whose last top frames (-0.13 to -0.25) match the user's
  /// kneeling reps after it, not the normal reps before it (-0.03 to
  /// -0.10).
  final double maxShinLiftGap;

  /// [PoseMetrics.hipHandGap] at the deepest frame minus its median over
  /// the last top frames before the descent, at or below this, is a
  /// kneeling bow: the hips went back over the heels while the head went
  /// down. It does not look at the arms, so a bow is caught whether the
  /// elbows stay straight or fold on the way down. On the H2 recordings 24
  /// of 34 bow reps moved -4.0 to -1.12 (every bow that kept the arms
  /// straight among them), normal reps +0.02 or more (one far rep -0.90),
  /// knee push-ups +0.11 or more, head-nod half reps -0.08 or more. Any
  /// line from -0.8 to -2.0 gave the same verdicts.
  final double bowHipRise;
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
    this.shoulderDrop,
    this.topShoulderY,
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

  /// How far the shoulders have dropped below the top pose, in shoulder
  /// widths. Compared with [depth] to see whether the head led the chest.
  final double? shoulderDrop;

  /// Calibrated shoulder midpoint in upright image pixels, for visual guidance.
  final double? topShoulderY;
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
/// usually hidden, so knees, belly, and an upright body are judged only in
/// attempts where those parts were seen. Otherwise the rep stands.
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
  double? _topShoulderY;
  double? _topWidth;
  double _maxDepth = 0;
  double _highestSinceBottom = 0;
  double? _minElbow;
  double _maxTilt = 0;
  double? _previousTilt;
  int _nextIndex = 1;

  int _torsoFrames = 0;
  double _minTorsoDrop = double.infinity;
  int _kneeBentFrames = 0;
  int _kneeFloorFrames = 0;
  bool _kneesLatched = false;
  Duration? _straightHipSince;
  double? _baselineHip;
  final List<double> _baselineHips = [];
  int _hipHandFrames = 0;
  final List<bool> _topShins = [];
  bool _shinsLifted = false;
  final List<double> _topHipHand = [];
  double? _attemptTopHipHand;
  double _maxTorsoDrop = double.negativeInfinity;
  double? _deepHipHandGap;
  double? _deepTorsoDrop;

  /// Time from the start of the attempt until the head first reached the
  /// bottom. Null until then.
  Duration? _descent;

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
    _topShoulderY = null;
    _topWidth = null;
    _kneesLatched = false;
    _straightHipSince = null;
    _baselineHip = null;
    _baselineHips.clear();
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
    _topShoulderY = null;
    _topWidth = null;
    _kneesLatched = false;
    _straightHipSince = null;
    _baselineHip = null;
    _baselineHips.clear();
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
      // The frame that becomes ready is already a straight-arm top. Judge
      // it now, so a kneel from the first moment latches before the descent.
      if (_phase != RepPhase.up) {
        _watchKnees(raw);
        return RepUpdate(snapshot: _snapshot(elbow, smoothed, tilt));
      }
    }

    final depth = _depth(smoothed)!;
    _watchKnees(raw);
    if (_phase == RepPhase.up) {
      _followTop(elbow, depth, smoothed, dt);
      _lockSetupHip(elbow, depth, raw);
      _watchKneeFromSetup(elbow, depth, raw);
      _clearKneeLatchIfPlank(now, elbow, depth, raw);
      _watchShinsAtTop(elbow, depth, raw);
      _watchHipsAtTop(depth, raw);
      if (depth >= config.enterDepth) {
        final count = _topShins.where((l) => l).length;
        final lifted =
            count >= config.minCheatFrames && count * 2 >= _topShins.length;
        final topHipHand = _median(_topHipHand);
        _beginAttempt(now, depth);
        _shinsLifted = lifted;
        _attemptTopHipHand = topHipHand;
      }
    }

    if (_phase == RepPhase.descending || _phase == RepPhase.bottom) {
      if (depth >= _maxDepth) {
        // Hidden hips at the deepest frame leave no bow reading.
        _deepHipHandGap = raw.hipHandGap;
        _deepTorsoDrop = raw.torsoDrop;
      }
      _maxDepth = math.max(_maxDepth, depth);
      if (elbow != null) _minElbow = math.min(_minElbow ?? elbow, elbow);
      _watchLowerBody(raw);
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

    // A hidden shoulder keeps its last smoothed value; it must not hold the
    // rep above the bottom.
    final shoulderDrop = raw.shoulderY == null ? null : _shoulderDrop(smoothed);
    final event = _advance(now, depth, shoulderDrop, elbow);
    return RepUpdate(snapshot: _snapshot(elbow, smoothed, tilt), event: event);
  }

  RepEvent? _advance(
    Duration now,
    double depth,
    double? shoulderDrop,
    double? elbow,
  ) {
    if (_phase == RepPhase.descending) {
      final shouldersDown =
          shoulderDrop == null || shoulderDrop >= config.minShoulderDrop;
      if (depth >= config.bottomDepth && shouldersDown) {
        _phase = RepPhase.bottom;
        _highestSinceBottom = depth;
        _descent ??= now - _attemptStarted!;
      } else if (depth <= config.topDepth) {
        final event = _tooBrief(now) || _maxDepth < config.shallowDepth
            ? null
            : _emit(now, RejectReason.insufficientDepth);
        _finishAtTop();
        return event;
      }
    }

    if (_phase == RepPhase.bottom) {
      _highestSinceBottom = math.min(_highestSinceBottom, depth);
      final armsExtended = elbow == null || elbow >= config.topAngle;
      if (depth <= config.topDepth && armsExtended) {
        final event = _tooBrief(now) ? null : _complete(now);
        _finishAtTop();
        return event;
      }
      if (_highestSinceBottom <= config.partialDepth &&
          depth - _highestSinceBottom >= config.reDescentDepth) {
        // A flicker this short is not a missed lockout. Keep judging.
        // The re-attempt sees no top frames, so it keeps the shin verdict
        // as it keeps the knee latch.
        final shinsLifted = _shinsLifted;
        final topHipHand = _attemptTopHipHand;
        if (_tooBrief(now)) {
          _beginAttempt(now, depth);
          _shinsLifted = shinsLifted;
          _attemptTopHipHand = topHipHand;
          return null;
        }
        final event = _emit(now, _withKnees(RejectReason.incompleteExtension));
        _beginAttempt(now, depth);
        _shinsLifted = shinsLifted;
        _attemptTopHipHand = topHipHand;
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
      _topShoulderY = smoothed.shoulderY ?? _topShoulderY;
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
    final shoulderY = smoothed.shoulderY;
    if (shoulderY != null) {
      final top = _topShoulderY;
      _topShoulderY = top == null ? shoulderY : top + alpha * (shoulderY - top);
    }
    final width = smoothed.shoulderWidth;
    if (width != null) _topWidth = _topWidth! + alpha * (width - _topWidth!);
  }

  /// Normal plank tops. The first one is kept immediately, with a wider
  /// knee line. After [RepJudgeConfig.baselineFrames] the line tightens
  /// and the value freezes, so a later kneel cannot become the baseline.
  void _lockSetupHip(double? elbow, double depth, PoseMetrics raw) {
    if (_baselineHips.length >= config.baselineFrames) return;
    final hip = raw.hipAngle;
    final openTop =
        elbow != null &&
        elbow >= config.topAngle &&
        depth < config.topDepth &&
        hip != null &&
        hip >= config.adoptHipAngle;
    if (!openTop) return;
    _baselineHips.add(hip);
    _baselineHip = _baselineValue();
  }

  /// One sample is that angle. Two are their mean. Three are the median.
  double _baselineValue() {
    final sorted = [..._baselineHips]..sort();
    if (sorted.length == 2) return (sorted[0] + sorted[1]) / 2;
    return sorted[sorted.length ~/ 2];
  }

  /// Wider until three normal tops have been seen, then the tight line.
  double get _foldMargin => _baselineHips.length >= config.baselineFrames
      ? config.hipFoldFromSetup
      : config.hipFoldWide;

  /// One straight-arm frame at the top. With a personal baseline, folded
  /// [_foldMargin] past it. With none, below [RepJudgeConfig.defaultKneeHip],
  /// which is how a kneel from the first frame is caught. The descent can
  /// open the angle again; the latch stays.
  void _watchKneeFromSetup(double? elbow, double depth, PoseMetrics raw) {
    final hip = raw.hipAngle;
    if (hip == null || elbow == null) return;
    if (elbow < config.topAngle || depth >= config.topDepth) return;
    final base = _baselineHip;
    if (base != null) {
      if (hip <= base - _foldMargin) _kneesLatched = true;
    } else if (hip < config.defaultKneeHip) {
      _kneesLatched = true;
    }
  }

  /// Shoulder–hip–knee angle. Three frames below [RepJudgeConfig.kneeBentAngle]
  /// latch the rep as knees. A straighter frame clears that streak, not the
  /// latch: the fold was at the top, and it opens again on the way down.
  void _watchKnees(PoseMetrics raw) {
    final hipAngle = raw.hipAngle;
    if (hipAngle == null) return;
    if (hipAngle < config.kneeBentAngle) {
      _kneeBentFrames++;
      if (_kneeBentFrames >= config.minCheatFrames) _kneesLatched = true;
    } else {
      _kneeBentFrames = 0;
    }
  }

  /// A plank top, arms straight and hips open, forgets an earlier knee latch
  /// so the next rep can count. Hidden hips do the same after [topHold]: a
  /// part that is not seen does not keep rejecting.
  void _clearKneeLatchIfPlank(
    Duration now,
    double? elbow,
    double depth,
    PoseMetrics raw,
  ) {
    final hip = raw.hipAngle;
    final base = _baselineHip;
    final backToSetup =
        hip == null ||
        (base == null ? hip >= config.adoptHipAngle : hip > base - _foldMargin);
    final plank =
        elbow != null &&
        elbow >= config.topAngle &&
        depth < config.topDepth &&
        backToSetup;
    if (!plank) {
      _straightHipSince = null;
      return;
    }
    _straightHipSince ??= now;
    if (now - _straightHipSince! >= config.topHold) _kneesLatched = false;
  }

  /// Records what the attempt showed of the hips and knees, raw: the cheat
  /// checks count frames, so one noisy frame cannot reject a rep alone. The
  /// belly's torso drop is the attempt's peak, though: on the H1 belly reps
  /// it never came in the same frames as the hips at the hands, so one
  /// noisy torso frame can add to three hip frames.
  void _watchLowerBody(PoseMetrics raw) {
    final drop = raw.torsoDrop;
    if (drop != null) {
      _torsoFrames++;
      _minTorsoDrop = math.min(_minTorsoDrop, drop);
      _maxTorsoDrop = math.max(_maxTorsoDrop, drop);
    }
    final kneeGap = raw.kneeHandGap;
    if (kneeGap != null) {
      // Knees next to the hands are on the floor. Knees far behind the
      // hands are a plank, and one such frame clears a flicker. A hidden
      // knee leaves the count alone.
      if (kneeGap >= config.minKneeHandGap &&
          kneeGap <= config.maxKneeHandGap) {
        _kneeFloorFrames++;
      } else {
        _kneeFloorFrames = 0;
      }
    }
    final hipGap = raw.hipHandGap;
    if (hipGap != null &&
        hipGap >= config.minHipOnFloorGap &&
        hipGap <= config.maxHipHandGap) {
      _hipHandFrames++;
    }
  }

  /// Knees were seen on the floor for [RepJudgeConfig.minCheatFrames]
  /// consecutive frames, either folded or sitting next to the hands, or the
  /// hips sat back in a kneeling bow.
  bool _kneesDown() {
    final frames = config.minCheatFrames;
    return _kneesLatched ||
        _kneeBentFrames >= frames ||
        _kneeFloorFrames >= frames ||
        _shinsLifted ||
        _bowedBack();
  }

  /// The arms may lock out at the top of a bow, so it is told apart by the
  /// hips at the bottom, not the elbows: front-view elbow angles of bows
  /// and normal reps overlap.
  bool _bowedBack() {
    final gap = _deepHipHandGap;
    final drop = _deepTorsoDrop;
    final top = _attemptTopHipHand;
    if (gap != null && top != null && gap - top <= config.bowHipRise) {
      return true;
    }
    return gap != null &&
        drop != null &&
        gap <= config.bowHipHandGap &&
        drop <= config.bowTorsoDrop;
  }

  /// Straight arms through the bottom of a rep already seen on the knees.
  /// A plank that simply keeps the elbows extended, with the hips open,
  /// still counts. The cat pose had both: the fold, and elbows that stayed
  /// around 170°. On H1's straight-arm reps on the knees, the knees showed
  /// by the hands as often as by the fold, so either one is enough.
  bool _armsNeverBent() =>
      _kneesDown() &&
      _minElbow != null &&
      _minElbow! >= config.straightArmAngle &&
      _maxDepth >= config.bottomDepth;

  bool _uprightTorso() =>
      _torsoFrames >= config.minCheatFrames &&
      _minTorsoDrop > config.maxTorsoDrop;

  /// A kneeling body replaces a missed lockout. A rep that never reached
  /// depth stays insufficient depth. The hips of a knee push-up barely
  /// move, which is not the belly resting on the floor.
  RejectReason _withKnees(RejectReason reason) =>
      _kneesDown() ? RejectReason.kneesDown : reason;

  /// The cheat seen in this attempt, if any. Arms and a setup-baseline
  /// kneel do not use [RepJudgeConfig.minCheatFrames]; an upright body and
  /// a belly on the floor do.
  RejectReason? _cheat() {
    if (_armsNeverBent() && !_uprightTorso()) return RejectReason.armsStraight;
    if (_bellyOnFloor()) return RejectReason.bellyDown;
    if (_kneesDown()) return RejectReason.kneesDown;
    if (_uprightTorso()) return RejectReason.notFloorPushUp;
    return null;
  }

  /// Hips down at the hands with the torso sagging. Checked before the
  /// knees: a sagging belly also folds the hip angle at the top, which
  /// used to close every belly rep as knees. Hips that merely stay put, as
  /// they do when the knees hold them up, do not sag the torso.
  bool _bellyOnFloor() =>
      _hipHandFrames >= config.minCheatFrames &&
      _maxTorsoDrop >= config.minBellyTorsoDrop;

  static const _shinWindow = 10;

  /// Keeps the last straight-arm top frames before the descent and whether
  /// their shins read lifted.
  void _watchShinsAtTop(double? elbow, double depth, PoseMetrics raw) {
    if (elbow == null || elbow < config.topAngle) return;
    if (depth >= config.enterDepth) return;
    // Hidden ankles push out older readings, so a part no longer seen
    // cannot reject the rep.
    final gap = raw.ankleKneeGap;
    _topShins.add(gap != null && gap <= config.maxShinLiftGap);
    if (_topShins.length > _shinWindow) _topShins.removeAt(0);
  }

  /// Keeps the last top-frame hip–hand gaps before the descent. Hidden
  /// hips are skipped: an older reading left in the window sat lower, so it
  /// can only make the rise smaller, never reject a rep.
  void _watchHipsAtTop(double depth, PoseMetrics raw) {
    if (depth >= config.enterDepth) return;
    final gap = raw.hipHandGap;
    if (gap == null) return;
    _topHipHand.add(gap);
    if (_topHipHand.length > _shinWindow) _topHipHand.removeAt(0);
  }

  double? _median(List<double> values) {
    if (values.length < config.minCheatFrames) return null;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  void _beginAttempt(Duration now, double depth) {
    _phase = RepPhase.descending;
    _attemptStarted = now;
    _maxDepth = depth;
    _highestSinceBottom = depth;
    _minElbow = null;
    _maxTilt = 0;
    _descent = null;
    _clearLowerBody();
  }

  void _clearLowerBody() {
    _torsoFrames = 0;
    _minTorsoDrop = double.infinity;
    _kneeBentFrames = 0;
    _kneeFloorFrames = 0;
    _hipHandFrames = 0;
    _maxTorsoDrop = double.negativeInfinity;
    _topShins.clear();
    _shinsLifted = false;
    _topHipHand.clear();
    _attemptTopHipHand = null;
    _deepHipHandGap = null;
    _deepTorsoDrop = null;
  }

  void _finishAtTop() {
    _phase = RepPhase.up;
    _clearAttempt();
  }

  /// True when this attempt is too short to be a push-up. The caller drops
  /// it without [_emit], so it takes no index and shows no reason.
  bool _tooBrief(Duration now) {
    final started = _attemptStarted;
    return started != null && now - started < config.noiseFloor;
  }

  RepEvent _complete(Duration now) {
    final RejectReason? reason;
    final cheat = _cheat();
    if (cheat != null) {
      reason = cheat;
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
    descent: _descent,
  );

  void _clearAttempt() {
    _attemptStarted = null;
    _maxDepth = 0;
    _highestSinceBottom = 0;
    _minElbow = null;
    _maxTilt = 0;
    _previousTilt = null;
    _descent = null;
    _clearLowerBody();
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

  double? _shoulderDrop(PoseMetrics smoothed) {
    final top = _topShoulderY;
    final width = _topWidth;
    final shoulder = smoothed.shoulderY;
    if (top == null || width == null || width < 1e-6 || shoulder == null) {
      return null;
    }
    return (shoulder - top) / width;
  }

  JudgeSnapshot _snapshot(double? elbow, PoseMetrics smoothed, double? tilt) =>
      JudgeSnapshot(
        phase: _phase,
        elbowAngle: elbow,
        depth: _depth(smoothed),
        tilt: tilt,
        shoulderDrop: _shoulderDrop(smoothed),
        topShoulderY: _topShoulderY,
      );
}
