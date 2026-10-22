import 'match_record.dart';

/// What the home screen shows about the user.
class UserProfile {
  const UserProfile({
    required this.name,
    this.bestReps,
    this.lastMatch,
    this.unsentMatches = 0,
  });

  /// Name in the greeting, e.g. "우현".
  final String name;

  /// Most push-ups counted in one battle; null before the first battle.
  final int? bestReps;

  /// The latest battle; null before the first battle.
  final MatchRecord? lastMatch;

  /// Finished battles the app could not save to the server yet. They are
  /// retried on the next load; not in [bestReps] or [lastMatch] until then.
  final int unsentMatches;
}
