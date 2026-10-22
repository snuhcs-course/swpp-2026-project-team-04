import 'dart:math' as math;

import '../../models/exercise_type.dart';
import '../../models/match_page.dart';
import '../../models/match_record.dart';
import '../../models/user_profile.dart';
import 'user_repository.dart';

/// Sample data kept in memory, for tests and demos that need no server.
///
/// Saved battles last until the app closes.
class InMemoryUserRepository implements UserRepository {
  InMemoryUserRepository({this._name = '우현', List<MatchRecord>? matches})
    : _matches = List.of(matches ?? _sampleMatches);

  /// Latest 24 : 19, best 32.
  static const _sampleMatches = [
    MatchRecord(
      exercise: ExerciseType.pushUp,
      opponentName: 'RepBot',
      myReps: 24,
      opponentReps: 19,
    ),
    MatchRecord(
      exercise: ExerciseType.pushUp,
      opponentName: 'RepBot',
      myReps: 32,
      opponentReps: 27,
    ),
  ];

  final String _name;

  /// Newest first.
  final List<MatchRecord> _matches;

  @override
  Future<UserProfile> fetchProfile() async => UserProfile(
    name: _name,
    bestReps: _matches.isEmpty
        ? null
        : _matches.map((m) => m.myReps).reduce(math.max),
    lastMatch: _matches.firstOrNull,
  );

  @override
  Future<void> saveMatch(MatchRecord record) async =>
      _matches.insert(0, record);

  @override
  Future<MatchPage> fetchHistory({String? cursor, int limit = 20}) async {
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = math.min(start + limit, _matches.length);
    return MatchPage(
      items: _matches.sublist(start, end),
      nextCursor: end < _matches.length ? '$end' : null,
    );
  }
}
