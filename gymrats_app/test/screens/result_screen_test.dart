import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/result_report.dart';

// The drawing of the report is tested in test/widgets/result_report_test.dart
// and result_cards_test.dart. This file checks only what the screen adds:
// the values it gathers from the battle, and where its buttons lead.

final _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: const Opponent(
    name: 'RepBot',
    isBot: true,
  ).at(BotDifficulty.beginner),
);

final _form = FormReport(
  endedAt: DateTime(2026, 11, 4, 14, 30),
  opponentName: 'AI 봇 · 초보',
  roundLength: const Duration(seconds: 30),
  reps: const [],
  samples: const [],
);

BattleResult _result({
  MatchOutcome? outcome = MatchOutcome.win,
  GameEnd end = GameEnd.timeUp,
  Duration roundLength = const Duration(seconds: 30),
  FormReport? form,
}) => BattleResult(
  matchup: _matchup,
  myReps: 12,
  myInvalidReps: 2,
  opponentReps: 14,
  myScore: 240,
  opponentScore: 125,
  end: end,
  decidedOutcome: outcome,
  endedAt: DateTime(2026, 11, 4, 14, 30),
  roundLength: roundLength,
  form: form,
);

/// The routes pushed or put in place, in order.
class _Routes extends NavigatorObserver {
  final settings = <RouteSettings>[];

  List<String?> get names => [for (final route in settings) route.name];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      settings.add(route.settings);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      settings.add(newRoute!.settings);
}

void main() {
  group('the values it gathers from main\'s battle result', () {
    test('a time-up win: the outcome, the scores, the reps, the times', () {
      final data = ResultScreen.reportOf(_result());
      expect(data.outcome, MatchOutcome.win);
      expect(data.byKo, isFalse);
      expect(data.exercise, ExerciseType.pushUp);
      expect(data.opponent.difficulty, BotDifficulty.beginner);
      expect(data.played, const Duration(seconds: 30));
      expect((data.myScore, data.opponentScore), (240, 125));
      expect((data.myValidReps, data.myInvalidReps), (12, 2));
      expect(data.endedAt, DateTime(2026, 11, 4, 14, 30));
    });

    test('a KO loss, and the time it took', () {
      final data = ResultScreen.reportOf(
        _result(
          outcome: MatchOutcome.lose,
          end: GameEnd.ko,
          roundLength: const Duration(seconds: 24),
        ),
      );
      expect(data.outcome, MatchOutcome.lose);
      expect(data.byKo, isTrue);
      expect(data.played, const Duration(seconds: 24));
    });

    test('a battle built without a game shows its reps as the scores', () {
      final data = ResultScreen.reportOf(_result(outcome: null));
      expect((data.myScore, data.opponentScore), (12, 14));
      expect(data.outcome, MatchOutcome.lose);
    });

    test('feedback only with a form report', () {
      expect(ResultScreen.reportOf(_result()).hasFeedback, isFalse);
      expect(ResultScreen.reportOf(_result(form: _form)).hasFeedback, isTrue);
    });

    test('main has no personal best, latest battles or tip: those cards '
        'stay hidden until the view model (J4) gives them', () {
      final data = ResultScreen.reportOf(_result(form: _form));
      expect(data.best, isNull);
      expect(data.recent, isNull);
      expect(data.tip, isNull);
    });
  });

  group('the buttons', () {
    late _Routes routes;

    /// Opens ResultScreen above a home page, where the battle leaves it. The
    /// matching and feedback routes are stubs that show their argument.
    Future<void> open(WidgetTester tester, BattleResult result) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      routes = _Routes();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          navigatorObservers: [routes],
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
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                Scaffold(body: Text('${settings.name} ${settings.arguments}')),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      routes.settings.clear();
    }

    testWidgets('it shows the report of the battle', (tester) async {
      await open(tester, _result());
      expect(find.byType(ResultReport), findsOneWidget);
      expect(find.text('승리'), findsOneWidget);
      expect(find.text('RepBot 초보'), findsOneWidget);
      expect(find.text('240'), findsOneWidget);
    });

    for (final (name, press) in [
      ('홈으로', (WidgetTester t) => t.tap(find.text('홈으로'))),
      ('the back button', (WidgetTester t) => t.tap(find.byTooltip('홈으로'))),
      ('system back', (WidgetTester t) => t.binding.handlePopRoute()),
    ]) {
      testWidgets('$name goes home', (tester) async {
        await open(tester, _result());
        await press(tester);
        await tester.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
        expect(find.byType(ResultScreen), findsNothing);
      });
    }

    testWidgets('다시 대결 replaces the result with a search for the same '
        'battle; back from it goes home', (tester) async {
      await open(tester, _result());
      await tester.tap(find.text('다시 대결'));
      await tester.pumpAndSettle();
      expect(routes.names, [GymRatsApp.matchingRoute]);
      final request = routes.settings.single.arguments! as BotMatchRequest;
      expect(request.exercise, ExerciseType.pushUp);
      expect(request.difficulty, BotDifficulty.beginner);
      expect(find.byType(ResultScreen), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('only the first leaving button acts', (tester) async {
      await open(tester, _result());
      final rematch = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      final home = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .onPressed!;
      rematch();
      rematch();
      home();
      await tester.pumpAndSettle();
      expect(routes.names, [GymRatsApp.matchingRoute]);
    });

    testWidgets('자세 피드백 전체 보기 opens this battle\'s feedback on top; '
        'back comes here again', (tester) async {
      await open(tester, _result(form: _form));
      await tester.tap(find.text('자세 피드백 전체 보기'));
      await tester.pumpAndSettle();
      expect(routes.names, [GymRatsApp.feedbackRoute]);
      expect(routes.settings.single.arguments, same(_form));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ResultScreen), findsOneWidget);
    });

    testWidgets('without a form report there is no feedback link', (
      tester,
    ) async {
      await open(tester, _result());
      expect(find.text('자세 피드백 전체 보기'), findsNothing);
    });
  });
}
