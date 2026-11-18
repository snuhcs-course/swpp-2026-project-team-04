import 'dart:math' as math;

/// String labels preserve the frozen scorer's minimum-edit semantics for both
/// push-up and squat reasons.
List<(String?, String?)> alignLabels(
  List<String> expected,
  List<String> actual,
) {
  final n = expected.length, m = actual.length;
  final cost = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n; i >= 0; i--) {
    for (var j = m; j >= 0; j--) {
      cost[i][j] = i == n || j == m
          ? n - i + m - j
          : math.min(
              cost[i + 1][j + 1] + (expected[i] == actual[j] ? 0 : 1),
              math.min(cost[i + 1][j], cost[i][j + 1]) + 1,
            );
    }
  }
  final result = <(String?, String?)>[];
  var i = 0, j = 0;
  while (i < n || j < m) {
    final same = i < n && j < m && expected[i] == actual[j] ? 0 : 1;
    if (i < n && j < m && cost[i][j] == cost[i + 1][j + 1] + same) {
      result.add((expected[i++], actual[j++]));
    } else if (i < n && cost[i][j] == cost[i + 1][j] + 1) {
      result.add((expected[i++], null));
    } else {
      result.add((null, actual[j++]));
    }
  }
  return result;
}

class Iter4Tally {
  int normal = 0, normalCounted = 0, incorrect = 0, incorrectNotCounted = 0;
  int rightReason = 0, explicitRejected = 0, missedIncorrect = 0;
  int extraCounted = 0, extraRejected = 0, pendingCases = 0, scoredCases = 0;
  double? get m1 => normal == 0 ? null : normalCounted / normal;
  double? get m2 => incorrect == 0 ? null : incorrectNotCounted / incorrect;
  double? get m3 => incorrect == 0 ? null : rightReason / incorrect;

  void add(List<String>? expected, List<String> actual) {
    if (expected == null) {
      pendingCases++;
      return;
    }
    scoredCases++;
    for (final (want, got) in alignLabels(expected, actual)) {
      if (want == null) {
        if (got == 'valid') {
          extraCounted++;
        } else {
          extraRejected++;
        }
      } else if (want == 'valid') {
        normal++;
        if (got == 'valid') normalCounted++;
      } else {
        incorrect++;
        if (got != 'valid') incorrectNotCounted++;
        if (got == null) {
          missedIncorrect++;
        } else if (got != 'valid') {
          explicitRejected++;
        }
        if (got == want) rightReason++;
      }
    }
  }

  Map<String, Object?> toJson() => {
    'm1': m1,
    'm2': m2,
    'm3': m3,
    'normal': normal,
    'normalCounted': normalCounted,
    'incorrect': incorrect,
    'incorrectNotCounted': incorrectNotCounted,
    'rightReason': rightReason,
    'explicitRejected': explicitRejected,
    'missedIncorrect': missedIncorrect,
    'extraCounted': extraCounted,
    'extraRejected': extraRejected,
    'pendingCases': pendingCases,
    'scoredCases': scoredCases,
  };
}

/// Requires complete human labels and a Pareto gain on primary M1/M2.
/// This recommendation never rewrites the app's build default automatically.
bool verifiedBenefit(Iter4Tally off, Iter4Tally on) =>
    off.pendingCases == 0 &&
    on.pendingCases == 0 &&
    off.scoredCases > 0 &&
    off.scoredCases == on.scoredCases &&
    off.m1 != null &&
    on.m1 != null &&
    off.m2 != null &&
    on.m2 != null &&
    on.m1! >= off.m1! &&
    on.m2! >= off.m2! &&
    (on.m1! > off.m1! || on.m2! > off.m2!);
