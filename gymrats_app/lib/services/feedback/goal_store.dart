import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/exercise_type.dart';
import '../../models/feedback_goal.dart';

/// The goal each account picked for its next battle of each exercise
/// (A10 spec 5.2), kept on this phone like the character choice.
abstract interface class GoalStore {
  /// [accountId]'s goal for [exercise]; null when none is saved or the value
  /// cannot be read.
  Future<FeedbackGoal?> read(int accountId, ExerciseType exercise);

  /// Saves [goal] over the account's goal for its exercise.
  Future<void> write(int accountId, FeedbackGoal goal);

  /// Removes [accountId]'s goal for [exercise] ('사양할래').
  Future<void> clear(int accountId, ExerciseType exercise);
}

/// One JSON value per account and exercise in the phone's secure storage.
class SecureGoalStore implements GoalStore {
  SecureGoalStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String key(int accountId, ExerciseType exercise) =>
      'gymrats.goal.$accountId.${exercise.name}';

  @override
  Future<FeedbackGoal?> read(int accountId, ExerciseType exercise) async {
    try {
      final saved = await _storage.read(key: key(accountId, exercise));
      if (saved == null) return null;
      final goal = FeedbackGoal.fromJson(
        (jsonDecode(saved) as Map).cast<String, Object?>(),
      );
      // A value under another exercise's key is not this one's goal.
      return goal.exercise == exercise ? goal : null;
    } on Object {
      // A store that cannot be read (a lost key after a restore) or a value
      // of another layout is the same as no goal.
      return null;
    }
  }

  @override
  Future<void> write(int accountId, FeedbackGoal goal) => _storage.write(
    key: key(accountId, goal.exercise),
    value: jsonEncode(goal.toJson()),
  );

  @override
  Future<void> clear(int accountId, ExerciseType exercise) =>
      _storage.delete(key: key(accountId, exercise));
}

/// Keeps the goals only while the app runs. For tests and demos.
class MemoryGoalStore implements GoalStore {
  final goals = <(int, ExerciseType), FeedbackGoal>{};

  @override
  Future<FeedbackGoal?> read(int accountId, ExerciseType exercise) async =>
      goals[(accountId, exercise)];

  @override
  Future<void> write(int accountId, FeedbackGoal goal) async {
    goals[(accountId, goal.exercise)] = goal;
  }

  @override
  Future<void> clear(int accountId, ExerciseType exercise) async {
    goals.remove((accountId, exercise));
  }
}
