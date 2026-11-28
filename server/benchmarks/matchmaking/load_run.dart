/// A P20 load run: [runLoad] starts [LoadPlan.users] bots spread over
/// [LoadPlan.rampMs], samples how many are connected, queued and in a
/// match each second, and sums up what they saw in [LoadReport].
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'load_bot.dart';
import 'load_stats.dart';

class LoadPlan {
  const LoadPlan({
    required this.bot,
    this.users = 200,
    this.rampMs = 20000,
    this.seed = 20,
    this.idPrefix = 'load',
    this.stopAfterMs = 900000,
    this.sampleMs = 1000,
  });

  final BotConfig bot;

  /// Bots in the run; bot i starts at i × [rampMs] / [users].
  final int users, rampMs;

  /// Seeds every bot's choices (exercise, delays, reps), so a run repeats.
  final int seed;

  /// Bot ids are `<idPrefix>-001`, …
  final String idPrefix;

  /// Bots still running this long after the start are stopped.
  final int stopAfterMs;
  final int sampleMs;

  Map<String, Object?> toJson() => {
    'url': bot.url.toString(),
    'users': users,
    'ramp_ms': rampMs,
    'seed': seed,
    'rounds_per_user': bot.rounds,
    'exercises': bot.exercises,
    'pose_interval_ms': bot.poseIntervalMs,
    'ping_interval_ms': bot.pingIntervalMs,
    'setup_ms': [bot.setupMs.$1, bot.setupMs.$2],
    'ready_ms': [bot.readyMs.$1, bot.readyMs.$2],
    'think_ms': [bot.thinkMs.$1, bot.thinkMs.$2],
    'reps_per_round': [bot.repsPerRound.$1, bot.repsPerRound.$2],
    'connect_timeout_ms': bot.connectTimeoutMs,
    'round_timeout_ms': bot.roundTimeoutMs,
    'stop_after_ms': stopAfterMs,
  };
}

/// One timeline sample: bots in each state.
class LoadSample {
  const LoadSample(this.atMs, this.connected, this.queued, this.inMatch);
  final int atMs, connected, queued, inMatch;
  Map<String, int> toJson() => {
    'at_ms': atMs,
    'connected': connected,
    'queued': queued,
    'in_match': inMatch,
  };
}

/// Queue-wait buckets, in ms: around the 10 s simulated-opponent wait.
const queueWaitEdges = [100, 1000, 5000, 10000, 10500, 11000, 15000];

/// A run's summary.
class LoadReport {
  LoadReport(this.plan, this.records, this.samples, this.wallMs);

  final LoadPlan plan;
  final List<BotRecord> records;
  final List<LoadSample> samples;
  final int wallMs;

  Iterable<RoundRecord> get rounds => records.expand((r) => r.rounds);

  int get connected => records.where((r) => r.connectMs != null).length;
  int get peakConnected => samples.fold(0, (m, s) => max(m, s.connected));
  int get peakInMatch => samples.fold(0, (m, s) => max(m, s.inMatch));
  int get peakQueued => samples.fold(0, (m, s) => max(m, s.queued));

  /// Rounds that ended in a finished battle.
  int get succeeded =>
      rounds.where((r) => r.outcome.startsWith('finished:')).length;
  int get failed => rounds.length - succeeded;

  Map<String, int> get outcomes {
    final counts = <String, int>{};
    for (final r in rounds) {
      tally(counts, r.outcome);
    }
    return sortedCounts(counts);
  }

  Map<String, int> get connectErrors {
    final counts = <String, int>{};
    for (final r in records) {
      if (r.connectError case final e?) tally(counts, e);
    }
    return sortedCounts(counts);
  }

  Map<String, int> get serverErrors {
    final counts = <String, int>{};
    for (final r in records) {
      for (final MapEntry(:key, :value) in r.errors.entries) {
        counts[key] = (counts[key] ?? 0) + value;
      }
    }
    return sortedCounts(counts);
  }

  Map<String, int> get unexpectedCloses {
    final counts = <String, int>{};
    for (final r in records) {
      if (r.unexpectedClose case final code?) tally(counts, '$code');
    }
    return sortedCounts(counts);
  }

  Distribution queueWait({bool? simulated}) => Distribution([
    for (final r in rounds)
      if (r.queueWaitMs case final ms?
          when simulated == null || r.simulated == simulated)
        ms,
  ]);

  Distribution get connectMs =>
      Distribution([for (final r in records) ?r.connectMs]);
  Distribution get foundToStart =>
      Distribution([for (final r in rounds) ?r.foundToStartMs]);
  Distribution get repAck => Distribution(records.expand((r) => r.repAckMs));

  int get matchedReal => rounds.where((r) => r.simulated == false).length;
  int get matchedSimulated => rounds.where((r) => r.simulated == true).length;

  /// How many different accounts the simulated opponents copied (by their
  /// nickname): one or two when every bot falls back to the same average
  /// estimate, many when each bot's own estimate is used.
  int get simulatedOpponents => {
    for (final r in rounds)
      if (r.simulated == true) ?r.opponentName,
  }.length;

  int _sum(int Function(RoundRecord r) f) =>
      rounds.fold(0, (sum, r) => sum + f(r));

  Map<String, Object?> toJson() => {
    'plan': plan.toJson(),
    'client': {
      'dart': Platform.version.split(' ').first,
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'processors': Platform.numberOfProcessors,
      'compiled': Platform.executable.endsWith('dart') ? 'jit' : 'aot',
    },
    'wall_ms': wallMs,
    'users': records.length,
    'connected': connected,
    'connect_errors': connectErrors,
    'peak_connected': peakConnected,
    'peak_queued': peakQueued,
    'peak_in_match': peakInMatch,
    'rounds': rounds.length,
    'succeeded': succeeded,
    'failed': failed,
    'outcomes': outcomes,
    'matched_real': matchedReal,
    'matched_simulated': matchedSimulated,
    'simulated_opponents_distinct': simulatedOpponents,
    'server_errors': serverErrors,
    'unexpected_closes': unexpectedCloses,
    'connect_ms': connectMs.toJson(),
    'queue_wait_ms': {
      'all': queueWait().toJson(),
      'real': queueWait(simulated: false).toJson(),
      'simulated': queueWait(simulated: true).toJson(),
      'buckets': Distribution.bucketLabels(queueWaitEdges, unit: 'ms'),
      'histogram_all': queueWait().histogram(queueWaitEdges),
    },
    'found_to_start_ms': foundToStart.toJson(),
    'rep_ack_ms': repAck.toJson(),
    'reps_sent': _sum((r) => r.repsSent),
    'reps_acked': _sum((r) => r.repAckMs.length),
    'poses_sent': _sum((r) => r.posesSent),
    'poses_received': _sum((r) => r.posesReceived),
    'timeline': [for (final s in samples) s.toJson()],
  };

  /// The lines [load_client.dart] prints.
  List<String> summaryLines() => [
    'users=${records.length} connected=$connected '
        'connect_errors=$connectErrors wall=${wallMs}ms',
    'peak connected=$peakConnected queued=$peakQueued in_match=$peakInMatch',
    'rounds=${rounds.length} succeeded=$succeeded failed=$failed '
        'real=$matchedReal simulated=$matchedSimulated '
        '(copying $simulatedOpponents accounts)',
    'outcomes=$outcomes',
    'server_errors=$serverErrors unexpected_closes=$unexpectedCloses',
    'connect: ${connectMs.summary()}',
    'queue wait all: ${queueWait().summary()}',
    'queue wait real: ${queueWait(simulated: false).summary()}',
    'queue wait simulated: ${queueWait(simulated: true).summary()}',
    'queue wait buckets: ${{for (final (i, label) in Distribution.bucketLabels(queueWaitEdges, unit: 'ms').indexed) label: queueWait().histogram(queueWaitEdges)[i]}}',
    'found→start: ${foundToStart.summary()}',
    'rep ack: ${repAck.summary()}',
    'reps sent=${_sum((r) => r.repsSent)} acked=${_sum((r) => r.repAckMs.length)} '
        'poses sent=${_sum((r) => r.posesSent)} '
        'received=${_sum((r) => r.posesReceived)}',
  ];
}

/// Runs [plan] and sums it up.
Future<LoadReport> runLoad(LoadPlan plan) async {
  final seeds = Random(plan.seed);
  final bots = [
    for (var i = 1; i <= plan.users; i++)
      LoadBot(
        config: plan.bot,
        playerId: botId(plan.idPrefix, i, plan.users),
        displayName:
            'Load ${botId(plan.idPrefix, i, plan.users).split('-').last}',
        random: Random(seeds.nextInt(1 << 32)),
      ),
  ];
  final clock = Stopwatch()..start();
  final samples = <LoadSample>[];
  void sample() {
    var connected = 0, queued = 0, inMatch = 0;
    for (final b in bots) {
      switch (b.state) {
        case BotState.queued:
          queued++;
          connected++;
        case BotState.inMatch:
          inMatch++;
          connected++;
        case BotState.thinking:
          connected++;
        case BotState.idle || BotState.connecting || BotState.done:
          break;
      }
    }
    samples.add(
      LoadSample(clock.elapsedMilliseconds, connected, queued, inMatch),
    );
  }

  final sampler = Timer.periodic(
    Duration(milliseconds: plan.sampleMs),
    (_) => sample(),
  );
  final stopper = Timer(Duration(milliseconds: plan.stopAfterMs), () {
    for (final b in bots) {
      b.stop();
    }
  });
  final runs = <Future<BotRecord>>[];
  for (var i = 0; i < bots.length; i++) {
    final at = plan.users <= 1 ? 0 : i * plan.rampMs ~/ plan.users;
    final wait = at - clock.elapsedMilliseconds;
    if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
    runs.add(bots[i].run());
  }
  final records = await Future.wait(runs);
  sampler.cancel();
  stopper.cancel();
  sample();
  return LoadReport(plan, records, samples, clock.elapsedMilliseconds);
}
