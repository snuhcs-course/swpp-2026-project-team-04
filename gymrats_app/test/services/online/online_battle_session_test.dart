import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/shared/battle_protocol.dart';

/// A battle server stand-in on loopback that pairs the user with an
/// opponent at once and answers `match.setup` with [setupAnswer]: what an
/// older server (`UNKNOWN_TYPE`) or the current one does. It records what
/// the app sent.
class _StubServer {
  _StubServer(this._http, this.setupAnswer) {
    _http.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      _socket = socket;
      send('session.welcome', {'player_id': 'me'});
      socket.listen((raw) => _receive(jsonDecode(raw as String) as Map));
    });
  }

  static Future<_StubServer> start({
    Map<String, dynamic>? Function(Map<dynamic, dynamic> message)? setupAnswer,
  }) async => _StubServer(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    setupAnswer,
  );

  final HttpServer _http;
  final Map<String, dynamic>? Function(Map<dynamic, dynamic> message)?
  setupAnswer;
  WebSocket? _socket;
  final received = <Map<dynamic, dynamic>>[];

  Uri get endpoint => Uri.parse('ws://127.0.0.1:${_http.port}/ws/v1/battle');
  int get now => DateTime.now().millisecondsSinceEpoch;

  /// The `match.setup` requests the app sent.
  List<Map<dynamic, dynamic>> get setups =>
      received.where((m) => m['type'] == 'match.setup').toList();

  void send(
    String type,
    Map<String, dynamic> payload, {
    String? requestId,
    String? matchId,
  }) => _socket?.add(
    jsonEncode({
      'v': 1,
      'type': type,
      'request_id': ?requestId,
      'match_id': ?matchId,
      'server_time_ms': now,
      'payload': payload,
    }),
  );

  void _receive(Map<dynamic, dynamic> message) {
    received.add(message);
    final rid = message['request_id'] as String?;
    switch (message['type']) {
      case 'queue.join':
        send('queue.joined', {'queue_id': 'me'}, requestId: rid);
        send('match.found', {
          'players': [
            {'player_id': 'me', 'display_name': 'Me'},
            {'player_id': 'them', 'display_name': 'Them'},
          ],
          'duration_ms': 30000,
          'ready_deadline_ms': now + 60000,
        }, matchId: 'm1');
      case 'match.setup':
        final answer = setupAnswer?.call(message);
        if (answer != null) send('error', answer, requestId: rid);
    }
  }

  Future<void> close() => _http.close(force: true);
}

Future<void> _until(bool Function() condition) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsedMilliseconds > 5000) {
      throw TimeoutException('state not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// A session whose server clock the test sets.
class _ClockedSession extends OnlineBattleSession {
  _ClockedSession()
    : super(
        endpoint: Uri.parse('wss://example.com/ws/v1/battle'),
        accessToken: 'test-only',
      );
  int clock = 1000000;
  @override
  int get serverNow => clock;
}

void main() {
  Future<(OnlineBattleSession, _StubServer)> preparing({
    Map<String, dynamic>? Function(Map<dynamic, dynamic> message)? setupAnswer,
  }) async {
    final server = await _StubServer.start(setupAnswer: setupAnswer);
    addTearDown(server.close);
    final session = OnlineBattleSession(
      endpoint: server.endpoint,
      accessToken: 'test-only',
      allowInsecureLoopback: true,
    );
    addTearDown(session.dispose);
    await session.connect();
    await _until(() => session.phase == OnlinePhase.preparing);
    return (session, server);
  }

  group('the setup time (P12)', () {
    test('the open setup is sent once, however often it is reported', () async {
      final (session, server) = await preparing();
      session.setupOpened();
      session.setupOpened();
      session.setupOpened();
      await _until(() => server.setups.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(server.setups, hasLength(1));
      expect(server.setups.single['match_id'], 'm1');
      expect(server.setups.single['payload'], isEmpty);
    });

    test('nothing is sent once the match ended', () async {
      final (session, server) = await preparing();
      server.send('match.cancelled', {
        'reason': 'user_exit',
        'ended_at_ms': server.now,
      }, matchId: 'm1');
      await _until(() => session.terminal);
      session.setupOpened();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(server.setups, isEmpty);
    });

    for (final code in ['UNKNOWN_TYPE', 'INVALID_STATE', 'MATCH_NOT_FOUND']) {
      test('after $code to the open setup it is not sent again and no error '
          'shows (an older server, a match that just ended)', () async {
        final (session, server) = await preparing(
          setupAnswer: (_) => {'code': code, 'retryable': false},
        );
        session.setupOpened();
        await _until(() => server.setups.isNotEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        // The camera reports the open setup on every frame.
        for (var i = 0; i < 5; i++) {
          session.setupOpened();
        }
        await Future<void>.delayed(
          const Duration(milliseconds: OnlineBattleSession.setupRetryMs + 200),
        );
        session.setupOpened();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(server.setups, hasLength(1));
        expect(session.error, isNull);
        expect(session.phase, OnlinePhase.preparing);
        expect(session.setupDeadlineMs, isNull);
        expect(session.setupSecondsLeft, isNull);
      });
    }

    test('an open setup turned down for now is sent again, but not before a '
        'second has passed', () async {
      final (session, server) = await preparing(
        setupAnswer: (_) => {'code': 'RATE_LIMITED', 'retryable': false},
      );
      session.setupOpened();
      await _until(() => server.setups.length == 1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(session.error, isNull);
      for (var i = 0; i < 5; i++) {
        session.setupOpened();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(server.setups, hasLength(1));
      await Future<void>.delayed(
        const Duration(milliseconds: OnlineBattleSession.setupRetryMs),
      );
      session.setupOpened();
      await _until(() => server.setups.length == 2);
      expect(
        server.setups[1]['request_id'],
        isNot(server.setups[0]['request_id']),
      );
    });

    test('other errors are still said', () async {
      final (session, server) = await preparing();
      server.send('error', {
        'code': 'INVALID_PAYLOAD',
        'retryable': false,
      }, requestId: 'other');
      await _until(() => session.error != null);
      expect(session.error, '온라인 요청 오류: INVALID_PAYLOAD');
    });

    test(
      'the server\'s setup state sets who is set up and the deadline',
      () async {
        final (session, server) = await preparing();
        server.send('match.setup_state', {
          'setup_player_ids': ['me'],
          'setup_deadline_ms': null,
        }, matchId: 'm1');
        await _until(() => session.setupPlayers.isNotEmpty);
        expect(session.setupPlayers, {'me'});
        expect(session.setupDeadlineMs, isNull);
        final deadline = server.now + 8000;
        server.send('match.setup_state', {
          'setup_player_ids': ['me', 'them'],
          'setup_deadline_ms': deadline,
        }, matchId: 'm1');
        await _until(() => session.setupDeadlineMs != null);
        expect(session.setupPlayers, {'me', 'them'});
        expect(session.setupDeadlineMs, deadline);
        expect(session.setupSecondsLeft, inInclusiveRange(7, 8));
      },
    );

    test('a snapshot without the user sends the open setup again; one with '
        'the user does not', () async {
      final (session, server) = await preparing();
      session.setupOpened();
      await _until(() => server.setups.length == 1);
      Map<String, dynamic> snapshot(List<String> setUp) => {
        'status': 'preparing',
        'players': [
          {'player_id': 'me', 'display_name': 'Me'},
          {'player_id': 'them', 'display_name': 'Them'},
        ],
        'ready_player_ids': <String>[],
        'duration_ms': 30000,
        'start_at_ms': null,
        'end_at_ms': null,
        'setup_player_ids': setUp,
        'setup_deadline_ms': null,
        'scores': {
          'me': {'valid_reps': 0, 'invalid_reps': 0},
          'them': {'valid_reps': 0, 'invalid_reps': 0},
        },
        'disconnected_player_ids': <String>[],
        'result': null,
      };
      server.send('match.snapshot', snapshot(['me']), matchId: 'm1');
      await _until(() => session.setupPlayers.isNotEmpty);
      session.setupOpened();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(server.setups, hasLength(1));
      // The server lost it, as with a connection lost before it arrived.
      server.send('match.snapshot', snapshot([]), matchId: 'm1');
      await _until(() => session.setupPlayers.isEmpty);
      session.setupOpened();
      await _until(() => server.setups.length == 2);
    });

    test('the seconds left round up, stop at zero and count only while '
        'preparing', () {
      final session = _ClockedSession()..phase = OnlinePhase.preparing;
      addTearDown(session.dispose);
      expect(session.setupSecondsLeft, isNull);
      session.setupDeadlineMs = session.clock + 4001;
      expect(session.setupSecondsLeft, 5);
      session.clock += 4001;
      expect(session.setupSecondsLeft, 0);
      session.clock += 5000;
      expect(session.setupSecondsLeft, 0);
      session.phase = OnlinePhase.scheduled;
      expect(session.setupSecondsLeft, isNull);
    });

    test('only a cancel for the setup time is a setup timeout', () {
      final session = _ClockedSession();
      addTearDown(session.dispose);
      session
        ..phase = OnlinePhase.cancelled
        ..result = {'reason': battleSetupTimeoutReason};
      expect(session.setupTimedOut, isTrue);
      session.result = {'reason': 'ready_timeout'};
      expect(session.setupTimedOut, isFalse);
      session
        ..phase = OnlinePhase.voided
        ..result = {'reason': battleSetupTimeoutReason};
      expect(session.setupTimedOut, isFalse);
    });
  });
}
