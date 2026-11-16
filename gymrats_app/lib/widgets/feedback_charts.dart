import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/battle_rules.dart';
import '../models/form_report.dart';
import '../theme/app_theme.dart';

/// Seconds as the feedback screen writes them: "5" for a whole number, one
/// decimal otherwise ("2.8"), since a KO round cuts its slices short.
String feedbackSeconds(double seconds) {
  final tenths = (seconds * 10).round();
  return tenths % 10 == 0
      ? '${tenths ~/ 10}'
      : (tenths / 10).toStringAsFixed(1);
}

/// The time the charts span: the round's [battleTimeSlices] slices of
/// [sliceSeconds], so a 30 s round is 30 and a KO round is cut as short.
double _span(double sliceSeconds) => sliceSeconds * battleTimeSlices;

double _seconds(Duration d) => d.inMilliseconds / 1000;

/// The samples a chart draws: those taken within the round's [span]. A
/// frame handled just after the round ended is left out, so it neither
/// shows nor stretches the scale, and data only there counts as none.
Iterable<FormSample> _inRound(List<FormSample> samples, double span) =>
    samples.where((s) => _seconds(s.at) <= span);

/// The depth over the round (BFeedback): an ink line, a gray dashed mark at
/// each judged rep, and an amber square on top of a rejected rep's mark.
/// Gaps in the line are where the depth was not seen.
///
/// A push-up's head drop runs on a scale up to 2 shoulder widths or more; a
/// squat's share of the standing thigh up to 1 or more, in halves.
class FeedbackDepthPlot extends StatelessWidget {
  const FeedbackDepthPlot({
    super.key,
    required this.samples,
    required this.reps,
    required this.sliceSeconds,
    this.squat = false,
  });

  final List<FormSample> samples;
  final List<RepRecord> reps;
  final double sliceSeconds;
  final bool squat;

  static const double height = 180;

  /// Whether [samples] hold a depth to draw within the round of
  /// [sliceSeconds] slices.
  static bool hasData(
    List<FormSample> samples, {
    required double sliceSeconds,
  }) => _inRound(samples, _span(sliceSeconds)).any((s) => s.depth != null);

  @override
  Widget build(BuildContext context) {
    final span = _span(sliceSeconds);
    final depths = [for (final s in _inRound(samples, span)) ?s.depth];
    if (depths.isEmpty) return const SizedBox(height: height);
    final deepest = depths.reduce(math.max);
    final top = squat
        ? math.max(1.0, (deepest * 2).ceil() / 2)
        : math.max(2.0, deepest).ceilToDouble();
    final bottom = math.min(0.0, depths.reduce(math.min)).floorToDouble();
    final rejected = [
      for (final r in reps)
        if (!r.valid) FlSpot(math.min(_seconds(r.at), span), top),
    ];
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: span,
          minY: bottom,
          maxY: top,
          // No clip: the scale already holds every sample the line draws
          // (top at or above the deepest, bottom at or below the shallowest
          // of the samples within the round; a sample after the round is
          // not drawn), and a clip would cut a rejected rep's square at the
          // round's end, which hangs into the room on the right.
          clipData: const FlClipData.none(),
          lineBarsData: [
            _line(samples, (s) => s.depth, AppColors.ink, span: span),
            if (rejected.isNotEmpty)
              LineChartBarData(
                spots: rejected,
                barWidth: 0,
                color: Colors.transparent,
                dotData: FlDotData(
                  getDotPainter: (_, _, _, _) => const FeedbackRejectMark(),
                ),
              ),
          ],
          extraLinesData: ExtraLinesData(
            verticalLines: [
              for (final r in reps)
                VerticalLine(
                  x: math.min(_seconds(r.at), span),
                  color: AppColors.line.withValues(alpha: 0.6),
                  strokeWidth: 1,
                  dashArray: const [3, 3],
                ),
            ],
          ),
          titlesData: _titles(
            context,
            (v) => v.toStringAsFixed(1),
            0.5,
            sliceSeconds,
          ),
          gridData: _grid(0.5),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}

/// Both elbow angles over the round (BFeedback): the left arm a solid ink
/// line, the right arm a dashed gray one. Gaps are where an arm was hidden.
class FeedbackElbowPlot extends StatelessWidget {
  const FeedbackElbowPlot({
    super.key,
    required this.samples,
    required this.sliceSeconds,
  });

  final List<FormSample> samples;
  final double sliceSeconds;

  static const double height = 180;

  /// Whether [samples] saw either arm within the round of [sliceSeconds]
  /// slices.
  static bool hasData(
    List<FormSample> samples, {
    required double sliceSeconds,
  }) => _inRound(
    samples,
    _span(sliceSeconds),
  ).any((s) => s.leftElbow != null || s.rightElbow != null);

  @override
  Widget build(BuildContext context) {
    final span = _span(sliceSeconds);
    return _AngleChart(
      sliceSeconds: sliceSeconds,
      lines: [
        _line(samples, (s) => s.leftElbow, AppColors.ink, span: span),
        _line(
          samples,
          (s) => s.rightElbow,
          AppColors.line,
          span: span,
          dashes: FeedbackLegend.dashes,
        ),
      ],
    );
  }
}

/// A squat's hip angle (shoulder–hip–knee) over the round: one solid ink
/// line, near 180° standing and smaller the lower the squat. Gaps are where
/// the body was not seen. The analyzer judges no angle of a squat, so the
/// chart only shows it.
class FeedbackHipPlot extends StatelessWidget {
  const FeedbackHipPlot({
    super.key,
    required this.samples,
    required this.sliceSeconds,
  });

  final List<FormSample> samples;
  final double sliceSeconds;

  /// Whether [samples] hold a hip angle within the round of
  /// [sliceSeconds] slices.
  static bool hasData(
    List<FormSample> samples, {
    required double sliceSeconds,
  }) => _inRound(samples, _span(sliceSeconds)).any((s) => s.hipAngle != null);

  @override
  Widget build(BuildContext context) => _AngleChart(
    sliceSeconds: sliceSeconds,
    lines: [
      _line(
        samples,
        (s) => s.hipAngle,
        AppColors.ink,
        span: _span(sliceSeconds),
      ),
    ],
  );
}

/// [lines] of joint angles up to 180° over the round, 30° apart, from 60°
/// or, when an angle went lower, from the 30° step below it (at least 0°),
/// so a deep bend is never cut flat.
class _AngleChart extends StatelessWidget {
  const _AngleChart({required this.lines, required this.sliceSeconds});

  final List<LineChartBarData> lines;
  final double sliceSeconds;

  /// The chart's floor for the smallest angle in [lines] (their spots are
  /// already only the samples within the round).
  static double floorOf(List<LineChartBarData> lines) {
    var lowest = 60.0;
    for (final line in lines) {
      for (final spot in line.spots) {
        if (spot.isNotNull()) lowest = math.min(lowest, spot.y);
      }
    }
    return math.max(0, (lowest / 30).floor() * 30).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: FeedbackElbowPlot.height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: _span(sliceSeconds),
          minY: floorOf(lines),
          maxY: 180,
          clipData: const FlClipData.vertical(),
          lineBarsData: lines,
          titlesData: _titles(
            context,
            (v) => '${v.round()}°',
            30,
            sliceSeconds,
          ),
          gridData: _grid(30),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}

/// Counted reps in each slice of the round (BFeedback): lime bars with an
/// ink edge; an empty slice has no bar.
class FeedbackPacePlot extends StatelessWidget {
  const FeedbackPacePlot({
    super.key,
    required this.buckets,
    required this.sliceSeconds,
  });

  /// Counted reps per slice, from the view model.
  final List<int> buckets;
  final double sliceSeconds;

  static const double height = 160;
  static const double _barWidth = 16;
  static const double _barEdge = 1.5;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.feedbackAxis;
    final peak = buckets.fold(0, math.max);
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: math.max(2, peak).toDouble(),
          barGroups: [
            for (var i = 0; i < buckets.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: buckets[i].toDouble(),
                    color: AppColors.accent,
                    width: _barWidth,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.mark),
                    ),
                    borderSide: buckets[i] == 0
                        ? BorderSide.none
                        : const BorderSide(
                            color: AppColors.ink,
                            width: _barEdge,
                          ),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) => _label(
                  '${feedbackSeconds(value * sliceSeconds)}s',
                  style,
                  meta,
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) =>
                    _label('${value.round()}', style, meta),
              ),
            ),
          ),
          gridData: _grid(1),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
        ),
      ),
    );
  }
}

/// The amber square with an ink edge hanging from the top of a rejected
/// rep's mark on the depth chart.
class FeedbackRejectMark extends FlDotPainter {
  const FeedbackRejectMark();

  static const double size = AppHighlight.swatchSize;
  static const double _edge = 1.5;

  /// The square's box for a mark at [top]: centered on the mark, hanging
  /// down from the chart's top.
  static Rect box(Offset top) =>
      Rect.fromLTWH(top.dx - size / 2, top.dy, size, size);

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final square = RRect.fromRectAndRadius(
      box(offsetInCanvas),
      const Radius.circular(AppRadius.mark),
    );
    canvas
      ..drawRRect(square, Paint()..color = AppColors.warning)
      ..drawRRect(
        square.deflate(_edge / 2),
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _edge,
      );
  }

  @override
  Size getSize(FlSpot spot) => const Size.square(size);

  @override
  Color get mainColor => AppColors.warning;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  List<Object?> get props => const [];
}

/// The two lines of the elbow chart, named: a solid ink line for the left
/// arm, a dashed gray one for the right.
class FeedbackLegend extends StatelessWidget {
  const FeedbackLegend({super.key});

  /// The right arm's dashes, on the chart and here.
  static const dashes = [5, 4];

  static const Size _sample = Size(16, 4);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget entry(String label, Color color, {List<int>? dashes}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: _sample,
          painter: FeedbackLegendLine(color: color, dashes: dashes),
        ),
        const SizedBox(width: AppHighlight.swatchGap),
        Text(label, style: style),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.s12,
      children: [
        entry('왼팔', AppColors.ink),
        entry('오른팔', AppColors.line, dashes: dashes),
      ],
    );
  }
}

/// A short sample of a chart line: solid, or dashed by [dashes] (on, off).
class FeedbackLegendLine extends CustomPainter {
  const FeedbackLegendLine({required this.color, this.dashes});

  final Color color;
  final List<int>? dashes;

  static const double width = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    final y = size.height / 2;
    final dashes = this.dashes;
    if (dashes == null) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (var x = 0.0; x < size.width; x += dashes[0] + dashes[1]) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashes[0], size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FeedbackLegendLine oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashes != dashes;
}

/// A line through [value] of [samples] over the round's [span] seconds,
/// broken where the value is missing. Only the samples within the round are
/// drawn ([_inRound], the same rule as the scale and `hasData`).
LineChartBarData _line(
  List<FormSample> samples,
  double? Function(FormSample) value,
  Color color, {
  required double span,
  List<int>? dashes,
}) => LineChartBarData(
  spots: [
    for (final s in _inRound(samples, span))
      if (value(s) case final v?)
        FlSpot(_seconds(s.at), v)
      else
        FlSpot.nullSpot,
  ],
  color: color,
  barWidth: 2,
  isCurved: true,
  preventCurveOverShooting: true,
  dashArray: dashes,
  dotData: const FlDotData(show: false),
);

/// An axis number. Not scaled with the system text size: it is part of the
/// drawing, and the sentence under the chart says what it shows.
Widget _label(String text, TextStyle style, TitleMeta meta) => SideTitleWidget(
  meta: meta,
  child: Text(text, style: style, textScaler: TextScaler.noScaling),
);

/// The empty room right of the line charts: half a reject square, so a
/// rep at the round's end shows its whole square.
const double feedbackChartRightInset = FeedbackRejectMark.size / 2;

Widget _noTitle(double value, TitleMeta meta) => const SizedBox.shrink();

/// Seconds along the bottom, one label per slice; values on the left;
/// [feedbackChartRightInset] of room on the right.
FlTitlesData _titles(
  BuildContext context,
  String Function(double) leftLabel,
  double leftStep,
  double sliceSeconds,
) {
  final style = Theme.of(context).textTheme.feedbackAxis;
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: feedbackChartRightInset,
        getTitlesWidget: _noTitle,
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: sliceSeconds,
        reservedSize: 22,
        getTitlesWidget: (value, meta) =>
            _label('${feedbackSeconds(value)}s', style, meta),
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: leftStep,
        reservedSize: 34,
        getTitlesWidget: (value, meta) => _label(leftLabel(value), style, meta),
      ),
    ),
  );
}

FlGridData _grid(double step) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: step,
  getDrawingHorizontalLine: (_) =>
      const FlLine(color: AppColors.border, strokeWidth: 1),
);
