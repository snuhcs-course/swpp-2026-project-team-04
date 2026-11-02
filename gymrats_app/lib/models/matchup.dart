import 'bot_difficulty.dart';
import 'exercise_type.dart';

/// Who the user battles against.
class Opponent {
  const Opponent({required this.name, required this.isBot, this.difficulty});

  /// e.g. "AI 봇 · 초보".
  final String name;

  /// Whether the opponent is an AI. Screens tag it with "AI".
  final bool isBot;

  /// How hard a bot plays; null for a person, and for a bot no level was
  /// chosen for, which plays as an expert.
  final BotDifficulty? difficulty;

  /// This opponent at [difficulty]: a bot takes that level and its name, and a
  /// person stays as they are.
  Opponent at(BotDifficulty difficulty) => isBot
      ? Opponent(
          name: difficulty.opponentName,
          isBot: true,
          difficulty: difficulty,
        )
      : this;
}

/// What home or the result screen asks the matching screen to find: its route
/// argument.
class BotMatchRequest {
  const BotMatchRequest({required this.exercise, required this.difficulty});

  final ExerciseType exercise;
  final BotDifficulty difficulty;
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

  /// The same battle again: the same exercise and the same difficulty.
  BotMatchRequest get rematch => BotMatchRequest(
    exercise: exercise,
    difficulty: opponent.difficulty ?? BotDifficulty.expert,
  );
}
