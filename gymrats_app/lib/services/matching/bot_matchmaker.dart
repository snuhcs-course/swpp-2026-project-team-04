import '../../models/bot_difficulty.dart';
import '../../models/exercise_type.dart';
import '../../models/matchup.dart';
import 'matchmaker.dart';

/// Always matches the user with the AI opponent, after a short pause that
/// looks like a search.
class BotMatchmaker implements Matchmaker {
  BotMatchmaker({this.searchTime = const Duration(seconds: 3)});

  /// How long the search seems to take.
  final Duration searchTime;

  static const bot = Opponent(name: 'RepBot', isBot: true);

  @override
  Future<Opponent> findOpponent(ExerciseType exercise) async {
    await Future<void>.delayed(searchTime);
    return bot;
  }
}

/// How a simulated user plays (P10): about [expectedReps] valid reps in a
/// round of [BotDifficulty.paceLength], the skill estimate of the account it
/// copies, give or take one.
class SimulatedUserPace implements BotPace {
  const SimulatedUserPace(this.expectedReps)
    : assert(expectedReps >= 1, 'a simulated user makes at least one rep');

  /// The copied account's estimate, as the server rounded it.
  final int expectedReps;

  @override
  int get fewestValid => expectedReps > 1 ? expectedReps - 1 : 1;
  @override
  int get mostValid => expectedReps + 1;
  @override
  int get fewestRejected => 0;
  @override
  int get mostRejected => 2;

  /// Between the AI 1v1 middle and top levels.
  @override
  double get deepShare => 0.15;
  @override
  double get comboChance => 0.05;
}
