import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/weekly_rankings_banner.dart';

Future<void> pumpBanner(
  WidgetTester tester,
  WeeklyRankingsBanner banner, {
  double width = 320,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.dark,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: banner),
        ),
      ),
    ),
  ),
);

const week = WeeklyRankingsBanner(
  weekName: '11월 4주차',
  dates: '11.23 (월) – 11.29 (일)',
  timeLeft: '1일 9시간 남음',
  progress: 0.8,
);

/// The lime part of the bar along the bottom.
Finder fill() => find.byWidgetPredicate(
  (widget) =>
      widget is ColoredBox &&
      widget.color == AppColors.accent &&
      widget.child == null,
);

void main() {
  testWidgets('shows the week, its dates and the time left on ink', (
    tester,
  ) async {
    await pumpBanner(tester, week);
    expect(find.text('11월 4주차'), findsOneWidget);
    expect(find.text('11.23 (월) – 11.29 (일)'), findsOneWidget);
    expect(find.text('1일 9시간 남음'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    final name = tester.widget<Text>(find.text('11월 4주차'));
    expect(name.style?.color, AppColors.accent);
    expect(name.style?.fontFamily, AppFonts.display);
    expect(tester.getSize(find.byType(WeeklyRankingsBanner)).height, 62);
    // The flag is orange and 30 high.
    expect(
      tester.getSize(find.byType(WeeklyRankingsFlag)).height,
      WeeklyRankingsFlag.height,
    );
  });

  testWidgets('the bar fills by how much of the week has gone', (tester) async {
    await pumpBanner(tester, week);
    expect(tester.getSize(fill()).width, closeTo(320 * 0.8, 0.01));
    expect(tester.getSize(fill()).height, WeeklyRankingsBanner.barHeight);
    expect(
      tester.getBottomLeft(fill()),
      tester.getBottomLeft(find.byType(WeeklyRankingsBanner)),
    );
    for (final (progress, width) in [(0.0, 0.0), (1.0, 320.0), (1.4, 320.0)]) {
      await pumpBanner(
        tester,
        WeeklyRankingsBanner(weekName: 'w', progress: progress),
      );
      expect(tester.getSize(fill()).width, width);
    }
  });

  testWidgets('without a week it keeps its place, words and bar empty', (
    tester,
  ) async {
    await pumpBanner(tester, const WeeklyRankingsBanner());
    expect(tester.getSize(find.byType(WeeklyRankingsBanner)).height, 62);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(WeeklyRankingsFlag), findsNothing);
    expect(tester.getSize(fill()).width, 0);
  });

  testWidgets('reads as one sentence', (tester) async {
    await pumpBanner(tester, week);
    expect(
      tester.getSemantics(find.byType(WeeklyRankingsBanner)).label,
      '11월 4주차, 11.23 (월) – 11.29 (일), 1일 9시간 남음',
    );
  });

  testWidgets('fits a narrow phone with a large text size', (tester) async {
    for (final (width, scale) in [(280.0, 1.0), (320.0, 1.3)]) {
      await pumpBanner(
        tester,
        const WeeklyRankingsBanner(
          weekName: '11월 4주차',
          dates: '11.23 (월) – 11.29 (일)',
          timeLeft: '6일 23시간 남음',
          progress: 0.1,
        ),
        width: width,
        textScale: scale,
      );
      expect(tester.takeException(), isNull, reason: '$width x$scale');
      // The time left keeps its words whole.
      expect(find.text('6일 23시간 남음'), findsOneWidget);
    }
  });
}
