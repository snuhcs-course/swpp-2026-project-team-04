import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../theme/app_theme.dart';

/// Where the archive's score graph puts its points (BArchive): the scores
/// oldest first from left to right, zero at the base line, the highest a
/// little under the top so its value fits above it.
abstract final class GrowthChartLayout {
  /// Room left and right of the first and the last point.
  static const padX = 12.0;

  /// Room above the highest point, for the value over the last one.
  static const padTop = 24.0;

  /// The base line, this far above the bottom.
  static const baseGap = 8.0;

  /// The base line reaches this close to the left and the right edge.
  static const baseInset = 10.0;

  /// The top of the scale, as a share of the highest score.
  static const headroom = 1.04;

  /// With more points than this, only the last one gets a dot.
  static const dotsUpTo = 12;

  /// The base line's height in a graph of [height].
  static double baseOf(double height) => height - baseGap;

  /// One point per score in a graph of [size]. A single score sits at the
  /// right end, where the newest one always is.
  static List<Offset> points(List<int> scores, Size size) {
    if (scores.isEmpty) return const [];
    final base = baseOf(size.height);
    final highest = scores.reduce(math.max) * headroom;
    final scale = highest > 0 ? (base - padTop) / highest : 0.0;
    final span = size.width - 2 * padX;
    final n = scores.length;
    return [
      for (var i = 0; i < n; i++)
        Offset(
          n == 1 ? size.width - padX : padX + i * span / (n - 1),
          base - math.max(0, scores[i]) * scale,
        ),
    ];
  }
}

/// The archive's score graph: a lime area under an ink line through the
/// scores, a dot on each but the last, and the last as a lime ring with
/// its score above it.
class ArchiveGrowthPainter extends CustomPainter {
  const ArchiveGrowthPainter({
    required this.scores,
    required this.valueStyle,
    this.textScaler = TextScaler.noScaling,
  });

  /// Oldest first.
  final List<int> scores;

  /// The last score's text.
  final TextStyle valueStyle;
  final TextScaler textScaler;

  static const _lineWidth = 2.5;
  static const _dotRadius = 3.0;
  static const _lastRadius = 6.5;
  static const _areaStrength = 0.45;

  /// Where the last score's text ends and sits, from the last point.
  static const _valueRight = 6.0;
  static const _valueAbove = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final base = GrowthChartLayout.baseOf(size.height);
    canvas.drawLine(
      Offset(GrowthChartLayout.baseInset, base),
      Offset(size.width - GrowthChartLayout.baseInset, base),
      Paint()
        ..color = AppColors.chartBar
        ..strokeWidth = 1,
    );
    final points = GrowthChartLayout.points(scores, size);
    if (points.isEmpty) return;
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final last = points.last;
    if (points.length > 1) {
      final area = Path.from(line)
        ..lineTo(last.dx, base)
        ..lineTo(points.first.dx, base)
        ..close();
      canvas
        ..drawPath(
          area,
          Paint()..color = AppColors.accent.withValues(alpha: _areaStrength),
        )
        ..drawPath(
          line,
          Paint()
            ..color = AppColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = _lineWidth
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
    }
    if (points.length <= GrowthChartLayout.dotsUpTo) {
      final dot = Paint()..color = AppColors.ink;
      for (final point in points.take(points.length - 1)) {
        canvas.drawCircle(point, _dotRadius, dot);
      }
    }
    canvas
      ..drawCircle(last, _lastRadius, Paint()..color = AppColors.accent)
      ..drawCircle(
        last,
        _lastRadius,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _lineWidth,
      );
    final value = TextPainter(
      text: TextSpan(
        text: '${scores.last}',
        style: valueStyle.copyWith(color: AppColors.ink),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    // The design's text-anchor end, on a baseline 12 above the point.
    final baseline = value.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    value.paint(
      canvas,
      Offset(
        math.max(0, last.dx + _valueRight - value.width),
        math.max(0, last.dy - _valueAbove - baseline),
      ),
    );
    value.dispose();
  }

  @override
  bool shouldRepaint(ArchiveGrowthPainter oldDelegate) =>
      !listEquals(oldDelegate.scores, scores) ||
      oldDelegate.valueStyle != valueStyle ||
      oldDelegate.textScaler != textScaler;
}

/// The heights of the archive's day bars: the most reps fill [max], the
/// others in proportion, and every bar is at least [min] high, also on a
/// day without battles.
List<double> archiveBarHeights(
  List<int> reps, {
  required double max,
  required double min,
}) {
  final most = reps.fold(0, math.max);
  return [
    for (final count in reps)
      most == 0 ? min : math.max(min, (count / most * max).roundToDouble()),
  ];
}

/// A small line drawing of [exercise] in ink: a push-up from the side, or
/// a squat.
class ArchiveExerciseIcon extends StatelessWidget {
  const ArchiveExerciseIcon(this.exercise, {super.key, this.size = 22});

  final ExerciseType exercise;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: ArchiveExerciseIconPainter(exercise),
  );
}

/// Draws the design's 24-point exercise icons, scaled to the canvas.
class ArchiveExerciseIconPainter extends CustomPainter {
  const ArchiveExerciseIconPainter(this.exercise);

  final ExerciseType exercise;

  /// The design's box and stroke.
  static const _box = 24.0;
  static const _stroke = 2.0;
  static const _headRadius = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _box, size.height / _box);
    final pen = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (exercise) {
      case ExerciseType.pushUp:
        canvas
          ..drawCircle(const Offset(4.5, 9), _headRadius, pen)
          ..drawLine(const Offset(7, 10.6), const Offset(20, 14.5), pen)
          ..drawLine(const Offset(8.6, 11.1), const Offset(8.6, 17), pen)
          ..drawLine(const Offset(20, 14.5), const Offset(21.3, 17.1), pen)
          ..drawLine(const Offset(2, 19.5), const Offset(22, 19.5), pen);
      case ExerciseType.squat:
        canvas
          ..drawCircle(const Offset(10.5, 4), _headRadius, pen)
          ..drawPath(
            Path()
              ..moveTo(10.5, 6.5)
              ..lineTo(9, 12.5)
              ..lineTo(14.5, 13.1)
              ..lineTo(13, 19.1),
            pen,
          )
          ..drawLine(const Offset(10, 8.6), const Offset(16.5, 9), pen)
          ..drawLine(const Offset(4, 20), const Offset(20, 20), pen);
    }
  }

  @override
  bool shouldRepaint(ArchiveExerciseIconPainter oldDelegate) =>
      oldDelegate.exercise != exercise;
}
