import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/pose_frame.dart';
import '../services/pose/rep_judge.dart';
import 'chest_height_overlay.dart';
import 'pose_camera_view.dart';
import 'squat_height_overlay.dart';

/// The camera with the pose on it and the judge's height guides, for the
/// pose setup and the rep judge demo. Changes presentation only: it never
/// starts or stops the camera or the detector.
///
/// It used to switch to a 3D avatar of the pose ("아바타 보기"); the
/// characters replaced the avatars (W3), so it shows the camera only. The
/// name stays so the screens that use it need no change.
class PoseAvatarToggleView extends StatelessWidget {
  const PoseAvatarToggleView({
    super.key,
    required this.controller,
    this.frame,
    this.mirror = false,
    this.showLandmarks = false,
    this.cameraFit = BoxFit.cover,
    this.isVisible,
    this.cameraOverlay,
    this.chestSnapshot,
    this.squatSnapshot,
  });

  final CameraController? controller;
  final PoseFrame? frame;
  final bool mirror;
  final bool showLandmarks;
  final BoxFit cameraFit;
  final bool Function(Keypoint keypoint, PoseFrame frame)? isVisible;

  /// Drawn over the camera, e.g. the push-up silhouette.
  final Widget? cameraOverlay;
  final JudgeSnapshot? chestSnapshot;
  final JudgeSnapshot? squatSnapshot;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      PoseCameraView(
        controller: controller,
        frame: frame,
        mirror: mirror,
        showLandmarks: showLandmarks,
        fit: cameraFit,
        isVisible: isVisible,
      ),
      ?cameraOverlay,
      if (chestSnapshot case final snapshot?)
        ChestHeightOverlay(frame: frame, snapshot: snapshot, mirror: mirror),
      if (squatSnapshot case final snapshot?)
        SquatHeightOverlay(frame: frame, snapshot: snapshot),
    ],
  );
}
