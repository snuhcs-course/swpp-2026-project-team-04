import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/feedback_stats_chart.dart';
import 'package:gymrats_app/widgets/feedback_stats_slots.dart';

StatsSlot _slot(
  StatsBarLook look, {
  int reps = 0,
  double height = 3,
  String label = '',
  bool shown = false,
  bool now = false,
}) => StatsSlot(
  date: DateTime(2026, 11, 9),
  reps: reps,
  label: label,
  barHeight: height,
  look: look,
  future: look == StatsBarLook.future,
  now: now,
  valueShown: shown,
);

/// Every look once: a value, the zero line, today, a future day.
final _chart = StatsChart(
  kind: StatsChartKind.day,
  gap: 8,
  radius: 6,
  slots: [
    _slot(StatsBarLook.value, reps: 27, height: 48, label: '월', shown: true),
    _slot(StatsBarLook.zero, label: '화'),
    _slot(
      StatsBarLook.now,
      reps: 28,
      height: 77,
      label: '오늘',
      shown: true,
      now: true,
    ),
    _slot(StatsBarLook.future, height: 4, label: '일'),
  ],
);

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget chart, {
    double width = 288,
  }) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: chart),
          ),
        ),
      ),
    );
  }

  final paint = find.byKey(const ValueKey('feedback-stats-chart'));

  test('slots share the width equally, gaps between them', () {
    final columns = FeedbackStatsChartPainter.columns(_chart, 288);
    expect(columns, hasLength(4));
    const slot = (288 - 3 * 8) / 4;
    expect(columns.first, (0.0, slot));
    expect(columns.last.$1, moreOrLessEquals(3 * (slot + 8)));
    expect(columns.last.$1 + columns.last.$2, moreOrLessEquals(288));
    expect(
      FeedbackStatsChartPainter.columns(
        const StatsChart(
          kind: StatsChartKind.day,
          slots: [],
          gap: 8,
          radius: 6,
        ),
        288,
      ),
      isEmpty,
    );
  });

  testWidgets('bars by look: gray, the light line, ink for today, a dashed '
      'outline for a day to come', (tester) async {
    await show(tester, FeedbackStatsChart(chart: _chart));
    final columns = FeedbackStatsChartPainter.columns(_chart, 288);
    RRect bar(int i, double height, double radius) => RRect.fromRectAndRadius(
      Rect.fromLTWH(columns[i].$1, 92 - height, columns[i].$2, height),
      Radius.circular(radius),
    );
    expect(
      paint,
      paints
        ..rrect(rrect: bar(0, 48, 6), color: AppColors.chartBar)
        ..rrect(rrect: bar(1, 3, 2), color: AppColors.border)
        ..rrect(rrect: bar(2, 77, 6), color: AppColors.ink)
        ..path(color: AppColors.inactive, style: PaintingStyle.stroke),
    );
    expect(paint, paintsExactlyCountTimes(#drawRRect, 3));
    // The dashes: many short pieces of one outline, all light gray.
    final dashes = paints;
    for (var i = 0; i < 10; i++) {
      dashes.path(color: AppColors.inactive, style: PaintingStyle.stroke);
    }
    expect(paint, dashes);
    // The two values and the four letters.
    expect(paint, paintsExactlyCountTimes(#drawParagraph, 6));
  });

  testWidgets('a placeholder graph: light gray bars, no values', (
    tester,
  ) async {
    final skeleton = StatsChart.skeleton(
      StatsPeriod.week,
      DateTime(2026, 11, 14),
    );
    await show(tester, FeedbackStatsChart(chart: skeleton));
    expect(paint, paints..rrect(color: AppColors.facetLight));
    expect(paint, paintsExactlyCountTimes(#drawRRect, 7));
    // The seven letters only.
    expect(paint, paintsExactlyCountTimes(#drawParagraph, 7));
  });

  testWidgets('the plot, its gap and one line of letters; the letters grow '
      'with the text size', (tester) async {
    await show(tester, FeedbackStatsChart(chart: _chart));
    expect(tester.getSize(paint).height, 92 + 6 + 14);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await show(tester, FeedbackStatsChart(chart: _chart));
    expect(tester.getSize(paint).height, 92 + 6 + 28);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read as one sentence; a placeholder is not read', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await show(
      tester,
      FeedbackStatsChart(chart: _chart, semanticsLabel: '날짜별 인정 횟수. 월 27회'),
    );
    expect(find.bySemanticsLabel('날짜별 인정 횟수. 월 27회'), findsOneWidget);
    await show(tester, FeedbackStatsChart(chart: _chart));
    expect(find.bySemanticsLabel(RegExp('인정 횟수')), findsNothing);
    semantics.dispose();
  });

  testWidgets('a notice lies over the top of the plot, at least 80 high', (
    tester,
  ) async {
    await show(
      tester,
      FeedbackStatsChart(
        chart: _chart,
        notice: const ColoredBox(
          key: ValueKey('notice'),
          color: AppColors.cardHigh,
        ),
      ),
    );
    final notice = find.byKey(const ValueKey('notice'));
    expect(tester.getTopLeft(notice), tester.getTopLeft(paint));
    expect(tester.getSize(notice), const Size(288, 80));
  });

  testWidgets('a notice taller than the graph makes room, not cut', (
    tester,
  ) async {
    await show(
      tester,
      FeedbackStatsChart(
        chart: _chart,
        notice: const SizedBox(key: ValueKey('notice'), height: 170),
      ),
    );
    expect(tester.getSize(find.byType(FeedbackStatsChart)).height, 170);
    expect(tester.getSize(find.byKey(const ValueKey('notice'))).height, 170);
  });

  test('repaints for a new chart, style or text size', () {
    const style = TextStyle();
    FeedbackStatsChartPainter painter(StatsChart chart, [TextScaler? s]) =>
        FeedbackStatsChartPainter(
          chart: chart,
          valueStyle: style,
          labelStyle: style,
          nowLabelStyle: style,
          textScaler: s ?? TextScaler.noScaling,
        );
    final one = painter(_chart);
    expect(one.shouldRepaint(painter(_chart)), isFalse);
    expect(
      one.shouldRepaint(
        painter(StatsChart.skeleton(StatsPeriod.all, DateTime(2026))),
      ),
      isTrue,
    );
    expect(
      one.shouldRepaint(painter(_chart, const TextScaler.linear(2))),
      isTrue,
    );
    expect(
      one.shouldRepaint(
        FeedbackStatsChartPainter(
          chart: _chart,
          valueStyle: style,
          labelStyle: const TextStyle(fontWeight: FontWeight.w300),
          nowLabelStyle: style,
        ),
      ),
      isTrue,
    );
  });
}
