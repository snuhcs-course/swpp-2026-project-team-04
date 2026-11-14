import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/rep_event.dart';

MatchRecord _match(int? id) => MatchRecord(
  id: id,
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: 3,
  opponentReps: 1,
);

void main() {
  test('a point defaults to offline, no feedback, no issues', () {
    final point = StatsPoint(
      id: 1,
      exercise: ExerciseType.squat,
      playedAt: DateTime(2026, 11, 13),
      reps: 4,
    );
    expect((point.isOnline, point.hasFeedback), (false, false));
    expect((point.score, point.outcome, point.gameEnd), (null, null, null));
    expect(point.issues, isEmpty);
  });

  test('day reps and issue counts compare by value', () {
    final day = DateTime(2026, 11, 13);
    expect(DayReps(date: day, reps: 3), DayReps(date: day, reps: 3));
    expect(DayReps(date: day, reps: 3), isNot(DayReps(date: day, reps: 4)));
    expect(
      DayReps(date: day, reps: 3).hashCode,
      DayReps(date: day, reps: 3).hashCode,
    );
    expect(DayReps(date: day, reps: 3).toString(), contains('3'));
    const a = IssueCount(code: 'head_lead', count: 2);
    expect(a, const IssueCount(code: 'head_lead', count: 2));
    expect(a, isNot(const IssueCount(code: 'head_lead', count: 1)));
    expect(a.hashCode, const IssueCount(code: 'head_lead', count: 2).hashCode);
    expect(a.toString(), 'IssueCount(head_lead, 2)');
  });

  test('a reject code names its reason; other codes have none', () {
    expect(
      const IssueCount(code: 'reject.insufficientDepth', count: 1).rejectReason,
      RejectReason.insufficientDepth,
    );
    expect(
      const IssueCount(code: 'reject.shallowSquat', count: 1).rejectReason,
      RejectReason.shallowSquat,
    );
    expect(
      const IssueCount(code: 'elbow_flare', count: 1).rejectReason,
      isNull,
    );
    // A reason from a newer app version.
    expect(
      const IssueCount(code: 'reject.somethingNew', count: 1).rejectReason,
      isNull,
    );
  });

  test('the average is per battle, and none without battles', () {
    const empty = PeriodStats(period: StatsPeriod.all, start: null);
    expect(empty.averageReps, isNull);
    expect(empty.daily, isEmpty);
    expect(empty.issues, isEmpty);
    const some = PeriodStats(
      period: StatsPeriod.week,
      start: null,
      matches: 4,
      totalReps: 30,
    );
    expect(some.averageReps, 7.5);
  });

  test('growth: first and best of the kept scores, null without any', () {
    const none = ScoreGrowth(exercise: ExerciseType.pushUp);
    expect(
      (none.firstScore, none.bestScore, none.firstPlayedAt),
      (null, null, null),
    );
    const some = ScoreGrowth(
      exercise: ExerciseType.pushUp,
      scores: [80, 140, 120],
    );
    expect((some.firstScore, some.bestScore), (80, 140));
  });

  test('best gain of a match: by id, null when absent or unstored', () {
    const archive = ArchiveStats(bestGains: {7: 55});
    expect(archive.bestGainOf(_match(7)), 55);
    expect(archive.bestGainOf(_match(8)), isNull);
    expect(archive.bestGainOf(_match(null)), isNull);
    const empty = ArchiveStats();
    expect((empty.weekReps, empty.weekMatches, empty.streakDays), (0, 0, 0));
    expect(empty.weekDaily, isEmpty);
    expect(empty.growth, isEmpty);
  });
}
