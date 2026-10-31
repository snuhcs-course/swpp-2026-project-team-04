import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../shared/battle_protocol.dart';
import '../../models/avatar_model.dart';
import '../../models/pose_frame.dart';
import '../../models/rep_event.dart';
import 'pose_wire.dart';

enum OnlinePhase {
  idle,
  connecting,
  queued,
  preparing,
  scheduled,
  playing,
  awaitingResult,
  finished,
  cancelled,
  voided,
  failed,
}

class OnlinePlayer {
  const OnlinePlayer(this.id, this.name, this.avatar);
  final String id, name;
  final AvatarModel avatar;
  factory OnlinePlayer.fromJson(dynamic raw) {
    final p = object(raw), id = p['player_id'], name = p['display_name'];
    if (id is! String || name is! String) invalid();
    return OnlinePlayer(
      id,
      name,
      AvatarModel.values.firstWhere(
        (a) => a.protocolId == p['avatar_id'],
        orElse: () => AvatarModel.astronaut,
      ),
    );
  }
}

/// One socket survives lobby → camera preparation → battle → result.
/// Only explicit joint coordinates, avatar IDs, verdicts and control data leave.
class OnlineBattleSession extends ChangeNotifier {
  OnlineBattleSession({
    required this.endpoint,
    required this.accessToken,
    required this.avatar,
    this.allowInsecureLoopback = false,
  });
  final Uri endpoint;
  final String accessToken;
  final AvatarModel avatar;
  final bool allowInsecureLoopback;
  final _clock = Stopwatch()..start();
  final _nonce = Random.secure().nextInt(0x7fffffff).toRadixString(16);
  final _pending = <int, Map<String, dynamic>>{};
  WebSocket? _socket;
  Timer? _timer, _retry;
  bool _disposed = false, _joining = false;
  int _generation = 0,
      _request = 0,
      _frameSeq = 0,
      _repSeq = 0,
      _lastPoseSeq = 0,
      _retries = 0;
  int _serverAnchor = DateTime.now().millisecondsSinceEpoch,
      _localAnchor = 0,
      _bestRtt = 1 << 30,
      _lastReceived = 0,
      _lastPoseSent = -1000,
      _poseAt = -1000,
      _remotePoseAt = -1000;
  PoseFrame? _latestPose;
  OnlinePhase phase = OnlinePhase.idle;
  String? playerId, matchId, queueId, error;
  OnlinePlayer? opponent;
  int durationMs = 30000;
  int? startAtMs, endAtMs;
  int myReps = 0, myInvalidReps = 0, opponentReps = 0;
  bool connected = false, opponentConnected = true;
  bool authenticationRejected = false;
  Set<String> readyPlayers = {};
  PoseFrame? opponentFrame;
  Map<String, dynamic>? result;
  int get serverNow =>
      _serverAnchor + _clock.elapsedMilliseconds - _localAnchor;
  int get elapsedMs =>
      startAtMs == null ? 0 : (serverNow - startAtMs!).clamp(0, durationMs);
  int get remainingMs => endAtMs == null
      ? durationMs
      : (endAtMs! - serverNow).clamp(0, durationMs);
  int get countdownSeconds => startAtMs == null
      ? 0
      : ((startAtMs! - serverNow) / 1000).ceil().clamp(0, 60);
  bool get terminal => {
    OnlinePhase.finished,
    OnlinePhase.cancelled,
    OnlinePhase.voided,
    OnlinePhase.failed,
  }.contains(phase);
  bool get roundRunning =>
      startAtMs != null &&
      serverNow >= startAtMs! &&
      remainingMs > 0 &&
      !terminal;
  bool get canReady => connected && phase == OnlinePhase.preparing;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// The battle server lost this battle (restart, protocol §8): it ended
  /// void with no result, or the server no longer knows it.
  bool get matchUnconfirmed => serverRestarted || matchNotFound;

  /// Ended void because the battle server restarted.
  bool get serverRestarted =>
      phase == OnlinePhase.voided && result?['reason'] == 'server_restarted';

  /// The battle server no longer knows this battle (restart or expired).
  bool get matchNotFound => phase == OnlinePhase.failed && _matchNotFound;
  bool _matchNotFound = false;
  String? get outcome {
    if (result?['players'] is! List) return null;
    for (final p in result!['players'] as List) {
      if (p['player_id'] == playerId) return p['outcome'] as String?;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _rid() => '$_nonce-${++_request}';
  Map<String, dynamic> _message(
    String type,
    Map<String, dynamic> payload, {
    String? requestId,
  }) => {
    'v': 1,
    'type': type,
    if (type != 'pose.frame') 'request_id': requestId ?? _rid(),
    if (matchId != null) 'match_id': matchId,
    'payload': payload,
  };
  void _send(Map<String, dynamic> message) {
    if (connected && _socket?.readyState == WebSocket.open) {
      _socket!.add(jsonEncode(message));
    }
  }

  Future<void> connect() async {
    if (_disposed || _joining || terminal) return;
    final loopback = {'127.0.0.1', 'localhost', '::1'}.contains(endpoint.host);
    if (endpoint.path != '/ws/v1/battle' ||
        endpoint.hasQuery ||
        endpoint.userInfo.isNotEmpty ||
        (endpoint.scheme != 'wss' &&
            !(endpoint.scheme == 'ws' &&
                allowInsecureLoopback &&
                !kReleaseMode &&
                loopback)) ||
        accessToken.trim().isEmpty) {
      error = '안전한 온라인 서버 주소와 로그인 토큰이 필요해요.';
      phase = OnlinePhase.failed;
      _notify();
      return;
    }
    _joining = true;
    final generation = ++_generation;
    if (matchId == null) phase = OnlinePhase.connecting;
    _notify();
    try {
      final socket = await WebSocket.connect(
        endpoint.toString(),
        headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'},
        compression: CompressionOptions.compressionOff,
        maxPayloadLength: 16384,
      ).timeout(const Duration(seconds: 8));
      if (_disposed || generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      connected = true;
      _lastReceived = _clock.elapsedMilliseconds;
      socket.pingInterval = const Duration(seconds: 5);
      socket.listen(
        (data) => _receive(data, generation),
        onDone: () => _lost(generation),
        onError: (_) => _lost(generation),
      );
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _tick(),
      );
    } catch (error) {
      if (!_disposed && generation == _generation) {
        if (error is WebSocketException && error.httpStatusCode == 401) {
          authenticationRejected = true;
          phase = OnlinePhase.failed;
          this.error = '로그인이 만료됐어요. 다시 로그인해주세요.';
          _retry?.cancel();
        } else if (matchId == null) {
          phase = OnlinePhase.failed;
          this.error = '서버에 연결하지 못했어요. 로그인·인터넷 연결·서버 실행 상태를 확인해주세요.';
        } else {
          _scheduleReconnect();
        }
        _notify();
      }
    } finally {
      _joining = false;
    }
  }

  void _receive(dynamic raw, int generation) {
    if (_disposed || generation != _generation) return;
    try {
      if (raw is! String || utf8.encode(raw).length > 16384) invalid();
      final m = object(jsonDecode(raw));
      if (m['v'] != 1) invalid();
      final p = object(m['payload']), type = m['type'];
      _lastReceived = _clock.elapsedMilliseconds;
      if (type == 'session.welcome') {
        playerId = m['payload']['player_id'] as String;
        matchId ??= p['active_match_id'] as String?;
        _serverAnchor = (m['server_time_ms'] as num).toInt();
        _localAnchor = _clock.elapsedMilliseconds;
        _bestRtt = 1 << 30;
        _retries = 0;
        for (var i = 0; i < 3; i++) {
          _send(
            _message('clock.sync', {
              'client_sent_ms': _clock.elapsedMilliseconds,
            }),
          );
        }
        if (matchId != null) {
          _send(_message('match.resume', {}));
        } else {
          _send(
            _message('queue.join', {
              'exercise': 'push_up',
              'avatar_id': avatar.protocolId,
            }),
          );
        }
      } else if (type == 'clock.synced') {
        final sent = integer(p['client_sent_ms'], 0, 0x1fffffffffffff),
            rtt = _clock.elapsedMilliseconds - sent;
        if (rtt < _bestRtt) {
          _bestRtt = rtt;
          _serverAnchor = (p['server_sent_ms'] as num).toInt() + rtt ~/ 2;
          _localAnchor = _clock.elapsedMilliseconds;
        }
      } else if (type == 'queue.joined') {
        queueId = p['queue_id'] as String;
        if (matchId == null) phase = OnlinePhase.queued;
      } else if (type == 'queue.cancelled') {
        phase = OnlinePhase.cancelled;
      } else if (type == 'match.found') {
        matchId = m['match_id'] as String;
        _matchNotFound = false;
        durationMs = integer(p['duration_ms'], 1, 60000);
        _readPlayers(p['players']);
        phase = OnlinePhase.preparing;
      } else if (m['match_id'] == matchId && matchId != null) {
        switch (type) {
          case 'match.ready_state':
            readyPlayers = (p['ready_player_ids'] as List)
                .cast<String>()
                .toSet();
          case 'match.start':
            startAtMs = (p['start_at_ms'] as num).toInt();
            endAtMs = (p['end_at_ms'] as num).toInt();
            phase = OnlinePhase.scheduled;
          case 'pose.frame':
            if (p['player_id'] != opponent?.id) return;
            final wire = Map<String, dynamic>.from(p)..remove('player_id');
            final seq = integer(wire['frame_seq'], 1, 0x7fffffff);
            if (seq <= _lastPoseSeq) return;
            final frame = decodeBattlePose(wire, durationMs: durationMs);
            opponentFrame = frame.hasPerson ? frame : null;
            _lastPoseSeq = seq;
            _remotePoseAt = _clock.elapsedMilliseconds;
          case 'rep.accepted':
            myReps = max(myReps, integer(p['valid_reps'], 0, 10000));
            myInvalidReps = max(
              myInvalidReps,
              integer(p['invalid_reps'], 0, 10000),
            );
            final seq = integer(p['rep_seq'], 1, 10000);
            _pending.removeWhere((key, _) => key <= seq);
          case 'rep.updated':
            if (p['player_id'] == opponent?.id) {
              opponentReps = integer(p['valid_reps'], 0, 10000);
            }
          case 'match.connection_state':
            if (p['player_id'] == opponent?.id) {
              opponentConnected = p['state'] == 'reconnected';
              if (!opponentConnected) opponentFrame = null;
            }
          case 'match.snapshot':
            _snapshot(p);
          case 'match.finished':
            result = p;
            _readFinalScores(p);
            phase = OnlinePhase.finished;
            _pending.clear();
          case 'match.cancelled':
            result = p;
            phase = OnlinePhase.cancelled;
          case 'match.void':
            result = p;
            phase = OnlinePhase.voided;
        }
      }
      if (type == 'error') {
        final code = p['code'];
        if (code == 'REP_OUT_OF_ORDER') {
          for (final message in _pending.values) {
            _send(message);
          }
        } else if (code == 'INVALID_STATE' &&
            (phase == OnlinePhase.awaitingResult || terminal)) {
        } else if (code == 'QUEUE_NOT_FOUND' && matchId != null) {
          _send(_message('match.leave', {'reason': 'user_exit'}));
        } else if (code == 'RATE_LIMITED') {
        } else {
          error = '온라인 요청 오류: $code';
          if (code == 'MATCH_NOT_FOUND' || matchId == null) {
            _matchNotFound = code == 'MATCH_NOT_FOUND';
            phase = OnlinePhase.failed;
          }
        }
      }
      _notify();
    } catch (_) {
      error = '잘못된 서버 데이터를 무시했어요.';
      _notify();
    }
  }

  void _readPlayers(dynamic value) {
    if (value is! List || value.length != 2) invalid();
    final players = value.map(OnlinePlayer.fromJson).toList();
    if (players.where((p) => p.id == playerId).length != 1) invalid();
    opponent = players.firstWhere((p) => p.id != playerId);
  }

  void _readFinalScores(Map<String, dynamic> p) {
    for (final player in p['players'] as List) {
      if (player['player_id'] == playerId) {
        myReps = integer(player['valid_reps'], 0, 10000);
        myInvalidReps = integer(player['invalid_reps'], 0, 10000);
      } else {
        opponentReps = integer(player['valid_reps'], 0, 10000);
      }
    }
  }

  void _snapshot(Map<String, dynamic> p) {
    _readPlayers(p['players']);
    durationMs = integer(p['duration_ms'], 1, 60000);
    startAtMs = p['start_at_ms'] as int?;
    endAtMs = p['end_at_ms'] as int?;
    readyPlayers = (p['ready_player_ids'] as List).cast<String>().toSet();
    final scores = object(p['scores']),
        mine = object(scores[playerId]),
        other = object(scores[opponent!.id]);
    myReps = integer(mine['valid_reps'], 0, 10000);
    myInvalidReps = integer(mine['invalid_reps'], 0, 10000);
    opponentReps = integer(other['valid_reps'], 0, 10000);
    final accepted = integer(mine['last_rep_seq'], 0, 10000);
    _frameSeq = max(
      _frameSeq,
      integer(mine['last_pose_seq'] ?? 0, 0, 0x7fffffff),
    );
    _repSeq = max(_repSeq, accepted);
    _pending.removeWhere((seq, _) => seq <= accepted);
    opponentConnected = !(p['disconnected_player_ids'] as List).contains(
      opponent!.id,
    );
    phase = switch (p['status']) {
      'preparing' => OnlinePhase.preparing,
      'scheduled' => OnlinePhase.scheduled,
      'playing' => OnlinePhase.playing,
      'finished' => OnlinePhase.finished,
      'cancelled' => OnlinePhase.cancelled,
      'void' => OnlinePhase.voided,
      _ => OnlinePhase.failed,
    };
    if (p['result'] is Map) {
      result = object(p['result']);
      if (phase == OnlinePhase.finished) {
        _readFinalScores(result!);
      }
    }
    if (!terminal) {
      for (final message in _pending.values) {
        _send(message);
      }
    }
  }

  void ready(bool value) {
    if (canReady) _send(_message('match.ready', {'ready': value}));
  }

  void publishPose(PoseFrame? frame) {
    if (!identical(frame, _latestPose)) {
      _latestPose = frame;
      _poseAt = _clock.elapsedMilliseconds;
    }
  }

  void submitRep(RepEvent rep) {
    if (!roundRunning) return;
    final reason = switch (rep.reason) {
      RejectReason.insufficientDepth => 'insufficient_depth',
      RejectReason.incompleteExtension => 'incomplete_extension',
      RejectReason.shouldersNotLevel => 'shoulders_not_level',
      RejectReason.tooFast => 'too_fast',
      RejectReason.kneesDown => 'knees_down',
      RejectReason.armsStraight => 'arms_straight',
      RejectReason.bellyDown => 'belly_down',
      RejectReason.notFloorPushUp => 'not_floor_push_up',
      RejectReason.phoneMoved => 'phone_moved',
      RejectReason.shallowSquat => 'shallow_squat',
      RejectReason.standUpFully => 'stand_up_fully',
      null => null,
    };
    final seq = ++_repSeq,
        message = _message('rep.submit', {
          'rep_seq': seq,
          'elapsed_ms': elapsedMs,
          'valid': rep.valid,
          'reason': rep.valid ? null : reason,
        }, requestId: '$_nonce-rep-$seq');
    _pending[seq] = message;
    _send(message);
  }

  void _tick() {
    if (_disposed) return;
    final local = _clock.elapsedMilliseconds;
    if (!terminal && startAtMs != null && serverNow >= startAtMs!) {
      phase = remainingMs == 0
          ? OnlinePhase.awaitingResult
          : OnlinePhase.playing;
    }
    if (opponentFrame != null && local - _remotePoseAt > 500) {
      opponentFrame = null;
    }
    if (connected && local - _lastReceived > 15000) {
      _lost(_generation);
    }
    if (connected && roundRunning && local - _lastPoseSent >= 100) {
      _lastPoseSent = local;
      final frame = local - _poseAt <= 500 ? _latestPose : null;
      try {
        _send(
          _message(
            'pose.frame',
            encodeBattlePose(
              frame,
              sequence: ++_frameSeq,
              elapsedMs: elapsedMs,
            ),
          ),
        );
      } on BattleProtocolError {
        /* Drop malformed detector data, never queue it. */
      }
    }
    // A pong/clock reply refreshes the receive watchdog, even when no pose exists.
    if (connected && local % 5000 < 100) _send(_message('session.ping', {}));
    _notify();
  }

  void _lost(int generation) {
    if (_disposed || generation != _generation || !connected) return;
    connected = false;
    opponentFrame = null;
    final old = _socket;
    _socket = null;
    ++_generation;
    if (old?.closeCode == 4001) {
      phase = OnlinePhase.failed;
      error = '같은 계정이 다른 연결에서 사용 중이에요.';
    } else if (!terminal) {
      _scheduleReconnect();
    }
    unawaited(old?.close());
    _notify();
  }

  void _scheduleReconnect() {
    if (_disposed || terminal || _retry?.isActive == true) return;
    if (++_retries > 10) {
      phase = OnlinePhase.failed;
      error = '연결을 복구하지 못했어요. 임의의 승패는 기록하지 않습니다.';
      return;
    }
    _retry = Timer(
      Duration(seconds: min(_retries, 3)),
      () => unawaited(connect()),
    );
  }

  Future<void> leave() async {
    if (connected && !terminal) {
      if (matchId != null) {
        _send(_message('match.leave', {'reason': 'user_exit'}));
      } else if (queueId != null) {
        _send(_message('queue.cancel', {'queue_id': queueId}));
      }
    }
    phase = OnlinePhase.cancelled;
    _retry?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    _retry?.cancel();
    unawaited(_socket?.close());
    super.dispose();
  }
}
