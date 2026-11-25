import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Where the journal's trend chart puts its points (P13, draft C): one slot
/// per battle from left to right, oldest first, each point in the middle of
/// its slot so the days under the chart line up; zero at the base line, the
/// highest a little under the top so its value fits above it.
abstract final class TrendChartLayout {
  /// Room above the highest point, for its value.
  static const padTop = 24.0;

  /// The base line, this far above the bottom, with room for a value under
  /// the lowest point.
  static const padBottom = 20.0;

  /// The middle of each of [count] slots across [width].
  static List<double> xs(int count, double width) => [
    for (var i = 0; i < count; i++) (i + 0.5) * width / count,
  ];

  /// The height of [value] in a chart of [height] whose top is [highest].
  static double y(num value, num highest, double height) {
    final base = height - padBottom;
    if (highest <= 0) return base;
    return base - math.max(0, value) / highest * (base - padTop);
  }

  /// One point per value in a chart of [size].
  static List<Offset> points(List<int> values, Size size) {
    if (values.isEmpty) return const [];
    final highest = values.reduce(math.max);
    final xs = TrendChartLayout.xs(values.length, size.width);
    return [
      for (var i = 0; i < values.length; i++)
        Offset(xs[i], y(values[i], highest, size.height)),
    ];
  }

  /// The mean of [values]; 0 without any.
  static double mean(List<int> values) =>
      values.isEmpty ? 0 : values.fold(0, (sum, v) => sum + v) / values.length;
}

/// The journal's trend chart: a green line through [values], a white dot on
/// each but the newest (a filled green one), the value over each point, and
/// the mean as a dashed grey line named "평균 N".
class ArchiveTrendPainter extends CustomPainter {
  ArchiveTrendPainter({
    required this.values,
    required this.labelStyle,
    required this.meanStyle,
  });

  final List<int> values;
  final TextStyle labelStyle;
  final TextStyle meanStyle;

  static const _line = 2.5;
  static const _dot = 4.0;
  static const _lastDot = 6.0;
  static const _dash = 4.0;
  static const _labelGap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final points = TrendChartLayout.points(values, size);
    final highest = values.reduce(math.max);
    final grid = Paint()
      ..color = AppColors.facetLight
      ..strokeWidth = 1;
    final base = size.height - TrendChartLayout.padBottom;
    canvas
      ..drawLine(
        Offset(0, TrendChartLayout.padTop),
        Offset(size.width, TrendChartLayout.padTop),
        grid,
      )
      ..drawLine(Offset(0, base), Offset(size.width, base), grid);

    final mean = TrendChartLayout.mean(values);
    final meanY = TrendChartLayout.y(mean, highest, size.height);
    final dash = Paint()
      ..color = AppColors.inactive
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 2 * _dash) {
      canvas.drawLine(
        Offset(x, meanY),
        Offset(math.min(size.width, x + _dash), meanY),
        dash,
      );
    }
    _text(
      canvas,
      '평균 ${mean.round()}',
      meanStyle,
      Offset(0, meanY - _labelGap),
      above: true,
      alignLeft: true,
    );

    final line = Paint()
      ..color = AppColors.statusGood
      ..strokeWidth = _line
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    if (points.length > 1) {
      canvas.drawPath(Path()..addPolygon(points, false), line);
    }
    for (var i = 0; i < points.length; i++) {
      final last = i == points.length - 1;
      if (last) {
        canvas.drawCircle(
          points[i],
          _lastDot,
          Paint()..color = AppColors.statusGood,
        );
      } else {
        canvas
          ..drawCircle(points[i], _dot, Paint()..color = AppColors.card)
          ..drawCircle(points[i], _dot, line..strokeWidth = 2);
        line.strokeWidth = _line;
      }
      _text(
        canvas,
        '${values[i]}',
        labelStyle,
        points[i] - const Offset(0, _lastDot + _labelGap),
        above: true,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at, {
    bool above = false,
    bool alignLeft = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignLeft ? at.dx : at.dx - painter.width / 2;
    final dy = above ? at.dy - painter.height : at.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(ArchiveTrendPainter old) =>
      !listEquals(old.values, values) ||
      old.labelStyle != labelStyle ||
      old.meanStyle != meanStyle;
}
