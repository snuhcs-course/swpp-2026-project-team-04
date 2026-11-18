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
    this.bold = false,
  });

  final PoseFrame frame;

  /// The front camera preview is mirrored, ML Kit coordinates are not.
  final bool mirror;

  /// Whether a landmark is likely enough to fill its dot.
  final bool Function(Keypoint keypoint) isVisible;

  /// The battle camera's bold look (A9 spec 4): larger white joints with an
  /// ink edge, joined by an ink-edged white skeleton between likely joints.
  final bool bold;

  /// The skeleton's bones in the bold look.
  static const bones = [
    (BodyLandmark.leftShoulder, BodyLandmark.rightShoulder),
    (BodyLandmark.leftShoulder, BodyLandmark.leftElbow),
    (BodyLandmark.leftElbow, BodyLandmark.leftWrist),
    (BodyLandmark.rightShoulder, BodyLandmark.rightElbow),
    (BodyLandmark.rightElbow, BodyLandmark.rightWrist),
    (BodyLandmark.leftShoulder, BodyLandmark.leftHip),
    (BodyLandmark.rightShoulder, BodyLandmark.rightHip),
    (BodyLandmark.leftHip, BodyLandmark.rightHip),
    (BodyLandmark.leftHip, BodyLandmark.leftKnee),
    (BodyLandmark.leftKnee, BodyLandmark.leftAnkle),
    (BodyLandmark.rightHip, BodyLandmark.rightKnee),
    (BodyLandmark.rightKnee, BodyLandmark.rightAnkle),
  ];

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
        bold: bold,
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
    this.bold = false,
  });

  final PoseFrame frame;
  final bool mirror;
  final bool Function(Keypoint keypoint) isVisible;
  final bool bold;

  /// The design's sizes are for a camera 390 wide; they scale with it.
  static const _designWidth = 390.0;
  static const _jointRadius = 5.8;
  static const _faceRadius = 3.6;
  static const _hollowRadius = 4.5;

  /// The bold look's sizes are the A9 design's, in screen points for the
  /// battle's camera picture, 290 wide on an S22; they scale with it.
  static const _boldDesignWidth = 290.0;
  static const _boldJointRadius = 8.0;
  static const _boldJointEdge = 2.5;
  static const _boneWidth = 5.0;
  static const _boneOutlineWidth = 10.0;

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
    final boldScale = size.width / _boldDesignWidth;
    if (bold) _paintBones(canvas, size, boldScale);
    final fill = Paint()..color = bold ? AppColors.card : AppColors.accent;
    final rim = Paint()
      ..color = bold ? AppColors.ink : AppColors.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = bold ? _boldJointEdge * boldScale : 1.8 * scale;
    final hollow = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale;
    for (final landmark in LandmarkOverlay.shown) {
      final keypoint = frame[landmark];
      if (keypoint == null) continue;
      final center = landmarkPosition(keypoint, frame, size, mirror: mirror);
      if (isVisible(keypoint)) {
        final radius = bold
            ? (_face.contains(landmark) ? _faceRadius : _boldJointRadius) *
                  boldScale
            : (_face.contains(landmark) ? _faceRadius : _jointRadius) * scale;
        canvas
          ..drawCircle(center, radius, fill)
          ..drawCircle(center, radius, rim);
      } else {
        canvas.drawCircle(center, _hollowRadius * scale, hollow);
      }
    }
  }

  /// The bold look's skeleton: every bone between two likely joints, all in
  /// ink first and then in white over it, so the joins stay clean.
  void _paintBones(Canvas canvas, Size size, double boldScale) {
    final shown = [
      for (final (a, b) in LandmarkOverlay.bones)
        if (frame[a] case final from?)
          if (frame[b] case final to?)
            if (isVisible(from) && isVisible(to))
              (
                landmarkPosition(from, frame, size, mirror: mirror),
                landmarkPosition(to, frame, size, mirror: mirror),
              ),
    ];
    for (final (color, width) in [
      (AppColors.ink, _boneOutlineWidth),
      (AppColors.card, _boneWidth),
    ]) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = width * boldScale
        ..strokeCap = StrokeCap.round;
      for (final (from, to) in shown) {
        canvas.drawLine(from, to, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LandmarkPainter old) =>
      old.frame != frame || old.mirror != mirror || old.bold != bold;
}
