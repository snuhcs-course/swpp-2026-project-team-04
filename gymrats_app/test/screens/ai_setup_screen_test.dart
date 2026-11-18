import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/screens/ai_setup_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';
import 'package:gymrats_app/widgets/accent_button.dart';
import 'package:gymrats_app/widgets/lobby_parts.dart';
import 'package:provider/provider.dart';
import 'package:gymrats_app/models/feedback_goal.dart';
import 'package:gymrats_app/services/feedback/goal_store.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';

import '../support/auth_fakes.dart';
import '../support/fakes.dart';
import '../widgets/battle_test_support.dart' show loadBattleFonts;

/// The squat goal of the tests: 20 counted reps, set with the seal after 18.
final _squatGoal = FeedbackGoal(
  exercise: ExerciseType.squat,
  kind: GoalKind.reps,
  target: 20,
  baseline: 18,
  title: '스쿼트 20회 인정받기',
  setAt: DateTime(2026, 11, 17, 14),
  characterId: 'seal',
  fromMatch: 'report-1',
);

/// A goal of [kind] and [target], for the summary line.
FeedbackGoal _goalOf(GoalKind kind, int target) => FeedbackGoal(
  exercise: ExerciseType.squat,
  kind: kind,
  target: target,
  baseline: 0,
  title: 'x',
  setAt: DateTime(2026, 11, 17),
  characterId: 'seal',
  fromMatch: 'r',
);

/// The app's auth with account 1 signed in.
Future<AuthViewModel> _signedIn() async {
  final repository = ScriptedAuthRepository();
  await repository.logIn(loginId: 'woohyun', password: 'pw');
  return AuthViewModel(repository: repository);
}

/// A goal store whose reads wait for [release].
class _SlowGoalStore extends MemoryGoalStore {
  final release = Completer<void>();

  @override
  Future<FeedbackGoal?> read(int accountId, ExerciseType exercise) async {
    await release.future;
    return super.read(accountId, exercise);
  }
}

void main() {
  late FakeUserRepository repository;

  // A tap that misses its target must fail here, not pass with nothing done.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  setUp(() {
    repository = FakeUserRepository()
      ..profile = const UserProfile(
        name: '우현',
        bests: {ExerciseType.pushUp: PersonalBest(reps: 24, score: 240)},
      );
  });

  /// The AI 1v1 page on home's loaded view model, with a stub matching page
  /// that shows its request.
  Future<HomeViewModel> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    GoalStore? goals,
    AuthViewModel? auth,
    CharacterViewModel? characters,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = HomeViewModel(repository: repository);
    addTearDown(vm.dispose);
    await vm.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: vm),
            if (goals != null) Provider<GoalStore>.value(value: goals),
            if (auth != null)
              ChangeNotifierProvider<AuthViewModel>.value(value: auth),
            if (characters != null)
              ChangeNotifierProvider<CharacterViewModel>.value(
                value: characters,
              ),
          ],
          child: const AiSetupScreen(),
        ),
        routes: {
          GymRatsApp.matchingRoute: (context) {
            final request =
                ModalRoute.of(context)!.settings.arguments! as BotMatchRequest;
            return Scaffold(
              body: Text('matching ${request.exercise} ${request.difficulty}'),
            );
          },
        },
      ),
    );
    return vm;
  }

  /// The option card around [text].
  Finder optionOf(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(Material)).first;

  /// Whether the option around [text] shows as chosen: an ink edge on the
  /// light lime fill, as designed.
  bool chosen(WidgetTester tester, String text) {
    final shape =
        tester.widget<Material>(optionOf(text)).shape!
            as RoundedRectangleBorder;
    return shape.side.color == AppColors.ink &&
        tester.widget<Material>(optionOf(text)).color == AppColors.selectedFill;
  }

  testWidgets('shows the exercises, the levels and the start button', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('PLAY / AI 1V1'), findsOneWidget);
    expect(find.text('RepBot과 겨룰 종목과 난이도를 골라요'), findsOneWidget);
    for (final text in ['종목', 'EXERCISE', '난이도', 'LEVEL', '푸쉬업', '스쿼트']) {
      expect(find.text(text), findsOneWidget);
    }
    for (final level in BotDifficulty.values) {
      expect(find.text(level.label), findsOneWidget);
      expect(find.text(level.summary), findsOneWidget);
    }
    // As designed: an ink button, white text and a lime arrow (a dark fill
    // takes light text, the exception in palette B).
    expect(find.byType(AccentButton), findsNothing);
    final start = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('대결 시작'),
        matching: find.byType(FilledButton),
      ),
    );
    const none = <WidgetState>{};
    expect(start.style!.backgroundColor!.resolve(none), AppColors.ink);
    // No edge, unlike the lime AccentButton.
    expect(
      (start.style!.shape!.resolve(none)! as RoundedRectangleBorder).side,
      BorderSide.none,
    );
    expect(
      tester.widget<Text>(find.text('대결 시작')).style!.color,
      AppColors.onInk,
    );
    final arrow = find.descendant(
      of: find.byWidget(start),
      matching: find.byIcon(Icons.arrow_forward_rounded),
    );
    expect(tester.widget<Icon>(arrow).color, AppColors.accent);
    expect(find.text('대결 시작'), findsOneWidget);
  });

  testWidgets('starts at push-ups against 중수, as designed', (tester) async {
    await open(tester);
    expect(chosen(tester, '푸쉬업'), isTrue);
    expect(chosen(tester, '스쿼트'), isFalse);
    expect(chosen(tester, '중수'), isTrue);
    expect(chosen(tester, '초보'), isFalse);
    expect(chosen(tester, '고수'), isFalse);
    expect(find.text('푸쉬업 · RepBot 중수 · 30초 대결'), findsOneWidget);
    // Only the chosen exercise carries the check.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets("each exercise shows the user's best, in points or reps", (
    tester,
  ) async {
    repository.profile = const UserProfile(
      name: '우현',
      bests: {
        ExerciseType.pushUp: PersonalBest(reps: 24, score: 240),
        ExerciseType.squat: PersonalBest(reps: 30),
      },
    );
    await open(tester);
    expect(find.text('최고 240점'), findsOneWidget);
    expect(find.text('최고 30회'), findsOneWidget);
  });

  testWidgets('a new user reads 기록 없음, not 0점', (tester) async {
    repository.profile = const UserProfile(name: '우현');
    await open(tester);
    expect(find.text('기록 없음'), findsNWidgets(2));
    expect(find.textContaining('0점'), findsNothing);
  });

  testWidgets('tapping an exercise and a level chooses them', (tester) async {
    final vm = await open(tester);
    await tester.tap(find.text('스쿼트'));
    await tester.tap(find.text('고수'));
    await tester.pump();
    expect(chosen(tester, '스쿼트'), isTrue);
    expect(chosen(tester, '푸쉬업'), isFalse);
    expect(chosen(tester, '고수'), isTrue);
    expect(chosen(tester, '중수'), isFalse);
    expect(find.text('스쿼트 · RepBot 고수 · 30초 대결'), findsOneWidget);
    expect(vm.state.botSetup.exercise, ExerciseType.squat);
    expect(vm.state.botSetup.difficulty, BotDifficulty.expert);
  });

  testWidgets('대결 시작 searches for the bot chosen', (tester) async {
    await open(tester);
    await tester.tap(find.text('스쿼트'));
    await tester.tap(find.text('초보'));
    await tester.pump();
    await tester.tap(find.text('대결 시작'));
    await tester.pumpAndSettle();
    expect(
      find.text('matching ${ExerciseType.squat} ${BotDifficulty.beginner}'),
      findsOneWidget,
    );
  });

  testWidgets('a stronger level lights more bars: pink with an ink edge, the '
      'rest gray outlines', (tester) async {
    await open(tester);
    List<BoxDecoration> barsOf(BotDifficulty level) => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: optionOf(level.label),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null && d.borderRadius == null)
        .toList();
    int lit(BotDifficulty level) =>
        barsOf(level).where((d) => d.color == AppColors.opponent).length;
    expect(BotDifficulty.values.map(lit), [1, 2, 3]);
    for (final bar in barsOf(BotDifficulty.beginner)) {
      final edge = (bar.border! as Border).top.color;
      expect(
        edge,
        bar.color == AppColors.opponent ? AppColors.ink : AppColors.line,
      );
    }
  });

  testWidgets('the tag is ink, as all text in palette B', (tester) async {
    await open(tester);
    expect(
      tester.widget<LobbyTag>(find.byType(LobbyTag)).color,
      AppColors.textPrimary,
    );
  });

  testWidgets('the chosen exercise carries a lime check chip with an ink '
      'check', (tester) async {
    await open(tester);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.check_rounded)).color,
      AppColors.ink,
    );
    expect(
      tester.widget<LobbyArrowChip>(find.byType(LobbyArrowChip)).color,
      AppColors.accent,
    );
  });

  testWidgets('a screen reader hears each option, and which is chosen', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('푸쉬업, 최고 240점')),
      matchesSemantics(
        label: '푸쉬업, 최고 240점',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('고수, 콤보가 많아요')),
      matchesSemantics(
        label: '고수, 콤보가 많아요',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
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
        find.text('대결 시작'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      expect(find.text('대결 시작').hitTestable(), findsOneWidget);
    });
  }

  group('the goal (A11 spec 3)', () {
    late AuthViewModel auth;
    late MemoryGoalStore store;

    setUp(() async {
      auth = await _signedIn();
      addTearDown(auth.dispose);
      store = MemoryGoalStore()..goals[(1, ExerciseType.squat)] = _squatGoal;
    });

    Finder sticker() => find.byType(GoalSticker);
    final rowLabel = find.text('이번 판 목표 · 물렁범과 정함');

    testWidgets('a sticker only on the exercise with a goal, over its top '
        'right corner, turned 6°; its best stays', (tester) async {
      await open(tester, goals: store, auth: auth);
      await tester.pump();
      expect(sticker(), findsOneWidget);
      expect(
        find.descendant(of: sticker(), matching: find.text('목표 20회')),
        findsOneWidget,
      );
      final card = tester.getRect(optionOf('스쿼트'));
      final frame = find.ancestor(
        of: sticker(),
        matching: find.byType(GoalStickerFrame),
      );
      expect(tester.getRect(frame), card);
      final sticking = tester.getRect(
        find.ancestor(of: sticker(), matching: find.byType(Positioned)).first,
      );
      expect(sticking.right, closeTo(card.right + 8, 0.01));
      expect(sticking.top, closeTo(card.top - 12, 0.01));
      final turn = tester.widget<Transform>(
        find.descendant(of: sticker(), matching: find.byType(Transform)).first,
      );
      expect(
        math.atan2(turn.transform.entry(1, 0), turn.transform.entry(0, 0)),
        closeTo(6 * math.pi / 180, 1e-6),
      );
      final pill = tester.widget<Container>(
        find.descendant(of: sticker(), matching: find.byType(Container)),
      );
      final look = pill.decoration! as BoxDecoration;
      expect(look.color, AppColors.accent);
      expect(look.border, Border.all(color: AppColors.ink, width: 2));
      // The card's own best is still there.
      expect(find.text('기록 없음'), findsOneWidget);
    });

    testWidgets('the goal row shows only for the chosen exercise with a goal, '
        'with the character it was set with, also after a change of '
        'character', (tester) async {
      final characters = CharacterViewModel(store: MemoryCharacterStore());
      await characters.load(1);
      await characters.choose('bear');
      await open(tester, goals: store, auth: auth, characters: characters);
      await tester.pump();
      // Push-ups are chosen and have no goal.
      expect(rowLabel, findsNothing);
      await tester.tap(optionOf('스쿼트'));
      await tester.pump();
      expect(rowLabel, findsOneWidget);
      expect(find.text('스쿼트 20회 인정받기'), findsOneWidget);
      expect(find.text('지난 18'), findsOneWidget);
      final face = tester.widget<CharacterFigure>(
        find.descendant(
          of: find.byKey(const ValueKey('goal-row-face')),
          matching: find.byType(CharacterFigure),
        ),
      );
      expect(face.characterId, 'seal');
      expect(face.scale, 0.62);
      expect(characters.characterId, 'bear');
      // Under the cards, 12 below them.
      final cards = tester.getRect(optionOf('스쿼트'));
      final row = tester.getRect(
        find.ancestor(of: rowLabel, matching: find.byType(Container)).first,
      );
      expect(row.top, closeTo(cards.bottom + 12, 0.01));
      expect(
        tester.getSize(find.byKey(const ValueKey('goal-row-face'))),
        const Size(46, 46),
      );
      await tester.tap(optionOf('푸쉬업'));
      await tester.pump();
      expect(rowLabel, findsNothing);
    });

    testWidgets('the line under 대결 시작 ends in the goal', (tester) async {
      final vm = await open(tester, goals: store, auth: auth);
      await tester.pump();
      vm.chooseBotExercise(ExerciseType.squat);
      await tester.pump();
      expect(find.text('스쿼트 · RepBot 중수 · 30초 대결 · 목표 20회'), findsOneWidget);
      vm.chooseBotExercise(ExerciseType.pushUp);
      await tester.pump();
      expect(find.text('푸쉬업 · RepBot 중수 · 30초 대결'), findsOneWidget);
    });

    test('the summary words of each kind', () {
      expect(AiSetupScreen.summaryGoal(null), '');
      expect(
        AiSetupScreen.summaryGoal(_goalOf(GoalKind.reps, 20)),
        ' · 목표 20회',
      );
      expect(
        AiSetupScreen.summaryGoal(_goalOf(GoalKind.lateReps, 8)),
        ' · 목표 후반 8회',
      );
      expect(
        AiSetupScreen.summaryGoal(_goalOf(GoalKind.combo, 5)),
        ' · 목표 콤보 5',
      );
      expect(
        AiSetupScreen.summaryGoal(_goalOf(GoalKind.maxRejects, 2)),
        ' · 목표 무효 2회 이하',
      );
    });

    testWidgets('a screen reader hears the goal with its exercise and on the '
        'row', (tester) async {
      final semantics = tester.ensureSemantics();
      final vm = await open(tester, goals: store, auth: auth);
      vm.chooseBotExercise(ExerciseType.squat);
      await tester.pump();
      expect(
        find.bySemanticsLabel('스쿼트, 기록 없음, 이번 판 목표 스쿼트 20회 인정받기'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('이번 판 목표 스쿼트 20회 인정받기, 물렁범과 정함, 지난 판 18'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('while the goals are read, the cards and what is under them '
        'wait hidden; they come with the row at once, read once', (
      tester,
    ) async {
      final slow = _SlowGoalStore()
        ..goals[(1, ExerciseType.squat)] = _squatGoal;
      final vm = await open(tester, goals: slow, auth: auth);
      vm.chooseBotExercise(ExerciseType.squat);
      await tester.pump();
      Opacity around(Finder finder) => tester.widget<Opacity>(
        find.ancestor(of: finder, matching: find.byType(Opacity)).first,
      );
      expect(around(find.text('대결 시작')).opacity, 0);
      expect(around(find.text('스쿼트')).opacity, 0);
      expect(rowLabel, findsNothing);
      // The header does not wait.
      expect(
        find.ancestor(of: find.text('AI 1v1'), matching: find.byType(Opacity)),
        findsNothing,
      );
      slow.release.complete();
      await tester.pump();
      await tester.pump();
      expect(rowLabel, findsOneWidget);
      expect(
        find.ancestor(of: find.text('대결 시작'), matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(find.text('대결 시작').hitTestable(), findsOneWidget);
    });

    testWidgets('a read slower than 300 ms shows the page without the goal; '
        'a goal that comes later stays away', (tester) async {
      final slow = _SlowGoalStore()
        ..goals[(1, ExerciseType.squat)] = _squatGoal;
      final vm = await open(tester, goals: slow, auth: auth);
      vm.chooseBotExercise(ExerciseType.squat);
      final hidden = find.ancestor(
        of: find.text('대결 시작'),
        matching: find.byType(Opacity),
      );
      await tester.pump(GoalsOnce.readLimit - const Duration(milliseconds: 1));
      expect(hidden, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(hidden, findsNothing);
      expect(find.text('대결 시작').hitTestable(), findsOneWidget);
      expect(sticker(), findsNothing);
      slow.release.complete();
      await tester.pump();
      await tester.pump();
      expect(sticker(), findsNothing);
      expect(rowLabel, findsNothing);
    });

    testWidgets('without a signed-in account nothing waits and nothing shows', (
      tester,
    ) async {
      await open(tester, goals: store);
      expect(sticker(), findsNothing);
      expect(
        find.ancestor(of: find.text('대결 시작'), matching: find.byType(Opacity)),
        findsNothing,
      );
    });

    group('with the app fonts', () {
      setUpAll(loadBattleFonts);

      /// Opens on squats, whose goal of [title] shows its row, on a 360 x 780
      /// phone with system bars of [bars].
      Future<ScrollPosition> openTall(
        WidgetTester tester,
        String title,
        FakeViewPadding bars,
      ) async {
        tester.view.padding = bars;
        tester.view.viewPadding = bars;
        store.goals[(1, ExerciseType.squat)] = FeedbackGoal(
          exercise: ExerciseType.squat,
          kind: GoalKind.lateReps,
          target: 10,
          baseline: 8,
          title: title,
          setAt: DateTime(2026, 11, 17),
          characterId: 'kangaroo',
          fromMatch: 'r',
        );
        final vm = await open(
          tester,
          size: const Size(360, 780),
          goals: store,
          auth: auth,
        );
        vm.chooseBotExercise(ExerciseType.squat);
        await tester.pump();
        return tester.state<ScrollableState>(find.byType(Scrollable)).position;
      }

      testWidgets('an exercise card is as tall as what it holds (decision 9): '
          'the name is measured on its one line', (tester) async {
        await openTall(
          tester,
          '스쿼트 20회 인정받기',
          const FakeViewPadding(top: 24, bottom: 24),
        );
        final card = tester.getRect(optionOf('푸쉬업'));
        final name = tester.getRect(find.text('푸쉬업'));
        // 12 under the name, as above the drawing.
        expect(card.bottom, closeTo(name.bottom + 12, 1));
        expect(card.height, lessThan(100));
        expect(
          tester.getSize(
            find
                .ancestor(of: find.text('초보'), matching: find.byType(Material))
                .first,
          ),
          const Size(320, 56),
        );
      });

      testWidgets('with three-button bars (24 / 48) the page scrolls about '
          '20 and every option is reached', (tester) async {
        final scroll = await openTall(
          tester,
          '스쿼트 20회 인정받기',
          const FakeViewPadding(top: 24, bottom: 48),
        );
        expect(tester.takeException(), isNull);
        expect(scroll.maxScrollExtent, lessThanOrEqualTo(24));
        await tester.dragUntilVisible(
          find.text('대결 시작'),
          find.byType(SingleChildScrollView),
          const Offset(0, -100),
        );
        expect(find.text('대결 시작').hitTestable(), findsOneWidget);
      });

      for (final (name, title) in [
        ('the design title', '스쿼트 20회 인정받기'),
        ('a long weak-point title', '후반 15초에 10회 이상'),
      ]) {
        testWidgets(
          'a 360 x 780 phone (S22) with gesture bars does not scroll with '
          'the goal row: $name',
          (tester) async {
            final scroll = await openTall(
              tester,
              title,
              const FakeViewPadding(top: 24, bottom: 24),
            );
            expect(find.text(title), findsOneWidget);
            expect(tester.takeException(), isNull);
            expect(scroll.maxScrollExtent, 0);
            // The title keeps to one line.
            final words = tester.getSize(find.text(title));
            expect(words.height, lessThan(22 * 1.2 * 1.5));
          },
        );
      }
    });
  });
}
