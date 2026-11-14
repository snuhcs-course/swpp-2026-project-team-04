// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/services/feedback/form_analyzer.dart';
import 'package:gymrats_app/services/feedback/form_summary.dart';

import '../../support/form_report_fixtures.dart';

/// Returns fixed findings, so the summary is tested on its own.
class _FixedAnalyzer extends FormAnalyzer {
  const _FixedAnalyzer(this.findings);

  final List<FormFinding> findings;

  @override
  List<FormFinding> analyze(FormReport report) => findings;
}

FormFinding _finding(FindingKind kind, String title) =>
    FormFinding(kind: kind, title: title, detail: '');

void main() {
  test('counts the reps and takes the first issue as the row line', () {
    final summary = summarizeForm(
      sampleReport(valid: 3, rejected: 1),
      analyzer: _FixedAnalyzer([
        _finding(FindingKind.good, '좋아요'),
        _finding(FindingKind.issue, '깊이 부족 1회'),
        _finding(FindingKind.issue, '후반 깊이 감소'),
        _finding(FindingKind.note, '팔꿈치 각도'),
      ]),
    );
    expect(summary.validReps, 3);
    expect(summary.invalidReps, 1);
    expect(summary.accuracy, 0.75);
    expect(summary.topIssue, '깊이 부족 1회');
    expect(summary.issueCount, 2);
  });

  test('no judged rep has no accuracy; no issue has no top issue', () {
    final summary = summarizeForm(
      sampleReport(valid: 0),
      analyzer: _FixedAnalyzer([_finding(FindingKind.good, '좋아요')]),
    );
    expect(summary.accuracy, isNull);
    expect(summary.topIssue, isNull);
    expect(summary.issueCount, 0);
  });

  test('a long title is cut to what the server keeps', () {
    final summary = summarizeForm(
      sampleReport(),
      analyzer: _FixedAnalyzer([_finding(FindingKind.issue, '가' * 100)]),
    );
    expect(summary.topIssue, '가' * 80);
  });

  test('the real analyzer agrees with the feedback screen', () {
    final report = sampleReport(valid: 2, rejected: 2);
    final issues = const FormAnalyzer()
        .analyze(report)
        .where((f) => f.kind == FindingKind.issue)
        .toList();
    final summary = summarizeForm(report);
    expect(summary.issueCount, issues.length);
    expect(summary.topIssue, issues.firstOrNull?.title);
    expect(summary.issues, {'reject.insufficientDepth': 2});
  });

  test('issue codes with counts; findings without a code are left out', () {
    final summary = summarizeForm(
      sampleReport(),
      analyzer: const _FixedAnalyzer([
        FormFinding(
          kind: FindingKind.issue,
          title: '얕음 3회',
          detail: '',
          code: 'reject.insufficientDepth',
          count: 3,
        ),
        FormFinding(
          kind: FindingKind.issue,
          title: '팔꿈치',
          detail: '',
          code: 'elbow_flare',
        ),
        FormFinding(kind: FindingKind.issue, title: '코드 없음', detail: ''),
        FormFinding(kind: FindingKind.good, title: '좋아요', detail: ''),
      ]),
    );
    expect(summary.issueCount, 3);
    expect(summary.issues, {'reject.insufficientDepth': 3, 'elbow_flare': 1});
  });

  test('a clean battle has no issue codes', () {
    expect(summarizeForm(sampleReport()).issues, isEmpty);
  });
}
