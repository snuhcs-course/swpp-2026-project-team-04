import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/pose_frame.dart';
import '../services/pose/rep_judge.dart';
import '../theme/app_theme.dart';
import 'chest_height_overlay.dart';
import 'pose_camera_view.dart';
import 'pose_silhouette_guide.dart';
import 'squat_height_overlay.dart';

/// Where the arena lays the camera picture out (W2b 3-B), for a
/// [BattleCameraView] under it: the camera's box in the setup's layout and
/// in the battle's, and how far the screen is from the one to the other
/// ([progress], eased, 0 to 1). Without it the view fills the box it is
/// given in its own shape, as before W2b.
class BattleCameraLayout extends InheritedWidget {
  const BattleCameraLayout({
    super.key,
    required this.setupBox,
    required this.battleBox,
    required this.progress,
    required super.child,
  });

  /// The camera's box while setting up: under a line high on the screen.
  final Size setupBox;

  /// The camera's box from the countdown on: the lower half.
  final Size battleBox;
  final double progress;

  static BattleCameraLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BattleCameraLayout>();

  @override
  bool updateShouldNotify(BattleCameraLayout oldWidget) =>
      oldWidget.setupBox != setupBox ||
      oldWidget.battleBox != battleBox ||
      oldWidget.progress != progress;
}

/// The user's camera on the battle screen, in the camera's own shape. Over
/// it, as before the stage, the detected joints and the chest or squat
/// height lines, and before the round the setup's guide, with the picture
/// around the guide dimmed as the guide dims its own outside
/// ([BattleGuideOverlay]).
///
/// Under a [BattleCameraLayout] (the arena's) it fills the camera's box while
/// setting up, cropping what does not fit, and shows the whole picture,
/// uncropped and centered, in the battle's layout, growing or shrinking in
/// between ([pictureSize]); the guide keeps its place on the picture all the
/// way. Without one it shows the whole picture in the box it is given.
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
  ///   not fit. The battle's layout shows the whole picture instead, so the
  ///   guide covers only the part of it such a camera would show in the
  ///   battle layout's box ([coverShare]): the box this view is given, or
  ///   under a [BattleCameraLayout] its [BattleCameraLayout.battleBox], in
  ///   the setup's layout too. So the guide grows with the picture there,
  ///   keeps its shape, and asks the user to stand where the battle's
  ///   layout does (W2b, option 가).
  /// - [BoxFit.contain]: the whole picture, as here; the guide covers it.
  final BoxFit guideFit;

  /// Width over height of a phone camera's picture held upright.
  static const _uprightShape = 3 / 4;

  /// The setup's guide over the camera for [exercise], and the camera box it
  /// was drawn for ([guideFit]), for the bot and the online battle alike:
  /// 한상우's push-up silhouette fills a cropping camera box. Squats have
  /// none yet: the standing silhouette (UAT-1 step 5) goes into their case
  /// when it comes.
  static ({Widget widget, BoxFit fit})? setupGuide(
    ExerciseType exercise, {
    required bool ready,
  }) => switch (exercise) {
    ExerciseType.pushUp => (
      widget: PoseSilhouetteGuide(ready: ready),
      fit: BoxFit.cover,
    ),
    ExerciseType.squat => null,
  };

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

  /// The picture's size for a camera of [shape] (width over height) at a
  /// layout [progress] (W2b 3-B 4.5): at 0 it fills [setupBox], cropping
  /// what does not fit; at 1 it fits whole in [battleBox]; in between its
  /// height goes evenly from the one to the other, in its own shape.
  static Size pictureSize(
    double shape, {
    required Size setupBox,
    required Size battleBox,
    required double progress,
  }) {
    if (shape <= 0 || setupBox.isEmpty || battleBox.isEmpty) return Size.zero;
    final filling = shape > setupBox.width / setupBox.height
        ? setupBox.height
        : setupBox.width / shape;
    final whole = shape > battleBox.width / battleBox.height
        ? battleBox.width / shape
        : battleBox.height;
    final height = filling + (whole - filling) * progress;
    return Size(height * shape, height);
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
    final layout = BattleCameraLayout.maybeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (layout == null) {
          return AspectRatio(
            aspectRatio: shape,
            child: _picture(_guideShare(shape, constraints.biggest)),
          );
        }
        final size = pictureSize(
          shape,
          setupBox: layout.setupBox,
          battleBox: layout.battleBox,
          progress: layout.progress,
        );
        // Centered in the box, and what does not fit is cut off.
        return ClipRect(
          child: OverflowBox(
            minWidth: size.width,
            maxWidth: size.width,
            minHeight: size.height,
            maxHeight: size.height,
            child: _picture(_guideShare(shape, layout.battleBox)),
          ),
        );
      },
    );
  }

  /// The share of the picture the guide covers, for the battle layout's
  /// camera [box] ([guideFit]).
  ({double width, double height}) _guideShare(double shape, Size box) =>
      guideFit == BoxFit.cover
      ? coverShare(shape, box)
      : (width: 1.0, height: 1.0);

  /// The picture and what is drawn on it, filling its box.
  Widget _picture(({double width, double height}) share) {
    final chest = chestSnapshot;
    final squat = squatSnapshot;
    final guide = this.guide;
    return Stack(
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
        if (guide != null) BattleGuideOverlay(share: share, guide: guide),
      ],
    );
  }
}

/// Lays the setup's [guide] over the middle [share] of the camera picture
/// (widths and heights as shares of the picture's) and dims the rest of the
/// picture as the push-up silhouette dims outside its outline
/// ([AppColors.setupGuideScrim]). So the strips a cropping camera would not
/// show, above and below the guide on a phone like the S22, are as dark as
/// the guide's own outside instead of a lighter band. A guide that covers
/// the whole picture leaves nothing to dim. The strips take no taps.
///
/// Where a strip meets the guide's box, the box's edge may fall inside a
/// pixel; two dimmings that each cover part of that pixel leave a lighter
/// line along it. So the guide and the strips are drawn into one layer of
/// their own, and the strips reach a point into the guide's box and take
/// the place of what the guide drew there ([BlendMode.src]): there the
/// guide dims the picture just as much, its outline keeps further in, and
/// the pixel of the edge gets the one shade.
class BattleGuideOverlay extends StatelessWidget {
  const BattleGuideOverlay({
    super.key,
    required this.share,
    required this.guide,
  });

  final ({double width, double height}) share;
  final Widget guide;

  @override
  Widget build(BuildContext context) {
    final guided = Center(
      child: FractionallySizedBox(
        widthFactor: share.width,
        heightFactor: share.height,
        child: guide,
      ),
    );
    if (share.width >= 1 && share.height >= 1) return guided;
    return ClipRect(
      // The layer the strips are added up in, apart from the camera.
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Stack(
        fit: StackFit.expand,
        children: [
          guided,
          IgnorePointer(child: CustomPaint(painter: _OutsideShare(share))),
        ],
      ),
    );
  }
}

/// The picture outside its middle [share], in the guide's dimming, over the
/// first [_overlap] of the guide's box on each cropped side, in place of
/// what is drawn below it in the same layer: drawn after the guide.
class _OutsideShare extends CustomPainter {
  const _OutsideShare(this.share);

  final ({double width, double height}) share;

  /// How far into the guide's box the strips reach: past the pixel its edge
  /// falls in at any pixel density, and short of the silhouette's white
  /// line, which ends 2 points above its box's bottom under the hands on an
  /// S22 (only the faint edge of the line's dark shadow reaches that far).
  static const _overlap = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final whole = Offset.zero & size;
    final inside = Rect.fromCenter(
      center: whole.center,
      width: share.width < 1
          ? size.width * share.width - 2 * _overlap
          : size.width,
      height: share.height < 1
          ? size.height * share.height - 2 * _overlap
          : size.height,
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(whole)
        ..addRect(inside),
      Paint()
        ..color = AppColors.setupGuideScrim
        ..blendMode = BlendMode.src,
    );
  }

  @override
  bool shouldRepaint(_OutsideShare oldDelegate) => oldDelegate.share != share;
}
