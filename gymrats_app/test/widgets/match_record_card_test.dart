// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('the outcome is ink on its color, with an ink edge', (
    tester,
  ) async {
    for (final (outcome, fill) in [
      (MatchOutcome.win, AppColors.accent),
      (MatchOutcome.lose, AppColors.opponent),
      (MatchOutcome.draw, AppColors.cardHigh),
    ]) {
      await show(tester, MatchOutcomeBadge(outcome: outcome));
      expect(colorOf(tester, outcome.label), AppColors.ink);
      final box = tester.widget<Container>(find.byType(Container));
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, fill);
      expect((decoration.border! as Border).top.color, AppColors.ink);
    }
  });

  /// The band painted behind the text, if any.
  Color? bandOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.backgroundColor;

  testWidgets('a top issue reads in ink on an amber band', (tester) async {
    await show(
      tester,
      MatchRecordCard(match: _match(summary: _issue), showFeedback: true),
    );
    expect(find.text('팔꿈치가 벌어져요'), findsOneWidget);
    expect(colorOf(tester, '팔꿈치가 벌어져요'), AppColors.ink);
    expect(
      bandOf(tester, '팔꿈치가 벌어져요'),
      AppColors.warning.withValues(alpha: 0.6),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded)).color,
      AppColors.ink,
    );
  });

  testWidgets('nothing to fix reads 좋은 자세 in ink on a lime band', (
    tester,
  ) async {
    await show(
      tester,
      MatchRecordCard(match: _match(summary: _clean), showFeedback: true),
    );
    expect(colorOf(tester, '좋은 자세'), AppColors.ink);
    expect(bandOf(tester, '좋은 자세'), AppColors.accent.withValues(alpha: 0.6));
  });

  testWidgets('a battle without feedback reads 피드백 없음', (tester) async {
    await show(tester, MatchRecordCard(match: _match(), showFeedback: true));
    expect(colorOf(tester, '피드백 없음'), AppColors.textMuted);
    expect(bandOf(tester, '피드백 없음'), isNull);
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
    expect(find.text('푸쉬업 · 10월 21일 09:05'), findsOneWidget);
  });

  testWidgets('the opponent stands over the exercise and the date', (
    tester,
  ) async {
    await show(tester, MatchRecordCard(match: _match(), showDate: true));
    final opponent = tester.getRect(find.text('vs 진영'));
    final played = tester.getRect(find.text('푸쉬업 · 10월 21일 09:05'));
    expect(opponent.bottom, lessThanOrEqualTo(played.top));
    expect(opponent.left, played.left);
    expect(
      tester.widget<Text>(find.text('푸쉬업 · 10월 21일 09:05')).style?.color,
      AppColors.textSecondary,
    );
  });

  testWidgets('a name takes up to three lines, then ends in an ellipsis', (
    tester,
  ) async {
    final name = 'r' * 60;
    await show(
      tester,
      MatchRecordCard(
        match: MatchRecord(
          exercise: ExerciseType.pushUp,
          opponentName: name,
          myReps: 20,
          opponentReps: 3,
        ),
      ),
    );
    final line = find.text('vs $name');
    final style = tester.widget<Text>(line).style;
    expect(
      tester.getSize(line).height,
      moreOrLessEquals(3 * style!.fontSize! * style.height!, epsilon: 1),
    );
    expect(
      tester.renderObject<RenderParagraph>(line).didExceedMaxLines,
      isTrue,
    );
    expect(tester.widget<Text>(line).overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the exercise shows alone without the date', (tester) async {
    await show(tester, MatchRecordCard(match: _match()));
    expect(find.text('푸쉬업'), findsOneWidget);
    expect(find.textContaining('10월'), findsNothing);
  });

  testWidgets('a battle with no time shows the exercise alone', (tester) async {
    await show(
      tester,
      const MatchRecordCard(
        match: MatchRecord(
          exercise: ExerciseType.squat,
          opponentName: '진영',
          myReps: 20,
          opponentReps: 3,
        ),
        showDate: true,
      ),
    );
    expect(find.text('스쿼트'), findsOneWidget);
  });

  testWidgets('a battle with game scores shows them, not its reps', (
    tester,
  ) async {
    await show(
      tester,
      const MatchRecordCard(
        match: MatchRecord(
          exercise: ExerciseType.pushUp,
          opponentName: 'RepBot',
          myReps: 7,
          opponentReps: 9,
          myScore: 150,
          opponentScore: 90,
          decidedOutcome: MatchOutcome.win,
        ),
      ),
    );
    expect(find.text('승'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.textContaining('7'), findsNothing);
    expect(find.textContaining('회'), findsNothing);
    // "나" sits on a lime pill: ink, readable in the light theme.
    expect(colorOf(tester, '나'), AppColors.ink);
  });

  testWidgets('a battle with no game scores shows its reps with a unit', (
    tester,
  ) async {
    await show(
      tester,
      const MatchRecordCard(
        match: MatchRecord(
          exercise: ExerciseType.pushUp,
          opponentName: 'RepBot',
          myReps: 3,
          opponentReps: 5,
          decidedOutcome: MatchOutcome.win,
        ),
      ),
    );
    expect(find.text('승'), findsOneWidget);
    expect(find.text('3회'), findsOneWidget);
    expect(find.text('5회'), findsOneWidget);
  });

  testWidgets('one score alone shows the reps', (tester) async {
    await show(
      tester,
      const MatchRecordCard(
        match: MatchRecord(
          exercise: ExerciseType.pushUp,
          opponentName: 'RepBot',
          myReps: 3,
          opponentReps: 5,
          myScore: 150,
        ),
      ),
    );
    expect(find.text('3회'), findsOneWidget);
    expect(find.text('5회'), findsOneWidget);
    expect(find.textContaining('150'), findsNothing);
  });

  testWidgets('the unit is small and takes each number\'s color', (
    tester,
  ) async {
    await show(tester, MatchRecordCard(match: _match()));
    final theme = Theme.of(tester.element(find.text('20회'))).textTheme;
    final mine = tester.widget<Text>(find.text('20회'));
    final theirs = tester.widget<Text>(find.text('3회'));
    expect(mine.style!.fontSize, theme.titleLarge!.fontSize);
    expect(mine.style!.color, AppColors.textPrimary);
    expect(theirs.style!.color, AppColors.textSecondary);
    final myUnit = mine.textSpan! as TextSpan;
    final theirUnit = theirs.textSpan! as TextSpan;
    final mineSpan = myUnit.children!.single as TextSpan;
    final theirSpan = theirUnit.children!.single as TextSpan;
    expect(mineSpan.style!.fontSize, theme.bodySmall!.fontSize);
    expect(mineSpan.style!.color, AppColors.textPrimary);
    expect(theirSpan.style!.color, AppColors.textSecondary);
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
