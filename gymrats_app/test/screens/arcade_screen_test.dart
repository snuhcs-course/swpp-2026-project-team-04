import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_progress.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/arcade_boss_screen.dart';
import 'package:gymrats_app/screens/arcade_screen.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/arcade_viewmodel.dart';
import 'package:gymrats_app/widgets/arcade_map.dart';
import 'package:gymrats_app/widgets/arcade_stage_sheet.dart';
import 'package:provider/provider.dart';

ArcadeProgress _progress(List<int> first) =>
    ArcadeProgress([...first, for (var i = first.length; i < 24; i++) 0]);

/// The design's `cur`: stages 1 to 7 played, 17 stars.
final _atStage8 = _progress([3, 2, 3, 3, 3, 2, 1]);

/// A store whose first read waits until [release].
class _WaitingStore extends MemoryArcadeProgressStore {
  final gate = Completer<void>();

  @override
  Future<ArcadeProgress> read(int accountId) async {
    await gate.future;
    return super.read(accountId);
  }
}

void main() {
  late MemoryArcadeProgressStore store;
  late ArcadeViewModel arcade;
  late List<ArcadeHoldStage> holds;

  setUp(() {
    store = MemoryArcadeProgressStore();
    holds = [];
  });

  /// The map over a page below, signed in as account 1 with [progress].
  Future<void> open(
    WidgetTester tester, {
    ArcadeProgress? progress,
    MemoryArcadeProgressStore? using,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    if (using != null) store = using;
    if (progress != null) store.saved[1] = progress;
    arcade = ArcadeViewModel(store: store);
    addTearDown(arcade.dispose);
    unawaited(arcade.load(1));
    await tester.pumpWidget(
      ChangeNotifierProvider<ArcadeViewModel>.value(
        value: arcade,
        child: MaterialApp(
          theme: AppTheme.light,
          navigatorObservers: [GymRatsApp.routeObserver],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, GymRatsApp.arcadeRoute),
                child: const Text('below'),
              ),
            ),
          ),
          onGenerateRoute: (settings) => switch (settings.name) {
            GymRatsApp.arcadeRoute => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  ArcadeScreen(onOpenHold: (_, stage) => holds.add(stage)),
            ),
            GymRatsApp.versusRoute => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                body: Text(
                  'versus ${(settings.arguments! as Matchup).opponent.name}',
                ),
              ),
            ),
            _ => null,
          },
        ),
      ),
    );
    await tester.tap(find.text('below'));
    await tester.pumpAndSettle();
  }

  Finder cell(int number) => find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        (widget.properties.label?.startsWith('STAGE $number,') ?? false),
  );

  Future<void> tapCell(WidgetTester tester, int number) async {
    await tester.ensureVisible(cell(number));
    await tester.pumpAndSettle();
    await tester.tap(cell(number), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets('while the progress is read only the header shows (spec 9)', (
    tester,
  ) async {
    final waiting = _WaitingStore();
    await open(tester, using: waiting);
    expect(find.text('아케이드'), findsOneWidget);
    expect(find.text('PLAY / ARCADE'), findsOneWidget);
    expect(find.byType(ArcadeMap), findsNothing);
    expect(find.text('도전'), findsNothing);
    expect(find.text('/ 72'), findsNothing);
    waiting.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ArcadeMap), findsOneWidget);
  });

  testWidgets('STAGE 8: 17 of 72 stars, and the bar with the stage to play '
      '(design ArcMap cur)', (tester) async {
    await open(tester, progress: _atStage8);
    // 17 is also a stage's number on the map.
    expect(find.text('17'), findsWidgets);
    expect(find.text('/ 72'), findsOneWidget);
    expect(find.bySemanticsLabel('별 17개, 72개 중'), findsOneWidget);
    expect(find.text('STAGE 8 · 2F'), findsOneWidget);
    expect(find.text('물렁범 · 스쿼트'), findsOneWidget);
    expect(find.text('도전'), findsOneWidget);
  });

  testWidgets('it opens with the stage to play about the middle of the map '
      '(spec 4)', (tester) async {
    await open(tester, progress: _atStage8);
    final view = tester.getRect(find.byType(SingleChildScrollView));
    final stage = tester.getCenter(cell(8));
    expect((stage.dy - view.center.dy).abs(), lessThan(2));
  });

  testWidgets('a new account opens at STAGE 1, the map scrolled to its end', (
    tester,
  ) async {
    await open(tester, progress: ArcadeProgress.initial());
    expect(find.text('STAGE 1 · 1F'), findsOneWidget);
    expect(find.text('RepBot · 푸쉬업'), findsOneWidget);
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(scroll.pixels, scroll.maxScrollExtent);
  });

  testWidgets('all 24 cleared: no bar, 72 stars, at the top with 5F', (
    tester,
  ) async {
    await open(tester, progress: ArcadeProgress(List.filled(24, 3)));
    expect(find.text('72'), findsOneWidget);
    expect(find.text('도전'), findsNothing);
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(scroll.pixels, 0);
    expect(find.text('공사중').hitTestable(), findsWidgets);
  });

  testWidgets('the bar\'s 도전 opens the stage sheet; 닫기 closes it (spec 5)', (
    tester,
  ) async {
    await open(tester, progress: _atStage8);
    await tester.tap(find.text('도전'));
    await tester.pumpAndSettle();
    expect(find.byType(ArcadeStageSheet), findsOneWidget);
    expect(find.text('STAGE 8'), findsOneWidget);
    expect(find.text('2F · AI LV 6'), findsOneWidget);
    expect(find.text('스쿼트 · 30초'), findsOneWidget);
    // The rule chip of 2F, also on its band under the sheet.
    expect(
      find.descendant(
        of: find.byType(ArcadeStageSheet),
        matching: find.text('피버 15초부터'),
      ),
      findsOneWidget,
    );
    expect(find.text('별 조건'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(ArcadeStageSheet), findsNothing);
    expect(find.byType(ArcadeScreen), findsOneWidget);
  });

  testWidgets('the sheet\'s 도전 opens the stage\'s versus', (tester) async {
    await open(tester, progress: _atStage8);
    await tester.tap(find.text('도전'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ArcadeStageSheet),
        matching: find.text('도전'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('versus STAGE 8 · 물렁범'), findsOneWidget);
  });

  testWidgets('cells: a played fight opens its sheet again, a boss its '
      'intro, a hold the hold screen; a locked one nothing (spec 4)', (
    tester,
  ) async {
    await open(tester, progress: _atStage8);
    await tapCell(tester, 7);
    expect(find.byType(ArcadeStageSheet), findsOneWidget);
    expect(find.text('STAGE 7'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    await tapCell(tester, 3);
    expect(holds.map((stage) => stage.number), [3]);

    await tapCell(tester, 9);
    expect(find.byType(ArcadeStageSheet), findsNothing);
    expect(holds.map((stage) => stage.number), [3]);

    await tapCell(tester, 6);
    expect(find.byType(ArcadeBossScreen), findsOneWidget);
    expect(find.text('STAGE 6 · 1F BOSS'), findsOneWidget);
  });

  testWidgets('back from a stage reads the progress again, moves the bar on, '
      'and opens the stage a result asked for', (tester) async {
    await open(tester, progress: _atStage8);
    await tester.tap(find.text('도전'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ArcadeStageSheet),
        matching: find.text('도전'),
      ),
    );
    await tester.pumpAndSettle();
    // Meanwhile stage 8 and the hold after it were cleared, and the result
    // asked for stage 10.
    store.saved[1] = _progress([3, 2, 3, 3, 3, 2, 1, 2, 1]);
    arcade.request(10);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('STAGE 10 · 2F'), findsOneWidget);
    expect(find.byType(ArcadeStageSheet), findsOneWidget);
    expect(find.text('곰탱이'), findsWidgets);
    expect(arcade.takeRequest(), isNull);
  });

  testWidgets('back returns to 게임 시작', (tester) async {
    await open(tester, progress: _atStage8);
    await tester.tap(find.byTooltip('게임 시작으로'));
    await tester.pumpAndSettle();
    expect(find.text('below'), findsOneWidget);
  });

  testWidgets('every button is big enough and has a name (spec 11)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester, progress: _atStage8);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(
      find.bySemanticsLabel('STAGE 8, 물렁범 · 스쿼트, 별 0개, 지금 판'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  test('the bar uses the stage\'s own title (ArcadeWords)', () {
    expect(ArcadeWords.title(ArcadeCatalog.stage(8)), '물렁범 · 스쿼트');
  });
}
