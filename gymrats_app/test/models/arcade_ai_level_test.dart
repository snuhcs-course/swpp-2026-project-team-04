import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_ai_level.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/services/opponent/bot_opponent.dart';

void main() {
  test('16 levels, numbered from 1 in order', () {
    expect([
      for (final level in ArcadeAiLevel.values) level.level,
    ], List.generate(16, (i) => i + 1));
  });

  test('of gives the level of a number', () {
    for (var n = 1; n <= 16; n++) {
      expect(ArcadeAiLevel.of(n).level, n);
    }
    expect(ArcadeAiLevel.of(1), ArcadeAiLevel.lv1);
    expect(ArcadeAiLevel.of(16), ArcadeAiLevel.lv16);
  });

  test('a level outside 1 to 16 throws', () {
    expect(() => ArcadeAiLevel.of(0), throwsRangeError);
    expect(() => ArcadeAiLevel.of(17), throwsRangeError);
    expect(() => ArcadeAiLevel.of(-1), throwsRangeError);
  });

  test('LV 1 has every number of 초보', () {
    const level = ArcadeAiLevel.lv1;
    const beginner = BotDifficulty.beginner;
    expect(
      (
        level.fewestValid,
        level.mostValid,
        level.fewestRejected,
        level.mostRejected,
        level.deepShare,
        level.comboChance,
      ),
      (
        beginner.fewestValid,
        beginner.mostValid,
        beginner.fewestRejected,
        beginner.mostRejected,
        beginner.deepShare,
        beginner.comboChance,
      ),
    );
  });

  test('each level up adds one valid rep at both ends', () {
    for (var n = 2; n <= 16; n++) {
      final level = ArcadeAiLevel.of(n), before = ArcadeAiLevel.of(n - 1);
      expect(level.fewestValid, before.fewestValid + 1, reason: 'LV $n');
      expect(level.mostValid, before.mostValid + 1, reason: 'LV $n');
    }
  });

  test('the 4F boss, LV 16, counts 20 to 22 in 30 s', () {
    expect(ArcadeAiLevel.lv16.validRangeIn30s, (20, 22));
  });

  group('the bot plays a level', () {
    test('LV 1 plans exactly the rounds of 초보', () {
      for (var seed = 0; seed < 100; seed++) {
        expect(
          [
            for (final rep in BotOpponent.planRound(
              Random(seed),
              battleDuration,
              difficulty: ArcadeAiLevel.lv1,
            ))
              (rep.at, rep.reason, rep.maxDepth),
          ],
          [
            for (final rep in BotOpponent.planRound(
              Random(seed),
              battleDuration,
              difficulty: BotDifficulty.beginner,
            ))
              (rep.at, rep.reason, rep.maxDepth),
          ],
          reason: 'seed $seed',
        );
      }
    });

    for (final level in ArcadeAiLevel.values) {
      test('LV ${level.level} stays inside its valid and rejected counts', () {
        for (var seed = 0; seed < 200; seed++) {
          final round = BotOpponent.planRound(
            Random(seed),
            battleDuration,
            difficulty: level,
          );
          final valid = round.where((rep) => rep.valid).length;
          expect(
            valid,
            inInclusiveRange(level.fewestValid, level.mostValid),
            reason: 'seed $seed',
          );
          expect(
            round.length - valid,
            inInclusiveRange(level.fewestRejected, level.mostRejected),
            reason: 'seed $seed',
          );
          expect(round.last.at, lessThan(battleDuration));
        }
      });
    }

    test('a bot takes a level as its pace', () {
      final bot = BotOpponent(difficulty: ArcadeAiLevel.lv9);
      expect(bot.difficulty, ArcadeAiLevel.lv9);
      bot.dispose();
    });
  });
}

extension on ArcadeAiLevel {
  (int, int) get validRangeIn30s => (
    BotDifficulty.atPace(fewestValid, const Duration(seconds: 30)),
    BotDifficulty.atPace(mostValid, const Duration(seconds: 30)),
  );
}
