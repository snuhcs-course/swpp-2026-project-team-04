/// Numbers the P20 load test reports: distributions of times and counts of
/// outcomes, kept as plain data so a run can be written to JSON and read
/// back.
library;

import 'dart:math' as math;

/// A sorted sample of whole numbers (milliseconds, or microseconds).
class Distribution {
  Distribution(Iterable<num> values)
    : sorted = values.map((v) => v.toDouble()).toList()..sort();

  final List<double> sorted;

  int get count => sorted.length;
  double? get min => sorted.isEmpty ? null : sorted.first;
  double? get max => sorted.isEmpty ? null : sorted.last;
  double? get mean => sorted.isEmpty
      ? null
      : sorted.fold<double>(0, (sum, v) => sum + v) / sorted.length;

  /// The [q]-th percentile (0–100) by nearest rank: the smallest value that
  /// at least [q]% of the sample is at or below. Null for an empty sample.
  double? percentile(num q) {
    if (q < 0 || q > 100) throw RangeError.range(q, 0, 100, 'q');
    if (sorted.isEmpty) return null;
    if (q == 0) return sorted.first;
    final rank = (q / 100 * sorted.length).ceil();
    return sorted[math.max(rank, 1) - 1];
  }

  /// How many values fall in each bucket: below the first edge, between
  /// consecutive [edges], and at or above the last one.
  List<int> histogram(List<num> edges) {
    final counts = List.filled(edges.length + 1, 0);
    for (final v in sorted) {
      var i = 0;
      while (i < edges.length && v >= edges[i]) {
        i++;
      }
      counts[i]++;
    }
    return counts;
  }

  /// The labels of [histogram]'s buckets, as `<e0`, `e0–e1`, …, `≥en`.
  static List<String> bucketLabels(List<num> edges, {String unit = ''}) => [
    if (edges.isNotEmpty) '<${edges.first}$unit',
    for (var i = 0; i + 1 < edges.length; i++)
      '${edges[i]}–${edges[i + 1]}$unit',
    if (edges.isNotEmpty) '≥${edges.last}$unit' else 'all',
  ];

  Map<String, Object?> toJson() => {
    'count': count,
    'min': min,
    'p50': percentile(50),
    'p90': percentile(90),
    'p95': percentile(95),
    'p99': percentile(99),
    'max': max,
    'mean': mean == null ? null : double.parse(mean!.toStringAsFixed(2)),
  };

  /// `n=… p50=… p90=… p99=… max=…`, or `n=0`.
  String summary({String unit = 'ms'}) {
    if (sorted.isEmpty) return 'n=0';
    String f(double? v) => '${v!.toStringAsFixed(v < 10 ? 2 : 0)}$unit';
    return 'n=$count min=${f(min)} p50=${f(percentile(50))} '
        'p90=${f(percentile(90))} p95=${f(percentile(95))} '
        'p99=${f(percentile(99))} max=${f(max)}';
  }
}

/// Adds one to [key] in [counts].
void tally(Map<String, int> counts, String key) =>
    counts[key] = (counts[key] ?? 0) + 1;

/// [counts] sorted by key, so two runs print in the same order.
Map<String, int> sortedCounts(Map<String, int> counts) => {
  for (final key in counts.keys.toList()..sort()) key: counts[key]!,
};
