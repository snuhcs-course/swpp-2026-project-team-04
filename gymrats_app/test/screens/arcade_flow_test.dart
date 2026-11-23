import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_progress.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/arcade_boss_screen.dart';
import 'package:gymrats_app/screens/arcade_flow.dart';
import 'package:gymrats_app/screens/arcade_result_screen.dart';
import 'package:gymrats_app/screens/arcade_screen.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/arcade_viewmodel.dart';
import 'package:gymrats_app/widgets/arcade_stage_sheet.dart';
import 'package:provider/provider.dart';

ArcadeProgress _progress(int played) =>
    ArcadeProgress([for (var i = 0; i < 24; i++) i < played ? 1 : 0]);

BattleResult _battle(
  Matchup matchup, {
  required bool won,
  bool ko = false,
  int me = 160,
  int opponent = 90,
}) => BattleResult(
  matchup: matchup,
  myReps: 12,
  myInvalidReps: 1,
  opponentReps: 8,
  myScore: won ? me : opponent,
  opponentScore: won ? opponent : me,
  decidedOutcome: won ? MatchOutcome.win : MatchOutcome.lose,
  end: ko ? GameEnd.ko : GameEnd.timeUp,
  endedAt: DateTime(2026, 11, 23, 20),
);

ArcadeFightStage _fight(int number) =>
    ArcadeCatalog.stage(number) as ArcadeFightStage;
ArcadeBossStage _boss(int number) =>
    ArcadeCatalog.stage(number) as ArcadeBossStage;

void main() {
  late MemoryArcadeProgressStore store;
  late ArcadeViewModel arcade;
  late List<int> holds;

  /// The map over a page below, with [played] stages starred, and a
  /// stand-in battle page over the map.
  Future<void> open(WidgetTester tester, {required int played}) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    holds = [];
    store = MemoryArcadeProgressStore()..saved[1] = _progress(played);
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
              builder: (_) => ArcadeScreen(
                onOpenHold: (_, stage) => holds.add(stage.number),
              ),
            ),
            GymRatsApp.versusRoute ||
            GymRatsApp.battleRoute => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                body: Text(
                  '${settings.name} '
                  '${(settings.arguments! as Matchup).opponent.name}',
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

  /// A battle page over the map that ends as [result] at once.
  Future<void> play(WidgetTester tester, BattleResult result) async {
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    ArcadeFlow.afterBattle(context, result, passDepth: 0.5),
                child: const Text('battle over'),
              ),
            ),
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.text('battle over'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('a fight (spec 6)', () {
    testWidgets('won by KO: 클리어!, the stars got, the next stage\'s card, '
        'and the stars kept', (tester) async {
      await open(tester, played: 7);
      final stage = _fight(8);
      await play(
        tester,
        _battle(
          ArcadeMatchups.fight(stage, playerName: '우현'),
          won: true,
          ko: true,
        ),
      );
      expect(find.byType(ArcadeResultScreen), findsOneWidget);
      expect(find.text('STAGE 8 · 2F'), findsOneWidget);
      expect(find.text('클리어!'), findsOneWidget);
      expect(
        find.bySemanticsLabel('승리 받음, 콤보 5 이상 못 받음, KO 승리 받음'),
        findsOneWidget,
      );
      expect(find.text('STAGE 9'), findsOneWidget);
      expect(find.text('펭뚱이 · 하이 플랭크'), findsOneWidget);
      expect(find.text('HOLD'), findsOneWidget);
      expect(find.text('리포트 보기'), findsOneWidget);
      expect(find.text('다음 스테이지'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(store.saved[1]!.bestOf(8), 2);
      expect(arcade.progress!.bestOf(8), 2);
    });

    testWidgets('lost: 실패 with the score and no star; no star is kept', (
      tester,
    ) async {
      await open(tester, played: 7);
      final stage = _fight(8);
      await play(
        tester,
        _battle(
          ArcadeMatchups.fight(stage, playerName: '우현'),
          won: false,
          me: 140,
          opponent: 98,
        ),
      );
      expect(find.text('실패'), findsOneWidget);
      expect(find.bySemanticsLabel('내 점수 98, 상대 점수 140'), findsOneWidget);
      expect(
        find.bySemanticsLabel('승리 못 받음, 콤보 5 이상 못 받음, KO 승리 못 받음'),
        findsOneWidget,
      );
      expect(find.text('다시 도전'), findsOneWidget);
      expect(find.text('아케이드로'), findsOneWidget);
      expect(store.saved[1]!.bestOf(8), 0);
    });

    testWidgets('a draw is a fail too', (tester) async {
      await open(tester, played: 7);
      final draw = BattleResult(
        matchup: ArcadeMatchups.fight(_fight(8), playerName: '우현'),
        myReps: 9,
        myInvalidReps: 0,
        opponentReps: 9,
        myScore: 120,
        opponentScore: 120,
        decidedOutcome: MatchOutcome.draw,
        endedAt: DateTime(2026, 11, 23),
      );
      await play(tester, draw);
      expect(find.text('실패'), findsOneWidget);
    });

    testWidgets('다시 도전 opens the versus again over the map', (tester) async {
      await open(tester, played: 7);
      await play(
        tester,
        _battle(ArcadeMatchups.fight(_fight(8), playerName: '우현'), won: false),
      );
      await tap(tester, '다시 도전');
      expect(find.text('/versus STAGE 8 · 물렁범'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeScreen), findsOneWidget);
    });

    testWidgets('아케이드로 goes back to the map', (tester) async {
      await open(tester, played: 7);
      await play(
        tester,
        _battle(ArcadeMatchups.fight(_fight(8), playerName: '우현'), won: false),
      );
      await tap(tester, '아케이드로');
      expect(find.byType(ArcadeScreen), findsOneWidget);
      expect(find.byType(ArcadeResultScreen), findsNothing);
    });

    testWidgets('back goes to the map too', (tester) async {
      await open(tester, played: 7);
      await play(
        tester,
        _battle(ArcadeMatchups.fight(_fight(8), playerName: '우현'), won: true),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeScreen), findsOneWidget);
    });

    testWidgets('다음 스테이지 opens the next stage over the map: a fight\'s '
        'sheet, a hold\'s screen', (tester) async {
      await open(tester, played: 6);
      await play(
        tester,
        _battle(ArcadeMatchups.fight(_fight(7), playerName: '우현'), won: true),
      );
      await tap(tester, '다음 스테이지');
      expect(find.byType(ArcadeStageSheet), findsOneWidget);
      expect(find.text('STAGE 8'), findsOneWidget);
      await tap(tester, '닫기');

      await play(
        tester,
        _battle(ArcadeMatchups.fight(_fight(8), playerName: '우현'), won: true),
      );
      await tap(tester, '다음 스테이지');
      expect(holds, [9]);
    });
  });

  group('a boss match (spec 7)', () {
    testWidgets('R1 lost ends it: R1 패배, R2 locked, no stars', (tester) async {
      await open(tester, played: 5);
      final stage = _boss(6);
      await play(
        tester,
        _battle(
          ArcadeMatchups.boss(stage, 1, playerName: '우현'),
          won: false,
          me: 132,
          opponent: 88,
        ),
      );
      expect(find.text('STAGE 6 · 1F BOSS'), findsOneWidget);
      expect(find.text('R1 패배'), findsOneWidget);
      expect(find.text('푸쉬업 · 패배'), findsOneWidget);
      expect(find.text('88 : 132'), findsOneWidget);
      expect(find.text('스쿼트'), findsOneWidget);
      expect(find.text('R1부터 다시'), findsOneWidget);
      expect(find.text('아케이드로'), findsOneWidget);
      expect(arcade.bossRun, isNull);
      expect(store.saved[1]!.bestOf(6), 0);
    });

    testWidgets('R1 won: the break; R2 lost: R2 패배 with R1 checked', (
      tester,
    ) async {
      await open(tester, played: 5);
      final stage = _boss(6);
      final first = _battle(
        ArcadeMatchups.boss(stage, 1, playerName: '우현'),
        won: true,
        me: 165,
        opponent: 120,
      );
      await play(tester, first);
      expect(find.byType(ArcadeBossScreen), findsOneWidget);
      expect(find.text('1라운드 승리!'), findsOneWidget);
      expect(arcade.bossRun!.first, same(first));

      await play(
        tester,
        _battle(
          ArcadeMatchups.boss(stage, 2, playerName: '우현'),
          won: false,
          me: 140,
          opponent: 100,
        ),
      );
      expect(find.text('R2 패배'), findsOneWidget);
      expect(find.text('푸쉬업 · 승리'), findsOneWidget);
      expect(find.text('165 : 120'), findsOneWidget);
      expect(find.text('스쿼트 · 패배'), findsOneWidget);
      expect(find.text('100 : 140'), findsOneWidget);
      expect(store.saved[1]!.bestOf(6), 0);
    });

    testWidgets('both won: n층 클리어!, the rounds, the next floor open; '
        '{n+1}층으로 opens its first stage', (tester) async {
      await open(tester, played: 5);
      final stage = _boss(6);
      await play(
        tester,
        _battle(
          ArcadeMatchups.boss(stage, 1, playerName: '우현'),
          won: true,
          ko: true,
        ),
      );
      await play(
        tester,
        _battle(
          ArcadeMatchups.boss(stage, 2, playerName: '우현'),
          won: true,
          ko: true,
          me: 200,
          opponent: 95,
        ),
      );
      expect(find.text('STAGE 6 · 1F 동네 체육관'), findsOneWidget);
      expect(find.text('1층 클리어!'), findsOneWidget);
      expect(find.text('푸쉬업 · KO 승리'), findsOneWidget);
      expect(find.text('스쿼트 · KO 승리'), findsOneWidget);
      expect(find.text('200 : 95'), findsOneWidget);
      expect(find.text('시립 체육관'), findsOneWidget);
      expect(find.text('체육관 관장 · 펭뚱이'), findsOneWidget);
      expect(find.text('OPEN'), findsOneWidget);
      await tester.pumpAndSettle();
      // Both won by KO: the first and third stars (no excellent reps read).
      expect(store.saved[1]!.bestOf(6), 2);
      expect(arcade.progress!.isOpen(7), isTrue);

      await tap(tester, '2층으로');
      expect(find.byType(ArcadeStageSheet), findsOneWidget);
      expect(find.text('STAGE 7'), findsOneWidget);
    });

    testWidgets('4F: 4층 클리어! with 5F 공사중, and the map at the top (spec '
        '1.6)', (tester) async {
      await open(tester, played: 23);
      final stage = _boss(24);
      await play(
        tester,
        _battle(ArcadeMatchups.boss(stage, 1, playerName: '우현'), won: true),
      );
      await play(
        tester,
        _battle(ArcadeMatchups.boss(stage, 2, playerName: '우현'), won: true),
      );
      expect(find.text('STAGE 24 · 4F BOSS'), findsOneWidget);
      expect(find.text('4층 클리어!'), findsOneWidget);
      expect(find.text('5F'), findsWidgets);
      expect(find.text('공사중'), findsOneWidget);
      expect(find.text('리포트 보기'), findsOneWidget);
      await tap(tester, '아케이드로');
      expect(find.byType(ArcadeScreen), findsOneWidget);
      expect(arcade.progress!.currentStage, isNull);
      expect(find.text('도전'), findsNothing);
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(scroll.pixels, 0);
    });

    testWidgets('R1부터 다시 opens the intro again', (tester) async {
      await open(tester, played: 5);
      await play(
        tester,
        _battle(ArcadeMatchups.boss(_boss(6), 1, playerName: '우현'), won: false),
      );
      await tap(tester, 'R1부터 다시');
      expect(find.byType(ArcadeBossScreen), findsOneWidget);
      expect(find.text('보스 매치'), findsOneWidget);
    });

    testWidgets('R2 without R1 known counts as left: back to the map', (
      tester,
    ) async {
      await open(tester, played: 5);
      await play(
        tester,
        _battle(ArcadeMatchups.boss(_boss(6), 2, playerName: '우현'), won: true),
      );
      expect(find.byType(ArcadeScreen), findsOneWidget);
      expect(store.saved[1]!.bestOf(6), 0);
    });
  });

  group('ways back', () {
    testWidgets('leave ends the boss run and goes to the map', (tester) async {
      await open(tester, played: 5);
      await play(
        tester,
        _battle(ArcadeMatchups.boss(_boss(6), 1, playerName: '우현'), won: true),
      );
      expect(arcade.bossRun, isNotNull);
      await tap(tester, '그만하기');
      expect(find.byType(ArcadeScreen), findsOneWidget);
      expect(arcade.bossRun, isNull);
    });

    testWidgets('replay: a fight from its versus, a boss match from its '
        'intro, a hold back to the map', (tester) async {
      await open(tester, played: 7);
      final context = tester.element(find.byType(ArcadeScreen));
      ArcadeFlow.replay(context, 8);
      await tester.pumpAndSettle();
      expect(find.text('/versus STAGE 8 · 물렁범'), findsOneWidget);

      ArcadeFlow.replay(tester.element(find.text('/versus STAGE 8 · 물렁범')), 6);
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeBossScreen), findsOneWidget);

      ArcadeFlow.replay(tester.element(find.byType(ArcadeBossScreen)), 3);
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeScreen), findsOneWidget);
      // The map stays under each, nothing piles up.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('below'), findsOneWidget);
    });

    testWidgets('the player\'s name comes from the signed-in account; none '
        'gives an empty name', (tester) async {
      await open(tester, played: 0);
      expect(
        ArcadeFlow.playerName(tester.element(find.byType(ArcadeScreen))),
        '',
      );
    });
  });
}
