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
    this.topHold = const Duration(milliseconds: 250),
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
    this.defaultKneeHip = 0,
    this.hipFoldWide = 25,
    this.baselineFrames = 3,
    this.hipFoldFromSetup = 20,
    this.straightArmAngle = 160,
    this.minKneeHandGap = -0.22,
    this.maxKneeHandGap = 1.0,
    this.maxHipHandGap = 0.45,
    this.minHipOnFloorGap = -0.08,
    this.minBellyTorsoDrop = 1.1,
    this.minShoulderDrop = 0.68,
    this.deepElbowAngle = 100,
    this.lockoutArmAngle = 172,
    this.bowHipHandGap = -0.9,
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
  /// or more, and half reps with a head nod 0.57 to 0.90. The line was
  /// 0.70 until testers found it too strict. At 0.68 no recorded rep goes
  /// from rejected to counted; eight rejected reps fall through from the
  /// depth check to the knee and arm checks, and the highest head nod still
  /// caught here (0.65) is 0.03 under the line. Without a shoulder
  /// measurement the nose depth decides alone.
  final double minShoulderDrop;

  /// Elbows bent to this or less, in degrees, with the head at least
  /// [shallowDepth] down, also reach the bottom, whatever [bottomDepth] and
  /// [minShoulderDrop] say. Both lines are in shoulder widths, and on the
  /// AI evaluation set (2026-11-02) one tester's normal reps bent the
  /// elbows to 68–89° while the head went down only 1.03–1.34 and the
  /// shoulders stayed under the line. Head-nod half reps read 103° or more
  /// on every set, so they stay shallow. 0 turns the check off.
  final double deepElbowAngle;

  /// The less extended arm must reach this, in degrees, in the frame that
  /// closes a rep at the top (raw, not smoothed). The
  /// average of both arms ([topAngle]) let one bent arm hide behind the
  /// other, so reps that came up short counted. On the evaluation set the
  /// tops of the deliberately short set read 143–171° on most reps, and
  /// every counted normal rep before the evaluation reached 174° or more.
  /// A frame without both elbows skips the check. The top pose still
  /// follows the user on [topAngle] alone: stopping it there let more
  /// head-nod reps through. Even so the check has a cost on the earlier
  /// fixtures: with it, head-nod reps 3 and 4 of one set count instead of
  /// closing as knees, and three knee reps close as belly. 0 turns the
  /// check off.
  final double lockoutArmAngle;

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
  /// 0 turns the check off, the default: one frame is enough to latch, and
  /// on the AI evaluation set (2026-11-02) planks read a median hip angle
  /// of 160–162° on one tester, so normal reps latched. Turning it off
  /// let no labelled knee rep through; the fold from a personal baseline
  /// ([hipFoldFromSetup]) still applies.
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
  /// knee push-ups -0.14 to -0.32. The line was -0.6 until the AI
  /// evaluation set (2026-11-02): with the phone at 79–85° one tester's
  /// normal reps read a median of -0.74, so they closed as knees. At -0.9
  /// [bowHipRise] still catches the bows of the evaluation set; one bow
  /// rep of an earlier recording now counts.
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
    this.squatHipY,
    this.squatKneeY,
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

  /// Mean heights of the usable sides in the current squat frame.
  final double? squatHipY;
  final double? squatKneeY;
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
  RepJudge({
    this.config = const RepJudgeConfig(),
    RepClock? clock,
    this.useMlp = const bool.fromEnvironment('PUSHUP_MLP'),
  }) : _clock = clock ?? _stopwatchClock(),
       _smoother = MetricSmoother(tau: config.smoothingTau);

  final RepJudgeConfig config;

  /// Enables the user-requested local binary model experiment in this build.
  final bool useMlp;
  final RepClock _clock;
  final MetricSmoother _smoother;
  double? _frameTiltDegrees;
  final _spanDetector = PushupSpanDetector();
  final _spanHistory = PushupSpanHistory();
  final _spanArbiter = PushupSpanArbiter();
  Duration? _previousPrimaryAt;
  late final _mlpHistory = PushupMlpHistory();
  late final _mlpProposals = PushupWideProposalDetector();
  int _mlpNextIndex = 1;
  Duration? _mlpLastAt;
  late final _ShortCycleFeedback _shortCycle = _ShortCycleFeedback(config);
  double _travelScale = 1;
  double _topTorsoSum = 0;
  int _topTorsoFrames = 0;

  double get _enterDepth => config.enterDepth * _travelScale;
  double get _topDepth => config.topDepth * _travelScale;
  double get _shallowDepth => config.shallowDepth * _travelScale;
  double get _bottomDepth => config.bottomDepth * _travelScale;

  RepPhase _phase = RepPhase.idle;
  Duration? _lastAt;
  Duration? _topSince;
  Duration? _attemptStarted;

  /// A pending verdict from either head-based cycle takes priority over a
  /// projected arm-span verdict for the same movement.
  Duration? get openPrimaryAttempt => _attemptStarted ?? _shortCycle._started;
  double? _topNoseY;
  double? _topShoulderY;
  double? _topWidth;
  double _maxDepth = 0;
  double _highestSinceBottom = 0;
  bool _ordinaryBottom = false;
  bool _sawStraightAtBottom = false;
  double? _bentAtBottom;
  bool get _needsVisibleCycle => _travelScale < 1 && !_ordinaryBottom;
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
  double? _lessArm;

  /// Time from the start of the attempt until the head first reached the
  /// bottom. Null until then.
  Duration? _descent;

  static RepClock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// Clears the state machine and the rep index.
  void reset() {
    if (useMlp) {
      _mlpHistory.reset();
      _mlpProposals.reset();
      _mlpLastAt = null;
      _mlpNextIndex = 1;
    }
    _resetSpan();
    _phase = RepPhase.idle;
    _lastAt = null;
    _topSince = null;
    _clearAttempt();
    _topNoseY = null;
    _topShoulderY = null;
    _topWidth = null;
    _resetCalibration();
    _kneesLatched = false;
    _straightHipSince = null;
    _baselineHip = null;
    _baselineHips.clear();
    _lessArm = null;
    _nextIndex = 1;
    _smoother.reset();
  }

  /// Drops the attempt in progress without forgetting reps already emitted.
  ///
  /// Used when the camera hiccups: the next rep keeps the following index.
  void abandon() {
    if (useMlp) {
      _mlpHistory.reset();
      _mlpProposals.reset();
      _mlpLastAt = null;
    }
    _resetSpan();
    _abandonHead();
  }

  void _resetSpan() {
    _spanDetector.reset();
    _spanHistory.reset();
    _spanArbiter.reset();
    _previousPrimaryAt = null;
  }

  void _abandonHead() {
    _phase = RepPhase.lost;
    _topSince = null;
    _clearAttempt();
    _topNoseY = null;
    _topShoulderY = null;
    _topWidth = null;
    _resetCalibration();
    _kneesLatched = false;
    _straightHipSince = null;
    _baselineHip = null;
    _baselineHips.clear();
    _lessArm = null;
    _smoother.reset();
  }

  /// The gravity reading is valid for this image only. Direct video replay
  /// uses [update] when no phone sensor was recorded.
  RepUpdate updateWithPhoneTilt(PoseFrame frame, double? tiltDegrees) {
    final previous = _frameTiltDegrees;
    _frameTiltDegrees = tiltDegrees;
    try {
      return update(frame);
    } finally {
      _frameTiltDegrees = previous;
    }
  }

  /// Judges [frame] and maybe closes one rep.
  RepUpdate update(PoseFrame frame) {
    final now = _clock();
    if (useMlp) return _updateMlp(frame, now);
    _spanHistory.add(frame, now);
    final cycle = _spanDetector.update(
      frame,
      now,
      phoneAngleDegrees: _frameTiltDegrees,
    );
    final primaryOnset = openPrimaryAttempt;
    var head = _updateHead(frame, now);
    final event = head.event;
    if (event != null) {
      final start = _spanHistory.primaryWindowStart(now, _previousPrimaryAt);
      _previousPrimaryAt = now;
      if (start != null) {
        final values = _spanHistory.evidence(
          start: start,
          bottom: start + (now - start) ~/ 2,
          end: now,
        );
        final calibrated = calibratePushupPrimary(
          event,
          values,
          observedReturn:
              primaryOnset != null &&
              _spanHistory.observedReturn(
                frame,
                start,
                now,
                notBefore: primaryOnset,
                lockout: config.lockoutArmAngle > 0
                    ? math.max(165, config.lockoutArmAngle)
                    : 165,
              ),
          lockoutAngle: config.lockoutArmAngle,
        );
        head = RepUpdate(snapshot: head.snapshot, event: calibrated);
      }
    }
    final extra = _spanArbiter.update(
      now,
      primaryEvent: head.event != null,
      // The shorter head/chest cycle can close one or two frames after the
      // arm span recovers while the main phase already reports "up".
      primaryAttemptStarted: openPrimaryAttempt,
      cycle: cycle,
      reason: cycle == null
          ? null
          : _spanHistory.reasonFor(
              start: cycle.start,
              bottom: cycle.bottom,
              end: cycle.end,
              phoneAngleDegrees: switch (_spanDetector.band) {
                PushupPhoneBand.near60 => 60,
                PushupPhoneBand.near80 => 80,
                PushupPhoneBand.unknown => null,
              },
            ),
    );
    if (extra == null) return head;
    return RepUpdate(
      snapshot: head.snapshot,
      event: RepEvent(
        index: _nextIndex++,
        valid: false,
        at: now,
        reason: extra.reason,
        descent: extra.cycle.bottom - extra.cycle.start,
      ),
    );
  }

  RepUpdate _updateMlp(PoseFrame frame, Duration now) {
    if (_mlpLastAt != null &&
        (now <= _mlpLastAt! || now - _mlpLastAt! > config.maxFrameGap)) {
      _mlpHistory.reset();
      _mlpProposals.reset();
      _abandonHead();
    }
    _mlpLastAt = now;
    _mlpHistory.add(frame, now);
    // The proposal model was trained with this earlier head/short-cycle
    // counter as one input. The newer binary calibration is a separate model.
    final primary = _updateHead(frame, now);
    final proposal = _mlpProposals.update(frame, now, primary: primary.event);
    if (proposal == null) return RepUpdate(snapshot: primary.snapshot);
    final features = _mlpHistory.featuresForProposal(now);
    final probability = PushupMlpModel.normalProbability(features);
    final kneesDown = PushupKneeModel.rejects(features);
    final valid = probability > .5 && !kneesDown;
    final previous = primary.event;
    final reason = valid
        ? null
        : kneesDown
        ? RejectReason.kneesDown
        : previous?.reason ?? _cheat() ?? RejectReason.insufficientDepth;
    return RepUpdate(
      snapshot: primary.snapshot,
      event: RepEvent(
        index: _mlpNextIndex++,
        at: now,
        valid: valid,
        reason: reason,
        maxDepth: previous?.maxDepth,
        minElbowAngle: previous?.minElbowAngle,
        maxTilt: previous?.maxTilt,
        descent: previous?.descent,
      ),
    );
  }

  RepUpdate _updateHead(PoseFrame frame, Duration now) {
    final gap = _lastAt == null ? Duration.zero : now - _lastAt!;
    if (gap > config.maxFrameGap) _abandonHead();

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
      _holdTop(now, elbow, smoothed, raw);
      // The frame that becomes ready is already a straight-arm top. Judge
      // it now, so a kneel from the first moment latches before the descent.
      if (_phase != RepPhase.up) {
        _watchKnees(raw);
        return RepUpdate(snapshot: _snapshot(elbow, smoothed, tilt));
      }
    }

    final depth = _depth(smoothed)!;
    // Do not use a carried-forward shoulder position when the shoulders are hidden.
    final shoulderDrop = raw.shoulderY == null ? null : _shoulderDrop(smoothed);
    _watchKnees(raw);
    if (_phase == RepPhase.up) {
      _followTop(elbow, depth, smoothed, dt);
      _lockSetupHip(elbow, depth, raw);
      _watchKneeFromSetup(elbow, depth, raw);
      _clearKneeLatchIfPlank(now, elbow, depth, raw);
      _watchShinsAtTop(elbow, depth, raw);
      _watchHipsAtTop(depth, raw);
      if (depth >= _enterDepth) {
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
        _resetCalibration();
        _previousTilt = tilt;
        return RepUpdate(snapshot: _snapshot(elbow, smoothed, tilt));
      }
    }
    _previousTilt = tilt;

    _watchLessArm(raw);
    _observeBottom(depth, shoulderDrop, elbow, raw);
    var event = _advance(now, depth, shoulderDrop, elbow);
    // A normal attempt owns the verdict once it reaches full depth. A small
    // dip can only report a form fault, and it never emits a second verdict.
    if (event != null ||
        _phase == RepPhase.bottom ||
        depth >= config.shallowDepth) {
      _shortCycle.reset();
    } else {
      event = _shortCycle.update(
        now,
        depth,
        shoulderDrop,
        elbow,
        raw,
        _nextIndex,
      );
      if (event != null) _nextIndex++;
    }
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
          shoulderDrop == null ||
          shoulderDrop >= config.minShoulderDrop * _travelScale;
      final elbowsDeep =
          config.deepElbowAngle > 0 &&
          elbow != null &&
          elbow <= config.deepElbowAngle &&
          depth >= _shallowDepth;
      if ((depth >= _bottomDepth && shouldersDown) || elbowsDeep) {
        _phase = RepPhase.bottom;
        _highestSinceBottom = depth;
        _descent ??= now - _attemptStarted!;
      } else if (depth <= _topDepth) {
        final reason = _shallowReason(_maxTilt, _minElbow);
        final event = _tooBrief(now) || _maxDepth < _shallowDepth
            ? null
            : _emit(now, reason);
        _finishAtTop();
        return event;
      }
    }

    if (_phase == RepPhase.bottom) {
      _highestSinceBottom = math.min(_highestSinceBottom, depth);
      final armsExtended =
          (elbow == null || elbow >= config.topAngle) && _lessArmLockedOut();
      if (depth <= _topDepth && armsExtended && _returnObserved) {
        final event = _tooBrief(now) ? null : _closeAtTop(now);
        _finishAtTop();
        return event;
      }
      if (_highestSinceBottom <= config.partialDepth * _travelScale &&
          depth - _highestSinceBottom >= config.reDescentDepth * _travelScale) {
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

  void _observeBottom(
    double depth,
    double? shoulderDrop,
    double? elbow,
    PoseMetrics raw,
  ) {
    if (!_needsVisibleCycle ||
        (_phase != RepPhase.descending && _phase != RepPhase.bottom)) {
      return;
    }
    // A rep reaching the original bottom still follows the original lockout
    // rules, even if the camera briefly loses the wrists at full extension.
    final elbowsDeep =
        config.deepElbowAngle > 0 &&
        elbow != null &&
        elbow <= config.deepElbowAngle;
    if ((depth >= config.bottomDepth &&
            (shoulderDrop == null || shoulderDrop >= config.minShoulderDrop)) ||
        (depth >= config.shallowDepth && elbowsDeep)) {
      _ordinaryBottom = true;
      return;
    }

    // At the reduced depth a head-only dip is insufficient. Both arms must
    // actually bend while the shoulders descend in that same visible frame.
    if (shoulderDrop == null ||
        shoulderDrop < config.minShoulderDrop * _travelScale ||
        (depth < config.bottomDepth * _travelScale &&
            !(depth >= config.shallowDepth * _travelScale && elbowsDeep))) {
      return;
    }
    final left = raw.leftElbowAngle, right = raw.rightElbowAngle;
    if (left == null || right == null) return;
    final straighter = math.max(left, right);
    if (straighter <= 150) {
      _bentAtBottom = math.min(_bentAtBottom ?? straighter, straighter);
    }
    if (math.min(left, right) >= config.straightArmAngle) {
      _sawStraightAtBottom = true;
    }
  }

  /// A reduced-depth attempt must show the return of both arms. If the
  /// bottom itself was unobserved, it can close only with a rejection.
  bool get _returnObserved {
    final bent = _bentAtBottom;
    final arm = _lessArm;
    return !_needsVisibleCycle ||
        bent == null ||
        (arm != null && arm >= config.topAngle && arm - bent >= 14);
  }

  /// The less extended arm in this frame, or null without both elbows.
  void _watchLessArm(PoseMetrics raw) {
    final left = raw.leftElbowAngle, right = raw.rightElbowAngle;
    _lessArm = left == null || right == null ? null : math.min(left, right);
  }

  bool _lessArmLockedOut() {
    final arm = _lessArm;
    return config.lockoutArmAngle == 0 ||
        arm == null ||
        arm >= config.lockoutArmAngle;
  }

  void _resetCalibration() {
    _shortCycle.reset();
    _travelScale = 1;
    _topTorsoSum = 0;
    _topTorsoFrames = 0;
  }

  void _holdTop(
    Duration now,
    double? elbow,
    PoseMetrics smoothed,
    PoseMetrics raw,
  ) {
    if (elbow == null) return;
    if (elbow < config.topAngle || smoothed.shoulderWidth == null) {
      _topSince = null;
      _resetCalibration();
      return;
    }
    _topSince ??= now;
    final torso = raw.torsoDrop;
    if (torso != null && raw.handsBelowShoulders) {
      _topTorsoSum += torso;
      _topTorsoFrames++;
    }
    if (now - _topSince! >= config.topHold) {
      // A higher viewpoint compresses vertical motion. Calibrate only when
      // at least two visible straight-arm poses support this perspective.
      if (_topTorsoFrames >= 2 && _topTorsoSum / _topTorsoFrames <= 0.60) {
        _travelScale = 0.64;
      }
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
    if (depth >= _enterDepth) return;
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
        depth < _topDepth &&
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
    if (elbow < config.topAngle || depth >= _topDepth) return;
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
  /// so the next rep can count. Hidden hips do the same after a hold: a
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
        depth < _topDepth &&
        backToSetup;
    if (!plank) {
      _straightHipSince = null;
      return;
    }
    _straightHipSince ??= now;
    // Keep the former 300 ms knee-latch release minimum even when the
    // initial top-pose hold is shorter. Occluded hips alone must not clear a
    // recent knee verdict any earlier.
    const minimumKneeRelease = Duration(milliseconds: 300);
    final releaseHold = config.topHold < minimumKneeRelease
        ? minimumKneeRelease
        : config.topHold;
    if (now - _straightHipSince! >= releaseHold) _kneesLatched = false;
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
      _maxDepth >= _bottomDepth;

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
    if (depth >= _enterDepth) return;
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
    if (depth >= _enterDepth) return;
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
    _ordinaryBottom = false;
    _sawStraightAtBottom = false;
    _bentAtBottom = null;
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

  RepEvent _closeAtTop(Duration now) {
    if (_needsVisibleCycle && _bentAtBottom == null) {
      final straight =
          _sawStraightAtBottom &&
          _minElbow != null &&
          _minElbow! >= config.straightArmAngle;
      return _emit(
        now,
        straight ? RejectReason.armsStraight : RejectReason.insufficientDepth,
      );
    }
    return _complete(now);
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
    reason: _refinePartial(
      reason,
      maxDepth: _maxDepth,
      minElbow: _minElbow,
      maxTilt: _maxTilt,
      bottomHipHandGap: _deepHipHandGap,
      topHipHandGap: _attemptTopHipHand,
      supportedKnee: _kneesDown(),
    ),
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

/// A tilted partial rep needs visible arm flexion to distinguish it from a nod.
RejectReason _shallowReason(double? sustainedTilt, double? minElbow) =>
    sustainedTilt != null &&
        sustainedTilt > 15 &&
        minElbow != null &&
        minElbow <= 140
    ? RejectReason.shouldersNotLevel
    : RejectReason.insufficientDepth;

/// Gives feedback for a small articulated dip that the counting state machine
/// would otherwise discard. Distances are measured in shoulder widths.
class _ShortCycleFeedback {
  _ShortCycleFeedback(this.config);

  final RepJudgeConfig config;
  static const double _entryDepth = .18;
  static const double _minimumDepth = .30;
  static const double _elbowExcursion = 14;
  double? _topElbow;
  Duration? _started;
  double _peakDepth = 0;
  double _minElbow = 180;
  double? _maxTilt;
  double? _previousTilt;
  bool _bentWithChest = false;
  int _supportedFrames = 0;
  bool _supported = false;

  void reset() {
    _topElbow = null;
    _started = null;
    _peakDepth = 0;
    _minElbow = 180;
    _maxTilt = null;
    _previousTilt = null;
    _bentWithChest = false;
    _supportedFrames = 0;
    _supported = false;
  }

  RepEvent? update(
    Duration now,
    double depth,
    double? chest,
    double? elbow,
    PoseMetrics raw,
    int index,
  ) {
    final atTop = depth <= _entryDepth / 2;
    if (_started == null) {
      if (atTop && elbow != null && elbow >= config.topAngle) _topElbow = elbow;
      if (_topElbow == null || depth < _entryDepth) return null;
      _started = now;
    }
    if (now - _started! > config.maxAttempt) {
      reset();
      return null;
    }
    _peakDepth = math.max(_peakDepth, depth);
    if (elbow != null) {
      _minElbow = math.min(_minElbow, elbow);
      if (chest != null &&
          chest >= _minimumDepth / 2 &&
          _topElbow! - elbow >= _elbowExcursion) {
        _bentWithChest = true;
      }
    }
    final tilt = raw.tilt;
    if (tilt != null && _previousTilt != null) {
      _maxTilt = math.max(_maxTilt ?? 0, math.min(_previousTilt!, tilt));
    }
    _previousTilt = tilt;
    final knee = raw.kneeHandGap;
    final hip = raw.hipAngle;
    final shin = raw.ankleKneeGap;
    final onFloor =
        knee != null &&
        knee >= config.minKneeHandGap &&
        knee <= config.maxKneeHandGap;
    final folded =
        (hip != null && hip < 145) ||
        (shin != null && shin <= config.maxShinLiftGap);
    _supportedFrames = onFloor && folded ? _supportedFrames + 1 : 0;
    if (_supportedFrames >= config.minCheatFrames) _supported = true;

    if (!atTop) return null;
    final completed =
        now - _started! >= config.noiseFloor &&
        _peakDepth >= _minimumDepth &&
        _bentWithChest &&
        elbow != null &&
        elbow - _minElbow >= _elbowExcursion;
    final event = completed
        ? RepEvent(
            index: index,
            at: now,
            valid: false,
            reason: _refinePartial(
              _supported
                  ? RejectReason.kneesDown
                  : _shallowReason(_maxTilt, _minElbow),
              maxDepth: _peakDepth,
              minElbow: _minElbow,
              maxTilt: _maxTilt,
              supportedKnee: _supported ? true : null,
            ),
            maxDepth: _peakDepth,
            minElbowAngle: _minElbow,
            maxTilt: _maxTilt,
          )
        : null;
    reset();
    if (elbow != null && elbow >= config.topAngle) _topElbow = elbow;
    return event;
  }
}

/// Native ML Kit attempt tree, fitted on the grouped development recordings.
/// It refines a partial rep's feedback only; the counter owns the verdict time
/// and decides whether it scores. Missing hip distances took the lower branch
/// during training. A knee correction always requires separate support evidence.
RejectReason? _refinePartial(
  RejectReason? original, {
  required double maxDepth,
  required double? minElbow,
  required double? maxTilt,
  required bool? supportedKnee,
  double? bottomHipHandGap,
  double? topHipHandGap,
}) {
  if (original != RejectReason.insufficientDepth &&
      original != RejectReason.shouldersNotLevel) {
    return original;
  }
  if (maxTilt == null || maxTilt <= 7.99029) {
    if (supportedKnee != true || minElbow == null) return original;
    if (topHipHandGap == null || topHipHandGap <= -1.15106) {
      return minElbow >= 155 && maxDepth >= .5
          ? RejectReason.armsStraight
          : original;
    }
    if (minElbow > 147.46887 &&
        (bottomHipHandGap == null || bottomHipHandGap <= -1.05911)) {
      return RejectReason.kneesDown;
    }
    return original;
  }
  if (maxTilt >= 8 &&
      maxTilt <= 19.19753 &&
      minElbow != null &&
      minElbow <= 155) {
    return RejectReason.shouldersNotLevel;
  }
  return original;
}

/// A descent and recovery in the image plane. Times are those of observed
/// frames in the ongoing round, independent of the picture's frame rate.
class PushupSpanCycle {
  const PushupSpanCycle(this.start, this.bottom, this.end);
  final Duration start;
  final Duration bottom;
  final Duration end;
}

/// Detects visible cycles that the head-depth path may miss in a tilted view.
/// It never assigns points or an exercise label. A stationary wrist is the
/// local origin for its own shoulder, so moving the whole image together
/// does not make a descent. Scale uses both forearms and upper arms.
class PushupSpanDetector {
  PushupSpanDetector({this.minSpan = 0.12});

  final double minSpan;
  Duration? _lastSeen, _topAt, _bottomAt, _crestAt, _lastCycle;
  double? _scale, _smooth, _top, _bottom, _crest;
  PushupPhoneBand _band = PushupPhoneBand.unknown;
  PushupPhoneBand get band => _band;

  void reset() {
    _lastSeen = _topAt = _bottomAt = _crestAt = _lastCycle = null;
    _scale = _smooth = _top = _bottom = _crest = null;
    _band = PushupPhoneBand.unknown;
  }

  static ({double height, double length, double reach})? _arm(
    PoseFrame frame,
    BodyLandmark shoulder,
    BodyLandmark elbow,
    BodyLandmark wrist,
  ) {
    final s = frame[shoulder], e = frame[elbow], w = frame[wrist];
    if (s == null ||
        e == null ||
        w == null ||
        s.likelihood < .6 ||
        e.likelihood < .6 ||
        w.likelihood < .6) {
      return null;
    }
    double distance(Keypoint a, Keypoint b) {
      final dx = a.x - b.x, dy = a.y - b.y;
      return math.sqrt(dx * dx + dy * dy);
    }

    final length = distance(s, e) + distance(e, w);
    final floor = math.min(frame.imageWidth, frame.imageHeight) * .035;
    if (!length.isFinite || length <= math.max(2, floor)) return null;
    return (height: w.y - s.y, length: length, reach: distance(s, w));
  }

  PushupSpanCycle? update(
    PoseFrame frame,
    Duration now, {
    double? phoneAngleDegrees,
  }) {
    final left = _arm(
      frame,
      BodyLandmark.leftShoulder,
      BodyLandmark.leftElbow,
      BodyLandmark.leftWrist,
    );
    final right = _arm(
      frame,
      BodyLandmark.rightShoulder,
      BodyLandmark.rightElbow,
      BodyLandmark.rightWrist,
    );
    if (left == null || right == null) {
      if (_lastSeen != null &&
          now - _lastSeen! > const Duration(milliseconds: 300)) {
        reset();
      }
      return null;
    }
    final elapsed = _lastSeen == null ? 0 : (now - _lastSeen!).inMicroseconds;
    // A tilt towards the ceiling shortens the vertical projection; retain
    // more of the shoulder-to-wrist distance in x and y for that band.
    final band = pushupPhoneBand(phoneAngleDegrees, previous: _band);
    if (elapsed <= 0 || elapsed > 300000 || _band != band) reset();
    _band = band;
    final weight = switch (band) {
      PushupPhoneBand.near60 => .52,
      PushupPhoneBand.near80 => .88,
      PushupPhoneBand.unknown => .70,
    };
    final length = (left.length + right.length) / 2;
    _scale ??= length;
    _scale =
        _scale! + (1 - math.exp(-elapsed.abs() / 1200000)) * (length - _scale!);
    final span =
        (weight * (left.height + right.height) +
            (1 - weight) * (left.reach + right.reach)) /
        (2 * _scale!);
    _smooth ??= span;
    _smooth =
        _smooth! + (1 - math.exp(-elapsed.abs() / 52000)) * (span - _smooth!);
    final value = _smooth!;
    _lastSeen = now;
    final handsBelow =
        left.height >= .10 * left.length && right.height >= .10 * right.length;
    if (_top == null || now - _topAt! > const Duration(seconds: 5)) {
      _newTop(value, now, handsBelow);
      return null;
    }
    if (_bottom == null) {
      if (value > _top! - .012 && handsBelow) {
        // Refresh the time on a plateau, but keep the actual height. At a
        // high frame rate a slow descent moves less than the jitter band
        // on each frame and would otherwise drag its own baseline down.
        _newTop(math.max(_top!, value), now, true);
      } else if (_top! - value >= minSpan) {
        _bottom = value;
        _bottomAt = now;
      }
      return null;
    }
    if (value <= _bottom!) {
      _bottom = value;
      _bottomAt = now;
      _crest = _crestAt = null;
      return null;
    }
    if (_crest == null || value > _crest!) {
      _crest = value;
      _crestAt = now;
    }
    final travel = _top! - _bottom!;
    final recovered = (_crest! - _bottom!) / travel;
    final turning = _crest! - value >= minSpan * .40;
    if (!handsBelow ||
        recovered < .65 ||
        recovered < .86 &&
            !turning &&
            now - _crestAt! < const Duration(milliseconds: 160)) {
      return null;
    }
    final start = _topAt!, bottom = _bottomAt!;
    _newTop(_crest!, _crestAt!, true);
    if (bottom - start < const Duration(milliseconds: 90) ||
        now - bottom < const Duration(milliseconds: 90) ||
        now - start < const Duration(milliseconds: 300) ||
        _lastCycle != null &&
            now - _lastCycle! < const Duration(milliseconds: 400)) {
      return null;
    }
    _lastCycle = now;
    return PushupSpanCycle(start, bottom, now);
  }

  void _newTop(double value, Duration at, bool handsBelow) {
    _top = handsBelow ? value : null;
    _topAt = handsBelow ? at : null;
    _bottom = _crest = null;
    _bottomAt = _crestAt = null;
  }
}

/// Gives an overlapping primary attempt the first opportunity to emit. Only
/// a classified rejection can be queued. Every decision uses the current or
/// preceding frames and does not require the next descent to arrive.
class PushupSpanArbiter {
  PushupSpanArbiter({this.grace = Duration.zero, this.quiet = Duration.zero});
  final Duration grace;
  final Duration quiet;
  ({PushupSpanCycle cycle, RejectReason reason})? _pending;
  Duration? _lastPrimary, _lastSupplement;

  void reset() {
    _pending = null;
    _lastPrimary = _lastSupplement = null;
  }

  ({PushupSpanCycle cycle, RejectReason reason})? update(
    Duration now, {
    required bool primaryEvent,
    Duration? primaryAttemptStarted,
    PushupSpanCycle? cycle,
    RejectReason? reason,
  }) {
    if (primaryEvent) {
      _pending = null;
      _lastPrimary = now;
      return null;
    }
    if (cycle != null && reason != null) {
      _pending = (cycle: cycle, reason: reason);
    }
    final pending = _pending;
    if (pending == null) return null;
    final age = now - pending.cycle.end;
    if (age < grace) return null;
    _pending = null;
    if (age > grace + const Duration(milliseconds: 150) ||
        primaryAttemptStarted != null &&
            primaryAttemptStarted <= pending.cycle.end) {
      return null;
    }
    final primary = _lastPrimary;
    if (primary != null &&
        (primary >= pending.cycle.start - const Duration(milliseconds: 120) ||
            now - primary <= quiet)) {
      return null;
    }
    if (_lastSupplement != null &&
        now - _lastSupplement! < const Duration(milliseconds: 400)) {
      return null;
    }
    _lastSupplement = now;
    return pending;
  }
}

/// Calibrates a soft image-depth decision using complete, observed 2D motion.
/// The grouped development tree is reduced to its decision regions. Existing
/// knee, belly, wall and device-motion verdicts never enter this calibration.
RepEvent calibratePushupPrimary(
  RepEvent event,
  List<double?>? values, {
  required bool observedReturn,
  double lockoutAngle = 172,
}) {
  if (values == null ||
      values.length != 96 ||
      !event.valid &&
          event.reason != RejectReason.insufficientDepth &&
          event.reason != RejectReason.incompleteExtension &&
          event.reason != RejectReason.shouldersNotLevel) {
    return event;
  }
  double? v(PushupSpanSignal signal, PushupSpanStat stat) =>
      values[signal.index * 6 + stat.index];
  final meanLow = v(PushupSpanSignal.elbow, PushupSpanStat.low);
  final meanHigh = v(PushupSpanSignal.elbow, PushupSpanStat.high);
  final weakerHigh = v(PushupSpanSignal.weakerElbow, PushupSpanStat.high);
  final weakerFinish = v(PushupSpanSignal.weakerElbow, PushupSpanStat.finish);
  final handHigh = v(PushupSpanSignal.handShoulderY, PushupSpanStat.high);
  final handLow = v(PushupSpanSignal.handShoulderY, PushupSpanStat.low);
  final tilt = v(PushupSpanSignal.shoulderTilt, PushupSpanStat.middle);
  final hip = v(PushupSpanSignal.hipAngle, PushupSpanStat.middle);
  final knee = v(PushupSpanSignal.kneeAngle, PushupSpanStat.middle);
  final torso = v(PushupSpanSignal.hipShoulderY, PushupSpanStat.middle);
  final travel = handHigh == null || handLow == null
      ? null
      : handHigh - handLow;
  final canPromote =
      observedReturn &&
      weakerHigh != null &&
      weakerHigh >= 157 &&
      meanLow != null &&
      meanLow <= 140 &&
      meanHigh != null &&
      meanHigh - meanLow >= 20 &&
      (lockoutAngle <= 0 ||
          weakerFinish != null && weakerFinish >= lockoutAngle) &&
      handHigh != null &&
      handHigh >= .35 &&
      travel != null &&
      travel >= .10 &&
      torso != null &&
      torso <= .75 &&
      (tilt == null || tilt <= 13) &&
      (hip == null || hip >= 140) &&
      (knee == null || knee >= 140);
  RejectReason? visibleFault;
  final tiltHigh = v(PushupSpanSignal.shoulderTilt, PushupSpanStat.high);
  final shoulders = v(PushupSpanSignal.shoulderWidth, PushupSpanStat.middle);
  final kneeWrist = v(PushupSpanSignal.kneeWristY, PushupSpanStat.middle);
  if (tiltHigh != null &&
      tiltHigh >= 15 &&
      shoulders != null &&
      shoulders >= .28) {
    visibleFault = RejectReason.shouldersNotLevel;
  } else if (knee != null &&
      knee < 140 &&
      hip != null &&
      hip < 147 &&
      kneeWrist != null &&
      kneeWrist > -.50 &&
      kneeWrist < .30) {
    visibleFault = RejectReason.kneesDown;
  } else if (weakerHigh != null &&
      weakerHigh < 160 &&
      meanHigh != null &&
      meanLow != null &&
      meanHigh - meanLow >= 22) {
    visibleFault = RejectReason.incompleteExtension;
  } else if (travel != null &&
      travel <= .21 &&
      meanLow != null &&
      meanLow >= 125) {
    visibleFault = RejectReason.insufficientDepth;
  }
  // Missing observations use the same training sentinel at internal tree
  // nodes, while the physical gates above still demand their own evidence.
  double f(PushupSpanSignal signal, PushupSpanStat stat) =>
      v(signal, stat) ?? -999;
  var decision = 0; // -1 requires invalid form, 1 requires a verified return.
  if (f(PushupSpanSignal.elbow, PushupSpanStat.bottom) <= 134.47439575195312) {
    if (f(PushupSpanSignal.hipShoulderX, PushupSpanStat.high) <=
        .10866658762097359) {
      if (f(PushupSpanSignal.handShoulderY, PushupSpanStat.bottom) <=
              .8011197149753571 ||
          f(PushupSpanSignal.noseShoulderY, PushupSpanStat.high) >
              .1566329523921013) {
        decision = 1;
      }
    } else if (f(PushupSpanSignal.hipShoulderY, PushupSpanStat.start) <=
            .3434966057538986 ||
        f(PushupSpanSignal.weakerElbow, PushupSpanStat.bottom) <=
            96.17656326293945) {
      decision = 1;
    } else if (f(PushupSpanSignal.ankleKneeY, PushupSpanStat.middle) >
        .021117151714861393) {
      decision = -1;
    }
  } else if (f(PushupSpanSignal.weakerElbow, PushupSpanStat.start) <=
          114.19804382324219 ||
      f(PushupSpanSignal.wristWidth, PushupSpanStat.finish) <=
          .6391173899173737) {
    decision = 1;
  } else if (f(PushupSpanSignal.shoulderWidth, PushupSpanStat.finish) >
          .6757148802280426 &&
      f(PushupSpanSignal.hipShoulderX, PushupSpanStat.high) >
          .1835765242576599) {
    decision = -1;
  }
  final valid = event.valid
      ? !(decision == -1 && visibleFault != null)
      : decision == 1 && canPromote;
  if (valid == event.valid) return event;
  return RepEvent(
    index: event.index,
    valid: valid,
    at: event.at,
    reason: valid ? null : visibleFault,
    maxDepth: event.maxDepth,
    minElbowAngle: event.minElbowAngle,
    maxTilt: event.maxTilt,
    descent: event.descent,
  );
}

/// A causal candidate for the experimental binary MLP. The optional primary
/// event contributes its measured score metadata and explanation.
class PushupWideProposal {
  const PushupWideProposal({this.primary});
  final RepEvent? primary;
}

/// Exact online counterpart of the frozen wide-proposal video experiment.
/// All three detectors continue to observe frames during the 800 ms cooldown.
/// The first candidate wins. A simultaneous head event supplies the metadata.
class PushupWideProposalDetector {
  final _span = PushupSpanDetector(minSpan: .06);
  final _elbow = _PushupSoftTurn();
  final _height = _PushupSoftTurn();
  Duration? _lastAccepted;
  Duration? _lastFrame;

  void reset() {
    _span.reset();
    _elbow.reset();
    _height.reset();
    _lastAccepted = null;
    _lastFrame = null;
  }

  PushupWideProposal? update(
    PoseFrame frame,
    Duration now, {
    RepEvent? primary,
  }) {
    if (_lastFrame != null && now < _lastFrame!) reset();
    _lastFrame = now;
    // The training videos contained no IMU. This proposal branch therefore
    // uses the same image-only projection even if another judge has a tilt.
    final span = _span.update(frame, now);
    final left = _wideArm(
      frame,
      BodyLandmark.leftShoulder,
      BodyLandmark.leftElbow,
      BodyLandmark.leftWrist,
    );
    final right = _wideArm(
      frame,
      BodyLandmark.rightShoulder,
      BodyLandmark.rightElbow,
      BodyLandmark.rightWrist,
    );
    double? mean(double? a, double? b) => a == null
        ? b
        : b == null
        ? a
        : (a + b) / 2;
    final time = now.inMilliseconds;
    final elbowTurn = _elbow.update(mean(left?.angle, right?.angle), time);
    final heightTurn = _height.update(mean(left?.height, right?.height), time);
    final candidate =
        primary != null || span != null || elbowTurn || heightTurn;
    if (!candidate ||
        _lastAccepted != null &&
            now - _lastAccepted! < const Duration(milliseconds: 800)) {
      return null;
    }
    _lastAccepted = now;
    return PushupWideProposal(primary: primary);
  }

  static ({double angle, double height})? _wideArm(
    PoseFrame frame,
    BodyLandmark shoulder,
    BodyLandmark elbow,
    BodyLandmark wrist,
  ) {
    Keypoint? visible(BodyLandmark name) {
      final p = frame[name];
      return p != null && p.likelihood >= .55 && p.x.isFinite && p.y.isFinite
          ? p
          : null;
    }

    final s = visible(shoulder), e = visible(elbow), w = visible(wrist);
    if (s == null || e == null || w == null) return null;
    final ax = s.x - e.x, ay = s.y - e.y;
    final bx = w.x - e.x, by = w.y - e.y;
    final upper = math.sqrt(ax * ax + ay * ay);
    final lower = math.sqrt(bx * bx + by * by);
    if (upper <= 1 || lower <= 1) return null;
    final cosine = ((ax * bx + ay * by) / (upper * lower)).clamp(-1.0, 1.0);
    return (
      angle: math.acos(cosine) / math.pi,
      height: (w.y - s.y) / (upper + lower),
    );
  }
}

/// Scalar descent-and-return recognizer with exactly the frozen time constants.
class _PushupSoftTurn {
  double? _top, _low, _smoothed;
  int? _topAt, _bottomAt, _previousAt;

  void reset() {
    _top = _low = _smoothed = null;
    _topAt = _bottomAt = _previousAt = null;
  }

  bool update(double? raw, int milliseconds) {
    if (raw == null || !raw.isFinite) return false;
    final previous = _previousAt;
    if (previous == null || milliseconds - previous > 320) {
      _top = _smoothed = raw;
      _low = null;
      _topAt = _bottomAt = milliseconds;
    }
    if (previous != null) {
      _smoothed =
          _smoothed! +
          (raw - _smoothed!) * (1 - math.exp(-(milliseconds - previous) / 80));
    }
    _previousAt = milliseconds;
    final value = _smoothed!;
    if (_low == null) {
      if (value > _top! || milliseconds - _topAt! > 3200) {
        _top = value;
        _topAt = milliseconds;
      } else if (_top! - value >= .095) {
        _low = value;
        _bottomAt = milliseconds;
      }
    } else if (milliseconds - _topAt! > 4800) {
      _top = value;
      _topAt = milliseconds;
      _low = null;
    } else if (value <= _low!) {
      _low = value;
      _bottomAt = milliseconds;
    } else if (value - _low! >= math.max(.095 * .6, (_top! - _low!) * .58) &&
        milliseconds - _bottomAt! >= 65 &&
        milliseconds - _topAt! >= 240) {
      _top = value;
      _topAt = milliseconds;
      _low = null;
      return true;
    }
    return false;
  }
}
