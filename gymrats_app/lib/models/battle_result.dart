import 'battle_rules.dart';
import 'form_report.dart';
import 'game_score.dart';
import 'match_record.dart';
import 'matchup.dart';

/// A battle that ended by time or KO, as the result screen shows it.
///
/// BattleViewModel builds it when the round ends. The result screen receives
/// it as its route argument.
class BattleResult {
  const BattleResult({
    required this.matchup,
    required this.myReps,
    required this.myInvalidReps,
    required this.opponentReps,
    required this.endedAt,
    this.myScore = 0,
    this.opponentScore = 0,
    this.end = GameEnd.timeUp,
    this.decidedOutcome,
    this.roundLength = battleDuration,
    this.form,
  });

  final Matchup matchup;

  /// The user's valid reps.
  final int myReps;

  /// The user's reps that did not count.
  final int myInvalidReps;

  /// The opponent's valid reps.
  final int opponentReps;

  /// The user's game score.
  final int myScore;

  /// The opponent's game score.
  final int opponentScore;

  /// Whether time ran out or a KO ended the battle.
  final GameEnd end;

  /// The outcome by the game's rules. Null for a battle built without a
  /// game: more reps then wins.
  final MatchOutcome? decidedOutcome;

  /// When the round ended, for the result screen's header.
  final DateTime endedAt;

  /// How long the round was, for the result screen's header.
  final Duration roundLength;

  /// The user's measurements in this battle, for the form feedback. Null
  /// when the battle was built without them.
  final FormReport? form;

  /// What the home screen keeps of this battle.
  MatchRecord get record => MatchRecord(
    exercise: matchup.exercise,
    opponentName: matchup.opponent.name,
    myReps: myReps,
    opponentReps: opponentReps,
    playedAt: endedAt,
    decidedOutcome: decidedOutcome,
  );

  MatchOutcome get outcome => record.outcome;

  /// Whether the battle was played with the game, as every battle now is.
  bool get hasGame => decidedOutcome != null;

  /// The number shown big for the user: the game score, or the valid reps
  /// for a battle built without a game.
  int get myDisplayScore => hasGame ? myScore : myReps;

  /// The same for the opponent.
  int get opponentDisplayScore => hasGame ? opponentScore : opponentReps;

  /// How far apart the two big numbers are.
  int get margin => (myDisplayScore - opponentDisplayScore).abs();

  /// Share of the user's judged reps that counted, from 0 to 1. Null when
  /// none was judged.
  double? get accuracy {
    final judged = myReps + myInvalidReps;
    return judged == 0 ? null : myReps / judged;
  }
}
