import 'dart:math' as math;

import '../../models/exercise_type.dart';
import '../../models/match_page.dart';
import '../../models/match_record.dart';
import '../../models/user_profile.dart';
import '../api/api_client.dart';
import '../auth/auth_repository.dart';
import 'user_repository.dart';

/// [UserRepository] backed by the GymRats API, for the logged-in user.
///
/// A battle that fails to upload stays in a queue for this app run and is
/// sent again before the next profile or history load. Each upload carries
/// an id made on the phone, so a retry never stores the battle twice.
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
        unsentMatches: _queuedForMe.length,
      );
    });
  }

  @override
  Future<void> saveMatch(MatchRecord record) async {
    final accountId = _auth.session?.account.id;
    if (accountId == null) {
      throw const ApiException(ApiErrorKind.unauthorized);
    }
    final entry = (accountId: accountId, clientId: _newId(), record: record);
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
        await _api.post('/matches', _matchJson(queued.clientId, queued.record));
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

  Map<String, Object?> _matchJson(String clientId, MatchRecord record) => {
    'client_id': clientId,
    'exercise': _exerciseCode(record.exercise),
    'opponent_name': record.opponentName,
    'my_reps': record.myReps,
    'opponent_reps': record.opponentReps,
    'played_at': (record.playedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };

  static MatchRecord _match(Map<String, Object?> json) => MatchRecord(
    exercise: _exercise(json['exercise']! as String),
    opponentName: json['opponent_name']! as String,
    myReps: json['my_reps']! as int,
    opponentReps: json['opponent_reps']! as int,
    playedAt: DateTime.parse(json['played_at']! as String).toLocal(),
  );

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
/// id that makes a retried upload count once.
typedef _Queued = ({int accountId, String clientId, MatchRecord record});
