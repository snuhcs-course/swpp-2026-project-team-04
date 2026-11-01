import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/services/game/rep_grade.dart';
import 'package:gymrats_app/services/opponent/bot_opponent.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

void main() {
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
