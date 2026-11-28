/// P10 → P20: the skill index's build cost apart from its search cost, at
/// growing account counts, with [measureSkillIndex]. Each size is measured
/// [_repeats] times after a warm-up and the median is printed.
///
///   dart run server/benchmarks/matchmaking/skill_index_bench.dart
library;

import 'dart:convert';
import 'dart:io';

import '../../lib/skill_matchmaker.dart';
import 'load_server.dart' show SyntheticSkills;
import 'load_stats.dart';

const _sizes = [100, 1000, 10000, 100000];
const _repeats = 5;
const _lookups = 10000;

/// Median build and per-lookup cost for [accounts] synthetic accounts.
Map<String, Object?> measureSize(int accounts, {int repeats = _repeats}) {
  final records = SyntheticSkills(accounts: accounts).records();
  final skills = [for (var i = 0; i < 97; i++) i * 0.3];
  measureSkillIndex(records, skills, lookups: _lookups); // warm-up
  final runs = [
    for (var i = 0; i < repeats; i++)
      measureSkillIndex(records, skills, lookups: _lookups),
  ];
  final build = Distribution(runs.map((r) => r.buildMicros));
  final lookup = Distribution(runs.map((r) => r.microsPerLookup));
  return {
    'accounts': accounts,
    'repeats': repeats,
    'lookups': _lookups,
    'build_us_median': build.percentile(50),
    'build_us_max': build.max,
    'lookup_us_median': lookup.percentile(50),
    'lookup_us_max': lookup.max,
  };
}

void main(List<String> args) {
  final rows = [for (final n in _sizes) measureSize(n)];
  stdout.writeln(
    'dart ${Platform.version.split(' ').first} '
    '${Platform.operatingSystem} cpus=${Platform.numberOfProcessors}',
  );
  for (final row in rows) {
    stdout.writeln(jsonEncode(row));
  }
}
