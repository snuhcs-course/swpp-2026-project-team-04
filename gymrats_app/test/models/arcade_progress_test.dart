import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_progress.dart';

/// A progress with [stars] in the stages before [upTo] and none after.
ArcadeProgress _upTo(int upTo, {int stars = 1}) => ArcadeProgress([
  for (var stage = 1; stage <= 24; stage++) stage < upTo ? stars : 0,
]);

void main() {
  group('the first state', () {
    final progress = ArcadeProgress.initial();

    test('no star anywhere, 72 to get', () {
      expect(progress.best, List.filled(24, 0));
      expect(progress.totalStars, 0);
      expect(ArcadeProgress.maxStars, 72);
    });

    test('only stage 1 is open, and it is the one to play', () {
      expect(progress.isOpen(1), isTrue);
      expect(progress.isOpen(2), isFalse);
      expect(progress.currentStage, 1);
    });

    test('no floor cleared and no 5F', () {
      for (var floor = 1; floor <= 4; floor++) {
        expect(progress.isFloorCleared(floor), isFalse);
      }
      expect(progress.showsUnderConstruction, isFalse);
    });
  });

  group('opening stages (spec 6)', () {
    test('a stage opens once the one before it has a star', () {
      final progress = ArcadeProgress.initial().withStars(1, 1);
      expect(progress.isOpen(2), isTrue);
      expect(progress.isOpen(3), isFalse);
      expect(progress.currentStage, 2);
    });

    test('the stage to play is the first one with no star', () {
      expect(_upTo(10).currentStage, 10);
      final skipped = _upTo(10).withStars(11, 2);
      expect(skipped.currentStage, 10);
    });

    test('a stage played with no star stays the one to play', () {
      final progress = ArcadeProgress.initial().withStars(1, 0);
      expect(progress.currentStage, 1);
      expect(progress.isOpen(2), isFalse);
    });

    test('numbers outside 1 to 24 throw', () {
      final progress = ArcadeProgress.initial();
      expect(() => progress.isOpen(0), throwsRangeError);
      expect(() => progress.isOpen(25), throwsRangeError);
      expect(() => progress.bestOf(25), throwsRangeError);
      expect(() => progress.withStars(0, 1), throwsRangeError);
    });
  });

  group('floors and 5F', () {
    test('a floor is cleared by a star in its boss match', () {
      final beforeBoss = _upTo(6);
      expect(beforeBoss.isFloorCleared(1), isFalse);
      final afterBoss = beforeBoss.withStars(6, 1);
      expect(afterBoss.isFloorCleared(1), isTrue);
      expect(afterBoss.isFloorCleared(2), isFalse);
      expect(afterBoss.isOpen(7), isTrue);
    });

    test('only the boss match clears the floor', () {
      final progress = ArcadeProgress([
        for (var stage = 1; stage <= 24; stage++) stage == 12 ? 0 : 3,
      ]);
      expect(progress.isFloorCleared(2), isFalse);
      expect(progress.isFloorCleared(3), isTrue);
    });

    test('5F shows once the 4F boss match has a star', () {
      expect(_upTo(24).showsUnderConstruction, isFalse);
      expect(_upTo(24).withStars(24, 1).showsUnderConstruction, isTrue);
    });

    test('all 24 cleared: no stage left, every floor and 5F', () {
      final done = _upTo(25);
      expect(done.currentStage, isNull);
      for (var floor = 1; floor <= 4; floor++) {
        expect(done.isFloorCleared(floor), isTrue);
      }
      expect(done.showsUnderConstruction, isTrue);
      expect(done.totalStars, 24);
    });
  });

  group('stars', () {
    test('the total adds every stage, up to 72', () {
      final progress = ArcadeProgress.initial()
          .withStars(1, 3)
          .withStars(2, 2)
          .withStars(3, 1);
      expect(progress.totalStars, 6);
      expect(_upTo(25, stars: 3).totalStars, 72);
    });

    test('playing again keeps the most stars of the stage (spec 11.2)', () {
      final best = ArcadeProgress.initial().withStars(1, 3);
      expect(best.withStars(1, 1).bestOf(1), 3);
      expect(best.withStars(1, 0).bestOf(1), 3);
      expect(best.withStars(1, 1), best);
      final better = ArcadeProgress.initial().withStars(1, 1).withStars(1, 2);
      expect(better.bestOf(1), 2);
    });

    test('a count outside 0 to 3 throws', () {
      final progress = ArcadeProgress.initial();
      expect(() => progress.withStars(1, 4), throwsRangeError);
      expect(() => progress.withStars(1, -1), throwsRangeError);
    });

    test('the list cannot be changed from outside', () {
      expect(
        () => ArcadeProgress.initial().best[0] = 3,
        throwsUnsupportedError,
      );
    });
  });

  group('building one', () {
    test('needs 24 counts from 0 to 3', () {
      expect(() => ArcadeProgress(List.filled(23, 0)), throwsArgumentError);
      expect(() => ArcadeProgress(List.filled(25, 0)), throwsArgumentError);
      expect(
        () => ArcadeProgress([4, ...List.filled(23, 0)]),
        throwsArgumentError,
      );
      expect(
        () => ArcadeProgress([-1, ...List.filled(23, 0)]),
        throwsArgumentError,
      );
    });

    test('two with the same stars are equal', () {
      expect(_upTo(5), _upTo(5));
      expect(_upTo(5).hashCode, _upTo(5).hashCode);
      expect(_upTo(5), isNot(_upTo(6)));
      expect(_upTo(2).toString(), startsWith('ArcadeProgress(1,0,'));
    });
  });

  group('the saved form (spec 7)', () {
    test('is {"v":1,"best":[...]} and reads back', () {
      final progress = _upTo(4, stars: 2);
      expect(progress.toJson(), {
        'v': 1,
        'best': [2, 2, 2, ...List.filled(21, 0)],
      });
      expect(ArcadeProgress.fromJson(progress.toJson()), progress);
    });

    test('another version, length or count is not progress', () {
      List<int> best([int first = 0]) => [first, ...List.filled(23, 0)];
      for (final broken in <Object?>[
        null,
        'progress',
        [0, 0],
        {'best': best()},
        {'v': 2, 'best': best()},
        {'v': '1', 'best': best()},
        {'v': 1},
        {'v': 1, 'best': 'nope'},
        {'v': 1, 'best': List.filled(23, 0)},
        {'v': 1, 'best': best(4)},
        {'v': 1, 'best': best(-1)},
        {
          'v': 1,
          'best': [1.0, ...List.filled(23, 0)],
        },
        {
          'v': 1,
          'best': [null, ...List.filled(23, 0)],
        },
      ]) {
        expect(
          () => ArcadeProgress.fromJson(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });
  });
}
