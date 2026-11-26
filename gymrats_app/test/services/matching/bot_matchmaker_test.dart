import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/services/matching/bot_matchmaker.dart';

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
      BotMatchmaker(
        searchTime: const Duration(milliseconds: 500),
      ).findOpponent(ExerciseType.pushUp).then((o) => found = o);

      async.elapse(const Duration(milliseconds: 499));
      expect(found, isNull);
      async.elapse(const Duration(milliseconds: 1));
      expect(found, same(BotMatchmaker.bot));
    });
  });
}
