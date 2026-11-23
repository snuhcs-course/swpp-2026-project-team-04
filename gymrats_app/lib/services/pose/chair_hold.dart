import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/arcade_stage.dart';
import '../../models/exercise_type.dart';
import '../../models/hold_reading.dart';
import '../../models/pose_frame.dart';
import 'hold_pose_definition.dart';
import 'rep_judge.dart';
import 'squat_rep_judge.dart';

/// The chair pose's faults besides [HoldFault.offScreen] (arcade chair
/// spec 3 and 4), each with the icon A4 drew for it.
abstract final class ChairFaults {
  /// The hips are too high (the design's `reason=low`).
  static const low = HoldFault(
    id: 'chair.low',
    cue: ('더', '앉아요'),
    icon: HoldIcon.low,
  );

  /// The knees come in (the design's `reason=spread`).
  static const kneesIn = HoldFault(
    id: 'chair.kneesIn',
    cue: ('무릎', '벌려요'),
    icon: HoldIcon.spread,
  );

  static const all = [low, kneesIn];
}

/// The chair pose's bundle (spec 1 to 5): set up standing, as in the squat
/// battle, and entered after GO; the time starts once the pose is first
/// held for `HoldTiming.resume`. Its drawings are A4's: the sitting figure
/// and the squat battle's hip and knee height lines.
final chairHold = HoldPoseDefinition(
  pose: HoldPose.chair,
  setupExercise: ExerciseType.squat,
  createReader: ChairHoldReader.new,
  entry: true,
  checks: const ['엉덩이 높이', '무릎 안 모으기'],
  faults: ChairFaults.all,
  silhouette: HoldSilhouette.sit,
  guide: HoldGuide.squatHeight,
);

/// The chair reading's lines that [SquatRepJudge] does not make public.
abstract final class ChairLines {
  /// A leg stands while its smoothed thigh is at least this share of its
  /// shin: `SquatRepJudge.update`'s `thigh >= .7 * shin`.
  static const standingThigh = .7;

  /// Standing this long sets the standing thigh: the 300 ms of
  /// `SquatRepJudge.update`.
  static const standingFor = Duration(milliseconds: 300);

  /// In the 3·2·1 the standing thigh follows a standing user only under
  /// this depth, and from it on not until the depth is back at
  /// [followAgainAt]: `SquatRepJudge.update`'s `.25`, where a squat starts,
  /// and its `.15`, where it is back up. After GO it does not follow.
  static const followUnder = .25;
  static const followAgainAt = .15;

  /// The knees come in when the gap between them, across the picture, is
  /// under this share of the gap between the ankles. A new value, not in
  /// the squat judge (spec 3; the user's answer to spec 9.1, 2026-11-23).
  /// The phone check writes the ratios it saw in the testing notes.
  static const kneeGap = .8;
}

/// Reads the chair pose from the front camera, where the squat is read
/// (spec 3): the depth is how much shorter the thigh looks than when the
/// user stood, as in [SquatRepJudge.update]. From the front, the thigh
/// shortens on the picture as it comes level with the floor: 0 is standing,
/// 1 a level thigh.
///
/// [SquatRepJudge] is not run itself: 12 s after a squat starts down it
/// drops the squat and its standing thigh, and a chair is held for up to
/// 45 s. Its formulas are worked here instead, with its public numbers
/// ([SquatRepJudge.minLikelihood], [SquatRepJudge.passDepth],
/// [SquatRepJudge.smoothingTau], [SquatRepJudge.baselineTau]) read from
/// [squat] and the others copied into [ChairLines]:
///
/// - **Legs:** a side whose hip, knee and ankle are seen at
///   [SquatRepJudge.minLikelihood] or more, with the ankle under the knee.
///   With both, their mean.
/// - **Thigh:** the knee's height under the hip, smoothed over
///   [SquatRepJudge.smoothingTau].
/// - **Standing thigh:** the thigh after [ChairLines.standingFor] standing
///   ([ChairLines.standingThigh]); the 3·2·1's frames take it, and in the
///   3·2·1 it follows a standing user over [SquatRepJudge.baselineTau], as
///   the squat judge's does, never while sitting.
///
///   From GO on it is fixed for the play (the user's decision, 2026-11-24,
///   narrowing the spec's "follows while standing" to before GO): the squat
///   judge's rule follows the thigh while it is still standing on the way
///   down, so a slow sit lowered it and a true 0.8 read 0.73–0.75, under
///   [SquatRepJudge.passDepth]. Without one by GO, the first
///   [ChairLines.standingFor] standing after GO takes it, once. It is never
///   dropped in a play: not after a gap in the frames, not after 12 s down.
/// - **Depth:** 1 − thigh / standing thigh.
///
/// The reading:
///
/// - **Unknown:** no leg, or no standing thigh yet. A part that is not seen
///   never breaks the pose.
/// - **Hips too high** ([ChairFaults.low]): a depth under
///   [SquatRepJudge.passDepth], the depth a squat counts at. Standing up is
///   this too. A depth over 1 (hips under the knees) is held (the user's
///   answer to spec 9.2).
/// - **Knees in** ([ChairFaults.kneesIn]): both knees and both ankles seen,
///   and the knees closer than [ChairLines.kneeGap] of the ankles' gap. With
///   one of them not seen this is not read.
/// - Both: the hips.
///
/// It also gives the squat guide's lines ([guide]) in the squat judge's
/// shape: the hips and knees it read, and a phase that is
/// [RepPhase.bottom] while the depth holds, which turns the hip line green.
/// In debug builds it prints its numbers twice a second, for the phone
/// check.
class ChairHoldReader implements HoldGuideReader {
  ChairHoldReader({SquatRepJudge? squat}) : squat = squat ?? SquatRepJudge();

  /// The squat judge whose public numbers are read. It is never updated.
  final SquatRepJudge squat;

  Duration? _lastAt;
  Duration? _standingSince;
  double? _thigh;
  double? _standingThigh;
  bool _down = false;
  double? _depth;
  double? _kneeRatio;
  JudgeSnapshot _guide = JudgeSnapshot.initial;
  Duration? _printedAt;

  /// The standing thigh in pixels; null until taken.
  double? get standingThigh => _standingThigh;

  /// The depth of the last frame with a leg; null without a standing thigh.
  double? get depth => _depth;

  /// The knees' gap over the ankles' of the last frame that showed all
  /// four; null before one.
  double? get kneeRatio => _kneeRatio;

  @override
  JudgeSnapshot get guide => _guide;

  @override
  HoldReading read(
    PoseFrame frame, {
    required Duration at,
    bool counting = false,
  }) {
    final knees = _kneesOverAnkles(frame);
    if (knees != null) _kneeRatio = knees;
    final legs = _legs(frame);
    if (legs.isEmpty) {
      _guide = JudgeSnapshot(phase: _phase);
      return _printed(at, counting, HoldReading.unknown);
    }
    _measure(legs, at, follow: counting);
    _guide = JudgeSnapshot(
      phase: _phase,
      depth: _depth,
      squatHipY: _mean(legs.map((l) => l.hipY)),
      squatKneeY: _mean(legs.map((l) => l.kneeY)),
    );
    return _printed(at, counting, _reading(knees));
  }

  RepPhase get _phase {
    final depth = _depth;
    if (_standingThigh == null || depth == null) return RepPhase.idle;
    if (depth >= squat.passDepth) return RepPhase.bottom;
    return _down ? RepPhase.descending : RepPhase.up;
  }

  /// [knees] is the frame's knee gap over its ankle gap, if it showed all
  /// four.
  HoldReading _reading(double? knees) {
    final depth = _depth;
    if (depth == null) return HoldReading.unknown;
    if (depth < squat.passDepth) {
      return const HoldReading.broken(ChairFaults.low);
    }
    if (knees != null && knees < ChairLines.kneeGap) {
      return const HoldReading.broken(ChairFaults.kneesIn);
    }
    return HoldReading.ok;
  }

  /// `SquatRepJudge.update`'s thigh, standing thigh and depth, without its
  /// rep flow; the standing thigh follows only when [follow] (the 3·2·1).
  void _measure(List<_Leg> legs, Duration at, {required bool follow}) {
    final previousAt = _lastAt;
    _lastAt = at;
    double alpha(Duration tau) {
      if (previousAt == null || tau <= Duration.zero) return 1;
      final gap = at - previousAt;
      // A clock going back moves nothing here; the squat judge would give a
      // negative weight. The hold's clock never goes back.
      if (gap <= Duration.zero) return 0;
      return 1 - math.exp(-gap.inMicroseconds / tau.inMicroseconds);
    }

    final measured = _mean(legs.map((l) => l.thigh));
    final smoothed = _thigh;
    _thigh = smoothed == null
        ? measured
        : smoothed + alpha(squat.smoothingTau) * (measured - smoothed);
    final thigh = _thigh!;
    final shin = _mean(legs.map((l) => l.shin));
    final standing = thigh >= ChairLines.standingThigh * shin;

    final top = _standingThigh;
    if (top == null) {
      if (!standing) {
        _standingSince = null;
      } else {
        final since = _standingSince ??= at;
        if (at - since >= ChairLines.standingFor) _standingThigh = thigh;
      }
      _depth = _standingThigh == null ? null : 0;
      return;
    }
    var depth = 1 - thigh / top;
    if (follow && !_down && depth < ChairLines.followUnder && standing) {
      final followed = top + alpha(squat.baselineTau) * (thigh - top);
      _standingThigh = followed;
      depth = 1 - thigh / followed;
    }
    if (!_down && depth >= ChairLines.followUnder) {
      _down = true;
    } else if (_down && depth <= ChairLines.followAgainAt) {
      _down = false;
    }
    _depth = depth;
  }

  /// The sides the squat judge would use.
  List<_Leg> _legs(PoseFrame frame) => [
    for (final (hipId, kneeId, ankleId) in const [
      (BodyLandmark.leftHip, BodyLandmark.leftKnee, BodyLandmark.leftAnkle),
      (BodyLandmark.rightHip, BodyLandmark.rightKnee, BodyLandmark.rightAnkle),
    ])
      ?_leg(frame[hipId], frame[kneeId], frame[ankleId]),
  ];

  _Leg? _leg(Keypoint? hip, Keypoint? knee, Keypoint? ankle) {
    if (hip == null || knee == null || ankle == null) return null;
    for (final point in [hip, knee, ankle]) {
      if (!point.y.isFinite ||
          !point.likelihood.isFinite ||
          point.likelihood < squat.minLikelihood) {
        return null;
      }
    }
    final shin = ankle.y - knee.y;
    if (shin <= 0) return null;
    return (thigh: knee.y - hip.y, shin: shin, hipY: hip.y, kneeY: knee.y);
  }

  /// The knees' gap over the ankles', across the picture; null unless both
  /// knees and both ankles are seen, apart.
  double? _kneesOverAnkles(PoseFrame frame) {
    final points = [
      frame[BodyLandmark.leftKnee],
      frame[BodyLandmark.rightKnee],
      frame[BodyLandmark.leftAnkle],
      frame[BodyLandmark.rightAnkle],
    ];
    for (final point in points) {
      if (point == null ||
          !point.x.isFinite ||
          !point.likelihood.isFinite ||
          point.likelihood < squat.minLikelihood) {
        return null;
      }
    }
    final ankles = (points[2]!.x - points[3]!.x).abs();
    if (ankles < 1e-6) return null;
    return (points[0]!.x - points[1]!.x).abs() / ankles;
  }

  HoldReading _printed(Duration at, bool counting, HoldReading reading) {
    assert(() {
      final last = _printedAt;
      if (last == null || at - last >= const Duration(milliseconds: 500)) {
        _printedAt = at;
        debugPrint(
          'chair_hold ${counting ? '3-2-1' : 'hold'} '
          'depth=${_depth?.toStringAsFixed(3)} '
          'knees=${_kneeRatio?.toStringAsFixed(3)} '
          'standingThigh=${_standingThigh?.toStringAsFixed(1)} $reading',
        );
      }
      return true;
    }());
    return reading;
  }

  static double _mean(Iterable<double> values) =>
      values.reduce((a, b) => a + b) / values.length;
}

typedef _Leg = ({double thigh, double shin, double hipY, double kneeY});
