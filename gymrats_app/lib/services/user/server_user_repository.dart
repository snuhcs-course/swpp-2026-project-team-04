import 'dart:math' as math;

import '../../models/exercise_type.dart';
import '../../models/feedback_summary.dart';
import '../../models/form_report.dart';
import '../../models/game_score.dart';
import '../../models/match_page.dart';
import '../../models/match_record.dart';
import '../../models/user_profile.dart';
import '../api/api_client.dart';
import '../auth/auth_repository.dart';
import '../feedback/form_summary.dart';
import 'user_repository.dart';

/// [UserRepository] backed by the GymRats API, for the logged-in user.
///
/// A battle that fails to upload stays in a queue for this app run and is
/// sent again before the next profile or history load. Each upload carries
/// an id made on the phone, so a retry never stores the battle twice. A
/// battle's form report rides along with it; an online battle's report is
/// queued on its own under the battle server's result id.
class ServerUserRepository implements UserRepository {
  ServerUserRepository({
    required this._api,
    required this._auth,
    math.Random? random,
  }) : _random = random ?? math.Random.secure();

  final ApiClient _api;
  final AuthRepository _auth;
  final math.Random _random;

  /// Battles not on the server yet, oldest first, each with its owner.
  final _unsent = <_Queued>[];

  @override
  Future<UserProfile> fetchProfile() async {
    await _sendQueued();
    final json = await _api.get('/users/me') as Map<String, Object?>?;
    return _read(() {
      final last = json!['last_match'];
      return UserProfile(
        name: json['nickname']! as String,
        bestReps: json['best_reps'] as int?,
        lastMatch: last == null ? null : _match(last as Map<String, Object?>),
        unsentMatches: _queuedForMe.where((q) => q.record != null).length,
      );
    });
  }

  @override
  Future<void> saveMatch(MatchRecord record, {FormReport? report}) =>
      _queue(_newId(), record, report);

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  @override
  Future<void> saveFeedback(String resultId, FormReport report) =>
      _queue(resultId, null, report);

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  @override
  Future<List<MatchRecord>> fetchRecent({int limit = 3}) async =>
      (await fetchHistory(limit: limit)).items;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  @override
  Future<FormReport?> fetchFeedback(int matchId) async {
    final Object? json;
    try {
      json = await _api.get('/matches/$matchId/feedback');
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
    return _read(
      () => FormReport.fromJson(
        ((json! as Map)['report']! as Map).cast<String, Object?>(),
      ),
    );
  }

  Future<void> _queue(
    String clientId,
    MatchRecord? record,
    FormReport? report,
  ) async {
    final accountId = _auth.session?.account.id;
    if (accountId == null) {
      throw const ApiException(ApiErrorKind.unauthorized);
    }
    final entry = (
      accountId: accountId,
      clientId: clientId,
      record: record,
      report: report,
    );
    _unsent.add(entry);
    final failure = await _sendQueued(watch: entry);
    if (failure != null) throw failure;
  }

  @override
  Future<MatchPage> fetchHistory({String? cursor, int limit = 20}) async {
    if (cursor == null) await _sendQueued();
    final json = await _api.get(
      '/matches',
      query: {'limit': '$limit', 'before': ?cursor},
    ) as Map<String, Object?>?;
    return _read(() {
      final items = (json!['items']! as List<Object?>)
          .map((m) => _match(m! as Map<String, Object?>))
          .toList();
      final next = json['next_before'] as int?;
      return MatchPage(items: items, nextCursor: next?.toString());
    });
  }

  Iterable<_Queued> get _queuedForMe {
    final me = _auth.session?.account.id;
    return _unsent.where((m) => m.accountId == me);
  }

  /// Uploads the queued battles of the logged-in user, oldest first. Stops
  /// at the first network, timeout, or server failure; the rest stay
  /// queued. A battle the server refuses (4xx) would be refused again, so
  /// it leaves the queue instead of blocking the ones after it.
  ///
  /// Returns why [watch] was not saved, or null when it was (or when no
  /// battle is watched).
  Future<Exception?> _sendQueued({_Queued? watch}) async {
    for (final queued in _queuedForMe.toList()) {
      try {
        await _send(queued);
        _unsent.remove(queued);
      } on Exception catch (e) {
        final refused = e is ApiException && e.kind == ApiErrorKind.rejected;
        if (refused) {
          _unsent.remove(queued);
          if (identical(queued, watch)) return e;
          continue;
        }
        // Stopped here: the watched battle, if any, is still queued.
        return watch == null ? null : e;
      }
    }
    return null;
  }

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// One queued upload. A battle whose report the server refuses (e.g. too
  /// large) is sent again without it, so the result itself is not lost.
  Future<void> _send(_Queued queued) async {
    final record = queued.record, report = queued.report;
    if (record == null) {
      await _api.put(
        '/matches/feedback/${queued.clientId}',
        _feedbackJson(report!),
      );
      return;
    }
    final body = _matchJson(queued.clientId, record);
    if (report == null) {
      await _api.post('/matches', body);
      return;
    }
    try {
      await _api.post('/matches', {...body, 'feedback': _feedbackJson(report)});
    } on ApiException catch (e) {
      if (e.kind != ApiErrorKind.rejected) rethrow;
      await _api.post('/matches', body);
    }
  }

  static Map<String, Object?> _feedbackJson(FormReport report) => {
    'summary': summarizeForm(report).toJson(),
    'report': report.toJson(),
  };

  Map<String, Object?> _matchJson(String clientId, MatchRecord record) => {
    'client_id': clientId,
    'exercise': _exerciseCode(record.exercise),
    'opponent_name': record.opponentName,
    'my_reps': record.myReps,
    'opponent_reps': record.opponentReps,
    'played_at': (record.playedAt ?? DateTime.now()).toUtc().toIso8601String(),
    if (record.decidedOutcome case final outcome?)
      'outcome': _outcomeCode(outcome),
    if (record.gameEnd case final end?) 'reason': _reasonCode(end),
  };

  static String _outcomeCode(MatchOutcome outcome) => switch (outcome) {
    MatchOutcome.win => 'win',
    MatchOutcome.lose => 'loss',
    MatchOutcome.draw => 'draw',
  };

  static String _reasonCode(GameEnd end) => switch (end) {
    GameEnd.timeUp => 'time_up',
    GameEnd.ko => 'ko',
  };

  static MatchRecord _match(Map<String, Object?> json) {
    final summary = json['feedback_summary'];
    return MatchRecord(
      id: json['id'] as int?,
      exercise: _exercise(json['exercise']! as String),
      opponentName: json['opponent_name']! as String,
      myReps: json['my_reps']! as int,
      opponentReps: json['opponent_reps']! as int,
      playedAt: DateTime.parse(json['played_at']! as String).toLocal(),
      decidedOutcome: _outcome(json['outcome'] as String?),
      feedbackSummary: summary == null
          ? null
          : FeedbackSummary.fromJson((summary as Map).cast<String, Object?>()),
    );
  }

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Null for a server that does not send it yet; the reps decide then.
  static MatchOutcome? _outcome(String? code) => switch (code) {
    null => null,
    'win' => MatchOutcome.win,
    'loss' => MatchOutcome.lose,
    'draw' => MatchOutcome.draw,
    _ => throw FormatException('Unknown outcome $code'),
  };

  static String _exerciseCode(ExerciseType exercise) => switch (exercise) {
    ExerciseType.pushUp => 'push_up',
  };

  static ExerciseType _exercise(String code) => switch (code) {
    'push_up' => ExerciseType.pushUp,
    _ => throw FormatException('Unknown exercise $code'),
  };

  /// Turns a response the app cannot read into a server error.
  static T _read<T>(T Function() parse) {
    try {
      return parse();
    } on Object {
      throw const ApiException(ApiErrorKind.server);
    }
  }

  /// 32 random hex digits.
  String _newId() => List.generate(
    16,
    (_) => _random.nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// A battle waiting to be uploaded, with the account it belongs to and the
/// id that makes a retried upload count once. [record] is null for an
/// online battle's feedback, which the server joins to its battle.
typedef _Queued = ({
  int accountId,
  String clientId,
  MatchRecord? record,
  FormReport? report,
});
