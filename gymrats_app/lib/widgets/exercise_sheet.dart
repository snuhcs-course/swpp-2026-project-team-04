import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';

/// Asks which exercise to battle in, under the line [subtitle]. Null when the
/// user closes the sheet without choosing.
Future<ExerciseType?> showExerciseSheet(
  BuildContext context, {
  required String subtitle,
  required UserProfile profile,
}) => showModalBottomSheet<ExerciseType>(
  context: context,
  backgroundColor: AppColors.card,
  showDragHandle: true,
  // Taller than the default limit with a large system text size.
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    side: BorderSide(color: AppColors.border),
  ),
  builder: (_) => ExerciseSheet(subtitle: subtitle, profile: profile),
);

/// One card per exercise, side by side. Tapping a card closes the sheet with it.
class ExerciseSheet extends StatelessWidget {
  const ExerciseSheet({
    super.key,
    required this.subtitle,
    required this.profile,
  });

  final String subtitle;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          0,
          AppSpacing.s20,
          AppSpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OneLine(
              '어떤 종목으로 붙을까요?',
              alignment: Alignment.centerLeft,
              style: text.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              subtitle,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s24),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, exercise)
                      in ExerciseType.values.indexed) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _ExerciseCard(
                        exercise,
                        best: profile.bestOf(exercise),
                      ),
                    ),
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

/// The exercise's drawing, its name and the user's best in it.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard(this.exercise, {required this.best});

  final ExerciseType exercise;
  final PersonalBest? best;

  /// The best's number and unit: points, or reps with none above 0, or a dash
  /// with nothing to show, as before the first battle.
  (String, String) get _best => switch (best) {
    null => ('—', ''),
    final best when best.readsInPoints => ('${best.score}', '점'),
    final best => ('${best.reps}', '회'),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (value, unit) = _best;
    final number = text.titleLarge!.copyWith(color: AppColors.textPrimary);
    void choose() => Navigator.pop(context, exercise);
    // One sentence for a screen reader, which also loses the InkWell's tap.
    return Semantics(
      button: true,
      label: '${exercise.koreanName}, 개인 최고 $value$unit',
      onTap: choose,
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.cardHigh,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: choose,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExercisePictogram(exercise),
                const SizedBox(height: AppSpacing.s8),
                _OneLine(exercise.koreanName, style: text.headlineSmall),
                const SizedBox(height: AppSpacing.s4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '개인 최고 '),
                        TextSpan(text: value, style: number),
                        TextSpan(text: unit),
                      ],
                    ),
                    maxLines: 1,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    // The number's height whatever fits on the line, so the
                    // row's measured height holds with a large text size.
                    strutStyle: StrutStyle.fromTextStyle(
                      number,
                      forceStrutHeight: true,
                    ),
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
  const _OneLine(this.text, {this.style, this.alignment = Alignment.center});

  final String text;
  final TextStyle? style;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: Text(text, maxLines: 1, style: style),
  );
}

/// An exercise as a line drawing on a floor line, in [color].
class ExercisePictogram extends StatelessWidget {
  const ExercisePictogram(
    this.exercise, {
    super.key,
    this.color = AppColors.textPrimary,
    this.size = defaultSize,
  });

  final ExerciseType exercise;
  final Color color;
  final Size size;

  /// 1.5 times the 72×40 design.
  static const defaultSize = Size(108, 60);

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: size, painter: _ExercisePainter(exercise, color));
}

/// Designed on a 72×40 box and stretched to the canvas. Only the points scale;
/// line widths stay the same.
class _ExercisePainter extends CustomPainter {
  const _ExercisePainter(this.exercise, this.color);

  final ExerciseType exercise;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 72;
    final sy = size.height / 40;
    Offset at(double x, double y) => Offset(x * sx, y * sy);
    final floor = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    final figure = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(at(4, 36), at(70, 36), floor);
    switch (exercise) {
      case ExerciseType.pushUp:
        canvas
          ..drawCircle(at(10, 15), 4.5 * sx, figure) // head
          ..drawLine(at(16, 18), at(64, 30), figure) // body
          ..drawLine(at(18, 18), at(18, 34), figure) // arm
          ..drawLine(at(64, 30), at(66, 34), figure); // feet
      case ExerciseType.squat:
        canvas
          ..drawCircle(at(36, 5), 4.5 * sx, figure) // head
          ..drawLine(at(47, 23), at(40.5, 11), figure) // body
          ..drawLine(at(40, 12), at(24, 13), figure) // arms
          ..drawPath(
            // Hip to knee, knee to ankle, ankle to toe.
            Path()
              ..moveTo(at(47, 23).dx, at(47, 23).dy)
              ..lineTo(at(30, 22).dx, at(30, 22).dy)
              ..lineTo(at(37, 34).dx, at(37, 34).dy)
              ..lineTo(at(30, 34).dx, at(30, 34).dy),
            figure,
          );
    }
  }

  @override
  bool shouldRepaint(_ExercisePainter oldDelegate) =>
      oldDelegate.exercise != exercise || oldDelegate.color != color;
}
