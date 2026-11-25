import '../../models/arcade_stage.dart';
import 'chair_hold.dart';
import 'high_plank_hold.dart';
import 'hold_pose_definition.dart';

/// The one place that picks a held pose's bundle (arcade hold spec 3).
abstract final class HoldPoses {
  static HoldPoseDefinition of(HoldPose pose) => switch (pose) {
    HoldPose.plank => highPlankHold,
    HoldPose.chair => chairHold,
  };
}
