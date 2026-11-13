import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/screens/ai_setup_screen.dart';
import 'package:gymrats_app/screens/help_screen.dart';
import 'package:gymrats_app/screens/play_screen.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_mode_card.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

MatchRecord _battleWith(String opponentName, ExerciseType exercise) =>
    MatchRecord(
      exercise: exercise,
      opponentName: opponentName,
      myReps: 10,
      opponentReps: 8,
    );

void main() {
  late FakeUserRepository repository;

  /// The app's character, above the navigator as in main.dart.
  late CharacterViewModel characters;

  // A tap that misses its target must fail here, not pass with nothing done.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  setUp(() {
    characters = CharacterViewModel(store: MemoryCharacterStore());
    addTearDown(characters.dispose);
    repository = FakeUserRepository()
      ..profile = UserProfile(
        name: '우현',
        bests: const {
          ExerciseType.pushUp: PersonalBest(reps: 24, score: 240),
          ExerciseType.squat: PersonalBest(reps: 30),
        },
        lastMatch: _battleWith(
          BotDifficulty.expert.opponentName,
          ExerciseType.pushUp,
        ),
      );
  });

  /// The play page over a stub page, on home's loaded view model, with stub
  /// pages for the routes it opens that show their arguments.
  Future<HomeViewModel> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = HomeViewModel(repository: repository);
    addTearDown(vm.dispose);
    await vm.load();
    await tester.pumpWidget(
      ChangeNotifierProvider<CharacterViewModel>.value(
        value: characters,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: vm,
                      child: const PlayScreen(),
                    ),
                  ),
                ),
                child: const Text('below'),
              ),
            ),
          ),
          routes: {
            GymRatsApp.helpRoute: (_) => const HelpScreen(),
            GymRatsApp.characterRoute: (_) =>
                const Scaffold(body: Text('character page')),
            GymRatsApp.onlineBattleRoute: (context) => Scaffold(
              body: Text('lobby ${ModalRoute.of(context)!.settings.arguments}'),
            ),
            GymRatsApp.matchingRoute: (context) {
              final request =
                  ModalRoute.of(context)!.settings.arguments!
                      as BotMatchRequest;
              return Scaffold(
                body: Text(
                  'matching ${request.exercise} ${request.difficulty}',
                ),
              );
            },
          },
        ),
      ),
    );
    await tester.tap(find.text('below'));
    await tester.pumpAndSettle();
    return vm;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('shows both battles, the latest setup and the rules', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('01 / PLAY'), findsOneWidget);
    expect(find.text('게임 시작'), findsOneWidget);
    expect(find.byType(BattleModeCard), findsNWidgets(2));
    expect(find.text('온라인 1v1'), findsOneWidget);
    expect(find.text('AI 1v1'), findsOneWidget);
    expect(find.text('푸쉬업 · 스쿼트'), findsOneWidget);
    expect(find.text('초보 · 중수 · 고수'), findsOneWidget);
    expect(find.text('최근 설정으로 다시 하기'), findsOneWidget);
    expect(find.text('푸쉬업 · AI 1v1 · 고수'), findsOneWidget);
    expect(find.text('30초 · 점수 높은 쪽 승리'), findsOneWidget);
    expect(find.text('규칙 보기'), findsOneWidget);
  });

  testWidgets('the online card asks for the exercise, then opens the lobby', (
    tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, find.text('온라인 1v1'));
    expect(find.byType(ExerciseSheet), findsOneWidget);
    expect(find.text('온라인 1v1 · 30초'), findsOneWidget);
    // The sheet reads each exercise's own best.
    expect(find.text('개인 최고 240점', findRichText: true), findsOneWidget);
    expect(find.text('개인 최고 30회', findRichText: true), findsOneWidget);

    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(ExerciseSheet),
        matching: find.text('스쿼트'),
      ),
    );
    expect(find.text('lobby ${ExerciseType.squat}'), findsOneWidget);
  });

  testWidgets('closing the online sheet stays here with no lobby', (
    tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, find.text('온라인 1v1'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseSheet), findsNothing);
    expect(find.byType(PlayScreen), findsOneWidget);
    expect(find.textContaining('lobby'), findsNothing);
  });

  testWidgets('an exercise chosen after the page has gone opens no lobby', (
    tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, find.text('온라인 1v1'));
    final page = ModalRoute.of(tester.element(find.byType(PlayScreen)))!;
    page.navigator!.removeRoute(page);
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(ExerciseSheet),
        matching: find.text('푸쉬업'),
      ),
    );
    expect(find.textContaining('lobby'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the AI card opens the AI 1v1 page on the same view model', (
    tester,
  ) async {
    final vm = await open(tester);
    await tapAndSettle(tester, find.text('AI 1v1'));
    expect(find.byType(AiSetupScreen), findsOneWidget);
    await tapAndSettle(tester, find.text('고수'));
    expect(vm.state.botSetup.difficulty, BotDifficulty.expert);
  });

  testWidgets('again with a bot starts the search at once', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('최근 설정으로 다시 하기'));
    expect(
      find.text('matching ${ExerciseType.pushUp} ${BotDifficulty.expert}'),
      findsOneWidget,
    );
  });

  testWidgets('again after an online battle opens the lobby at once', (
    tester,
  ) async {
    repository.profile = UserProfile(
      name: '우현',
      lastMatch: _battleWith('민지', ExerciseType.squat),
    );
    await open(tester);
    expect(find.text('스쿼트 · 온라인 1v1'), findsOneWidget);
    await tapAndSettle(tester, find.text('최근 설정으로 다시 하기'));
    expect(find.byType(ExerciseSheet), findsNothing);
    expect(find.text('lobby ${ExerciseType.squat}'), findsOneWidget);
  });

  testWidgets('nothing to play again before the first battle', (tester) async {
    repository.profile = const UserProfile(name: '우현');
    await open(tester);
    expect(find.text('최근 설정으로 다시 하기'), findsNothing);
    expect(find.byType(BattleModeCard), findsNWidgets(2));
  });

  testWidgets('규칙 보기 opens the rules', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.text('규칙 보기'));
    expect(find.byType(HelpScreen), findsOneWidget);
  });

  testWidgets('back returns to the page below', (tester) async {
    await open(tester);
    await tapAndSettle(tester, find.byTooltip('뒤로'));
    expect(find.byType(PlayScreen), findsNothing);
    expect(find.text('below'), findsOneWidget);
  });

  for (final (label, size, scale) in [
    ('a short phone', const Size(360, 640), 1.0),
    ('a large text size', const Size(360, 780), 2.0),
  ]) {
    testWidgets('fits $label without overflow, scrolling if it must', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.text('규칙 보기'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      expect(find.text('규칙 보기').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('the 캐릭터 row shows my character and opens 캐릭터 선택', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('캐릭터'), findsOneWidget);
    expect(find.text('GYM마우스'), findsOneWidget);
    expect(
      tester.widget<CharacterFigure>(find.byType(CharacterFigure)).characterId,
      'mouse',
    );
    await tapAndSettle(tester, find.text('캐릭터'));
    expect(find.text('character page'), findsOneWidget);
  });

  testWidgets('the 캐릭터 row follows a new choice at once', (tester) async {
    await open(tester);
    await characters.choose('penguin');
    await tester.pump();
    expect(find.text('펭뚱이'), findsOneWidget);
    expect(find.text('GYM마우스'), findsNothing);
    expect(
      tester.widget<CharacterFigure>(find.byType(CharacterFigure)).characterId,
      'penguin',
    );
  });

  testWidgets('every button is big enough and has a name', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(
      find.bySemanticsLabel('최근 설정으로 다시 하기, 푸쉬업 · AI 1v1 · 고수'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('캐릭터, GYM마우스'), findsOneWidget);
    semantics.dispose();
  });
}
