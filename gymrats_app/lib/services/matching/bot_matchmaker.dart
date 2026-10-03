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
