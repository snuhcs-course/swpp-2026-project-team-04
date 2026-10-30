// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';

// The standalone battle server is exercised through real loopback sockets.
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/battle_server.dart';
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/result_store.dart';

// The same library the server imports: by package: it would be another type.
// ignore: avoid_relative_lib_imports
import '../../../lib/models/battle_rules.dart';

import 'online_battle_integration_test.dart' show Wire, until;

class FakeResultStore implements BattleResultStore {
  FakeResultStore({this.lost = const {}});

  final Map<String, Set<String>> lost;
  final starts = <(String, int, List<String>)>[];
  final results = <Map<String, dynamic>>[];
  final voids = <(String, String)>[];
  final recoveredBefore = <int>[];

  @override
  Future<void> started(String matchId, int startAtMs, List<String> ids) async =>
      starts.add((matchId, startAtMs, ids));

  @override
  Future<void> finished(Map<String, dynamic> result) async =>
      results.add(result);

  @override
  Future<void> voided(String matchId, String reason) async =>
      voids.add((matchId, reason));

  @override
  Future<Map<String, Set<String>>> recover(int bootedAtMs) async {
    recoveredBefore.add(bootedAtMs);
    return lost;
  }
}

const secret = 'test-results-secret-not-used-anywhere-else';

void main() {
  Future<BattleServer> server(
    BattleResultStore store, {
    int duration = 300,
    BattleRules rules = battleRules,
  }) async {
    final s = BattleServer(
      authenticate: (token) => switch (token) {
        'alpha' => const BattleIdentity('1', 'Alpha'),
        'beta' => const BattleIdentity('2', 'Beta'),
        _ => null,
      },
      durationMs: duration,
      countdownMs: 50,
      readyTimeoutMs: 2000,
      reconnectMs: 200,
      results: store,
      rules: rules,
    );
    await s.start();
    addTearDown(s.close);
    return s;
  }

  Future<(Wire, Wire)> playing(BattleServer s) async {
    final a = await Wire.open(s, 'alpha'), b = await Wire.open(s, 'beta');
    addTearDown(a.close);
    addTearDown(b.close);
    a.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_01'});
    b.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_02'});
    final found = await a.next('match.found');
    await b.next('match.found');
    a.match = b.match = found['match_id'] as String;
    a.send('match.ready', {'ready': true});
    b.send('match.ready', {'ready': true});
    await a.next('match.start');
    await b.next('match.start');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return (a, b);
  }

  group('battle server and the P11 store', () {
    test('a started battle is recorded with both players', () async {
      final store = FakeResultStore();
      final s = await server(store);
      final (a, _) = await playing(s);
      await until(() => store.starts.isNotEmpty);
      final (matchId, startAt, ids) = store.starts.single;
      expect(matchId, a.match);
      expect(startAt, greaterThan(0));
      expect(ids, ['1', '2']);
    });

    test('the final result is stored once with names and outcomes', () async {
      final store = FakeResultStore();
      final s = await server(store);
      final (a, b) = await playing(s);
      a.send('rep.submit', {
        'rep_seq': 1,
        'elapsed_ms': 10,
        'valid': true,
        'reason': null,
      });
      await a.next('rep.accepted');
      final finished = await a.next('match.finished');
      await b.next('match.finished');
      await until(() => store.results.isNotEmpty);
      // Give a duplicate call the chance to show up.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final saved = store.results.single;
      expect(saved['match_id'], a.match);
      expect(saved['result_id'], finished['payload']['result_id']);
      expect(saved['reason'], 'time_up');
      expect(saved['players'], [
        {
          'player_id': '1',
          'display_name': 'Alpha',
          'valid_reps': 1,
          'invalid_reps': 0,
          'outcome': 'win',
        },
        {
          'player_id': '2',
          'display_name': 'Beta',
          'valid_reps': 0,
          'invalid_reps': 0,
          'outcome': 'loss',
        },
      ]);
    });

    test('a KO is stored with its reason, without the game score', () async {
      final store = FakeResultStore();
      final s = await server(
        store,
        duration: 5000,
        rules: const BattleRules(koLead: 10),
      );
      final (a, b) = await playing(s);
      a.send('rep.submit', {
        'rep_seq': 1,
        'elapsed_ms': 10,
        'valid': true,
        'reason': null,
      });
      await a.next('rep.accepted');
      await b.next('match.finished');
      await until(() => store.results.isNotEmpty);
      final saved = store.results.single;
      expect(saved['reason'], 'ko');
      expect(saved['players'], [
        {
          'player_id': '1',
          'display_name': 'Alpha',
          'valid_reps': 1,
          'invalid_reps': 0,
          'outcome': 'win',
        },
        {
          'player_id': '2',
          'display_name': 'Beta',
          'valid_reps': 0,
          'invalid_reps': 0,
          'outcome': 'loss',
        },
      ]);
    });

    test('a forfeit is stored as a loss for the player who left', () async {
      final store = FakeResultStore();
      final s = await server(store, duration: 5000);
      final (a, b) = await playing(s);
      b.send('rep.submit', {
        'rep_seq': 1,
        'elapsed_ms': 10,
        'valid': true,
        'reason': null,
      });
      await b.next('rep.accepted');
      b.send('match.leave', {'reason': 'user_exit'});
      await a.next('match.finished');
      await until(() => store.results.isNotEmpty);
      final saved = store.results.single;
      expect(saved['reason'], 'forfeit');
      expect(
        [for (final p in saved['players'] as List) p['outcome']],
        ['win', 'loss'],
      );
    });

    test('a battle both players lost is stored as void', () async {
      final store = FakeResultStore();
      final s = await server(store, duration: 5000);
      final (a, b) = await playing(s);
      final matchId = a.match!;
      await a.close();
      await b.close();
      await until(() => store.voids.isNotEmpty);
      expect(store.voids.single, (matchId, 'both_disconnected'));
      expect(store.results, isEmpty);
    });

    test(
      'shutting down does not store a void for the running battle',
      () async {
        final store = FakeResultStore();
        final s = await server(store, duration: 5000);
        await playing(s);
        await s.close();
        expect(store.voids, isEmpty);
        expect(store.results, isEmpty);
      },
    );

    test(
      'after a restart a resuming player learns the battle was void',
      () async {
        final store = FakeResultStore(
          lost: {
            'lost-match': {'1', '2'},
          },
        );
        final before = DateTime.now().millisecondsSinceEpoch;
        final s = await server(store);
        // Only battles started before this process are voided.
        expect(store.recoveredBefore, hasLength(1));
        expect(store.recoveredBefore.single, greaterThanOrEqualTo(before - 50));
        final a = await Wire.open(s, 'alpha');
        addTearDown(a.close);
        a.match = 'lost-match';
        a.send('match.resume', {});
        final reply = await a.next('match.void');
        expect(reply['match_id'], 'lost-match');
        expect(reply['payload']['reason'], 'server_restarted');
        expect(store.results, isEmpty);
      },
    );

    test('a battle the player was not in still reads as not found', () async {
      final store = FakeResultStore(
        lost: {
          'lost-match': {'2'},
        },
      );
      final s = await server(store);
      final a = await Wire.open(s, 'alpha');
      addTearDown(a.close);
      a.match = 'lost-match';
      a.send('match.resume', {});
      final error = await a.next('error');
      expect(error['payload']['code'], 'MATCH_NOT_FOUND');
    });

    test(
      'an app in a battle the server restarts reads it as unconfirmed',
      () async {
        final store = FakeResultStore();
        final s = await server(store, duration: 5000);
        final session = OnlineBattleSession(
          endpoint: Uri.parse('ws://127.0.0.1:${s.port}/ws/v1/battle'),
          accessToken: 'alpha',
          avatar: AvatarModel.astronaut,
          allowInsecureLoopback: true,
        );
        addTearDown(session.dispose);
        await session.connect();
        await until(() => session.phase == OnlinePhase.queued);
        final b = await Wire.open(s, 'beta');
        addTearDown(b.close);
        b.send('queue.join', {'exercise': 'push_up', 'avatar_id': 'avatar_02'});
        b.match = (await b.next('match.found'))['match_id'] as String;
        await until(() => session.phase == OnlinePhase.preparing);
        session.ready(true);
        b.send('match.ready', {'ready': true});
        await until(() => session.phase == OnlinePhase.scheduled);
        expect(session.matchUnconfirmed, isFalse);
        await s.close();
        await until(() => session.terminal);
        expect(session.phase, OnlinePhase.voided);
        expect(session.matchUnconfirmed, isTrue);
        expect(session.serverRestarted, isTrue);
        expect(session.matchNotFound, isFalse);
      },
    );

    test('a battle the server no longer knows reads as not found', () async {
      // A scripted server: welcome with a battle it then cannot find.
      final fake = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => fake.close(force: true));
      final sockets = <WebSocket>[];
      Map<String, dynamic> envelope(String type, Map<String, dynamic> p) => {
        'v': 1,
        'type': type,
        'server_time_ms': DateTime.now().millisecondsSinceEpoch,
        'payload': p,
      };
      fake.listen((request) async {
        final ws = await WebSocketTransformer.upgrade(request);
        sockets.add(ws);
        ws.add(
          jsonEncode(
            envelope('session.welcome', {
              'player_id': '1',
              'active_match_id': 'gone-match',
              'connection_id': 'c1',
              'heartbeat_interval_ms': 5000,
              'heartbeat_timeout_ms': 15000,
            }),
          ),
        );
        ws.listen((raw) {
          final m = jsonDecode(raw as String) as Map;
          if (m['type'] == 'match.resume') {
            ws.add(
              jsonEncode(
                envelope('error', {
                  'code': 'MATCH_NOT_FOUND',
                  'retryable': false,
                }),
              ),
            );
          }
        });
      });
      final session = OnlineBattleSession(
        endpoint: Uri.parse('ws://127.0.0.1:${fake.port}/ws/v1/battle'),
        accessToken: 'alpha',
        avatar: AvatarModel.astronaut,
        allowInsecureLoopback: true,
      );
      addTearDown(session.dispose);
      await session.connect();
      await until(() => session.phase == OnlinePhase.failed);
      expect(session.matchNotFound, isTrue);
      expect(session.matchUnconfirmed, isTrue);
      expect(session.serverRestarted, isFalse);
      // A new battle clears the flag.
      sockets.single.add(
        jsonEncode({
          ...envelope('match.found', {
            'players': [
              {
                'player_id': '1',
                'display_name': 'Alpha',
                'avatar_id': 'avatar_01',
              },
              {
                'player_id': '2',
                'display_name': 'Beta',
                'avatar_id': 'avatar_02',
              },
            ],
            'duration_ms': 30000,
            'ready_deadline_ms': 0,
          }),
          'match_id': 'new-match',
        }),
      );
      await until(() => session.phase == OnlinePhase.preparing);
      expect(session.matchNotFound, isFalse);
      expect(session.matchUnconfirmed, isFalse);
    });

    test('a failing store does not stop the battle server', () async {
      final s = await server(_ThrowingStore());
      final (a, _) = await playing(s);
      final finished = await a.next('match.finished');
      expect(finished['payload']['reason'], 'time_up');
    });
  });

  group('HttpResultStore', () {
    late HttpServer api;
    late List<(String, String?, Map<String, dynamic>)> calls;
    late List<int> statuses;
    late List<bool> chunked;

    setUp(() async {
      calls = [];
      statuses = [];
      chunked = [];
      api = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      api.listen((request) async {
        chunked.add(request.headers.chunkedTransferEncoding);
        final body = jsonDecode(await utf8.decodeStream(request));
        calls.add((
          request.uri.path,
          request.headers.value('X-Results-Secret'),
          Map<String, dynamic>.from(body as Map),
        ));
        final status = statuses.isEmpty ? 200 : statuses.removeAt(0);
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          request.uri.path.endsWith('recover')
              ? jsonEncode({
                  'voided': [
                    {
                      'match_id': 'm1',
                      'player_ids': ['1', '2'],
                    },
                    {'match_id': 7},
                  ],
                })
              : '{}',
        );
        await request.response.close();
      });
      addTearDown(() => api.close(force: true));
    });

    HttpResultStore store({List<String>? log}) => HttpResultStore(
      Uri.parse('http://127.0.0.1:${api.port}/internal'),
      secret,
      retryDelays: const [Duration(milliseconds: 5), Duration(milliseconds: 5)],
      log: log?.add,
    );

    test('posts each call to its path with the secret', () async {
      final s = store();
      await s.started('m1', 1000, ['1', '2']);
      await s.finished({'result_id': 'r1'});
      await s.voided('m2', 'both_disconnected');
      expect(
        [for (final c in calls) c.$1],
        [
          '/internal/battles/start',
          '/internal/results',
          '/internal/battles/void',
        ],
      );
      expect(calls.every((c) => c.$2 == secret), isTrue);
      // Django ignores a chunked body, so each call sends Content-Length.
      expect(chunked, everyElement(isFalse));
      expect(calls[0].$3, {
        'match_id': 'm1',
        'started_at_ms': 1000,
        'player_ids': ['1', '2'],
      });
      expect(calls[2].$3, {'match_id': 'm2', 'reason': 'both_disconnected'});
    });

    test('recover sends the boot time and skips bad rows', () async {
      expect(await store().recover(1234), {
        'm1': {'1', '2'},
      });
      expect(calls.single.$3, {'booted_at_ms': 1234});
    });

    test('a server error is retried until it succeeds', () async {
      statuses = [503, 502];
      await store().finished({'result_id': 'r1'});
      expect(calls, hasLength(3));
    });

    test(
      'a refused call is not retried and is logged without its body',
      () async {
        statuses = [409];
        final log = <String>[];
        await store(log: log).finished({'result_id': 'secret-free'});
        expect(calls, hasLength(1));
        expect(log.single, contains('HTTP 409'));
        expect(log.single, isNot(contains('secret-free')));
        expect(log.single, isNot(contains(secret)));
      },
    );

    test('gives up after the last retry', () async {
      statuses = [500, 500, 500, 500];
      final log = <String>[];
      await store(log: log).finished({'result_id': 'r1'});
      expect(calls, hasLength(3));
      expect(log.single, contains('failed after 3 tries'));
    });

    test('an unreachable API gives up quietly', () async {
      final port = api.port;
      await api.close(force: true);
      final log = <String>[];
      final s = HttpResultStore(
        Uri.parse('http://127.0.0.1:$port/internal/'),
        secret,
        retryDelays: const [],
        log: log.add,
      );
      expect(await s.recover(0), isEmpty);
      expect(log.single, contains('failed after 1 tries'));
    });

    test('readEnvValue reads one key and nothing else', () {
      const env = '''
# comment
JWT_SECRET=other-secret
RESULTS_SECRET="quoted-value"
RESULTS_SECRET_OLD=old
''';
      expect(readEnvValue(env, 'RESULTS_SECRET'), 'quoted-value');
      expect(readEnvValue('RESULTS_SECRET=plain\n', 'RESULTS_SECRET'), 'plain');
      expect(
        readEnvValue("RESULTS_SECRET='single'", 'RESULTS_SECRET'),
        'single',
      );
      expect(readEnvValue(env, 'MISSING'), isNull);
    });

    test('only a loopback URL and a long secret are accepted', () {
      expect(
        () =>
            HttpResultStore(Uri.parse('http://52.78.38.225/internal/'), secret),
        throwsArgumentError,
      );
      expect(
        () => HttpResultStore(Uri.parse('https://127.0.0.1/internal/'), secret),
        throwsArgumentError,
      );
      expect(
        () => HttpResultStore(Uri.parse('http://127.0.0.1/internal/'), 'short'),
        throwsArgumentError,
      );
    });
  });
}

class _ThrowingStore implements BattleResultStore {
  @override
  Future<void> started(String matchId, int startAtMs, List<String> ids) =>
      Future.error(StateError('down'));

  @override
  Future<void> finished(Map<String, dynamic> result) =>
      Future.error(StateError('down'));

  @override
  Future<void> voided(String matchId, String reason) =>
      Future.error(StateError('down'));

  @override
  Future<Map<String, Set<String>>> recover(int bootedAtMs) =>
      Future.error(StateError('down'));
}
