import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../models/exercise_type.dart';
import '../../shared/battle_protocol.dart';
import '../api/api_client.dart';
import '../friends/friend_repository.dart';
import '../online/online_battle_session.dart';
import '../pose/setup_checker.dart';

/// The app's version in every event; set at build time with
/// `--dart-define=GYMRATS_VERSION=...`, else the pubspec version.
const telemetryAppVersion = String.fromEnvironment(
  'GYMRATS_VERSION',
  defaultValue: '1.0.0+1',
);

/// The three things P6 measures from the app, each as a start and an end
/// joined by an attempt id: the tutorial, the pose setup and matching.
enum TelemetryFlow {
  tutorial('tutorial_started', 'tutorial_finished', 'duration_ms'),
  setup('setup_started', 'setup_finished', 'duration_ms'),
  matching('matching_started', 'matching_finished', 'wait_ms');

  const TelemetryFlow(this.startEvent, this.endEvent, this.timeField);

  final String startEvent;
  final String endEvent;

  /// Where the end event carries the time since the start.
  final String timeField;
}

/// How a batch went: [delivered] (stored, or refused one by one by the
/// server), [refused] (the whole batch, which would fail again), [later]
/// (no connection, a server error, or the server not there yet) or
/// [unauthorized] (no login the server takes: wait for the next one).
enum TelemetrySendResult { delivered, refused, later, unauthorized }

/// Sends one batch of events.
typedef TelemetrySend = Future<TelemetrySendResult> Function(
  List<Map<String, Object?>> batch,
);

/// The [SetupReason] as P6's snake_case value; null for [SetupReason.ready].
String? setupReasonCode(SetupReason reason) => reason == SetupReason.ready
    ? null
    : reason.name.replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '_${m[0]!.toLowerCase()}',
      );

/// One tutorial, pose setup or matching, from its start to its end.
///
/// The start is recorded when it is made; [finish] records the end once,
/// with the time since the start, and does nothing after that. A screen can
/// therefore call it from every way out and from `dispose` too.
class TelemetryAttempt {
  TelemetryAttempt._(this._telemetry, this.flow, this.id)
    : _started = _telemetry._now();

  final Telemetry _telemetry;
  final TelemetryFlow flow;
  final String id;
  final DateTime _started;
  bool _finished = false;

  bool get finished => _finished;

  /// Records the end with [result] and the event's other [fields].
  void finish(String result, [Map<String, Object?> fields = const {}]) {
    if (_finished) return;
    _finished = true;
    final elapsed = _telemetry._now().difference(_started).inMilliseconds;
    _telemetry._record(flow.endEvent, {
      'attempt_id': id,
      'result': result,
      // A clock set back mid-way would give a negative time.
      flow.timeField: math.max(0, elapsed),
      ...fields,
    });
  }
}

/// P17: records P6's telemetry events and sends them to the server.
///
/// Each event gets the common fields (an event id, the time in UTC, this
/// app run's session id and the app version) and only the fields its
/// screen gives; the account is added by the server. Nothing else is ever
/// put in: no camera frames, no joints, no tokens or e-mail.
///
/// Events wait in [pending] and are sent in batches of [batchSize] a short
/// while after they are recorded. When sending has to wait (logged out, no
/// connection, server down) they stay, up to [maxPending], the oldest
/// dropped first, and are written to the phone so the next app start sends
/// them. Without [send] nothing is sent (tests, and before setup).
///
/// Each event belongs to the account signed in when it was recorded
/// ([owner]; one recorded signed out goes with the next login), and is only
/// sent with that account's login: another account signing in on the same
/// phone never sends them as its own.
class Telemetry {
  Telemetry({
    this._send,
    this._root,
    this._owner,
    math.Random? random,
    DateTime Function()? now,
    this.flushDelay = const Duration(seconds: 3),
    this.retryDelay = const Duration(seconds: 30),
    this.maxPending = 200,
    this.batchSize = 100,
  }) : _random = random ?? math.Random.secure(),
       _now = now ?? DateTime.now {
    sessionId = _uuid();
    // Read before anything is written, so this run's first event does not
    // overwrite what an earlier run left.
    _writing = _readSaved();
  }

  final TelemetrySend? _send;
  final Future<String?> Function()? _root;

  /// The signed-in account, as any stable key; null while signed out.
  final String? Function()? _owner;

  /// Where an event keeps its account on the phone; never sent.
  static const _ownerKey = '_owner';
  final math.Random _random;
  final DateTime Function() _now;
  final Duration flushDelay, retryDelay;
  final int maxPending, batchSize;

  /// New for every app run.
  late final String sessionId;

  final _pending = <Map<String, Object?>>[];
  Timer? _timer;
  bool _flushing = false;
  bool _disposed = false;

  /// The events not sent yet, oldest first, as they will be sent.
  List<Map<String, Object?>> get pending => List.unmodifiable([
    for (final e in _pending) {...e}..remove(_ownerKey),
  ]);

  /// Starts [flow] and records its start event with [fields].
  TelemetryAttempt begin(TelemetryFlow flow, Map<String, Object?> fields) {
    final attempt = TelemetryAttempt._(this, flow, _uuid());
    _record(flow.startEvent, {'attempt_id': attempt.id, ...fields});
    return attempt;
  }

  void _record(String event, Map<String, Object?> fields) {
    if (_disposed) return;
    _pending.add({
      _ownerKey: ?_owner?.call(),
      'event': event,
      'event_id': _uuid(),
      'ts': _now().toUtc().toIso8601String(),
      'session_id': sessionId,
      'app_version': telemetryAppVersion,
      ...fields,
    });
    if (_pending.length > maxPending) {
      _pending.removeRange(0, _pending.length - maxPending);
    }
    _save();
    _schedule(flushDelay);
  }

  void _schedule(Duration delay) {
    if (_send == null || _disposed || _timer != null) return;
    _timer = Timer(delay, () {
      _timer = null;
      flush();
    });
  }

  /// Sends the signed-in account's pending events, a batch at a time, and
  /// stops at the first batch that has to wait: tried again after
  /// [retryDelay], or, without a login the server takes, at the next one
  /// (the app calls this on every login).
  Future<void> flush() async {
    final send = _send;
    if (send == null || _flushing || _disposed) return;
    final owner = _owner == null ? null : _owner();
    // Signed out: everything waits for a login.
    if (_owner != null && owner == null) return;
    _flushing = true;
    try {
      while (!_disposed) {
        // A switch to another account mid-way stops here: the rest waits
        // for its own login.
        if ((_owner == null ? null : _owner()) != owner) return;
        final batch = _pending
            .where((e) => e[_ownerKey] == null || e[_ownerKey] == owner)
            .take(batchSize)
            .toList();
        if (batch.isEmpty) return;
        TelemetrySendResult result;
        try {
          result = await send([
            for (final e in batch) {...e}..remove(_ownerKey),
          ]);
        } on Object {
          result = TelemetrySendResult.later;
        }
        if (result == TelemetrySendResult.unauthorized) return;
        if (result == TelemetrySendResult.later) {
          _schedule(retryDelay);
          return;
        }
        // Only what was sent: events recorded meanwhile stay.
        _pending.removeWhere((e) => batch.any((b) => identical(b, e)));
        _save();
      }
    } finally {
      _flushing = false;
    }
  }

  /// Done once the events an earlier app run could not send are read; they
  /// go before this run's.
  Future<void> load() => _writing;

  Future<void> _readSaved() async {
    final file = await _file();
    if (file == null || !await file.exists()) return;
    try {
      final saved = jsonDecode(await file.readAsString());
      if (saved is! List) return;
      _pending.insertAll(0, [
        for (final e in saved)
          if (e is Map) Map<String, Object?>.from(e),
      ]);
      if (_pending.length > maxPending) {
        _pending.removeRange(0, _pending.length - maxPending);
      }
      if (_pending.isNotEmpty) _schedule(flushDelay);
    } on FormatException {
      // A broken file is dropped, not retried.
      await file.delete();
    } on FileSystemException {
      // Unreadable: this run's events are still kept and sent.
    }
  }

  Future<File?> _file() async {
    final root = await _root?.call();
    if (root == null) return null;
    return File('$root${Platform.pathSeparator}telemetry_pending.json');
  }

  late Future<void> _writing;

  void _save() {
    if (_root == null) return;
    _writing = _writing.then((_) async {
      final file = await _file();
      if (file == null) return;
      // Taken now, after the earlier run's events were read in, not when
      // the write was asked for: otherwise this run's first event would
      // write a file without them.
      final snapshot = jsonEncode(_pending);
      try {
        await file.writeAsString(snapshot, flush: true);
      } on FileSystemException {
        // Kept in memory; the phone copy is only for the next start.
      }
    });
  }

  /// Waits for the last write to the phone (tests).
  Future<void> saved() => _writing;

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  /// A random (version 4) UUID.
  String _uuid() {
    final b = List.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

String _exerciseCode(ExerciseType exercise) =>
    exercise == ExerciseType.squat ? 'squat' : 'push_up';

/// One pose setup as P6's setup_started and setup_finished (P17): what it
/// was, what the checker last asked for, and how it ended. The screens tell
/// it what happens; it decides what that means and records the end once.
class SetupTelemetry {
  SetupTelemetry._(this._attempt, this._limit);

  /// The bot battle's setup: no time limit.
  factory SetupTelemetry.bot(Telemetry? telemetry, ExerciseType exercise) =>
      SetupTelemetry._(
        telemetry?.begin(TelemetryFlow.setup, {
          'exercise': _exerciseCode(exercise),
          'mode': 'bot',
        }),
        null,
      );

  /// An online battle's setup, main queue or friend, with the server's
  /// setup time.
  factory SetupTelemetry.online(
    Telemetry? telemetry,
    OnlineBattleSession session,
  ) => SetupTelemetry._(
    telemetry?.begin(TelemetryFlow.setup, {
      'exercise': _exerciseCode(session.exercise),
      'mode': session.friendId == null ? 'main' : 'friend',
    }),
    battleSetupTimeout,
  );

  final TelemetryAttempt? _attempt;
  final Duration? _limit;
  SetupReason? _last;

  bool get finished => _attempt?.finished ?? true;

  /// What the checker asks for now; [SetupReason.ready] keeps the last ask.
  void saw(SetupReason? reason) {
    if (reason != null && reason != SetupReason.ready) _last = reason;
  }

  void ready() => _end('ready');
  void timedOut() => _end('timeout');
  void cancelled() => _end('cancelled');

  /// An online setup from the session: ready once the server set the start;
  /// before it, the setup or ready time running out is a timeout and any
  /// other end (opponent left, connection lost) cancelled.
  void follow(OnlineBattleSession session) {
    if (finished) return;
    if (session.startAtMs != null) {
      ready();
    } else if (session.terminal) {
      session.setupTimedOut || session.result?['reason'] == 'ready_timeout'
          ? timedOut()
          : cancelled();
    }
  }

  void _end(String result) {
    final last = _last;
    _attempt?.finish(result, {
      'limit_ms': _limit?.inMilliseconds,
      'last_reason': last == null ? null : setupReasonCode(last),
    });
  }
}

/// One search for an opponent as P6's matching_started and
/// matching_finished (P17). It starts when the queue takes the join and ends
/// once: found, cancelled by the user (or a friend who declined), timed out
/// (a friend who did not come) or failed.
class MatchingTelemetry {
  MatchingTelemetry(
    this._telemetry, {
    required this.exercise,
    required this.friend,
  });

  final Telemetry? _telemetry;
  final ExerciseType exercise;

  /// A friend battle (P9), not the main queue.
  final bool friend;
  TelemetryAttempt? _attempt;

  /// Started and not ended yet.
  bool get searching => !(_attempt?.finished ?? true);

  /// Follows [session]: its first queued state starts the search (a
  /// reconnect queues again without starting another); an opponent ends it
  /// found, and an end without one as an error.
  void follow(OnlineBattleSession session) {
    if (_attempt == null && session.phase == OnlinePhase.queued) {
      _attempt = _telemetry?.begin(TelemetryFlow.matching, {
        'exercise': _exerciseCode(exercise),
        'kind': friend ? 'friend' : 'main',
      });
    }
    if (session.opponent != null) {
      _attempt?.finish('found');
    } else if (session.terminal) {
      _attempt?.finish('error');
    }
  }

  /// The friend's invite ended the wait, as [status] last read: declined or
  /// taken back is cancelled, not accepted in time (or never paired after
  /// it) a timeout, and an invite that was never sent ([status] null) an
  /// error.
  void inviteEnded(InviteStatus? status) => _attempt?.finish(switch (status) {
    null => 'error',
    InviteStatus.declined || InviteStatus.cancelled => 'cancelled',
    _ => 'timeout',
  });

  /// The login ran out while searching.
  void failed() => _attempt?.finish('error');

  /// The user stopped searching (cancel, back, leaving, a new invite).
  void stopped() => _attempt?.finish('cancelled');
}

/// Sends batches to `POST /telemetry/events` with [api]'s login.
///
/// It does not go through [ApiClient]'s requests: a rejected token there
/// logs the user out, and telemetry must never do that. Logged out, or with
/// a token the server no longer takes, the events wait for the next login.
TelemetrySend httpTelemetrySender(
  ApiClient api, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 10),
}) {
  final sender = client ?? _defaultClient;
  return (batch) async {
    final token = api.token;
    if (token == null) return TelemetrySendResult.unauthorized;
    final uri = Uri.parse('${api.baseUrl}/telemetry/events');
    final http.Response response;
    try {
      response = await sender
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'events': batch}),
          )
          .timeout(timeout);
    } on Object {
      return TelemetrySendResult.later;
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return TelemetrySendResult.delivered;
    if (status == 401) return TelemetrySendResult.unauthorized;
    // Rate and server problems pass, and so does a server without the
    // telemetry API yet (404): anything else would fail again.
    if (status == 404 || status == 408 || status == 429 || status >= 500) {
      return TelemetrySendResult.later;
    }
    return TelemetrySendResult.refused;
  };
}

final _defaultClient = http.Client();
