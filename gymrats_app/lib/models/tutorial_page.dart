import 'exercise_type.dart';

/// What one tutorial page shows, in the order a battle goes.
enum TutorialStep {
  /// A 1v1 battle of one exercise against a person or RepBot.
  intro,

  /// Matching the pose before the battle starts.
  setup,

  /// The battle screen: scores push the health bar.
  battle,

  /// The grades of a rep, best first.
  excellent,
  good,
  average,
  fail,

  /// The last seconds, where points are multiplied.
  fever,

  /// A lead that ends the battle at once.
  ko,

  /// The result and its form feedback after the battle.
  report,
}

/// One page of the tutorial: a [step] told for one [exercise].
class TutorialPage {
  const TutorialPage(this.exercise, this.step);

  final ExerciseType exercise;
  final TutorialStep step;

  @override
  bool operator ==(Object other) =>
      other is TutorialPage && other.exercise == exercise && other.step == step;

  @override
  int get hashCode => Object.hash(exercise, step);

  @override
  String toString() => 'TutorialPage(${exercise.name}, ${step.name})';
}
