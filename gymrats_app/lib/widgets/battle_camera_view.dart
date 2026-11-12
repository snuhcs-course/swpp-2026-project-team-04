import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/pose_frame.dart';
import '../services/pose/rep_judge.dart';
import 'chest_height_overlay.dart';
import 'pose_camera_view.dart';
import 'squat_height_overlay.dart';

/// The user's camera in the battle's lower half, in the camera's own shape:
/// the arena centers it and never crops it. Over it, as before the stage,
/// the detected joints and the chest or squat height lines.
///
/// Before the camera runs it is a black picture of the usual 3 : 4 shape.
class BattleCameraView extends StatelessWidget {
  const BattleCameraView({
    super.key,
    required this.controller,
    this.frame,
    this.mirror = false,
    this.chestSnapshot,
    this.squatSnapshot,
  });

  final CameraController? controller;
  final PoseFrame? frame;

  /// The front camera's picture is mirrored, the joints are not.
  final bool mirror;

  /// The push-up judge's state, for the chest height lines; null for none.
  final JudgeSnapshot? chestSnapshot;

  /// The squat judge's state, for the squat height lines; null for none.
  final JudgeSnapshot? squatSnapshot;

  /// Width over height of a phone camera's picture held upright.
  static const _uprightShape = 3 / 4;

  @override
  Widget build(BuildContext context) {
    final preview = controller?.value.previewSize;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // The preview size is always given lying down (wider than tall).
    final shape = preview == null || preview.isEmpty
        ? _uprightShape
        : (landscape
              ? preview.width / preview.height
              : preview.height / preview.width);
    final chest = chestSnapshot;
    final squat = squatSnapshot;
    return AspectRatio(
      aspectRatio: shape,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PoseCameraView(
            controller: controller,
            frame: frame,
            mirror: mirror,
            showLandmarks: true,
          ),
          if (chest != null)
            ChestHeightOverlay(frame: frame, snapshot: chest, mirror: mirror),
          if (squat != null) SquatHeightOverlay(frame: frame, snapshot: squat),
        ],
      ),
    );
  }
}
