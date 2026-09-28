/// Exercises a user can choose for a battle.
enum ExerciseType {
  pushUp('Push-up'),
  sitUp('Sit-up'),
  pullUp('Pull-up');

  const ExerciseType(this.label);

  /// Human-readable name shown in the UI.
  final String label;
}
