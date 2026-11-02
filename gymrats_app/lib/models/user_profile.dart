import 'exercise_type.dart';
import 'match_record.dart';

/// The user's best battle numbers in one exercise.
class PersonalBest {
  const PersonalBest({required this.reps, this.score});

  /// Most valid reps in one battle.
  final int reps;

  /// Most game points in one battle; null when no battle kept its points.
  final int? score;

  /// Whether the best reads in points. A battle that scored nothing says less
  /// than the reps of an older one.
  bool get readsInPoints => (score ?? 0) > 0;

  /// No points and no reps: it says no more than no battle at all.
  bool get isEmpty => reps == 0 && !readsInPoints;
}

/// What the home screen shows about the user.
class UserProfile {
  const UserProfile({
    required this.name,
    this.bestReps,
    this.bests = const {},
    this.lastMatch,
    this.unsentMatches = 0,
  });

  /// Name in the greeting, e.g. "우현".
  final String name;

  /// Most reps counted in one battle, of any exercise; null before the first
  /// battle.
  final int? bestReps;

  /// The best of each exercise played. Empty with a server that sends only
  /// [bestReps].
  final Map<ExerciseType, PersonalBest> bests;

  /// The latest battle; null before the first battle.
  final MatchRecord? lastMatch;

  /// Finished battles the app could not save to the server yet. They are
  /// retried on the next load; not in [bestReps], [bests] or [lastMatch] until
  /// then.
  final int unsentMatches;

  /// The best of [exercise]; null with nothing to show, as before its first
  /// battle. A server that sends only [bestReps] kept nothing per exercise, so
  /// that number stands for push-ups, the exercise it was made for.
  PersonalBest? bestOf(ExerciseType exercise) {
    final reps = bestReps;
    final best = bests.isNotEmpty
        ? bests[exercise]
        : exercise == ExerciseType.pushUp && reps != null
        ? PersonalBest(reps: reps)
        : null;
    return best == null || best.isEmpty ? null : best;
  }
}
