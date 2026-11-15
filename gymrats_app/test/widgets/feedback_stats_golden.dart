import 'dart:convert';
import 'dart:io';

import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';

/// The mockup's numbers (W7-STATS `w7_golden.json`, made from
/// `dc/W7A.dc.html`): 67 stored battles and 11 cases.
const goldenStatsPath = 'test/widgets/feedback_stats_golden.json';

Map<String, dynamic> readStatsGolden() =>
    jsonDecode(File(goldenStatsPath).readAsStringSync())
        as Map<String, dynamic>;

/// The 67 battles as the app's statistics points, in local time; those
/// before [since] are left out (the mockup's shorter histories).
List<StatsPoint> goldenStatsPoints({DateTime? since}) => [
  for (final p in readStatsGolden()['points'] as List)
    if (since == null ||
        !DateTime.parse(p['playedAt'] as String).isBefore(since))
      StatsPoint(
        id: p['id'] as int,
        exercise: p['exercise'] == 'squat'
            ? ExerciseType.squat
            : ExerciseType.pushUp,
        playedAt: DateTime.parse(p['playedAt'] as String),
        reps: p['reps'] as int,
        hasFeedback: p['hasFeedback'] as bool,
        issues: (p['issues'] as Map).cast<String, int>(),
      ),
];

/// The end of [ymd]'s day ("2026-11-14"), the cases' "now".
DateTime goldenDayEnd(String ymd) {
  final [y, m, d] = ymd.split('-').map(int.parse).toList();
  return DateTime(y, m, d, 23, 59, 59);
}

/// The case named [id].
Map<String, dynamic> goldenStatsCase(String id) =>
    (readStatsGolden()['cases'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((c) => c['id'] == id);
