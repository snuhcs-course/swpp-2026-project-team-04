import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../gymrats_app/lib/shared/battle_protocol.dart';
import 'result_store.dart';

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

class _Player {
  _Player(this.identity);
  final BattleIdentity identity;
  WebSocket? socket;
  _Match? match;
  String avatar = 'avatar_01';
  bool queued = false;
  int lastHeartbeat = 0, rateAt = 0, controls = 0, poseAt = -1000;
  final requests =
      <String, ({String signature, Map<String, dynamic> response})>{};
}

class _Match {
  _Match(this.id, this.players, this.created, this.readyDeadline)
    : roster = [
        for (final p in players)
          {
            'player_id': p.identity.id,
            'display_name': p.identity.name,
            'avatar_id': p.avatar,
          },
      ];
  final String id;
  final List<_Player> players;
  final List<Map<String, dynamic>> roster;
  final int created, readyDeadline;
  final ready = <String>{};
  final scores = <String, List<int>>{};
  final reps = <String, Map<int, Map<String, dynamic>>>{};
  final poseSeq = <String, int>{},
      lastRepElapsed = <String, int>{},
      disconnected = <String, int>{};
  String status = 'preparing';
  int? start, end, ended;
  Map<String, dynamic>? result;
  bool get terminal => {'finished', 'cancelled', 'void'}.contains(status);
}

/// In-memory v1 prototype. Authentication is injected; no trust in client IDs.
/// Production TLS termination and durable result storage are external adapters.
class BattleServer {
  BattleServer({
    required this.authenticate,
    this.durationMs = 30000,
    this.countdownMs = 3000,
    this.readyTimeoutMs = 60000,
    this.reconnectMs = 10000,
    this.heartbeatTimeoutMs = 15000,
    this.results,
  });
  final BattleAuthenticator authenticate;

  /// P11 storage; null keeps results in memory only (local tests, dev).
  final BattleResultStore? results;
  final int durationMs,
      countdownMs,
      readyTimeoutMs,
      reconnectMs,
      heartbeatTimeoutMs;
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
    _http = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    _http!.listen((request) => unawaited(_upgrade(request)));
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
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
  void _raw(_Player p, Map<String, dynamic> message) {
    if (p.socket?.readyState == WebSocket.open)
      p.socket!.add(jsonEncode(message));
  }

  void _send(
    _Player p,
    String type,
    Map<String, dynamic> payload, {
    String? requestId,
    String? matchId,
  }) => _raw(
    p,
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
        _raw(player, old.response);
        return;
      }
      final response = _command(player, type, payload, message, requestId);
      if (type != 'session.ping' && type != 'clock.sync') {
        player.requests[requestId] = (signature: signature, response: response);
      }
      _raw(player, response);
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
        fields(payload, {'exercise', 'avatar_id'});
        if (payload['exercise'] != 'push_up') invalid();
        if (!battleAvatarIds.contains(payload['avatar_id']))
          invalid('INVALID_AVATAR');
        if (p.queued) invalid('ALREADY_QUEUED');
        if (p.match != null && !p.match!.terminal) invalid('ALREADY_IN_MATCH');
        p.requests
            .clear(); // Prior match is terminal; retain all IDs of the new one.
        p.match = null;
        p.avatar = payload['avatar_id'] as String;
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
      case 'match.ready':
        fields(payload, {'ready'});
        final m = _activeMatch(p, message);
        if (m.status != 'preparing' || payload['ready'] is! bool)
          invalid('INVALID_STATE');
        if (payload['ready'] == true) {
          m.ready.add(p.identity.id);
        } else {
          m.ready.remove(p.identity.id);
        }
        _broadcast(m, 'match.ready_state', {
          'ready_player_ids': m.ready.toList(),
        });
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
        return reply('request.accepted', {});
      case 'rep.submit':
        fields(payload, {'rep_seq', 'elapsed_ms', 'valid', 'reason'});
        final m = _activeMatch(p, message), id = p.identity.id;
        final seq = integer(payload['rep_seq'], 1, 10000),
            elapsed = integer(payload['elapsed_ms'], 0, durationMs - 1);
        if (payload['valid'] is! bool ||
            (payload['valid'] == true
                ? payload['reason'] != null
                : !battleReasons.contains(payload['reason'])))
          invalid();
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
        final scores = m.scores[id]!;
        scores[payload['valid'] == true ? 0 : 1]++;
        m.lastRepElapsed[id] = elapsed;
        final ack = {
          'rep_seq': seq,
          'valid_reps': scores[0],
          'invalid_reps': scores[1],
        };
        accepted[seq] = {
          'submitted': Map<String, dynamic>.from(payload),
          'ack': ack,
        };
        _send(m.players.firstWhere((other) => other != p), 'rep.updated', {
          'player_id': id,
          ...payload,
          ...ack,
        }, matchId: m.id);
        return reply('rep.accepted', ack);
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

  List<Map<String, dynamic>> _roster(_Match m) => m.roster;
  void _pair() {
    _queue.removeWhere(
      (p) => !p.queued || p.socket?.readyState != WebSocket.open,
    );
    while (_queue.length >= 2) {
      final pair = [_queue.removeFirst(), _queue.removeFirst()];
      final m = _Match(_id(), pair, now, now + readyTimeoutMs);
      _matches[m.id] = m;
      for (final p in pair) {
        p.queued = false;
        p.match = m;
        m.scores[p.identity.id] = [0, 0];
        m.reps[p.identity.id] = {};
      }
      _broadcast(m, 'match.found', {
        'players': _roster(m),
        'duration_ms': durationMs,
        'ready_deadline_ms': m.readyDeadline,
      });
    }
  }

  Map<String, dynamic> _snapshot(_Match m) => {
    'status': m.status,
    'players': _roster(m),
    'ready_player_ids': m.ready.toList(),
    'duration_ms': durationMs,
    'start_at_ms': m.start,
    'end_at_ms': m.end,
    'ready_deadline_ms': m.readyDeadline,
    'scores': m.scores.map(
      (id, s) => MapEntry(id, {
        'valid_reps': s[0],
        'invalid_reps': s[1],
        'last_rep_seq': m.reps[id]!.length,
        'last_pose_seq': m.poseSeq[id] ?? 0,
      }),
    ),
    'disconnected_player_ids': m.disconnected.keys.toList(),
    'result': m.result,
  };
  void _cancel(_Match m, String reason) {
    m.status = 'cancelled';
    m.ended = now;
    m.result = {'reason': reason, 'ended_at_ms': now};
    _broadcast(m, 'match.cancelled', m.result!);
  }

  void _void(_Match m, String reason) {
    m.status = 'void';
    m.ended = now;
    m.result = {'reason': reason, 'ended_at_ms': now};
    _broadcast(m, 'match.void', m.result!);
    // On shutdown the next start-up voids it in storage instead, so a
    // resuming app still learns what happened.
    if (!_closing) _store((store) => store.voided(m.id, reason));
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
    final winner = loser != null
        ? (loser == a ? b : a)
        : (m.scores[a]![0] == m.scores[b]![0]
              ? null
              : (m.scores[a]![0] > m.scores[b]![0] ? a : b));
    m.result = {
      'result_id': _id(),
      'reason': reason,
      'winner_id': winner,
      'ended_at_ms': now,
      'players': m.players
          .map(
            (p) => {
              'player_id': p.identity.id,
              'avatar_id': p.avatar,
              'valid_reps': m.scores[p.identity.id]![0],
              'invalid_reps': m.scores[p.identity.id]![1],
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
        'ended_at_ms': m.ended,
        'players': [
          for (final player in m.result!['players'] as List)
            {
              'player_id': player['player_id'],
              'display_name': m.roster.firstWhere(
                (r) => r['player_id'] == player['player_id'],
              )['display_name'],
              'valid_reps': player['valid_reps'],
              'invalid_reps': player['invalid_reps'],
              'outcome': player['outcome'],
            },
        ],
      }),
    );
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

  void _tick() {
    for (final p in _players.values) {
      if (p.socket case final socket?) {
        if (now - p.lastHeartbeat > heartbeatTimeoutMs) {
          _disconnect(p, socket);
          unawaited(socket.close(4000, 'Heartbeat timeout'));
        }
      }
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
        if (now >= m.readyDeadline) _cancel(m, 'ready_timeout');
        continue;
      }
      if (now >= m.start!) m.status = 'playing';
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
