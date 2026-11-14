import 'dart:async';

import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/services/feedback/feedback_stats.dart';

import 'fakes.dart';

/// A battle point for statistics tests; [playedAt] is local time.
StatsPoint statsPoint(
  int id,
  DateTime playedAt, {
  int reps = 10,
  int? score,
  ExerciseType exercise = ExerciseType.pushUp,
  Map<String, int> issues = const {},
  bool? hasFeedback,
}) => StatsPoint(
  id: id,
  exercise: exercise,
  playedAt: playedAt,
  reps: reps,
  score: score,
  issues: issues,
  hasFeedback: hasFeedback ?? issues.isNotEmpty,
);

/// [FeedbackStatsSource] returning [points], or throwing [error].
class FakeFeedbackStatsSource implements FeedbackStatsSource {
  FakeFeedbackStatsSource([this.points = const []]);

  List<StatsPoint> points;
  Exception? error;

  /// When set, each fetch waits for it, like a slow server.
  Completer<void>? gate;

  /// The arguments of each fetch, in order.
  final calls = <({ExerciseType? exercise, DateTime? since})>[];

  @override
  Future<List<StatsPoint>> fetchStatsPoints({
    ExerciseType? exercise,
    DateTime? since,
  }) async {
    calls.add((exercise: exercise, since: since));
    await gate?.future;
    if (error case final e?) throw e;
    return points;
  }
}

/// A user repository that is also a statistics source, like the server one.
class FakeStatsUserRepository extends FakeUserRepository
    implements FeedbackStatsSource {
  final stats = FakeFeedbackStatsSource();

  @override
  Future<List<StatsPoint>> fetchStatsPoints({
    ExerciseType? exercise,
    DateTime? since,
  }) => stats.fetchStatsPoints(exercise: exercise, since: since);
}
