// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import '../../models/feedback_summary.dart';
import '../../models/form_report.dart';
import 'form_analyzer.dart';

/// The list-row summary of [report]: the same findings the feedback screen
/// shows, cut down to the counts and the first thing to fix.
FeedbackSummary summarizeForm(
  FormReport report, {
  FormAnalyzer analyzer = const FormAnalyzer(),
}) {
  final issues = analyzer
      .analyze(report)
      .where((f) => f.kind == FindingKind.issue)
      .toList();
  final judged = report.reps.length;
  return FeedbackSummary(
    validReps: report.validReps,
    invalidReps: report.invalidReps,
    accuracy: judged == 0 ? null : report.validReps / judged,
    topIssue: _fit(issues.firstOrNull?.title),
    issueCount: issues.length,
  );
}

/// The server keeps at most 80 characters of the title.
String? _fit(String? title) =>
    title == null || title.length <= 80 ? title : title.substring(0, 80);
