import 'dart:math' as math;

import '../../models/battle_rules.dart';
import '../../models/exercise_type.dart';
import '../../models/feedback_goal.dart';
import '../../models/form_report.dart';
import '../../models/game_score.dart';
import '../game/player_game_score.dart';
import 'goal_store.dart';

/// How far one battle has come on a goal (A11 spec 2), counted from its reps
/// alone: the battle's chip and the next feedback's check count the same way.
///
/// The reps are the ones a form report keeps ([FormReport.reps]): each with
/// its round time and whether it counted. Nothing here judges or scores a
/// rep.
class GoalProgress {
  const GoalProgress({
    required this.kind,
    required this.target,
    required this.value,
    this.ended = false,
  });

  /// Counts [reps] for [goal]. The later half of the round starts half way
  /// through [roundLength], the full round's length: a battle that ends
  /// early by KO keeps the same half and is judged on its reps so far.
  /// [ended] says the battle is over, which a [GoalKind.maxRejects] goal
  /// needs to be reached.
  factory GoalProgress.of(
    FeedbackGoal goal,
    Iterable<RepRecord> reps, {
    required Duration roundLength,
    bool ended = false,
    BattleRules rules = battleRules,
  }) => GoalProgress(
    kind: goal.kind,
    target: goal.target,
    value: valueOf(goal.kind, reps, roundLength: roundLength, rules: rules),
    ended: ended,
  );

  final GoalKind kind;

  /// The goal's number: at least it, or for [GoalKind.maxRejects] at most.
  final int target;

  /// The battle's value of [kind] so far.
  final int value;

  /// Whether the battle is over.
  final bool ended;

  /// The battle's value of [kind] in [reps]: counted reps, counted reps in
  /// the later half, rejected reps, or the longest combo.
  static int valueOf(
    GoalKind kind,
    Iterable<RepRecord> reps, {
    required Duration roundLength,
    BattleRules rules = battleRules,
  }) => switch (kind) {
    GoalKind.reps => reps.where((rep) => rep.valid).length,
    GoalKind.lateReps =>
      reps.where((rep) => rep.valid && rep.at >= lateFrom(roundLength)).length,
    GoalKind.maxRejects => reps.where((rep) => !rep.valid).length,
    GoalKind.combo => longestCombo(reps, rules: rules),
  };

  /// Where the later half of a [roundLength] round starts: 15 s into 30 s.
  static Duration lateFrom(Duration roundLength) => roundLength ~/ 2;

  /// The longest run of counted reps in [reps], by the game's combo rule
  /// ([PlayerGameScore.combo]: at most [BattleRules.comboWindow] between
  /// two, broken by a rejected rep), as the reps close in time order.
  static int longestCombo(
    Iterable<RepRecord> reps, {
    BattleRules rules = battleRules,
  }) {
    final score = PlayerGameScore(rules);
    final ordered = [...reps]..sort((a, b) => a.at.compareTo(b.at));
    var longest = 0;
    for (final rep in ordered) {
      if (rep.valid) {
        score.addValid(GameGrade.good, rep.at);
        longest = math.max(longest, score.combo);
      } else {
        score.addRejected();
      }
    }
    return longest;
  }

  /// Whether the goal is reached: [value] at least [target], or for
  /// [GoalKind.maxRejects] at most [target] once the battle is over.
  bool get reached => switch (kind) {
    GoalKind.maxRejects => ended && value <= target,
    _ => value >= target,
  };

  /// Whether a [GoalKind.maxRejects] goal is already missed: more rejected
  /// reps than it allows.
  bool get over => kind == GoalKind.maxRejects && value > target;

  /// How much of the chip is lime, from the left, from 0 to 1. A
  /// [GoalKind.maxRejects] goal has none until it is reached at the end
  /// (task.md W11 decision 8): a fill would grow with each rejection.
  double get fill {
    if (reached) return 1;
    if (kind == GoalKind.maxRejects || target <= 0) return 0;
    return (value / target).clamp(0.0, 1.0);
  }

  /// This goal with the battle over.
  GoalProgress atEnd() =>
      GoalProgress(kind: kind, target: target, value: value, ended: true);

  /// The battle chip's words (spec 2), e.g. "목표 12/20". A
  /// [GoalKind.lateReps] goal reads "후반 목표 8" until the round is in its
  /// later half ([late]), then "후반 3/8".
  String chipText({required bool late}) => switch (kind) {
    GoalKind.reps => '목표 $value/$target',
    GoalKind.lateReps => late ? '후반 $value/$target' : '후반 목표 $target',
    GoalKind.combo => '콤보 $value/$target',
    GoalKind.maxRejects => '무효 $value/$target',
  };

  /// What a screen reader says for the chip, e.g. "이번 판 목표 20회 중
  /// 12회".
  String chipLabel({required bool late}) {
    final words = switch (kind) {
      GoalKind.reps => '이번 판 목표 $target회 중 $value회',
      GoalKind.lateReps => late ? '후반 목표 $target회 중 $value회' : '후반 목표 $target회',
      GoalKind.combo => '콤보 목표 $target 중 최고 $value',
      GoalKind.maxRejects => '무효 $target회 이하 목표, 지금 $value회',
    };
    if (reached) return '$words, 목표 달성';
    if (over) return '$words, 목표를 넘었어요';
    return words;
  }

  /// The game choice's sticker words for a goal of [kind] and [target]
  /// (spec 2), e.g. "목표 20회".
  static String stickerText(GoalKind kind, int target) => switch (kind) {
    GoalKind.reps => '목표 $target회',
    GoalKind.lateReps => '후반 $target회',
    GoalKind.combo => '콤보 $target',
    GoalKind.maxRejects => '무효 $target회 이하',
  };

  @override
  bool operator ==(Object other) =>
      other is GoalProgress &&
      other.kind == kind &&
      other.target == target &&
      other.value == value &&
      other.ended == ended;

  @override
  int get hashCode => Object.hash(kind, target, value, ended);

  @override
  String toString() =>
      'GoalProgress(${kind.name} $value/$target${ended ? ', ended' : ''})';
}

/// Follows one battle's goal as the user's reps come in, for the battle
/// screens: the progress after each rep, and the one rep that first reaches
/// a goal the stage celebrates.
class GoalTracker {
  GoalTracker(this.goal)
    : progress = GoalProgress(kind: goal.kind, target: goal.target, value: 0);

  final FeedbackGoal goal;

  /// The progress after the latest [count].
  GoalProgress progress;

  bool _celebrated = false;

  /// Counts the battle's [reps] so far in a round of [roundLength] (see
  /// [GoalProgress.of]). True only the first time a goal that shows
  /// '목표 달성!' during the battle is reached: a [GoalKind.maxRejects] goal
  /// is only decided at the end (spec 5).
  bool count(Iterable<RepRecord> reps, {required Duration roundLength}) {
    progress = GoalProgress.of(goal, reps, roundLength: roundLength);
    if (_celebrated || goal.kind == GoalKind.maxRejects || !progress.reached) {
      return false;
    }
    _celebrated = true;
    return true;
  }
}

/// [accountId]'s saved goal of each exercise in [store], for the game
/// choice (A11 spec 3): only read, never written (task.md W11 decision 6).
/// An exercise without a goal, or whose goal cannot be read, is left out.
Future<Map<ExerciseType, FeedbackGoal>> readGoals(
  GoalStore store,
  int accountId,
) async {
  final goals = <ExerciseType, FeedbackGoal>{};
  for (final exercise in ExerciseType.values) {
    try {
      final goal = await store.read(accountId, exercise);
      if (goal != null && goal.exercise == exercise) goals[exercise] = goal;
    } on Object {
      // The same as no goal.
    }
  }
  return goals;
}
