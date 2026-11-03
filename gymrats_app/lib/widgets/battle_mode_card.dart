import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../theme/app_theme.dart';
import 'exercise_sheet.dart';

/// One way to start a battle: a picture over a title and one line. Home shows
/// one per mode, side by side. The [main] one has the lime edge.
class BattleModeCard extends StatelessWidget {
  const BattleModeCard({
    super.key,
    required this.title,
    required this.line,
    required this.picture,
    required this.onTap,
    this.main = false,
  });

  final String title;
  final String line;
  final Widget picture;
  final VoidCallback onTap;
  final bool main;

  static const _pictureHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // One sentence for a screen reader, which also loses the InkWell's tap.
    return Semantics(
      button: true,
      label: '$title, $line',
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: main
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
                side: BorderSide(color: AppColors.accent, width: 2),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ink, so a tap's ripple shows over the band too.
              Ink(
                height: _pictureHeight,
                color: main
                    ? AppColors.accent.withValues(alpha: 0.08)
                    : AppColors.cardHigh,
                child: Center(child: picture),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OneLine(title, style: text.headlineSmall),
                    const SizedBox(height: AppSpacing.s4),
                    _OneLine(
                      line,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    alignment: Alignment.centerLeft,
    child: Text(text, maxLines: 1, style: style),
  );
}

/// The user in lime, facing the opponent, under "VS".
class BattleModePicture extends StatelessWidget {
  const BattleModePicture._(this.opponent);

  /// A person in pink, doing the same push-up.
  const BattleModePicture.online()
    : this._(
        const ExercisePictogram(
          ExerciseType.pushUp,
          color: AppColors.opponent,
          size: _figureSize,
        ),
      );

  /// RepBot.
  const BattleModePicture.bot()
    : this._(
        const CustomPaint(
          size: Size(_figureWidth, _rowHeight),
          painter: _RepBotPainter(),
        ),
      );

  final Widget opponent;

  /// 0.8 times the 72×40 design.
  static const _figureWidth = 58.0;
  static const _figureSize = Size(_figureWidth, 32);

  /// Room for RepBot, who stands taller than a push-up.
  static const _rowHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VS',
            style: text.titleLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s4),
          // The same height either way, so "VS" sits level on both cards.
          SizedBox(
            height: _rowHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform.flip(
                  flipX: true,
                  child: const ExercisePictogram(
                    ExerciseType.pushUp,
                    size: _figureSize,
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                opponent,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// RepBot in the opponent's pink, on the same floor as the figure beside it,
/// in the same line widths.
class _RepBotPainter extends CustomPainter {
  const _RepBotPainter();

  /// The figure's floor: 0.8 times its 36, under the 12 it stands below the
  /// top of the row.
  static const _floor = 40.8;

  @override
  void paint(Canvas canvas, Size size) {
    final floor = Paint()
      ..color = AppColors.opponent.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    final line = Paint()
      ..color = AppColors.opponent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = AppColors.opponent;
    canvas
      ..drawLine(const Offset(3.2, _floor), const Offset(56, _floor), floor)
      ..drawRRect(
        RRect.fromRectXY(const Rect.fromLTWH(14, _floor - 24, 30, 24), 6, 6),
        line,
      )
      ..drawLine(const Offset(29, _floor - 24), const Offset(29, 9.8), line)
      ..drawCircle(const Offset(29, 8.3), 2, fill)
      ..drawCircle(const Offset(22.5, _floor - 13), 2, fill)
      ..drawCircle(const Offset(35.5, _floor - 13), 2, fill);
  }

  @override
  bool shouldRepaint(_RepBotPainter oldDelegate) => false;
}
