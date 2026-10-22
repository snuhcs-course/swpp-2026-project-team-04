// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/feedback_summary.dart';

void main() {
  test('reads and writes the server summary fields', () {
    const json = {
      'valid_reps': 12,
      'invalid_reps': 2,
      'accuracy': 0.857,
      'top_issue': '팔꿈치가 벌어져요',
      'issue_count': 1,
    };
    final summary = FeedbackSummary.fromJson(json);
    expect(summary.validReps, 12);
    expect(summary.invalidReps, 2);
    expect(summary.accuracy, 0.857);
    expect(summary.topIssue, '팔꿈치가 벌어져요');
    expect(summary.issueCount, 1);
    expect(summary.toJson(), json);
  });

  test('an integer accuracy and missing optional values still read', () {
    final summary = FeedbackSummary.fromJson(const {
      'valid_reps': 0,
      'invalid_reps': 0,
      'accuracy': 1,
      'issue_count': 0,
    });
    expect(summary.accuracy, 1.0);
    expect(summary.topIssue, isNull);
  });

  test('the row line is the top issue, or praise without one', () {
    const withIssue = FeedbackSummary(
      validReps: 5,
      invalidReps: 1,
      issueCount: 2,
      topIssue: '깊이 부족 1회',
    );
    const clean = FeedbackSummary(validReps: 5, invalidReps: 0, issueCount: 0);
    expect(withIssue.line, '깊이 부족 1회');
    expect(clean.line, '좋은 자세');
  });
}
