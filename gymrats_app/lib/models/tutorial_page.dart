import 'exercise_type.dart';

/// What one tutorial page shows, in the order a battle goes.
enum TutorialStep {
  /// The game as a whole, before either exercise: a 1v1 battle of push-ups
  /// or squats against a person or the bot (user 2026-11-15).
  welcome,

  /// The game's two ways to play: online battles for the weekly rankings,
  /// and the arcade's floors (A13).
  modes,

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

  /// Reps close together score extra (user 2026-11-15).
  combo,

  /// The last seconds, where points are multiplied.
  fever,

  /// A lead that ends the battle at once.
  ko,

  /// The result and its form feedback after the battle.
  report,
}

/// One page of the tutorial: a [step] told for one [exercise], or for the
/// whole game when [exercise] is null ([welcome], [modes]).
class TutorialPage {
  const TutorialPage(this.exercise, this.step);

  /// The first page, about the game as a whole.
  static const welcome = TutorialPage(null, TutorialStep.welcome);

  /// The second page, about online battles and the arcade.
  static const modes = TutorialPage(null, TutorialStep.modes);

  final ExerciseType? exercise;
  final TutorialStep step;

  @override
  bool operator ==(Object other) =>
      other is TutorialPage && other.exercise == exercise && other.step == step;

  @override
  int get hashCode => Object.hash(exercise, step);

  @override
  String toString() => 'TutorialPage(${exercise?.name}, ${step.name})';
}
