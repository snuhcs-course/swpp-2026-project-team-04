import '../../models/arcade_stage.dart';
import '../../models/exercise_type.dart';
import '../../models/hold_reading.dart';
import '../../models/pose_frame.dart';
import 'rep_judge.dart';

/// Reads one held pose from camera frames: the part of a hold that differs
/// by pose (arcade hold spec 3, "자세 읽기"). The time and the warnings are
/// the same for every pose ([HoldJudge]).
abstract interface class HoldPoseReader {
  /// Reads [frame], seen at [at].
  ///
  /// While [counting] (the 3·2·1 between the setup and GO) the reading is
  /// not used for the time or the warnings: the reader may only set its
  /// baselines from it (the chair pose takes the standing thigh length
  /// there). After GO every frame is read with [counting] false.
  HoldReading read(PoseFrame frame, {required Duration at, bool counting});
}

/// A pose reader that also gives the state of the guide lines over the
/// camera, in the shape of the setup exercise judge's snapshot (for the
/// squat guide: `squatHipY`, `squatKneeY` and `phase`). Without one, the
/// hold runs the setup exercise's own rep judge from GO for its guide
/// lines. The chair pose needs this: the squat judge drops a squat after
/// 12 s down, and with it the lines, while a chair is held for up to 45 s.
abstract interface class HoldGuideReader implements HoldPoseReader {
  /// The guide lines' state after the last frame read.
  JudgeSnapshot get guide;
}

/// Everything about one held pose that differs by pose, in one bundle
/// (spec 3, "자세 정의"). The hold screen and [HoldJudge] look only at this.
///
/// Pick one with `HoldPoses.of` (`hold_poses.dart`), the one place that
/// knows every pose.
class HoldPoseDefinition {
  const HoldPoseDefinition({
    required this.pose,
    required this.setupExercise,
    required this.createReader,
    required this.entry,
    required this.checks,
    required this.faults,
    required this.silhouette,
    required this.guide,
  });

  final HoldPose pose;

  /// The battle's setup this pose is set up with: its check, silhouette and
  /// cues, and the place of the phone. The high plank is the push-up's top.
  final ExerciseType setupExercise;

  /// A new reader for one play of a stage.
  final HoldPoseReader Function() createReader;

  /// Whether the pose is entered after GO (spec 3, "들어가기"): the time
  /// stays at zero, with no warning, until the pose is first held for
  /// `HoldTiming.resume`. False starts the time at GO: the setup's pose is
  /// already the held one.
  final bool entry;

  /// The briefing card's check chips, e.g. "팔 펴기".
  final List<String> checks;

  /// The faults its reader gives, besides [HoldFault.offScreen], each with
  /// its warning words and icon.
  final List<HoldFault> faults;

  /// The figure in the camera box and the icon on the briefing card.
  final HoldSilhouette silhouette;

  /// The guide lines over the camera while holding.
  final HoldGuide guide;
}
