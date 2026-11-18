import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/feedback/coach_script.dart';
import 'package:gymrats_app/viewmodels/feedback_viewmodel.dart';

/// When the A10 test battles end.
final coachEndedAt = DateTime(2026, 11, 17, 14, 30);

/// A battle of [exercise] whose counted reps closed at [valid] seconds into
/// a [roundSeconds] round and whose rejected ones at [rejected] (seconds
/// and reason). No samples: only the reps' rules speak.
FormReport coachReport({
  List<double> valid = const [],
  List<(double, RejectReason)> rejected = const [],
  double roundSeconds = 30,
  ExerciseType exercise = ExerciseType.squat,
  DateTime? endedAt,
}) {
  final reps = <(double, RejectReason?)>[
    for (final t in valid) (t, null),
    for (final (t, reason) in rejected) (t, reason),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return FormReport(
    endedAt: endedAt ?? coachEndedAt,
    opponentName: 'RepBot',
    roundLength: Duration(milliseconds: (roundSeconds * 1000).round()),
    exercise: exercise,
    samples: const [],
    reps: [
      for (final (i, (t, reason)) in reps.indexed)
        RepRecord(
          index: i,
          valid: reason == null,
          at: Duration(milliseconds: (t * 1000).round()),
          reason: reason,
        ),
    ],
  );
}

/// [count] times from [from] to [to] seconds, evenly apart.
List<double> evenly(int count, {double from = 0.5, double to = 29.5}) => [
  for (var i = 0; i < count; i++)
    count == 1 ? from : from + (to - from) * i / (count - 1),
];

/// [count] reps spread evenly over the slice [slice] of a 30 s round.
List<double> inSlice(int slice, int count) =>
    evenly(count, from: slice * 5 + 0.4, to: slice * 5 + 4.6);

/// The design's battle (UxGfx): 5, 5, 2, 2, 2, 2 counted reps per 5 s.
List<double> designPace() => [
  ...inSlice(0, 5),
  ...inSlice(1, 5),
  for (var slice = 2; slice < 6; slice++) ...inSlice(slice, 2),
];

/// [report]'s pace, as the talk takes it from [FormFeedback].
CoachPace paceOf(FormReport report) {
  final feedback = FormFeedback.of(report);
  return CoachPace(
    buckets: feedback.paceBuckets,
    sliceSeconds: feedback.sliceSeconds,
  );
}

/// The talk's input for [report], by the app's own analyzer.
CoachInput coachInputOf(
  FormReport report, {
  String characterId = 'seal',
  List<CoachEarlier> earlier = const [],
}) => CoachInput(
  report: report,
  findings: FormFeedback.of(report).findings,
  pace: paceOf(report),
  characterId: characterId,
  earlier: earlier,
);

/// An earlier battle with [reps] counted reps, its pace of [buckets] in a
/// 30 s round (none: no form report) and its [combo].
CoachEarlier earlierBattle(int reps, {List<int>? buckets, int? combo}) =>
    CoachEarlier(
      reps: reps,
      pace: buckets == null
          ? null
          : CoachPace(buckets: buckets, sliceSeconds: 5),
      longestCombo: combo,
    );
