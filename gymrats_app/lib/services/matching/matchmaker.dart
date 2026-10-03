import '../../models/exercise_type.dart';
import '../../models/matchup.dart';

/// Finds an opponent for a battle.
///
/// GymRatsApp creates one instance and shares it through Provider, like
/// UserRepository. Iteration 1 battles only the AI and uses BotMatchmaker;
/// a server implementation can replace it later.
abstract interface class Matchmaker {
  /// Waits until an opponent for [exercise] is found.
  ///
  /// Throws an [Exception] when no opponent can be found.
  Future<Opponent> findOpponent(ExerciseType exercise);
}
