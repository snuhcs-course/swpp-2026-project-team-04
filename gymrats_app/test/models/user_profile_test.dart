import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/user_profile.dart';

void main() {
  test('each exercise has its own best', () {
    const profile = UserProfile(
      name: '우현',
      bestReps: 20,
      bests: {
        ExerciseType.pushUp: PersonalBest(reps: 14, score: 150),
        ExerciseType.squat: PersonalBest(reps: 20),
      },
    );
    expect(profile.bestOf(ExerciseType.pushUp)!.score, 150);
    expect(profile.bestOf(ExerciseType.pushUp)!.reps, 14);
    expect(profile.bestOf(ExerciseType.squat)!.score, isNull);
    expect(profile.bestOf(ExerciseType.squat)!.reps, 20);
  });

  test('an exercise not played has no best, whatever the other one has', () {
    const profile = UserProfile(
      name: '우현',
      bestReps: 20,
      bests: {ExerciseType.squat: PersonalBest(reps: 20)},
    );
    expect(profile.bestOf(ExerciseType.pushUp), isNull);
  });

  test("a server that sends only best_reps speaks for push-ups", () {
    const profile = UserProfile(name: '우현', bestReps: 32);
    final best = profile.bestOf(ExerciseType.pushUp)!;
    expect(best.reps, 32);
    expect(best.score, isNull);
    expect(profile.bestOf(ExerciseType.squat), isNull);
  });

  test('a best reads in points only when it scored something', () {
    expect(const PersonalBest(reps: 14, score: 150).readsInPoints, isTrue);
    expect(const PersonalBest(reps: 32).readsInPoints, isFalse);
    expect(const PersonalBest(reps: 32, score: 0).readsInPoints, isFalse);
  });

  test('before the first battle there is no best', () {
    const profile = UserProfile(name: '우현');
    expect(profile.bestOf(ExerciseType.pushUp), isNull);
    expect(profile.bestOf(ExerciseType.squat), isNull);
  });
}
