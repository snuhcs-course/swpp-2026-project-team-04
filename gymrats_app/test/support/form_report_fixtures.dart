// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
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
