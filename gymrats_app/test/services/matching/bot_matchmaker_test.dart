import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/services/matching/bot_matchmaker.dart';
import 'package:gymrats_app/services/opponent/bot_opponent.dart';

void main() {
  test('finds RepBot, an AI, after about 3 seconds', () {
    fakeAsync((async) {
      Opponent? found;
      BotMatchmaker().findOpponent(ExerciseType.pushUp).then((o) => found = o);

      async.elapse(const Duration(milliseconds: 2999));
      expect(found, isNull);
      async.elapse(const Duration(milliseconds: 1));
      expect(found?.name, 'RepBot');
      expect(found?.isBot, isTrue);
    });
  });

  test('waits for the injected search time', () {
    fakeAsync((async) {
      Opponent? found;
      BotMatchmaker(searchTime: const Duration(milliseconds: 500))
          .findOpponent(ExerciseType.pushUp)
          .then((o) => found = o);

      async.elapse(const Duration(milliseconds: 499));
      expect(found, isNull);
      async.elapse(const Duration(milliseconds: 1));
      expect(found, same(BotMatchmaker.bot));
    });
  });

  group('SimulatedUserPace (P10)', () {
    test('plays the copied estimate, give or take one', () {
      const pace = SimulatedUserPace(12);
      expect(pace.fewestValid, 11);
      expect(pace.mostValid, 13);
      expect(pace.fewestRejected, 0);
      expect(pace.mostRejected, 2);
      expect(pace.deepShare, inInclusiveRange(0, 1));
      expect(pace.comboChance, inInclusiveRange(0, 1));
    });

    test('never plans fewer than one valid rep', () {
      const pace = SimulatedUserPace(1);
      expect(pace.fewestValid, 1);
      expect(pace.mostValid, 2);
    });

    test('a bot at this pace makes about that many reps', () {
      final plan = BotOpponent.planRound(
        Random(3),
        const Duration(seconds: 30),
        difficulty: const SimulatedUserPace(12),
      );
      final valid = plan.where((r) => r.valid).length;
      expect(valid, inInclusiveRange(11, 13));
    });
  });
}
