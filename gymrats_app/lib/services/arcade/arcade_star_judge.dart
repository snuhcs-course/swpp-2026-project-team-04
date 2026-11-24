import '../../models/arcade_stage.dart';
import '../../models/battle_result.dart';
import '../../models/battle_rules.dart';
import '../../models/form_report.dart';
import '../../models/game_score.dart';
import '../../models/match_record.dart';
import '../feedback/goal_progress.dart';
import '../game/rep_grade.dart';

/// What the stars read of one battle round: the user's side of it. Nothing
/// here judges or scores a rep again (arcade spec 1).
class ArcadeRound {
  const ArcadeRound({
    required this.won,
    this.wonByKo = false,
    this.rejects = 0,
    this.longestCombo = 0,
    this.excellent = 0,
  });

  /// The round as [result] ended it, by the floor's [rules]. [passDepth] is
  /// the pass depth of the round's exercise, which grades the reps
  /// (arcade spec 5):
  ///
  /// - won: [BattleResult.outcome] is a win; by KO when [BattleResult.end]
  ///   is [GameEnd.ko] as well.
  /// - rejects: [BattleResult.myInvalidReps].
  /// - longest combo: [GoalProgress.longestCombo] of the user's reps.
  /// - excellent: the user's excellent reps, as [GameGradeCounts.ofReps]
  ///   counts them.
  ///
  /// The reps come from [BattleResult.form]; a result built without it has
  /// no combo and no excellent rep.
  factory ArcadeRound.fromBattle(
    BattleResult result, {
    required double passDepth,
    required BattleRules rules,
  }) {
    final reps = result.form?.reps ?? const <RepRecord>[];
    final won = result.outcome == MatchOutcome.win;
    return ArcadeRound(
      won: won,
      wonByKo: won && result.end == GameEnd.ko,
      rejects: result.myInvalidReps,
      longestCombo: GoalProgress.longestCombo(reps, rules: rules),
      excellent: GameGradeCounts.ofReps(
        reps,
        passDepth: passDepth,
        rules: rules,
      ).excellent,
    );
  }

  /// Whether the user won the round.
  final bool won;

  /// Whether the user won it by KO.
  final bool wonByKo;

  /// The user's reps that did not count.
  final int rejects;

  /// The user's longest run of combo reps.
  final int longestCombo;

  /// How many of the user's reps were excellent.
  final int excellent;
}

/// The stars a play of a stage lights (arcade spec 5). Pure functions: the
/// stage's numbers come from its stars.
abstract final class ArcadeStarJudge {
  /// A fight: ★ a win, ★★ a win that meets the stage's condition, ★★★ a
  /// win by KO. A loss lights none; the second and the third do not depend
  /// on each other.
  static ArcadeStars fight(ArcadeFightStage stage, ArcadeRound round) {
    if (!round.won) return ArcadeStars.none;
    return ArcadeStars(true, _meets(stage.stars[1], round), round.wonByKo);
  }

  /// A boss match of two rounds. [second] is null when the user lost the
  /// first, so there was none. ★ both won, ★★ both won with at least n
  /// excellent reps in the two, ★★★ both won by KO. Losing either round
  /// lights none, and the floor is not cleared.
  static ArcadeStars boss(
    ArcadeBossStage stage,
    ArcadeRound first,
    ArcadeRound? second,
  ) {
    if (!first.won || second == null || !second.won) return ArcadeStars.none;
    final excellent = first.excellent + second.excellent;
    return ArcadeStars(
      true,
      excellent >= stage.stars[1].n!,
      first.wonByKo && second.wonByKo,
    );
  }

  /// A hold of [held], the time really held: time stopped by a warning is
  /// left out. Star i lights once [held] reaches its seconds. A hold ended
  /// by two warnings counts the same way, with the time held until then
  /// (arcade spec 11.1, decided 2026-11-23): no star is a fail, one or more
  /// clears the stage.
  static ArcadeStars hold(ArcadeHoldStage stage, Duration held) {
    final lit = [for (final time in stage.starTimes) held >= time];
    return ArcadeStars(lit[0], lit[1], lit[2]);
  }

  static bool _meets(ArcadeStar condition, ArcadeRound round) =>
      switch (condition.kind) {
        ArcadeStarKind.maxRejects => round.rejects <= condition.n!,
        ArcadeStarKind.combo => round.longestCombo >= condition.n!,
        ArcadeStarKind.excellent => round.excellent >= condition.n!,
        ArcadeStarKind.win ||
        ArcadeStarKind.koWin ||
        ArcadeStarKind.winBothRounds ||
        ArcadeStarKind.bossExcellent ||
        ArcadeStarKind.koBothRounds ||
        ArcadeStarKind.holdSeconds => throw ArgumentError.value(
          condition.kind,
          'condition',
          'not the second star of a fight',
        ),
      };
}
