import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/opponent/bot_opponent.dart';

void main() {
  group('planRound', () {
    final plans = [
      for (var seed = 0; seed < 200; seed++)
        BotOpponent.planRound(Random(seed), battleDuration),
    ];

    test('20 to 28 counted reps and up to 3 rejected ones', () {
      for (final (seed, plan) in plans.indexed) {
        final counted = plan.where((rep) => rep.valid).length;
        expect(counted, inInclusiveRange(20, 28), reason: 'seed $seed');
        expect(plan.length - counted, inInclusiveRange(0, 3));
        for (final rep in plan) {
          expect(rep.reason == null, rep.valid, reason: 'seed $seed');
        }
      }
      // Some rounds do mix in rejected reps.
      expect(plans.where((plan) => plan.any((rep) => !rep.valid)), isNotEmpty);
    });

    test('reps are numbered from 1 and end inside the round, at least '
        '0.9 s apart', () {
      for (final (seed, plan) in plans.indexed) {
        expect(
          [for (final rep in plan) rep.index],
          [for (var i = 1; i <= plan.length; i++) i],
        );
        expect(plan.first.at, greaterThan(const Duration(seconds: 2)));
        expect(plan.last.at, lessThan(battleDuration));
        for (var i = 1; i < plan.length; i++) {
          expect(
            plan[i].at - plan[i - 1].at,
            greaterThanOrEqualTo(const Duration(milliseconds: 900)),
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

    test('the same seed plans the same round', () {
      List<(int, bool, RejectReason?, Duration)> plan(int seed) => [
        for (final rep in BotOpponent.planRound(Random(seed), battleDuration))
          (rep.index, rep.valid, rep.reason, rep.at),
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
        expect(sent.length, greaterThan(before + 20));
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
