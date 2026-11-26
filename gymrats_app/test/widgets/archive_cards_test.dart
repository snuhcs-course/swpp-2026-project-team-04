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
        find.bySemanticsLabel('푸쉬업 최고 170점, 인정 18회 · 11.23'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('스쿼트 최고 90점, 인정 10회 · 11.21'),
        findsOneWidget,
      );
    });

    testWidgets('none yet: one line', (tester) async {
      await _show(tester, const ArchiveBests(bests: []));
      expect(find.text('기록된 최고 기록이 아직 없어요.'), findsOneWidget);
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
  group('버티기 on the 전체 tab, laid out as an exercise (P13)', () {
    HoldRecord hold(HoldPose pose, int day, int ms) => HoldRecord(
      endedAt: DateTime(2026, 11, day, 9),
      pose: pose,
      stage: 3,
      held: Duration(milliseconds: ms),
      elapsed: Duration(milliseconds: ms),
      stars: 1,
      starSeconds: const [15, 20, 30],
    );

    testWidgets('the summary: holds, time held and the longest hold', (
      tester,
    ) async {
      await _show(
        tester,
        const ArchiveHoldFigures(
          holds: ArchiveHolds(
            count: 3,
            held: Duration(milliseconds: 69600),
            bests: [],
            bestHeld: Duration(milliseconds: 24600),
          ),
        ),
      );
      expect(find.bySemanticsLabel('횟수 3회'), findsOneWidget);
      expect(find.bySemanticsLabel('버틴 시간 1분 10초'), findsOneWidget);
      expect(find.bySemanticsLabel('최고 버틴 시간 24.6초'), findsOneWidget);
      await _show(
        tester,
        const ArchiveHoldFigures(
          holds: ArchiveHolds(count: 0, held: Duration.zero, bests: []),
        ),
      );
      expect(find.bySemanticsLabel('최고 버틴 시간 –'), findsOneWidget);
    });

    testWidgets('경기별 버틴 시간: every hold in time; both poses in their '
        'colours with a legend', (tester) async {
      await _show(
        tester,
        ArchiveHoldChart(
          holds: [
            hold(HoldPose.plank, 24, 20100),
            hold(HoldPose.chair, 25, 15000),
            hold(HoldPose.plank, 26, 24600),
          ],
        ),
      );
      expect(find.text('경기별 버틴 시간'), findsOneWidget);
      expect(
        find.bySemanticsLabel('경기별 버틴 시간: 20.1초, 15초, 24.6초'),
        findsOneWidget,
      );
      expect(find.text('하이 플랭크'), findsOneWidget);
      expect(find.text('의자 자세'), findsOneWidget);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) =>
                          w is CustomPaint && w.painter is ArchiveTrendPainter,
                    ),
                  )
                  .painter!
              as ArchiveTrendPainter;
      expect(painter.colors, [
        holdPoseColor(HoldPose.plank),
        holdPoseColor(HoldPose.chair),
        holdPoseColor(HoldPose.plank),
      ]);
    });

    testWidgets('one pose: no legend, one colour; none: one line', (
      tester,
    ) async {
      await _show(
        tester,
        ArchiveHoldChart(holds: [hold(HoldPose.plank, 26, 24600)]),
      );
      expect(find.text('하이 플랭크'), findsNothing);
      await _show(tester, const ArchiveHoldChart(holds: []));
      expect(find.text('이 기간에 기록된 버티기가 없어요.'), findsOneWidget);
    });

    testWidgets('개인 최고 has a tile per pose, two to a row with the '
        'exercises', (tester) async {
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
          ],
          holds: [hold(HoldPose.plank, 26, 40000)],
        ),
      );
      expect(
        find.bySemanticsLabel('하이 플랭크 최고 40초, 버티기 · 11.26'),
        findsOneWidget,
      );
      final push = tester.getTopLeft(find.text('푸쉬업'));
      final plank = tester.getTopLeft(find.text('하이 플랭크'));
      expect(plank.dy, push.dy);
      expect(plank.dx, greaterThan(push.dx));
    });

    testWidgets('자주 받은 경고: the warnings as bars, most first; none says '
        'so', (tester) async {
      await _show(
        tester,
        const ArchiveHoldWarnings(
          warnings: [(words: '무릎 떼요', count: 4), (words: '팔 펴요', count: 1)],
        ),
      );
      expect(find.text('무릎 떼요'), findsOneWidget);
      expect(find.text('4회'), findsOneWidget);
      await _show(tester, const ArchiveHoldWarnings(warnings: []));
      expect(find.text('이 기간에 받은 경고가 없어요.'), findsOneWidget);
    });

    test('a hold\'s time', () {
      expect(archiveHoldTime(const Duration(milliseconds: 24600)), '24.6초');
      expect(archiveHoldTime(const Duration(seconds: 30)), '30초');
      expect(archiveHoldTime(const Duration(seconds: 72)), '1분 12초');
    });
  });

  group('scopes and 운동량 (P13)', () {
    testWidgets('전체 · 푸쉬업 · 스쿼트 · 버티기 chips', (tester) async {
      ArchiveScope? picked;
      await _show(
        tester,
        ArchiveScopeChips(
          selected: ArchiveScope.all,
          onSelected: (s) => picked = s,
        ),
      );
      for (final s in ArchiveScope.values) {
        expect(find.text(s.label), findsOneWidget);
      }
      await tester.tap(find.text('버티기'));
      expect(picked, ArchiveScope.hold);
    });

    testWidgets('전체\'s summary has the holds and the split by exercise', (
      tester,
    ) async {
      await _show(
        tester,
        const ArchiveSummary(
          growth: ArchiveGrowth(
            period: StatsPeriod.week,
            exercise: null,
            matches: 4,
            repsPerMatch: 6,
            bestScore: 170,
            points: [],
            bests: [],
            issues: [],
            perExercise: {ExerciseType.pushUp: 3, ExerciseType.squat: 1},
          ),
          holds: 2,
        ),
      );
      expect(find.bySemanticsLabel('버티기 2회'), findsOneWidget);
      expect(find.text('푸쉬업 3판 · 스쿼트 1판 · 버티기 2회'), findsOneWidget);
    });

    const amount = ArchiveAmount(
      battles: 3,
      kcal: 26,
      liftedKg: 4200,
      endurance: 108,
      holds: 1,
    );

    testWidgets('운동량: calories, lifted weight and endurance against the '
        'period before, the weight it assumed; no other note', (tester) async {
      await _show(
        tester,
        const ArchiveVolumeSection(
          volume: ArchiveVolume(
            current: amount,
            previous: ArchiveAmount(
              battles: 2,
              kcal: 22,
              liftedKg: 3600,
              endurance: 100,
            ),
            weightKg: 65,
            weightAssumed: true,
          ),
          period: StatsPeriod.week,
        ),
      );
      expect(find.text('이번 주 운동량'), findsOneWidget);
      expect(find.text('지난 주'), findsOneWidget);
      expect(
        find.bySemanticsLabel('예상 소모 칼로리 26kcal, 증가 4, 버티기 1회 포함'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('들어 올린 무게 4.2t, 증가 600 kg'), findsOneWidget);
      expect(find.bySemanticsLabel('근지구력 지수 108, 증가 8'), findsOneWidget);
      expect(find.text('65 kg 기준 추정'), findsOneWidget);
      expect(find.textContaining('이 폰에 남은'), findsNothing);
      expect(find.textContaining('= 100'), findsNothing);
    });

    testWidgets('버티기: calories and endurance, no lifted weight; nothing to '
        'compare says so', (tester) async {
      await _show(
        tester,
        const ArchiveVolumeSection(
          volume: ArchiveVolume(
            current: ArchiveAmount(
              battles: 0,
              kcal: 1.8,
              liftedKg: 0,
              holds: 1,
            ),
            weightKg: 80,
            weightAssumed: false,
          ),
          period: StatsPeriod.all,
          holdsOnly: true,
        ),
      );
      expect(find.text('들어 올린 무게'), findsNothing);
      expect(find.bySemanticsLabel('근지구력 지수 –, 비교 기록 없음'), findsOneWidget);
      expect(find.text('체중 80 kg 기준 추정'), findsOneWidget);
    });

    testWidgets('nothing in the period: one line', (tester) async {
      await _show(
        tester,
        const ArchiveVolumeSection(
          volume: ArchiveVolume(
            current: ArchiveAmount(battles: 0, kcal: 0, liftedKg: 0),
            weightKg: 65,
            weightAssumed: true,
          ),
          period: StatsPeriod.week,
          holdsOnly: true,
        ),
      );
      expect(find.text('이 기간에 버티기 기록이 없어요.'), findsOneWidget);
    });
  });
}
