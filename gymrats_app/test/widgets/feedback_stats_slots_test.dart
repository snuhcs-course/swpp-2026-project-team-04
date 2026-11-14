import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/services/feedback/feedback_stats.dart';
import 'package:gymrats_app/widgets/feedback_stats_slots.dart';
import 'package:gymrats_app/widgets/feedback_stats_words.dart';

import 'feedback_stats_golden.dart';

DateTime _day(String ymd) {
  final [y, m, d] = ymd.split('-').map(int.parse).toList();
  return DateTime(y, m, d);
}

StatsPeriod _period(String name) => switch (name) {
  'week' => StatsPeriod.week,
  'month' => StatsPeriod.month,
  _ => StatsPeriod.all,
};

ExerciseType? _exercise(String name) => switch (name) {
  'push' => ExerciseType.pushUp,
  'squat' => ExerciseType.squat,
  _ => null,
};

StatsBarLook _look(Map<String, dynamic> slot) => switch (slot['color']) {
  '#8A93A5' => StatsBarLook.value,
  '#141A26' => StatsBarLook.now,
  '#D5DAE3' => StatsBarLook.zero,
  'transparent' => StatsBarLook.future,
  final other => throw StateError('unknown color $other'),
};

double _px(String value) => double.parse(value.replaceAll('px', ''));

void main() {
  final golden = readStatsGolden();
  final points = goldenStatsPoints();

  test('the copy of the mockup numbers is the one the screen was built '
      'from (11 cases, 67 battles)', () {
    expect(golden['meta']['source'], 'dc/W7A.dc.html');
    expect(points, hasLength(67));
    expect(golden['cases'], hasLength(11));
    expect(golden['meta']['plot'], {
      'height': StatsChart.plotHeight,
      'maxBar': StatsChart.maxBar,
      'valueLine': 12,
      'valueGap': StatsChart.valueGap,
      'zeroBar': StatsChart.zeroBar,
      'futureBar': StatsChart.futureBar,
    });
    expect(golden['meta']['cutPerGroup'], FeedbackStatsWords.cut);
  });

  for (final c in golden['cases'] as List) {
    final input = c['input'] as Map<String, dynamic>;
    final id = input['id'] as String;
    final period = _period(input['period'] as String);
    final exercise = _exercise(input['exercise'] as String);
    final today = _day(input['today'] as String);
    final now = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final since = input['since'] == null
        ? null
        : _day(input['since'] as String);

    // As the view model: one exercise, or both; the calculator does the rest.
    PeriodStats stats() => const FeedbackStatsCalculator().period(
      [
        for (final p in points)
          if ((since == null || !p.playedAt.isBefore(since)) &&
              (exercise == null || p.exercise == exercise))
            p,
      ],
      period,
      now,
    );

    group(id, () {
      test('summary: range, average, battles, reps, with a form record', () {
        final s = stats();
        final summary = c['summary'] as Map<String, dynamic>;
        expect(FeedbackStatsWords.range(period, s, now), summary['range']);
        expect(FeedbackStatsWords.average(s), summary['average']);
        expect(s.matches, summary['matches']);
        expect(s.totalReps, summary['totalReps']);
        expect(s.matchesWithFeedback, summary['matchesWithFeedback']);
      });

      test('chart: kind, slots, gap, and per slot the label, reps, future, '
          'now, value, bar height and look', () {
        final chart = StatsChart.of(stats(), now);
        final expected = c['chart'] as Map<String, dynamic>;
        expect(chart.kind.name, expected['kind']);
        expect(chart.slots, hasLength(expected['columns']));
        expect(chart.gap, _px(expected['gap'] as String));
        expect(
          chart.kind == StatsChartKind.week ? FeedbackStatsWords.weeksNote : '',
          expected['note'],
        );
        final slots = expected['slots'] as List;
        for (final (i, e) in slots.indexed) {
          final slot = chart.slots[i];
          final reason = '$id slot $i';
          expect(slot.label, e['label'], reason: reason);
          expect(slot.reps, e['reps'], reason: reason);
          expect(slot.future, e['future'], reason: reason);
          expect(slot.now, e['now'], reason: reason);
          expect(slot.valueShown, e['valueShown'], reason: reason);
          expect(slot.barHeight, _px(e['barHeight'] as String), reason: reason);
          expect(slot.look, _look(e as Map<String, dynamic>), reason: reason);
          expect(
            slot.look == StatsBarLook.future,
            e['border'] != '0',
            reason: reason,
          );
        }
      });

      test('empty notice: words and place', () {
        final s = stats();
        final empty = c['empty'] as Map<String, dynamic>?;
        if (empty == null) {
          expect(s.matches, isPositive);
          return;
        }
        expect(s.matches, 0);
        expect(FeedbackStatsWords.emptyTitle(period, exercise), empty['title']);
        expect(FeedbackStatsWords.emptyDetail(period), empty['detail']);
        expect(period == StatsPeriod.all ? 'below' : 'plot', empty['place']);
      });

      test('form issues: base, blank line, and both groups in order with '
          'names, counts and bar widths', () {
        final s = stats();
        final issues = c['issues'] as Map<String, dynamic>;
        expect(FeedbackStatsWords.base(s) ?? '', issues['base']);
        expect(FeedbackStatsWords.blank(s), issues['blank']);
        void same(List<StatsIssueRow> rows, List expected) {
          expect(rows.map((r) => r.code), [
            for (final e in expected) e['code'],
          ]);
          for (final (i, e) in expected.indexed) {
            expect(rows[i].name, e['label']);
            expect(rows[i].count, e['count']);
            expect(rows[i].widthPct, e['widthPct']);
            expect(rows[i].of, e['of']);
          }
        }

        same(FeedbackStatsWords.rejectedRows(s), issues['rejected'] as List);
        same(FeedbackStatsWords.reportRows(s), issues['report'] as List);
      });
    });
  }

  group('StatsChart', () {
    PeriodStats stats(
      StatsPeriod period,
      List<DayReps> daily, {
      DateTime? start,
    }) => PeriodStats(
      period: period,
      start: start,
      matches: daily.length,
      totalReps: daily.fold(0, (sum, d) => sum + d.reps),
      daily: daily,
    );

    test('every record over 26 weeks stays grouped by week (later work)', () {
      final today = DateTime(2026, 11, 14);
      final daily = [
        for (var i = 0; i < 30; i++)
          DayReps(date: DateTime(2026, 1, 5 + i * 10), reps: 10),
      ];
      final chart = StatsChart.of(stats(StatsPeriod.all, daily), today);
      expect(chart.kind, StatsChartKind.week);
      expect(chart.slots.first.date, DateTime(2026, 1, 5));
      expect(chart.slots.last.date, DateTime(2026, 11, 9));
      expect(chart.slots, hasLength(45));
      expect(chart.gap, 3);
      expect(chart.radius, 2);
      // Every other label from this week back.
      expect(chart.slots.last.label, '이번 주');
      expect(chart.slots[chart.slots.length - 2].label, '');
      expect(chart.slots[chart.slots.length - 3].label, '10/26');
    });

    test(
      'every record with exactly 14 days stays by day; a 15th groups it',
      () {
        final today = DateTime(2026, 11, 14);
        List<DayReps> days(int n) => [
          for (var i = 0; i < n; i++)
            DayReps(date: DateTime(2026, 10, 1 + i), reps: 5),
        ];
        expect(
          StatsChart.of(stats(StatsPeriod.all, days(14)), today).kind,
          StatsChartKind.day,
        );
        expect(
          StatsChart.of(stats(StatsPeriod.all, days(15)), today).kind,
          StatsChartKind.week,
        );
      },
    );

    test('a month of 28 days in a leap-less February', () {
      final today = DateTime(2027, 2, 10);
      final chart = StatsChart.of(
        stats(StatsPeriod.month, [
          for (var d = 1; d <= 10; d++)
            DayReps(date: DateTime(2027, 2, d), reps: 0),
        ], start: DateTime(2027, 2)),
        today,
      );
      expect(chart.slots, hasLength(28));
      expect(chart.slots.where((s) => s.future), hasLength(18));
      // 8 is two days from today: left out, as 오늘 would run into it.
      expect(
        [for (final s in chart.slots) s.label].where((l) => l.isNotEmpty),
        ['1', '오늘', '15', '22'],
      );
      // Nothing yet: every past bar is the thin line, the max is 1.
      expect(chart.slots.first.look, StatsBarLook.zero);
      expect(chart.slots.any((s) => s.valueShown), isFalse);
    });

    test('a single slot with reps fills the plot', () {
      final today = DateTime(2026, 11, 14);
      final chart = StatsChart.of(
        stats(StatsPeriod.all, [DayReps(date: today, reps: 3)]),
        today,
      );
      expect(chart.slots.single.barHeight, StatsChart.maxBar);
      expect(chart.slots.single.look, StatsBarLook.now);
      expect(chart.slots.single.label, '오늘');
    });

    test('a slot with few reps is at least 4 high', () {
      final today = DateTime(2026, 11, 14);
      final chart = StatsChart.of(
        stats(StatsPeriod.all, [
          DayReps(date: DateTime(2026, 11, 1), reps: 1),
          DayReps(date: DateTime(2026, 11, 2), reps: 100),
        ]),
        today,
      );
      expect(chart.slots.first.barHeight, StatsChart.leastBar);
      expect(chart.slots.first.label, '11/1');
      expect(chart.slots.last.label, '2');
    });

    group('skeleton while loading', () {
      final today = DateTime(2026, 11, 14, 15);

      test('this week: 7 gray bars, weekday letters and 오늘', () {
        final chart = StatsChart.skeleton(StatsPeriod.week, today);
        expect(chart.slots.map((s) => s.label), [
          '월',
          '화',
          '수',
          '목',
          '금',
          '오늘',
          '일',
        ]);
        expect(chart.slots.map((s) => s.barHeight), [
          46,
          64,
          30,
          72,
          40,
          58,
          34,
        ]);
        expect(
          chart.slots.every((s) => s.look == StatsBarLook.skeleton),
          isTrue,
        );
        expect(chart.gap, 8);
        expect(chart.radius, 6);
      });

      test("this month: the month's days, the pattern repeated", () {
        final chart = StatsChart.skeleton(StatsPeriod.month, today);
        expect(chart.slots, hasLength(30));
        expect(chart.slots[10].barHeight, 46);
        expect(
          [for (final s in chart.slots) s.label].where((l) => l.isNotEmpty),
          ['1', '8', '오늘', '22', '29'],
        );
        expect(chart.gap, 3);
        expect(chart.radius, 2);
      });

      test('every record: 10 bars without letters', () {
        final chart = StatsChart.skeleton(StatsPeriod.all, today);
        expect(chart.slots, hasLength(10));
        expect(chart.slots.every((s) => s.label.isEmpty), isTrue);
        expect(chart.gap, 6);
        expect(chart.radius, 4);
      });
    });

    test('calendar helpers keep midnights across months and years', () {
      expect(
        StatsChart.addDays(DateTime(2026, 12, 30), 3),
        DateTime(2027, 1, 2),
      );
      expect(
        StatsChart.mondayOf(DateTime(2026, 11, 15)),
        DateTime(2026, 11, 9),
      );
      expect(StatsChart.mondayOf(DateTime(2026, 11, 9)), DateTime(2026, 11, 9));
      expect(StatsChart.daysInMonth(DateTime(2028, 2)), 29);
      expect(
        StatsChart.daysBetween(DateTime(2026, 10, 31), DateTime(2026, 11, 2)),
        2,
      );
    });
  });

  group('FeedbackStatsWords', () {
    final now = goldenDayEnd('2026-11-14');

    test('the graph as one sentence: weekdays this week, dates spelled out '
        'otherwise, weeks from their Monday', () {
      PeriodStats of(StatsPeriod period, {DateTime? since}) =>
          const FeedbackStatsCalculator().period(
            goldenStatsPoints(since: since),
            period,
            now,
          );
      final week = of(StatsPeriod.week);
      expect(
        FeedbackStatsWords.chartLabel(
          StatsPeriod.week,
          StatsChart.of(week, now),
        ),
        '날짜별 인정 횟수. 월 27회, 화 0회, 수 10회, 목 43회, 금 16회, '
        '토 28회, 일 아직',
      );
      final days = of(StatsPeriod.all, since: DateTime(2026, 11, 2));
      expect(
        FeedbackStatsWords.chartLabel(
          StatsPeriod.all,
          StatsChart.of(days, now),
        ),
        startsWith('날짜별 인정 횟수. 11월 2일 25회, 11월 4일 8회'),
      );
      final month = of(StatsPeriod.month);
      expect(
        FeedbackStatsWords.chartLabel(
          StatsPeriod.month,
          StatsChart.of(month, now),
        ),
        allOf(startsWith('날짜별 인정 횟수. 11월 1일 9회'), endsWith('11월 30일 아직')),
      );
      final weeks = of(StatsPeriod.all);
      expect(
        FeedbackStatsWords.chartLabel(
          StatsPeriod.all,
          StatsChart.of(weeks, now),
        ),
        allOf(
          startsWith('주별 인정 횟수. 9월 7일부터 한 주 73회, 9월 14일부터 한 주 94회'),
          endsWith('11월 9일부터 한 주 124회'),
        ),
      );
    });

    test('the summary as a screen reader says it', () {
      final week = const FeedbackStatsCalculator().period(
        goldenStatsPoints(),
        StatsPeriod.week,
        now,
      );
      expect(
        FeedbackStatsWords.summaryLabel(StatsPeriod.week, week, now),
        '이번 주, 11월 9일 월요일부터 15일 일요일까지. 경기당 평균 인정 13.8회, '
        '경기 9판, 총 인정 124회',
      );
      expect(
        FeedbackStatsWords.spokenRange(
          StatsPeriod.week,
          null,
          DateTime(2026, 11, 1, 12),
        ),
        '이번 주, 10월 26일 월요일부터 11월 1일 일요일까지',
      );
      expect(
        FeedbackStatsWords.spokenRange(StatsPeriod.month, null, now),
        '이번 달, 11월 1일부터 30일까지',
      );
      expect(FeedbackStatsWords.spokenRange(StatsPeriod.all, null, now), '전체');
      expect(
        FeedbackStatsWords.summaryLabel(
          StatsPeriod.all,
          const PeriodStats(period: StatsPeriod.all, start: null),
          now,
        ),
        '전체. 경기당 평균 인정 없음, 경기 0판, 총 인정 0회',
      );
    });

    test('the report names are the form report\'s own titles', () {
      // form_analyzer.dart keeps them private; read them from its source.
      final source = File('lib/services/feedback/form_analyzer.dart')
          .readAsStringSync();
      final titles = {
        for (final m in RegExp(
          r"code: '(\w+)',\s*title: '([^'$]+)',",
        ).allMatches(source))
          m[1]!: m[2]!,
      };
      expect(titles, FeedbackStatsWords.reportNames);
    });

    test('rows read as one line, and the more button names what is left', () {
      const rejected = StatsIssueRow(
        code: 'reject.kneesDown',
        name: '무릎을 바닥에서 떼요',
        count: 7,
        widthPct: 100,
      );
      const report = StatsIssueRow(
        code: 'elbow_flare',
        name: '팔꿈치 벌어짐',
        count: 3,
        of: 8,
        widthPct: 38,
      );
      expect(rejected.group, StatsIssueGroup.rejected);
      expect(report.group, StatsIssueGroup.report);
      expect(FeedbackStatsWords.rowLabel(rejected), '무릎을 바닥에서 떼요, 거절 7회');
      expect(FeedbackStatsWords.rowLabel(report), '팔꿈치 벌어짐, 자세 기록 8판 중 3판');
      expect(FeedbackStatsWords.moreLabel(3, open: false), '나머지 3개 더 보기');
      expect(FeedbackStatsWords.moreLabel(3, open: true), '접기');
    });
  });
}
