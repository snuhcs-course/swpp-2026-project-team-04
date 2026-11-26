import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/result_scene_demo.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/screens/result_screen.dart';
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
}
