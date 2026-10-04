import 'match_record.dart';
import 'matchup.dart';

/// A battle that ran its full time, as the result screen shows it.
///
/// BattleViewModel builds it when time runs out. The result screen receives
/// it as its route argument.
class BattleResult {
  const BattleResult({
    required this.matchup,
    required this.myReps,
    required this.myInvalidReps,
    required this.opponentReps,
    required this.endedAt,
  });

  final Matchup matchup;

  /// The user's valid reps: their score.
  final int myReps;

  /// The user's reps that did not count.
  final int myInvalidReps;

  /// The opponent's valid reps: their score.
  final int opponentReps;

  /// When time ran out, for the result screen's header.
  final DateTime endedAt;

  /// What the home screen keeps of this battle.
  MatchRecord get record => MatchRecord(
    exercise: matchup.exercise,
    opponentName: matchup.opponent.name,
    myReps: myReps,
    opponentReps: opponentReps,
  );

  MatchOutcome get outcome => record.outcome;

  /// How many reps apart the two scores are.
  int get margin => (myReps - opponentReps).abs();

  /// Share of the user's judged reps that counted, from 0 to 1. Null when
  /// none was judged.
  double? get accuracy {
    final judged = myReps + myInvalidReps;
    return judged == 0 ? null : myReps / judged;
  }
}
