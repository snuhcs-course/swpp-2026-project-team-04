/// How a valid rep is judged, by its depth.
enum GameGrade {
  good('Good'),
  excellent('Excellent');

  const GameGrade(this.label);

  /// Shown with the points, e.g. "Excellent +15".
  final String label;
}

/// Why a battle stopped, when it ran until someone won.
enum GameEnd { timeUp, ko }

/// What one valid rep earned.
class GameRepScore {
  const GameRepScore({
    required this.grade,
    required this.combo,
    required this.fever,
    required this.points,
  });

  final GameGrade grade;

  /// Valid reps in a row, this one included. 1 when it is not a combo.
  final int combo;

  /// Whether it landed in fever time.
  final bool fever;

  /// Points added to the player's game score.
  final int points;
}
