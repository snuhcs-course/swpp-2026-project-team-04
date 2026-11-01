import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/battle_screen.dart';
import 'package:gymrats_app/screens/matching_screen.dart';
import 'package:gymrats_app/screens/versus_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/battle_viewmodel.dart';
import 'package:gymrats_app/viewmodels/matching_viewmodel.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_score_panel.dart';
import 'package:gymrats_app/widgets/bot_difficulty_sheet.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/match_record_card.dart';
import 'package:gymrats_app/widgets/opponent_window.dart';

import '../support/fakes.dart';
import '../support/game_fakes.dart';
import '../support/placed_phone.dart';

/// Tests otherwise draw every letter as the same square, so only here does the
/// text have its real width. In its own file, as the fonts stay loaded for the
/// rest of the run.
Future<void> _loadAppFonts(WidgetTester tester) => tester.runAsync(() async {
  for (final entry in const {
    AppFonts.number: ['assets/fonts/Oxanium-Bold.ttf'],
    AppFonts.headline: ['assets/fonts/BlackHanSans-Regular.ttf'],
    AppFonts.body: [
      'assets/fonts/IBMPlexSansKR-Regular.ttf',
      'assets/fonts/IBMPlexSansKR-Medium.ttf',
      'assets/fonts/IBMPlexSansKR-Bold.ttf',
    ],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
});

void main() {
  /// What the sheet answered; null until it closes, and after closing with no
  /// choice.
  BotDifficulty? answer;
  var answered = false;

  void setWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Opens the sheet from a page with one button.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    ExerciseType exercise = ExerciseType.pushUp,
  }) async {
    await _loadAppFonts(tester);
    setWindow(tester, size);
    answer = null;
    answered = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                answer = await showBotDifficultySheet(
                  context,
                  exercise: exercise,
                );
                answered = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool truncated(WidgetTester tester, Finder text) =>
      tester.renderObject<RenderParagraph>(text).didExceedMaxLines;

  testWidgets('shows a card for each level: name, reps and one line', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('어떤 봇과 붙어볼까요?'), findsOneWidget);
    expect(find.text('푸쉬업 · 30초 · 1v1'), findsOneWidget);
    expect(find.byType(BotDifficultyPicture), findsNWidgets(3));
    for (final (name, reps, line) in const [
      ('초보', '5~7', '실수가 잦아요'),
      ('중수', '8~10', '가끔 콤보'),
      ('고수', '10~14', '콤보가 많아요'),
    ]) {
      expect(find.text(name), findsOneWidget);
      expect(find.text(reps), findsOneWidget);
      expect(find.text(line), findsOneWidget);
    }
  });

  testWidgets('its cards read from the easiest, left to right', (tester) async {
    await open(tester);
    final left = [
      for (final name in const ['초보', '중수', '고수'])
        tester.getCenter(find.text(name)).dx,
    ];
    expect(left, orderedEquals([...left]..sort()));
    expect(left.toSet(), hasLength(3));
  });

  testWidgets('the sheet names the exercise it was opened for', (tester) async {
    await open(tester, exercise: ExerciseType.squat);
    expect(find.text('스쿼트 · 30초 · 1v1'), findsOneWidget);
  });

  for (final level in BotDifficulty.values) {
    testWidgets('tapping ${level.label} closes the sheet with it', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text(level.label));
      await tester.pumpAndSettle();
      expect(answered, isTrue);
      expect(answer, level);
      expect(find.byType(BotDifficultySheet), findsNothing);
    });

    testWidgets('all of the ${level.label} card is the tap target', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is BotDifficultyPicture && widget.level == level,
        ),
      );
      await tester.pumpAndSettle();
      expect(answer, level);
    });

    testWidgets('a screen reader hears the ${level.label} card whole, and can '
        'choose it', (tester) async {
      await open(tester);
      final handle = tester.ensureSemantics();
      final reps = level.validRange(battleDuration);
      final card = find.bySemanticsLabel(
        '${level.label}, 30초에 $reps회, ${level.summary}',
      );
      expect(
        tester.getSemantics(card),
        matchesSemantics(
          label: '${level.label}, 30초에 $reps회, ${level.summary}',
          isButton: true,
          hasTapAction: true,
        ),
      );
      tester
          .getSemantics(card)
          .owner!
          .performAction(tester.getSemantics(card).id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(answer, level);
      handle.dispose();
    });
  }

  testWidgets('tapping outside closes the sheet with no answer', (
    tester,
  ) async {
    await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(answered, isTrue);
    expect(answer, isNull);
    expect(find.byType(BotDifficultySheet), findsNothing);
  });

  testWidgets('back closes the sheet with no answer', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(answered, isTrue);
    expect(answer, isNull);
  });

  testWidgets('at 360 wide, every text fits on one line at its full size', (
    tester,
  ) async {
    await open(tester);
    expect(tester.takeException(), isNull);
    final texts = find.descendant(
      of: find.byType(BotDifficultySheet),
      matching: find.byType(Text),
    );
    expect(texts, findsNWidgets(11));
    for (final element in texts.evaluate()) {
      final text = find.byWidget(element.widget);
      final size = tester.getSize(text);
      final style = tester.renderObject<RenderParagraph>(text).text.style;
      final lineHeight = style!.fontSize! * (style.height ?? 1.5);
      expect(truncated(tester, text), isFalse, reason: '${element.widget}');
      expect(
        size.height,
        lessThan(lineHeight * 1.2),
        reason: '${element.widget}',
      );
      // A FittedBox that had to shrink it would draw it narrower than this.
      expect(
        tester.getRect(text).width,
        closeTo(size.width, 0.01),
        reason: '${element.widget}',
      );
    }
  });

  for (final size in const [Size(360, 640), Size(360, 780), Size(320, 568)]) {
    for (final scale in const [1.0, 1.3, 1.5, 2.0]) {
      testWidgets('fits with no overflow at ${size.width.toInt()}x'
          '${size.height.toInt()}, text scale $scale', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await open(tester, size: size);
        expect(tester.takeException(), isNull);
        // Cards keep one height, whatever their text does.
        final cards = find.descendant(
          of: find.byType(BotDifficultySheet),
          matching: find.byType(Card),
        );
        final heights = {
          for (final card in cards.evaluate())
            tester.getSize(find.byWidget(card.widget)).height,
        };
        expect(heights, hasLength(1));
        // A card can be reached and tapped, also when the sheet has to scroll.
        await tester.ensureVisible(find.text('고수'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('고수'));
        await tester.pumpAndSettle();
        expect(answer, BotDifficulty.expert);
      });
    }
  }

  group('the pictures', () {
    /// Paints [level]'s picture alone and returns its RGBA bytes.
    Future<List<int>> pixels(WidgetTester tester, BotDifficulty level) async {
      final boundary = GlobalKey();
      setWindow(tester, const Size(360, 780));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: boundary,
              child: BotDifficultyPicture(level),
            ),
          ),
        ),
      );
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      final image = (await tester.runAsync(render.toImage))!;
      final bytes = (await tester.runAsync(image.toByteData))!;
      image.dispose();
      return bytes.buffer.asUint8List();
    }

    int painted(List<int> rgba) {
      var count = 0;
      for (var i = 3; i < rgba.length; i += 4) {
        if (rgba[i] > 0) count++;
      }
      return count;
    }

    int alphaAt(List<int> rgba, int x, int y) =>
        rgba[(y * BotDifficultyPicture.designSize.width.toInt() + x) * 4 + 3];

    testWidgets('a stronger level draws more', (tester) async {
      final beginner = painted(await pixels(tester, BotDifficulty.beginner));
      final middle = painted(await pixels(tester, BotDifficulty.intermediate));
      final expert = painted(await pixels(tester, BotDifficulty.expert));
      expect(beginner, greaterThan(0));
      expect(beginner, lessThan(middle));
      expect(middle, lessThan(expert));
    });

    testWidgets('a stronger level draws the same robot in a stronger pink', (
      tester,
    ) async {
      // The middle of the robot's bottom line.
      int robot(List<int> rgba) => alphaAt(rgba, 36, 47);
      final beginner = robot(await pixels(tester, BotDifficulty.beginner));
      final middle = robot(await pixels(tester, BotDifficulty.intermediate));
      final expert = robot(await pixels(tester, BotDifficulty.expert));
      expect(beginner, closeTo(0.7 * 255, 2));
      expect(middle, closeTo(0.85 * 255, 2));
      expect(expert, 255);
    });

    testWidgets("the robot's color is the opponent's pink", (tester) async {
      final rgba = await pixels(tester, BotDifficulty.expert);
      final at = (47 * BotDifficultyPicture.designSize.width.toInt() + 36) * 4;
      expect(rgba.sublist(at, at + 3), [
        (AppColors.opponent.r * 255).round(),
        (AppColors.opponent.g * 255).round(),
        (AppColors.opponent.b * 255).round(),
      ]);
    });

    testWidgets('only the upper levels have lines at the sides', (
      tester,
    ) async {
      // On the inner line's bulge, left and right.
      bool hasInner(List<int> rgba) =>
          alphaAt(rgba, 10, 36) > 0 && alphaAt(rgba, 61, 36) > 0;
      // On the outer line's bulge, left and right.
      bool hasOuter(List<int> rgba) =>
          alphaAt(rgba, 2, 36) > 0 && alphaAt(rgba, 69, 36) > 0;
      final beginner = await pixels(tester, BotDifficulty.beginner);
      final middle = await pixels(tester, BotDifficulty.intermediate);
      final expert = await pixels(tester, BotDifficulty.expert);
      expect(hasInner(beginner), isFalse);
      expect(hasOuter(beginner), isFalse);
      expect(hasInner(middle), isTrue);
      expect(hasOuter(middle), isFalse);
      expect(hasInner(expert), isTrue);
      expect(hasOuter(expert), isTrue);
    });

    testWidgets('only the expert has a star', (tester) async {
      // Near the star's top point, above the other levels' antenna.
      bool hasStar(List<int> rgba) => alphaAt(rgba, 36, 6) > 0;
      expect(hasStar(await pixels(tester, BotDifficulty.beginner)), isFalse);
      expect(
        hasStar(await pixels(tester, BotDifficulty.intermediate)),
        isFalse,
      );
      expect(hasStar(await pixels(tester, BotDifficulty.expert)), isTrue);
    });
  });

  group("the level's name with the real fonts, at 360 wide", () {
    final matchup = Matchup(
      exercise: ExerciseType.pushUp,
      playerName: '우현',
      opponent: const Opponent(
        name: 'RepBot',
        isBot: true,
      ).at(BotDifficulty.beginner),
    );
    const name = 'AI 봇 · 초보';

    testWidgets('fits on the versus screen', (tester) async {
      await _loadAppFonts(tester);
      setWindow(tester, const Size(360, 780));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: VersusScreen(matchup: matchup),
        ),
      );
      await tester.pump();
      expect(truncated(tester, find.text(name)), isFalse);
      expect(tester.takeException(), isNull);
    });

    /// Opens the battle, at a text scale of [scale].
    Future<void> openBattle(WidgetTester tester, double scale) async {
      await _loadAppFonts(tester);
      setWindow(tester, const Size(360, 780));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BattleScreen(
            matchup: matchup,
            createViewModel: () => BattleViewModel(
              matchup: matchup,
              counter: RepCounterViewModel(
                camera: FakeCameraService(),
                estimator: FakePoseEstimator(),
                judge: DepthRepJudge(),
                phoneTilt: placedPhone(),
                clock: () => Duration.zero,
                roundLength: battleDuration,
              ),
              opponent: TimedOpponentSource(),
              repository: FakeUserRepository(),
              sound: FakeRepSound(),
              now: () => DateTime(2026, 11, 1),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Finder nameIn(Type place) =>
        find.descendant(of: find.byType(place), matching: find.text(name));

    testWidgets('fits on the scoreboard and in the opponent window', (
      tester,
    ) async {
      await openBattle(tester, 1);
      expect(truncated(tester, nameIn(BattleScorePanel)), isFalse);
      expect(truncated(tester, nameIn(OpponentWindow)), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the scoreboard still shows it whole at text scale 1.3', (
      tester,
    ) async {
      await openBattle(tester, 1.3);
      expect(truncated(tester, nameIn(BattleScorePanel)), isFalse);
      expect(tester.takeException(), isNull);
    });

    /// How many lines [text] takes, from its height and its style.
    double linesOf(WidgetTester tester, Finder text) {
      final style = tester.renderObject<RenderParagraph>(text).text.style!;
      final lineHeight = style.fontSize! * (style.height ?? 1.5);
      return tester.getSize(text).height / lineHeight;
    }

    testWidgets('the matching title stays on one line', (tester) async {
      await _loadAppFonts(tester);
      setWindow(tester, const Size(360, 780));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MatchingScreen(
            exercise: ExerciseType.pushUp,
            difficulty: BotDifficulty.beginner,
            createViewModel: () => MatchingViewModel(
              matchmaker: FakeMatchmaker()..gate = Completer(),
              repository: FakeUserRepository(),
              exercise: ExerciseType.pushUp,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(linesOf(tester, find.text('초보 AI 상대를 찾는 중')), lessThan(1.2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets("the leave dialog keeps its message's two lines", (
      tester,
    ) async {
      await _loadAppFonts(tester);
      setWindow(tester, const Size(360, 780));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: ExitDialog.game(opponentName: name)),
        ),
      );
      expect(
        linesOf(tester, find.text('$name와의 대결이 취소되고\n홈으로 돌아가요.')),
        lessThan(2.2),
      );
    });

    testWidgets('shows whole in the history card', (tester) async {
      await _loadAppFonts(tester);
      setWindow(tester, const Size(360, 780));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: MatchRecordCard(
              match: MatchRecord(
                exercise: ExerciseType.pushUp,
                opponentName: name,
                myReps: 12,
                opponentReps: 6,
              ),
            ),
          ),
        ),
      );
      final line = find.text('푸쉬업 · vs $name');
      expect(line, findsOneWidget);
      expect(truncated(tester, line), isFalse);
    });
  });
}
