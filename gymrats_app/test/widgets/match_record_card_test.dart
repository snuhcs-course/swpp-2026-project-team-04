// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_summary.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/match_record_card.dart';

MatchRecord _match({FeedbackSummary? summary, MatchOutcome? outcome}) =>
    MatchRecord(
      id: 1,
      exercise: ExerciseType.pushUp,
      opponentName: '진영',
      myReps: 20,
      opponentReps: 3,
      playedAt: DateTime(2026, 10, 21, 9, 5),
      decidedOutcome: outcome,
      feedbackSummary: summary,
    );

const _issue = FeedbackSummary(
  validReps: 20,
  invalidReps: 2,
  issueCount: 2,
  topIssue: '팔꿈치가 벌어져요',
);
const _clean = FeedbackSummary(validReps: 20, invalidReps: 0, issueCount: 0);

void main() {
  Future<void> show(WidgetTester tester, Widget card) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: card),
      ),
    );
  }

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('a top issue reads in amber', (tester) async {
    await show(
      tester,
      MatchRecordCard(match: _match(summary: _issue), showFeedback: true),
    );
    expect(find.text('팔꿈치가 벌어져요'), findsOneWidget);
    expect(colorOf(tester, '팔꿈치가 벌어져요'), AppColors.warning);
  });

  testWidgets('nothing to fix reads 좋은 자세 in lime', (tester) async {
    await show(
      tester,
      MatchRecordCard(match: _match(summary: _clean), showFeedback: true),
    );
    expect(colorOf(tester, '좋은 자세'), AppColors.accent);
  });

  testWidgets('a battle without feedback reads 피드백 없음', (tester) async {
    await show(tester, MatchRecordCard(match: _match(), showFeedback: true));
    expect(colorOf(tester, '피드백 없음'), AppColors.textMuted);
  });

  testWidgets('the feedback line shows only when asked', (tester) async {
    await show(tester, MatchRecordCard(match: _match(summary: _issue)));
    expect(find.text('팔꿈치가 벌어져요'), findsNothing);
  });

  testWidgets('a forfeit shows 패 whatever the reps', (tester) async {
    await show(
      tester,
      MatchRecordCard(
        match: _match(outcome: MatchOutcome.lose),
        showDate: true,
        showFeedback: true,
      ),
    );
    expect(find.text('패'), findsOneWidget);
    expect(find.text('10월 21일 09:05'), findsOneWidget);
  });

  testWidgets('a long feedback line stays on one line without overflow', (
    tester,
  ) async {
    await show(
      tester,
      MatchRecordCard(
        match: _match(
          summary: const FeedbackSummary(
            validReps: 1,
            invalidReps: 0,
            issueCount: 1,
            topIssue: '아주 긴 자세 피드백 문장이 한 줄을 넘어가도 잘려서 보여요',
          ),
        ),
        showDate: true,
        showFeedback: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
