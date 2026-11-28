/// P20 test server: the production battle server ([BattleServer], same
/// defaults: 30 s round, 10 s simulated-opponent wait, 20 s setup) on
/// loopback with development tokens, a synthetic skill table instead of the
/// API server, and nothing stored. It samples its own event-loop lag,
/// memory and CPU, and writes them to `--out` when stopped (Ctrl-C).
///
///   dart compile exe server/benchmarks/matchmaking/load_server.dart -o load-server
///   ./load-server --port 8090 --accounts 1000 --out /tmp/p20-server.json
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../lib/battle_server.dart';
import '../../lib/skill_matchmaker.dart';
import 'load_client.dart' show parseArgs;
import 'load_stats.dart';

/// [accounts] made-up accounts with five battles of each exercise, valid
/// reps around [meanReps]; ids are numbers, as the API server's are. The
/// first [bots] load-test bots (`load-001`, … as [botId] makes them for a run
/// of [bots]) get records too, so each bot has its own estimate and its
/// simulated opponent copies the account nearest to it.
class SyntheticSkills implements SkillSource {
  SyntheticSkills({
    required this.accounts,
    this.bots = 0,
    this.botPrefix = 'load',
    this.seed = 20,
    this.meanReps = 15,
  });
  final int accounts, bots, seed;
  final String botPrefix;
  final double meanReps;

  List<SkillRecord> records() {
    final random = Random(seed);
    num reps() => max(
      0,
      (meanReps + (random.nextDouble() + random.nextDouble() - 1) * 12).round(),
    );
    return [
      for (var i = 1; i <= accounts; i++)
        SkillRecord('${100000 + i}', 'Rat $i', {
          for (final exercise in skillExercises)
            exercise: [for (var j = 0; j < recentMatches; j++) reps()],
        }),
      for (var i = 1; i <= bots; i++)
        SkillRecord(botId(botPrefix, i, bots), 'Load $i', {
          for (final exercise in skillExercises)
            exercise: [for (var j = 0; j < recentMatches; j++) reps()],
        }),
    ];
  }

  @override
  Future<List<SkillRecord>> loadSkills() async => records();
}

/// How late a periodic timer fires: the time the server's one isolate was
/// busy, which every message and tick waits behind.
class LagSampler {
  LagSampler({this.periodMs = 100});
  final int periodMs;
  final lags = <int>[];
  final _clock = Stopwatch();
  Timer? _timer;

  void start() {
    _clock.start();
    var expected = periodMs;
    _timer = Timer.periodic(Duration(milliseconds: periodMs), (_) {
      final at = _clock.elapsedMilliseconds;
      lags.add(max(0, at - expected));
      expected = at + periodMs;
    });
  }

  void stop() => _timer?.cancel();
}

/// `ps` CPU share and resident memory of this process.
Future<({double cpu, int rssKb})?> processUsage() async {
  try {
    final out = await Process.run('ps', ['-o', '%cpu=,rss=', '-p', '$pid']);
    final parts = (out.stdout as String).trim().split(RegExp(r'\s+'));
    return (cpu: double.parse(parts[0]), rssKb: int.parse(parts[1]));
  } catch (_) {
    return null;
  }
}

Future<void> main(List<String> args) async {
  final Map<String, String> o;
  try {
    o = parseArgs(args);
    const known = {
      'port',
      'accounts',
      'bots',
      'bot-prefix',
      'seed',
      'virtual-after-ms',
      'out',
    };
    final unknown = o.keys.where((k) => !known.contains(k));
    if (unknown.isNotEmpty) throw FormatException('Unknown: $unknown');
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
    return;
  }
  final port = int.parse(o['port'] ?? '8090');
  final skills = SyntheticSkills(
    accounts: int.parse(o['accounts'] ?? '1000'),
    bots: int.parse(o['bots'] ?? '200'),
    botPrefix: o['bot-prefix'] ?? 'load',
    seed: int.parse(o['seed'] ?? '20'),
  );
  final virtualAfter = o['virtual-after-ms'] == null
      ? null
      : int.parse(o['virtual-after-ms']!);
  final server = BattleServer(
    skills: skills,
    virtualAfterMs: virtualAfter,
    authenticate: (token) {
      final m = RegExp(r'^dev:([a-zA-Z0-9_-]{3,64}):([^:]{1,40})$')
          .firstMatch(token);
      return m == null ? null : BattleIdentity(m[1]!, m[2]!);
    },
  );
  await server.start(address: InternetAddress.loopbackIPv4, port: port);
  final lag = LagSampler()..start();
  final usage = <Map<String, Object?>>[];
  final clock = Stopwatch()..start();
  final poll = Timer.periodic(const Duration(seconds: 5), (_) async {
    final u = await processUsage();
    usage.add({
      'at_ms': clock.elapsedMilliseconds,
      'cpu_percent': u?.cpu,
      'rss_kb': u?.rssKb ?? ProcessInfo.currentRss ~/ 1024,
    });
  });
  stdout.writeln(
    'P20 load server on 127.0.0.1:${server.port} '
    'accounts=${skills.accounts} bots=${skills.bots} virtual_after_ms='
    '${server.virtualAfterMs} duration_ms=${server.durationMs}',
  );

  var stopping = false;
  Future<void> stop() async {
    if (stopping) return;
    stopping = true;
    poll.cancel();
    lag.stop();
    await server.close();
    final lags = Distribution(lag.lags);
    final report = {
      'server': {
        'dart': Platform.version.split(' ').first,
        'os': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'processors': Platform.numberOfProcessors,
        'compiled': Platform.executable.endsWith('dart') ? 'jit' : 'aot',
        'port': port,
        'accounts': skills.accounts,
        'bots_in_skill_table': skills.bots,
        'virtual_after_ms': server.virtualAfterMs,
        'duration_ms': server.durationMs,
        'setup_timeout_ms': server.setupTimeoutMs,
        'tick_ms': server.tickMs,
      },
      'wall_ms': clock.elapsedMilliseconds,
      'event_loop_lag_ms': lags.toJson(),
      'lag_over_50ms': lag.lags.where((l) => l > 50).length,
      'max_rss_kb': ProcessInfo.maxRss ~/ 1024,
      'usage': usage,
    };
    stdout.writeln('event loop lag: ${lags.summary()}');
    stdout.writeln('max rss: ${ProcessInfo.maxRss ~/ 1024} KB');
    if (o['out'] case final path?) {
      await File(path)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      stdout.writeln('report: $path');
    }
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => stop());
  ProcessSignal.sigterm.watch().listen((_) => stop());
}
