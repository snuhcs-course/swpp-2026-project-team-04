import 'dart:ui' show SemanticsAction, SemanticsRole, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/weekly_rankings_tabs.dart';

void main() {
  late List<Object> chosen;

  Future<void> pumpTabs(
    WidgetTester tester, {
    RankingScope scope = RankingScope.global,
    ExerciseType exercise = ExerciseType.pushUp,
    double width = 320,
  }) {
    chosen = [];
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: WeeklyRankingsTabs(
                scope: scope,
                exercise: exercise,
                onScope: chosen.add,
                onExercise: chosen.add,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color fillOf(WidgetTester tester, String name) =>
      (tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.text(name),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration)
          .color!;

  testWidgets('the scope and exercise tabs on one line, the exercise 136 '
      'wide', (tester) async {
    await pumpTabs(tester);
    for (final name in ['전체', '친구', '푸시업', '스쿼트']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(
      tester.getCenter(find.text('전체')).dy,
      tester.getCenter(find.text('푸시업')).dy,
    );
    expect(tester.getSize(find.byType(WeeklyRankingsTabs)).height, 48);
    final pills = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is ShapeDecoration &&
          (widget.decoration! as ShapeDecoration).shape is StadiumBorder,
    );
    expect(pills, findsNWidgets(2));
    expect(tester.getSize(pills.first), const Size(320 - 8 - 136, 40));
    expect(tester.getSize(pills.last), const Size(136, 40));
  });

  testWidgets('the chosen scope is lime, the chosen exercise ink', (
    tester,
  ) async {
    await pumpTabs(tester, scope: RankingScope.friends);
    expect(fillOf(tester, '친구'), AppColors.accent);
    expect(fillOf(tester, '전체'), AppColors.card);
    expect(fillOf(tester, '푸시업'), AppColors.ink);
    expect(fillOf(tester, '스쿼트'), AppColors.card);
    final chosenName = tester.widget<Text>(find.text('푸시업')).style!;
    expect(
      (chosenName.color, chosenName.fontWeight),
      (AppColors.onInk, FontWeight.w700),
    );
    final other = tester.widget<Text>(find.text('전체')).style!;
    expect(
      (other.color, other.fontWeight),
      (AppColors.textSecondary, FontWeight.w500),
    );
  });

  testWidgets('tapping a tab chooses it; the chosen one does nothing', (
    tester,
  ) async {
    await pumpTabs(tester);
    await tester.tap(find.text('친구'));
    await tester.tap(find.text('스쿼트'));
    await tester.tap(find.text('전체'));
    await tester.tap(find.text('푸시업'));
    expect(chosen, [RankingScope.friends, ExerciseType.squat]);
  });

  testWidgets('a screen reader hears tabs with their place and state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpTabs(tester, exercise: ExerciseType.squat);
    for (final (name, chosen, position) in const [
      ('전체', true, '탭 2개 중 1번째'),
      ('친구', false, '탭 2개 중 2번째'),
      ('푸시업', false, '탭 2개 중 1번째'),
      ('스쿼트', true, '탭 2개 중 2번째'),
    ]) {
      final node = tester.getSemantics(find.bySemanticsLabel(name));
      final data = node.getSemanticsData();
      expect(data.role, SemanticsRole.tab, reason: name);
      expect(
        data.flagsCollection.isSelected,
        chosen ? Tristate.isTrue : Tristate.isFalse,
        reason: name,
      );
      expect(data.flagsCollection.isButton, isTrue, reason: name);
      expect(data.value, position, reason: name);
      expect(data.hasAction(SemanticsAction.tap), isTrue, reason: name);
      expect(node.rect.height, greaterThanOrEqualTo(48), reason: name);
      expect(node.parent!.getSemanticsData().role, SemanticsRole.tabBar);
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('fits a narrow phone with a large text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTabs(tester, width: 280);
    expect(tester.takeException(), isNull);
  });

  test('names the scopes and exercises as the design', () {
    expect(WeeklyRankingsTabs.scopeName(RankingScope.global), '전체');
    expect(WeeklyRankingsTabs.scopeName(RankingScope.friends), '친구');
    expect(WeeklyRankingsTabs.exerciseName(ExerciseType.pushUp), '푸시업');
    expect(WeeklyRankingsTabs.exerciseName(ExerciseType.squat), '스쿼트');
  });

  testWidgets("each pill's ink edge is drawn over its halves, clipped "
      "inside it", (tester) async {
    await pumpTabs(tester);
    final pills = find.byWidgetPredicate(
      (widget) =>
          widget is Container && widget.foregroundDecoration is ShapeDecoration,
    );
    expect(pills, findsNWidgets(2));
    for (final pill in pills.evaluate()) {
      final edge =
          (pill.widget as Container).foregroundDecoration! as ShapeDecoration;
      final shape = edge.shape as StadiumBorder;
      expect((shape.side.color, shape.side.width), (AppColors.ink, 2.0));
      expect(
        find.descendant(
          of: find.byWidget(pill.widget),
          matching: find.byType(ClipPath),
        ),
        findsOneWidget,
      );
    }
  });
}
