import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';

import '../support/fakes.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

BattleResult _result({
  int mine = 26,
  int invalid = 3,
  int theirs = 24,
  Matchup matchup = _matchup,
  Duration roundLength = const Duration(seconds: 60),
}) => BattleResult(
  matchup: matchup,
  myReps: mine,
  myInvalidReps: invalid,
  opponentReps: theirs,
  endedAt: DateTime(2026, 10, 4, 14, 32),
  roundLength: roundLength,
);

void main() {
  late PushLog pushes;

  /// Opens ResultScreen above a home page, where the battle leaves it. The
  /// matching route is a stub that shows its argument.
  Future<void> open(
    WidgetTester tester,
    BattleResult result, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pushes = PushLog();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        navigatorObservers: [pushes],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ResultScreen(result: result),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
        onGenerateRoute: (settings) => switch (settings.name) {
          GymRatsApp.matchingRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                Scaffold(body: Text('matching ${settings.arguments}')),
          ),
          _ => null,
        },
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.color;

  testWidgets('a win: WIN, the margin, both players, and my stats', (
    tester,
  ) async {
    await open(tester, _result());
    expect(find.text('RESULT'), findsOneWidget);
    expect(find.text('푸쉬업 · 60초 · 오늘 14:32'), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);
    expect(colorOf(tester, 'WIN'), AppColors.accent);
    expect(find.text('2개 차이로 이겼어요!'), findsOneWidget);

    expect(find.text('우현'), findsOneWidget);
    expect(find.text('우'), findsOneWidget);
    expect(find.text('RepBot'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
    expect(colorOf(tester, '26'), AppColors.accent);
    expect(colorOf(tester, '24'), AppColors.opponent);

    expect(find.text('인정'), findsOneWidget);
    expect(find.text('26회'), findsOneWidget);
    expect(find.text('무효'), findsOneWidget);
    expect(find.text('3회'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('3회')).textSpan!.style!.color,
      AppColors.warning,
    );
    // 26 of 29 judged reps.
    expect(find.text('정확도'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);

    // Left out this iteration.
    expect(find.textContaining('TP'), findsNothing);
    expect(find.textContaining('티어'), findsNothing);
    expect(find.textContaining('자세 피드백'), findsNothing);
    expect(find.text('홈으로'), findsOneWidget);
    expect(find.text('다시 매칭'), findsOneWidget);
  });

  for (final (mine, theirs, word, line, color) in [
    (20, 23, 'LOSE', '3개 차이로 졌어요', AppColors.opponent),
    (22, 22, 'DRAW', '비겼어요!', AppColors.textPrimary),
  ]) {
    testWidgets('$mine:$theirs is a $word', (tester) async {
      await open(tester, _result(mine: mine, theirs: theirs));
      expect(find.text(word), findsOneWidget);
      expect(colorOf(tester, word), color);
      expect(find.text(line), findsOneWidget);
    });
  }

  testWidgets('without a judged rep, accuracy is a dash', (tester) async {
    await open(tester, _result(mine: 0, invalid: 0, theirs: 21));
    expect(find.text('0회'), findsNWidgets(2));
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('a person gets a person icon; the header follows the round', (
    tester,
  ) async {
    await open(
      tester,
      _result(
        matchup: const Matchup(
          exercise: ExerciseType.pushUp,
          playerName: '우현',
          opponent: Opponent(name: 'Mina', isBot: false),
        ),
        roundLength: const Duration(seconds: 20),
      ),
    );
    expect(find.text('Mina'), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsNothing);
    expect(find.text('푸쉬업 · 20초 · 오늘 14:32'), findsOneWidget);
  });

  testWidgets('홈으로 goes home', (tester) async {
    await open(tester, _result());
    await tester.tap(find.text('홈으로'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(ResultScreen), findsNothing);
  });

  testWidgets('back goes home too', (tester) async {
    await open(tester, _result());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('다시 매칭 replaces the result with a search for push-ups', (
    tester,
  ) async {
    await open(tester, _result());
    await tester.tap(find.text('다시 매칭'));
    await tester.pumpAndSettle();
    expect(find.text('matching ${ExerciseType.pushUp}'), findsOneWidget);
    expect(find.byType(ResultScreen), findsNothing);

    // Replaced, not pushed: back from the search goes home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('pressing 다시 매칭 twice searches once', (tester) async {
    await open(tester, _result());
    final press = tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('다시 매칭'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed!;
    press();
    press();
    await tester.pumpAndSettle();
    expect(
      pushes.names.where((name) => name == GymRatsApp.matchingRoute),
      hasLength(1),
    );
  });

  /// The 홈으로 button, tap area included.
  final homeButton = find.ancestor(
    of: find.text('홈으로'),
    matching: find.byType(OutlinedButton),
  );

  testWidgets('a tall phone shows the buttons at the bottom', (tester) async {
    await open(tester, _result());
    expect(tester.takeException(), isNull);
    expect(tester.getRect(homeButton).bottom, 915 - 28);
  });

  testWidgets('a short phone scrolls down to the buttons', (tester) async {
    await open(tester, _result(), size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(homeButton).bottom, 640 - 28);
  });
}
