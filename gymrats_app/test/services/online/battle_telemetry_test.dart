import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The standalone battle server is exercised through real loopback sockets.
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/battle_server.dart';
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/result_store.dart';

// The same library the server imports: by package: it would be another type.
// ignore: avoid_relative_lib_imports
import '../../../lib/models/battle_rules.dart';

import 'online_battle_integration_test.dart' show Wire, until;

/// Keeps every `battle_finished` the server records.
class FakeTelemetry implements BattleTelemetry {
  final events = <Map<String, dynamic>>[];

  @override
  Future<void> battleFinished(Map<String, dynamic> event) async =>
      events.add(event);
}

const secret = 'test-results-secret-not-used-anywhere-else';
final uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

BattleIdentity? identity(String token) => switch (token) {
  'alpha' => const BattleIdentity('1', 'Alpha'),
  'beta' => const BattleIdentity('2', 'Beta'),
  _ => null,
};

void main() {
  Future<BattleServer> server(
    BattleTelemetry telemetry, {
    int duration = 300,
    int readyTimeout = 2000,
    int setupTimeout = 10000,
    BattleRules rules = battleRules,
  }) async {
    final s = BattleServer(
      authenticate: identity,
      durationMs: duration,
      countdownMs: 50,
      readyTimeoutMs: readyTimeout,
      setupTimeoutMs: setupTimeout,
      reconnectMs: 200,
      telemetry: telemetry,
      rules: rules,
    );
    await s.start();
    addTearDown(s.close);
    return s;
  }

  /// Both join and are matched; with [friends] they name each other.
  Future<(Wire, Wire)> found(
    BattleServer s, {
    String exercise = 'push_up',
    bool friends = false,
  }) async {
    final a = await Wire.open(s, 'alpha'), b = await Wire.open(s, 'beta');
    addTearDown(a.close);
    addTearDown(b.close);
    a.send('queue.join', {'exercise': exercise, if (friends) 'friend_id': '2'});
    await a.next('queue.joined');
    b.send('queue.join', {'exercise': exercise, if (friends) 'friend_id': '1'});
    final match = await a.next('match.found');
    await b.next('match.found');
    a.match = b.match = match['match_id'] as String;
    return (a, b);
  }

  Future<(Wire, Wire)> playing(BattleServer s) async {
    final (a, b) = await found(s);
    a.send('match.ready', {'ready': true});
    b.send('match.ready', {'ready': true});
    await a.next('match.start');
    await b.next('match.start');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return (a, b);
  }

  /// Waits for the first record, then gives a duplicate the time to show.
  Future<Map<String, dynamic>> recorded(FakeTelemetry t) async {
    await until(() => t.events.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return t.events.single;
  }

  group('battle_finished from the battle server (P17)', () {
    test('a played battle is recorded once, with both scores and only the '
        "dictionary's fields", () async {
      final t = FakeTelemetry();
      final s = await server(t);
      final (a, b) = await playing(s);
      a.send('rep.submit', {
        'rep_seq': 1,
        'elapsed_ms': 10,
        'valid': true,
        'reason': null,
      });
      await a.next('rep.accepted');
      await a.next('match.finished');
      await b.next('match.finished');
      final event = await recorded(t);
      expect(event.keys.toSet(), {
        'event',
        'event_id',
        'ts',
        'match_id',
        'end_reason',
        'status',
        'duration_ms',
        'exercise',
        'kind',
        'scores',
      });
      expect(event['event'], 'battle_finished');
      expect(event['event_id'], matches(uuid));
      expect(DateTime.parse(event['ts'] as String).isUtc, isTrue);
      expect(event['match_id'], a.match);
      expect(event['end_reason'], 'time_up');
      expect(event['status'], 'finished');
      expect(event['exercise'], 'push_up');
      expect(event['kind'], 'main');
      // From match.found: past the countdown and the 300 ms round.
      expect(event['duration_ms'], greaterThanOrEqualTo(350));
      expect(event['scores'], [
        {'player_id': '1', 'game_score': 10, 'valid_reps': 1},
        {'player_id': '2', 'game_score': 0, 'valid_reps': 0},
      ]);
    });

    test('a match nobody got ready for is recorded as cancelled, with no '
        'scores', () async {
      final t = FakeTelemetry();
      final s = await server(t, readyTimeout: 150);
      final (a, _) = await found(s, exercise: 'squat');
      await a.next('match.cancelled');
      final event = await recorded(t);
      expect(event['end_reason'], 'ready_timeout');
      expect(event['status'], 'cancelled');
      expect(event['exercise'], 'squat');
      expect(event['scores'], isEmpty);
    });

    test('a setup timeout is recorded with its own code', () async {
      final t = FakeTelemetry();
      final s = await server(t, setupTimeout: 150);
      final (a, b) = await found(s);
      a.send('match.setup', {});
      b.send('match.setup', {});
      await a.next('match.cancelled');
      expect((await recorded(t))['end_reason'], 'setup_timeout');
    });

    test('leaving before the start is user_exit; a friend battle says '
        'friend', () async {
      final t = FakeTelemetry();
      final s = await server(t);
      final (a, b) = await found(s, friends: true);
      a.send('match.leave', {'reason': 'user_exit'});
      await b.next('match.cancelled');
      final event = await recorded(t);
      expect(event['end_reason'], 'user_exit');
      expect(event['kind'], 'friend');
    });

    test('a KO is finished with its own code', () async {
      final t = FakeTelemetry();
      final s = await server(
        t,
        duration: 5000,
        rules: const BattleRules(koLead: 5),
      );
      final (a, _) = await playing(s);
      a.send('rep.submit', {
        'rep_seq': 1,
        'elapsed_ms': 10,
        'valid': true,
        'reason': null,
      });
      await a.next('match.finished');
      final event = await recorded(t);
      expect(event['end_reason'], 'ko');
      expect(event['status'], 'finished');
    });

    test('leaving after the start is a forfeit, finished', () async {
      final t = FakeTelemetry();
      final s = await server(t, duration: 5000);
      final (a, b) = await playing(s);
      a.send('match.leave', {'reason': 'user_exit'});
      await b.next('match.finished');
      final event = await recorded(t);
      expect(event['end_reason'], 'forfeit');
      expect(event['status'], 'finished');
      expect(event['scores'], hasLength(2));
    });

    test(
      'one player lost for good after the start is disconnect_timeout',
      () async {
        final t = FakeTelemetry();
        final s = await server(t, duration: 5000);
        final (a, b) = await playing(s);
        await a.close();
        await b.next('match.finished');
        expect((await recorded(t))['end_reason'], 'disconnect_timeout');
      },
    );

    test('a player lost before the start cancels it as '
        'disconnected_before_start', () async {
      final t = FakeTelemetry();
      final s = await server(t);
      final (a, b) = await found(s);
      await a.close();
      await b.next('match.cancelled');
      final event = await recorded(t);
      expect(event['end_reason'], 'disconnected_before_start');
      expect(event['status'], 'cancelled');
      expect(event['scores'], isEmpty);
    });

    test('a battle both lost is recorded as void', () async {
      final t = FakeTelemetry();
      final s = await server(t, duration: 5000);
      final (a, b) = await playing(s);
      await a.close();
      await b.close();
      final event = await recorded(t);
      expect(event['end_reason'], 'both_disconnected');
      expect(event['status'], 'void');
      expect(event['scores'], hasLength(2));
    });

    test('a battle still running when the server stops is not recorded: '
        'the next start voids it in storage', () async {
      final t = FakeTelemetry();
      final s = await server(t, duration: 5000);
      await playing(s);
      await s.close();
      expect(t.events, isEmpty);
    });

    test(
      'by default the P11 store records it, at its telemetry path',
      () async {
        final paths = <String>[];
        final bodies = <Map<String, dynamic>>[];
        final api = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => api.close(force: true));
        api.listen((request) async {
          final body = jsonDecode(await utf8.decodeStream(request));
          paths.add(request.uri.path);
          bodies.add(Map<String, dynamic>.from(body as Map));
          request.response.headers.contentType = ContentType.json;
          request.response.write('{}');
          await request.response.close();
        });
        final s = BattleServer(
          authenticate: identity,
          readyTimeoutMs: 150,
          results: HttpResultStore(
            Uri.parse('http://127.0.0.1:${api.port}/internal/'),
            secret,
          ),
        );
        await s.start();
        addTearDown(s.close);
        final (a, _) = await found(s);
        await a.next('match.cancelled');
        await until(() => paths.contains('/internal/telemetry/battle'));
        final body = bodies[paths.indexOf('/internal/telemetry/battle')];
        expect(body['end_reason'], 'ready_timeout');
        expect(body['match_id'], a.match);
      },
    );
  });
}
