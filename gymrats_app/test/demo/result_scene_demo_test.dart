import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/result_scene_demo.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/ranking_ladder.dart';
import 'package:gymrats_app/screens/result_screen.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/widgets/victory_overlay.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';

final _playing = find.byWidgetPredicate(
  (widget) => widget is VictoryOverlay && widget.play,
);

Future<void> _start(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(360, 780)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ResultSceneDemo());
}

/// Taps the chip or switch with [words]; a character's name is in two rows
/// (mine first, then the opponent's), so [mine] picks the first.
Future<void> _tap(
  WidgetTester tester,
  String words, {
  bool mine = false,
}) async {
  final found = mine ? find.text(words).first : find.text(words).last;
  await tester.ensureVisible(found);
  await tester.tap(found);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a draw against 펭뚱이 with 곰탱이: the report plays the draw '
      'with both, then back to the picker', (tester) async {
    await _start(tester);
    await _tap(tester, '무승부');
    await _tap(tester, '곰탱이', mine: true);
    await _tap(tester, '펭뚱이');
    await tester.ensureVisible(find.text('리포트 열기'));
    await tester.tap(find.text('리포트 열기'));
    // The route's push, then the seat is found and the clock ticks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
    final overlay = tester.widget<VictoryOverlay>(_playing);
    expect(overlay.result, VictoryResult.draw);
    expect(overlay.characterId, 'bear');
    expect(overlay.opponent?.characterId, 'penguin');
    expect(overlay.opponent?.isBot, isFalse);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(_playing, findsNothing);
    expect(find.byType(VictorySeat), findsOneWidget);

    // System back, as on the phone.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('리포트 열기'), findsOneWidget);
  });

  testWidgets('애니메이션 줄이기 opens the report on its end look', (tester) async {
    await _start(tester);
    await _tap(tester, '애니메이션 줄이기');
    await tester.ensureVisible(find.text('리포트 열기'));
    await tester.tap(find.text('리포트 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(_playing, findsNothing);
    expect(
      tester.widget<VictorySeat>(find.byType(VictorySeat)).result,
      VictoryResult.lose,
    );
  });

  test('the made-up battles give each result, RepBot as a bot and an '
      'opponent not known without a character', () {
    for (final result in VictoryResult.values) {
      final battle = ResultScenePicker.battleOf(result, 'seal');
      expect(VictoryResult.of(battle), result);
      expect(battle.matchup.opponent.characterId, 'seal');
      expect(battle.matchup.opponent.isBot, isFalse);
    }
    expect(
      ResultScenePicker.battleOf(VictoryResult.koWin, null).end,
      GameEnd.ko,
    );
    expect(
      ResultScenePicker.battleOf(VictoryResult.leftWin, null).departure,
      BattleDeparture.opponentLeft,
    );
    expect(
      ResultScenePicker.battleOf(VictoryResult.draw, null).outcome,
      MatchOutcome.draw,
    );
    final bot = ResultScenePicker.battleOf(VictoryResult.draw, 'bot');
    expect(bot.matchup.opponent.isBot, isTrue);
    expect(bot.matchup.opponent.characterId, isNull);
    expect(VictoryOverlay.opponentCharacterOf(bot.matchup.opponent), 'bot');
    final unknown = ResultScenePicker.battleOf(VictoryResult.draw, null);
    expect(unknown.matchup.opponent.characterId, isNull);
    expect(
      VictoryOverlay.opponentCharacterOf(unknown.matchup.opponent),
      'mouse',
    );
  });

  group('순위 경우 (A15)', () {
    /// Picks KO 승리 and the ladder's [name], opens the report and plays
    /// [ms] of its scene.
    Future<VictoryOverlay> openCase(
      WidgetTester tester,
      String name, {
      int ms = 1500,
    }) async {
      await _start(tester);
      await _tap(tester, 'KO 승리');
      // The cases are below the button: scroll to the chip first.
      await tester.ensureVisible(find.text(name).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('리포트 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('리포트 열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump();
      final overlay = tester.widget<VictoryOverlay>(_playing);
      for (var left = ms; left > 0; left -= 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return overlay;
    }

    testWidgets('base: the ladder plays in the hold and the chip stays', (
      tester,
    ) async {
      final overlay = await openCase(tester, 'base');
      expect(overlay.ladder!.path, LadderPath.confirmed);
      expect(find.text('펭귄짱'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      // Held: still playing past the scene's old end.
      expect(_playing, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(_playing, findsNothing);
      expect(find.text('29'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('리포트 열기'), findsOneWidget);
    });

    testWidgets('late: no ladder, the scene as before', (tester) async {
      final overlay = await openCase(tester, 'late', ms: 1000);
      expect(overlay.ladder!.path, LadderPath.late);
      expect(find.text('펭귄짱'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(_playing, findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    });

    testWidgets('none: a friend battle, no ladder', (tester) async {
      final overlay = await openCase(tester, 'none', ms: 100);
      expect(overlay.ladder, isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    });

    test('battleOf makes a case ranked with its ranking before', () {
      final ranked = ResultScenePicker.battleOf(
        VictoryResult.koWin,
        'penguin',
        ladderCase: 'mid',
      );
      expect(ranked.ranked, isTrue);
      expect(ranked.rankingBefore!.me!.rank, 20);
      final friend = ResultScenePicker.battleOf(
        VictoryResult.koWin,
        'penguin',
        ladderCase: 'none',
      );
      expect(friend.ranked, isFalse);
      expect(friend.rankingBefore, isNull);
      final plain = ResultScenePicker.battleOf(VictoryResult.lose, null);
      expect(plain.ranked, isFalse);
    });

    test('every case answers with its ranking after the battle', () async {
      for (final MapEntry(key: name, value: c) in ScoreLadderCase.all.entries) {
        final after = await c
            .rankings(VictoryResult.draw)
            .fetchWeekly(RankingScope.global, ExerciseType.pushUp);
        expect(after.me!.points, (c.old ?? 0) + 3, reason: name);
        expect(after.me!.battles, (c.old == null ? 0 : 4) + 1, reason: name);
      }
      final late = await ScoreLadderCase.all['late']!
          .rankings(VictoryResult.koWin, late: true)
          .fetchWeekly(RankingScope.global, ExerciseType.pushUp);
      expect(late.me!.battles, ScoreLadderCase.myBattles);
    });
  });
}
