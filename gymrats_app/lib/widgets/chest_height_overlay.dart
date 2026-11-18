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
                phase: snapshot.phase,
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
    this.phase,
  });
  final PoseFrame frame;
  final double? baselineY;
  final bool mirror;

  /// The judge's phase: the shoulder line turns status green at the bottom.
  final RepPhase? phase;

  /// A9 spec 4, in screen points: the shoulder line is [lineWidth] over
  /// [outlineWidth] of ink, its dot [dotRadius] with an ink edge, and the
  /// start height's dashes [dashWidth] over [dashOutlineWidth] of ink; the
  /// names are pills [pillHeight] tall at the left, the lines starting after
  /// the wider pill as in the design.
  static const lineWidth = 8.0;
  static const outlineWidth = 14.0;
  static const dotRadius = 9.0;
  static const _dotEdge = 3.0;
  static const dashWidth = 3.0;
  static const dashOutlineWidth = 6.0;
  static const pillHeight = 22.0;
  static const _pillEdge = 2.0;

  /// The room between the start height's pill and the shoulder's.
  static const _pillGap = 2.0;

  /// A line's name, laid out.
  static TextPainter _name(String words) => TextPainter(
    text: TextSpan(text: words, style: BattleCameraText.cameraLineLabel),
    textDirection: TextDirection.ltr,
  )..layout();

  /// A name in a pill of [color] with an ink edge, at the left of the line
  /// at [y].
  static void _pill(Canvas canvas, TextPainter text, double y, Color color) {
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
    final lineColor = phase == RepPhase.bottom
        ? AppColors.statusGood
        : AppColors.card;
    final ink = Paint()
      ..color = AppColors.ink
      ..strokeWidth = outlineWidth
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;
    final baseline = baselineY;
    final hasBaseline = baseline != null && baseline.isFinite;
    final shoulderName = _name('어깨');
    final startName = _name('시작 높이');
    final start =
        AppSpacing.s4 +
        [
          shoulderName,
          if (hasBaseline) startName,
        ].map((name) => name.width + 2 * AppSpacing.s8).reduce(math.max) +
        AppSpacing.s4;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (hasBaseline) {
      final y = project(Offset(0, baseline), size).dy;
      final reference = Paint()
        ..color = AppColors.card
        ..strokeWidth = dashWidth;
      final referenceInk = Paint()
        ..color = AppColors.ink
        ..strokeWidth = dashOutlineWidth;
      for (double x = start; x < size.width - 12; x += 12) {
        final from = Offset(x, y);
        final to = Offset(math.min(x + 6, size.width - 12), y);
        canvas
          ..drawLine(from, to, referenceInk)
          ..drawLine(from, to, reference);
      }
      final x = size.width - 22;
      canvas.drawLine(Offset(x, y), Offset(x, current.dy), paint);
      for (final lineY in [y, current.dy]) {
        canvas.drawLine(Offset(x - 4, lineY), Offset(x + 4, lineY), paint);
      }
    }
    canvas.drawLine(
      Offset(start, current.dy),
      Offset(size.width - 12, current.dy),
      ink,
    );
    canvas.drawLine(
      Offset(start, current.dy),
      Offset(size.width - 12, current.dy),
      line,
    );
    canvas
      ..drawCircle(current, dotRadius, Paint()..color = lineColor)
      ..drawCircle(
        current,
        dotRadius,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _dotEdge,
      );
    if (hasBaseline) {
      // On its line, or above the shoulder's pill while the shoulders are
      // near the start height (at the top of a rep), so neither covers the
      // other.
      final y = math.min(
        project(Offset(0, baseline), size).dy,
        current.dy - pillHeight - _pillGap,
      );
      const half = pillHeight / 2;
      _pill(
        canvas,
        startName,
        y.clamp(half, math.max(half, size.height - half)),
        AppColors.card,
      );
    }
    _pill(canvas, shoulderName, current.dy, lineColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ChestHeightGuidePainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.baselineY != baselineY ||
      oldDelegate.mirror != mirror ||
      oldDelegate.phase != phase;
}
