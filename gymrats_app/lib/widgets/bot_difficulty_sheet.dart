import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/battle_rules.dart';
import '../models/bot_difficulty.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../theme/app_theme.dart';

/// Asks how hard the bot should play. Null when the user closes the sheet
/// without choosing.
Future<BotDifficulty?> showBotDifficultySheet(
  BuildContext context, {
  required ExerciseType exercise,
}) => showModalBottomSheet<BotDifficulty>(
  context: context,
  backgroundColor: AppColors.card,
  showDragHandle: true,
  // Taller than the default limit with a large system text size.
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    side: BorderSide(color: AppColors.border),
  ),
  builder: (_) => BotDifficultySheet(exercise: exercise),
);

/// One card per level, in a row. Tapping a card closes the sheet with it.
class BotDifficultySheet extends StatelessWidget {
  const BotDifficultySheet({super.key, required this.exercise});

  final ExerciseType exercise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          0,
          AppSpacing.s20,
          AppSpacing.s32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('어떤 봇과 붙어볼까요?', style: text.headlineMedium),
            const SizedBox(height: AppSpacing.s4),
            Text(
              '${exercise.koreanName} · ${battleDuration.inSeconds}초 · 1v1',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, level)
                      in BotDifficulty.values.indexed) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.s8),
                    Expanded(child: _LevelCard(level)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The level's picture, name, reps and one line. Each text stays on one line
/// in a narrow card, shrinking with a large system text size.
class _LevelCard extends StatelessWidget {
  const _LevelCard(this.level);

  final BotDifficulty level;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reps = level.validRange(battleDuration);
    void choose() => Navigator.pop(context, level);
    // One sentence for a screen reader, which also loses the InkWell's tap.
    return Semantics(
      button: true,
      label:
          '${level.label}, ${battleDuration.inSeconds}초에 $reps회, '
          '${level.summary}',
      onTap: choose,
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.cardHigh,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: choose,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: AppSpacing.s16,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BotDifficultyPicture(level),
                const SizedBox(height: AppSpacing.s8),
                _OneLine(level.label, style: text.headlineSmall),
                const SizedBox(height: AppSpacing.s4),
                _OneLine(
                  reps,
                  style: text.titleLarge?.copyWith(color: AppColors.opponent),
                ),
                const SizedBox(height: AppSpacing.s4),
                _OneLine(
                  level.summary,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OneLine extends StatelessWidget {
  const _OneLine(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, style: style),
  );
}

/// The same line-drawn robot in every level. A stronger level draws it in a
/// stronger pink and adds to it: lines at its sides, then a second pair and a
/// star, so the pictures alone read in order.
class BotDifficultyPicture extends StatelessWidget {
  const BotDifficultyPicture(this.level, {super.key});

  final BotDifficulty level;

  /// The design's canvas; the painter scales it to its size.
  static const designSize = Size(72, 56);

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox.fromSize(
      size: designSize,
      child: CustomPaint(painter: _BotPainter(level)),
    ),
  );
}

class _BotPainter extends CustomPainter {
  const _BotPainter(this.level);

  final BotDifficulty level;

  /// How strong the expert's outer lines are, behind its inner ones.
  static const _outerLineAlpha = 0.7;

  /// The star's inner points, as a share of its outer ones.
  static const _starWaist = 0.45;

  /// How strong the robot's pink is. The weakest still stands out from the
  /// card at 3:1.
  double get _strength => switch (level) {
    BotDifficulty.beginner => 0.7,
    BotDifficulty.intermediate => 0.85,
    BotDifficulty.expert => 1,
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / BotDifficultyPicture.designSize.width);
    final pink = AppColors.opponent.withValues(alpha: _strength);
    final line = Paint()
      ..color = pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = pink;

    canvas
      ..drawRRect(
        RRect.fromRectXY(const Rect.fromLTWH(21, 25, 30, 22), 6, 6),
        line,
      )
      ..drawCircle(const Offset(29.5, 35), 2, fill)
      ..drawCircle(const Offset(42.5, 35), 2, fill);

    if (level == BotDifficulty.expert) {
      canvas.drawLine(const Offset(36, 25), const Offset(36, 15), line);
      final star = _star(const Offset(36, 9), 6);
      canvas
        ..drawPath(star, fill)
        ..drawPath(star, line..strokeWidth = 0.5);
      line.strokeWidth = 2;
    } else {
      canvas
        ..drawLine(const Offset(36, 25), const Offset(36, 18), line)
        ..drawCircle(const Offset(36, 16.5), 1.5, fill);
    }

    if (level != BotDifficulty.beginner) {
      _drawBothSides(
        canvas,
        Path()
          ..moveTo(14, 23)
          ..cubicTo(9, 31, 9, 42, 16, 50),
        line,
      );
    }
    if (level == BotDifficulty.expert) {
      _drawBothSides(
        canvas,
        Path()
          ..moveTo(7, 19)
          ..cubicTo(1, 30, 1, 44, 10, 54),
        line..color = AppColors.opponent.withValues(alpha: _outerLineAlpha),
      );
    }
  }

  /// Draws [path], and its mirror image across the picture's middle.
  void _drawBothSides(Canvas canvas, Path path, Paint paint) {
    canvas
      ..drawPath(path, paint)
      ..save()
      ..translate(BotDifficultyPicture.designSize.width, 0)
      ..scale(-1, 1)
      ..drawPath(path, paint)
      ..restore();
  }

  Path _star(Offset center, double radius) {
    final path = Path();
    for (var point = 0; point < 10; point++) {
      final position =
          center +
          Offset.fromDirection(
            -math.pi / 2 + point * math.pi / 5,
            point.isEven ? radius : radius * _starWaist,
          );
      if (point == 0) {
        path.moveTo(position.dx, position.dy);
      } else {
        path.lineTo(position.dx, position.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_BotPainter oldDelegate) => oldDelegate.level != level;
}
