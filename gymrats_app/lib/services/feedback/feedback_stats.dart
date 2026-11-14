import '../../models/exercise_type.dart';
import '../../models/feedback_stats.dart';

/// Where the statistics' battles come from: every stored battle of the
/// period, uncapped (the server's `GET /matches/stats`).
abstract interface class FeedbackStatsSource {
  /// The user's battles played at or after [since] (all of them when null),
  /// of [exercise] only when given, oldest first.
  ///
  /// Throws an [Exception] when they cannot be loaded.
  Future<List<StatsPoint>> fetchStatsPoints({
    ExerciseType? exercise,
    DateTime? since,
  });
}

/// Turns stored battles into the archive and statistics values. Days are
/// cut at local midnight of [now]'s time zone.
class FeedbackStatsCalculator {
  const FeedbackStatsCalculator();

  /// Local midnight of [time]'s day; a UTC time is turned local first.
  static DateTime dayOf(DateTime time) {
    final local = time.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Where [period] starts at [now]; null for every record.
  DateTime? periodStart(StatsPeriod period, DateTime now) {
    final today = dayOf(now);
    return switch (period) {
      StatsPeriod.all => null,
      StatsPeriod.month => DateTime(today.year, today.month),
      StatsPeriod.week => _addDays(today, 1 - today.weekday),
    };
  }

  /// The statistics screen's values of [period] from [points] (any order;
  /// battles before the period are left out).
  PeriodStats period(
    List<StatsPoint> points,
    StatsPeriod period,
    DateTime now,
  ) {
    final start = periodStart(period, now);
    final inPeriod = [
      for (final p in points)
        if ((start == null || !p.playedAt.isBefore(start)) &&
            !p.playedAt.isAfter(now))
          p,
    ];
    final byDay = _repsByDay(inPeriod);
    final today = dayOf(now);
    final daily = switch (period) {
      StatsPeriod.all => [
        for (final day in byDay.keys.toList()..sort())
          DayReps(date: day, reps: byDay[day]!),
      ],
      StatsPeriod.month => _slots(byDay, start!, today.day),
      StatsPeriod.week => _slots(byDay, start!, 7),
    };
    final issues = <String, int>{};
    for (final p in inPeriod) {
      for (final MapEntry(:key, :value) in p.issues.entries) {
        issues[key] = (issues[key] ?? 0) + value;
      }
    }
    return PeriodStats(
      period: period,
      start: start,
      matches: inPeriod.length,
      totalReps: inPeriod.fold(0, (sum, p) => sum + p.reps),
      matchesWithFeedback: inPeriod.where((p) => p.hasFeedback).length,
      daily: daily,
      issues:
          [
            for (final MapEntry(:key, :value) in issues.entries)
              IssueCount(code: key, count: value),
          ]..sort(
            (a, b) => b.count != a.count
                ? b.count.compareTo(a.count)
                : a.code.compareTo(b.code),
          ),
    );
  }

  /// The archive's values from every stored battle (any order). A battle
  /// stamped after [now] (a phone clock ahead) is left out of all of them.
  ArchiveStats archive(List<StatsPoint> all, DateTime now) {
    final points = [
      for (final p in all)
        if (!p.playedAt.isAfter(now)) p,
    ];
    final today = dayOf(now);
    final weekStart = _addDays(today, -6);
    final lastWeek = [
      for (final p in points)
        if (!p.playedAt.isBefore(weekStart)) p,
    ];
    final sorted = [...points]..sort(_byTime);
    return ArchiveStats(
      weekReps: lastWeek.fold(0, (sum, p) => sum + p.reps),
      weekMatches: lastWeek.length,
      streakDays: _streak(points, today),
      weekDaily: _slots(_repsByDay(lastWeek), weekStart, 7),
      growth: {
        for (final exercise in ExerciseType.values)
          exercise: _growth(exercise, sorted),
      },
      bestGains: _bestGains(sorted),
    );
  }

  static int _byTime(StatsPoint a, StatsPoint b) {
    final time = a.playedAt.compareTo(b.playedAt);
    return time != 0 ? time : a.id.compareTo(b.id);
  }

  static Map<DateTime, int> _repsByDay(Iterable<StatsPoint> points) {
    final byDay = <DateTime, int>{};
    for (final p in points) {
      final day = dayOf(p.playedAt);
      byDay[day] = (byDay[day] ?? 0) + p.reps;
    }
    return byDay;
  }

  /// [count] day slots from [start], 0 reps on a day without battles.
  static List<DayReps> _slots(
    Map<DateTime, int> byDay,
    DateTime start,
    int count,
  ) => [
    for (var i = 0; i < count; i++)
      DayReps(date: _addDays(start, i), reps: byDay[_addDays(start, i)] ?? 0),
  ];

  static int _streak(List<StatsPoint> points, DateTime today) {
    final days = {for (final p in points) dayOf(p.playedAt)};
    var day = days.contains(today) ? today : _addDays(today, -1);
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = _addDays(day, -1);
    }
    return streak;
  }

  static ScoreGrowth _growth(ExerciseType exercise, List<StatsPoint> sorted) {
    final scored = sorted.where(
      (p) => p.exercise == exercise && p.score != null,
    );
    return ScoreGrowth(
      exercise: exercise,
      scores: [for (final p in scored) p.score!],
      firstPlayedAt: scored.firstOrNull?.playedAt,
    );
  }

  static Map<int, int> _bestGains(List<StatsPoint> sorted) {
    final best = <ExerciseType, int>{};
    final gains = <int, int>{};
    for (final p in sorted) {
      final score = p.score;
      if (score == null) continue;
      final before = best[p.exercise];
      if (before != null && score > before) gains[p.id] = score - before;
      if (before == null || score > before) best[p.exercise] = score;
    }
    return gains;
  }

  /// Calendar days, so a daylight-saving change never shifts the midnight.
  static DateTime _addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);
}
