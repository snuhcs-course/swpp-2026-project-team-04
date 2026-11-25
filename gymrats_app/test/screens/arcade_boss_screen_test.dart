import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_progress.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/arcade_boss_screen.dart';
import 'package:gymrats_app/screens/arcade_result_screen.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/services/arcade/arcade_star_judge.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/arcade_viewmodel.dart';
import 'package:gymrats_app/widgets/arcade_parts.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/gym_owner_figure.dart';
import 'package:provider/provider.dart';

final _stage = ArcadeCatalog.stage(6) as ArcadeBossStage;

/// The four corners of [words] where they are painted, their slant and any
/// shrinking included.
List<Offset> _paintedCorners(WidgetTester tester, Finder words) {
  final box = tester.renderObject<RenderBox>(words);
  final size = box.size;
  return [
    for (final corner in [
      Offset.zero,
      size.topRight(Offset.zero),
      size.bottomLeft(Offset.zero),
      size.bottomRight(Offset.zero),
    ])
      box.localToGlobal(corner),
  ];
}

/// How much [words] are shrunk where they are painted: 1 at their own size.
double _wordsScale(WidgetTester tester, Finder words) {
  final corners = _paintedCorners(tester, words);
  return (corners[1] - corners[0]).distance /
      tester.renderObject<RenderBox>(words).size.width;
}

/// Checks that [label]'s words are painted inside their button, its round
/// corners included: the slanted words are a parallelogram, so it is inside
/// when its four corners are.
void _expectWordsInside(WidgetTester tester, String label) {
  final words = find.text(label);
  final button = tester.getRect(
    find.ancestor(of: words, matching: find.byType(InkWell)).first,
  );
  final shape = RRect.fromRectAndRadius(
    button,
    const Radius.circular(ArcadeDarkButton.radius),
  );
  for (final corner in _paintedCorners(tester, words)) {
    expect(
      shape.contains(corner),
      isTrue,
      reason: '$label painted at $corner, its button $button',
    );
  }
}

void main() {
  late ArcadeViewModel arcade;

  /// A stand-in map, and the boss screen over it ([first] for the break).
  Future<void> open(
    WidgetTester tester, {
    BattleResult? first,
    int best = 0,
    Size size = const Size(360, 780),
    double textScale = 1,
  }) async {
    // A second open in one test starts from nothing.
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final store = MemoryArcadeProgressStore()
      ..saved[1] = ArcadeProgress([
        for (var i = 1; i <= 24; i++) i < 6 ? 1 : (i == 6 ? best : 0),
      ]);
    arcade = ArcadeViewModel(store: store);
    addTearDown(arcade.dispose);
    await arcade.load(1);
    if (first != null) {
      arcade.wonFirstRound(
        _stage,
        first,
        const ArcadeRound(
          won: true,
          wonByKo: false,
          rejects: 0,
          longestCombo: 0,
          excellent: 0,
        ),
      );
    }
    await tester.pumpWidget(
      ChangeNotifierProvider<ArcadeViewModel>.value(
        value: arcade,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, GymRatsApp.arcadeRoute),
                child: const Text('below'),
              ),
            ),
          ),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => settings.name == GymRatsApp.arcadeRoute
                ? Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        ArcadeBossScreen.route(stage: _stage, first: first),
                      ),
                      child: const Text('map'),
                    ),
                  )
                : Scaffold(
                    body: Text(
                      '${settings.name} '
                      '${(settings.arguments! as Matchup).opponent.name}',
                    ),
                  ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('below'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('map'));
    await tester.pumpAndSettle();
  }

  BattleResult firstRound() => BattleResult(
    matchup: ArcadeMatchups.boss(_stage, 1, playerName: '우현'),
    myReps: 14,
    myInvalidReps: 0,
    opponentReps: 9,
    myScore: 165,
    opponentScore: 120,
    decidedOutcome: MatchOutcome.win,
    endedAt: DateTime(2026, 11, 23),
  );

  group('the intro (P16Boss intro)', () {
    testWidgets('shows the owner, the two rounds and the star conditions', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('STAGE 6 · 1F BOSS'), findsOneWidget);
      expect(find.text('보스 매치'), findsOneWidget);
      expect(find.text('BOSS'), findsOneWidget);
      expect(find.text('물렁범'), findsOneWidget);
      expect(find.text('1F 체육관 관장'), findsOneWidget);
      expect(find.text('AI LV 4'), findsOneWidget);
      expect(find.text('ROUND 1'), findsOneWidget);
      expect(find.text('ROUND 2'), findsOneWidget);
      expect(find.text('푸쉬업'), findsOneWidget);
      expect(find.text('스쿼트'), findsOneWidget);
      expect(find.text('30초'), findsNWidgets(2));
      for (final star in _stage.stars) {
        expect(find.text(star.label), findsOneWidget);
      }
      expect(find.text('자세 잡기'), findsOneWidget);
      // The owner in goggles, facing left.
      expect(
        tester
            .widgetList<GymOwnerFigure>(find.byType(GymOwnerFigure))
            .map((owner) => owner.ownerId)
            .toSet(),
        {'seal'},
      );
    });

    testWidgets('a best of 2 from two KO wins without the second condition: '
        'no condition reads as got; the best on a line of its own (PR #91 '
        'review)', (tester) async {
      await open(tester, best: 2);
      expect(find.text('최고 기록: 별 2/3'), findsOneWidget);
      expect(find.bySemanticsLabel('최고 기록, 별 3개 중 2개'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('받음')), findsNothing);
      expect(
        find.bySemanticsLabel('두 번째 별, ${_stage.stars[1].label}'),
        findsOneWidget,
      );
    });

    testWidgets('never cleared: no best line (PR #91 review)', (tester) async {
      await open(tester);
      expect(find.textContaining('최고 기록'), findsNothing);
    });

    testWidgets('자세 잡기 opens R1\'s setup and battle in its place', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('자세 잡기'));
      await tester.pumpAndSettle();
      expect(find.text('/battle STAGE 6 R1 · 물렁범'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('map'), findsOneWidget);
    });

    testWidgets('back returns to the map', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('지도로'));
      await tester.pumpAndSettle();
      expect(find.text('map'), findsOneWidget);
    });
  });

  group('the break (P16Boss break)', () {
    testWidgets('R1 won: its score, R2 next, no rest timer', (tester) async {
      await open(tester, first: firstRound());
      expect(find.text('STAGE 6 · 1F BOSS'), findsOneWidget);
      expect(find.text('1라운드 승리!'), findsOneWidget);
      expect(find.bySemanticsLabel('내 점수 165, 상대 점수 120'), findsOneWidget);
      expect(find.bySemanticsLabel('라운드 진행, 1라운드 승리, 다음 2라운드'), findsOne);
      expect(find.text('R2'), findsOneWidget);
      expect(find.text('NEXT · ROUND 2'), findsOneWidget);
      expect(find.text('스쿼트 30초'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d+초 후')), findsNothing);
      // The owner as a fighter, hit.
      expect(
        tester
            .widgetList<CharacterFigure>(find.byType(CharacterFigure))
            .map((figure) => (figure.characterId, figure.pose))
            .toSet(),
        {('seal', BattlePose.hit)},
      );
    });

    testWidgets('자세 잡기 opens R2\'s setup and battle', (tester) async {
      await open(tester, first: firstRound());
      await tester.tap(find.text('자세 잡기'));
      await tester.pumpAndSettle();
      expect(find.text('/battle STAGE 6 R2 · 물렁범'), findsOneWidget);
      expect(arcade.bossRun, isNotNull);
    });

    testWidgets('그만하기 and back end the match: the map, no stars', (
      tester,
    ) async {
      await open(tester, first: firstRound());
      await tester.tap(find.text('그만하기'));
      await tester.pumpAndSettle();
      expect(find.text('map'), findsOneWidget);
      expect(arcade.bossRun, isNull);

      await open(tester, first: firstRound());
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('map'), findsOneWidget);
      expect(arcade.bossRun, isNull);
      expect(arcade.progress!.bestOf(6), 0);
    });

    testWidgets('the round progress is drawn with the check glyph', (
      tester,
    ) async {
      await open(tester, first: firstRound());
      expect(
        tester
            .widgetList<ArcadeGlyphIcon>(find.byType(ArcadeGlyphIcon))
            .where((icon) => icon.glyph == ArcadeGlyph.check),
        hasLength(1),
      );
    });
  });

  for (final (label, size, scale) in [
    ('a short phone', const Size(360, 640), 1.0),
    ('a large text size', const Size(360, 780), 1.3),
  ]) {
    testWidgets('fits $label without overflow, scrolling to its buttons', (
      tester,
    ) async {
      await open(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('자세 잡기'));
      await tester.pump();
      expect(find.text('자세 잡기').hitTestable(), findsOneWidget);

      await open(tester, first: firstRound(), size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('그만하기'));
      await tester.pump();
      expect(find.text('그만하기').hitTestable(), findsOneWidget);
      expect(find.text('자세 잡기').hitTestable(), findsOneWidget);
    });
  }

  /// The floor cleared after the break (`ArcResult` floor): R1 and R2 won.
  Future<void> openFloorCleared(
    WidgetTester tester, {
    required Size size,
    required double textScale,
  }) async {
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final arcade = ArcadeViewModel(store: MemoryArcadeProgressStore());
    addTearDown(arcade.dispose);
    final second = BattleResult(
      matchup: ArcadeMatchups.boss(_stage, 2, playerName: '우현'),
      myReps: 15,
      myInvalidReps: 0,
      opponentReps: 10,
      myScore: 170,
      opponentScore: 130,
      decidedOutcome: MatchOutcome.win,
      endedAt: DateTime(2026, 11, 23),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<ArcadeViewModel>.value(
        value: arcade,
        child: MaterialApp(
          theme: AppTheme.light,
          home: ArcadeResultScreen(
            stage: _stage,
            rounds: [firstRound(), second],
            stars: const ArcadeStars(true, false, false),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // The design's phone with its own text size and with 1.3x text, and a
  // 320-wide phone with both.
  for (final (size, scale) in [
    (const Size(360, 780), 1.0),
    (const Size(360, 780), 1.3),
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 1.3),
  ]) {
    final where =
        '${size.width.toInt()} x ${size.height.toInt()} with ${scale}x text';
    testWidgets('on $where every button keeps its words inside it: the '
        'intro, the break and the floor cleared', (tester) async {
      Future<void> check(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        _expectWordsInside(tester, label);
      }

      await open(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      await check('자세 잡기');

      await open(tester, first: firstRound(), size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      await check('자세 잡기');
      await check('그만하기');

      await openFloorCleared(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('1층 클리어!'), findsOneWidget);
      await check('2층으로');
      await check('리포트 보기');
    });
  }

  testWidgets('the break\'s 자세 잡기 is the intro\'s button: as wide as the '
      'screen\'s content, 58 high, its words at full size', (tester) async {
    await open(tester);
    final intro = tester.getRect(find.byType(ArcadeDarkButton));
    await open(tester, first: firstRound());
    final breakButton = tester.getRect(find.byType(ArcadeDarkButton));
    // 360 less the design's 20 on each side.
    expect(intro.width, 320);
    expect(breakButton.width, 320);
    expect(breakButton.height, 58);
    expect(breakButton.left, 20);
    expect(_wordsScale(tester, find.text('자세 잡기')), closeTo(1, 1e-9));
  });

  testWidgets('every button is big enough and has a name', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await open(tester, first: firstRound());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
