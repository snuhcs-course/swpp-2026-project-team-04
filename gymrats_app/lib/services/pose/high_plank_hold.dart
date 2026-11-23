import '../../models/arcade_stage.dart';
import '../../models/exercise_type.dart';
import '../../models/hold_reading.dart';
import '../../models/pose_frame.dart';
import 'hold_pose_definition.dart';
import 'hold_judge.dart';
import 'pose_metrics.dart';
import 'rep_judge.dart';
import 'setup_checker.dart';

/// The high plank's faults besides [HoldFault.offScreen] (arcade hold spec
/// 3 and 4). The setup cues have no arm or head icon, so those two show an
/// empty box.
abstract final class HighPlankFaults {
  static const armBent = HoldFault(
    id: 'plank.armBent',
    cue: ('팔', '펴요'),
    icon: HoldIcon.blank,
  );
  static const kneeDown = HoldFault(
    id: 'plank.kneeDown',
    cue: ('무릎', '떼요'),
    icon: HoldIcon.knee,
  );
  static const headDown = HoldFault(
    id: 'plank.headDown',
    cue: ('머리', '들어요'),
    icon: HoldIcon.blank,
  );

  static const all = [armBent, kneeDown, headDown];
}

/// The high plank's bundle: set up as the push-up's top, held from GO.
final highPlankHold = HoldPoseDefinition(
  pose: HoldPose.plank,
  setupExercise: ExerciseType.pushUp,
  createReader: HighPlankReader.new,
  entry: false,
  checks: const ['팔 펴기', '무릎 떼기', '머리 들기'],
  faults: HighPlankFaults.all,
  silhouette: HoldSilhouette.plank,
  guide: HoldGuide.chestHeight,
);

/// Reads a high plank from the front camera, where the push-up is read
/// (spec 3, "하이 플랭크 읽기"). From there the hips hide behind the torso,
/// so their sag cannot be seen ([PoseMetrics.tilt]); it looks at the arms,
/// the knees and the head instead. Every number is the push-up judge's or
/// the setup's, read from their configs; none is made up here.
///
/// - **Unknown:** both shoulders and at least one arm (shoulder, elbow and
///   wrist) at [RepJudgeConfig.minLikelihood] or more are needed. A part
///   that is not seen never breaks the pose.
/// - **Off screen:** both wrists are seen and are not below their
///   shoulders ([PoseMetrics.handsBelowShoulders]): the user stood up. So
///   is a body the push-up judge calls upright: the hips seen more than
///   [RepJudgeConfig.maxTorsoDrop] shoulder widths under the shoulders
///   ([PoseMetrics.torsoDrop]), since a user standing with the arms down
///   still has the hands below the shoulders.
/// - **Knees down:** the push-up judge's knee decision is made inside its
///   rep flow and cannot be called alone, so its per-frame parts are used
///   (spec 3): the knee contact classifier ([KneeFrameClassifier]) reading
///   touching; the knees beside the hands ([PoseMetrics.kneeHandGap] from
///   [RepJudgeConfig.minKneeHandGap] to [RepJudgeConfig.maxKneeHandGap]);
///   or, with straight arms, the hips folded from the user's own plank
///   ([PoseMetrics.hipAngle] [RepJudgeConfig.hipFoldWide] or, after
///   [RepJudgeConfig.baselineFrames] of them,
///   [RepJudgeConfig.hipFoldFromSetup] under the plank angles taken at
///   [RepJudgeConfig.adoptHipAngle] or more, as the judge keeps them).
/// - **Arms bent:** [PoseMetrics.elbowAngle] under the setup's push-up arm
///   line ([SetupConfig.pushUpArmAngle], 155°, the judge's
///   [RepJudgeConfig.topAngle] too).
/// - **Head down:** the nose more than [RepJudgeConfig.enterDepth] shoulder
///   widths under where it was, the depth that starts a push-up. Where it
///   was: the mean nose height and shoulder width of the frames read as
///   held in the first [baselineFor] from the first such frame after GO.
///   It is never taken again in a play.
///
/// The first fault in that order is the reading's. A flicker at a line is
/// left to the common part's [HoldTiming.warn] (spec 3).
class HighPlankReader implements HoldPoseReader {
  HighPlankReader({
    this.judge = const RepJudgeConfig(),
    this.setup = const SetupConfig(),
    KneeFrameClassifier? kneeClassifier,
    this.baselineFor = HoldTiming.warn,
  }) : _knees = kneeClassifier ?? KneeFrameClassifier();

  /// The push-up judge's numbers.
  final RepJudgeConfig judge;

  /// The setup's numbers: the push-up arm line.
  final SetupConfig setup;

  /// How long after the first held frame after GO the head's height is
  /// taken.
  final Duration baselineFor;

  final KneeFrameClassifier _knees;

  /// The plank hip angles kept as the user's own, as the judge keeps them.
  final List<double> _plankHips = [];
  double? _plankHip;

  /// The head's place: taken once, after GO.
  Duration? _baselineSince;
  final List<double> _noses = [];
  final List<double> _widths = [];
  double? _baseNose;
  double? _baseWidth;

  /// Where the head was held, in pixels, and the shoulder width with it;
  /// null until taken.
  double? get baseNoseY => _baseNose;
  double? get baseShoulderWidth => _baseWidth;

  /// The user's own plank hip angle; null until one was seen.
  double? get plankHipAngle => _plankHip;

  @override
  HoldReading read(
    PoseFrame frame, {
    required Duration at,
    bool counting = false,
  }) {
    final metrics = measurePose(frame, minLikelihood: judge.minLikelihood);
    final elbow = metrics.elbowAngle;
    final width = metrics.shoulderWidth;
    if (elbow == null || width == null || width < 1e-6) {
      return HoldReading.unknown;
    }
    _keepPlankHip(elbow, metrics.hipAngle);

    final fault = _fault(frame, metrics, elbow);
    if (fault != null) return HoldReading.broken(fault);
    if (_headDown(metrics)) {
      return const HoldReading.broken(HighPlankFaults.headDown);
    }
    if (!counting) _takeHead(metrics, at);
    return HoldReading.ok;
  }

  HoldFault? _fault(PoseFrame frame, PoseMetrics metrics, double elbow) {
    if (_bothWristsSeen(frame) && !metrics.handsBelowShoulders) {
      return HoldFault.offScreen;
    }
    final drop = metrics.torsoDrop;
    if (drop != null && drop > judge.maxTorsoDrop) return HoldFault.offScreen;
    if (_kneesDown(frame, metrics, elbow)) return HighPlankFaults.kneeDown;
    if (elbow < setup.pushUpArmAngle) return HighPlankFaults.armBent;
    return null;
  }

  bool _bothWristsSeen(PoseFrame frame) =>
      _seen(frame[BodyLandmark.leftWrist]) &&
      _seen(frame[BodyLandmark.rightWrist]);

  bool _seen(Keypoint? point) =>
      point != null && point.likelihood >= judge.minLikelihood;

  bool _kneesDown(PoseFrame frame, PoseMetrics metrics, double elbow) {
    if (_knees.classify(frame).state == KneeFrameState.touching) return true;
    final gap = metrics.kneeHandGap;
    if (gap != null &&
        gap >= judge.minKneeHandGap &&
        gap <= judge.maxKneeHandGap) {
      return true;
    }
    final hip = metrics.hipAngle;
    if (hip == null || elbow < judge.topAngle) return false;
    final plank = _plankHip;
    if (plank != null) return hip <= plank - _foldMargin;
    return hip < judge.defaultKneeHip;
  }

  /// Wider until the judge's count of plank angles is kept, then tight.
  double get _foldMargin => _plankHips.length >= judge.baselineFrames
      ? judge.hipFoldFromSetup
      : judge.hipFoldWide;

  /// A straight-arm frame with the hips at the judge's plank angle or more
  /// adds to the user's own plank, up to the judge's count; then it is
  /// fixed, so a later kneel cannot become it. One is taken as it is, two
  /// are their mean, three their median.
  void _keepPlankHip(double elbow, double? hip) {
    if (_plankHips.length >= judge.baselineFrames) return;
    if (hip == null || elbow < judge.topAngle || hip < judge.adoptHipAngle) {
      return;
    }
    _plankHips.add(hip);
    final sorted = [..._plankHips]..sort();
    _plankHip = sorted.length == 2
        ? (sorted[0] + sorted[1]) / 2
        : sorted[sorted.length ~/ 2];
  }

  bool _headDown(PoseMetrics metrics) {
    final base = _baseNose;
    final width = _baseWidth;
    final nose = metrics.noseY;
    if (base == null || width == null || nose == null) return false;
    return (nose - base) / width > judge.enterDepth;
  }

  /// A held frame after GO, while the head's place is not yet taken.
  void _takeHead(PoseMetrics metrics, Duration at) {
    if (_baseNose != null) return;
    final since = _baselineSince ??= at;
    final nose = metrics.noseY;
    if (at - since < baselineFor) {
      if (nose != null) {
        _noses.add(nose);
        _widths.add(metrics.shoulderWidth!);
      }
      return;
    }
    if (_noses.isEmpty) {
      // No nose seen in the window: wait for the first one.
      if (nose == null) return;
      _noses.add(nose);
      _widths.add(metrics.shoulderWidth!);
    }
    _baseNose = _noses.reduce((a, b) => a + b) / _noses.length;
    _baseWidth = _widths.reduce((a, b) => a + b) / _widths.length;
  }
}
