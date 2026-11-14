import 'dart:math' as math;

import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/feedback_stats.dart';
import '../models/reject_reason_korean.dart';
import '../services/feedback/feedback_stats.dart';
import 'feedback_stats_slots.dart';

/// Which of the form-issue card's two groups a row is in.
enum StatsIssueGroup {
  /// Reps that were not counted, by reason (회).
  rejected,

  /// Battles whose form report found the issue (판).
  report,
}

/// One row of the form-issue card.
class StatsIssueRow {
  const StatsIssueRow({
    required this.code,
    required this.name,
    required this.count,
    required this.widthPct,
    this.of,
  });

  final String code;
  final String name;
  final int count;

  /// The bar's length in percent of the row (at least 4).
  final int widthPct;

  /// The battles with a form record, for a report row ("3판 / 8").
  final int? of;

  StatsIssueGroup get group =>
      of == null ? StatsIssueGroup.rejected : StatsIssueGroup.report;
}

/// The statistics screen's words (W7-STATS 4), worked out from the view
/// model's values without any widget: the screen words, the view model
/// counts.
abstract final class FeedbackStatsWords {
  /// Rows shown per group before "나머지 N개 더 보기".
  static const cut = 5;

  /// The shortest bar of a row, in percent.
  static const leastWidthPct = 4;

  /// The form report's issue titles, as `form_analyzer.dart` names them.
  static const reportNames = {
    'imbalance': '좌우 불균형',
    'depth_loss': '후반 깊이 감소',
    'fast_descent': '내려가는 속도',
    'elbow_flare': '팔꿈치 벌어짐',
    'hand_width': '손 간격',
    'head_lead': '고개가 먼저 내려감',
  };

  static const _calculator = FeedbackStatsCalculator();

  static String _md(DateTime day) => '${day.month}/${day.day}';

  static DateTime _start(
    StatsPeriod period,
    PeriodStats? stats,
    DateTime now,
  ) => stats?.start ?? _calculator.periodStart(period, now)!;

  /// The summary card's first line, e.g. "이번 주 · 11/9 월 ~ 11/15 일";
  /// before [stats] loads, from [now] ("전체" alone for every record).
  static String range(StatsPeriod period, PeriodStats? stats, DateTime now) {
    switch (period) {
      case StatsPeriod.week:
        final start = _start(period, stats, now);
        final end = StatsChart.addDays(start, 6);
        return '이번 주 · ${_md(start)} 월 ~ ${_md(end)} 일';
      case StatsPeriod.month:
        final start = _start(period, stats, now);
        return '이번 달 · ${start.month}/1 ~ '
            '${start.month}/${StatsChart.daysInMonth(start)}';
      case StatsPeriod.all:
        final daily = stats?.daily ?? const [];
        return daily.isEmpty ? '전체' : '전체 · ${_md(daily.first.date)} 첫 경기부터';
    }
  }

  /// The same, as a screen reader says it: "이번 주, 11월 9일 월요일부터
  /// 15일 일요일까지".
  static String spokenRange(
    StatsPeriod period,
    PeriodStats? stats,
    DateTime now,
  ) {
    switch (period) {
      case StatsPeriod.week:
        final start = _start(period, stats, now);
        final end = StatsChart.addDays(start, 6);
        final endMonth = end.month == start.month ? '' : '${end.month}월 ';
        return '이번 주, ${start.month}월 ${start.day}일 월요일부터 '
            '$endMonth${end.day}일 일요일까지';
      case StatsPeriod.month:
        final start = _start(period, stats, now);
        return '이번 달, ${start.month}월 1일부터 '
            '${StatsChart.daysInMonth(start)}일까지';
      case StatsPeriod.all:
        final daily = stats?.daily ?? const [];
        if (daily.isEmpty) return '전체';
        final first = daily.first.date;
        return '전체, ${first.month}월 ${first.day}일 첫 경기부터';
    }
  }

  /// The average counted reps to one decimal ("13.8", "12.0"), or "–"
  /// without battles.
  static String average(PeriodStats stats) {
    final average = stats.averageReps;
    return average == null
        ? '–'
        : ((average * 10).round() / 10).toStringAsFixed(1);
  }

  /// The summary card as a screen reader says it.
  static String summaryLabel(
    StatsPeriod period,
    PeriodStats stats,
    DateTime now,
  ) {
    final average = stats.matches == 0
        ? '없음'
        : '${FeedbackStatsWords.average(stats)}회';
    return '${spokenRange(period, stats, now)}. 경기당 평균 인정 $average, '
        '경기 ${stats.matches}판, 총 인정 ${stats.totalReps}회';
  }

  /// The graph as one sentence: "날짜별 인정 횟수. 월 27회, 화 0회, …, 일
  /// 아직", "날짜별 인정 횟수. 11월 1일 9회, …" or, by week, "주별 인정
  /// 횟수. 9월 7일부터 한 주 73회, …". Dates are spelled out (W7-STATS 7),
  /// as "9/7" may be read as a fraction.
  static String chartLabel(StatsPeriod period, StatsChart chart) {
    final byWeek = chart.kind == StatsChartKind.week;
    String spoken(DateTime day) => '${day.month}월 ${day.day}일';
    String name(DateTime day) => byWeek
        ? '${spoken(day)}부터 한 주'
        : period == StatsPeriod.week
        ? StatsChart.weekdayName(day)
        : spoken(day);
    final words = [
      for (final slot in chart.slots)
        '${name(slot.date!)} ${slot.future ? '아직' : '${slot.reps}회'}',
    ];
    return '${byWeek ? '주별' : '날짜별'} 인정 횟수. ${words.join(', ')}';
  }

  /// Under a graph of weeks.
  static const weeksNote = '경기한 날이 14일을 넘어서 한 주씩 묶었어요. 막대 하나가 월요일부터 일요일까지예요.';

  /// The notice of a period without battles: the first line.
  static String emptyTitle(StatsPeriod period, ExerciseType? exercise) {
    final name = exercise == null ? '' : '${exercise.koreanName} ';
    return switch (period) {
      StatsPeriod.all => '아직 $name경기 기록이 없어요',
      StatsPeriod.month => '이번 달에는 아직 $name경기가 없어요',
      StatsPeriod.week => '이번 주에는 아직 $name경기가 없어요',
    };
  }

  /// The notice's second line.
  static String emptyDetail(StatsPeriod period) => period == StatsPeriod.all
      ? '첫 대결을 마치면 여기에 날짜별로 쌓여요.'
      : '대결을 마치면 여기에 날짜별로 쌓여요.';

  /// The form-issue card's base, e.g. "경기 9판 중 자세 기록 8판 기준";
  /// null without battles.
  static String? base(PeriodStats stats) {
    if (stats.matches == 0) return null;
    final withFeedback = stats.matchesWithFeedback;
    return withFeedback == stats.matches
        ? '자세 기록 있는 $withFeedback판 기준'
        : '경기 ${stats.matches}판 중 자세 기록 $withFeedback판 기준';
  }

  /// The form-issue card's only line when no battle has a form record;
  /// null when some do.
  static String? blank(PeriodStats stats) {
    if (stats.matchesWithFeedback > 0) return null;
    return stats.matches == 0
        ? '경기를 마치면 자세 문제가 여기에 모여요.'
        : '이 기간 경기에는 자세 기록이 없어요.';
  }

  /// The "거절된 이유" rows, most first: bars against the largest count.
  /// A reason this app does not know is left out (user, 2026-11-14).
  static List<StatsIssueRow> rejectedRows(PeriodStats stats) {
    final known = [
      for (final issue in stats.issues)
        if (issue.rejectReason case final reason?)
          (issue: issue, name: reason.koreanMessage),
    ];
    final most = known.fold(1, (most, row) => math.max(most, row.issue.count));
    return [
      for (final (:issue, :name) in known)
        StatsIssueRow(
          code: issue.code,
          name: name,
          count: issue.count,
          widthPct: _pct(issue.count, most),
        ),
    ];
  }

  /// The "자세 리포트" rows, most first: bars against the battles with a
  /// form record. A code this app does not know is left out.
  static List<StatsIssueRow> reportRows(PeriodStats stats) {
    final withFeedback = stats.matchesWithFeedback;
    return [
      for (final issue in stats.issues)
        if (!issue.code.startsWith('reject.'))
          if (reportNames[issue.code] case final name?)
            StatsIssueRow(
              code: issue.code,
              name: name,
              count: issue.count,
              of: withFeedback,
              widthPct: _pct(issue.count, math.max(1, withFeedback)),
            ),
    ];
  }

  static int _pct(int count, int whole) =>
      math.min(100, math.max(leastWidthPct, (count / whole * 100).round()));

  /// A row as a screen reader says it: "가슴을 더 내려요, 거절 7회",
  /// "팔꿈치 벌어짐, 자세 기록 8판 중 3판".
  static String rowLabel(StatsIssueRow row) => row.of == null
      ? '${row.name}, 거절 ${row.count}회'
      : '${row.name}, 자세 기록 ${row.of}판 중 ${row.count}판';

  /// "나머지 3개 더 보기", or "접기" when open.
  static String moreLabel(int hidden, {required bool open}) =>
      open ? '접기' : '나머지 $hidden개 더 보기';
}
