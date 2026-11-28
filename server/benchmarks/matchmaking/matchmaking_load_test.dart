// P20 load tool tests. Not under gymrats_app/test, so `flutter test` alone
// does not run them; from gymrats_app/:
//   flutter test ../server/benchmarks/matchmaking/matchmaking_load_test.dart
// The battle server runs in this process on loopback with short timings;
// nothing leaves the machine.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../lib/battle_server.dart';
import '../../lib/skill_matchmaker.dart';
import 'load_bot.dart';
import 'load_client.dart';
import 'load_run.dart';
import 'load_server.dart';
import 'load_stats.dart';
import 'skill_index_bench.dart';

BattleIdentity? _dev(String token) {
  final m = RegExp(r'^dev:([a-zA-Z0-9_-]{3,64}):([^:]{1,40})$')
      .firstMatch(token);
  return m == null ? null : BattleIdentity(m[1]!, m[2]!);
}

Future<BattleServer> _server({
  int virtualAfterMs = 400,
  SkillSource? skills,
}) async {
  final server = BattleServer(
    authenticate: _dev,
    durationMs: 1500,
    countdownMs: 100,
    tickMs: 10,
    virtualAfterMs: virtualAfterMs,
    simulatedSetupMs: (10, 30),
    simulatedReadyMs: (10, 30),
    skills: skills,
  );
  await server.start();
  return server;
}

BotConfig _bot(
  BattleServer server, {
  int rounds = 1,
  int roundTimeout = 8000,
}) => BotConfig(
  url: Uri.parse('ws://127.0.0.1:${server.port}/ws/v1/battle'),
  rounds: rounds,
  exercises: const ['push_up'],
  setupMs: (10, 30),
  readyMs: (10, 30),
  thinkMs: (10, 30),
  repsPerRound: (3, 5),
  roundTimeoutMs: roundTimeout,
);

void main() {
  group('Distribution', () {
    test('percentiles are by nearest rank', () {
      final d = Distribution([5, 1, 4, 2, 3, 6, 7, 8, 9, 10]);
      expect(d.count, 10);
      expect(d.min, 1);
      expect(d.max, 10);
      expect(d.mean, 5.5);
      expect(d.percentile(0), 1);
      expect(d.percentile(50), 5);
      expect(d.percentile(90), 9);
      expect(d.percentile(95), 10);
      expect(d.percentile(100), 10);
    });

    test('a single value is every percentile', () {
      final d = Distribution([42]);
      expect(
        [d.percentile(1), d.percentile(50), d.percentile(99)],
        [42, 42, 42],
      );
    });

    test('an empty sample has no numbers and prints n=0', () {
      final d = Distribution(const <int>[]);
      expect(d.percentile(50), isNull);
      expect(d.mean, isNull);
      expect(d.summary(), 'n=0');
      expect(d.toJson()['count'], 0);
    });

    test('a percentile outside 0–100 is an error', () {
      expect(() => Distribution([1]).percentile(101), throwsRangeError);
      expect(() => Distribution([1]).percentile(-1), throwsRangeError);
    });

    test('histogram counts below, between and at or above the edges', () {
      final d = Distribution([0, 99, 100, 999, 1000, 10000, 20000]);
      expect(d.histogram([100, 1000, 10000]), [2, 2, 1, 2]);
      expect(Distribution.bucketLabels([100, 1000], unit: 'ms'), [
        '<100ms',
        '100–1000ms',
        '≥1000ms',
      ]);
    });

    test('summary prints the percentiles', () {
      expect(
        Distribution([10, 20, 30]).summary(),
        'n=3 min=10ms p50=20ms p90=30ms p95=30ms p99=30ms max=30ms',
      );
    });

    test('tallies sort by key', () {
      final counts = <String, int>{};
      for (final k in ['b', 'a', 'b']) {
        tally(counts, k);
      }
      expect(sortedCounts(counts).entries.map((e) => '${e.key}${e.value}'), [
        'a1',
        'b2',
      ]);
    });
  });

  group('load_client arguments', () {
    test('defaults are the documented 200-user scenario', () {
      final plan = planFrom(const {});
      expect(plan.users, 200);
      expect(plan.rampMs, 20000);
      expect(plan.bot.rounds, 3);
      expect(plan.bot.poseIntervalMs, 100);
      expect(plan.bot.thinkMs, (2000, 8000));
      expect(plan.bot.url.toString(), 'ws://127.0.0.1:8090/ws/v1/battle');
    });

    test('options override the plan', () {
      final plan = planFrom(
        parseArgs([
          '--users', '50', '--ramp-ms', '0', '--rounds', '1', //
          '--think-ms', '5', '--exercises', 'squat', '--seed', '7',
        ]),
      );
      expect(plan.users, 50);
      expect(plan.rampMs, 0);
      expect(plan.bot.rounds, 1);
      expect(plan.bot.thinkMs, (5, 5));
      expect(plan.bot.exercises, ['squat']);
      expect(plan.seed, 7);
    });

    test('an unknown option is refused, not run with the defaults', () {
      expect(() => planFrom({'ram-ms': '0'}), throwsFormatException);
      expect(planFrom({'out': 'report.json'}).users, 200);
    });

    test('a flag without a value or a bad range is refused', () {
      expect(() => parseArgs(['--users']), throwsFormatException);
      expect(() => parseArgs(['users', '3']), throwsFormatException);
      expect(() => parseRange('9-3'), throwsFormatException);
    });
  });

  group('synthetic skills', () {
    test('the same seed gives the same accounts, with numeric ids', () {
      final a = SyntheticSkills(accounts: 20).records();
      final b = SyntheticSkills(accounts: 20).records();
      expect(a.length, 20);
      expect(a.first.id, '100001');
      expect(a.map((r) => r.recent), b.map((r) => r.recent));
      for (final r in a) {
        for (final exercise in skillExercises) {
          expect(r.recent[exercise], hasLength(recentMatches));
          expect(r.recent[exercise]!.every((n) => n >= 0), isTrue);
        }
      }
    });

    test('the index bench reports build and lookup cost per size', () {
      final row = measureSize(50, repeats: 1);
      expect(row['accounts'], 50);
      expect(row['build_us_median'], isA<double>());
      expect(row['lookup_us_median'], isA<double>());
    });
  });

  group('load run against a real battle server', () {
    test('an even pair matches each other at once and an odd one gets a '
        'simulated opponent after the wait', () async {
      final server = await _server(skills: SyntheticSkills(accounts: 30));
      addTearDown(server.close);
      final report = await runLoad(
        LoadPlan(bot: _bot(server), users: 3, rampMs: 0, sampleMs: 50),
      );
      expect(report.connected, 3);
      expect(report.peakConnected, 3);
      expect(report.rounds.length, 3);
      expect(report.succeeded, 3);
      expect(report.failed, 0);
      expect(report.matchedReal, 2);
      expect(report.matchedSimulated, 1);
      expect(report.serverErrors, isEmpty);
      expect(report.unexpectedCloses, isEmpty);
      expect(report.queueWait(simulated: true).min, greaterThanOrEqualTo(400));
      expect(report.queueWait(simulated: false).max, lessThan(400));
      expect(report.repAck.count, greaterThan(0));
      final json = report.toJson();
      expect(json['succeeded'], 3);
      expect((json['queue_wait_ms'] as Map)['histogram_all'], hasLength(8));
      expect(report.summaryLines().first, startsWith('users=3 connected=3'));
    });

    test('poses go to the real opponent during the round', () async {
      final server = await _server();
      addTearDown(server.close);
      final report = await runLoad(
        LoadPlan(bot: _bot(server), users: 2, rampMs: 0),
      );
      final rounds = report.rounds.toList();
      expect(rounds.every((r) => r.posesSent > 0), isTrue);
      expect(rounds.every((r) => r.posesReceived > 0), isTrue);
      expect(
        rounds.map((r) => r.result).toSet().difference({'win', 'loss', 'draw'}),
        isEmpty,
      );
    });

    test('each bot plays its rounds one after another', () async {
      final server = await _server();
      addTearDown(server.close);
      final report = await runLoad(
        LoadPlan(bot: _bot(server, rounds: 2), users: 2, rampMs: 0),
      );
      expect(report.rounds.length, 4);
      expect(report.succeeded, 4);
      expect(report.records.every((r) => r.rounds.length == 2), isTrue);
    });

    test('a refused token is a connect error, not a round', () async {
      final server = await _server();
      addTearDown(server.close);
      final bot = LoadBot(
        config: _bot(server),
        playerId: 'x', // shorter than the dev token allows
        displayName: 'X',
        random: Random(1),
      );
      final record = await bot.run();
      expect(record.connectError, '401');
      expect(record.connectMs, isNull);
      expect(record.rounds, isEmpty);
    });

    test('a round with no opponent in time ends as timeout', () async {
      final server = await _server(virtualAfterMs: 60000);
      addTearDown(server.close);
      final report = await runLoad(
        LoadPlan(bot: _bot(server, roundTimeout: 300), users: 1, rampMs: 0),
      );
      expect(report.outcomes, {'timeout': 1});
      expect(report.failed, 1);
      expect(report.serverErrors, isEmpty);
    });

    test('bots still running at the stop time are stopped', () async {
      final server = await _server(virtualAfterMs: 60000);
      addTearDown(server.close);
      final report = await runLoad(
        LoadPlan(bot: _bot(server), users: 1, rampMs: 0, stopAfterMs: 200),
      );
      expect(report.outcomes, {'stopped': 1});
    });

    test('a server that stops mid-run voids the battle and closes the '
        'socket', () async {
      final server = await _server();
      final run = runLoad(
        LoadPlan(bot: _bot(server, rounds: 3), users: 2, rampMs: 0),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await server.close();
      final report = await run;
      expect(report.outcomes.keys, contains('void:server_restarted'));
      expect(report.unexpectedCloses, {'1001': 2});
    });
    test(
      'a round timed out in a match leaves it and waits for the answer',
      () async {
        final server = await _server();
        addTearDown(server.close);
        final bot = BotConfig(
          url: Uri.parse('ws://127.0.0.1:${server.port}/ws/v1/battle'),
          rounds: 1,
          exercises: const ['push_up'],
          setupMs: (10, 10),
          readyMs: (5000, 5000), // never ready before the timeout
          roundTimeoutMs: 600,
        );
        final report = await runLoad(LoadPlan(bot: bot, users: 2, rampMs: 0));
        expect(report.matchedReal, 2);
        expect(report.outcomes.keys, contains('timeout'));
        expect(
          report.outcomes.keys.toSet().difference({
            'timeout',
            'cancelled:user_exit',
          }),
          isEmpty,
        );
        expect(report.serverErrors, isEmpty);
        expect(report.unexpectedCloses, isEmpty);
      },
    );
  });

  group('load bot against a scripted server', () {
    /// A loopback WebSocket server that answers as [script] says.
    Future<HttpServer> scripted(
      void Function(WebSocket socket, Map<String, dynamic> message) script,
    ) async {
      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      http.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen(
          (raw) =>
              script(socket, jsonDecode(raw as String) as Map<String, dynamic>),
        );
      });
      addTearDown(() => http.close(force: true));
      return http;
    }

    Map<String, dynamic> envelope(
      String type,
      Map<String, dynamic> payload, {
      String? requestId,
    }) => {
      'v': 1,
      'type': type,
      'server_time_ms': 0,
      'request_id': ?requestId,
      'match_id': 'm1',
      'payload': payload,
    };

    /// A server that upgrades each socket [delay] after it is asked, and
    /// completes [closed] when that socket closes.
    Future<(HttpServer, Completer<void>)> slowUpgrade(Duration delay) async {
      final closed = Completer<void>();
      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      http.listen((request) async {
        await Future<void>.delayed(delay);
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen(
          (_) {},
          onDone: () {
            if (!closed.isCompleted) closed.complete();
          },
        );
      });
      addTearDown(() => http.close(force: true));
      return (http, closed);
    }

    test(
      'an upgrade that finishes after the connect timeout is closed',
      () async {
        final (http, closed) = await slowUpgrade(
          const Duration(milliseconds: 400),
        );
        final record = await LoadBot(
          config: BotConfig(
            url: Uri.parse('ws://127.0.0.1:${http.port}/'),
            connectTimeoutMs: 100,
          ),
          playerId: 'bot-3',
          displayName: 'B',
          random: Random(5),
        ).run();
        expect(record.connectError, 'timeout');
        expect(record.connectMs, isNull);
        // Without closing it, the late socket would stay open on the server.
        await closed.future.timeout(const Duration(seconds: 3));
      },
    );

    test('a bot stopped while connecting closes the socket and counts no '
        'connection', () async {
      final (http, closed) = await slowUpgrade(
        const Duration(milliseconds: 400),
      );
      final report = await runLoad(
        LoadPlan(
          bot: BotConfig(url: Uri.parse('ws://127.0.0.1:${http.port}/')),
          users: 1,
          rampMs: 0,
          stopAfterMs: 100,
        ),
      ).timeout(const Duration(seconds: 3));
      expect(report.connected, 0);
      expect(report.connectErrors, {'stopped': 1});
      expect(report.rounds, isEmpty);
      await closed.future.timeout(const Duration(seconds: 3));
    });

    test('a bot whose turn comes after the stop time never connects', () async {
      // The first bot is stopped while connecting; the second never starts.
      final (http, _) = await slowUpgrade(const Duration(milliseconds: 400));
      final report = await runLoad(
        LoadPlan(
          bot: BotConfig(url: Uri.parse('ws://127.0.0.1:${http.port}/')),
          users: 2,
          rampMs: 1000, // the second bot starts at 500 ms
          stopAfterMs: 100,
        ),
      ).timeout(const Duration(seconds: 5));
      expect(report.connectErrors['stopped'], 2);
      expect(report.connected, 0);
    });

    test('reps follow the server clock from clock.sync', () async {
      // The server's clock runs a minute ahead of the bot's.
      const ahead = 60000;
      int serverNow() => DateTime.now().millisecondsSinceEpoch + ahead;
      final reps = <int>[];
      final http = await scripted((socket, m) {
        void send(String type, Map<String, dynamic> p) => socket.add(
          jsonEncode(envelope(type, p, requestId: m['request_id'] as String?)),
        );
        switch (m['type']) {
          case 'clock.sync':
            send('clock.synced', {
              'client_sent_ms': m['payload']['client_sent_ms'],
              'server_received_ms': serverNow(),
              'server_sent_ms': serverNow(),
            });
          case 'queue.join':
            send('match.found', {
              'players': [
                {'player_id': 'bot-1', 'display_name': 'B'},
                {'player_id': 'other', 'display_name': 'O'},
              ],
              'duration_ms': 1000,
            });
          case 'match.ready':
            send('match.start', {'start_at_ms': serverNow() + 100});
          case 'rep.submit':
            reps.add(m['payload']['rep_seq'] as int);
            send('rep.accepted', {});
            if (reps.length == 3) {
              send('match.finished', {
                'reason': 'time_up',
                'players': [
                  {'player_id': 'bot-1', 'outcome': 'win'},
                ],
              });
            }
        }
      });
      final record = await LoadBot(
        config: BotConfig(
          url: Uri.parse('ws://127.0.0.1:${http.port}/'),
          rounds: 1,
          setupMs: (10, 10),
          readyMs: (10, 10),
          repsPerRound: (3, 3),
          poseIntervalMs: 0,
          roundTimeoutMs: 5000,
        ),
        playerId: 'bot-1',
        displayName: 'B',
        random: Random(3),
      ).run().timeout(const Duration(seconds: 5));
      // Ignoring the offset would schedule the reps a minute late.
      expect(record.rounds.single.outcome, 'finished:time_up');
      expect(record.rounds.single.result, 'win');
      expect(reps.take(3), [1, 2, 3]);
      expect(record.rounds.single.repAckMs, hasLength(3));
    });

    test('every server error is counted, one without a code as unknown, and '
        'a close by the server is recorded', () async {
      final http = await scripted((socket, m) {
        if (m['type'] != 'queue.join') return;
        socket
          ..add(jsonEncode(envelope('error', {})))
          ..add(jsonEncode(envelope('error', {'code': 7})))
          ..add(jsonEncode(envelope('error', {'code': 'RATE_LIMITED'})))
          ..add(jsonEncode(envelope('error', {'code': 'RATE_LIMITED'})));
        Timer(const Duration(milliseconds: 100), () => socket.close(4000));
      });
      final record = await LoadBot(
        config: BotConfig(url: Uri.parse('ws://127.0.0.1:${http.port}/')),
        playerId: 'bot-2',
        displayName: 'B',
        random: Random(4),
      ).run().timeout(const Duration(seconds: 5));
      expect(record.errors, {'unknown': 2, 'RATE_LIMITED': 2});
      expect(record.unexpectedClose, 4000);
      expect(record.rounds.single.outcome, 'socket_closed');
    });
  });
}
