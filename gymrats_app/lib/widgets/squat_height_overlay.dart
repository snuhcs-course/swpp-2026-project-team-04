import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pose_frame.dart';
import '../services/pose/rep_judge.dart';
import '../theme/app_theme.dart';

/// Displays the same hip and knee heights that the squat judge used.
class SquatHeightOverlay extends StatelessWidget {
  const SquatHeightOverlay({
    super.key,
    required this.frame,
    required this.snapshot,
  });

  final PoseFrame? frame;
  final JudgeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final currentFrame = frame;
    if (currentFrame == null ||
        currentFrame.imageWidth <= 0 ||
        currentFrame.imageHeight <= 0 ||
        !currentFrame.imageWidth.isFinite ||
        !currentFrame.imageHeight.isFinite ||
        snapshot.squatHipY == null ||
        snapshot.squatKneeY == null ||
        snapshot.phase == RepPhase.lost) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: SquatHeightPainter(frame: currentFrame, snapshot: snapshot),
      ),
    );
  }
}

class SquatHeightPainter extends CustomPainter {
  SquatHeightPainter({required this.frame, required this.snapshot});
  final PoseFrame frame;
  final JudgeSnapshot snapshot;

  /// A9 spec 4, in screen points: each line is [lineWidth] of its color over
  /// [outlineWidth] of ink, and its name a pill [pillHeight] tall at its
  /// left, the lines starting after the wider pill as in the design.
  static const lineWidth = 8.0;
  static const outlineWidth = 14.0;
  static const pillHeight = 22.0;
  static const _pillEdge = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    // The knee line is the target height (amber); the hip line turns status
    // green at the bottom of the rep.
    final hipColor = snapshot.phase == RepPhase.bottom
        ? AppColors.statusGood
        : AppColors.card;
    final scale = math.max(
      size.width / frame.imageWidth,
      size.height / frame.imageHeight,
    );
    double projectY(double y) =>
        (y - frame.imageHeight / 2) * scale + size.height / 2;
    final hipY = projectY(snapshot.squatHipY!);
    final kneeY = projectY(snapshot.squatKneeY!);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // As in the design: the knee first, so at the bottom of a rep the green
    // hip line lies over it; both lines first, then the two names over them.
    TextPainter name(String words) => TextPainter(
      text: TextSpan(text: words, style: BattleCameraText.cameraLineLabel),
      textDirection: TextDirection.ltr,
    )..layout();
    final lines = [
      (kneeY, name('무릎'), AppColors.warning),
      (hipY, name('엉덩이'), hipColor),
    ];
    final start =
        AppSpacing.s4 +
        lines.map((l) => l.$2.width + 2 * AppSpacing.s8).reduce(math.max) +
        AppSpacing.s4;
    for (final (y, _, color) in lines) {
      final dark = Paint()
        ..color = AppColors.ink
        ..strokeWidth = outlineWidth
        ..strokeCap = StrokeCap.round;
      final line = Paint()
        ..color = color
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(start, y), Offset(size.width - 12, y), dark);
      canvas.drawLine(Offset(start, y), Offset(size.width - 12, y), line);
    }
    for (final (y, text, color) in lines) {
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          AppSpacing.s4,
          y - pillHeight / 2,
          text.width + 2 * AppSpacing.s8,
          pillHeight,
        ),
        const Radius.circular(pillHeight / 2),
      );
      canvas
        ..drawRRect(pill, Paint()..color = color)
        ..drawRRect(
          pill,
          Paint()
            ..color = AppColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = _pillEdge,
        );
      text.paint(
        canvas,
        Offset(AppSpacing.s4 + AppSpacing.s8, y - text.height / 2),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SquatHeightPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.snapshot != snapshot;
}
