import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../gymrats_app/lib/models/battle_rules.dart';
import '../../gymrats_app/lib/models/character_rig.dart';
import '../../gymrats_app/lib/models/game_score.dart';
import '../../gymrats_app/lib/services/game/player_game_score.dart';
import '../../gymrats_app/lib/shared/battle_protocol.dart';
import 'result_store.dart';
import 'simulated_player.dart';
import 'skill_matchmaker.dart';

String _signature(dynamic value) {
  dynamic canonical(dynamic v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(v[key])};
    }
    if (v is List) return v.map(canonical).toList();
    return v;
  }

  return jsonEncode(canonical(value));
}

class BattleIdentity {
  const BattleIdentity(this.id, this.name);
  final String id, name;
}

typedef BattleAuthenticator = FutureOr<BattleIdentity?> Function(String token);

/// Writes one frame if the peer is still connected. The socket listener owns
/// disconnect and reconnect handling, including when a write loses the race.
void sendBattleFrame(WebSocket? socket, Map<String, dynamic> message) {
  if (socket == null || socket.readyState != WebSocket.open) return;
  final frame = jsonEncode(message);
  try {
    socket.add(frame);
  } on StateError {
    // The outgoing sink can be closed before readyState reflects the close.
    return;
  } on IOException {
    // The transport lost the peer before the frame could be written.
    return;
  }
}

class _Player {
  _Player(this.identity);
  final BattleIdentity identity;
  WebSocket? socket;
  _Match? match;

  /// What the player sent in `avatar_id` (W3: their character id),
  /// passed on as it came; null when they sent none.
  String? avatar;
  String exercise = 'push_up';

  /// The friend this player waits for (`friend_id`, P9); null in the main
  /// queue.
  String? friend;
  bool queued = false;

  /// Whether the player takes a simulated opponent after [BattleServer.
  /// virtualAfterMs] in the main queue (P10, `accept_virtual`); an older
  /// app does not ask and keeps waiting.
  bool acceptVirtual = false;

  /// When the player's latest `queue.join` was accepted.
  int queuedAt = 0;
  int lastHeartbeat = 0, rateAt = 0, controls = 0, poseAt = -1000;
  final requests =
      <String, ({String signature, Map<String, dynamic> response})>{};
}

/// A simulated player in a match (P10): when it opens its setup and gets
/// ready, and the reps it makes, played by the server's ticks.
class _Simulation {
  _Simulation(this.player, this.reps, this.setupAt, this.readyAt);
  final _Player player;
  final List<Map<String, dynamic>> reps;
  final int setupAt, readyAt;

  /// The index in [reps] of the next rep to make.
  int next = 0;
}

class _Match {
  _Match(this.id, this.players, this.created, this.readyDeadline)
    : roster = [
        for (final p in players)
          {
            'player_id': p.identity.id,
            'display_name': p.identity.name,
            if (p.avatar case final avatar?) 'avatar_id': avatar,
          },
      ];
  final String id;
  final List<_Player> players;
  final List<Map<String, dynamic>> roster;
  final int created, readyDeadline;
  final ready = <String>{};

  /// Players whose setup camera is on (`match.setup`); once both are,
  /// [setupDeadline] is set and the setup time counts.
  final setupOpen = <String>{};
  int? setupDeadline;
  final scores = <String, List<int>>{};
  final games = <String, PlayerGameScore>{};
  final reps = <String, Map<int, Map<String, dynamic>>>{};
  final poseSeq = <String, int>{},
      lastRepElapsed = <String, int>{},
      disconnected = <String, int>{};
  String status = 'preparing';
  int? start, end, ended;
  Map<String, dynamic>? result;

  /// The simulated player of this match, if it has one (P10).
  _Simulation? simulation;

  /// A KO landed and the match is about to finish: no rep counts after it.
  bool koLanded = false;
  bool get terminal => {'finished', 'cancelled', 'void'}.contains(status);
}

/// In-memory v1 prototype. Authentication is injected; no trust in client IDs.
/// Production TLS termination and durable result storage are external adapters.
class BattleServer {
  BattleServer({
    required this.authenticate,
    int? durationMs,
    this.countdownMs = 3000,
    this.readyTimeoutMs = 60000,
    int? setupTimeoutMs,
    this.tickMs = 50,
    this.reconnectMs = 10000,
    this.heartbeatTimeoutMs = 15000,
    this.results,
    BattleTelemetry? telemetry,
    SkillSource? skills,
    int? virtualAfterMs,
    this.skillRefreshMs = 300000,
    Random? simulationRandom,
    this.simulatedSetupMs = (4000, 7000),
    this.simulatedReadyMs = (3000, 6000),
    this.rules = battleRules,
  }) : _telemetry =
           telemetry ??
           (results is BattleTelemetry ? results as BattleTelemetry : null),
       _skillSource =
           skills ?? (results is SkillSource ? results as SkillSource : null),
       virtualAfterMs = virtualAfterMs ?? battleVirtualWait.inMilliseconds,
       _simulationRandom = simulationRandom ?? Random(),
       durationMs = durationMs ?? battleDuration.inMilliseconds,
       setupTimeoutMs = setupTimeoutMs ?? battleSetupTimeout.inMilliseconds;
  final BattleAuthenticator authenticate;

  /// The game the server scores: the same code and numbers as the app.
  final BattleRules rules;

  /// P11 storage; null keeps results in memory only (local tests, dev).
  final BattleResultStore? results;

  /// P17: where each match's end is recorded as `battle_finished`; the P11
  /// store by default, null to record nothing.
  final BattleTelemetry? _telemetry;

  /// P10: the recent battles the skill estimates are taken from; the P11
  /// store by default, null to give every player the default estimate.
  final SkillSource? _skillSource;

  /// P10: how long a player who accepts it waits in the main queue for a
  /// real player before a simulated one is assigned.
  final int virtualAfterMs;

  /// P10: how often the estimates are read again, so AI battles the phones
  /// saved count too.
  final int skillRefreshMs;
  SkillIndex _skills = SkillIndex.empty();
  int? _skillsReadAt;
  bool _readingSkills = false;

  /// The estimates the simulated opponents are chosen by.
  SkillIndex get skills => _skills;

  /// P10: a simulated player opens its setup this long (at least, at most,
  /// in ms) after the match is found, as a person takes the warning and the
  /// countdown, and is ready this long after that.
  final (int, int) simulatedSetupMs, simulatedReadyMs;
  final Random _simulationRandom;

  /// P10: the character each player last joined with, when it is one a
  /// person may pick; a simulated player copying them shows it.
  final _characters = <String, String>{};
  int _between((int, int) range) =>
      range.$1 + _simulationRandom.nextInt(range.$2 - range.$1 + 1);
  final int durationMs,
      countdownMs,
      readyTimeoutMs,
      reconnectMs,
      heartbeatTimeoutMs;

  /// From both setups open to both ready (P12). [readyTimeoutMs], from
  /// `match.found`, still bounds a match whose setup never opens (an older
  /// app, a camera that never starts).
  final int setupTimeoutMs;

  /// How often deadlines are checked; tests make it long to see that a
  /// late request is turned down without waiting for a check.
  final int tickMs;
  final _clock = Stopwatch()..start();
  final int _epoch = DateTime.now().millisecondsSinceEpoch;
  final _random = Random.secure();
  final _players = <String, _Player>{}, _matches = <String, _Match>{};
  // FIFO by accepted queue.join, not by socket connection/login time.
  // Cancelled/disconnected players leave the queue; rejoining goes to the tail.
  final _queue = ListQueue<_Player>();
  HttpServer? _http;
  Timer? _timer;
  bool _closing = false;
  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  // Battles a previous process left running, voided at start-up: match id to
  // player ids. A player resuming one is told it ended void.
  final _lost = <String, Set<String>>{};
  final _storing = <Future<void>>{};
  int get now => _epoch + _clock.elapsedMilliseconds;
  int get port => _http!.port;
  String _id() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  Future<void> start({InternetAddress? address, int port = 0}) async {
    // Before accepting sockets, so a reconnecting app already finds its
    // battle in _lost.
    if (results case final store?) {
      try {
        _lost.addAll(
          await store.recover(now).timeout(const Duration(seconds: 10)),
        );
      } catch (_) {}
    }
    // Not awaited: players can join meanwhile, at the default estimate.
    unawaited(_readSkills());
    _http = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    _http!.listen((request) => unawaited(_upgrade(request)));
    _timer = Timer.periodic(Duration(milliseconds: tickMs), (_) => _tick());
  }

  /// Reads the estimates again; a failure keeps the ones there are.
  Future<void> _readSkills() async {
    final source = _skillSource;
    if (source == null || _readingSkills) return;
    _readingSkills = true;
    try {
      final records = await source.loadSkills().timeout(
        const Duration(seconds: 10),
      );
      _skills = SkillIndex.build(records);
    } catch (_) {
      // Kept as they were; read again at the next refresh.
    } finally {
      _skillsReadAt = now;
      _readingSkills = false;
    }
  }

  Future<void> _upgrade(HttpRequest request) async {
    if (request.uri.path == '/health' && request.method == 'GET') {
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"status":"ok","protocol":1}');
      await request.response.close();
      return;
    }
    if (request.uri.path != '/ws/v1/battle' ||
        request.method != 'GET' ||
        request.uri.hasQuery) {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }
    try {
      final header = request.headers.value(HttpHeaders.authorizationHeader);
      final identity = header?.startsWith('Bearer ') == true
          ? await authenticate(header!.substring(7))
          : null;
      if (identity == null ||
          identity.id.isEmpty ||
          identity.name.length > 80) {
        request.response.statusCode = 401;
        await request.response.close();
        return;
      }
      if (_closing) {
        request.response.statusCode = 503;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(
        request,
        compression: CompressionOptions.compressionOff,
        maxPayloadLength: 16384,
      );
      socket.pingInterval = const Duration(seconds: 5);
      final player = _players.putIfAbsent(identity.id, () => _Player(identity));
      final old = player.socket;
      if (player.queued) {
        _queue.remove(player);
        player.queued = false;
      }
      player.socket = socket;
      player.lastHeartbeat = now;
      if (old != null) unawaited(old.close(4001, 'Session replaced'));
      _send(player, 'session.welcome', {
        if (player.match != null && !player.match!.terminal)
          'active_match_id': player.match!.id,
        'player_id': identity.id,
        'connection_id': _id(),
        'heartbeat_interval_ms': 5000,
        'heartbeat_timeout_ms': heartbeatTimeoutMs,
      });
      socket.listen(
        (data) => _receive(player, socket, data),
        onDone: () => _disconnect(player, socket),
        onError: (_) => _disconnect(player, socket),
      );
    } catch (_) {
      try {
        request.response.statusCode = 400;
        await request.response.close();
      } catch (_) {}
    }
  }

  Map<String, dynamic> _envelope(
    _Player p,
    String type,
    Map<String, dynamic> payload, {
    String? requestId,
    String? matchId,
  }) => {
    'v': 1,
    'type': type,
    'server_time_ms': now,
    if (requestId != null) 'request_id': requestId,
    if (matchId ?? p.match?.id case final id?) 'match_id': id,
    'payload': payload,
  };
  void _send(
    _Player p,
    String type,
    Map<String, dynamic> payload, {
    String? requestId,
    String? matchId,
  }) => sendBattleFrame(
    p.socket,
    _envelope(p, type, payload, requestId: requestId, matchId: matchId),
  );
  void _broadcast(_Match m, String type, Map<String, dynamic> payload) {
    for (final p in m.players) _send(p, type, payload, matchId: m.id);
  }

  void _receive(_Player player, WebSocket socket, dynamic data) {
    if (player.socket != socket) return;
    String? requestId;
    try {
      if (data is! String || utf8.encode(data).length > 16384) invalid();
      final message = object(jsonDecode(data));
      fields(message, {'v', 'type', 'request_id', 'match_id', 'payload'});
      if (message['v'] != 1) invalid('UNSUPPORTED_VERSION');
      final type = message['type'];
      if (type is! String) invalid();
      final payload = object(message['payload']);
      player.lastHeartbeat = now;
      if (type == 'pose.frame') {
        final m = _activeMatch(player, message);
        if (!_playing(m)) return;
        final p = checkedPose(payload, durationMs: durationMs),
            seq = p['frame_seq'] as int;
        if (seq <= (m.poseSeq[player.identity.id] ?? 0)) return;
        m.poseSeq[player.identity.id] = seq;
        if (now - player.poseAt < 100) return;
        player.poseAt = now;
        final other = m.players.firstWhere((p) => p != player);
        _send(other, 'pose.frame', {
          'player_id': player.identity.id,
          ...p,
        }, matchId: m.id);
        return;
      }
      requestId = message['request_id'] as String?;
      if (requestId == null || requestId.isEmpty || requestId.length > 96)
        invalid();
      if (now - player.rateAt >= 1000) {
        player.rateAt = now;
        player.controls = 0;
      }
      if (++player.controls > 15) invalid('RATE_LIMITED');
      final signature = _signature(message);
      if (player.requests[requestId] case final old?) {
        if (old.signature != signature) invalid('REQUEST_ID_REUSED');
        sendBattleFrame(socket, old.response);
        return;
      }
      final response = _command(player, type, payload, message, requestId);
      if (type != 'session.ping' && type != 'clock.sync') {
        player.requests[requestId] = (signature: signature, response: response);
      }
      sendBattleFrame(socket, response);
    } on BattleProtocolError catch (error) {
      _send(player, 'error', {
        'code': error.code,
        'retryable': error.code == 'REP_OUT_OF_ORDER',
      }, requestId: requestId);
    } catch (_) {
      _send(player, 'error', {
        'code': 'INVALID_PAYLOAD',
        'retryable': false,
      }, requestId: requestId);
    }
  }

  _Match _activeMatch(_Player p, Map<String, dynamic> message) {
    final m = p.match;
    if (m == null || message['match_id'] != m.id) invalid('MATCH_NOT_FOUND');
    return m;
  }

  bool _playing(_Match m) =>
      !m.terminal && m.start != null && now >= m.start! && now < m.end!;
  Map<String, dynamic> _command(
    _Player p,
    String type,
    Map<String, dynamic> payload,
    Map<String, dynamic> message,
    String rid,
  ) {
    Map<String, dynamic> reply(String t, Map<String, dynamic> value) =>
        _envelope(p, t, value, requestId: rid);
    switch (type) {
      case 'session.ping':
        fields(payload, {});
        return reply('session.pong', {});
      case 'clock.sync':
        fields(payload, {'client_sent_ms'});
        integer(payload['client_sent_ms'], 0, 0x1fffffffffffff);
        return reply('clock.synced', {
          'client_sent_ms': payload['client_sent_ms'],
          'server_received_ms': now,
          'server_sent_ms': now,
        });
      case 'queue.join':
        fields(payload, {
          'exercise',
          'avatar_id',
          'friend_id',
          'accept_virtual',
        });
        if (!{'push_up', 'squat'}.contains(payload['exercise'])) invalid();
        // Optional (W3); any short id, passed on without reading it.
        if (payload.containsKey('avatar_id') &&
            !isBattleAvatarId(payload['avatar_id'])) {
          invalid('INVALID_AVATAR');
        }
        // Optional (P9): only that friend, who must name this player back.
        if (payload.containsKey('friend_id') &&
            (!isBattleFriendId(payload['friend_id']) ||
                payload['friend_id'] == p.identity.id)) {
          invalid('INVALID_FRIEND');
        }
        // Optional (P10): a simulated opponent after the wait, main queue
        // only.
        if (payload.containsKey('accept_virtual') &&
            (payload['accept_virtual'] is! bool ||
                payload['accept_virtual'] == true &&
                    payload.containsKey('friend_id'))) {
          invalid();
        }
        if (p.queued) invalid('ALREADY_QUEUED');
        if (p.match != null && !p.match!.terminal) invalid('ALREADY_IN_MATCH');
        p.requests
            .clear(); // Prior match is terminal; retain all IDs of the new one.
        p.match = null;
        p.avatar = payload['avatar_id'] as String?;
        if (p.avatar case final id?
            when CharacterRig.standard.selectableOrDefault(id) == id) {
          _characters[p.identity.id] = id;
        }
        p.exercise = payload['exercise'] as String;
        p.friend = payload['friend_id'] as String?;
        p.acceptVirtual = payload['accept_virtual'] == true;
        p.queuedAt = now;
        p.queued = true;
        _queue.addLast(p);
        final response = reply('queue.joined', {'queue_id': p.identity.id});
        // ACK is queued before match.found so clients cannot regress to queued.
        scheduleMicrotask(_pair);
        return response;
      case 'queue.cancel':
        fields(payload, {'queue_id'});
        if (!p.queued) invalid('QUEUE_NOT_FOUND');
        if (payload['queue_id'] != p.identity.id) invalid('FORBIDDEN');
        p.queued = false;
        _queue.remove(p);
        return reply('queue.cancelled', {'queue_id': p.identity.id});
      case 'match.setup':
        fields(payload, {});
        final m = _activeMatch(p, message);
        _expireBeforeStart(m);
        if (m.status != 'preparing') invalid('INVALID_STATE');
        if (m.setupOpen.add(p.identity.id)) {
          if (m.setupOpen.length == 2) {
            m.setupDeadline = now + setupTimeoutMs;
          }
          _broadcast(m, 'match.setup_state', _setupState(m));
        }
        return reply('request.accepted', {});
      case 'match.ready':
        fields(payload, {'ready'});
        final m = _activeMatch(p, message);
        // A ready that comes after the deadline is too late, even before
        // the next tick has cancelled the match.
        _expireBeforeStart(m);
        if (m.status != 'preparing' || payload['ready'] is! bool)
          invalid('INVALID_STATE');
        _setReady(m, p, payload['ready'] == true);
        return reply('request.accepted', {});
      case 'rep.submit':
        fields(payload, {'rep_seq', 'elapsed_ms', 'valid', 'reason', 'grade'});
        final m = _activeMatch(p, message), id = p.identity.id;
        final seq = integer(payload['rep_seq'], 1, 10000),
            elapsed = integer(payload['elapsed_ms'], 0, durationMs - 1);
        if (payload['valid'] is! bool ||
            (payload['valid'] == true
                ? payload['reason'] != null
                : !battleReasons.contains(payload['reason'])))
          invalid();
        final grade = _grade(payload, pushUp: p.exercise == 'push_up');
        final accepted = m.reps[id]!;
        if (accepted[seq] case final previous?) {
          if (_signature(previous['submitted']) != _signature(payload))
            invalid('REP_CONFLICT');
          return reply('rep.accepted', object(previous['ack']));
        }
        if (seq != accepted.length + 1) invalid('REP_OUT_OF_ORDER');
        if (!_playing(m)) invalid('INVALID_STATE');
        if (elapsed < (m.lastRepElapsed[id] ?? 0) ||
            elapsed > now - m.start! + 1000)
          invalid();
        return reply('rep.accepted', _acceptRep(m, p, payload, grade));
      case 'match.leave':
        fields(payload, {'reason'});
        if (payload['reason'] != 'user_exit') invalid();
        final m = _activeMatch(p, message);
        if (!m.terminal) {
          if (m.start == null || now < m.start!) {
            _cancel(m, 'user_exit');
          } else {
            _finish(m, 'forfeit', loser: p.identity.id);
          }
        }
        return reply('request.accepted', {});
      case 'match.resume':
        fields(payload, {});
        final lostId = message['match_id'];
        if (p.match?.id != lostId &&
            _lost[lostId]?.contains(p.identity.id) == true) {
          return _envelope(
            p,
            'match.void',
            {'reason': 'server_restarted', 'ended_at_ms': null},
            requestId: rid,
            matchId: lostId as String,
          );
        }
        final m = _activeMatch(p, message);
        if (m.disconnected.remove(p.identity.id) != null && !m.terminal)
          _broadcast(m, 'match.connection_state', {
            'player_id': p.identity.id,
            'state': 'reconnected',
          });
        return reply('match.snapshot', _snapshot(m));
      default:
        invalid('UNKNOWN_TYPE');
    }
  }

  /// The grade of a submitted rep; null when it was rejected and earned
  /// nothing. The depth and the elbow angle stay on the phone, which judges
  /// them. An app that sends no grade is scored as good, and its rejected reps
  /// as nothing. Shallow reps and completed knee push-ups can earn Average.
  /// [p] is ready or not in [m]; with both ready the round is scheduled.
  void _setReady(_Match m, _Player p, bool ready) {
    if (ready) {
      m.ready.add(p.identity.id);
    } else {
      m.ready.remove(p.identity.id);
    }
    _broadcast(m, 'match.ready_state', {'ready_player_ids': m.ready.toList()});
    if (m.ready.length == 2) {
      m.status = 'scheduled';
      m.start = now + countdownMs;
      m.end = m.start! + durationMs;
      _broadcast(m, 'match.start', {
        'start_at_ms': m.start,
        'end_at_ms': m.end,
      });
      _store(
        (store) => store.started(m.id, m.start!, [
          for (final player in m.players) player.identity.id,
        ]),
      );
    }
  }

  /// Scores [p]'s checked rep [payload] in [m], tells the other player and
  /// returns the acknowledgement. A KO ends the match after it.
  Map<String, dynamic> _acceptRep(
    _Match m,
    _Player p,
    Map<String, dynamic> payload,
    GameGrade? grade,
  ) {
    final id = p.identity.id;
    final seq = payload['rep_seq'] as int,
        elapsed = payload['elapsed_ms'] as int;
    final scores = m.scores[id]!;
    scores[payload['valid'] == true ? 0 : 1]++;
    m.lastRepElapsed[id] = elapsed;
    final game = m.games[id]!;
    final earned =
        game
            .addRep(
              grade,
              Duration(milliseconds: elapsed),
              kneePushup: payload['reason'] == 'knees_down',
            )
            ?.points ??
        0;
    final ack = {
      'rep_seq': seq,
      'valid_reps': scores[0],
      'invalid_reps': scores[1],
      'combo': game.combo,
      'points': earned,
      'game_score': game.points,
    };
    m.reps[id]![seq] = {
      'submitted': Map<String, dynamic>.from(payload),
      'ack': ack,
    };
    _send(m.players.firstWhere((other) => other != p), 'rep.updated', {
      'player_id': id,
      ...payload,
      ...ack,
    }, matchId: m.id);
    final other = m.games[m.players.firstWhere((o) => o != p).identity.id]!;
    // ACK is queued before match.finished, like match.found after the join.
    if (rules.isKo(game.points - other.points)) {
      m.koLanded = true;
      scheduleMicrotask(() => _finish(m, 'ko'));
    }
    return ack;
  }

  GameGrade? _grade(Map<String, dynamic> payload, {required bool pushUp}) {
    final grade = payload['grade'];
    if (payload['valid'] != true) {
      if (grade == null) return null;
      return grade == GameGrade.average.name &&
              (payload['reason'] == 'insufficient_depth' ||
                  (pushUp &&
                      rules.kneeAverageEnabled &&
                      rules.averagePoints > 0 &&
                      payload['reason'] == 'knees_down'))
          ? GameGrade.average
          : invalid();
    }
    if (grade == null) return GameGrade.good;
    return GameGrade.values.firstWhere(
      (g) => g != GameGrade.average && g.name == grade,
      orElse: () => invalid(),
    );
  }

  List<Map<String, dynamic>> _roster(_Match m) => m.roster;

  /// Whether [a] and [b] may be paired: the same exercise, and either both
  /// in the main queue or each waiting for the other (P9).
  bool _fits(_Player a, _Player b) =>
      a.exercise == b.exercise &&
      (a.friend == null && b.friend == null ||
          a.friend == b.identity.id && b.friend == a.identity.id);
  void _pair() {
    _queue.removeWhere(
      (p) => !p.queued || p.socket?.readyState != WebSocket.open,
    );
    while (_queue.length >= 2) {
      _Player? first;
      _Player? second;
      for (final candidate in _queue) {
        for (final other in _queue) {
          if (!identical(candidate, other) && _fits(candidate, other)) {
            first = candidate;
            second = other;
            break;
          }
        }
        if (first != null) break;
      }
      if (first == null || second == null) break;
      _queue.remove(first);
      _queue.remove(second);
      _open([first, second]);
    }
  }

  /// A new match of [pair], announced to them with `match.found`.
  _Match _open(List<_Player> pair, {_Simulation? simulation}) {
    final m = _Match(_id(), pair, now, now + readyTimeoutMs)
      ..simulation = simulation;
    _matches[m.id] = m;
    for (final p in pair) {
      p.queued = false;
      p.match = m;
      m.scores[p.identity.id] = [0, 0];
      m.games[p.identity.id] = PlayerGameScore(rules);
      m.reps[p.identity.id] = {};
    }
    _broadcast(m, 'match.found', {
      'players': _roster(m),
      'duration_ms': durationMs,
      'ready_deadline_ms': m.readyDeadline,
      'fever_start_ms': rules.feverStart.inMilliseconds,
      'ko_lead': rules.koLead,
      'average_points': rules.averagePoints,
      'knee_average': rules.kneeAverageEnabled,
    });
    return m;
  }

  Map<String, dynamic> _snapshot(_Match m) => {
    'status': m.status,
    'players': _roster(m),
    'ready_player_ids': m.ready.toList(),
    'duration_ms': durationMs,
    'start_at_ms': m.start,
    'end_at_ms': m.end,
    'ready_deadline_ms': m.readyDeadline,
    ..._setupState(m),
    'fever_start_ms': rules.feverStart.inMilliseconds,
    'ko_lead': rules.koLead,
    'average_points': rules.averagePoints,
    'knee_average': rules.kneeAverageEnabled,
    'scores': m.scores.map(
      (id, s) => MapEntry(id, {
        'valid_reps': s[0],
        'invalid_reps': s[1],
        'game_score': m.games[id]!.points,
        'last_rep_seq': m.reps[id]!.length,
        'last_pose_seq': m.poseSeq[id] ?? 0,
      }),
    ),
    'disconnected_player_ids': m.disconnected.keys.toList(),
    'result': m.result,
  };
  Map<String, dynamic> _setupState(_Match m) => {
    'setup_player_ids': m.setupOpen.toList(),
    'setup_deadline_ms': m.setupDeadline,
  };

  /// Cancels [m] before its start once its deadline passed. With both
  /// setups open that is only the announced setup deadline, even when it
  /// ends after the ready deadline from `match.found`; until then it is the
  /// ready deadline. The ticks and the requests use this one rule.
  void _expireBeforeStart(_Match m) {
    if (m.start != null) return;
    final setup = m.setupDeadline;
    if (setup != null) {
      if (now >= setup) _cancel(m, battleSetupTimeoutReason);
    } else if (now >= m.readyDeadline) {
      _cancel(m, 'ready_timeout');
    }
  }

  /// Ends [m] before its start. Once only: a match that already ended keeps
  /// its first ending.
  void _cancel(_Match m, String reason) {
    if (m.terminal) return;
    m.status = 'cancelled';
    m.ended = now;
    m.result = {'reason': reason, 'ended_at_ms': now};
    _broadcast(m, 'match.cancelled', m.result!);
    _recordEnd(m, reason);
  }

  void _void(_Match m, String reason) {
    m.status = 'void';
    m.ended = now;
    m.result = {'reason': reason, 'ended_at_ms': now};
    _broadcast(m, 'match.void', m.result!);
    // On shutdown the next start-up voids it in storage instead, so a
    // resuming app still learns what happened.
    if (!_closing) {
      _store((store) => store.voided(m.id, reason));
      _recordEnd(m, reason);
    }
  }

  /// P17: records [m]'s end as P6's `battle_finished`, here and only here,
  /// so two phones reporting the same match still count once. Called once
  /// per match, as it ends: the callers return early for a terminal match.
  /// [reason] is the server's own end code; the duration is from
  /// `match.found` to the end.
  void _recordEnd(_Match m, String reason) {
    final sink = _telemetry;
    if (sink == null) return;
    final event = <String, dynamic>{
      'event': 'battle_finished',
      'event_id': _uuid(),
      'ts': DateTime.fromMillisecondsSinceEpoch(
        now,
        isUtc: true,
      ).toIso8601String(),
      'match_id': m.id,
      'end_reason': reason,
      'status': m.status,
      'duration_ms': now - m.created,
      'exercise': m.players.first.exercise,
      'kind': m.players.first.friend == null ? 'main' : 'friend',
      // Points exist only once the battle started.
      'scores': m.start == null
          ? const <Map<String, dynamic>>[]
          : [
              for (final p in m.players)
                {
                  'player_id': p.identity.id,
                  'game_score': m.games[p.identity.id]!.points,
                  'valid_reps': m.scores[p.identity.id]![0],
                },
            ],
    };
    late final Future<void> pending;
    pending = sink
        .battleFinished(event)
        .catchError((_) {})
        .whenComplete(() => _storing.remove(pending));
    _storing.add(pending);
  }

  /// A random (version 4) UUID, the event id Django keys events by.
  String _uuid() {
    final b = List.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  void _store(Future<void> Function(BattleResultStore store) call) {
    final store = results;
    if (store == null) return;
    late final Future<void> pending;
    pending = call(store)
        .catchError((_) {})
        .whenComplete(() => _storing.remove(pending));
    _storing.add(pending);
  }

  void _finish(_Match m, String reason, {String? loser}) {
    if (m.terminal) return;
    m.status = 'finished';
    m.ended = now;
    final a = m.players[0].identity.id, b = m.players[1].identity.id;
    final order = m.games[a]!.compareTo(m.games[b]!);
    final winner = loser != null
        ? (loser == a ? b : a)
        : (order == 0 ? null : (order > 0 ? a : b));
    m.result = {
      'result_id': _id(),
      'reason': reason,
      'winner_id': winner,
      'ended_at_ms': now,
      'players': m.players
          .map(
            (p) => {
              'player_id': p.identity.id,
              if (p.avatar case final avatar?) 'avatar_id': avatar,
              'valid_reps': m.scores[p.identity.id]![0],
              'invalid_reps': m.scores[p.identity.id]![1],
              'game_score': m.games[p.identity.id]!.points,
              'outcome': winner == null
                  ? 'draw'
                  : winner == p.identity.id
                  ? 'win'
                  : 'loss',
            },
          )
          .toList(),
    };
    _broadcast(m, 'match.finished', m.result!);
    // P11 saver: once per result_id, since a terminal match never finishes again.
    _store(
      (store) => store.finished({
        'match_id': m.id,
        'result_id': m.result!['result_id'],
        'reason': reason,
        'exercise': m.players.first.exercise,
        // P11: friend battles are left out of the weekly rankings.
        'kind': m.players.first.friend == null ? 'main' : 'friend',
        'ended_at_ms': m.ended,
        'players': [
          for (final player in m.result!['players'] as List)
            {
              'player_id': player['player_id'],
              if (SimulatedPlayer.isSimulatedId(player['player_id'] as String))
                'simulated': true,
              'display_name': m.roster.firstWhere(
                (r) => r['player_id'] == player['player_id'],
              )['display_name'],
              'valid_reps': player['valid_reps'],
              'invalid_reps': player['invalid_reps'],
              'game_score': player['game_score'],
              'outcome': player['outcome'],
            },
        ],
      }),
    );
    _recordEnd(m, reason);
  }

  void _disconnect(_Player p, WebSocket socket) {
    if (p.socket != socket) return;
    p.socket = null;
    p.queued = false;
    _queue.remove(p);
    final m = p.match;
    if (m == null || m.terminal) return;
    if (m.start == null || now < m.start!) {
      _cancel(m, 'disconnected_before_start');
      return;
    }
    m.disconnected[p.identity.id] = now + reconnectMs;
    _broadcast(m, 'match.connection_state', {
      'player_id': p.identity.id,
      'state': 'disconnected',
      'reconnect_deadline_ms': now + reconnectMs,
    });
  }

  /// P10: [p] waited [virtualAfterMs] without a real player, so it gets a
  /// match with a simulated one, found as a real match is. Once only: it is
  /// no longer queued.
  void _assignVirtual(_Player p) {
    p.queued = false;
    _queue.remove(p);
    final copy = SimulatedPlayer.forPlayer(
      _skills,
      playerId: p.identity.id,
      exercise: p.exercise,
    );
    final player =
        _Player(
            BattleIdentity(
              // Short enough for the API server's 20-character player ids.
              '${SimulatedPlayer.idPrefix}${_id().substring(0, 12)}',
              copy.displayName,
            ),
          )
          ..exercise = p.exercise
          ..avatar = _characterFor(copy.copiedId);
    final setupAt = now + _between(simulatedSetupMs);
    _open(
      [p, player],
      simulation: _Simulation(
        player,
        copy.planReps(_simulationRandom, durationMs: durationMs),
        setupAt,
        setupAt + _between(simulatedReadyMs),
      ),
    );
  }

  /// The character a simulated player copying [copiedId] shows: the one that
  /// account last joined with, or else one a person may pick, at random.
  String _characterFor(String? copiedId) {
    if (_characters[copiedId] case final known?) return known;
    final choices = CharacterRig.standard.selectable;
    return choices[_simulationRandom.nextInt(choices.length)].id;
  }

  /// Plays [m]'s simulated player for now: its setup and ready before the
  /// round, and its reps that are due during it.
  void _simulate(_Match m) {
    final sim = m.simulation;
    if (sim == null || m.terminal) return;
    final id = sim.player.identity.id;
    if (m.status == 'preparing') {
      if (now >= sim.setupAt && m.setupOpen.add(id)) {
        if (m.setupOpen.length == 2) {
          m.setupDeadline = now + setupTimeoutMs;
        }
        _broadcast(m, 'match.setup_state', _setupState(m));
      }
      if (now >= sim.readyAt &&
          m.setupOpen.contains(id) &&
          !m.ready.contains(id)) {
        _setReady(m, sim.player, true);
      }
      return;
    }
    if (!_playing(m)) return;
    final elapsed = now - m.start!;
    while (!m.terminal &&
        !m.koLanded &&
        sim.next < sim.reps.length &&
        (sim.reps[sim.next]['elapsed_ms'] as int) <= elapsed) {
      final rep = sim.reps[sim.next++];
      _acceptRep(
        m,
        sim.player,
        rep,
        _grade(rep, pushUp: sim.player.exercise == 'push_up'),
      );
    }
  }

  void _tick() {
    for (final p in _players.values) {
      if (p.socket case final socket?) {
        if (now - p.lastHeartbeat > heartbeatTimeoutMs) {
          _disconnect(p, socket);
          unawaited(socket.close(4000, 'Heartbeat timeout'));
        }
      }
    }
    // Real players were paired as they joined; whoever still waits after
    // the wait gets a simulated opponent.
    for (final p in _queue.toList()) {
      if (p.queued &&
          p.acceptVirtual &&
          p.friend == null &&
          p.socket?.readyState == WebSocket.open &&
          now - p.queuedAt >= virtualAfterMs) {
        _assignVirtual(p);
      }
    }
    if (_skillsReadAt case final readAt?
        when !_closing && now - readAt >= skillRefreshMs) {
      unawaited(_readSkills());
    }
    for (final m in _matches.values.toList()) {
      if (m.terminal) {
        if (now - m.ended! > 600000) {
          _matches.remove(m.id);
          for (final p in m.players) {
            if (p.match == m) p.match = null;
          }
        }
        continue;
      }
      if (m.start == null) {
        _expireBeforeStart(m);
        _simulate(m);
        continue;
      }
      if (now >= m.start!) m.status = 'playing';
      _simulate(m);
      final expired = m.disconnected.entries
          .where((e) => now >= e.value)
          .toList();
      if (m.disconnected.length == 2 && (expired.isNotEmpty || now >= m.end!)) {
        _void(m, 'both_disconnected');
        continue;
      }
      if (expired.isNotEmpty) {
        _finish(m, 'disconnect_timeout', loser: expired.first.key);
        continue;
      }
      if (now >= m.end! && m.disconnected.isEmpty) _finish(m, 'time_up');
    }
    // Bound idle sessions / request caches. Active and retained matches survive.
    _players.removeWhere(
      (_, p) =>
          p.socket == null && p.match == null && now - p.lastHeartbeat > 600000,
    );
  }

  Future<void> close() async {
    _closing = true;
    _timer?.cancel();
    for (final m in _matches.values) {
      if (!m.terminal) _void(m, 'server_restarted');
    }
    await Future.wait(
      _players.values.map(
        (p) => p.socket?.close(1001, 'Server stopping') ?? Future.value(),
      ),
    );
    await _http?.close(force: true);
    // Let results that are being stored finish, within the stop timeout.
    await Future.wait(_storing.toList())
        .timeout(const Duration(seconds: 5), onTimeout: () => []);
  }
}
