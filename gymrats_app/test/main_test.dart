import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/battle_screen.dart';
import 'package:gymrats_app/screens/character_select_screen.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/match_setup_screen.dart';
import 'package:gymrats_app/screens/matching_screen.dart';
import 'package:gymrats_app/screens/online_lobby_screen.dart';
import 'package:gymrats_app/screens/play_screen.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/screens/versus_screen.dart';
import 'package:gymrats_app/services/matching/bot_matchmaker.dart';
import 'package:gymrats_app/services/matching/matchmaker.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/services/user/in_memory_user_repository.dart';
import 'package:gymrats_app/services/user/rules_seen_store.dart';
import 'package:gymrats_app/services/user/settings_store.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/help_rules.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';

/// Stays in the queue, with no server behind it.
class _QueuedSession extends OnlineBattleSession {
  _QueuedSession(Uri endpoint, String token, String character)
    : super(endpoint: endpoint, accessToken: token, character: character);

  @override
  Future<void> connect() async {
    playerId = 'me';
    connected = true;
    phase = OnlinePhase.queued;
    notifyListeners();
  }
}

/// A character store whose reads wait until [finishRead] (or fail at
/// [failRead]), as a slow phone storage would; writes land at once. A read answers what was saved when
/// it began, as a real read in flight does.
class _SlowReadCharacterStore implements CharacterStore {
  final saved = <int, String>{};
  final _reads = <(Completer<String>, String)>[];

  void finishRead() {
    for (final (answer, value) in _reads) {
      answer.complete(value);
    }
    _reads.clear();
  }

  void failRead() {
    for (final (answer, _) in _reads) {
      answer.completeError(StateError('storage unreadable'));
    }
    _reads.clear();
  }

  @override
  Future<String> read(int accountId) {
    final answer = Completer<String>();
    _reads.add((answer, saved[accountId] ?? 'mouse'));
    return answer.future;
  }

  @override
  Future<void> write(int accountId, String characterId) async {
    saved[accountId] = characterId;
  }
}

/// Turns on the system's reduced motion, so home's RepBot holds still and
/// pumpAndSettle can settle.
void _stillRepBot(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// The app at home on a phone-sized screen, with RepBot holding still.
Future<void> _openApp(WidgetTester tester, [GymRatsApp? app]) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _stillRepBot(tester);
  await tester.pumpWidget(app ?? testApp());
  await tester.pumpAndSettle();
}

void main() {
  /// Taps [text] and lets what it opens slide in.
  Future<void> tapAndSettle(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Opens 게임 시작, then the AI 1v1 page.
  Future<void> openBotSetup(WidgetTester tester) async {
    await tapAndSettle(tester, '게임 시작');
    await tapAndSettle(tester, 'AI 1v1');
  }

  /// Chooses push-ups and 초보 on the AI 1v1 page, starts, and lets the
  /// matching page slide in. The radar keeps turning, so pumpAndSettle would
  /// only return after the bot is found.
  Future<void> startMatching(WidgetTester tester) async {
    await openBotSetup(tester);
    await tester.tap(find.text('초보'));
    await tester.pump();
    await tester.tap(find.text('대결 시작'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('start leads through matching to versus; cancelling goes home', (
    tester,
  ) async {
    await _openApp(tester);
    expect(find.text('GYMMOUSE'), findsOneWidget);

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
    // Past 게임 시작 and AI 1v1, straight to home.
    expect(find.byType(PlayScreen), findsNothing);
    expect(find.text('GYMMOUSE'), findsOneWidget);
  });

  testWidgets('the AI 1v1 page leads to a squat bot at the level chosen', (
    tester,
  ) async {
    await _openApp(tester);
    await openBotSetup(tester);
    await tester.tap(find.text('스쿼트'));
    await tester.tap(find.text('고수'));
    await tester.pump();
    expect(find.text('스쿼트 · RepBot 고수 · 30초 대결'), findsOneWidget);

    await tester.tap(find.text('대결 시작'));
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
        await _openApp(
          tester,
          testApp(createOnlineSession: _QueuedSession.new),
        );
        await tapAndSettle(tester, '게임 시작');
        await tapAndSettle(tester, '온라인 1v1');
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

  testWidgets('back steps out one page at a time to home', (tester) async {
    await _openApp(tester);
    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    await tapAndSettle(tester, '게임 시작');
    await tapAndSettle(tester, '온라인 1v1');
    expect(find.byType(ExerciseSheet), findsOneWidget);
    await back();
    expect(find.byType(ExerciseSheet), findsNothing);
    expect(find.byType(PlayScreen), findsOneWidget);

    await tapAndSettle(tester, 'AI 1v1');
    expect(find.text('RepBot과 겨룰 종목과 난이도를 골라요'), findsOneWidget);
    await back();
    expect(find.byType(PlayScreen), findsOneWidget);
    await back();
    expect(find.byType(PlayScreen), findsNothing);
    expect(find.text('GYMMOUSE'), findsOneWidget);
  });

  testWidgets('the online route takes the exercise, not a bot request', (
    tester,
  ) async {
    await _openApp(tester);
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

  testWidgets('the online route sends the character of the account', (
    tester,
  ) async {
    final store = MemoryCharacterStore()..values[testAccount.id] = 'kangaroo';
    await _openApp(
      tester,
      GymRatsApp(
        authRepository: signedInAuth(),
        userRepository: InMemoryUserRepository(),
        characterStore: store,
      ),
    );
    final route =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).onGenerateRoute!(
          const RouteSettings(name: GymRatsApp.onlineBattleRoute),
        )!;
    final lobby = (route as MaterialPageRoute<void>).builder(
      tester.element(find.byType(HomeScreen)),
    ) as OnlineLobbyScreen;
    expect(lobby.myCharacter, 'kangaroo');
  });

  testWidgets("'?' on home opens the rules over home; back returns home", (
    tester,
  ) async {
    await _openApp(tester);
    await tester.tap(find.byTooltip('게임 규칙'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.text('건너뛰기'), findsNothing);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsNothing);
    expect(find.text('GYMMOUSE'), findsOneWidget);
  });

  testWidgets('every screen gets the same repository and matchmaker', (
    tester,
  ) async {
    await _openApp(tester);
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

  // The bot flow no longer passes these routes (versus opens the battle
  // screen, which sets up itself: versus_screen_test.dart); they stay in the
  // app for 한상우's setup screens.
  testWidgets('the match setup route still opens MatchSetupScreen and the '
      'setup route SetupScreen', (tester) async {
    await _openApp(tester);
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
    await _openApp(tester);
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
      isA<BattleScreen>()
          .having((screen) => screen.matchup, 'matchup', same(matchup))
          .having((screen) => screen.myCharacter, 'my character', 'mouse'),
    );
  });

  group('the character (W3)', () {
    late MemoryCharacterStore store;

    GymRatsApp app() => GymRatsApp(
      authRepository: signedInAuth(),
      userRepository: InMemoryUserRepository(),
      characterStore: store,
    );

    setUp(() => store = MemoryCharacterStore());

    /// The character idling large on 캐릭터 선택.
    String previewOf(WidgetTester tester) => tester
        .widget<CharacterIdleFigure>(find.byType(CharacterIdleFigure))
        .characterId;

    testWidgets('the signed-in account\'s saved character shows on 캐릭터 '
        '선택, opened from home\'s 캐릭터 row', (tester) async {
      store.values[testAccount.id] = 'bear';
      await _openApp(tester, app());
      await tapAndSettle(tester, '캐릭터');
      expect(previewOf(tester), 'bear');
    });

    testWidgets('a pick on 캐릭터 선택, opened from home\'s 캐릭터 row, is '
        'saved for the account and goes into the next bot battle', (
      tester,
    ) async {
      await _openApp(tester, app());
      await tapAndSettle(tester, '캐릭터');
      expect(find.byType(CharacterSelectScreen), findsOneWidget);
      expect(previewOf(tester), 'mouse');
      await tester.tap(find.text('펭뚱이'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, '이 캐릭터로 하기');
      expect(find.byType(CharacterSelectScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(store.values, {testAccount.id: 'penguin'});

      final generate = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .onGenerateRoute!;
      final route =
          generate(
                const RouteSettings(
                  name: GymRatsApp.battleRoute,
                  arguments: Matchup(
                    exercise: ExerciseType.pushUp,
                    playerName: '우현',
                    opponent: BotMatchmaker.bot,
                  ),
                ),
              )!
              as MaterialPageRoute<void>;
      expect(
        (route.builder(
          tester.element(find.byType(HomeScreen)),
        ) as BattleScreen).myCharacter,
        'penguin',
      );
    });

    group('while the saved character is still being read', () {
      late _SlowReadCharacterStore slow;

      setUp(
        () => slow = _SlowReadCharacterStore()..saved[testAccount.id] = 'seal',
      );

      /// The app on a phone-sized screen, a second after it opened, with
      /// the character's read still running (no settling: a spinner turns).
      Future<void> openWhileReading(
        WidgetTester tester, {
        RulesSeenStore? rules,
      }) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        _stillRepBot(tester);
        await tester.pumpWidget(
          GymRatsApp(
            authRepository: signedInAuth(),
            userRepository: InMemoryUserRepository(),
            characterStore: slow,
            rulesSeenStore: rules,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      CharacterViewModel characters(WidgetTester tester) =>
          Provider.of<CharacterViewModel>(
            tester.element(find.byType(MaterialApp)),
            listen: false,
          );

      testWidgets('home waits for it, so 캐릭터 선택 and a bot battle start on '
          'the saved character and a pick does not overwrite it', (
        tester,
      ) async {
        await openWhileReading(tester);
        expect(find.byType(HomeScreen), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        slow.finishRead();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        final route =
            tester
                    .widget<MaterialApp>(find.byType(MaterialApp))
                    .onGenerateRoute!(
                  const RouteSettings(
                    name: GymRatsApp.battleRoute,
                    arguments: Matchup(
                      exercise: ExerciseType.pushUp,
                      playerName: '우현',
                      opponent: BotMatchmaker.bot,
                    ),
                  ),
                )!
                as MaterialPageRoute<void>;
        expect(
          (route.builder(
            tester.element(find.byType(HomeScreen)),
          ) as BattleScreen).myCharacter,
          'seal',
        );
        await tapAndSettle(tester, '캐릭터');
        expect(previewOf(tester), 'seal');
        await tapAndSettle(tester, '이 캐릭터로 하기');
        expect(slow.saved[testAccount.id], 'seal');
        expect(characters(tester).characterId, 'seal');
      });

      testWidgets('a new account reads the rules meanwhile; after 시작하기 '
          'home still waits for the read', (tester) async {
        await openWhileReading(
          tester,
          rules: MemoryRulesSeenStore()..values[testAccount.id] = false,
        );
        expect(find.byType(HelpScreen), findsOneWidget);
        for (var page = 1; page < HelpRules.pages.length; page++) {
          await tester.tap(find.text('다음'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.tap(find.text('시작하기'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(HelpScreen), findsNothing);
        expect(find.byType(HomeScreen), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        slow.finishRead();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(characters(tester).characterId, 'seal');
      });

      testWidgets('a read that fails opens home with the mouse', (
        tester,
      ) async {
        await openWhileReading(tester);
        slow.failRead();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(characters(tester).characterId, 'mouse');
        expect(characters(tester).loading, isFalse);
      });
    });

    testWidgets('logging out puts the mouse back for the next account', (
      tester,
    ) async {
      store.values[testAccount.id] = 'seal';
      await _openApp(tester, app());
      final element = tester.element(find.byType(HomeScreen));
      expect(
        Provider.of<CharacterViewModel>(element, listen: false).art.name,
        '물렁범',
      );
      await Provider.of<AuthViewModel>(element, listen: false).logOut();
      await tester.pumpAndSettle();
      expect(
        Provider.of<CharacterViewModel>(
          tester.element(find.byType(MaterialApp)),
          listen: false,
        ).characterId,
        'mouse',
      );
    });
  });

  testWidgets('after the result, home shows the saved battle', (tester) async {
    await _openApp(tester);
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
    // Home loaded again: 게임 시작 offers that battle again, and the AI 1v1
    // page reads the new best.
    await tapAndSettle(tester, '게임 시작');
    expect(find.text('푸쉬업 · AI 1v1 · 고수'), findsOneWidget);
    await tapAndSettle(tester, 'AI 1v1');
    expect(find.text('최고 40회'), findsOneWidget);
  });

  testWidgets("after a game's result, the best reads in points, not reps", (
    tester,
  ) async {
    await _openApp(tester);
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
    await openBotSetup(tester);
    expect(find.text('최고 150점'), findsOneWidget);
    expect(find.text('최고 7회'), findsNothing);
  });

  testWidgets('the sound switches keep what an earlier run saved, and save '
      'a change', (tester) async {
    // What the previous run of the app left on the phone.
    final store = MemorySettingsStore()
      ..soundEffectsOn = false
      ..voiceGuidanceOn = true;
    await _openApp(
      tester,
      GymRatsApp(
        authRepository: signedInAuth(),
        userRepository: InMemoryUserRepository(),
        settingsStore: store,
      ),
    );
    await tapAndSettle(tester, '환경설정');
    bool switchOf(String title) => tester
        .widget<Switch>(
          find.descendant(
            of: find.ancestor(
              of: find.text(title),
              matching: find.byType(InkWell),
            ),
            matching: find.byType(Switch),
          ),
        )
        .value;
    expect(switchOf('효과음'), isFalse);
    expect(switchOf('음성 안내'), isTrue);

    await tester.tap(find.text('효과음'));
    await tester.pumpAndSettle();
    expect(switchOf('효과음'), isTrue);
    expect(store.soundEffectsOn, isTrue);
  });
}
