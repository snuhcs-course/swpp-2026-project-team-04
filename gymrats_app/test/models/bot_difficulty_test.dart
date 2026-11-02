import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';

void main() {
  group('the numbers, for a 30 s round', () {
    test('초보: 5 to 7 counted, 1 to 3 mistakes, none deep, no added combos', () {
      const level = BotDifficulty.beginner;
      expect(level.label, '초보');
      expect((level.fewestValid, level.mostValid), (5, 7));
      expect((level.fewestRejected, level.mostRejected), (1, 3));
      expect(level.deepShare, 0);
      expect(level.comboChance, 0);
    });

    test('중수: 8 to 10 counted, 0 to 2 mistakes, 10% deep, some combos', () {
      const level = BotDifficulty.intermediate;
      expect(level.label, '중수');
      expect((level.fewestValid, level.mostValid), (8, 10));
      expect((level.fewestRejected, level.mostRejected), (0, 2));
      expect(level.deepShare, 0.1);
      expect(level.comboChance, 0.08);
    });

    test('고수: the bot from before there were levels', () {
      const level = BotDifficulty.expert;
      expect(level.label, '고수');
      expect((level.fewestValid, level.mostValid), (10, 14));
      expect((level.fewestRejected, level.mostRejected), (0, 2));
      expect(level.deepShare, 0.2);
      expect(level.comboChance, 0);
    });

    test('are stated for 30 s', () {
      expect(BotDifficulty.paceLength, const Duration(seconds: 30));
    });

    test('the levels are in order, from the easiest', () {
      expect(BotDifficulty.values, [
        BotDifficulty.beginner,
        BotDifficulty.intermediate,
        BotDifficulty.expert,
      ]);
    });
  });

  group('atPace', () {
    test('keeps a count in a 30 s round', () {
      expect(BotDifficulty.atPace(14, const Duration(seconds: 30)), 14);
    });

    test('scales a count with the round, to the nearest whole rep', () {
      expect(BotDifficulty.atPace(10, const Duration(seconds: 20)), 7);
      expect(BotDifficulty.atPace(14, const Duration(seconds: 20)), 9);
      expect(BotDifficulty.atPace(14, const Duration(seconds: 60)), 28);
    });
  });

  test('validRange says the valid reps of a round', () {
    const round = Duration(seconds: 30);
    expect(BotDifficulty.beginner.validRange(round), '5~7');
    expect(BotDifficulty.intermediate.validRange(round), '8~10');
    expect(BotDifficulty.expert.validRange(round), '10~14');
    expect(BotDifficulty.expert.validRange(const Duration(seconds: 20)), '7~9');
  });

  group('the name', () {
    test('tells the levels apart', () {
      expect(BotDifficulty.beginner.opponentName, 'AI 봇 · 초보');
      expect(BotDifficulty.intermediate.opponentName, 'AI 봇 · 중수');
      expect(BotDifficulty.expert.opponentName, 'AI 봇 · 고수');
    });

    test("fits the server's 40 characters for an opponent's name", () {
      for (final level in BotDifficulty.values) {
        expect(level.opponentName.length, lessThanOrEqualTo(40));
      }
    });

    test('goes into the saved record', () {
      final result = BattleResult(
        matchup: Matchup(
          exercise: ExerciseType.pushUp,
          playerName: '우현',
          opponent: const Opponent(
            name: 'RepBot',
            isBot: true,
          ).at(BotDifficulty.beginner),
        ),
        myReps: 3,
        myInvalidReps: 0,
        opponentReps: 2,
        endedAt: DateTime(2026, 11, 1),
      );
      expect(result.record.opponentName, 'AI 봇 · 초보');
    });
  });

  group('Opponent.at', () {
    test('gives a bot the level and its name', () {
      final bot = const Opponent(
        name: 'RepBot',
        isBot: true,
      ).at(BotDifficulty.intermediate);
      expect(bot.name, 'AI 봇 · 중수');
      expect(bot.isBot, isTrue);
      expect(bot.difficulty, BotDifficulty.intermediate);
    });

    test('leaves a person as they are', () {
      const person = Opponent(name: '진영', isBot: false);
      expect(person.at(BotDifficulty.beginner), same(person));
      expect(person.difficulty, isNull);
    });
  });

  group('Matchup.rematch', () {
    test('asks for the same exercise and the same level', () {
      final request = Matchup(
        exercise: ExerciseType.squat,
        playerName: '우현',
        opponent: const Opponent(
          name: 'RepBot',
          isBot: true,
        ).at(BotDifficulty.beginner),
      ).rematch;
      expect(request.exercise, ExerciseType.squat);
      expect(request.difficulty, BotDifficulty.beginner);
    });

    test('with no level chosen, asks for the expert', () {
      const matchup = Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: 'RepBot', isBot: true),
      );
      expect(matchup.rematch.difficulty, BotDifficulty.expert);
    });
  });
}
