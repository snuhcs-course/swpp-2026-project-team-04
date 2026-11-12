import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/pose_frame.dart';
import '../services/pose/rep_judge.dart';
import 'chest_height_overlay.dart';
import 'pose_camera_view.dart';
import 'squat_height_overlay.dart';

/// The user's camera in the battle's lower half, in the camera's own shape:
/// the arena centers it and never crops it. Over it, as before the stage,
/// the detected joints and the chest or squat height lines, and before the
/// round the setup's guide.
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
    this.guide,
    this.guideFit = BoxFit.cover,
  }) : assert(
         guideFit == BoxFit.cover || guideFit == BoxFit.contain,
         'A guide is drawn for a cropping or a whole-picture camera box.',
       );

  final CameraController? controller;
  final PoseFrame? frame;

  /// The front camera's picture is mirrored, the joints are not.
  final bool mirror;

  /// The push-up judge's state, for the chest height lines; null for none.
  final JudgeSnapshot? chestSnapshot;

  /// The squat judge's state, for the squat height lines; null for none.
  final JudgeSnapshot? squatSnapshot;

  /// The setup's guide, e.g. the push-up silhouette; null for none. It lies
  /// over the picture as [guideFit] says.
  final Widget? guide;

  /// The camera box the [guide] was drawn for, so that its lines fall on the
  /// same place of the picture here:
  ///
  /// - [BoxFit.cover]: a camera that fills its whole box and crops what does
  ///   not fit. This view shows the whole picture instead, so the guide
  ///   covers only the part of it such a camera would show in the box this
  ///   view is given ([coverShare]).
  /// - [BoxFit.contain]: the whole picture, as here; the guide covers it.
  final BoxFit guideFit;

  /// Width over height of a phone camera's picture held upright.
  static const _uprightShape = 3 / 4;

  /// The part of a picture of [shape] (width over height) that a camera
  /// filling a box of [box] would show, as a share of the picture's width
  /// and height. The picture is cropped on one side only: its sides for a
  /// box narrower than the picture, its top and bottom for a wider one.
  static ({double width, double height}) coverShare(double shape, Size box) {
    if (!box.width.isFinite ||
        !box.height.isFinite ||
        box.isEmpty ||
        shape <= 0) {
      return (width: 1, height: 1);
    }
    final boxShape = box.width / box.height;
    return (
      width: math.min(1, boxShape / shape),
      height: math.min(1, shape / boxShape),
    );
  }

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
    final guide = this.guide;
    return LayoutBuilder(
      builder: (context, constraints) {
        final share = guideFit == BoxFit.cover
            ? coverShare(shape, constraints.biggest)
            : (width: 1.0, height: 1.0);
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
                ChestHeightOverlay(
                  frame: frame,
                  snapshot: chest,
                  mirror: mirror,
                ),
              if (squat != null)
                SquatHeightOverlay(frame: frame, snapshot: squat),
              if (guide != null)
                Center(
                  child: FractionallySizedBox(
                    widthFactor: share.width,
                    heightFactor: share.height,
                    child: guide,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
