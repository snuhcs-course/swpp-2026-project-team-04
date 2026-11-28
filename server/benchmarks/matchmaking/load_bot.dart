/// One simulated phone for the P20 load test: it speaks the battle
/// protocol as the app does (a ping every 5 s, a pose frame every 100 ms
/// during the round, its reps as `rep.submit`) and records what it saw.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../gymrats_app/lib/services/online/pose_wire.dart';
import '../../../gymrats_app/lib/services/online/synthetic_battle_pose.dart';
import '../../lib/simulated_player.dart';
import 'load_stats.dart';

/// How every bot of a run behaves.
class BotConfig {
  const BotConfig({
    required this.url,
    this.rounds = 3,
    this.exercises = const ['push_up', 'squat'],
    this.poseIntervalMs = 100,
    this.pingIntervalMs = 5000,
    this.setupMs = (1000, 3000),
    this.readyMs = (1000, 3000),
    this.thinkMs = (2000, 8000),
    this.repsPerRound = (8, 25),
    this.connectTimeoutMs = 8000,
    this.roundTimeoutMs = 120000,
  });

  /// The battle WebSocket, e.g. `ws://127.0.0.1:8080/ws/v1/battle`.
  final Uri url;

  /// Battles each bot plays, one after another.
  final int rounds;

  /// Each round's exercise is one of these, at random.
  final List<String> exercises;

  /// As the app: a pose frame this often in the round (0 sends none), and
  /// `session.ping` this often while connected.
  final int poseIntervalMs, pingIntervalMs;

  /// Like a person (at least, at most, in ms): from `match.found` to the
  /// setup camera, from there to ready, and from a result to the next
  /// `queue.join`.
  final (int, int) setupMs, readyMs, thinkMs;

  /// The valid reps a bot plans in a round.
  final (int, int) repsPerRound;

  /// As the app (`online_battle_session.dart`): an upgrade not done in 8 s
  /// is given up.
  final int connectTimeoutMs;

  /// A round still open this long after its `queue.join` is given up.
  final int roundTimeoutMs;
}

/// One battle a bot played, or tried to.
class RoundRecord {
  RoundRecord(this.exercise);
  final String exercise;

  /// From sending `queue.join` to receiving `match.found`.
  int? queueWaitMs;

  /// Whether the opponent was a simulated player (`sim-` id), and the name
  /// it showed (a simulated one shows the copied account's nickname).
  bool? simulated;
  String? opponentName;

  /// From `match.found` to receiving `match.start`.
  int? foundToStartMs;

  /// `finished:<reason>`, `cancelled:<reason>`, `void:<reason>`, `timeout`,
  /// `socket_closed` or `stopped`.
  String outcome = 'open';

  /// This bot's own result in a finished battle: win, loss or draw.
  String? result;

  /// From sending each `rep.submit` to its `rep.accepted`.
  final repAckMs = <int>[];
  int repsSent = 0, posesSent = 0, posesReceived = 0;

  Map<String, Object?> toJson() => {
    'exercise': exercise,
    'queue_wait_ms': queueWaitMs,
    'simulated': simulated,
    'opponent_name': opponentName,
    'found_to_start_ms': foundToStartMs,
    'outcome': outcome,
    'result': result,
    'reps_sent': repsSent,
    'reps_acked': repAckMs.length,
    'poses_sent': posesSent,
    'poses_received': posesReceived,
  };
}

/// What one bot saw over its connection.
class BotRecord {
  BotRecord(this.playerId);
  final String playerId;

  /// The WebSocket upgrade, when it worked; else why it did not.
  int? connectMs;
  String? connectError;

  /// The close code when the server closed the socket before the bot was
  /// done (null when the bot closed it, or it never opened).
  int? unexpectedClose;
  final rounds = <RoundRecord>[];

  /// Codes of the `error` messages the server sent.
  final errors = <String, int>{};

  /// `rep.accepted` round trips, every round together.
  Iterable<int> get repAckMs => rounds.expand((r) => r.repAckMs);
}

/// Where a bot is, for the run's timeline.
enum BotState { idle, connecting, queued, inMatch, thinking, done }

/// One bot: [run] connects, plays [BotConfig.rounds] battles and returns
/// what it saw. It never throws.
class LoadBot {
  LoadBot({
    required this.config,
    required this.playerId,
    required this.displayName,
    required this.random,
  });

  final BotConfig config;

  /// The development token `dev:<id>:<name>` is built from these.
  final String playerId, displayName;
  final Random random;

  BotState state = BotState.idle;
  late final BotRecord record = BotRecord(playerId);

  WebSocket? _socket;
  final _done = Completer<void>();
  final _timers = <Timer>[];
  Timer? _ping;
  RoundRecord? _round;
  String? _matchId;
  int _joinedAt = 0, _foundAt = 0, _requests = 0, _frameSeq = 0;
  int _durationMs = 30000;
  bool _closing = false;

  /// A request whose answer [_finish] waits for (at most a second).
  String? _awaiting;

  /// Server time minus local time, from `clock.sync`.
  int _offset = 0;
  final _clockSent = <String, int>{};
  final _repSent = <String, int>{};

  static int get _now => DateTime.now().millisecondsSinceEpoch;
  int _between((int, int) range) =>
      range.$1 + random.nextInt(range.$2 - range.$1 + 1);

  Future<BotRecord> run() async {
    // Stopped before its turn to start (the run's stop time came first).
    if (_done.isCompleted) {
      record.connectError ??= 'stopped';
      return record;
    }
    state = BotState.connecting;
    final clock = Stopwatch()..start();
    final pending = _connect();
    try {
      _socket = await pending.timeout(
        Duration(milliseconds: config.connectTimeoutMs),
      );
    } on TimeoutException {
      record.connectError = 'timeout';
      // The upgrade goes on after the timeout: close it if it still opens,
      // so no uncounted connection stays on the server.
      unawaited(
        pending.then<void>(
          (late) => late.close(1000, 'timeout'),
          onError: (_) {},
        ),
      );
    } on _Refused catch (e) {
      record.connectError = '${e.status}';
    } catch (e) {
      record.connectError = e.runtimeType.toString();
    }
    final socket = _socket;
    if (socket != null && _done.isCompleted) {
      // Stopped while connecting: close what opened, count no connection.
      _socket = null;
      unawaited(socket.close(1000, 'stopped'));
      record.connectError = 'stopped';
      state = BotState.done;
      return record;
    }
    if (socket == null) {
      if (_done.isCompleted) record.connectError ??= 'stopped';
      state = BotState.done;
      if (!_done.isCompleted) _done.complete();
      return record;
    }
    record.connectMs = clock.elapsedMilliseconds;
    socket.pingInterval = const Duration(seconds: 5);
    socket.listen(_receive, onDone: _closed, onError: (_) => _closed());
    _ping = Timer.periodic(
      Duration(milliseconds: config.pingIntervalMs),
      (_) => _request('session.ping', {}),
    );
    final rid = _request('clock.sync', {'client_sent_ms': _now});
    _clockSent[rid] = _now;
    _startRound();
    await _done.future;
    return record;
  }

  /// Ends the bot now: its open round is recorded as `stopped`.
  void stop() {
    if (_done.isCompleted) return;
    if (_round != null) _endRound('stopped', next: false);
    _finish();
  }

  /// The WebSocket upgrade by hand, so a refusal keeps its HTTP status
  /// (401 bad token, 503 server stopping), which [WebSocket.connect] drops.
  Future<WebSocket> _connect() async {
    final client = HttpClient();
    try {
      final url = config.url.replace(
        scheme: config.url.scheme == 'wss' ? 'https' : 'http',
      );
      final request = await client.getUrl(url);
      final key = base64.encode(List.generate(16, (_) => random.nextInt(256)));
      request.headers
        ..set(HttpHeaders.connectionHeader, 'Upgrade')
        ..set(HttpHeaders.upgradeHeader, 'websocket')
        ..set('Sec-WebSocket-Key', key)
        ..set('Sec-WebSocket-Version', '13')
        ..set(
          HttpHeaders.authorizationHeader,
          'Bearer dev:$playerId:$displayName',
        );
      final response = await request.close();
      if (response.statusCode != HttpStatus.switchingProtocols) {
        await response.drain<void>();
        throw _Refused(response.statusCode);
      }
      return WebSocket.fromUpgradedSocket(
        await response.detachSocket(),
        serverSide: false,
      );
    } finally {
      client.close();
    }
  }

  String _request(String type, Map<String, dynamic> payload) {
    final rid = '$playerId-${++_requests}';
    _send({
      'v': 1,
      'type': type,
      'request_id': rid,
      if (_matchId case final id?
          when type.startsWith('match.') || type == 'rep.submit')
        'match_id': id,
      'payload': payload,
    });
    return rid;
  }

  void _send(Map<String, dynamic> message) {
    final socket = _socket;
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(jsonEncode(message));
    }
  }

  void _later(int ms, void Function() action) =>
      _timers.add(Timer(Duration(milliseconds: max(ms, 0)), action));

  void _startRound() {
    if (_done.isCompleted) return;
    final exercise = config.exercises[random.nextInt(config.exercises.length)];
    final round = _round = RoundRecord(exercise);
    _frameSeq = 0;
    state = BotState.queued;
    _joinedAt = _now;
    _request('queue.join', {'exercise': exercise, 'accept_virtual': true});
    _later(config.roundTimeoutMs, () {
      if (_round != round) return;
      // The bot closes only once the server answered (at most 1 s): see
      // "Findings" in docs/iteration-5/matchmaking-load.md.
      _awaiting = _matchId == null
          ? _request('queue.cancel', {'queue_id': playerId})
          : _request('match.leave', {'reason': 'user_exit'});
      _endRound('timeout');
    });
  }

  void _receive(dynamic data) {
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(data as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = message['type'] as String?;
    final payload =
        (message['payload'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rid = message['request_id'] as String?;
    final round = _round;
    if (rid != null && rid == _awaiting) {
      _awaiting = null;
      if (state == BotState.done) _finish();
    }
    switch (type) {
      case 'clock.synced':
        final sent = _clockSent.remove(rid);
        final at = payload['server_received_ms'];
        if (sent != null && at is int) _offset = at - (sent + _now) ~/ 2;
      case 'match.found':
        if (round == null || _matchId != null) return;
        _matchId = message['match_id'] as String?;
        _foundAt = _now;
        _durationMs = payload['duration_ms'] as int? ?? _durationMs;
        round.queueWaitMs = _foundAt - _joinedAt;
        final players = (payload['players'] as List? ?? const []).cast<Map>();
        final opponent = players.where((p) => p['player_id'] != playerId);
        round.simulated = opponent.any(
          (p) => SimulatedPlayer.isSimulatedId(p['player_id'] as String),
        );
        round.opponentName = opponent.isEmpty
            ? null
            : opponent.first['display_name'] as String?;
        state = BotState.inMatch;
        final setup = _between(config.setupMs);
        _later(setup, () {
          if (_round == round) _request('match.setup', {});
        });
        _later(setup + _between(config.readyMs), () {
          if (_round == round) _request('match.ready', {'ready': true});
        });
      case 'match.start':
        if (round == null || round.foundToStartMs != null) return;
        round.foundToStartMs = _now - _foundAt;
        _play(round, payload['start_at_ms'] as int);
      case 'rep.accepted':
        final sent = _repSent.remove(rid);
        if (sent != null) round?.repAckMs.add(_now - sent);
      case 'pose.frame':
        if (round != null) round.posesReceived++;
      case 'error':
        final code = payload['code'];
        tally(record.errors, code is String ? code : 'unknown');
        _repSent.remove(rid);
      case 'match.finished':
        if (round == null || message['match_id'] != _matchId) return;
        final me = (payload['players'] as List? ?? const []).cast<Map>().where(
          (p) => p['player_id'] == playerId,
        );
        round.result = me.isEmpty ? null : me.first['outcome'] as String?;
        _endRound('finished:${payload['reason']}');
      case 'match.cancelled' || 'match.void':
        if (round == null || message['match_id'] != _matchId) return;
        _endRound('${type!.substring(6)}:${payload['reason']}');
    }
  }

  /// Sends [round]'s reps and pose frames from [startAt] (server time).
  void _play(RoundRecord round, int startAt) {
    final plan = SimulatedPlayer(
      displayName: displayName,
      expectedReps: _between(config.repsPerRound),
      playerSkill: 0,
    ).planReps(random, durationMs: _durationMs);
    final localStart = startAt - _offset;
    for (final rep in plan) {
      _later(localStart + (rep['elapsed_ms'] as int) - _now, () {
        if (_round != round) return;
        round.repsSent++;
        _repSent[_request('rep.submit', rep)] = _now;
      });
    }
    if (config.poseIntervalMs <= 0) return;
    _later(localStart - _now, () {
      if (_round != round) return;
      late final Timer frames;
      frames = Timer.periodic(Duration(milliseconds: config.poseIntervalMs), (
        _,
      ) {
        final elapsed = _now + _offset - startAt;
        if (_round != round || elapsed >= _durationMs) {
          frames.cancel();
          return;
        }
        round.posesSent++;
        _send({
          'v': 1,
          'type': 'pose.frame',
          'match_id': _matchId,
          'payload': encodeBattlePose(
            syntheticBattlePose(elapsed),
            sequence: ++_frameSeq,
            elapsedMs: max(elapsed, 0),
          ),
        });
      });
      _timers.add(frames);
    });
  }

  void _endRound(String outcome, {bool next = true}) {
    final round = _round;
    if (round == null) return;
    round.outcome = outcome;
    record.rounds.add(round);
    _round = null;
    _matchId = null;
    _repSent.clear();
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    if (!next) return;
    if (record.rounds.length >= config.rounds) {
      _finish();
      return;
    }
    state = BotState.thinking;
    _later(_between(config.thinkMs), _startRound);
  }

  void _closed() {
    if (!_closing) record.unexpectedClose = _socket?.closeCode ?? 0;
    if (_round != null) _endRound('socket_closed', next: false);
    _finish();
  }

  void _finish() {
    if (_done.isCompleted) return;
    _closing = true;
    state = BotState.done;
    _ping?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    if (_awaiting != null && _socket?.readyState == WebSocket.open) {
      _timers.add(
        Timer(const Duration(seconds: 1), () {
          _awaiting = null;
          _finish();
        }),
      );
      return;
    }
    unawaited(_socket?.close(1000, 'done'));
    _done.complete();
  }
}

/// The server answered the upgrade with [status] instead of 101.
class _Refused implements Exception {
  const _Refused(this.status);
  final int status;
}
