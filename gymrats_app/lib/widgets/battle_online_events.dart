import '../models/game_score.dart';
import '../models/rep_event.dart';
import '../services/game/rep_grade.dart';
import '../services/online/online_battle_session.dart';
import 'battle_stage_model.dart';

/// What the stage last saw of the opponent's reps, to tell a new one by:
/// their latest score, their valid reps, and their reps that earned nothing.
typedef OnlineOpponentSeen = ({GameRepScore? score, int reps, int misses});

/// Turns an online battle's session into what the stage is fed. It decides
/// nothing: the grades, points, combos, the KO and the outcome are the
/// game's and the server's.
abstract final class OnlineStageEvents {
  /// The user's own [rep], read right after it was submitted: a blow with
  /// the points and combo of the phone's preview of the server's score, so
  /// the stage answers at once while the score number waits for the server.
  ///
  /// It is never the knockout blow: only the server says a KO, and its
  /// report starts the ring-out.
  static BattleStageEvent myRep(
    OnlineBattleSession session,
    RepEvent rep, {
    required double passDepth,
  }) {
    final rules = session.rules;
    if (rules == null) {
      // An older server has no game: a counted rep lands for one point.
      return BattleStageEvent(
        side: BattleSide.me,
        grade: rep.valid ? GameGrade.good : null,
        points: rep.valid ? 1 : 0,
        combo: rep.valid ? 1 : 0,
        reason: rep.valid ? null : rep.reason,
      );
    }
    final grade = rules.gradeOf(rep, passDepth: passDepth);
    // Submitting a rep that earns something makes the preview its score, the
    // game's combo included (an average rep has none).
    final score = grade == null ? null : session.myLastScore;
    return BattleStageEvent(
      side: BattleSide.me,
      grade: grade,
      points: score?.points ?? 0,
      combo: score?.combo ?? 0,
      fever: score?.fever ?? session.fever,
      reason: rep.valid ? null : rep.reason,
    );
  }

  /// What the stage has seen of the opponent's reps in [session] now.
  static OnlineOpponentSeen opponentSeen(OnlineBattleSession session) => (
    score: session.opponentLastScore,
    reps: session.opponentReps,
    misses: session.opponentMisses,
  );

  /// The opponent's rep that the server reported since [before], if any: a
  /// blow of its grade, or a swing that misses for a rep that earned
  /// nothing. The server reports one rep at a time; a reconnect snapshot
  /// counts no miss, so none is played again.
  ///
  /// The blow that brought a KO lead is flagged as the knockout: the server
  /// sends it before the report that ends the battle.
  static BattleStageEvent? opponentRep(
    OnlineOpponentSeen before,
    OnlineBattleSession session,
  ) {
    final rules = session.rules;
    final missed = session.opponentMisses > before.misses
        ? BattleStageEvent(
            side: BattleSide.opponent,
            grade: null,
            fever: session.fever,
          )
        : null;
    if (rules == null) {
      if (session.opponentReps <= before.reps) return missed;
      return const BattleStageEvent(
        side: BattleSide.opponent,
        grade: GameGrade.good,
        points: 1,
        combo: 1,
      );
    }
    final score = session.opponentLastScore;
    if (score == null || identical(score, before.score)) return missed;
    final lead = session.myScore - session.opponentScore;
    return BattleStageEvent(
      side: BattleSide.opponent,
      grade: score.grade,
      points: score.points,
      combo: score.combo,
      fever: score.fever,
      knockout: lead < 0 && rules.isKo(lead),
    );
  }

  /// How the battle ended, as the stage shows it; null while it runs and
  /// when it ended without a result (cancelled, void, a connection error).
  ///
  /// When the phone's clock has run out before the server's result, the
  /// time-up is not decided yet: "TIME!" shows and the verdict waits.
  static BattleStageEnd? endOf(OnlineBattleSession session) {
    if (session.phase == OnlinePhase.finished) {
      if (session.matchUnconfirmed) return null;
      final winner = switch (session.outcome) {
        'win' => BattleSide.me,
        'loss' => BattleSide.opponent,
        _ => null,
      };
      final known = const {'win', 'loss', 'draw'}.contains(session.outcome);
      return switch (session.result?['reason']) {
        'ko' when winner != null => BattleStageEnd(
          kind: BattleEndKind.knockout,
          winner: winner,
        ),
        'forfeit' || 'disconnect_timeout' when winner != null => BattleStageEnd(
          kind: BattleEndKind.playerLeft,
          winner: winner,
        ),
        _ => BattleStageEnd(
          kind: BattleEndKind.timeUp,
          winner: winner,
          decided: known,
        ),
      };
    }
    if (!session.terminal &&
        session.startAtMs != null &&
        session.serverNow >= session.startAtMs! &&
        session.remainingMs == 0) {
      return const BattleStageEnd(kind: BattleEndKind.timeUp, decided: false);
    }
    return null;
  }

  /// What the stage shows of [session], with the user's own [myName].
  ///
  /// While the [cameraFailed], the red danger edge stays off: the camera
  /// area then asks the user to fix the camera, and a flashing edge around
  /// that would only alarm.
  static BattleStageState stateOf(
    OnlineBattleSession session, {
    required String myName,
    bool cameraFailed = false,
  }) {
    final rules = session.rules;
    final end = endOf(session);
    final startAt = session.startAtMs;
    final phase = end != null
        ? BattleStagePhase.ended
        : switch (session.phase) {
            OnlinePhase.scheduled => BattleStagePhase.countdown,
            OnlinePhase.playing ||
            OnlinePhase.awaitingResult => BattleStagePhase.playing,
            _ => BattleStagePhase.setup,
          };
    final opponent = session.opponent;
    return BattleStageState(
      phase: phase,
      myName: myName,
      opponentName: opponent?.name ?? '상대',
      remaining: Duration(milliseconds: session.remainingMs),
      roundLength: Duration(milliseconds: session.durationMs),
      // An older server has no game: the valid reps are the score.
      myScore: rules == null ? session.myReps : session.myScore,
      opponentScore: rules == null
          ? session.opponentReps
          : session.opponentScore,
      myReps: session.myReps,
      opponentReps: session.opponentReps,
      barShare: session.myBarShare,
      fever: session.fever,
      feverMultiplier: rules?.feverMultiplier ?? 2,
      danger: session.inDanger && !cameraFailed,
      meReady: session.readyPlayers.contains(session.playerId),
      opponentReady:
          opponent != null && session.readyPlayers.contains(opponent.id),
      // Exact to the millisecond, so the numbers do not jump.
      countdown: phase == BattleStagePhase.countdown && startAt != null
          ? Duration(
              milliseconds: (startAt - session.serverNow).clamp(0, 1 << 30),
            )
          : null,
      reconnecting: !session.connected,
      opponentDisconnected: !session.opponentConnected,
      end: end,
    );
  }
}
