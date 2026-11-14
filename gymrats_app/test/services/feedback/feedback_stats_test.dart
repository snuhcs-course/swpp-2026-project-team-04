import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/services/feedback/feedback_stats.dart';

import '../../support/feedback_fakes.dart';

/// Friday 2026-11-13, 21:00 local.
final _now = DateTime(2026, 11, 13, 21);

DateTime _day(int month, int day, [int hour = 12]) =>
    DateTime(2026, month, day, hour);

void main() {
  const calc = FeedbackStatsCalculator();

  group('period start', () {
    test('this week starts on Monday at local midnight', () {
      expect(calc.periodStart(StatsPeriod.week, _now), DateTime(2026, 11, 9));
      // On a Monday it is that same day; on a Sunday the Monday before.
      expect(
        calc.periodStart(StatsPeriod.week, DateTime(2026, 11, 9, 0, 0, 1)),
        DateTime(2026, 11, 9),
      );
      expect(
        calc.periodStart(StatsPeriod.week, DateTime(2026, 11, 15, 23, 59)),
        DateTime(2026, 11, 9),
      );
      // A week across the month and year boundary.
      expect(
        calc.periodStart(StatsPeriod.week, DateTime(2027, 1, 1)),
        DateTime(2026, 12, 28),
      );
    });

    test('this month starts on the 1st; every record has no start', () {
      expect(calc.periodStart(StatsPeriod.month, _now), DateTime(2026, 11));
      expect(calc.periodStart(StatsPeriod.all, _now), isNull);
    });
  });

  group('period statistics (UAT-4 AC3)', () {
    final points = [
      statsPoint(1, _day(10, 20), reps: 4),
      statsPoint(2, _day(11, 3), reps: 6, issues: {'elbow_flare': 1}),
      statsPoint(
        3,
        _day(11, 9, 0),
        reps: 10,
        issues: {'reject.insufficientDepth': 3, 'elbow_flare': 1},
      ),
      statsPoint(4, _day(11, 9, 23), reps: 8),
      statsPoint(
        5,
        _day(11, 13, 20),
        reps: 12,
        issues: {'reject.insufficientDepth': 1, 'head_lead': 1},
      ),
    ];

    test('this week: average, 7 slots Monday to Sunday, issue counts', () {
      final week = calc.period(points, StatsPeriod.week, _now);
      expect(week.period, StatsPeriod.week);
      expect(week.start, DateTime(2026, 11, 9));
      expect(week.matches, 3);
      expect(week.totalReps, 30);
      expect(week.averageReps, 10);
      expect(week.matchesWithFeedback, 2);
      expect(week.daily, [
        DayReps(date: DateTime(2026, 11, 9), reps: 18),
        DayReps(date: DateTime(2026, 11, 10), reps: 0),
        DayReps(date: DateTime(2026, 11, 11), reps: 0),
        DayReps(date: DateTime(2026, 11, 12), reps: 0),
        DayReps(date: DateTime(2026, 11, 13), reps: 12),
        DayReps(date: DateTime(2026, 11, 14), reps: 0),
        DayReps(date: DateTime(2026, 11, 15), reps: 0),
      ]);
      expect(week.issues, const [
        IssueCount(code: 'reject.insufficientDepth', count: 4),
        IssueCount(code: 'elbow_flare', count: 1),
        IssueCount(code: 'head_lead', count: 1),
      ]);
    });

    test('this month: one slot per day from the 1st to today', () {
      final month = calc.period(points, StatsPeriod.month, _now);
      expect(month.matches, 4);
      expect(month.averageReps, 9);
      expect(month.daily, hasLength(13));
      expect(month.daily.first, DayReps(date: DateTime(2026, 11), reps: 0));
      expect(month.daily[2], DayReps(date: DateTime(2026, 11, 3), reps: 6));
      expect(month.daily.last, DayReps(date: DateTime(2026, 11, 13), reps: 12));
      expect(
        month.issues.first,
        const IssueCount(code: 'reject.insufficientDepth', count: 4),
      );
      expect(month.issues[1], const IssueCount(code: 'elbow_flare', count: 2));
    });

    test('every record: only the days with battles, oldest first', () {
      final all = calc.period(points.reversed.toList(), StatsPeriod.all, _now);
      expect(all.start, isNull);
      expect(all.matches, 5);
      expect(all.averageReps, 8);
      expect(all.daily.map((d) => (d.date.month, d.date.day, d.reps)), [
        (10, 20, 4),
        (11, 3, 6),
        (11, 9, 18),
        (11, 13, 12),
      ]);
    });

    test('a period without battles has zeros, empty issues, no average', () {
      final empty = calc.period(const [], StatsPeriod.week, _now);
      expect(empty.matches, 0);
      expect(empty.averageReps, isNull);
      expect(empty.issues, isEmpty);
      expect(empty.daily.map((d) => d.reps), List.filled(7, 0));
      expect(calc.period(const [], StatsPeriod.all, _now).daily, isEmpty);
    });

    test('a battle one second before Monday is last week', () {
      final edge = [statsPoint(1, DateTime(2026, 11, 8, 23, 59, 59))];
      expect(calc.period(edge, StatsPeriod.week, _now).matches, 0);
      expect(calc.period(edge, StatsPeriod.month, _now).matches, 1);
    });
  });

  group('archive', () {
    test('last 7 days: today last, zeros on empty days, reps and battles', () {
      final archive = calc.archive([
        statsPoint(1, _day(11, 6, 23), reps: 50), // 8 days ago: left out
        statsPoint(2, DateTime(2026, 11, 7), reps: 5), // first slot
        statsPoint(3, _day(11, 10), reps: 7),
        statsPoint(4, _day(11, 10, 18), reps: 3),
        statsPoint(5, _day(11, 13, 20), reps: 9),
      ], _now);
      expect(archive.weekReps, 24);
      expect(archive.weekMatches, 4);
      expect(archive.weekDaily.map((d) => (d.date.day, d.reps)), [
        (7, 5),
        (8, 0),
        (9, 0),
        (10, 10),
        (11, 0),
        (12, 0),
        (13, 9),
      ]);
    });

    test('a user without battles has zeros and empty growth', () {
      final archive = calc.archive(const [], _now);
      expect(
        (archive.weekReps, archive.weekMatches, archive.streakDays),
        (0, 0, 0),
      );
      expect(archive.weekDaily, hasLength(7));
      expect(archive.growth.keys, ExerciseType.values);
      final growth = archive.growth[ExerciseType.pushUp]!;
      expect(growth.scores, isEmpty);
      expect(
        (growth.firstScore, growth.bestScore, growth.firstPlayedAt),
        (null, null, null),
      );
      expect(archive.bestGains, isEmpty);
    });

    group('streak', () {
      int streak(List<int> daysAgo) => calc.archive([
        for (final (i, ago) in daysAgo.indexed)
          statsPoint(i, DateTime(2026, 11, 13 - ago, 8)),
      ], _now).streakDays;

      test('counts today and the days before it', () {
        expect(streak([0, 1, 2]), 3);
        expect(streak([0, 0, 1]), 2);
        expect(streak([0, 2, 3]), 1);
      });

      test('still counts up to yesterday when today has no battle yet', () {
        expect(streak([1, 2, 3, 5]), 3);
        expect(streak([1]), 1);
      });

      test('is 0 when the last battle is older than yesterday', () {
        expect(streak([2, 3, 4]), 0);
        expect(streak([]), 0);
      });

      test('days are cut at local midnight, across months', () {
        final archive = calc.archive([
          statsPoint(1, DateTime(2026, 10, 31, 23, 59)),
          statsPoint(2, DateTime(2026, 11, 1, 0, 0)),
          statsPoint(3, DateTime(2026, 11, 2, 0, 30)),
        ], DateTime(2026, 11, 2, 9));
        expect(archive.streakDays, 3);
      });
    });

    test('growth per exercise: kept scores oldest first, first and best', () {
      final archive = calc.archive([
        statsPoint(3, _day(11, 10), score: 120),
        statsPoint(1, _day(11, 2), score: null),
        statsPoint(2, _day(11, 5), score: 90),
        statsPoint(4, _day(11, 12), score: 100),
        statsPoint(5, _day(11, 11), score: 60, exercise: ExerciseType.squat),
      ], _now);
      final pushUp = archive.growth[ExerciseType.pushUp]!;
      expect(pushUp.scores, [90, 120, 100]);
      expect(pushUp.firstScore, 90);
      expect(pushUp.bestScore, 120);
      // The date of the first kept score, not of the older battle without one.
      expect(pushUp.firstPlayedAt, _day(11, 5));
      final squat = archive.growth[ExerciseType.squat]!;
      expect(squat.scores, [60]);
      expect(squat.firstPlayedAt, _day(11, 11));
    });

    test('best gain: above the earlier best of the same exercise only', () {
      final archive = calc.archive(
        [
          statsPoint(1, _day(11, 1), score: 100), // first: null
          statsPoint(2, _day(11, 2), score: 155), // +55
          statsPoint(3, _day(11, 3), score: 150), // below the best
          statsPoint(4, _day(11, 4), score: 155), // ties the best
          statsPoint(5, _day(11, 5), score: null), // no score
          statsPoint(6, _day(11, 6), score: 160), // +5
          // The squat's first battle has nothing to beat.
          statsPoint(7, _day(11, 7), score: 300, exercise: ExerciseType.squat),
          statsPoint(8, _day(11, 8), score: 310, exercise: ExerciseType.squat),
        ].reversed.toList(),
        _now,
      );
      expect(archive.bestGains, {2: 55, 6: 5, 8: 10});
    });

    test('battles at the same time are ordered by id', () {
      final archive = calc.archive([
        statsPoint(2, _day(11, 1), score: 130),
        statsPoint(1, _day(11, 1), score: 100),
      ], _now);
      expect(archive.bestGains, {2: 30});
      expect(archive.growth[ExerciseType.pushUp]!.scores, [100, 130]);
    });

    test('a battle before any scored one sets no gain', () {
      final archive = calc.archive([
        statsPoint(1, _day(11, 1), score: null),
        statsPoint(2, _day(11, 2), score: 80),
      ], _now);
      expect(archive.bestGains, isEmpty);
    });
  });

  test('dayOf is local midnight', () {
    expect(
      FeedbackStatsCalculator.dayOf(DateTime(2026, 11, 13, 23, 59, 59)),
      DateTime(2026, 11, 13),
    );
  });

  test('a UTC time is cut at local midnight, like a local one', () {
    final local = DateTime(2026, 11, 13, 0, 30);
    expect(
      FeedbackStatsCalculator.dayOf(local.toUtc()),
      DateTime(2026, 11, 13),
    );
    final archive = calc.archive([statsPoint(1, local.toUtc())], _now);
    expect(archive.weekDaily.last.reps, 10);
    expect(archive.streakDays, 1);
  });

  test('a battle stamped after now is left out, so bars match the totals', () {
    final points = [
      statsPoint(1, _day(11, 13, 9), reps: 5),
      statsPoint(2, DateTime(2026, 11, 14, 8), reps: 50), // phone clock ahead
    ];
    final archive = calc.archive([
      ...points,
      statsPoint(3, DateTime(2026, 11, 14, 9), score: 999),
    ], _now);
    expect((archive.weekReps, archive.weekMatches), (5, 1));
    // Nor does it count for the streak, growth or best gains.
    expect(archive.streakDays, 1);
    expect(archive.growth[ExerciseType.pushUp]!.scores, isEmpty);
    expect(archive.bestGains, isEmpty);
    expect(archive.weekDaily.fold(0, (sum, d) => sum + d.reps), 5);
    for (final period in StatsPeriod.values) {
      final stats = calc.period(points, period, _now);
      expect(stats.matches, 1, reason: '$period');
      expect(stats.daily.fold(0, (sum, d) => sum + d.reps), 5);
    }
  });
}
