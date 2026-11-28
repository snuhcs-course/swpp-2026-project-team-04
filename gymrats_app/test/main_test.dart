import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/arcade_ai_level.dart';
import 'package:gymrats_app/models/arcade_progress.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/arcade_boss_screen.dart';
import 'package:gymrats_app/screens/arcade_screen.dart';
import 'package:gymrats_app/screens/battle_screen.dart';
import 'package:gymrats_app/screens/character_select_screen.dart';
import 'package:gymrats_app/screens/coach_screen.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/hold_stage_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/match_setup_screen.dart';
import 'package:gymrats_app/screens/matching_screen.dart';
import 'package:gymrats_app/screens/online_lobby_screen.dart';
import 'package:gymrats_app/screens/play_screen.dart';
import 'package:gymrats_app/screens/setup_screen.dart';
import 'package:gymrats_app/screens/versus_screen.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/services/audio/sound_services.dart';
import 'package:gymrats_app/services/feedback/goal_store.dart';
import 'package:gymrats_app/services/friends/friend_repository.dart';
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
import 'package:gymrats_app/viewmodels/coach_viewmodel.dart';
import 'package:gymrats_app/widgets/arcade_stage_sheet.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/help_rules.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';
import 'support/form_report_fixtures.dart';

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

  /// Opens 게임 시작, then the arcade's map (P16).
  Future<void> openArcade(WidgetTester tester) async {
    await tapAndSettle(tester, '게임 시작');
    await tapAndSettle(tester, '아케이드');
  }

  /// Opens the matching page for a push-up bot at 초보, as a past AI 1v1
  /// battle's 다시 대결 still does (P16 took AI 1v1 off 게임 시작), and lets
  /// it slide in. The radar keeps turning, so pumpAndSettle would only
  /// return after the bot is found.
  Future<void> startMatching(WidgetTester tester) async {
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(
          GymRatsApp.matchingRoute,
          arguments: const BotMatchRequest(
            exercise: ExerciseType.pushUp,
            difficulty: BotDifficulty.beginner,
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// The app with [best] stars saved for the signed-in account's arcade.
  GymRatsApp arcadeApp(List<int> best) => GymRatsApp(
    authRepository: signedInAuth(),
    userRepository: InMemoryUserRepository(),
    arcadeStore: MemoryArcadeProgressStore()
      ..saved[testAccount.id] = ArcadeProgress(best),
  );

  /// 도전 on the stage sheet.
  Finder sheetChallenge() => find.descendant(
    of: find.byType(ArcadeStageSheet),
    matching: find.text('도전'),
  );

  testWidgets('게임 시작 leads through the arcade to a stage\'s versus; '
      'leaving goes back to the arcade (P16 spec 2 and 6)', (tester) async {
    await _openApp(tester);
    await openArcade(tester);
    expect(find.byType(ArcadeScreen), findsOneWidget);
    // A new account plays STAGE 1: the bar's 도전 opens its sheet.
    expect(find.text('STAGE 1 · 1F'), findsOneWidget);
    await tapAndSettle(tester, '도전');
    expect(find.byType(ArcadeStageSheet), findsOneWidget);
    await tester.tap(sheetChallenge());
    await tester.pumpAndSettle();

    expect(find.text('STAGE 1'), findsOneWidget);
    expect(find.text('아케이드로'), findsOneWidget);
    expect(find.text('RepBot'), findsOneWidget);
    expect(find.text('AI LV 1'), findsOneWidget);
    final matchup = tester
        .widget<VersusScreen>(find.byType(VersusScreen))
        .matchup;
    expect(matchup.opponent.name, 'STAGE 1 · RepBot');
    expect(matchup.opponent.pace, ArcadeAiLevel.lv1);

    // Back only asks; leaving returns to the arcade's map, not home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('게임에서 나갈까요?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(ExitDialog),
        matching: find.text('게임 나가기'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VersusScreen), findsNothing);
    expect(find.byType(ArcadeScreen), findsOneWidget);
  });

  testWidgets('the matching page still leads to versus; cancelling goes '
      'home', (tester) async {
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
    // Straight to home.
    expect(find.byType(PlayScreen), findsNothing);
    expect(find.text('GYMMOUSE'), findsOneWidget);
  });

  testWidgets('stage 2 opens 펭뚱이\'s squats at AI LV 2 once stage 1 has a '
      'star', (tester) async {
    await _openApp(tester, arcadeApp([1, for (var i = 1; i < 24; i++) 0]));
    await openArcade(tester);
    expect(find.text('STAGE 2 · 1F'), findsOneWidget);
    await tapAndSettle(tester, '도전');
    await tester.tap(sheetChallenge());
    await tester.pumpAndSettle();
    final matchup = tester
        .widget<VersusScreen>(find.byType(VersusScreen))
        .matchup;
    expect(matchup.exercise, ExerciseType.squat);
    expect(matchup.opponent.characterId, 'penguin');
    expect(matchup.opponent.pace, ArcadeAiLevel.lv2);
    expect(matchup.opponent.arcadeStage, 2);
    expect(find.text('펭뚱이'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group("a friend's invite on the arcade (#95's alert)", () {
    const friend = FriendPerson(id: 2, nickname: '헬창', code: '헬창#0002');
    // A11: the alert's sentence is two lines ("헬창님이" over this one).
    final invite = find.text('푸쉬업 대결을 신청했어요');

    /// The app with [best] saved for the arcade and a friend's push-up
    /// invite waiting.
    GymRatsApp invitedApp(List<int> best) {
      final friends = InMemoryFriendRepository()..friends.add(friend);
      friends.receiveInvite(friend, ExerciseType.pushUp);
      return GymRatsApp(
        authRepository: signedInAuth(),
        userRepository: InMemoryUserRepository(),
        arcadeStore: MemoryArcadeProgressStore()
          ..saved[testAccount.id] = ArcadeProgress(best),
        friendRepository: friends,
      );
    }

    /// The app's alert has read the invite.
    Future<void> settleInvite(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> openWith(WidgetTester tester, List<int> best) async {
      await _openApp(tester, invitedApp(best));
      await settleInvite(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(invite, findsOneWidget, reason: 'on home');
      await openArcade(tester);
      await settleInvite(tester);
    }

    testWidgets("it shows on the arcade's map as on home, and waits while a "
        "fight's sheet is open", (tester) async {
      await openWith(tester, [for (var i = 0; i < 24; i++) 0]);
      expect(find.byType(ArcadeScreen), findsOneWidget);
      expect(invite, findsOneWidget);
      await tapAndSettle(tester, '도전');
      expect(find.byType(ArcadeStageSheet), findsOneWidget);
      expect(invite, findsNothing);
      await tapAndSettle(tester, '닫기');
      expect(invite, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('it waits while a hold stage is open, and shows again on the '
        'map', (tester) async {
      SoundServices.shared = SoundServices.silent();
      addTearDown(() => SoundServices.shared = null);
      await openWith(tester, [3, 3, for (var i = 2; i < 24; i++) 0]);
      expect(invite, findsOneWidget);
      await tapAndSettle(tester, '도전');
      expect(find.byType(HoldStageScreen), findsOneWidget);
      expect(invite, findsNothing);
      await tester.tap(find.bySemanticsLabel('지도로'));
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeScreen), findsOneWidget);
      expect(invite, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets("it waits while a boss match's intro is open", (tester) async {
      await openWith(tester, [3, 3, 3, 3, 3, for (var i = 5; i < 24; i++) 0]);
      expect(invite, findsOneWidget);
      await tapAndSettle(tester, '도전');
      expect(find.byType(ArcadeBossScreen), findsOneWidget);
      expect(invite, findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
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
        await tapAndSettle(tester, '온라인 대결');
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
    await tapAndSettle(tester, '온라인 대결');
    expect(find.byType(ExerciseSheet), findsOneWidget);
    await back();
    expect(find.byType(ExerciseSheet), findsNothing);
    expect(find.byType(PlayScreen), findsOneWidget);

    await tapAndSettle(tester, '아케이드');
    expect(find.byType(ArcadeScreen), findsOneWidget);
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

  testWidgets('the talk route (A10) opens the talk on the report\'s view '
      'model, and every screen gets one goal store', (tester) async {
    await _openApp(tester);
    final home = tester.element(find.byType(HomeScreen));
    expect(home.read<GoalStore>(), isA<SecureGoalStore>());
    final generate = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .onGenerateRoute!;
    final talk = CoachViewModel(
      report: sampleReport(),
      characterId: 'seal',
      summary: '푸쉬업 · RepBot 초보 · 승리',
    );
    addTearDown(talk.dispose);
    final route = generate(
      RouteSettings(name: GymRatsApp.coachRoute, arguments: talk),
    );
    expect(route, isA<MaterialPageRoute<void>>());
    expect(
      (route! as MaterialPageRoute<void>).builder(home),
      isA<CoachScreen>().having(
        (screen) => screen.viewModel,
        'view model',
        same(talk),
      ),
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
        await tester.tap(find.text('완료'));
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
    expect(find.text('승리'), findsOneWidget);

    await tester.tap(find.text('홈으로'));
    await tester.pumpAndSettle();
    // Home loaded again: 게임 시작's online sheet reads the new best.
    await tapAndSettle(tester, '게임 시작');
    await tapAndSettle(tester, '온라인 대결');
    expect(find.text('개인 최고 40회', findRichText: true), findsOneWidget);
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
    await tapAndSettle(tester, '게임 시작');
    await tapAndSettle(tester, '온라인 대결');
    expect(find.text('개인 최고 150점', findRichText: true), findsOneWidget);
    expect(find.text('개인 최고 7회', findRichText: true), findsNothing);
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
