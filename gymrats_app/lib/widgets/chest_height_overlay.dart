import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pose_frame.dart';
import '../services/pose/rep_judge.dart';
import '../theme/app_theme.dart';

/// Chest height is an estimate from the shoulder midpoint, not a chest landmark
/// or a real-world distance. Losing either shoulder hides the guides immediately.
class ChestHeightOverlay extends StatelessWidget {
  const ChestHeightOverlay({
    super.key,
    required this.frame,
    required this.snapshot,
    this.mirror = false,
    this.drawGuide = true,
  });

  final PoseFrame? frame;
  final JudgeSnapshot snapshot;
  final bool mirror, drawGuide;

  static bool visible(PoseFrame? frame) {
    if (frame == null ||
        !frame.imageWidth.isFinite ||
        !frame.imageHeight.isFinite ||
        frame.imageWidth <= 0 ||
        frame.imageHeight <= 0) {
      return false;
    }
    return [BodyLandmark.leftShoulder, BodyLandmark.rightShoulder].every((id) {
      final p = frame[id];
      return p != null &&
          p.likelihood.isFinite &&
          p.likelihood >= .6 &&
          p.x.isFinite &&
          p.y.isFinite &&
          p.x >= 0 &&
          p.x <= frame.imageWidth &&
          p.y >= 0 &&
          p.y <= frame.imageHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final seen = visible(frame);
    final drop = seen && snapshot.shoulderDrop?.isFinite == true
        ? snapshot.shoulderDrop
        : null;
    final percent = drop == null ? null : (math.max(0, drop) * 100).round();
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (seen && drawGuide)
            CustomPaint(
              painter: ChestHeightGuidePainter(
                frame: frame!,
                baselineY: snapshot.topShoulderY,
                mirror: mirror,
              ),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 224),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: .85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: .5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '가슴 높이 · 어깨 중심 추정',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    !seen
                        ? '양쪽 어깨가 보이도록 해주세요'
                        : percent == null
                        ? '시작 높이 확인 중…'
                        : '하강 $percent% · 어깨 너비 기준',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  if (!drawGuide && percent != null) ...[
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 180,
                      child: LinearProgressIndicator(
                        value: (percent / 100).clamp(0, 1),
                        color: AppColors.accent,
                        backgroundColor: AppColors.border,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uses the same cover projection as the camera, including cropped previews.
class ChestHeightGuidePainter extends CustomPainter {
  ChestHeightGuidePainter({
    required this.frame,
    required this.baselineY,
    required this.mirror,
  });
  final PoseFrame frame;
  final double? baselineY;
  final bool mirror;

  Offset project(Offset point, Size size) {
    final scale = math.max(
      size.width / frame.imageWidth,
      size.height / frame.imageHeight,
    );
    final x = (point.dx - frame.imageWidth / 2) * scale + size.width / 2;
    return Offset(
      mirror ? size.width - x : x,
      (point.dy - frame.imageHeight / 2) * scale + size.height / 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final left = frame[BodyLandmark.leftShoulder]!,
        right = frame[BodyLandmark.rightShoulder]!;
    final current = project(
      Offset((left.x + right.x) / 2, (left.y + right.y) / 2),
      size,
    );
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawLine(
      Offset(12, current.dy),
      Offset(size.width - 12, current.dy),
      paint,
    );
    canvas.drawCircle(current, 5, paint);
    final baseline = baselineY;
    if (baseline != null && baseline.isFinite) {
      final y = project(Offset(0, baseline), size).dy;
      final reference = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: .7)
        ..strokeWidth = 1.5;
      for (double x = 12; x < size.width - 12; x += 12) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 6, size.width - 12), y),
          reference,
        );
      }
      final x = size.width - 22;
      canvas.drawLine(Offset(x, y), Offset(x, current.dy), paint);
      for (final lineY in [y, current.dy]) {
        canvas.drawLine(Offset(x - 4, lineY), Offset(x + 4, lineY), paint);
      }
      final label = TextPainter(
        text: const TextSpan(
          text: '시작 높이',
          style: TextStyle(
            fontSize: 11,
            fontFamily: AppFonts.body,
            color: AppColors.textPrimary,
            backgroundColor: AppColors.background,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(14, (y - 16).clamp(0, math.max(0, size.height - label.height))),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ChestHeightGuidePainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.baselineY != baselineY ||
      oldDelegate.mirror != mirror;
}
