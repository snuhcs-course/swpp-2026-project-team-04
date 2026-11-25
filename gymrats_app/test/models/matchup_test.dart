import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_ai_level.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';

void main() {
  group('Opponent.arcade (P16)', () {
    test('a fight stage keeps its character, pace and stage, and names '
        'its record "STAGE n · 캐릭터" (spec 13.3)', () {
      final opponent = Opponent.arcade(
        stage: 8,
        characterId: 'seal',
        pace: ArcadeAiLevel.lv6,
      );
      expect(opponent.name, 'STAGE 8 · 물렁범');
      expect(opponent.characterName, '물렁범');
      expect(opponent.isBot, isTrue);
      expect(opponent.isArcade, isTrue);
      expect(opponent.characterId, 'seal');
      expect(opponent.pace, ArcadeAiLevel.lv6);
      expect(opponent.arcadeStage, 8);
      expect(opponent.arcadeRound, isNull);
      expect(opponent.difficulty, isNull);
    });

    test('a boss round adds its round: "STAGE 6 R1 · 물렁범"', () {
      final first = Opponent.arcade(
        stage: 6,
        round: 1,
        characterId: 'seal',
        pace: ArcadeAiLevel.lv4,
      );
      final second = Opponent.arcade(
        stage: 6,
        round: 2,
        characterId: 'seal',
        pace: ArcadeAiLevel.lv4,
      );
      expect(first.name, 'STAGE 6 R1 · 물렁범');
      expect(second.name, 'STAGE 6 R2 · 물렁범');
      expect(second.arcadeRound, 2);
    });

    test('RepBot stages are named by RepBot', () {
      final opponent = Opponent.arcade(
        stage: 1,
        characterId: 'bot',
        pace: ArcadeAiLevel.lv1,
      );
      expect(opponent.name, 'STAGE 1 · RepBot');
      expect(opponent.characterName, 'RepBot');
    });
  });

  group('outside the arcade nothing changes', () {
    test('a bot and a person keep their names and no arcade values', () {
      const bot = Opponent(
        name: 'AI 봇 · 초보',
        isBot: true,
        difficulty: BotDifficulty.beginner,
      );
      const person = Opponent(name: '민지', isBot: false);
      for (final opponent in [bot, person]) {
        expect(opponent.isArcade, isFalse);
        expect(opponent.characterName, opponent.name);
        expect(opponent.characterId, isNull);
        expect(opponent.pace, isNull);
        expect(opponent.arcadeStage, isNull);
        expect(opponent.arcadeRound, isNull);
      }
    });

    test('at() still gives a bot its level and leaves a person alone', () {
      const bot = Opponent(name: 'x', isBot: true);
      expect(bot.at(BotDifficulty.intermediate).name, 'AI 봇 · 중수');
      const person = Opponent(name: '민지', isBot: false);
      expect(person.at(BotDifficulty.expert), same(person));
    });

    test('a rematch keeps the exercise and the level (고수 without one)', () {
      const matchup = Matchup(
        exercise: ExerciseType.squat,
        playerName: '우현',
        opponent: Opponent(name: 'x', isBot: true),
      );
      expect(matchup.rematch.exercise, ExerciseType.squat);
      expect(matchup.rematch.difficulty, BotDifficulty.expert);
    });
  });

  group('isArcadeName: a past battle keeps only the name', () {
    test('arcade names', () {
      expect(Opponent.isArcadeName('STAGE 8 · 물렁범'), isTrue);
      expect(Opponent.isArcadeName('STAGE 24 R2 · 곰탱이'), isTrue);
      expect(Opponent.isArcadeName('STAGE 1 · RepBot'), isTrue);
    });

    test('other names', () {
      expect(Opponent.isArcadeName('AI 봇 · 고수'), isFalse);
      expect(Opponent.isArcadeName('민지'), isFalse);
      expect(Opponent.isArcadeName('STAGE 8'), isFalse);
      expect(Opponent.isArcadeName('STAGE 8 R3 · 물렁범'), isFalse);
      expect(Opponent.isArcadeName('my STAGE 8 · 물렁범'), isFalse);
    });

    test('arcadeName and isArcadeName agree', () {
      for (final round in [null, 1, 2]) {
        expect(
          Opponent.isArcadeName(Opponent.arcadeName(12, round, '펭뚱이')),
          isTrue,
        );
      }
    });
  });
}
