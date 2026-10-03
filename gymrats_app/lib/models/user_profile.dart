import 'match_record.dart';

/// What the home screen shows about the user.
class UserProfile {
  const UserProfile({required this.name, this.bestReps, this.lastMatch});

  /// Name in the greeting, e.g. "우현".
  final String name;

  /// Most push-ups counted in one battle; null before the first battle.
  final int? bestReps;

  /// The latest battle; null before the first battle.
  final MatchRecord? lastMatch;
}
