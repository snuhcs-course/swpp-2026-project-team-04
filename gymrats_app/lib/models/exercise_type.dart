/// Exercises a user can choose for a battle.
///
/// Only push-up is supported for now. Other exercises come in later versions.
enum ExerciseType {
  pushUp('Push-up'),
  squat('Squat');

  const ExerciseType(this.label);

  /// Human-readable name shown in the UI.
  final String label;
}
