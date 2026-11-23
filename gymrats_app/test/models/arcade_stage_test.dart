import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/exercise_type.dart';

void main() {
  group('HoldPose', () {
    test('a high plank and a chair pose', () {
      expect(HoldPose.values, [HoldPose.plank, HoldPose.chair]);
      expect(HoldPose.plank.label, '하이 플랭크');
      expect(HoldPose.chair.label, '의자 자세');
    });

    test('the holds stay out of the exercises (spec 1)', () {
      expect(ExerciseType.values, [ExerciseType.pushUp, ExerciseType.squat]);
    });
  });

  group('a stage', () {
    test('says its kind', () {
      expect(ArcadeCatalog.stage(1).kind, ArcadeStageKind.fight);
      expect(ArcadeCatalog.stage(3).kind, ArcadeStageKind.hold);
      expect(ArcadeCatalog.stage(6).kind, ArcadeStageKind.boss);
    });

    test('a hold gives its star times and ends at the third', () {
      final plank = ArcadeCatalog.stage(3) as ArcadeHoldStage;
      expect(plank.pose, HoldPose.plank);
      expect(plank.starTimes, const [
        Duration(seconds: 15),
        Duration(seconds: 20),
        Duration(seconds: 30),
      ]);
      expect(plank.endsAt, const Duration(seconds: 30));
      final chair = ArcadeCatalog.stage(23) as ArcadeHoldStage;
      expect(chair.pose, HoldPose.chair);
      expect(chair.endsAt, const Duration(seconds: 45));
    });
  });

  group('ArcadeStars', () {
    test('counts the stars lit, and clears with one or more', () {
      expect(ArcadeStars.none.count, 0);
      expect(ArcadeStars.none.cleared, isFalse);
      expect(const ArcadeStars(true, false, false).count, 1);
      expect(const ArcadeStars(true, false, false).cleared, isTrue);
      expect(const ArcadeStars(true, false, true).count, 2);
      expect(const ArcadeStars(true, true, true).count, 3);
    });

    test('keeps each star lit or not, in order', () {
      expect(const ArcadeStars(true, false, true).lit, [true, false, true]);
      expect(ArcadeStars.none.lit, [false, false, false]);
    });

    test('two with the same stars are equal', () {
      expect(
        const ArcadeStars(true, true, false),
        const ArcadeStars(true, true, false),
      );
      expect(
        const ArcadeStars(true, true, false).hashCode,
        const ArcadeStars(true, true, false).hashCode,
      );
      expect(
        const ArcadeStars(true, true, false),
        isNot(const ArcadeStars(true, false, true)),
      );
      expect(const ArcadeStars(true, false, true).toString(), contains('★☆★'));
    });
  });
}
