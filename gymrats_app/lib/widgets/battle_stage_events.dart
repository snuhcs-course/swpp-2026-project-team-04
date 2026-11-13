import '../models/battle_rules.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import '../models/matchup.dart';
import '../services/game/rep_grade.dart';
import '../viewmodels/battle_viewmodel.dart';
import 'battle_stage_model.dart';

/// Turns a bot battle's state into what the stage is fed. It decides
/// nothing: the grades, points, combos and the KO are the game's.
abstract final class BattleStageEvents {
  /// The reps judged between two states of a bot battle, as stage events:
  /// the user's first, then the opponent's.
  ///
  /// Call it on every change of the view model, with the state of the last
  /// call as [before], and give the events to the stage at once. At most one
  /// rep of each player is read from one change; the view model notifies for
  /// each rep, so none is lost when it is called every time.
  ///
  /// The game ends the round the moment a KO lead is reached, so the user's
  /// own KO is reported (a state with a result) one change before the rep
  /// that caused it shows up here, flagged [BattleStageEvent.knockout]. The
  /// stage plays that late blow as the ending blow.
  ///
  /// [passDepth] is the user's judge's, as the game grades with it.
  static List<BattleStageEvent> between(
    BattleState before,
    BattleState after, {
    required double passDepth,
    BattleRules rules = battleRules,
  }) {
    final events = <BattleStageEvent>[];
    final rep = after.feedback;
    if (after.feedbackCount > before.feedbackCount && rep != null) {
      final grade = rules.gradeOf(rep, passDepth: passDepth);
      // The game scored this rep before the screen heard of it, so the
      // latest score is this rep's whenever it earned something.
      final latest = after.myLastScore;
      final score = latest != null && latest.grade == grade ? latest : null;
      final fever = score?.fever ?? after.fever;
      events.add(
        BattleStageEvent(
          side: BattleSide.me,
          grade: grade,
          points: grade == null
              ? 0
              : score?.points ??
                    rules.pointsFor(grade, combo: false, fever: fever),
          combo: grade == null || grade == GameGrade.average
              ? 0
              : score?.combo ?? 1,
          fever: fever,
          reason: rep.valid ? null : rep.reason,
          knockout: grade != null && after.lead > 0 && rules.isKo(after.lead),
        ),
      );
    }
    if (after.opponentMoves > before.opponentMoves) {
      // A rep that earned nothing leaves the opponent's latest score as it
      // was: the same object.
      final score = after.opponentLastScore;
      final landed =
          score != null && !identical(score, before.opponentLastScore);
      events.add(
        BattleStageEvent(
          side: BattleSide.opponent,
          grade: landed ? score.grade : null,
          points: landed ? score.points : 0,
          combo: landed ? score.combo : 0,
          fever: landed ? score.fever : after.fever,
          knockout: landed && after.lead < 0 && rules.isKo(after.lead),
        ),
      );
    }
    return events;
  }

  /// How a bot battle ended; null while it runs, and when the user left.
  static BattleStageEnd? endOf(BattleState state) {
    final result = state.result;
    if (result == null) return null;
    return BattleStageEnd(
      kind: result.end == GameEnd.ko
          ? BattleEndKind.knockout
          : BattleEndKind.timeUp,
      winner: switch (result.outcome) {
        MatchOutcome.win => BattleSide.me,
        MatchOutcome.lose => BattleSide.opponent,
        MatchOutcome.draw => null,
      },
    );
  }

  /// What the stage shows of a bot battle's [state].
  ///
  /// Before the round the user sets up and the bot is always ready, so
  /// nobody waits for the other: once the user's pose is ready, the setup's
  /// count to the start is the countdown. While the camera has failed, the
  /// red danger edge stays off: the camera area then asks the user to fix
  /// the camera.
  static BattleStageState stateOf(
    BattleState state,
    Matchup matchup, {
    required Duration roundLength,
    BattleRules rules = battleRules,
  }) {
    final end = endOf(state);
    final startIn = state.startIn;
    final phase = end != null
        ? BattleStagePhase.ended
        : state.started
        ? BattleStagePhase.playing
        : startIn != null
        ? BattleStagePhase.countdown
        : BattleStagePhase.setup;
    return BattleStageState(
      phase: phase,
      myName: matchup.playerName,
      opponentName: matchup.opponent.name,
      remaining: state.remaining,
      roundLength: roundLength,
      myScore: state.myScore,
      opponentScore: state.opponentScore,
      myReps: state.myReps,
      opponentReps: state.opponentReps,
      barShare: state.myBarShare,
      fever: state.fever,
      feverMultiplier: rules.feverMultiplier,
      danger: state.danger && state.phase != BattlePhase.failed,
      meReady: state.setup.isReady,
      opponentReady: true,
      countdown: phase == BattleStagePhase.countdown ? startIn : null,
      end: end,
    );
  }
}
