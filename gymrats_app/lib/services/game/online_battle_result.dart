import '../../models/battle_result.dart';
import '../../models/battle_rules.dart';
import '../../models/form_report.dart';
import '../../models/game_score.dart';
import '../../models/match_record.dart';
import '../../models/matchup.dart';
import '../../models/ranking_ladder.dart';
import '../online/online_battle_session.dart';

/// The result screen's view of an online battle the server has finished:
/// the server's scores, reps, outcome and reason, and the user's form
/// [report] from this phone.
///
/// Null while the battle has not finished, when it ended without a result
/// (cancelled, void, a connection error), and when the server gave no
/// outcome for the user. A battle the user left themself never comes here:
/// that screen closes without a result.
///
/// A battle that is not a friend battle counts in the weekly ranking (A15):
/// it carries [rankingBefore], the ranking read when it started.
BattleResult? onlineBattleResult(
  OnlineBattleSession session, {
  required String playerName,
  FormReport? report,
  RankingSnapshot? rankingBefore,
}) {
  if (session.phase != OnlinePhase.finished || session.matchUnconfirmed) {
    return null;
  }
  final outcome = switch (session.outcome) {
    'win' => MatchOutcome.win,
    'loss' => MatchOutcome.lose,
    'draw' => MatchOutcome.draw,
    _ => null,
  };
  if (outcome == null) return null;
  final reason = session.result?['reason'];
  final endedAtMs =
      (session.result?['ended_at_ms'] as int?) ?? session.serverNow;
  final fullRound = Duration(milliseconds: session.durationMs);
  final startAtMs = session.startAtMs;
  final knockout = reason == 'ko';
  final left = reason == 'forfeit' || reason == 'disconnect_timeout';
  // An older server has no game: the valid reps are the score, as on the
  // stage, and they decide a battle that ran to its end, as the record does.
  // A player leaving decides it whatever the reps.
  final noGame = session.rules == null;
  return BattleResult(
    matchup: Matchup(
      exercise: session.exercise,
      playerName: playerName,
      opponent: Opponent(
        name: session.opponent?.name ?? '상대',
        isBot: false,
        characterId: session.opponent?.character,
      ),
    ),
    myReps: session.myReps,
    myInvalidReps: session.myInvalidReps,
    opponentReps: session.opponentReps,
    myScore: noGame ? session.myReps : session.myScore,
    opponentScore: noGame ? session.opponentReps : session.opponentScore,
    end: knockout ? GameEnd.ko : GameEnd.timeUp,
    decidedOutcome: noGame && !left ? null : outcome,
    endedAt: DateTime.fromMillisecondsSinceEpoch(endedAtMs),
    roundLength: knockout && startAtMs != null
        ? BattleRules.koRoundLength(
            Duration(milliseconds: endedAtMs - startAtMs),
            fullRound,
          )
        : fullRound,
    form: report,
    departure: !left
        ? BattleDeparture.none
        : outcome == MatchOutcome.win
        ? BattleDeparture.opponentLeft
        : BattleDeparture.myConnectionLost,
    ranked: session.friendId == null,
    rankingBefore: rankingBefore,
  );
}
