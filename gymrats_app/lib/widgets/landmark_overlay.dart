import 'package:flutter/material.dart';

import '../models/pose_frame.dart';
import '../theme/app_theme.dart';

/// Landmark dots over a camera preview of the same size, as in the battle
/// design: likely landmarks are filled lime dots, unlikely ones hollow.
///
/// Positions are computed exactly as PoseCameraView computes its own dots
/// (see [landmarkPosition]), so the two line up on any preview.
class LandmarkOverlay extends StatelessWidget {
  const LandmarkOverlay({
    super.key,
    required this.frame,
    required this.mirror,
    required this.isVisible,
  });

  final PoseFrame frame;

  /// The front camera preview is mirrored, ML Kit coordinates are not.
  final bool mirror;

  /// Whether a landmark is likely enough to fill its dot.
  final bool Function(Keypoint keypoint) isVisible;

  /// The dots drawn: the face, arms, and legs. Fingers, mouth, heels, and
  /// toes are left out, as in the design.
  static const shown = [
    BodyLandmark.nose,
    BodyLandmark.leftEye,
    BodyLandmark.rightEye,
    BodyLandmark.leftEar,
    BodyLandmark.rightEar,
    BodyLandmark.leftShoulder,
    BodyLandmark.rightShoulder,
    BodyLandmark.leftElbow,
    BodyLandmark.rightElbow,
    BodyLandmark.leftWrist,
    BodyLandmark.rightWrist,
    BodyLandmark.leftHip,
    BodyLandmark.rightHip,
    BodyLandmark.leftKnee,
    BodyLandmark.rightKnee,
    BodyLandmark.leftAnkle,
    BodyLandmark.rightAnkle,
  ];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LandmarkPainter(
        frame: frame,
        mirror: mirror,
        isVisible: isVisible,
      ),
    );
  }
}

/// Where [keypoint] lands on a preview of [size], as PoseCameraView places
/// it: each axis scaled from the upright image, x mirrored for the front
/// camera.
Offset landmarkPosition(
  Keypoint keypoint,
  PoseFrame frame,
  Size size, {
  required bool mirror,
}) {
  final sx = size.width / frame.imageWidth;
  final sy = size.height / frame.imageHeight;
  final x = keypoint.x * sx;
  return Offset(mirror ? size.width - x : x, keypoint.y * sy);
}

class _LandmarkPainter extends CustomPainter {
  _LandmarkPainter({
    required this.frame,
    required this.mirror,
    required this.isVisible,
  });

  final PoseFrame frame;
  final bool mirror;
  final bool Function(Keypoint keypoint) isVisible;

  /// The design's sizes are for a camera 390 wide; they scale with it.
  static const _designWidth = 390.0;
  static const _jointRadius = 5.8;
  static const _faceRadius = 3.6;
  static const _hollowRadius = 4.5;

  static const _face = {
    BodyLandmark.nose,
    BodyLandmark.leftEye,
    BodyLandmark.rightEye,
    BodyLandmark.leftEar,
    BodyLandmark.rightEar,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _designWidth;
    final fill = Paint()..color = AppColors.accent;
    final rim = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale;
    final hollow = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale;
    for (final landmark in LandmarkOverlay.shown) {
      final keypoint = frame[landmark];
      if (keypoint == null) continue;
      final center = landmarkPosition(keypoint, frame, size, mirror: mirror);
      if (isVisible(keypoint)) {
        final radius =
            (_face.contains(landmark) ? _faceRadius : _jointRadius) * scale;
        canvas
          ..drawCircle(center, radius, fill)
          ..drawCircle(center, radius, rim);
      } else {
        canvas.drawCircle(center, _hollowRadius * scale, hollow);
      }
    }
  }

  @override
  bool shouldRepaint(_LandmarkPainter old) =>
      old.frame != frame || old.mirror != mirror;
}
