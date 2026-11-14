import 'exercise_type.dart';
import 'game_score.dart';
import 'match_record.dart';
import 'rep_event.dart';

/// The statistics periods of UAT-4: every record, this month, this week.
enum StatsPeriod {
  /// Every battle the user played.
  all,

  /// From the 1st of this month, local midnight.
  month,

  /// From this Monday, local midnight.
  week,
}

/// One stored battle as the statistics need it: no names, no report.
class StatsPoint {
  const StatsPoint({
    required this.id,
    required this.exercise,
    required this.playedAt,
    required this.reps,
    this.score,
    this.outcome,
    this.gameEnd,
    this.isOnline = false,
    this.hasFeedback = false,
    this.issues = const {},
  });

  /// The server's id, the same as [MatchRecord.id].
  final int id;
  final ExerciseType exercise;

  /// Local time.
  final DateTime playedAt;

  /// Counted reps.
  final int reps;

  /// Game score; null for a battle saved before scores were kept.
  final int? score;
  final MatchOutcome? outcome;

  /// KO or time up; null for an online forfeit or disconnect.
  final GameEnd? gameEnd;
  final bool isOnline;

  /// Whether a form report was stored for it.
  final bool hasFeedback;

  /// Issue codes with counts, as in [FeedbackSummary.issues].
  final Map<String, int> issues;
}

/// The counted reps of one local day.
class DayReps {
  const DayReps({required this.date, required this.reps});

  /// Local midnight of the day.
  final DateTime date;
  final int reps;

  @override
  bool operator ==(Object other) =>
      other is DayReps && other.date == date && other.reps == reps;

  @override
  int get hashCode => Object.hash(date, reps);

  @override
  String toString() => 'DayReps($date, $reps)';
}

/// How often one form issue came up over a period.
class IssueCount {
  const IssueCount({required this.code, required this.count});

  /// Stable issue code, e.g. `elbow_flare` or `reject.insufficientDepth`.
  final String code;

  /// Rejected reps for a rejection; battles with the issue otherwise.
  final int count;

  /// The reject reason of a `reject.` code; null for the other issues and
  /// for a reason this app does not know.
  RejectReason? get rejectReason => code.startsWith(_rejectPrefix)
      ? RejectReason.values.asNameMap()[code.substring(_rejectPrefix.length)]
      : null;

  static const _rejectPrefix = 'reject.';

  @override
  bool operator ==(Object other) =>
      other is IssueCount && other.code == code && other.count == count;

  @override
  int get hashCode => Object.hash(code, count);

  @override
  String toString() => 'IssueCount($code, $count)';
}

/// The statistics screen's values for one period (UAT-4 AC3).
class PeriodStats {
  const PeriodStats({
    required this.period,
    required this.start,
    this.matches = 0,
    this.totalReps = 0,
    this.matchesWithFeedback = 0,
    this.daily = const [],
    this.issues = const [],
  });

  final StatsPeriod period;

  /// Local midnight the period starts at; null for every record.
  final DateTime? start;

  /// Battles in the period.
  final int matches;

  /// Counted reps of those battles.
  final int totalReps;

  /// Battles in the period with a stored form report, the ones [issues]
  /// come from.
  final int matchesWithFeedback;

  /// Counted reps by local day, oldest first: 7 slots Monday to Sunday for
  /// this week, one per day from the 1st to today for this month, and only
  /// the days with battles for every record.
  final List<DayReps> daily;

  /// Form issues, most frequent first (ties by code).
  final List<IssueCount> issues;

  /// Average counted reps per battle; null without battles.
  double? get averageReps => matches == 0 ? null : totalReps / matches;
}

/// One exercise's score history for the archive's growth view.
class ScoreGrowth {
  const ScoreGrowth({
    required this.exercise,
    this.scores = const [],
    this.firstPlayedAt,
  });

  final ExerciseType exercise;

  /// Game scores of the battles that kept one, oldest first.
  final List<int> scores;

  /// When the battle of [firstScore] was played; null without one.
  final DateTime? firstPlayedAt;

  /// The first kept score; null without one.
  int? get firstScore => scores.firstOrNull;

  /// The highest kept score; null without one.
  int? get bestScore =>
      scores.isEmpty ? null : scores.reduce((a, b) => a > b ? a : b);
}

/// The archive's (기록보관소) summary values over every battle.
class ArchiveStats {
  const ArchiveStats({
    this.weekReps = 0,
    this.weekMatches = 0,
    this.streakDays = 0,
    this.weekDaily = const [],
    this.growth = const {},
    this.bestGains = const {},
  });

  /// Counted reps over the last 7 local days, today included.
  final int weekReps;

  /// Battles over the same 7 days.
  final int weekMatches;

  /// Days in a row with a battle, up to today, or up to yesterday when
  /// today has none yet; 0 when the last battle is older than yesterday.
  final int streakDays;

  /// The last 7 local days, oldest first, today last; 0 reps on a day
  /// without battles.
  final List<DayReps> weekDaily;

  /// Score history per exercise; every exercise is present.
  final Map<ExerciseType, ScoreGrowth> growth;

  /// By match id: how much the battle beat the best earlier score of its
  /// exercise. Battles that set no new best are absent.
  final Map<int, int> bestGains;

  /// [bestGains] of [match]; null when it set no new best, was the first of
  /// its exercise, or is not stored.
  int? bestGainOf(MatchRecord match) =>
      match.id == null ? null : bestGains[match.id];
}
