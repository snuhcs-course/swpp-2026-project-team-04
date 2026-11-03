import '../../models/battle_rules.dart';
import '../../models/form_report.dart';
import '../../models/game_score.dart';
import '../../models/rep_event.dart';

/// Reads a judged rep for the game. The judge's verdict stays as it is: a
/// rejected rep is rejected, whatever it earns here.
///
/// Apart from `player_game_score.dart`: the battle server gets a rep's grade
/// from the phone, so it does not import this or [RepEvent].
extension RepGrading on BattleRules {
  /// Whether rejected [rep] is average: only Go lower, by its elbow angle.
  bool earnsAverage(RepEvent rep) =>
      !rep.valid &&
      rep.reason == RejectReason.insufficientDepth &&
      isAverage(rep.minElbowAngle);

  /// The grade of [rep]; null when it was rejected and earned nothing.
  GameGrade? gradeOf(RepEvent rep, {required double passDepth}) {
    if (rep.valid) {
      return gradeFor(maxDepth: rep.maxDepth, passDepth: passDepth);
    }
    return earnsAverage(rep) ? GameGrade.average : null;
  }
}

/// How many of a player's judged reps got each grade, for the result.
class GameGradeCounts {
  const GameGradeCounts({this.excellent = 0, this.good = 0, this.average = 0});

  /// Counts [reps] by the rules of the battle they were judged in.
  factory GameGradeCounts.ofReps(
    Iterable<RepRecord> reps, {
    required double passDepth,
    BattleRules rules = battleRules,
  }) {
    var excellent = 0, good = 0, average = 0;
    for (final record in reps) {
      final grade = rules.gradeOf(
        RepEvent(
          index: record.index,
          valid: record.valid,
          at: record.at,
          reason: record.reason,
          maxDepth: record.maxDepth,
          minElbowAngle: record.minElbowAngle,
        ),
        passDepth: passDepth,
      );
      switch (grade) {
        case GameGrade.excellent:
          excellent++;
        case GameGrade.good:
          good++;
        case GameGrade.average:
          average++;
        case null:
          break;
      }
    }
    return GameGradeCounts(excellent: excellent, good: good, average: average);
  }

  final int excellent;
  final int good;
  final int average;
}
