import 'dart:math' as math;

import 'package:gymrats_app/models/rep_event.dart';

import 'eval_plan.dart';

/// One evaluated set: what the person did and what the judge said.
class EvalCase {
  const EvalCase({
    required this.id,
    required this.person,
    required this.set,
    required this.labelled,
    required this.judged,
  });

  final String id;
  final String person;
  final EvalSet set;

  /// The reps the person actually did, in order: null for a correct rep,
  /// else the reason it should be rejected with.
  final List<RejectReason?> labelled;

  /// The reps the judge closed, in order: null for a counted rep.
  final List<RejectReason?> judged;

  PhonePosition get position => set.position;
}

/// Counts behind M1–M3 over a group of cases.
class EvalTally {
  int normalReps = 0;
  int normalCounted = 0;
  int incorrectReps = 0;
  int incorrectNotCounted = 0;
  int incorrectRightReason = 0;

  /// Reps the judge closed that line up with no labelled rep.
  int extraCounted = 0;
  int extraRejected = 0;

  /// M1: correct reps counted ÷ correct reps done. Null with none done.
  double? get m1 => _share(normalCounted, normalReps);

  /// M2: incorrect reps not counted ÷ incorrect reps done.
  double? get m2 => _share(incorrectNotCounted, incorrectReps);

  /// M3: incorrect reps rejected with the right reason ÷ incorrect reps done.
  double? get m3 => _share(incorrectRightReason, incorrectReps);

  bool get passes =>
      (m1 ?? 0) >= m1CountAccuracyThreshold &&
      (m2 ?? 0) >= m2RejectionRateThreshold &&
      (m3 ?? 0) >= m3RightReasonThreshold;

  void add(EvalCase c) {
    for (final (want, got) in align(c.labelled, c.judged)) {
      if (want == null && got == null) continue;
      if (want == null) {
        // A judged rep with no labelled one.
        if (got!.counted) {
          extraCounted++;
        } else {
          extraRejected++;
        }
      } else if (want.correct) {
        normalReps++;
        if (got != null && got.counted) normalCounted++;
      } else {
        incorrectReps++;
        // A rep the judge never closed was not counted either.
        if (got == null || !got.counted) incorrectNotCounted++;
        if (got != null && got.reason == want.reason) incorrectRightReason++;
      }
    }
  }

  static double? _share(int part, int whole) =>
      whole == 0 ? null : part / whole;
}

/// One rep verdict: counted when [reason] is null.
class Verdict {
  const Verdict(this.reason);

  final RejectReason? reason;

  bool get counted => reason == null;

  /// Same as [counted], read on a labelled rep.
  bool get correct => reason == null;
}

/// Lines up [labelled] and [judged] reps by the fewest edits, so one rep
/// the judge never closed does not shift every later rep. Each pair holds
/// the labelled rep and the judged rep; either side is null where a rep
/// has no partner.
List<(Verdict?, Verdict?)> align(
  List<RejectReason?> labelled,
  List<RejectReason?> judged,
) {
  final n = labelled.length, m = judged.length;
  // cost[i][j]: edits to turn labelled[i..] into judged[j..].
  final cost = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n; i >= 0; i--) {
    for (var j = m; j >= 0; j--) {
      if (i == n || j == m) {
        cost[i][j] = (n - i) + (m - j);
      } else {
        final same = labelled[i] == judged[j] ? 0 : 1;
        cost[i][j] = math.min(
          cost[i + 1][j + 1] + same,
          math.min(cost[i + 1][j], cost[i][j + 1]) + 1,
        );
      }
    }
  }
  final pairs = <(Verdict?, Verdict?)>[];
  var i = 0, j = 0;
  while (i < n || j < m) {
    final same = i < n && j < m && labelled[i] == judged[j] ? 0 : 1;
    if (i < n && j < m && cost[i][j] == cost[i + 1][j + 1] + same) {
      pairs.add((Verdict(labelled[i++]), Verdict(judged[j++])));
    } else if (i < n && cost[i][j] == cost[i + 1][j] + 1) {
      pairs.add((Verdict(labelled[i++]), null));
    } else {
      pairs.add((null, Verdict(judged[j++])));
    }
  }
  return pairs;
}

/// M1–M3 over all cases, per phone position, and per person.
class EvalReport {
  EvalReport(Iterable<EvalCase> cases) {
    for (final c in cases) {
      overall.add(c);
      byPosition.putIfAbsent(c.position, EvalTally.new).add(c);
      byPerson.putIfAbsent(c.person, EvalTally.new).add(c);
      caseCount++;
    }
  }

  final overall = EvalTally();
  final byPosition = <PhonePosition, EvalTally>{};
  final byPerson = <String, EvalTally>{};
  int caseCount = 0;

  /// The result tables in Markdown, for the wiki and the results branch.
  String toMarkdown() {
    final o = overall;
    final rows = <String>[
      '| Metric | Value | Threshold | Result |',
      '|---|---|---|---|',
      _metricRow(
        'M1 Count accuracy',
        o.m1,
        o.normalCounted,
        o.normalReps,
        m1CountAccuracyThreshold,
      ),
      _metricRow(
        'M2 Rejection rate',
        o.m2,
        o.incorrectNotCounted,
        o.incorrectReps,
        m2RejectionRateThreshold,
      ),
      _metricRow(
        'M3 Right reason',
        o.m3,
        o.incorrectRightReason,
        o.incorrectReps,
        m3RightReasonThreshold,
      ),
      '',
      '$caseCount cases. Judged reps with no labelled rep: '
          '${o.extraCounted} counted, ${o.extraRejected} rejected.',
      '',
      '| Group | M1 | M2 | M3 |',
      '|---|---|---|---|',
      for (final p in PhonePosition.values)
        if (byPosition[p] case final t?)
          '| Position ${p.code} | ${_pct(t.m1)} | ${_pct(t.m2)} | ${_pct(t.m3)} |',
      for (final e
          in byPerson.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        '| ${e.key} | ${_pct(e.value.m1)} | ${_pct(e.value.m2)} | '
            '${_pct(e.value.m3)} |',
    ];
    return rows.join('\n');
  }

  static String _metricRow(
    String name,
    double? value,
    int part,
    int whole,
    double threshold,
  ) {
    final result = value == null
        ? 'no data'
        : value >= threshold
        ? 'pass'
        : 'fail';
    return '| $name | ${_pct(value)} ($part/$whole) | '
        '≥ ${_pct(threshold)} | $result |';
  }

  static String _pct(double? v) =>
      v == null ? '–' : '${(v * 100).toStringAsFixed(1)}%';
}
