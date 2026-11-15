import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';

/// A form report for the feedback screen's tests: the counted reps at
/// [depths], one every [repGap] seconds from 2 s, then a rejected rep for
/// each of [rejected], over a [round] with a sample every half second.
///
/// The samples hold a depth (unless [depthSamples] is false, like an AI
/// squat's, issue #59) deep enough for the push-up arm rules, and the
/// elbows [leftElbow] / [rightElbow] and the [hipAngle] (null: not seen).
/// [samples] caps how many there are; [extraSamples] are added after them,
/// e.g. a frame handled after the round ended.
FormReport feedbackReport({
  ExerciseType exercise = ExerciseType.pushUp,
  List<double> depths = const [1.2, 1.2, 1.2, 1.2],
  List<RejectReason> rejected = const [],
  Duration round = const Duration(seconds: 30),
  int repGap = 2,
  bool depthSamples = true,
  double? leftElbow = 100,
  double? rightElbow = 104,
  double? hipAngle = 150,
  int? samples,
  double? minElbowAngle = 90,
  DateTime? endedAt,
  List<FormSample> extraSamples = const [],
}) {
  final count = samples ?? round.inMilliseconds ~/ 500 + 1;
  return FormReport(
    endedAt: endedAt ?? DateTime(2026, 11, 15, 9, 5),
    opponentName: 'AI 봇 · 고수',
    exercise: exercise,
    roundLength: round,
    reps: [
      for (var i = 0; i < depths.length; i++)
        RepRecord(
          index: i + 1,
          valid: true,
          at: Duration(seconds: 2 + i * repGap),
          maxDepth: depths[i],
          minElbowAngle: minElbowAngle,
        ),
      for (var j = 0; j < rejected.length; j++)
        RepRecord(
          index: depths.length + j + 1,
          valid: false,
          at: Duration(seconds: 2 + (depths.length + j) * repGap),
          reason: rejected[j],
          maxDepth: 0.5,
          minElbowAngle: minElbowAngle,
        ),
    ],
    samples: [
      for (var k = 0; k < count; k++)
        FormSample(
          at: Duration(milliseconds: k * 500),
          depth: depthSamples ? 0.8 + (k % 4) * 0.1 : null,
          leftElbow: leftElbow,
          rightElbow: rightElbow,
          hipAngle: hipAngle,
        ),
      ...extraSamples,
    ],
  );
}

/// Issue #58's squat: counted reps at 0.95, 0.95, 0.80, 0.80 of the standing
/// thigh, a 0.15 loss: the squat line exactly, a third of the push-up one.
FormReport issue58Squat({ExerciseType exercise = ExerciseType.squat}) =>
    feedbackReport(
      exercise: exercise,
      depths: const [0.95, 0.95, 0.80, 0.80],
      leftElbow: 60,
      rightElbow: 170,
    );
