/// P20 load client: N simulated phones against a battle server that takes
/// development tokens (`load_server.dart`, or `bin/server.dart` with
/// `BATTLE_DEV_AUTH=1`). See docs/iteration-5/matchmaking-load.md.
///
///   dart run server/benchmarks/matchmaking/load_client.dart \
///     --url ws://127.0.0.1:8090/ws/v1/battle --users 200 --ramp-ms 20000 \
///     --rounds 3 --out /tmp/p20-client.json
library;

import 'dart:convert';
import 'dart:io';

import 'load_bot.dart';
import 'load_run.dart';

/// `--name value` pairs; a missing value is an error.
Map<String, String> parseArgs(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final name = args[i];
    if (!name.startsWith('--') || i + 1 >= args.length) {
      throw FormatException('Expected --name value, got "$name".');
    }
    options[name.substring(2)] = args[++i];
  }
  return options;
}

/// `min-max` or one number, as a range.
(int, int) parseRange(String text) {
  final parts = text.split('-').map(int.parse).toList();
  if (parts.length == 1) return (parts[0], parts[0]);
  if (parts.length != 2 || parts[0] > parts[1] || parts[0] < 0) {
    throw FormatException('Expected min-max, got "$text".');
  }
  return (parts[0], parts[1]);
}

/// The plan [args] ask for; the defaults are the documented scenario.
LoadPlan planFrom(Map<String, String> o) {
  int number(String name, int fallback) =>
      o[name] == null ? fallback : int.parse(o[name]!);
  (int, int) range(String name, (int, int) fallback) =>
      o[name] == null ? fallback : parseRange(o[name]!);
  final defaults = BotConfig(url: _defaultUrl);
  return LoadPlan(
    users: number('users', 200),
    rampMs: number('ramp-ms', 20000),
    seed: number('seed', 20),
    idPrefix: o['id-prefix'] ?? 'load',
    stopAfterMs: number('stop-after-ms', 900000),
    bot: BotConfig(
      url: Uri.parse(o['url'] ?? _defaultUrl.toString()),
      rounds: number('rounds', defaults.rounds),
      exercises: o['exercises']?.split(',') ?? defaults.exercises,
      poseIntervalMs: number('pose-interval-ms', defaults.poseIntervalMs),
      setupMs: range('setup-ms', defaults.setupMs),
      readyMs: range('ready-ms', defaults.readyMs),
      thinkMs: range('think-ms', defaults.thinkMs),
      repsPerRound: range('reps', defaults.repsPerRound),
      roundTimeoutMs: number('round-timeout-ms', defaults.roundTimeoutMs),
    ),
  );
}

final _defaultUrl = Uri.parse('ws://127.0.0.1:8090/ws/v1/battle');

Future<void> main(List<String> args) async {
  final LoadPlan plan;
  final Map<String, String> options;
  try {
    options = parseArgs(args);
    plan = planFrom(options);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
    return;
  }
  stdout.writeln('P20 load: ${jsonEncode(plan.toJson())}');
  final report = await runLoad(plan);
  report.summaryLines().forEach(stdout.writeln);
  if (options['out'] case final path?) {
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln('report: $path');
  }
}
