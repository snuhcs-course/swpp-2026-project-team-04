import 'exercise_type.dart';

/// What a goal for the next battle counts (A10 spec 5.1).
enum GoalKind {
  /// Counted reps in the whole battle, at least [FeedbackGoal.target].
  reps,

  /// Counted reps in the later half of the round, at least the target.
  lateReps,

  /// Rejected reps, at most the target.
  maxRejects,

  /// The longest combo, at least the target.
  combo,
}

/// The goal a user picked at the end of the character's talk, for their
/// next battle of [exercise] (A10 spec 5.2). One per exercise and account;
/// it is kept on this phone only.
class FeedbackGoal {
  const FeedbackGoal({
    required this.exercise,
    required this.kind,
    required this.target,
    required this.baseline,
    required this.title,
    required this.setAt,
    required this.characterId,
    required this.fromMatch,
  });

  final ExerciseType exercise;
  final GoalKind kind;

  /// The number to reach: at least it, or for [GoalKind.maxRejects] at most.
  final int target;

  /// The same value in the battle the goal was set after, e.g. its counted
  /// reps for [GoalKind.reps].
  final int baseline;

  /// The words on screen, e.g. "스쿼트 20회 인정받기".
  final String title;

  /// When the goal was picked.
  final DateTime setAt;

  /// The character the user had when picking it: the goal's card keeps
  /// showing that one after the user changes character.
  final String characterId;

  /// The id of the battle's form report ([FormReport.id]) it was set after.
  final String fromMatch;

  Map<String, Object?> toJson() => {
    'exercise': exercise.name,
    'kind': kind.name,
    'target': target,
    'baseline': baseline,
    'title': title,
    'setAt': setAt.millisecondsSinceEpoch,
    'characterId': characterId,
    'fromMatch': fromMatch,
  };

  /// Throws a [FormatException] when a value is missing or of another kind.
  factory FeedbackGoal.fromJson(Map<String, Object?> json) {
    T field<T>(String name) => switch (json[name]) {
      final T value => value,
      _ => throw FormatException('goal field "$name" is missing'),
    };
    T named<T extends Enum>(List<T> values, String name) {
      final value = values.asNameMap()[field<String>(name)];
      if (value == null) throw FormatException('unknown goal $name');
      return value;
    }

    return FeedbackGoal(
      exercise: named(ExerciseType.values, 'exercise'),
      kind: named(GoalKind.values, 'kind'),
      target: field<int>('target'),
      baseline: field<int>('baseline'),
      title: field<String>('title'),
      setAt: DateTime.fromMillisecondsSinceEpoch(field<int>('setAt')),
      characterId: field<String>('characterId'),
      fromMatch: field<String>('fromMatch'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FeedbackGoal &&
      other.exercise == exercise &&
      other.kind == kind &&
      other.target == target &&
      other.baseline == baseline &&
      other.title == title &&
      other.setAt == setAt &&
      other.characterId == characterId &&
      other.fromMatch == fromMatch;

  @override
  int get hashCode => Object.hash(
    exercise,
    kind,
    target,
    baseline,
    title,
    setAt,
    characterId,
    fromMatch,
  );

  @override
  String toString() => 'FeedbackGoal(${exercise.name}, ${kind.name} $target)';
}
