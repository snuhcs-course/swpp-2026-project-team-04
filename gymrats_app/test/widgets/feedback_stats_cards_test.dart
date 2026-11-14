import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/feedback_stats_cards.dart';
import 'package:gymrats_app/widgets/feedback_stats_chart.dart';

import 'battle_test_support.dart';

/// Saturday 2026-11-14, late.
final _now = DateTime(2026, 11, 14, 23);

PeriodStats _week({
  int matches = 9,
  int totalReps = 124,
  int withFeedback = 8,
  List<int> reps = const [27, 0, 10, 43, 16, 28, 0],
  List<IssueCount> issues = const [],
}) => PeriodStats(
  period: StatsPeriod.week,
  start: DateTime(2026, 11, 9),
  matches: matches,
  totalReps: totalReps,
  matchesWithFeedback: withFeedback,
  daily: [
    for (final (i, r) in reps.indexed)
      DayReps(date: DateTime(2026, 11, 9 + i), reps: r),
  ],
  issues: issues,
);

void main() {
  // The app's fonts, so the cards measure as they do on a phone.
  setUpAll(loadBattleFonts);

  Future<void> show(
    WidgetTester tester,
    Widget card, {
    Size size = const Size(360, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: card,
          ),
        ),
      ),
    );
  }

  group('FeedbackStatsSummaryCard', () {
    FeedbackStatsSummaryCard summary(
      PeriodStats stats, {
      StatsPeriod? period,
      ExerciseType? exercise,
    }) => FeedbackStatsSummaryCard(
      period: period ?? stats.period,
      exercise: exercise,
      stats: stats,
      now: _now,
    );

    testWidgets('the period, the average with 회, the battles and the total', (
      tester,
    ) async {
      await show(tester, summary(_week()));
      expect(find.text('이번 주 · 11/9 월 ~ 11/15 일'), findsOneWidget);
      expect(find.text('경기당 평균 인정'), findsOneWidget);
      expect(find.text('13.8회'), findsOneWidget);
      expect(find.text('9판'), findsOneWidget);
      expect(find.text('124회'), findsOneWidget);
      // The pair's bottom sits a step (4) above the average's.
      expect(
        tester.getBottomLeft(find.text('124회')).dy,
        moreOrLessEquals(
          tester.getBottomLeft(find.text('13.8회')).dy - 4,
          epsilon: 1,
        ),
      );
      expect(find.byType(FeedbackStatsChart), findsOneWidget);
      expect(find.byKey(const ValueKey('feedback-stats-empty')), findsNothing);
    });

    testWidgets('no battles: "–" alone, and the notice over the plot', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        summary(
          _week(
            matches: 0,
            totalReps: 0,
            withFeedback: 0,
            reps: List.filled(7, 0),
          ),
          exercise: ExerciseType.pushUp,
        ),
      );
      expect(find.text('–'), findsOneWidget);
      expect(find.text('–회'), findsNothing);
      expect(find.text('이번 주에는 아직 푸쉬업 경기가 없어요'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('경기당 평균 인정 없음, 경기 0판, 총 인정 0회')),
        findsOneWidget,
      );
      final notice = tester.getRect(
        find.byKey(const ValueKey('feedback-stats-empty')),
      );
      expect(notice.top, tester.getTopLeft(find.byType(FeedbackStatsChart)).dy);
      expect(notice.height, greaterThanOrEqualTo(80));
      expect(
        tester
            .widget<Container>(
              find.byKey(const ValueKey('feedback-stats-empty')),
            )
            .decoration,
        isA<BoxDecoration>().having(
          (d) => d.color,
          'color',
          AppColors.cardHigh,
        ),
      );
      semantics.dispose();
    });

    testWidgets('every record without battles: the notice under the numbers', (
      tester,
    ) async {
      await show(
        tester,
        summary(
          const PeriodStats(period: StatsPeriod.all, start: null),
          exercise: ExerciseType.squat,
        ),
      );
      expect(find.text('전체'), findsOneWidget);
      expect(find.text('아직 스쿼트 경기 기록이 없어요'), findsOneWidget);
      expect(find.byType(FeedbackStatsChart), findsNothing);
    });

    testWidgets('at 2x text the pair may go under the average, without '
        'overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await show(tester, summary(_week()));
      expect(tester.takeException(), isNull);
      expect(find.text('124회'), findsOneWidget);
    });
  });

  group('FeedbackStatsIssuesCard', () {
    testWidgets('both groups, their marks and units, the rows with counts '
        'and bars against the most or the battles', (tester) async {
      await show(
        tester,
        FeedbackStatsIssuesCard(
          stats: _week(
            issues: const [
              IssueCount(code: 'reject.insufficientDepth', count: 7),
              IssueCount(code: 'reject.incompleteExtension', count: 4),
              IssueCount(code: 'elbow_flare', count: 3),
            ],
          ),
        ),
      );
      expect(find.text('자세 문제'), findsOneWidget);
      expect(find.text('경기 9판 중 자세 기록 8판 기준'), findsOneWidget);
      expect(find.text('거절된 이유'), findsOneWidget);
      expect(find.text('카운트되지 않은 횟수'), findsOneWidget);
      expect(find.text('자세 리포트'), findsOneWidget);
      expect(find.text('이 문제가 나온 경기 수'), findsOneWidget);
      expect(find.text('7회'), findsOneWidget);
      expect(find.text('3판 / 8'), findsOneWidget);
      final bars = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((b) => b.widthFactor)
          .toList();
      expect(bars, [1.0, 0.57, 0.38]);
      // Above the second group.
      expect(
        tester.getTopLeft(find.text('팔을 끝까지 펴요')).dy,
        lessThan(tester.getTopLeft(find.text('자세 리포트')).dy),
      );
    });

    testWidgets('a group without rows says so', (tester) async {
      await show(
        tester,
        FeedbackStatsIssuesCard(
          stats: _week(
            issues: const [IssueCount(code: 'elbow_flare', count: 1)],
          ),
        ),
      );
      expect(find.text('이 기간에 거절된 횟수가 없어요.'), findsOneWidget);
      await show(
        tester,
        FeedbackStatsIssuesCard(
          stats: _week(
            issues: const [IssueCount(code: 'reject.kneesDown', count: 1)],
          ),
        ),
      );
      expect(find.text('자세 리포트에 나온 문제가 없어요.'), findsOneWidget);
    });

    testWidgets('codes the app does not know are left out, and still count '
        'in the base', (tester) async {
      await show(
        tester,
        FeedbackStatsIssuesCard(
          stats: _week(
            issues: const [
              IssueCount(code: 'reject.newReason', count: 9),
              IssueCount(code: 'reject.kneesDown', count: 2),
              IssueCount(code: 'mystery_code', count: 5),
              IssueCount(code: 'head_lead', count: 1),
            ],
          ),
        ),
      );
      expect(find.text('경기 9판 중 자세 기록 8판 기준'), findsOneWidget);
      expect(find.text('무릎을 바닥에서 떼요'), findsOneWidget);
      expect(find.text('고개가 먼저 내려감'), findsOneWidget);
      expect(find.textContaining('newReason'), findsNothing);
      expect(find.textContaining('mystery'), findsNothing);
      // The known reason is the most of its group now.
      expect(
        tester
            .widget<FractionallySizedBox>(
              find.byType(FractionallySizedBox).first,
            )
            .widthFactor,
        1.0,
      );
    });

    testWidgets('battles without form records: only the one line', (
      tester,
    ) async {
      await show(
        tester,
        FeedbackStatsIssuesCard(stats: _week(matches: 1, withFeedback: 0)),
      );
      expect(find.text('경기 1판 중 자세 기록 0판 기준'), findsOneWidget);
      expect(find.text('이 기간 경기에는 자세 기록이 없어요.'), findsOneWidget);
      expect(find.text('거절된 이유'), findsNothing);
    });

    testWidgets('more than five: "나머지 N개 더 보기" opens all and "접기" '
        'closes them; a screen reader hears each row as one line', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const reasons = [
        'reject.insufficientDepth',
        'reject.incompleteExtension',
        'reject.shouldersNotLevel',
        'reject.tooFast',
        'reject.kneesDown',
        'reject.armsStraight',
        'reject.bellyDown',
      ];
      await show(
        tester,
        FeedbackStatsIssuesCard(
          stats: _week(
            issues: [
              for (final (i, code) in reasons.indexed)
                IssueCount(code: code, count: 10 - i),
            ],
          ),
        ),
      );
      expect(find.text('나머지 2개 더 보기'), findsOneWidget);
      expect(find.text('팔을 굽혀서 내려요'), findsNothing);
      expect(find.bySemanticsLabel('가슴을 더 내려요, 거절 10회'), findsOneWidget);
      // The button itself says whether the group is open.
      expect(
        tester.getSemantics(find.text('나머지 2개 더 보기')),
        isSemantics(isButton: true, hasExpandedState: true, isExpanded: false),
      );
      await tester.tap(find.text('나머지 2개 더 보기'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('접기')),
        isSemantics(isButton: true, hasExpandedState: true, isExpanded: true),
      );
      expect(find.text('팔을 굽혀서 내려요'), findsOneWidget);
      expect(find.text('배를 바닥에서 떼요'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
      await tester.tap(find.text('접기'));
      await tester.pumpAndSettle();
      expect(find.text('배를 바닥에서 떼요'), findsNothing);
      expect(
        tester.getSize(find.widgetWithText(TextButton, '나머지 2개 더 보기')).height,
        44,
      );
      semantics.dispose();
    });

    testWidgets('six rows: one hidden, "나머지 1개 더 보기"', (tester) async {
      const reasons = [
        'reject.insufficientDepth',
        'reject.incompleteExtension',
        'reject.shouldersNotLevel',
        'reject.tooFast',
        'reject.kneesDown',
        'reject.armsStraight',
      ];
      await show(
        tester,
        FeedbackStatsIssuesCard(
          stats: _week(
            issues: [
              for (final (i, code) in reasons.indexed)
                IssueCount(code: code, count: 10 - i),
            ],
          ),
        ),
      );
      expect(find.text('나머지 1개 더 보기'), findsOneWidget);
      expect(find.text('팔을 굽혀서 내려요'), findsNothing);
    });

    testWidgets('a rare issue still gets a bar 4% long', (tester) async {
      await show(
        tester,
        FeedbackStatsIssuesCard(
          stats: _week(
            matches: 60,
            withFeedback: 60,
            issues: const [
              IssueCount(code: 'reject.insufficientDepth', count: 30),
              IssueCount(code: 'reject.kneesDown', count: 1),
              IssueCount(code: 'hand_width', count: 1),
            ],
          ),
        ),
      );
      final bars = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((b) => b.widthFactor)
          .toList();
      // 1 of 30 rejections is 3%, 1 of 60 battles 2%: both shown at 4%.
      expect(bars, [1.0, 0.04, 0.04]);
    });

    testWidgets('a long name ends in "…" on one line', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await show(
        tester,
        FeedbackStatsIssuesCard(
          stats: _week(
            issues: const [IssueCount(code: 'reject.shallowSquat', count: 12)],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final name = tester.widget<Text>(find.text('엉덩이를 무릎 높이까지 내려요'));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
    });
  });

  group('FeedbackStatsLoadingCards', () {
    testWidgets('the period, 불러오는 중 with a ring, gray boxes and four gray '
        'rows', (tester) async {
      await show(
        tester,
        FeedbackStatsLoadingCards(period: StatsPeriod.month, now: _now),
      );
      expect(find.text('이번 달 · 11/1 ~ 11/30'), findsOneWidget);
      expect(find.text('불러오는 중'), findsOneWidget);
      expect(find.byKey(const ValueKey('feedback-stats-ring')), findsOneWidget);
      expect(find.text('자세 문제'), findsOneWidget);
      expect(
        tester
            .widget<FeedbackStatsChart>(find.byType(FeedbackStatsChart))
            .chart
            .slots,
        hasLength(30),
      );
      // 4 rows of two boxes each.
      expect(find.byType(FractionallySizedBox), findsNWidgets(8));
      await show(
        tester,
        FeedbackStatsLoadingCards(period: StatsPeriod.all, now: _now),
      );
      expect(find.text('전체'), findsOneWidget);
    });
  });

  group('FeedbackStatsFailedCard', () {
    testWidgets('the mark, the words, the reason, 다시 시도 and the note', (
      tester,
    ) async {
      var retries = 0;
      await show(
        tester,
        FeedbackStatsFailedCard(message: '연결 안 됨', onRetry: () => retries++),
      );
      expect(find.text('!'), findsOneWidget);
      expect(find.text('통계를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('연결 안 됨'), findsOneWidget);
      expect(find.text('고른 기간과 종목은 그대로 남아요.'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, '다시 시도');
      expect(tester.getSize(button).height, 48);
      await tester.tap(button);
      expect(retries, 1);
    });
  });
}
