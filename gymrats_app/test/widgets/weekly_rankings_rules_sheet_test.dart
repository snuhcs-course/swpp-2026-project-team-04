import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/accent_button.dart';
import 'package:gymrats_app/widgets/weekly_rankings_rules_sheet.dart';

Future<void> openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showWeeklyRankingsRules(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the rules: a title, five results with their points, four '
      'notes and 확인', (tester) async {
    await openSheet(tester);
    expect(find.byType(WeeklyRankingsRulesSheet), findsOneWidget);
    expect(find.text('점수 규칙'), findsOneWidget);
    expect(find.text('이번 주 온라인 대결 결과로 점수를 모아요.'), findsOneWidget);
    for (final (name, points) in [
      ('KO승', RankingPoints.koWin),
      ('승리', RankingPoints.win),
      ('무승부', RankingPoints.draw),
      ('패배', RankingPoints.loss),
      ('중간에 나감', RankingPoints.leftBattle),
    ]) {
      expect(find.text(name), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^$name, $points점')), findsOneWidget);
    }
    expect(find.text('체력 바를 끝까지 밀어 이긴 경기'), findsOneWidget);
    expect(find.text('상대가 나가거나 연결이 끊겨도 승리'), findsOneWidget);
    expect(find.text('끝까지 하면 져도 ${RankingPoints.loss}점'), findsOneWidget);
    expect(find.text('내가 나가거나 연결이 끊긴 경기'), findsOneWidget);
    for (final note in WeeklyRankingsRulesSheet.notes) {
      expect(find.text(note), findsOneWidget);
    }
    expect(find.widgetWithText(AccentButton, '확인'), findsOneWidget);
  });

  test('the points boxes: lime for KO, gray for leaving, white otherwise', () {
    expect(
      [for (final (_, _, _, fill) in WeeklyRankingsRulesSheet.rules) fill],
      [
        AppColors.accent,
        AppColors.card,
        AppColors.card,
        AppColors.card,
        AppColors.cardHigh,
      ],
    );
    // 무승부 has no description line.
    expect(WeeklyRankingsRulesSheet.rules[2].$3, '');
  });

  testWidgets('확인 closes the sheet', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyRankingsRulesSheet), findsNothing);
  });

  testWidgets('scrolls on a small phone with a large text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openSheet(tester);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('확인'),
      100,
      scrollable: find.descendant(
        of: find.byType(WeeklyRankingsRulesSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyRankingsRulesSheet), findsNothing);
  });
}
