import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../../support/fakes.dart';

/// UI tests queue verdicts for specific camera timestamps. Intervening camera
/// frames keep the tracking stream alive without consuming that queued verdict.
/// The real continuity guard still observes every frame.
class CadencedRepJudge extends FakeRepJudge {
  bool holdVerdicts = false;

  @override
  RepUpdate update(PoseFrame frame) =>
      holdVerdicts ? RepUpdate(snapshot: snapshot) : super.update(frame);
}

/// A new detection of an unchanged pose, not a repeated state notification.
PoseFrame freshPose(PoseFrame frame) => PoseFrame(
  imageWidth: frame.imageWidth,
  imageHeight: frame.imageHeight,
  keypoints: frame.keypoints,
);
