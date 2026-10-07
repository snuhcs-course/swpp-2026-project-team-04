import 'exercise_type.dart';

/// How a battle ended for the user.
enum MatchOutcome {
  win('승'),
  lose('패'),
  draw('무');

  const MatchOutcome(this.label);

  /// Short label for the result badge.
  final String label;
}

/// A finished battle, seen from the user's side.
class MatchRecord {
  const MatchRecord({
    required this.exercise,
    required this.opponentName,
    required this.myReps,
    required this.opponentReps,
  });

  final ExerciseType exercise;

  /// e.g. "RepBot".
  final String opponentName;

  /// Reps counted for the user.
  final int myReps;

  /// Reps counted for the opponent.
  final int opponentReps;

  /// More reps wins; the same count is a draw.
  MatchOutcome get outcome => switch (myReps.compareTo(opponentReps)) {
    > 0 => MatchOutcome.win,
    < 0 => MatchOutcome.lose,
    _ => MatchOutcome.draw,
  };
}
