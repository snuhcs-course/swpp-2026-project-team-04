import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';

void main() {
  test('the steps go in the order of a battle', () {
    expect(TutorialStep.values, [
      TutorialStep.intro,
      TutorialStep.setup,
      TutorialStep.battle,
      TutorialStep.excellent,
      TutorialStep.good,
      TutorialStep.average,
      TutorialStep.fail,
      TutorialStep.fever,
      TutorialStep.ko,
      TutorialStep.report,
    ]);
  });

  test('pages with the same exercise and step are equal', () {
    const a = TutorialPage(ExerciseType.squat, TutorialStep.fever);
    const b = TutorialPage(ExerciseType.squat, TutorialStep.fever);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(const TutorialPage(ExerciseType.pushUp, TutorialStep.fever)),
    );
    expect(a, isNot(const TutorialPage(ExerciseType.squat, TutorialStep.ko)));
    expect(a == Object(), isFalse);
    expect(a.toString(), 'TutorialPage(squat, fever)');
  });
}
