import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'feedback_stats_slots.dart';

/// The statistics graph (W7-STATS 3): a 92 high plot of equal slots with
/// the reps over some bars, and the letters under it. [notice] lies over
/// the top of the plot (a period without battles); with large text it may
/// grow past the graph, and the graph's room grows with it. Read as one
/// sentence, [semanticsLabel]; a placeholder graph passes none and is not
/// read.
class FeedbackStatsChart extends StatelessWidget {
  const FeedbackStatsChart({
    super.key,
    required this.chart,
    this.semanticsLabel,
    this.notice,
  });

  final StatsChart chart;
  final String? semanticsLabel;
  final Widget? notice;

  /// The notice's least height over the plot.
  static const noticeHeight = 80.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final axis = text.statsAxis;
    final graph = SizedBox(
      height:
          StatsChart.plotHeight +
          StatsChart.labelGap +
          scaler.scale(StatsChart.labelLine),
      child: CustomPaint(
        key: const ValueKey('feedback-stats-chart'),
        size: Size.infinite,
        painter: FeedbackStatsChartPainter(
          chart: chart,
          valueStyle: text.statsBarValue.copyWith(color: AppColors.ink),
          labelStyle: axis.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
          nowLabelStyle: axis.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          textScaler: scaler,
        ),
      ),
    );
    final label = semanticsLabel;
    final notice = this.notice;
    return Stack(
      children: [
        if (label == null)
          ExcludeSemantics(child: graph)
        else
          Semantics(
            container: true,
            label: label,
            child: ExcludeSemantics(child: graph),
          ),
        // Not positioned, so a notice taller than the graph is not cut.
        if (notice != null)
          SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: noticeHeight),
              child: notice,
            ),
          ),
      ],
    );
  }
}

/// Paints [chart]: the bars by their look, the reps over the bars that
/// show them, and the letters under the slots. A text wider than its slot
/// runs over both sides evenly.
class FeedbackStatsChartPainter extends CustomPainter {
  const FeedbackStatsChartPainter({
    required this.chart,
    required this.valueStyle,
    required this.labelStyle,
    required this.nowLabelStyle,
    this.textScaler = TextScaler.noScaling,
  });

  final StatsChart chart;
  final TextStyle valueStyle;
  final TextStyle labelStyle;

  /// The letters under the slot with today.
  final TextStyle nowLabelStyle;
  final TextScaler textScaler;

  /// The dashed outline of a day not come yet.
  static const _dash = 3.0;
  static const _dashGap = 2.0;

  /// The left edge and width of each slot in [width].
  static List<(double, double)> columns(StatsChart chart, double width) {
    final n = chart.slots.length;
    if (n == 0) return const [];
    final slot = math.max(0.0, (width - chart.gap * (n - 1)) / n);
    return [for (var i = 0; i < n; i++) (i * (slot + chart.gap), slot)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = StatsChart.plotHeight;
    for (final (i, (left, width)) in columns(chart, size.width).indexed) {
      final slot = chart.slots[i];
      final rect = Rect.fromLTWH(
        left,
        bottom - slot.barHeight,
        width,
        slot.barHeight,
      );
      _bar(canvas, slot, rect);
      final center = left + width / 2;
      if (slot.valueShown) {
        _text(
          canvas,
          '${slot.reps}',
          valueStyle,
          center,
          bottom: rect.top - StatsChart.valueGap,
        );
      }
      if (slot.label.isNotEmpty) {
        _text(
          canvas,
          slot.label,
          slot.now ? nowLabelStyle : labelStyle,
          center,
          top: bottom + StatsChart.labelGap,
        );
      }
    }
  }

  void _bar(Canvas canvas, StatsSlot slot, Rect rect) {
    final full = switch (slot.look) {
      StatsBarLook.value || StatsBarLook.now || StatsBarLook.skeleton => true,
      StatsBarLook.zero || StatsBarLook.future => false,
    };
    final radius = Radius.circular(
      full ? chart.radius : StatsChart.smallRadius,
    );
    if (slot.look == StatsBarLook.future) {
      final outline = Path()
        ..addRRect(RRect.fromRectAndRadius(rect.deflate(0.5), radius));
      final pen = Paint()
        ..color = AppColors.inactive
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (final metric in outline.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += _dash + _dashGap) {
          canvas.drawPath(metric.extractPath(d, d + _dash), pen);
        }
      }
      return;
    }
    final color = switch (slot.look) {
      StatsBarLook.value => AppColors.chartBar,
      StatsBarLook.now => AppColors.ink,
      StatsBarLook.zero => AppColors.border,
      _ => AppColors.facetLight,
    };
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = color,
    );
  }

  /// [text] centered on [center], its bottom at [bottom] or its top at
  /// [top].
  void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    double center, {
    double? bottom,
    double? top,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      Offset(center - painter.width / 2, top ?? bottom! - painter.height),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(FeedbackStatsChartPainter oldDelegate) =>
      oldDelegate.chart != chart ||
      oldDelegate.valueStyle != valueStyle ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.nowLabelStyle != nowLabelStyle ||
      oldDelegate.textScaler != textScaler;
}
