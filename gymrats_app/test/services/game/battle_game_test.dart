import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/game/battle_game.dart';

import '../../support/game_fakes.dart';

/// Push-up pass depth: `RepJudgeConfig.bottomDepth`.
const _passDepth = 1.1;

BattleGame _game([BattleRules rules = battleRules]) =>
    BattleGame(passDepth: _passDepth, rules: rules);

void main() {
  group('combo', () {
    test('a valid rep within the window earns the bonus', () {
      final game = _game();
      expect(game.addMyRep(gameRep(3))!.points, 10);
      final second = game.addMyRep(gameRep(4.5))!;
      expect(second.combo, 2);
      expect(second.points, 15);
    });

    test('a longer gap restarts it', () {
      final game = _game();
      game.addMyRep(gameRep(3));
      final second = game.addMyRep(gameRep(4.501))!;
      expect(second.combo, 1);
      expect(second.points, 10);
    });

    test('the bonus stays the same however long it runs', () {
      final game = _game();
      game.addMyRep(gameRep(3));
      game.addMyRep(gameRep(4));
      final third = game.addMyRep(gameRep(5))!;
      expect(third.combo, 3);
      expect(third.points, 15);
    });

    test('a rejected rep breaks it and scores nothing', () {
      final game = _game();
      game.addMyRep(gameRep(3));
      final rejected = game.addMyRep(
        gameRep(3.5, reason: RejectReason.insufficientDepth),
      );
      expect(rejected, isNull);
      expect(game.me.combo, 0);
      final next = game.addMyRep(gameRep(4))!;
      expect(next.combo, 1);
      expect(next.points, 10);
      expect(game.me.points, 20);
      expect(game.me.validReps, 2);
    });

    test("the opponent's reps do not touch mine", () {
      final game = _game();
      game.addMyRep(gameRep(3));
      game.addOpponentRep(gameRep(3.5));
      game.addOpponentRep(gameRep(3.6, reason: RejectReason.bellyDown));
      expect(game.addMyRep(gameRep(4))!.combo, 2);
      expect(game.opponent.combo, 0);
    });
  });

  group('fever', () {
    test('a rep from the fever start on scores double', () {
      final game = _game();
      final before = game.addMyRep(gameRep(19.999))!;
      expect(before.fever, isFalse);
      expect(before.points, 10);
      final start = game.addOpponentRep(gameRep(20))!;
      expect(start.fever, isTrue);
      expect(start.points, 20);
    });

    test('it doubles the depth and the combo bonus too', () {
      final game = _game();
      game.addMyRep(gameRep(21, maxDepth: 1.78));
      final rep = game.addMyRep(gameRep(22.2, maxDepth: 1.85))!;
      expect(rep.grade, GameGrade.excellent);
      expect(rep.combo, 2);
      expect(rep.points, 40);
    });
  });

  group('the winner when time is up', () {
    test('more points win, even with fewer reps', () {
      final game = _game();
      game.addMyRep(gameRep(21, maxDepth: 1.8));
      game.addOpponentRep(gameRep(5));
      game.addOpponentRep(gameRep(10));
      expect(game.outcome, MatchOutcome.win);
      expect(game.me.validReps, lessThan(game.opponent.validReps));
    });

    test('the same points go to more valid reps', () {
      final game = _game();
      game.addMyRep(gameRep(21, maxDepth: 1.8));
      game.addOpponentRep(gameRep(3));
      game.addOpponentRep(gameRep(8));
      game.addOpponentRep(gameRep(13));
      expect(game.lead, 0);
      expect(game.outcome, MatchOutcome.lose);
    });

    test('the same points and reps are a draw', () {
      final game = _game();
      game.addMyRep(gameRep(3));
      game.addOpponentRep(gameRep(8));
      expect(game.outcome, MatchOutcome.draw);
    });

    test('nobody scoring is a draw', () {
      expect(_game().outcome, MatchOutcome.draw);
    });
  });

  group('KO', () {
    test('the rep that makes the full lead ends the game; later reps count '
        'for nothing', () {
      final game = _game();
      for (final seconds in [20.0, 22.0, 24.0, 26.0, 28.0]) {
        game.addOpponentRep(gameRep(seconds));
      }
      expect(game.lead, -100);
      expect(game.isKo, isTrue);
      expect(game.myBarShare, 0);
      expect(game.outcome, MatchOutcome.lose);

      expect(game.addMyRep(gameRep(29)), isNull);
      expect(game.addOpponentRep(gameRep(29)), isNull);
      expect(game.me.points, 0);
      expect(game.opponent.points, 100);
    });

    test('it can land before fever', () {
      final game = _game();
      for (var i = 0; i < 10; i++) {
        game.addMyRep(gameRep(2.0 * i));
      }
      expect(game.isKo, isTrue);
      expect(game.outcome, MatchOutcome.win);
    });
  });

  test('another config is what the game plays by', () {
    final game = _game(const BattleRules(koLead: 20, dangerLead: 10));
    game.addOpponentRep(gameRep(3));
    expect(game.inDanger, isTrue);
    expect(game.myBarShare, closeTo(0.25, 1e-9));
    game.addOpponentRep(gameRep(8));
    expect(game.isKo, isTrue);
  });

  group('battle-rules.md section 6', () {
    test('example 1: time up, fewer reps, still the win', () {
      final game = _game();
      void me(double at, double? depth, int mine, int bot, double bar) {
        game.addMyRep(gameRep(at, maxDepth: depth));
        expect((game.me.points, game.opponent.points), (mine, bot));
        expect(game.myBarShare, closeTo(bar, 1e-9));
      }

      void bot(double at, int mine, int theirs, double bar) {
        game.addOpponentRep(gameRep(at));
        expect((game.me.points, game.opponent.points), (mine, theirs));
        expect(game.myBarShare, closeTo(bar, 1e-9));
      }

      me(3, 1.45, 10, 0, 0.55);
      me(4.2, 1.80, 30, 0, 0.65);
      bot(4.5, 30, 10, 0.60);
      game.addMyRep(gameRep(5, reason: RejectReason.insufficientDepth));
      expect(game.me.points, 30);
      me(5.6, 1.50, 40, 10, 0.65);
      bot(6.8, 40, 20, 0.60);
      bot(9.1, 40, 30, 0.55);
      bot(20, 40, 50, 0.45);
      me(21, 1.78, 70, 50, 0.60);
      me(22.2, 1.85, 110, 50, 0.80);
      bot(23, 110, 70, 0.70);
      bot(25.5, 110, 90, 0.60);

      expect(game.outcome, MatchOutcome.win);
      expect(game.me.validReps, 5);
      expect(game.opponent.validReps, 6);
      expect(game.inDanger, isFalse);
    });

    test('example 2: danger comes and goes, then a KO in fever', () {
      final game = _game();
      // Up to 18.0 s: A has 50 points, last rep at 15.0; B 100, last at 16.0.
      for (final seconds in [3.0, 6.0, 9.0, 12.0, 15.0]) {
        game.addMyRep(gameRep(seconds));
      }
      for (final seconds in [1.0, 2.6, 4.2, 5.8, 7.4, 9.0, 10.6, 12.2, 13.8]) {
        game.addOpponentRep(gameRep(seconds));
      }
      game.addOpponentRep(gameRep(16));
      expect((game.me.points, game.opponent.points), (50, 100));
      expect(game.myBarShare, closeTo(0.25, 1e-9));
      expect(game.inDanger, isFalse);

      game.addOpponentRep(gameRep(18.4));
      expect(game.lead, -60);
      expect(game.myBarShare, closeTo(0.20, 1e-9));
      expect(game.inDanger, isTrue);

      game.addMyRep(gameRep(19.5, maxDepth: 1.82));
      expect(game.lead, -45);
      expect(game.myBarShare, closeTo(0.275, 1e-9));
      expect(game.inDanger, isFalse);

      game.addOpponentRep(gameRep(20.3));
      expect(game.lead, -65);
      expect(game.inDanger, isTrue);

      expect(game.addOpponentRep(gameRep(21.4))!.points, 30);
      expect(game.lead, -95);
      expect(game.isKo, isFalse);

      game.addMyRep(gameRep(22, reason: RejectReason.phoneMoved));
      expect(game.lead, -95);

      final last = game.addOpponentRep(gameRep(22.5))!;
      expect(last.combo, 3);
      expect(last.points, 30);
      expect((game.me.points, game.opponent.points), (65, 190));
      expect(game.myBarShare, 0);
      expect(game.isKo, isTrue);
      expect(game.outcome, MatchOutcome.lose);
    });
  });

  group('battle-rules.md 4.4, against a bot with no combo', () {
    const botReps = [
      2.8,
      4.4,
      6.2,
      8.1,
      10.1,
      12.2,
      14.4,
      16.7,
      19.1,
      21.7,
      24.3,
      27.1,
    ];

    /// Plays [mine] and [botReps] in time order, as a KO depends on it, and
    /// returns the game with the danger state after each rep.
    (BattleGame, Map<double, bool>) play(List<double> mine) {
      final game = _game();
      final dangerAt = <double, bool>{};
      for (final seconds in [...botReps, ...mine]..sort()) {
        if (mine.contains(seconds)) {
          game.addMyRep(gameRep(seconds));
        } else {
          game.addOpponentRep(gameRep(seconds));
        }
        dangerAt[seconds] = game.inDanger;
      }
      return (game, dangerAt);
    }

    /// [count] reps spread evenly over the round.
    List<double> even(int count) => [
      for (var i = 0; i < count; i++) (i + 0.5) * 30 / count,
    ];

    test('doing nothing is a KO at the first fever rep of the bot', () {
      final game = _game();
      for (final seconds in botReps) {
        game.addOpponentRep(gameRep(seconds));
        if (game.isKo) {
          expect(seconds, 21.7);
          break;
        }
      }
      expect(game.isKo, isTrue);
      expect(game.opponent.points, 110);
    });

    test('five even reps lose by 80 with no KO; danger starts at 19.1 s and '
        'goes off for a moment at 21 s', () {
      final (game, dangerAt) = play(even(5));
      expect(game.isKo, isFalse);
      expect((game.me.points, game.opponent.points), (70, 150));
      expect(game.outcome, MatchOutcome.lose);
      expect(dangerAt[16.7], isFalse);
      expect(dangerAt[19.1], isTrue);
      expect(dangerAt[21.0], isFalse);
      expect(dangerAt[21.7], isTrue);
    });

    test('eight even reps lose by 40; danger only until my next rep', () {
      final (game, dangerAt) = play(even(8));
      expect((game.me.points, game.opponent.points), (110, 150));
      expect(game.outcome, MatchOutcome.lose);
      expect(dangerAt[21.7], isFalse);
      expect(dangerAt[24.3], isTrue);
      expect(dangerAt[24.375], isFalse);
      expect(dangerAt[27.1], isTrue);
      expect(dangerAt[28.125], isFalse);
    });

    test('twelve even reps win by 10, thanks to one more fever rep', () {
      final (game, _) = play(even(12));
      expect((game.me.points, game.opponent.points), (160, 150));
      expect(game.outcome, MatchOutcome.win);
    });
  });
}
