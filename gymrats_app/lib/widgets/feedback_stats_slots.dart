import 'dart:math' as math;

import '../models/feedback_stats.dart';
import '../services/feedback/feedback_stats.dart';

/// How a bar of the statistics graph looks.
enum StatsBarLook {
  /// A past slot with reps: gray.
  value,

  /// The slot with today (this week, when grouped) and reps: ink.
  now,

  /// A past slot without reps: a thin light line.
  zero,

  /// A day not come yet: a dashed outline.
  future,

  /// A placeholder while the battles load.
  skeleton,
}

/// What the graph's slots stand for.
enum StatsChartKind {
  /// One slot per day.
  day,

  /// One slot per week, Monday to Sunday (every record, over 14 days).
  week,
}

/// One slot of the statistics graph: its bar, the reps over it and the
/// letters under it.
class StatsSlot {
  const StatsSlot({
    required this.date,
    required this.reps,
    required this.label,
    required this.barHeight,
    required this.look,
    this.future = false,
    this.now = false,
    this.valueShown = false,
  });

  /// The day, or the week's Monday; local midnight. Null for a placeholder.
  final DateTime? date;
  final int reps;

  /// Under the bar; empty for none.
  final String label;

  /// In the 92 high plot.
  final double barHeight;
  final StatsBarLook look;

  /// A day not come yet.
  final bool future;

  /// The slot with today (or this week).
  final bool now;

  /// Whether the reps are written over the bar.
  final bool valueShown;
}

/// The statistics graph's slots and spacing (W7-STATS 3), worked out from a
/// period's values without any widget, so it can be checked against the
/// mockup's numbers.
class StatsChart {
  const StatsChart({
    required this.kind,
    required this.slots,
    required this.gap,
    required this.radius,
  });

  final StatsChartKind kind;
  final List<StatsSlot> slots;

  /// Between two slots.
  final double gap;

  /// The corners of a bar with reps; the thin and the dashed ones use
  /// [smallRadius].
  final double radius;

  /// The plot's height: the value line, its gap and the tallest bar.
  static const plotHeight = 92.0;
  static const maxBar = 77.0;
  static const valueGap = 3.0;
  static const zeroBar = 3.0;
  static const futureBar = 4.0;
  static const leastBar = 4.0;
  static const smallRadius = 2.0;

  /// From the plot to the letters, and the letters' line.
  static const labelGap = 6.0;
  static const labelLine = 14.0;

  /// The placeholder bars while loading, repeated.
  static const skeletonHeights = [46, 64, 30, 72, 40, 58, 34, 52, 26, 66];

  /// Slots of every record, by day up to this many days with battles.
  static const maxDaySlots = 14;

  static double gapFor(int slots) => slots <= 7
      ? 8
      : slots <= 16
      ? 6
      : 3;

  static double radiusFor(int slots) => slots <= 7
      ? 6
      : slots <= 16
      ? 4
      : 2;

  bool get isEmpty => slots.isEmpty;

  /// The graph of [stats] on the day of [now] (the view model's clock).
  factory StatsChart.of(PeriodStats stats, DateTime now) {
    final today = FeedbackStatsCalculator.dayOf(now);
    final daily = stats.daily;
    var kind = StatsChartKind.day;
    final raw = <_Raw>[];
    switch (stats.period) {
      case StatsPeriod.week:
        for (final day in daily) {
          raw.add(
            _Raw(
              day.date,
              day.reps,
              future: day.date.isAfter(today),
              now: day.date == today,
              label: day.date == today ? '오늘' : weekdayName(day.date),
            ),
          );
        }
      case StatsPeriod.month:
        final start = stats.start ?? DateTime(today.year, today.month);
        final days = daysInMonth(start);
        final reps = {for (final day in daily) day.date: day.reps};
        for (var i = 0; i < days; i++) {
          final date = DateTime(start.year, start.month, 1 + i);
          raw.add(
            _Raw(
              date,
              reps[date] ?? 0,
              future: date.isAfter(today),
              now: date == today,
              label: monthLabel(date, today),
            ),
          );
        }
      case StatsPeriod.all when daily.length <= maxDaySlots:
        int? lastMonth;
        for (final day in daily) {
          final date = day.date;
          raw.add(
            _Raw(
              date,
              day.reps,
              now: date == today,
              label: date == today
                  ? '오늘'
                  : date.month != lastMonth
                  ? '${date.month}/${date.day}'
                  : '${date.day}',
            ),
          );
          lastMonth = date.month;
        }
      case StatsPeriod.all:
        kind = StatsChartKind.week;
        final firstMonday = mondayOf(daily.first.date);
        final thisMonday = mondayOf(today);
        final count = daysBetween(firstMonday, thisMonday) ~/ 7 + 1;
        final reps = {for (final day in daily) day.date: day.reps};
        for (var w = 0; w < count; w++) {
          final monday = addDays(firstMonday, 7 * w);
          var sum = 0;
          for (var d = 0; d < 7; d++) {
            sum += reps[addDays(monday, d)] ?? 0;
          }
          final fromEnd = count - 1 - w;
          raw.add(
            _Raw(
              monday,
              sum,
              now: fromEnd == 0,
              label: fromEnd == 0
                  ? '이번 주'
                  : count > 6 && fromEnd.isOdd
                  ? ''
                  : '${monday.month}/${monday.day}',
            ),
          );
        }
    }
    return _build(kind, raw, showEveryValue: _showsEveryValue(stats, kind));
  }

  /// The placeholder graph while [period]'s battles load: [period]'s slots
  /// (10 for every record) with gray bars of [skeletonHeights] and the
  /// letters of 3.4 (none for every record).
  factory StatsChart.skeleton(StatsPeriod period, DateTime now) {
    final today = FeedbackStatsCalculator.dayOf(now);
    final start = const FeedbackStatsCalculator().periodStart(period, now);
    final labels = switch (period) {
      StatsPeriod.week => [
        for (var i = 0; i < 7; i++)
          addDays(start!, i) == today ? '오늘' : weekdayName(addDays(start, i)),
      ],
      StatsPeriod.month => [
        for (var i = 0; i < daysInMonth(start!); i++)
          monthLabel(addDays(start, i), today),
      ],
      StatsPeriod.all => List.filled(10, ''),
    };
    return StatsChart(
      kind: StatsChartKind.day,
      gap: gapFor(labels.length),
      radius: radiusFor(labels.length),
      slots: [
        for (final (i, label) in labels.indexed)
          StatsSlot(
            date: null,
            reps: 0,
            label: label,
            barHeight: skeletonHeights[i % skeletonHeights.length].toDouble(),
            look: StatsBarLook.skeleton,
          ),
      ],
    );
  }

  /// Every slot's reps over this week's and the by-day record's bars; for
  /// the month and the weeks, only the highest (the first of equals) and
  /// the one with today.
  static bool _showsEveryValue(PeriodStats stats, StatsChartKind kind) =>
      stats.period == StatsPeriod.week ||
      (stats.period == StatsPeriod.all && kind == StatsChartKind.day);

  static StatsChart _build(
    StatsChartKind kind,
    List<_Raw> raw, {
    required bool showEveryValue,
  }) {
    final past = raw.where((s) => !s.future);
    final most = past.fold(1, (most, s) => math.max(most, s.reps));
    final mostAt = raw.indexWhere((s) => !s.future && s.reps == most);
    final radius = radiusFor(raw.length);
    return StatsChart(
      kind: kind,
      gap: gapFor(raw.length),
      radius: radius,
      slots: [
        for (final (i, s) in raw.indexed)
          StatsSlot(
            date: s.date,
            reps: s.reps,
            label: s.label,
            future: s.future,
            now: s.now,
            valueShown:
                !s.future &&
                s.reps > 0 &&
                (showEveryValue || s.now || i == mostAt),
            barHeight: s.future
                ? futureBar
                : s.reps > 0
                ? math.max(leastBar, (s.reps / most * maxBar).roundToDouble())
                : zeroBar,
            look: s.future
                ? StatsBarLook.future
                : s.reps == 0
                ? StatsBarLook.zero
                : s.now
                ? StatsBarLook.now
                : StatsBarLook.value,
          ),
      ],
    );
  }

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  /// "월" ... "일".
  static String weekdayName(DateTime date) => _weekdays[date.weekday - 1];

  /// This month's letter: today's "오늘", and the 1st, 8th, 15th, 22nd and
  /// 29th unless within two days of today (they would run into "오늘").
  static String monthLabel(DateTime date, DateTime today) {
    if (date == today) return '오늘';
    if (!const [1, 8, 15, 22, 29].contains(date.day)) return '';
    if (daysBetween(date, today).abs() <= 2) return '';
    return '${date.day}';
  }

  /// Calendar days, so a daylight-saving change never shifts a midnight.
  static DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  static DateTime mondayOf(DateTime day) => addDays(day, 1 - day.weekday);

  static int daysInMonth(DateTime day) =>
      DateTime(day.year, day.month + 1, 0).day;

  /// Whole calendar days from [from] to [to].
  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

class _Raw {
  _Raw(
    this.date,
    this.reps, {
    required this.label,
    this.future = false,
    this.now = false,
  });

  final DateTime date;
  final int reps;
  final String label;
  final bool future;
  final bool now;
}
