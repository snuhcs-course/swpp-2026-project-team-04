import 'exercise_type.dart';

/// Who the user battles against.
class Opponent {
  const Opponent({required this.name, required this.isBot});

  /// e.g. "RepBot".
  final String name;

  /// Whether the opponent is an AI. Screens tag it with "AI".
  final bool isBot;
}

/// A battle about to start, seen from the user's side: the exercise, the
/// user, and the opponent.
///
/// MatchingScreen builds it when an opponent is found. The versus screen and
/// the battle screen receive it as their route argument.
class Matchup {
  const Matchup({
    required this.exercise,
    required this.playerName,
    required this.opponent,
  });

  final ExerciseType exercise;

  /// The user's name, e.g. "우현".
  final String playerName;

  final Opponent opponent;
}
