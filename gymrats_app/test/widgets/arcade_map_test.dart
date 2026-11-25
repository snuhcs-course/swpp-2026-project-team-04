import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_progress.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/arcade_map.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/gym_background.dart';

ArcadeProgress _progress(List<int> first) =>
    ArcadeProgress([...first, for (var i = first.length; i < 24; i++) 0]);

/// Stages 1 to 7 played: STAGE 8 to play, as the design's `cur`.
final _atStage8 = _progress([3, 2, 3, 3, 3, 2, 1]);
final _allCleared = ArcadeProgress(List.filled(24, 2));

void main() {
  group('ArcadeMapLayout (design ArcMap, look m3)', () {
    test('5F 공사중 on top, 250 high; each floor 390 with a 46 band', () {
      expect(ArcadeMapLayout.top(5), 0);
      expect(ArcadeMapLayout.band(5), 250);
      expect(ArcadeMapLayout.top(4), 296);
      expect(ArcadeMapLayout.band(4), 686);
      expect(ArcadeMapLayout.top(1), 1604);
      expect(ArcadeMapLayout.band(1), 1994);
      expect(ArcadeMapLayout.height, 2040);
    });

    test('the stages stand on their floor\'s six places', () {
      expect(
        ArcadeMapLayout.center(ArcadeCatalog.stage(1)),
        const Offset(84, 1604 + 340),
      );
      expect(
        ArcadeMapLayout.center(ArcadeCatalog.stage(6)),
        const Offset(176, 1604 + 82),
      );
      expect(
        ArcadeMapLayout.center(ArcadeCatalog.stage(8)),
        const Offset(200, 1168 + 302),
      );
      expect(
        ArcadeMapLayout.center(ArcadeCatalog.stage(24)),
        const Offset(176, 296 + 82),
      );
    });

    test('cells: a boss match 70, the stage to play 64, any other 54', () {
      final boss = ArcadeCatalog.stage(6);
      final fight = ArcadeCatalog.stage(8);
      expect(ArcadeMapLayout.cellSize(boss, current: false), 70);
      expect(ArcadeMapLayout.cellSize(boss, current: true), 70);
      expect(ArcadeMapLayout.cellSize(fight, current: true), 64);
      expect(ArcadeMapLayout.cellSize(fight, current: false), 54);
      expect(ArcadeMapLayout.faceScale(70), 0.64);
      expect(ArcadeMapLayout.faceScale(64), 0.6);
      expect(ArcadeMapLayout.faceScale(54), 0.5);
    });

    test('the first scroll puts the stage in the middle, on the map; all '
        'cleared, the top (spec 4)', () {
      final stage8 = ArcadeCatalog.stage(8);
      expect(ArcadeMapLayout.scrollFor(stage8, 600), 1470 - 300);
      // Stage 1 is near the bottom: the scroll stops at the map's end.
      expect(
        ArcadeMapLayout.scrollFor(ArcadeCatalog.stage(1), 600),
        ArcadeMapLayout.height - 600,
      );
      expect(ArcadeMapLayout.scrollFor(null, 600), 0);
    });

    test('the marked stage is the one to play, or 24 once all are cleared', () {
      expect(arcadeMarkedStage(_atStage8).number, 8);
      expect(arcadeMarkedStage(ArcadeProgress.initial()).number, 1);
      expect(arcadeMarkedStage(_allCleared).number, 24);
    });
  });

  group('ArcadeMap', () {
    late List<int> tapped;
    late ScrollController scroll;

    setUp(() {
      tapped = [];
      scroll = ScrollController();
    });

    tearDown(() => scroll.dispose());

    Future<void> show(WidgetTester tester, ArcadeProgress progress) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: ArcadeMap(
                progress: progress,
                myCharacter: 'kangaroo',
                width: 360,
                scroll: scroll,
                onStage: (stage) => tapped.add(stage.number),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder cell(String label) => find.bySemanticsLabel(label);

    testWidgets('a new account: only STAGE 1 is open, and it is the one to '
        'play', (tester) async {
      await show(tester, ArcadeProgress.initial());
      expect(cell('STAGE 1, RepBot · 푸쉬업, 별 0개, 지금 판'), findsOneWidget);
      expect(cell('STAGE 2, 잠김'), findsOneWidget);
      expect(cell('STAGE 24, 잠김'), findsOneWidget);
    });

    testWidgets('STAGE 8: 1 to 7 with their stars, 3F and 4F locked (spec '
        '12)', (tester) async {
      await show(tester, _atStage8);
      expect(cell('STAGE 3, 물렁범 · 하이 플랭크, 별 3개'), findsOneWidget);
      expect(cell('STAGE 6, 보스 매치 · 물렁범, 별 2개'), findsOneWidget);
      expect(cell('STAGE 7, 그루 · 푸쉬업, 별 1개'), findsOneWidget);
      expect(cell('STAGE 8, 물렁범 · 스쿼트, 별 0개, 지금 판'), findsOneWidget);
      expect(cell('STAGE 9, 잠김'), findsOneWidget);
      expect(find.bySemanticsLabel('1F 동네 체육관'), findsOneWidget);
      expect(find.bySemanticsLabel('2F 시립 체육관'), findsOneWidget);
      expect(find.bySemanticsLabel('3F 복싱장, 잠김'), findsOneWidget);
      expect(find.bySemanticsLabel('4F 국가대표 훈련장, 잠김'), findsOneWidget);
      // The rules on the bands, grey on a locked floor.
      expect(find.text('피버 15초부터'), findsOneWidget);
      expect(find.text('콤보 보너스 2배'), findsOneWidget);
      expect(find.text('Excellent 2배'), findsOneWidget);
    });

    testWidgets('5F 공사중 is on top from the start (spec 13.2)', (tester) async {
      await show(tester, ArcadeProgress.initial());
      expect(find.bySemanticsLabel('5F 공사중'), findsOneWidget);
      // The band's name and the sign on its picture.
      expect(find.text('공사중'), findsNWidgets(2));
    });

    testWidgets('each built floor shows its gym; locked ones grey', (
      tester,
    ) async {
      await show(tester, _atStage8);
      final floors = tester
          .widgetList<GymBackground>(find.byType(GymBackground))
          .map((background) => background.floor)
          .toList();
      expect(floors, [4, 3, 2, 1]);
      expect(
        find.ancestor(
          of: find.byWidgetPredicate(
            (w) => w is GymBackground && w.floor == 3,
          ),
          matching: find.byType(ColorFiltered),
        ),
        findsWidgets,
      );
      expect(
        find.ancestor(
          of: find.byWidgetPredicate(
            (w) => w is GymBackground && w.floor == 2,
          ),
          matching: find.byType(ColorFiltered),
        ),
        findsNothing,
      );
    });

    testWidgets('open stages answer a tap (played ones too); locked ones do '
        'not (spec 4)', (tester) async {
      await show(tester, _atStage8);
      for (final number in [8, 3, 9, 24]) {
        final finder = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.startsWith('STAGE $number,') ?? false),
        );
        await tester.ensureVisible(finder);
        await tester.pump();
        await tester.tap(finder, warnIfMissed: false);
        await tester.pump();
      }
      expect(tapped, [8, 3]);
    });

    testWidgets('the user stands by the stage to play, idling; after all 24, '
        'celebrating by STAGE 24', (tester) async {
      await show(tester, _atStage8);
      expect(find.text('나'), findsOneWidget);
      expect(
        tester
            .widgetList<CharacterIdleFigure>(find.byType(CharacterIdleFigure))
            .map((figure) => figure.characterId)
            .toSet(),
        {'kangaroo'},
      );

      await show(tester, _allCleared);
      expect(find.byType(CharacterIdleFigure), findsNothing);
      expect(
        tester
            .widgetList<CharacterFigure>(find.byType(CharacterFigure))
            .where((figure) => figure.pose == BattlePose.win)
            .map((figure) => figure.characterId)
            .toSet(),
        {'kangaroo'},
      );
      expect(
        find.bySemanticsLabel('STAGE 24, 보스 매치 · 곰탱이, 별 2개'),
        findsOneWidget,
      );
    });

    testWidgets('a floor\'s tag shows while its band is out of view', (
      tester,
    ) async {
      await show(tester, ArcadeProgress.initial());
      // At the top every built floor's band is out of a 600 high view.
      for (final floor in ['1F', '2F', '3F', '4F']) {
        expect(find.text(floor), findsNWidgets(2), reason: floor);
      }
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      // At the bottom 1F's band shows, so its tag does not.
      expect(find.text('1F'), findsOneWidget);
      expect(find.text('4F'), findsNWidgets(2));
    });

    testWidgets('a hold stage shows its owner in goggles, a fight its '
        'opponent', (tester) async {
      await show(tester, _atStage8);
      final hold = ArcadeCatalog.stage(3) as ArcadeHoldStage;
      expect(hold.character, 'seal');
      expect(find.text('HOLD'), findsNWidgets(8));
      expect(find.text('BOSS'), findsNWidgets(4));
    });
  });
}
