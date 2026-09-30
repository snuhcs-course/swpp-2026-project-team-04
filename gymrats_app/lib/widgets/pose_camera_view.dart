import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/pose_frame.dart';

const _visibleColor = Colors.greenAccent;

/// Camera preview filling the screen, with optional landmark dots.
///
/// Shared by the setup screen and the rep-judge demo. [controller] is null
/// until the camera is running, and the preview is black until then.
class PoseCameraView extends StatelessWidget {
  const PoseCameraView({
    super.key,
    required this.controller,
    this.frame,
    this.mirror = false,
    this.showLandmarks = false,
    this.isVisible,
  });

  final CameraController? controller;
  final PoseFrame? frame;

  /// The front camera preview is mirrored, ML Kit coordinates are not.
  final bool mirror;
  final bool showLandmarks;

  /// Paints a landmark green when this returns true. Defaults to a
  /// likelihood of at least 0.6.
  final bool Function(Keypoint keypoint, PoseFrame frame)? isVisible;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    final previewSize = controller?.value.previewSize;
    if (controller == null ||
        !controller.value.isInitialized ||
        previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }
    final frame = this.frame;
    // previewSize is always landscape (width > height). Swap it when the
    // screen is portrait so the preview box matches the screen. Landmarks are
    // in the upright image for the current device orientation, so they line
    // up with the box in both orientations.
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: landscape ? previewSize.width : previewSize.height,
          height: landscape ? previewSize.height : previewSize.width,
          child: CameraPreview(
            controller,
            child: showLandmarks && frame != null
                ? CustomPaint(
                    painter: _LandmarkPainter(
                      frame: frame,
                      mirror: mirror,
                      isVisible: isVisible ?? _likely,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  static bool _likely(Keypoint keypoint, PoseFrame frame) =>
      keypoint.likelihood >= 0.6;
}

/// Draws detected landmarks: green when visible, red otherwise.
class _LandmarkPainter extends CustomPainter {
  _LandmarkPainter({
    required this.frame,
    required this.mirror,
    required this.isVisible,
  });

  final PoseFrame frame;
  final bool mirror;
  final bool Function(Keypoint keypoint, PoseFrame frame) isVisible;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / frame.imageWidth;
    final sy = size.height / frame.imageHeight;
    final radius = size.shortestSide / 90;
    final visible = Paint()..color = _visibleColor;
    final hidden = Paint()..color = Colors.redAccent;
    for (final keypoint in frame.keypoints.values) {
      final x = keypoint.x * sx;
      canvas.drawCircle(
        Offset(mirror ? size.width - x : x, keypoint.y * sy),
        radius,
        isVisible(keypoint, frame) ? visible : hidden,
      );
    }
  }

  @override
  bool shouldRepaint(_LandmarkPainter old) =>
      old.frame != frame || old.mirror != mirror;
}
