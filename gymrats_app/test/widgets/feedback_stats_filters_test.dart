import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/feedback_stats_filters.dart';

import 'battle_test_support.dart';

void main() {
  // The app's fonts, so the labels measure as they do on a phone.
  setUpAll(loadBattleFonts);

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    double width = 320,
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
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  bool picked(WidgetTester tester, String label) =>
      isSemantics(isSelected: true)
          .matches(tester.getSemantics(find.text(label)), {});

  group('FeedbackStatsPeriodTabs', () {
    testWidgets('전체, 이번 달, 이번 주 in equal tabs 44 high; the picked one '
        'white on ink', (tester) async {
      await show(
        tester,
        FeedbackStatsPeriodTabs(selected: StatsPeriod.week, onSelect: (_) {}),
      );
      final tabs = [
        for (final label in ['전체', '이번 달', '이번 주'])
          find.widgetWithText(TextButton, label),
      ];
      final sizes = [for (final tab in tabs) tester.getSize(tab)];
      expect(sizes.map((s) => s.height), [44, 44, 44]);
      expect(sizes.map((s) => s.width).toSet(), hasLength(1));
      expect(
        tester.getTopLeft(tabs[0]).dx,
        lessThan(tester.getTopLeft(tabs[1]).dx),
      );
      ButtonStyle style(Finder tab) => tester.widget<TextButton>(tab).style!;
      expect(style(tabs[2]).backgroundColor!.resolve({}), AppColors.ink);
      expect(style(tabs[2]).foregroundColor!.resolve({}), AppColors.onInk);
      expect(
        style(tabs[0]).foregroundColor!.resolve({}),
        AppColors.textSecondary,
      );
      // The track: white with a border, 50 high around the 44 tabs.
      expect(tester.getSize(find.byType(FeedbackStatsPeriodTabs)).height, 50);
    });

    testWidgets('a tap picks that period', (tester) async {
      final picks = <StatsPeriod>[];
      await show(
        tester,
        FeedbackStatsPeriodTabs(
          selected: StatsPeriod.week,
          onSelect: picks.add,
        ),
      );
      await tester.tap(find.text('전체'));
      await tester.tap(find.text('이번 달'));
      expect(picks, [StatsPeriod.all, StatsPeriod.month]);
    });

    testWidgets('a screen reader hears the group 기간 and which tab is '
        'picked', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        FeedbackStatsPeriodTabs(selected: StatsPeriod.month, onSelect: (_) {}),
      );
      expect(find.bySemanticsLabel('기간'), findsOneWidget);
      expect(picked(tester, '이번 달'), isTrue);
      expect(picked(tester, '이번 주'), isFalse);
      expect(
        tester.getSemantics(find.text('전체')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('at 2x text the names stay on one line and fit', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await show(
        tester,
        FeedbackStatsPeriodTabs(selected: StatsPeriod.week, onSelect: (_) {}),
        width: 280,
      );
      expect(tester.takeException(), isNull);
      final tab = tester.getRect(find.widgetWithText(TextButton, '이번 달'));
      final name = tester.getRect(find.text('이번 달'));
      expect(name.width, lessThanOrEqualTo(tab.width));
      expect(
        tester.getSize(find.widgetWithText(TextButton, '이번 달')).height,
        44,
      );
    });
  });

  group('FeedbackStatsExerciseChips', () {
    testWidgets('푸쉬업, 스쿼트, 둘 다: 32 high chips in 44 high taps; the '
        'picked one lime with an ink edge', (tester) async {
      await show(
        tester,
        FeedbackStatsExerciseChips(selected: null, onSelect: (_) {}),
      );
      double x(String label) => tester.getCenter(find.text(label)).dx;
      expect(x('푸쉬업'), lessThan(x('스쿼트')));
      expect(x('스쿼트'), lessThan(x('둘 다')));
      ShapeDecoration chip(String label) =>
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text(label),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as ShapeDecoration;
      expect(chip('둘 다').color, AppColors.accent);
      expect((chip('둘 다').shape as StadiumBorder).side.color, AppColors.ink);
      expect(chip('푸쉬업').color, AppColors.card);
      expect((chip('푸쉬업').shape as StadiumBorder).side.color, AppColors.border);
      final visible = tester.getSize(
        find
            .ancestor(of: find.text('스쿼트'), matching: find.byType(Container))
            .first,
      );
      expect(visible.height, 32);
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('스쿼트'),
                matching: find.byType(InkWell),
              ),
            )
            .height,
        44,
      );
    });

    testWidgets('a tap picks the exercise; 둘 다 is null', (tester) async {
      final picks = <ExerciseType?>[];
      await show(
        tester,
        FeedbackStatsExerciseChips(
          selected: ExerciseType.pushUp,
          onSelect: picks.add,
        ),
      );
      await tester.tap(find.text('스쿼트'));
      await tester.tap(find.text('둘 다'));
      await tester.tap(find.text('푸쉬업'));
      expect(picks, [ExerciseType.squat, null, ExerciseType.pushUp]);
    });

    testWidgets('a screen reader hears the group 종목, buttons, and which is '
        'picked', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        FeedbackStatsExerciseChips(
          selected: ExerciseType.squat,
          onSelect: (_) {},
        ),
      );
      expect(find.bySemanticsLabel('종목'), findsOneWidget);
      expect(picked(tester, '스쿼트'), isTrue);
      expect(picked(tester, '둘 다'), isFalse);
      expect(
        tester.getSemantics(find.text('푸쉬업')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    test('names: the app\'s own, and 둘 다 for both', () {
      expect(FeedbackStatsExerciseChips.nameOf(ExerciseType.pushUp), '푸쉬업');
      expect(FeedbackStatsExerciseChips.nameOf(ExerciseType.squat), '스쿼트');
      expect(FeedbackStatsExerciseChips.nameOf(null), '둘 다');
      expect(FeedbackStatsPeriodTabs.nameOf(StatsPeriod.all), '전체');
    });
  });
}
