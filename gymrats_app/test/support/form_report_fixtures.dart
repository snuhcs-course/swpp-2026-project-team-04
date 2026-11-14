// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';

/// A small form report: [valid] counted reps and [rejected] shallow ones.
FormReport sampleReport({int valid = 3, int rejected = 0, DateTime? endedAt}) =>
    FormReport(
      endedAt: endedAt ?? DateTime.utc(2026, 10, 21, 3),
      opponentName: 'RepBot',
      roundLength: const Duration(seconds: 30),
      reps: [
        for (var i = 0; i < valid + rejected; i++)
          RepRecord(
            index: i + 1,
            valid: i < valid,
            at: Duration(seconds: i * 2),
            reason: i < valid ? null : RejectReason.insufficientDepth,
            maxDepth: 1.5,
          ),
      ],
      samples: [
        for (var i = 0; i < 5; i++)
          FormSample(at: Duration(milliseconds: i * 100), depth: 1.0),
      ],
    );

/// The UAT-4 squat run: [full] counted squats then [shallow] too-shallow
/// ones, with push-up-only measurements (flared elbows, wide hands, uneven
/// arms) that the squat rules must ignore.
FormReport squatReport({
  int full = 4,
  int shallow = 2,
  int standUp = 0,
  double depth = 0.9,
  DateTime? endedAt,
}) => FormReport(
  endedAt: endedAt ?? DateTime.utc(2026, 11, 14, 3),
  opponentName: 'AI 봇 · 고수',
  exercise: ExerciseType.squat,
  roundLength: const Duration(seconds: 30),
  reps: [
    for (var i = 0; i < full; i++)
      RepRecord(
        index: i + 1,
        valid: true,
        at: Duration(seconds: i * 3),
        maxDepth: depth,
      ),
    for (var i = 0; i < shallow; i++)
      RepRecord(
        index: full + i + 1,
        valid: false,
        at: Duration(seconds: (full + i) * 3),
        reason: RejectReason.shallowSquat,
        maxDepth: 0.55,
      ),
    for (var i = 0; i < standUp; i++)
      RepRecord(
        index: full + shallow + i + 1,
        valid: false,
        at: Duration(seconds: (full + shallow + i) * 3),
        reason: RejectReason.standUpFully,
        maxDepth: 0.8,
      ),
  ],
  samples: [
    for (var i = 0; i < 20; i++)
      FormSample(
        at: Duration(milliseconds: i * 100),
        depth: 0.8,
        leftElbow: 60,
        rightElbow: 170,
        leftSpread: 1.5,
        rightSpread: 1.5,
        handSpan: 3,
        shoulderDrop: 0.4,
      ),
  ],
);
