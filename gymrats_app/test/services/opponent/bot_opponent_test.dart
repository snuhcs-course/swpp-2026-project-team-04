import 'dart:io';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/services/game/player_game_score.dart';
import 'package:gymrats_app/services/game/rep_grade.dart';
import 'package:gymrats_app/services/opponent/bot_opponent.dart';
import 'package:gymrats_app/services/pose/exercise_judge.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

/// The rounds the bot planned before there were levels, printed from that code
/// at `8fc6cb3`: when each rep ends in microseconds, and its depth or the
/// reason it was rejected.
const _roundsBeforeLevels = <int, List<(int, Object)>>{
  1: [
    (2512262, 1.4),
    (4067031, 1.4),
    (5493016, 1.4),
    (7323603, 1.4),
    (8952605, 1.4),
    (10339273, 1.4),
    (12197606, 1.4),
    (14003473, 1.4),
    (16200870, 1.4),
    (18265314, 1.4),
    (20629100, 1.4),
    (22863476, 1.9),
    (24727108, 1.4),
    (26964196, 1.4),
  ],
  7: [
    (2770148, 1.4),
    (4681865, RejectReason.bellyDown),
    (6099410, 1.4),
    (8211828, 1.4),
    (9905740, RejectReason.tooFast),
    (12379333, 1.4),
    (14428064, 1.4),
    (16788370, 1.4),
    (18885278, 1.4),
    (21794219, 1.9),
    (24394521, 1.4),
    (26973691, 1.4),
  ],
};

void main() {
  group('difficulty', () {
    const pushUpDepth = 1.1;

    List<List<RepEvent>> roundsOf(BotDifficulty level, {int count = 2000}) => [
      for (var seed = 0; seed < count; seed++)
        BotOpponent.planRound(Random(seed), battleDuration, difficulty: level),
    ];

    /// The round's points by the game's rules, and how many reps were combos.
    (int, int) score(List<RepEvent> round) {
      final player = PlayerGameScore();
      var combos = 0;
      for (final rep in round) {
        final result = player.addRep(
          battleRules.gradeOf(rep, passDepth: pushUpDepth),
          rep.at,
        );
        if (result != null && result.combo > 1) combos++;
      }
      return (player.points, combos);
    }

    double meanPoints(List<List<RepEvent>> rounds) =>
        rounds.map((round) => score(round).$1).reduce((a, b) => a + b) /
        rounds.length;

    double shareWithCombo(List<List<RepEvent>> rounds) =>
        rounds.where((round) => score(round).$2 > 0).length / rounds.length;

    for (final level in BotDifficulty.values) {
      group(level.label, () {
        final rounds = roundsOf(level, count: 300);

        test('stays inside its counts, and in order inside the round', () {
          for (final (seed, round) in rounds.indexed) {
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
            expect(
              [for (final rep in round) rep.index],
              [for (var i = 1; i <= round.length; i++) i],
            );
            expect(round.first.at, greaterThan(Duration.zero));
            expect(round.last.at, lessThan(battleDuration));
            for (var i = 1; i < round.length; i++) {
              expect(
                round[i].at,
                greaterThan(round[i - 1].at),
                reason: 'seed $seed, rep ${i + 1}',
              );
            }
          }
        });

        test('reaches both ends of its counts', () {
          final valid = {
            for (final round in rounds) round.where((rep) => rep.valid).length,
          };
          expect(valid, containsAll([level.fewestValid, level.mostValid]));
          final rejected = {
            for (final round in rounds) round.where((rep) => !rep.valid).length,
          };
          expect(
            rejected,
            containsAll([level.fewestRejected, level.mostRejected]),
          );
        });

        test('its share of excellent reps is about its deep share', () {
          final valid = [
            for (final round in rounds) ...round.where((rep) => rep.valid),
          ];
          final excellent = valid.where(
            (rep) =>
                battleRules.gradeFor(
                  maxDepth: rep.maxDepth,
                  passDepth: pushUpDepth,
                ) ==
                GameGrade.excellent,
          );
          if (level.deepShare == 0) {
            expect(excellent, isEmpty);
          } else {
            expect(
              excellent.length / valid.length,
              closeTo(level.deepShare, 0.04),
            );
          }
        });

        test('its mistakes earn nothing', () {
          for (final round in rounds) {
            for (final rep in round.where((rep) => !rep.valid)) {
              expect(rep.maxDepth, isNull);
              expect(rep.minElbowAngle, isNull);
              expect(battleRules.gradeOf(rep, passDepth: pushUpDepth), isNull);
            }
          }
        });

        test('at a squat pass depth, only its depths change', () {
          const squatDepth = 0.75;
          for (var seed = 0; seed < 100; seed++) {
            final pushUp = rounds[seed];
            final squat = BotOpponent.planRound(
              Random(seed),
              battleDuration,
              passDepth: squatDepth,
              difficulty: level,
            );
            expect(
              [for (final rep in squat) (rep.at, rep.reason)],
              [for (final rep in pushUp) (rep.at, rep.reason)],
            );
            for (final (i, rep) in squat.indexed) {
              if (!rep.valid) continue;
              // The same grade at its own pass depth.
              expect(
                rep.maxDepth! / squatDepth,
                closeTo(pushUp[i].maxDepth! / pushUpDepth, 1e-9),
              );
            }
          }
        });
      });
    }

    group('the combo chance', () {
      // Only this rule puts reps exactly this far apart: the rest of the plan
      // moves each rep by a random number of microseconds.
      const comboGap = Duration(milliseconds: 1200);

      List<(RepEvent, RepEvent)> pairsAtGap(BotDifficulty level) => [
        for (final round in roundsOf(level, count: 300))
          for (var i = 1; i < round.length; i++)
            if (round[i].at - round[i - 1].at == comboGap)
              (round[i - 1], round[i]),
      ];

      test('closes a valid rep right behind a valid one', () {
        final pairs = pairsAtGap(BotDifficulty.intermediate);
        expect(pairs.length, greaterThan(100));
        for (final (before, rep) in pairs) {
          expect(before.valid, isTrue);
          expect(rep.valid, isTrue);
        }
      });

      test('is inside the combo window of the game', () {
        expect(battleRules.isCombo(comboGap), isTrue);
      });

      test('does nothing in the levels that have none', () {
        expect(pairsAtGap(BotDifficulty.beginner), isEmpty);
        expect(pairsAtGap(BotDifficulty.expert), isEmpty);
      });
    });

    test('a round of another length scales all of its counts', () {
      const long = Duration(seconds: 60);
      for (var seed = 0; seed < 200; seed++) {
        final round = BotOpponent.planRound(
          Random(seed),
          long,
          difficulty: BotDifficulty.beginner,
        );
        final valid = round.where((rep) => rep.valid).length;
        expect(valid, inInclusiveRange(10, 14), reason: 'seed $seed');
        expect(round.length - valid, inInclusiveRange(2, 6));
        expect(round.last.at, lessThan(long));
      }
    });

    group('the numbers in battle-rules.md 4.5', () {
      final beginner = roundsOf(BotDifficulty.beginner);
      final middle = roundsOf(BotDifficulty.intermediate);
      final expert = roundsOf(BotDifficulty.expert);

      test('a stronger level scores more', () {
        expect(meanPoints(beginner), closeTo(76, 3));
        expect(meanPoints(middle), closeTo(123, 3));
        expect(meanPoints(expert), closeTo(174, 4));
      });

      test('초보 has almost no combos, 중수 sometimes, 고수 most rounds', () {
        expect(shareWithCombo(beginner), lessThan(0.01));
        expect(shareWithCombo(middle), closeTo(0.48, 0.06));
        expect(shareWithCombo(expert), closeTo(0.62, 0.06));
      });
    });

    group('고수 is the bot from before there were levels', () {
      for (final MapEntry(key: seed, value: pinned)
          in _roundsBeforeLevels.entries) {
        test('seed $seed plans exactly the same round', () {
          final round = BotOpponent.planRound(
            Random(seed),
            battleDuration,
            difficulty: BotDifficulty.expert,
          );
          expect([
            for (final rep in round)
              (rep.at.inMicroseconds, rep.valid ? rep.maxDepth! : rep.reason!),
          ], pinned);
        });
      }

      test('and is what a plan or a bot with no level plays', () {
        expect(BotOpponent().difficulty, BotDifficulty.expert);
        for (var seed = 0; seed < 50; seed++) {
          expect(
            [
              for (final rep in BotOpponent.planRound(
                Random(seed),
                battleDuration,
              ))
                (rep.at, rep.reason, rep.maxDepth),
            ],
            [
              for (final rep in BotOpponent.planRound(
                Random(seed),
                battleDuration,
                difficulty: BotDifficulty.expert,
              ))
                (rep.at, rep.reason, rep.maxDepth),
            ],
          );
        }
      });
    });

    test('plays the plan of its level', () {
      fakeAsync((async) {
        final bot = BotOpponent(
          random: Random(3),
          clock: () => async.elapsed,
          difficulty: BotDifficulty.beginner,
        );
        final reps = <RepEvent>[];
        bot.reps.listen(reps.add);
        bot.start();
        async.elapse(battleDuration);
        expect(
          [for (final rep in reps) (rep.at, rep.reason, rep.maxDepth)],
          [
            for (final rep in BotOpponent.planRound(
              Random(3),
              battleDuration,
              difficulty: BotDifficulty.beginner,
            ))
              (rep.at, rep.reason, rep.maxDepth),
          ],
        );
        bot.dispose();
      });
    });

    group('forMatchup', () {
      Matchup matchup(ExerciseType exercise, Opponent opponent) =>
          Matchup(exercise: exercise, playerName: '우현', opponent: opponent);
      const bot = Opponent(name: 'RepBot', isBot: true);

      for (final level in BotDifficulty.values) {
        test('a push-up bot plays ${level.label} at the push-up depth', () {
          final opponent = BotOpponent.forMatchup(
            matchup(ExerciseType.pushUp, bot.at(level)),
          );
          expect(opponent.difficulty, level);
          expect(opponent.passDepth, const RepJudgeConfig().bottomDepth);
          opponent.dispose();
        });

        test('a squat bot plays ${level.label} at the squat depth', () {
          final opponent = BotOpponent.forMatchup(
            matchup(ExerciseType.squat, bot.at(level)),
          );
          expect(opponent.difficulty, level);
          expect(opponent.passDepth, judgeFor(ExerciseType.squat).passDepth);
          expect(opponent.passDepth, isNot(const RepJudgeConfig().bottomDepth));
          opponent.dispose();
        });
      }

      test('a bot with no level chosen plays as an expert', () {
        final opponent = BotOpponent.forMatchup(
          matchup(ExerciseType.pushUp, bot),
        );
        expect(opponent.difficulty, BotDifficulty.expert);
        opponent.dispose();
      });
    });

    // Shown, the battle would open the real camera, so no widget test reaches
    // its default view model. W5 merges #17, whose edit is on the line before:
    // this fails if that merge brings back a bot with no level.
    test('battle_screen.dart still calls BotOpponent.forMatchup', () {
      expect(
        File('lib/screens/battle_screen.dart').readAsStringSync(),
        contains('opponent: BotOpponent.forMatchup(widget.matchup),'),
      );
    });
  });

  group('planRound', () {
    final plans = [
      for (var seed = 0; seed < 200; seed++)
        BotOpponent.planRound(Random(seed), battleDuration),
    ];

    test('10 to 14 counted reps and up to 2 rejected ones', () {
      for (final (seed, plan) in plans.indexed) {
        final counted = plan.where((rep) => rep.valid).length;
        expect(counted, inInclusiveRange(10, 14), reason: 'seed $seed');
        expect(plan.length - counted, inInclusiveRange(0, 2));
        for (final rep in plan) {
          expect(rep.reason == null, rep.valid, reason: 'seed $seed');
        }
      }
      // Some rounds do mix in rejected reps.
      expect(plans.where((plan) => plan.any((rep) => !rep.valid)), isNotEmpty);
    });

    test('reps are numbered from 1 and end inside the round, in order', () {
      for (final (seed, plan) in plans.indexed) {
        expect(
          [for (final rep in plan) rep.index],
          [for (var i = 1; i <= plan.length; i++) i],
        );
        expect(plan.first.at, greaterThan(const Duration(seconds: 2)));
        expect(plan.last.at, lessThan(battleDuration));
        for (var i = 1; i < plan.length; i++) {
          expect(
            plan[i].at,
            greaterThan(plan[i - 1].at),
            reason: 'seed $seed, rep ${i + 1}',
          );
        }
      }
    });

    test('slows down towards the end', () {
      Duration meanGap(List<RepEvent> reps) =>
          (reps.last.at - reps.first.at) ~/ (reps.length - 1);
      for (final (seed, plan) in plans.indexed) {
        final third = plan.length ~/ 3;
        expect(
          meanGap(plan.sublist(plan.length - third)),
          greaterThan(meanGap(plan.sublist(0, third))),
          reason: 'seed $seed',
        );
      }
    });

    test('about a fifth of the valid reps are excellent at the push-up pass '
        'depth; the rest are good, and rejected reps have no depth', () {
      final valid = [
        for (final plan in plans) ...plan.where((rep) => rep.valid),
      ];
      final grades = [
        for (final rep in valid)
          battleRules.gradeFor(
            maxDepth: rep.maxDepth,
            passDepth: const RepJudgeConfig().bottomDepth,
          ),
      ];
      final excellent = grades.where((g) => g == GameGrade.excellent).length;
      expect(excellent / valid.length, closeTo(0.2, 0.05));
      expect(valid.every((rep) => rep.maxDepth != null), isTrue);
      for (final plan in plans) {
        for (final rep in plan.where((rep) => !rep.valid)) {
          expect(rep.maxDepth, isNull);
        }
      }
    });

    test('with no pass depth, its reps go exactly 1.4 or 1.9 deep', () {
      for (final plan in plans) {
        for (final rep in plan.where((rep) => rep.valid)) {
          expect(rep.maxDepth, anyOf(1.4, 1.9));
        }
      }
    });

    test('its rejected reps have no elbow angle, so they earn nothing', () {
      for (final plan in plans) {
        for (final rep in plan.where((rep) => !rep.valid)) {
          expect(rep.minElbowAngle, isNull);
          expect(
            battleRules.gradeOf(
              rep,
              passDepth: const RepJudgeConfig().bottomDepth,
            ),
            isNull,
          );
        }
      }
    });

    group('with a squat pass depth of 0.75', () {
      const squatDepth = 0.75;

      List<RepEvent> squatPlan(int seed) => BotOpponent.planRound(
        Random(seed),
        battleDuration,
        passDepth: squatDepth,
      );

      test('its depths scale by the same multiples', () {
        for (var seed = 0; seed < 200; seed++) {
          final squat = squatPlan(seed);
          final pushUp = plans[seed];
          for (var i = 0; i < squat.length; i++) {
            if (!squat[i].valid) continue;
            expect(
              squat[i].maxDepth! / squatDepth,
              closeTo(pushUp[i].maxDepth! / 1.1, 1e-9),
            );
          }
        }
      });

      test('about a fifth of the valid reps are excellent, not all', () {
        final valid = [
          for (var seed = 0; seed < 200; seed++)
            ...squatPlan(seed).where((rep) => rep.valid),
        ];
        final excellent = valid.where(
          (rep) =>
              battleRules.gradeFor(
                maxDepth: rep.maxDepth,
                passDepth: squatDepth,
              ) ==
              GameGrade.excellent,
        );
        expect(excellent.length / valid.length, closeTo(0.2, 0.05));
      });

      test('only the depths change: the same times and reasons', () {
        for (var seed = 0; seed < 200; seed++) {
          final squat = squatPlan(seed);
          final pushUp = plans[seed];
          expect(squat.length, pushUp.length);
          for (var i = 0; i < squat.length; i++) {
            expect(squat[i].at, pushUp[i].at);
            expect(squat[i].reason, pushUp[i].reason);
          }
        }
      });
    });

    test('the same seed plans the same round', () {
      List<(int, bool, RejectReason?, Duration, double?)> plan(int seed) => [
        for (final rep in BotOpponent.planRound(Random(seed), battleDuration))
          (rep.index, rep.valid, rep.reason, rep.at, rep.maxDepth),
      ];
      expect(plan(7), plan(7));
      expect(plan(7), isNot(plan(8)));
    });

    test('a shorter round keeps the pace: 7 to 9 counted reps in 20 s', () {
      const shortRound = Duration(seconds: 20);
      for (var seed = 0; seed < 200; seed++) {
        final plan = BotOpponent.planRound(Random(seed), shortRound);
        final counted = plan.where((rep) => rep.valid).length;
        expect(counted, inInclusiveRange(7, 9), reason: 'seed $seed');
        expect(plan.length - counted, inInclusiveRange(0, 1));
        expect(plan.last.at, lessThan(shortRound));
        for (var i = 1; i < plan.length; i++) {
          expect(plan[i].at, greaterThan(plan[i - 1].at));
        }
      }
    });
  });

  group('a round', () {
    /// The plan BotOpponent makes with Random(seed), for comparison.
    List<RepEvent> planFor(int seed) =>
        BotOpponent.planRound(Random(seed), battleDuration);

    test('plays its own pass depth; by default, the push-up one', () {
      fakeAsync((async) {
        final squat = BotOpponent(
          random: Random(1),
          clock: () => async.elapsed,
          passDepth: .75,
        );
        final pushUp = BotOpponent(
          random: Random(1),
          clock: () => async.elapsed,
        );
        final squatDepths = <double?>[], pushUpDepths = <double?>[];
        squat.reps.listen((rep) => squatDepths.add(rep.maxDepth));
        pushUp.reps.listen((rep) => pushUpDepths.add(rep.maxDepth));
        squat.start();
        pushUp.start();
        async.elapse(battleDuration);
        expect(pushUpDepths, [for (final rep in planFor(1)) rep.maxDepth]);
        expect(squatDepths, [
          for (final rep in BotOpponent.planRound(
            Random(1),
            battleDuration,
            passDepth: .75,
          ))
            rep.maxDepth,
        ]);
        expect(squatDepths, isNot(pushUpDepths));
        squat.dispose();
        pushUp.dispose();
      });
    });

    test('sends each rep at its planned time', () {
      fakeAsync((async) {
        final bot = BotOpponent(random: Random(1), clock: () => async.elapsed);
        final sent = <(int, Duration)>[];
        bot.reps.listen((rep) => sent.add((rep.index, async.elapsed)));
        bot.start();
        async.elapse(battleDuration);
        expect(sent, [for (final rep in planFor(1)) (rep.index, rep.at)]);
        bot.dispose();
      });
    });

    test('pause holds the reps; resume goes on where it stopped', () {
      fakeAsync((async) {
        final plan = planFor(2);
        final bot = BotOpponent(random: Random(2), clock: () => async.elapsed);
        final sent = <Duration>[];
        bot.reps.listen((_) => sent.add(async.elapsed));
        bot.start();
        async.elapse(const Duration(seconds: 10));
        final before = sent.length;
        bot.pause();
        async.elapse(const Duration(seconds: 5));
        expect(sent, hasLength(before));
        bot.resume();
        async.elapse(battleDuration);
        expect(sent, hasLength(plan.length));
        // Everything after the pause comes 5 seconds late.
        expect(sent[before], plan[before].at + const Duration(seconds: 5));
        expect(sent.last, plan.last.at + const Duration(seconds: 5));
        bot.dispose();
      });
    });

    test('stop ends the round; resume cannot bring it back, start plans '
        'a new one', () {
      fakeAsync((async) {
        final bot = BotOpponent(random: Random(3), clock: () => async.elapsed);
        final sent = <RepEvent>[];
        bot.reps.listen(sent.add);
        bot.start();
        async.elapse(const Duration(seconds: 10));
        final before = sent.length;
        expect(before, greaterThan(0));
        bot
          ..stop()
          ..resume();
        async.elapse(battleDuration);
        expect(sent, hasLength(before));

        bot.start();
        async.elapse(battleDuration);
        expect(sent.length, greaterThanOrEqualTo(before + 10));
        // Numbering starts over with the new round.
        expect(sent[before].index, 1);
        bot.dispose();
      });
    });

    test('pause and resume twice in a row change nothing more', () {
      fakeAsync((async) {
        final plan = planFor(4);
        final bot = BotOpponent(random: Random(4), clock: () => async.elapsed);
        final sent = <Duration>[];
        bot.reps.listen((_) => sent.add(async.elapsed));
        bot
          ..start()
          ..resume();
        async.elapse(const Duration(seconds: 3));
        bot
          ..pause()
          ..pause();
        async.elapse(const Duration(seconds: 2));
        bot
          ..resume()
          ..resume();
        async.elapse(battleDuration);
        expect(sent.last, plan.last.at + const Duration(seconds: 2));
        bot.dispose();
      });
    });
  });
}
