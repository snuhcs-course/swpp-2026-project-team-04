import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/models/hold_record.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/history_viewmodel.dart';
import 'package:gymrats_app/widgets/archive_cards.dart';
import 'package:gymrats_app/widgets/archive_chart.dart';

import 'battle_test_support.dart';

Future<void> _show(WidgetTester tester, Widget child, {double width = 412}) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ListView(children: [child])),
    ),
  );
}

ArchiveGrowth _growth({
  int matches = 3,
  double perMatch = 5.5,
  int? best = 240,
  List<ArchivePoint> points = const [],
}) => ArchiveGrowth(
  period: StatsPeriod.week,
  exercise: ExerciseType.pushUp,
  matches: matches,
  repsPerMatch: perMatch,
  bestScore: best,
  points: points,
  bests: const [],
  issues: const [],
);

void main() {
  setUpAll(loadBattleFonts);

  group('the period picker', () {
    testWidgets('이번 주 · 이번 달 · 전체 기간, the chosen one selected; a tap '
        'chooses', (tester) async {
      final semantics = tester.ensureSemantics();
      StatsPeriod? chosen;
      await _show(
        tester,
        ArchivePeriodPicker(
          value: StatsPeriod.week,
          onChanged: (p) => chosen = p,
        ),
      );
      expect(find.text('이번 주'), findsOneWidget);
      expect(find.text('이번 달'), findsOneWidget);
      expect(find.text('전체 기간'), findsOneWidget);
      bool selected(String label) =>
          isSemantics(isSelected: true)
              .matches(tester.getSemantics(find.text(label)), {});
      expect(selected('이번 주'), isTrue);
      expect(selected('이번 달'), isFalse);
      await tester.tap(find.text('이번 달'));
      expect(chosen, StatsPeriod.month);
      expect(
        tester.getSize(find.byType(ArchivePeriodPicker)).height,
        greaterThanOrEqualTo(44),
      );
      semantics.dispose();
    });

    test('the period words', () {
      expect(StatsPeriod.values.map(archivePeriodLabel), [
        '전체 기간',
        '이번 달',
        '이번 주',
      ]);
    });
  });

  group('the chips', () {
    testWidgets('the chosen chip in ink, the others white; a tap picks', (
      tester,
    ) async {
      ExerciseType? picked;
      await _show(
        tester,
        ArchiveExerciseChips(
          selected: ExerciseType.pushUp,
          onSelected: (e) => picked = e,
        ),
      );
      Color fill(String label) => tester
          .widget<Material>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Material))
                .first,
          )
          .color!;
      expect(fill('푸쉬업'), AppColors.ink);
      expect(fill('스쿼트'), AppColors.card);
      await tester.tap(find.text('스쿼트'));
      expect(picked, ExerciseType.squat);
      expect(tester.getSize(find.text('스쿼트')).height, lessThan(44));
      expect(
        tester
            .getSize(
              find.ancestor(
                of: find.text('스쿼트'),
                matching: find.byType(InkWell),
              ),
            )
            .height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('many chips scroll sideways on a narrow phone', (tester) async {
      await _show(
        tester,
        ArchiveChips<ArchiveFilter>(
          values: ArchiveFilter.values,
          labelOf: (f) => f.label,
          selected: ArchiveFilter.all,
          onSelected: (_) {},
        ),
        width: 300,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('the summary', () {
    testWidgets('battles, reps per battle and best score, each read as one', (
      tester,
    ) async {
      await _show(tester, ArchiveSummary(growth: _growth()));
      expect(find.bySemanticsLabel('경기 3판'), findsOneWidget);
      expect(find.bySemanticsLabel('경기당 인정 5.5회'), findsOneWidget);
      expect(find.bySemanticsLabel('최고 점수 240점'), findsOneWidget);
    });

    testWidgets('no score kept: a dash', (tester) async {
      await _show(tester, ArchiveSummary(growth: _growth(best: null)));
      expect(find.bySemanticsLabel('최고 점수 –'), findsOneWidget);
    });

    test('reps per battle: one decimal, none when whole', () {
      expect(ArchiveSummary.perMatch(5.5), '5.5');
      expect(ArchiveSummary.perMatch(16.25), '16.3');
      expect(ArchiveSummary.perMatch(6), '6');
      expect(ArchiveSummary.perMatch(0), '0');
    });
  });

  group('the score chart', () {
    final points = [
      ArchivePoint(playedAt: DateTime(2026, 11, 10, 9), reps: 4, score: 60),
      ArchivePoint(playedAt: DateTime(2026, 11, 11, 9), reps: 6),
      ArchivePoint(playedAt: DateTime(2026, 11, 12, 9), reps: 7, score: 110),
    ];

    testWidgets('scores, leaving out a battle without one; 인정 횟수 shows '
        'every battle', (tester) async {
      await _show(tester, ArchiveScoreChart(points: points));
      expect(find.text('경기별 점수'), findsOneWidget);
      expect(find.bySemanticsLabel('경기별 점수: 60점, 110점'), findsOneWidget);
      expect(find.text('11.10'), findsOneWidget);
      expect(find.text('11.11'), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.tap(find.text('인정 횟수'));
      await tester.pumpAndSettle();
      expect(find.text('경기별 인정 횟수'), findsOneWidget);
      expect(find.bySemanticsLabel('경기별 인정 횟수: 4회, 6회, 7회'), findsOneWidget);
      expect(find.text('11.11'), findsOneWidget);
    });

    testWidgets('no battle: a line instead of the chart', (tester) async {
      await _show(tester, const ArchiveScoreChart(points: []));
      expect(find.text('이 기간에 기록된 경기가 없어요.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ArchiveTrendPainter,
        ),
        findsNothing,
      );
    });

    test('the day under a point', () {
      expect(archiveDay(DateTime(2026, 11, 3, 9)), '11.03');
      expect(archiveDay(DateTime(2026, 12, 24, 9)), '12.24');
    });
  });

  group('개인 최고', () {
    testWidgets('a tile per exercise with its score, reps and day', (
      tester,
    ) async {
      await _show(
        tester,
        ArchiveBests(
          bests: [
            ArchiveBest(
              exercise: ExerciseType.pushUp,
              score: 170,
              reps: 18,
              playedAt: DateTime(2026, 11, 23, 9),
            ),
            ArchiveBest(
              exercise: ExerciseType.squat,
              score: 90,
              reps: 10,
              playedAt: DateTime(2026, 11, 21, 9),
            ),
          ],
        ),
      );
      expect(
        find.bySemanticsLabel('푸쉬업 최고 170점, 인정 18회, 11.23'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('스쿼트 최고 90점, 인정 10회, 11.21'),
        findsOneWidget,
      );
    });

    testWidgets('none yet: one line', (tester) async {
      await _show(tester, const ArchiveBests(bests: []));
      expect(find.text('점수가 기록된 경기가 아직 없어요.'), findsOneWidget);
    });
  });

  group('자주 나온 자세 문제', () {
    testWidgets('each reason with its count and a bar against the most', (
      tester,
    ) async {
      await _show(
        tester,
        const ArchiveIssues(
          issues: [
            ArchiveIssue(reason: RejectReason.insufficientDepth, count: 6),
            ArchiveIssue(reason: RejectReason.kneesDown, count: 2),
          ],
        ),
      );
      expect(find.text('가슴을 더 내려요'), findsOneWidget);
      expect(find.text('6회'), findsOneWidget);
      expect(find.text('2회'), findsOneWidget);
      final bars = [
        for (final box in tester.renderObjectList<RenderBox>(
          find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == AppColors.warning,
          ),
        ))
          box.size.width,
      ];
      expect(bars, hasLength(2));
      expect(bars.last / bars.first, closeTo(2 / 6, 0.01));
    });

    testWidgets('none: one line', (tester) async {
      await _show(tester, const ArchiveIssues(issues: []));
      expect(find.text('이 기간에 무효 처리된 횟수가 없어요.'), findsOneWidget);
    });
  });

  group('sections', () {
    testWidgets('a section is white; its title is a header with its detail', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _show(
        tester,
        const ArchiveSection(
          child: ArchiveSectionTitle('개인 최고', detail: '이번 주'),
        ),
      );
      expect(
        tester
            .widget<ColoredBox>(
              find
                  .descendant(
                    of: find.byType(ArchiveSection),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            )
            .color,
        AppColors.card,
      );
      expect(
        tester.getSemantics(find.text('개인 최고')),
        isSemantics(isHeader: true),
      );
      expect(find.text('이번 주'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the retry line calls back', (tester) async {
      var retried = 0;
      await _show(tester, ArchiveStatsRetry(onRetry: () => retried++));
      expect(find.text('기간별 기록을 불러오지 못했어요'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      expect(retried, 1);
    });

    testWidgets('the old bordered card stays for the statistics', (
      tester,
    ) async {
      await _show(tester, const ArchiveCard(child: Text('x')));
      final box = tester.widget<DecoratedBox>(
        find.ancestor(of: find.text('x'), matching: find.byType(DecoratedBox)),
      );
      expect((box.decoration as BoxDecoration).color, AppColors.card);
    });
  });
  group('버티기 on the 전체 tab (P13)', () {
    HoldRecord best(HoldPose pose, int ms) => HoldRecord(
      endedAt: DateTime(2026, 11, 26, 21, 10),
      pose: pose,
      stage: 3,
      held: Duration(milliseconds: ms),
      elapsed: Duration(milliseconds: ms),
      stars: 1,
      starSeconds: const [15, 20, 30],
    );

    testWidgets('the holds and time held of the period, each pose\'s longest', (
      tester,
    ) async {
      await _show(
        tester,
        ArchiveHoldSummary(
          holds: ArchiveHolds(
            count: 3,
            held: const Duration(milliseconds: 69600),
            bests: [best(HoldPose.plank, 40000), best(HoldPose.chair, 15000)],
          ),
          period: StatsPeriod.week,
        ),
      );
      expect(find.text('버티기'), findsOneWidget);
      expect(find.text('이번 주'), findsOneWidget);
      expect(find.bySemanticsLabel('횟수 3회'), findsOneWidget);
      expect(find.bySemanticsLabel('버틴 시간 1분 10초'), findsOneWidget);
      expect(find.bySemanticsLabel('하이 플랭크 최고 40초, 11.26'), findsOneWidget);
      expect(find.bySemanticsLabel('의자 자세 최고 15초, 11.26'), findsOneWidget);
    });

    test('times under a minute with one decimal, from a minute in minutes', () {
      expect(
        ArchiveHoldSummary.time(const Duration(milliseconds: 24600)),
        '24.6초',
      );
      expect(ArchiveHoldSummary.time(const Duration(seconds: 30)), '30초');
      expect(ArchiveHoldSummary.time(const Duration(seconds: 72)), '1분 12초');
    });
  });
  group('자세별 버틴 시간 (P13)', () {
    HoldRecord hold(HoldPose pose, int day, int ms) => HoldRecord(
      endedAt: DateTime(2026, 11, day, 9),
      pose: pose,
      stage: 3,
      held: Duration(milliseconds: ms),
      elapsed: Duration(milliseconds: ms),
      stars: 1,
      starSeconds: const [15, 20, 30],
    );

    Future<void> showTrends(
      WidgetTester tester,
      Map<HoldPose, List<HoldRecord>> trends,
    ) => _show(
      tester,
      ArchiveHoldSummary(
        holds: ArchiveHolds(
          count: trends.values.fold(0, (n, l) => n + l.length),
          held: Duration.zero,
          bests: const [],
          trends: trends,
        ),
        period: StatsPeriod.week,
      ),
    );

    testWidgets('a pose\'s holds as a trend; the chips switch the pose', (
      tester,
    ) async {
      await showTrends(tester, {
        HoldPose.plank: [
          hold(HoldPose.plank, 24, 20100),
          hold(HoldPose.plank, 25, 23000),
          hold(HoldPose.plank, 26, 24600),
        ],
        HoldPose.chair: [
          hold(HoldPose.chair, 24, 15000),
          hold(HoldPose.chair, 26, 18000),
        ],
      });
      expect(find.text('자세별 버틴 시간'), findsOneWidget);
      expect(
        find.bySemanticsLabel('하이 플랭크 버틴 시간: 20.1초, 23초, 24.6초'),
        findsOneWidget,
      );
      expect(find.text('11.26'), findsOneWidget);
      await tester.tap(find.text('의자 자세'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('의자 자세 버틴 시간: 15초, 18초'), findsOneWidget);
      expect(find.text('2회'), findsOneWidget);
    });

    testWidgets('one hold of the pose: nothing to compare yet', (tester) async {
      await showTrends(tester, {
        HoldPose.plank: [hold(HoldPose.plank, 26, 24600)],
      });
      expect(find.text('하이 플랭크 24.6초 · 비교 기록 없음'), findsOneWidget);
      // One pose: no chips.
      expect(find.byType(ArchiveChips<HoldPose>), findsNothing);
    });

    testWidgets('no hold in the period: one line', (tester) async {
      await showTrends(tester, const {});
      expect(find.text('이 기간에 기록된 버티기가 없어요.'), findsOneWidget);
    });
  });
}
