import 'dart:math' as math;

import '../../models/exercise_type.dart';
import '../../models/form_report.dart';
import '../../models/match_page.dart';
import '../../models/match_record.dart';
import '../../models/user_profile.dart';
import '../feedback/form_summary.dart';
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

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Saved reports by battle id, and online reports by result id.
  final _reports = <int, FormReport>{};
  final _onlineReports = <String, FormReport>{};
  int _nextId = 1;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Gives the battle an id, like the server, and keeps [report] with it.
  @override
  Future<void> saveMatch(MatchRecord record, {FormReport? report}) async {
    final id = _nextId++;
    if (report != null) _reports[id] = report;
    _matches.insert(
      0,
      MatchRecord(
        id: id,
        exercise: record.exercise,
        opponentName: record.opponentName,
        myReps: record.myReps,
        opponentReps: record.opponentReps,
        playedAt: record.playedAt,
        decidedOutcome: record.decidedOutcome,
        feedbackSummary: report == null ? null : summarizeForm(report),
      ),
    );
  }

  /// No battle server here; the report is kept but joins no battle.
  @override
  Future<void> saveFeedback(String resultId, FormReport report) async =>
      _onlineReports[resultId] = report;

  @override
  Future<List<MatchRecord>> fetchRecent({int limit = 3}) async =>
      _matches.take(limit).toList();

  @override
  Future<FormReport?> fetchFeedback(int matchId) async => _reports[matchId];

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
