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

import '../support/fakes.dart';

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
        home: ChangeNotifierProvider.value(
          value: vm,
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
    // The design's dark start button, not the lime AccentButton.
    expect(find.byType(AccentButton), findsNothing);
    final start = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('대결 시작'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      start.style!.backgroundColor!.resolve(const <WidgetState>{}),
      AppColors.ink,
    );
    expect(
      tester.widget<Text>(find.text('대결 시작')).style!.color,
      AppColors.onInk,
    );
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

  testWidgets('a stronger level shows more pink bars', (tester) async {
    await open(tester);
    int pinkBars(BotDifficulty level) => tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: optionOf(level.label),
            matching: find.byType(ColoredBox),
          ),
        )
        .where((box) => box.color == AppColors.opponent)
        .length;
    expect(BotDifficulty.values.map(pinkBars), [1, 2, 3]);
  });

  testWidgets('the tag is dark pink, as the bot is, and readable', (
    tester,
  ) async {
    await open(tester);
    expect(
      tester.widget<LobbyTag>(find.byType(LobbyTag)).color,
      AppColors.opponentText,
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
}
