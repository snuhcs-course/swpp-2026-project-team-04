import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/archive_cards.dart';

/// The mockup's week (BArchive), on the 7 days up to Saturday 2026-11-14.
const _designReps = [7, 8, 8, 21, 24, 26, 29];

ScoreGrowth _growth(ExerciseType exercise, List<int> scores, [DateTime? at]) =>
    ScoreGrowth(exercise: exercise, scores: scores, firstPlayedAt: at);

ArchiveStats _stats({
  int streakDays = 8,
  List<int> reps = _designReps,
  Map<ExerciseType, ScoreGrowth>? growth,
}) => ArchiveStats(
  weekReps: 123,
  weekMatches: 11,
  streakDays: streakDays,
  weekDaily: [
    for (final (i, count) in reps.indexed)
      DayReps(date: DateTime(2026, 11, 8 + i), reps: count),
  ],
  growth:
      growth ??
      {
        ExerciseType.pushUp: _growth(ExerciseType.pushUp, const [
          80,
          95,
          110,
          105,
          130,
          150,
          185,
          240,
        ], DateTime(2026, 10, 28, 20)),
        ExerciseType.squat: _growth(ExerciseType.squat, const [
          300,
          360,
          420,
          490,
        ], DateTime(2026, 11, 1, 19)),
      },
);

/// Relative-luminance contrast (WCAG 2.x).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget card, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: card,
          ),
        ),
      ),
    );
  }

  test('the bar gray reads on the cards (3:1 for graphics)', () {
    expect(_contrast(AppColors.chartBar, AppColors.card), greaterThan(3));
    // Why the mockup's gray was replaced (user, 2026-11-14).
    expect(_contrast(AppColors.inactive, AppColors.card), lessThan(3));
  });

  group('ArchiveWeekCard', () {
    testWidgets('the 7 days: reps, battles and the streak chip', (
      tester,
    ) async {
      await show(tester, ArchiveWeekCard(stats: _stats()));
      // Named by its first day, unlike the statistics' week from Monday.
      expect(find.text('최근 7일 · 11/8 ~ 오늘'), findsOneWidget);
      expect(find.text('123회  · 11판'), findsOneWidget);
      expect(find.text('8일 연속'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });

    testWidgets('no streak, no chip', (tester) async {
      await show(tester, ArchiveWeekCard(stats: _stats(streakDays: 0)));
      expect(find.textContaining('연속'), findsNothing);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
    });

    testWidgets('a bar per day as in the mockup, today last and in ink', (
      tester,
    ) async {
      await show(tester, ArchiveWeekCard(stats: _stats()));
      const heights = [14.0, 16.0, 16.0, 42.0, 48.0, 52.0, 58.0];
      for (final (i, height) in heights.indexed) {
        final bar = find.byKey(ValueKey('archive-bar-$i'));
        expect(tester.getSize(bar).height, height);
        final color =
            (tester.widget<Container>(bar).decoration! as BoxDecoration).color;
        expect(color, i == 6 ? AppColors.ink : AppColors.chartBar);
      }
      // Oldest first: the bars run left to right and stand on one line.
      final bottoms = [
        for (var i = 0; i < 7; i++)
          tester.getBottomLeft(find.byKey(ValueKey('archive-bar-$i'))),
      ];
      for (var i = 1; i < 7; i++) {
        expect(bottoms[i].dx, greaterThan(bottoms[i - 1].dx));
        expect(bottoms[i].dy, bottoms[0].dy);
      }
    });

    testWidgets('weekday letters under the bars; the last says 오늘', (
      tester,
    ) async {
      await show(tester, ArchiveWeekCard(stats: _stats()));
      // 2026-11-08 is a Sunday.
      for (final label in ['일', '월', '화', '수', '목', '금', '오늘']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('토'), findsNothing);
      final today = tester.widget<Text>(find.text('오늘'));
      expect(today.style?.fontWeight, FontWeight.w700);
      expect(today.style?.color, AppColors.ink);
      expect(
        tester.widget<Text>(find.text('일')).style?.color,
        AppColors.textMuted,
      );
      expect(
        tester.getCenter(find.text('오늘')).dx,
        moreOrLessEquals(
          tester.getCenter(find.byKey(const ValueKey('archive-bar-6'))).dx,
          epsilon: 0.5,
        ),
      );
    });

    testWidgets('a screen reader hears each day and its reps', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, ArchiveWeekCard(stats: _stats()));
      expect(
        find.bySemanticsLabel('일 7회, 월 8회, 화 8회, 수 21회, 목 24회, 금 26회, 오늘 29회'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('a day without battles is a thin light line, today too', (
      tester,
    ) async {
      await show(
        tester,
        ArchiveWeekCard(stats: _stats(reps: const [12, 27, 0, 10, 43, 16, 0])),
      );
      BoxDecoration look(int i) =>
          tester
                  .widget<Container>(find.byKey(ValueKey('archive-bar-$i')))
                  .decoration!
              as BoxDecoration;
      for (final i in [2, 6]) {
        expect(
          tester.getSize(find.byKey(ValueKey('archive-bar-$i'))).height,
          ArchiveWeekCard.zeroBarHeight,
        );
        expect(look(i).color, AppColors.border);
        expect(
          look(i).borderRadius,
          const BorderRadius.all(Radius.circular(2)),
        );
      }
      expect(look(0).color, AppColors.chartBar);
      expect(look(0).borderRadius, const BorderRadius.all(Radius.circular(6)));
      expect(
        tester.getSize(find.byKey(const ValueKey('archive-bar-4'))).height,
        ArchiveWeekCard.barsHeight,
      );
      // A few reps still get the least bar.
      await show(
        tester,
        ArchiveWeekCard(stats: _stats(reps: const [1, 0, 0, 0, 0, 0, 100])),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('archive-bar-0'))).height,
        ArchiveWeekCard.barMinHeight,
      );
    });

    testWidgets('a quiet week: every bar the thin line', (tester) async {
      await show(
        tester,
        ArchiveWeekCard(stats: _stats(streakDays: 0, reps: List.filled(7, 0))),
      );
      for (var i = 0; i < 7; i++) {
        expect(
          tester.getSize(find.byKey(ValueKey('archive-bar-$i'))).height,
          ArchiveWeekCard.zeroBarHeight,
        );
      }
    });

    testWidgets('no days given: no bars, no dates in the name', (tester) async {
      await show(tester, const ArchiveWeekCard(stats: ArchiveStats()));
      expect(find.text('0회  · 0판'), findsOneWidget);
      expect(find.text('최근 7일'), findsOneWidget);
      expect(find.byKey(const ValueKey('archive-bar-0')), findsNothing);
    });

    test('sinceLabel: month/day of the first of the 7 days', () {
      expect(
        ArchiveWeekCard.sinceLabel(
          DayReps(date: DateTime(2026, 10, 31), reps: 3),
        ),
        '10/31',
      );
    });

    test('dayLabel: the weekday, or 오늘 for the last', () {
      final monday = DayReps(date: DateTime(2026, 11, 9), reps: 0);
      expect(ArchiveWeekCard.dayLabel(monday, isToday: false), '월');
      expect(ArchiveWeekCard.dayLabel(monday, isToday: true), '오늘');
    });
  });

  group('ArchiveGrowthCard', () {
    ArchiveGrowthCard card([Map<ExerciseType, ScoreGrowth>? growth]) =>
        ArchiveGrowthCard(growth: growth ?? _stats().growth);

    testWidgets('push-ups first: the rise, the line, the graph and the dates', (
      tester,
    ) async {
      await show(tester, card());
      expect(find.text('점수 성장'), findsOneWidget);
      expect(find.text('160점'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.text('첫 기록 80점 → 최고 240점'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('archive-growth-chart')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('archive-growth-chart'))),
        const Size(412 - 40 - 32, ArchiveGrowthCard.chartHeight),
      );
      expect(find.text('10/28'), findsOneWidget);
      expect(find.text('오늘'), findsOneWidget);
    });

    testWidgets('the 스쿼트 tab shows the squat scores', (tester) async {
      await show(tester, card());
      await tester.tap(find.text('스쿼트'));
      await tester.pump();
      expect(find.text('190점'), findsOneWidget);
      expect(find.text('첫 기록 300점 → 최고 490점'), findsOneWidget);
      expect(find.text('11/1'), findsOneWidget);
      expect(find.text('160점'), findsNothing);

      await tester.tap(find.text('푸쉬업'));
      await tester.pump();
      expect(find.text('160점'), findsOneWidget);
    });

    testWidgets('the picked tab is white on ink and says it is selected', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await show(tester, card());
      Color? colorOf(String label) => tester
          .widget<RichText>(
            find.descendant(
              of: find.widgetWithText(TextButton, label),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style
          ?.color;
      expect(colorOf('푸쉬업'), AppColors.onInk);
      expect(colorOf('스쿼트'), AppColors.textSecondary);
      expect(
        tester.getSemantics(find.text('푸쉬업')),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.text('스쿼트')),
        isSemantics(isSelected: false, isButton: true),
      );

      await tester.tap(find.text('스쿼트'));
      // The button's colors fade over the theme's 200 ms.
      await tester.pumpAndSettle();
      expect(colorOf('스쿼트'), AppColors.onInk);
      expect(colorOf('푸쉬업'), AppColors.textSecondary);
      semantics.dispose();
    });

    testWidgets('each tab is drawn 40 high and takes taps over 48', (
      tester,
    ) async {
      await show(tester, card());
      for (final label in ['푸쉬업', '스쿼트']) {
        final tab = find.widgetWithText(TextButton, label);
        expect(tester.getSize(tab).height, greaterThanOrEqualTo(48));
        expect(
          tester
              .getSize(
                find.descendant(of: tab, matching: find.byType(Material)),
              )
              .height,
          40,
        );
      }
    });

    testWidgets('a screen reader hears what the graph shows', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, card());
      expect(
        find.bySemanticsLabel('푸쉬업 점수 그래프, 첫 기록 80점에서 최고 240점으로 올랐어요'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('160점 올랐어요'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('an exercise without a scored battle: a short empty line', (
      tester,
    ) async {
      await show(
        tester,
        card({
          ExerciseType.pushUp: _growth(ExerciseType.pushUp, const [
            80,
            120,
          ], DateTime(2026, 11, 2)),
          ExerciseType.squat: _growth(ExerciseType.squat, const []),
        }),
      );
      await tester.tap(find.text('스쿼트'));
      await tester.pump();
      expect(find.text('아직 점수 기록이 없어요'), findsOneWidget);
      expect(find.text('스쿼트 대결을 마치면 점수가 쌓여요.'), findsOneWidget);
      expect(find.byKey(const ValueKey('archive-growth-chart')), findsNothing);
      expect(find.textContaining('첫 기록'), findsNothing);
      // The tabs stay, so the other exercise is one tap away.
      expect(find.text('푸쉬업'), findsOneWidget);
    });

    testWidgets('an exercise missing from the map counts as no scores', (
      tester,
    ) async {
      await show(tester, card(const {}));
      expect(find.text('아직 점수 기록이 없어요'), findsOneWidget);
      expect(find.text('푸쉬업 대결을 마치면 점수가 쌓여요.'), findsOneWidget);
    });

    testWidgets('one score: the first score only, no rise chip', (
      tester,
    ) async {
      await show(
        tester,
        card({
          ExerciseType.pushUp: _growth(ExerciseType.pushUp, const [
            80,
          ], DateTime(2026, 11, 14)),
        }),
      );
      expect(find.text('첫 기록 80점'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(
        find.byKey(const ValueKey('archive-growth-chart')),
        findsOneWidget,
      );
      expect(find.text('11/14'), findsOneWidget);
    });

    testWidgets('no rise yet: the line, no chip', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        card({
          ExerciseType.pushUp: _growth(ExerciseType.pushUp, const [
            100,
            90,
          ], DateTime(2026, 11, 12)),
        }),
      );
      expect(find.text('첫 기록 100점 → 최고 100점'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(
        find.bySemanticsLabel('푸쉬업 점수 그래프, 첫 기록 100점, 최고 100점'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('no first date: the date slot stays empty', (tester) async {
      await show(
        tester,
        card({
          ExerciseType.pushUp: _growth(ExerciseType.pushUp, const [10, 20]),
        }),
      );
      expect(find.text('오늘'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);
    });

    test('dateLabel and caption', () {
      expect(ArchiveGrowthCard.dateLabel(DateTime(2026, 10, 28, 23)), '10/28');
      expect(
        ArchiveGrowthCard.caption(
          _growth(ExerciseType.squat, const [300, 490, 420]),
        ),
        '첫 기록 300점 → 최고 490점',
      );
    });
  });

  group('ArchiveStatsRetry', () {
    testWidgets('says the summary failed and 다시 시도 calls back', (tester) async {
      var retries = 0;
      await show(tester, ArchiveStatsRetry(onRetry: () => retries++));
      expect(find.text('최근 7일과 점수 성장을 불러오지 못했어요'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      expect(retries, 1);
    });
  });

  group('larger text', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('both cards fit a 360 wide phone at ${scale}x text', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await show(
          tester,
          Column(
            children: [
              ArchiveWeekCard(stats: _stats()),
              ArchiveGrowthCard(growth: _stats().growth),
              ArchiveStatsRetry(onRetry: () {}),
            ],
          ),
          size: const Size(360, 780),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('8일 연속'), findsOneWidget);
        expect(find.text('스쿼트'), findsOneWidget);
      });
    }
  });
}
