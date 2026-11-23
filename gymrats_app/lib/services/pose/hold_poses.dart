import '../../models/arcade_stage.dart';
import 'high_plank_hold.dart';
import 'hold_pose_definition.dart';

/// The one place that picks a held pose's bundle (arcade hold spec 3).
///
/// The chair pose comes in A5: it adds its bundle in a `chair*.dart` file
/// and replaces the chair line below with one naming it. Until then a
/// chair stage is stopped here.
abstract final class HoldPoses {
  static HoldPoseDefinition of(HoldPose pose) => switch (pose) {
    HoldPose.plank => highPlankHold,
    HoldPose.chair => _notYet(pose),
  };

  static HoldPoseDefinition _notYet(HoldPose pose) {
    assert(false, '${pose.label} comes in A5 (P16-4).');
    throw UnsupportedError('${pose.label} is not built yet.');
  }
}
