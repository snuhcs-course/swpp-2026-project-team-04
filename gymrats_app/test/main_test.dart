import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/battle_screen.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/match_setup_screen.dart';
import 'package:gymrats_app/screens/matching_screen.dart';
import 'package:gymrats_app/screens/online_lobby_screen.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/screens/versus_screen.dart';
import 'package:gymrats_app/services/matching/bot_matchmaker.dart';
import 'package:gymrats_app/services/matching/matchmaker.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/user/in_memory_user_repository.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/widgets/bot_difficulty_sheet.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/match_record_card.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';

/// Stays in the queue, with no server behind it.
class _QueuedSession extends OnlineBattleSession {
  _QueuedSession(Uri endpoint, String token, AvatarModel avatar)
    : super(endpoint: endpoint, accessToken: token, avatar: avatar);

  @override
  Future<void> connect() async {
    playerId = 'me';
    connected = true;
    phase = OnlinePhase.queued;
    notifyListeners();
  }
}

void main() {
  /// Taps [exercise] on the exercise sheet.
  Future<void> choose(WidgetTester tester, String exercise) async {
    await tester.tap(
      find.descendant(
        of: find.byType(ExerciseSheet),
        matching: find.text(exercise),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the AI card, chooses push-ups and 초보, and lets the matching page
  /// slide in. The radar keeps turning, so pumpAndSettle would only return
  /// after the bot is found.
  Future<void> startMatching(WidgetTester tester) async {
    await tester.tap(find.text('AI 1v1'));
    await tester.pumpAndSettle();
    await choose(tester, '푸쉬업');
    await tester.tap(find.text('초보'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('start leads through matching to versus; cancelling goes home', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);

    await startMatching(tester);
    expect(find.text('초보 AI 상대를 찾는 중'), findsOneWidget);
    expect(find.text('MATCH FOUND'), findsNothing);

    // The bot answers 3 seconds after the search started.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('MATCH FOUND'), findsOneWidget);
    expect(find.text('우현'), findsOneWidget);
    expect(find.text('AI 봇 · 초보'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);

    // System back only asks; 게임 나가기 in the dialog goes home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('게임에서 나갈까요?'), findsOneWidget);
    expect(find.text('AI 봇 · 초보와의 대결이 취소되고\n홈으로 돌아가요.'), findsOneWidget);
    expect(find.text('MATCH FOUND'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(ExitDialog),
        matching: find.text('게임 나가기'),
      ),
    );
    await tester.pumpAndSettle();
    // Home keeps its scroll position; the greeting is at the top.
    await tester.scrollUntilVisible(find.text('안녕하세요, 우현님'), -180);
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);
  });

  testWidgets('the AI card leads through both sheets to a squat bot at that '
      'level', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 1v1'));
    await tester.pumpAndSettle();
    await choose(tester, '스쿼트');
    expect(find.text('스쿼트 · 30초 · 1v1'), findsOneWidget);

    await tester.tap(find.text('고수'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('고수 AI 상대를 찾는 중'), findsOneWidget);
    expect(
      tester.widget<MatchingScreen>(find.byType(MatchingScreen)).exercise,
      ExerciseType.squat,
    );

    // The bot answers 3 seconds after the search started.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final matchup = tester
        .widget<VersusScreen>(find.byType(VersusScreen))
        .matchup;
    expect(matchup.exercise, ExerciseType.squat);
    expect(matchup.opponent.name, 'AI 봇 · 고수');
    expect(matchup.opponent.difficulty, BotDifficulty.expert);
    expect(tester.takeException(), isNull);
  });

  for (final (name, exercise) in const [
    ('푸쉬업', ExerciseType.pushUp),
    ('스쿼트', ExerciseType.squat),
  ]) {
    testWidgets(
      'the online card leads through its sheet to a lobby for $name',
      (tester) async {
        await tester.pumpWidget(
          testApp(createOnlineSession: _QueuedSession.new),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('온라인 1v1'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(ExerciseSheet),
            matching: find.text(name),
          ),
        );
        // The lobby's radar keeps turning, so pumpAndSettle would never return.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester
              .widget<OnlineLobbyScreen>(find.byType(OnlineLobbyScreen))
              .exercise,
          exercise,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  testWidgets('closing a sheet on the real app stays on home', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    for (final mode in const ['온라인 1v1', 'AI 1v1']) {
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseSheet), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    }
    await tester.tap(find.text('AI 1v1'));
    await tester.pumpAndSettle();
    await choose(tester, '푸쉬업');
    expect(find.byType(BotDifficultySheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BotDifficultySheet), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the online route takes the exercise, not a bot request', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    final generate = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .onGenerateRoute!;
    // Built without showing it: shown, it would connect to the server.
    ExerciseType exerciseOf(Object? arguments) {
      final route = generate(
        RouteSettings(name: GymRatsApp.onlineBattleRoute, arguments: arguments),
      );
      return ((route! as MaterialPageRoute<void>).builder(
        tester.element(find.byType(HomeScreen)),
      ) as OnlineLobbyScreen).exercise;
    }

    expect(exerciseOf(ExerciseType.squat), ExerciseType.squat);
    expect(exerciseOf(null), ExerciseType.pushUp);
  });

  testWidgets("'?' on home opens the rules over home; back returns home", (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('게임 규칙'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.text('건너뛰기'), findsNothing);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsNothing);
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);
  });

  testWidgets('every screen gets the same repository and matchmaker', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    final home = tester.element(find.byType(HomeScreen));
    final repository = home.read<UserRepository>();
    final matchmaker = home.read<Matchmaker>();
    expect(repository, isA<InMemoryUserRepository>());
    expect(matchmaker, isA<BotMatchmaker>());

    await startMatching(tester);
    final matching = tester.element(find.byType(MatchingScreen));
    expect(matching.read<UserRepository>(), same(repository));
    expect(matching.read<Matchmaker>(), same(matchmaker));

    await tester.pumpAndSettle();
    final versus = tester.element(find.byType(VersusScreen));
    expect(versus.read<UserRepository>(), same(repository));
    expect(versus.read<Matchmaker>(), same(matchmaker));
  });

  testWidgets('the matching flow sets up in MatchSetupScreen; the setup '
      'route still opens SetupScreen', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    final generate = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .onGenerateRoute!;
    final context = tester.element(find.byType(HomeScreen));
    // Builds the screens without showing them: shown, they would ask the
    // real camera plugin for permission.
    Widget screenFor(String name, Object arguments) {
      final route = generate(RouteSettings(name: name, arguments: arguments));
      expect(route, isA<MaterialPageRoute<ExerciseType>>());
      return (route! as MaterialPageRoute<ExerciseType>).builder(context);
    }

    const matchup = Matchup(
      exercise: ExerciseType.pushUp,
      playerName: '우현',
      opponent: BotMatchmaker.bot,
    );
    expect(
      screenFor(GymRatsApp.matchSetupRoute, matchup),
      isA<MatchSetupScreen>().having(
        (screen) => screen.matchup,
        'matchup',
        same(matchup),
      ),
    );
    expect(
      screenFor(GymRatsApp.setupRoute, ExerciseType.pushUp),
      isA<SetupScreen>(),
    );
  });

  testWidgets('the battle route builds the battle for the matchup', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    final generate = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .onGenerateRoute!;
    const matchup = Matchup(
      exercise: ExerciseType.pushUp,
      playerName: '우현',
      opponent: BotMatchmaker.bot,
    );
    // Built without showing it: shown, it would open the real camera.
    final route = generate(
      const RouteSettings(name: GymRatsApp.battleRoute, arguments: matchup),
    );
    expect(route, isA<MaterialPageRoute<void>>());
    expect(
      (route! as MaterialPageRoute<void>).builder(
        tester.element(find.byType(HomeScreen)),
      ),
      isA<BattleScreen>().having(
        (screen) => screen.matchup,
        'matchup',
        same(matchup),
      ),
    );
  });

  testWidgets('after the result, home shows the saved battle', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    final result = BattleResult(
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: BotMatchmaker.bot,
      ),
      myReps: 40,
      myInvalidReps: 2,
      opponentReps: 30,
      endedAt: DateTime(2026, 10, 4, 14, 32),
    );
    // What the battle does when time is up: save, then show the result.
    await tester
        .element(find.byType(HomeScreen))
        .read<UserRepository>()
        .saveMatch(result.record);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(GymRatsApp.resultRoute, arguments: result);
    await tester.pumpAndSettle();
    expect(find.text('WIN'), findsOneWidget);
    expect(find.text('10개 차이로 이겼어요!'), findsOneWidget);

    await tester.tap(find.text('홈으로'));
    await tester.pumpAndSettle();
    expect(find.text('40회'), findsOneWidget);
    expect(find.text('30회'), findsOneWidget);
    await tester.tap(find.text('AI 1v1'));
    await tester.pumpAndSettle();
    expect(find.text('개인 최고 40회'), findsOneWidget);
  });

  testWidgets("after a game's result, home shows its points, not its reps", (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    final result = BattleResult(
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: BotMatchmaker.bot,
      ),
      myReps: 7,
      myInvalidReps: 2,
      opponentReps: 9,
      myScore: 150,
      opponentScore: 90,
      decidedOutcome: MatchOutcome.win,
      endedAt: DateTime(2026, 10, 4, 14, 32),
    );
    await tester
        .element(find.byType(HomeScreen))
        .read<UserRepository>()
        .saveMatch(result.record);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(GymRatsApp.resultRoute, arguments: result);
    await tester.pumpAndSettle();

    await tester.tap(find.text('홈으로'));
    await tester.pumpAndSettle();
    expect(find.text('150'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.text('7회'), findsNothing);
    expect(find.text('9회'), findsNothing);
    // Its reps alone would read as a loss: the stored outcome stands.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('150'),
          matching: find.byType(MatchRecordCard),
        ),
        matching: find.text('승'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('AI 1v1'));
    await tester.pumpAndSettle();
    expect(find.text('개인 최고 150점'), findsOneWidget);
  });
}
