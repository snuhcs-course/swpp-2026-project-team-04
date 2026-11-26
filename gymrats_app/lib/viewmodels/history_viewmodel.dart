import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/arcade_stage.dart';
import '../models/exercise_type.dart';
import '../models/feedback_stats.dart';
import '../models/hold_record.dart';
import '../models/match_record.dart';
import '../models/rep_event.dart';
import '../services/api/api_client.dart';
import '../services/feedback/feedback_stats.dart';
import '../services/feedback/hold_record_store.dart';
import '../services/user/user_repository.dart';
import 'login_viewmodel.dart';

/// What the history screen is showing.
enum HistoryPhase {
  /// Fetching the first page.
  loading,

  /// At least one battle is shown.
  ready,

  /// The user has no battles yet.
  empty,

  /// The first page failed; the user can retry.
  failed,
}

/// Which battles the 경기 tab lists (P13, draft C).
enum ArchiveFilter {
  all('전체'),
  pushUp('푸쉬업'),
  squat('스쿼트'),
  online('온라인'),
  arcade('아케이드'),
  hold('버티기');

  const ArchiveFilter(this.label);

  /// The chip's words.
  final String label;

  /// Whether [match] is listed under this filter. A battle whose kind the
  /// server did not say is only under 전체 and its exercise.
  bool keeps(MatchRecord match) => switch (this) {
    all => true,
    pushUp => match.exercise == ExerciseType.pushUp,
    squat => match.exercise == ExerciseType.squat,
    online => match.isOnline == true,
    arcade => match.isOnline == false,
    hold => false,
  };

  /// Whether the arcade's holds are listed: under 전체, 아케이드 and 버티기.
  bool get keepsHolds => this == all || this == arcade || this == hold;
}

/// One row of the 경기 tab: a battle or a played hold (P13).
sealed class ArchiveEntry {
  const ArchiveEntry();

  /// When it was played; null for a battle saved without a time.
  DateTime? get at;
}

final class ArchiveMatchEntry extends ArchiveEntry {
  const ArchiveMatchEntry(this.match);

  final MatchRecord match;

  @override
  DateTime? get at => match.playedAt?.toLocal();
}

final class ArchiveHoldEntry extends ArchiveEntry {
  const ArchiveHoldEntry(this.hold);

  final HoldRecord hold;

  @override
  DateTime? get at => hold.endedAt.toLocal();
}

/// The battles and holds of one local day, newest first, for the 경기 tab.
class ArchiveDay {
  const ArchiveDay({required this.date, required this.entries});

  /// Local midnight.
  final DateTime date;
  final List<ArchiveEntry> entries;

  /// The day's battles.
  List<MatchRecord> get matches => [
    for (final e in entries)
      if (e is ArchiveMatchEntry) e.match,
  ];

  /// The day's holds.
  List<HoldRecord> get holds => [
    for (final e in entries)
      if (e is ArchiveHoldEntry) e.hold,
  ];

  /// [matches] (newest first, as the server gave them) and [holds] (any
  /// order) by local day, newest first. A battle without a time goes under
  /// the one before it, or first when none. While older battles are still
  /// on the server ([complete] false), holds older than the oldest battle
  /// shown wait, so a later page does not put battles above them.
  static List<ArchiveDay> of(
    List<MatchRecord> matches, {
    List<HoldRecord> holds = const [],
    bool complete = true,
  }) {
    final oldest = [for (final m in matches) ?m.playedAt]
        .fold<DateTime?>(null, (o, t) => o == null || t.isBefore(o) ? t : o);
    final waiting = [
      for (final h in holds)
        if (complete || (oldest != null && !h.endedAt.isBefore(oldest))) h,
    ]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final entries = <ArchiveEntry>[];
    var h = 0;
    for (final match in matches) {
      final at = match.playedAt;
      while (at != null &&
          h < waiting.length &&
          waiting[h].endedAt.isAfter(at)) {
        entries.add(ArchiveHoldEntry(waiting[h++]));
      }
      entries.add(ArchiveMatchEntry(match));
    }
    for (; h < waiting.length; h++) {
      entries.add(ArchiveHoldEntry(waiting[h]));
    }
    final days = <ArchiveDay>[];
    for (final entry in entries) {
      final at = entry.at;
      final date = at == null
          ? (days.isEmpty ? null : days.last.date)
          : DateTime(at.year, at.month, at.day);
      if (days.isNotEmpty && days.last.date == date) {
        days.last.entries.add(entry);
      } else {
        days.add(ArchiveDay(date: date ?? DateTime(0), entries: [entry]));
      }
    }
    return days;
  }
}

/// The 전체 tab's holds of a period (P13): how many, the time held in all,
/// each pose's longest hold of all time, and each pose's holds of the
/// period in time for its trend chart.
class ArchiveHolds {
  const ArchiveHolds({
    required this.count,
    required this.held,
    required this.bests,
    this.trends = const {},
  });

  /// Holds in the period.
  final int count;

  /// Time held in the period, in all.
  final Duration held;

  /// Each pose's longest hold over every kept one, in the poses' order.
  final List<HoldRecord> bests;

  /// Each pose's holds of the period, oldest first, at most [trendCount]
  /// of the newest; a pose without one is left out.
  final Map<HoldPose, List<HoldRecord>> trends;

  /// How many holds a pose's trend chart shows.
  static const trendCount = 10;

  static ArchiveHolds of(
    List<HoldRecord> all,
    StatsPeriod period,
    DateTime now,
  ) {
    final start = const FeedbackStatsCalculator().periodStart(period, now);
    final inPeriod = [
      for (final h in all)
        if ((start == null || !h.endedAt.isBefore(start)) &&
            !h.endedAt.isAfter(now))
          h,
    ];
    final trends = <HoldPose, List<HoldRecord>>{};
    for (final pose in HoldPose.values) {
      final ofPose = [
        for (final h in inPeriod)
          if (h.pose == pose) h,
      ]..sort((a, b) => a.endedAt.compareTo(b.endedAt));
      if (ofPose.isNotEmpty) {
        trends[pose] = ofPose
            .skip(math.max(0, ofPose.length - trendCount))
            .toList();
      }
    }
    return ArchiveHolds(
      count: inPeriod.length,
      held: inPeriod.fold(Duration.zero, (sum, h) => sum + h.held),
      trends: trends,
      bests: [
        for (final pose in HoldPose.values)
          ?all
              .where((h) => h.pose == pose && !h.endedAt.isAfter(now))
              .fold<HoldRecord?>(
                null,
                (best, h) => best == null || h.held > best.held ? h : best,
              ),
      ],
    );
  }
}

/// One battle on the 전체 tab's chart: its score (null when none was kept)
/// and its counted reps.
class ArchivePoint {
  const ArchivePoint({required this.playedAt, required this.reps, this.score});

  final DateTime playedAt;
  final int reps;
  final int? score;
}

/// An exercise's best score of all time, with its reps and day.
class ArchiveBest {
  const ArchiveBest({
    required this.exercise,
    required this.score,
    required this.reps,
    required this.playedAt,
  });

  final ExerciseType exercise;
  final int score;
  final int reps;
  final DateTime playedAt;
}

/// A reject reason and how often it turned a rep down in the period.
class ArchiveIssue {
  const ArchiveIssue({required this.reason, required this.count});

  final RejectReason reason;
  final int count;
}

/// The 전체 tab of one period and exercise (P13, draft C): the battles,
/// reps per battle and best score, the battles in time for the chart, the
/// bests of every exercise and the most frequent reject reasons.
class ArchiveGrowth {
  const ArchiveGrowth({
    required this.period,
    required this.exercise,
    required this.matches,
    required this.repsPerMatch,
    required this.bestScore,
    required this.points,
    required this.bests,
    required this.issues,
  });

  final StatsPeriod period;
  final ExerciseType exercise;

  /// Battles of [exercise] in [period].
  final int matches;

  /// Counted reps per battle; 0 without battles.
  final double repsPerMatch;

  /// The best score in the period; null without a kept score.
  final int? bestScore;

  /// The period's battles of [exercise], oldest first, at most
  /// [chartCount] of the newest.
  final List<ArchivePoint> points;

  /// The best score of each exercise over every battle, in the exercises'
  /// order; an exercise without a kept score is left out.
  final List<ArchiveBest> bests;

  /// The period's reject reasons for [exercise], most first, at most
  /// [issueCount].
  final List<ArchiveIssue> issues;

  /// How many battles the chart shows.
  static const chartCount = 10;

  /// How many reject reasons are listed.
  static const issueCount = 3;

  static const _calculator = FeedbackStatsCalculator();

  /// The values of [period] and [exercise] from every battle [all] (any
  /// order), as of [now].
  static ArchiveGrowth of(
    List<StatsPoint> all,
    StatsPeriod period,
    ExerciseType exercise,
    DateTime now,
  ) {
    final start = _calculator.periodStart(period, now);
    final inPeriod = [
      for (final p in all)
        if (p.exercise == exercise &&
            (start == null || !p.playedAt.isBefore(start)) &&
            !p.playedAt.isAfter(now))
          p,
    ]..sort((a, b) => a.playedAt.compareTo(b.playedAt));
    final reps = inPeriod.fold(0, (sum, p) => sum + p.reps);
    final scores = [for (final p in inPeriod) ?p.score];
    final stats = _calculator.period(inPeriod, period, now);
    final issues = [
      for (final issue in stats.issues)
        if (issue.rejectReason case final reason?)
          ArchiveIssue(reason: reason, count: issue.count),
    ];
    return ArchiveGrowth(
      period: period,
      exercise: exercise,
      matches: inPeriod.length,
      repsPerMatch: inPeriod.isEmpty ? 0 : reps / inPeriod.length,
      bestScore: scores.isEmpty ? null : scores.reduce(math.max),
      points: [
        for (final p in inPeriod.skip(
          math.max(0, inPeriod.length - chartCount),
        ))
          ArchivePoint(playedAt: p.playedAt, reps: p.reps, score: p.score),
      ],
      bests: [for (final e in ExerciseType.values) ?_bestOf(all, e, now)],
      issues: issues.take(issueCount).toList(),
    );
  }

  static ArchiveBest? _bestOf(
    List<StatsPoint> all,
    ExerciseType exercise,
    DateTime now,
  ) {
    StatsPoint? best;
    for (final p in all) {
      final score = p.score;
      if (p.exercise != exercise || score == null || p.playedAt.isAfter(now)) {
        continue;
      }
      // The first battle to reach the best keeps it.
      final kept = best?.score;
      if (kept == null ||
          score > kept ||
          (score == kept && p.playedAt.isBefore(best!.playedAt))) {
        best = p;
      }
    }
    if (best == null) return null;
    return ArchiveBest(
      exercise: exercise,
      score: best.score!,
      reps: best.reps,
      playedAt: best.playedAt,
    );
  }
}

/// Immutable state rendered by the history screen.
class HistoryState {
  const HistoryState({
    this.phase = HistoryPhase.loading,
    this.matches = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.errorMessage,
    this.archive,
    this.statsFailed = false,
    this.points,
    this.filter = ArchiveFilter.all,
    this.period = StatsPeriod.week,
    this.exercise = ExerciseType.pushUp,
    this.holds = const [],
  });

  final HistoryPhase phase;

  /// Battles loaded so far, newest first.
  final List<MatchRecord> matches;

  /// Older battles are left on the server.
  final bool hasMore;

  /// The next page is loading: a spinner shows under the list.
  final bool loadingMore;

  /// The next page failed: a retry shows under the list.
  final bool loadMoreFailed;

  /// Why the first page failed, for the failed phase.
  final String? errorMessage;

  /// The archive's summary (last 7 days, streak, growth, best gains); null
  /// until it loads, when it failed, when the user has no battles (the empty
  /// phase), or without a statistics source.
  final ArchiveStats? archive;

  /// The summary failed to load while the list is shown; [HistoryViewModel.load]
  /// tries again.
  final bool statsFailed;

  /// Every battle for the 전체 tab, as the statistics source gave them;
  /// null until they load or without a source.
  final List<StatsPoint>? points;

  /// The 경기 tab's chip.
  final ArchiveFilter filter;

  /// The 전체 tab's period and exercise.
  final StatsPeriod period;
  final ExerciseType exercise;

  /// The holds kept on the phone, newest first (P13).
  final List<HoldRecord> holds;

  /// The loaded battles [filter] keeps, newest first.
  List<MatchRecord> get filtered => [
    for (final m in matches)
      if (filter.keeps(m)) m,
  ];

  /// [filtered] and, under [ArchiveFilter.keepsHolds], the holds, by local
  /// day.
  List<ArchiveDay> get days => ArchiveDay.of(
    filtered,
    holds: filter.keepsHolds ? holds : const [],
    complete: !hasMore,
  );

  /// How much [match] beat the earlier best score of its exercise; null when
  /// it set no new best, was the exercise's first battle, or the summary is
  /// not loaded.
  int? bestGainOf(MatchRecord match) => archive?.bestGainOf(match);

  HistoryState copyWith({
    HistoryPhase? phase,
    List<MatchRecord>? matches,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    String? errorMessage,
    ArchiveStats? archive,
    bool? statsFailed,
    List<StatsPoint>? points,
    ArchiveFilter? filter,
    StatsPeriod? period,
    ExerciseType? exercise,
    List<HoldRecord>? holds,
  }) => HistoryState(
    phase: phase ?? this.phase,
    matches: matches ?? this.matches,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    errorMessage: errorMessage ?? this.errorMessage,
    archive: archive ?? this.archive,
    statsFailed: statsFailed ?? this.statsFailed,
    points: points ?? this.points,
    filter: filter ?? this.filter,
    period: period ?? this.period,
    exercise: exercise ?? this.exercise,
    holds: holds ?? this.holds,
  );
}

/// Loads the user's battles page by page for the history screen, and the
/// archive's summary over all of them.
///
/// The summary comes from [stats], or from the repository when it is also a
/// [FeedbackStatsSource] (the server one is); without either it stays null.
class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({
    required this._repository,
    this.pageSize = 20,
    FeedbackStatsSource? stats,
    this.holdRecords,
    DateTime Function()? now,
  }) : _stats =
           stats ??
           (_repository is FeedbackStatsSource
               ? _repository as FeedbackStatsSource
               : null),
       _now = now ?? DateTime.now;

  final UserRepository _repository;
  final int pageSize;

  /// The holds kept on the phone (P13); null lists none.
  final HoldRecordStore? holdRecords;
  final FeedbackStatsSource? _stats;
  final DateTime Function() _now;
  static const _calculator = FeedbackStatsCalculator();

  HistoryState _state = const HistoryState();
  String? _cursor;
  bool _fetching = false;

  /// Counts [load] calls, so a summary from an earlier load is dropped.
  int _loads = 0;
  bool _disposed = false;

  HistoryState get state => _state;

  /// Loads the first page, or loads it again after a failure. Does nothing
  /// while a load is running.
  Future<void> load() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    final load = ++_loads;
    var loaded = false;
    final kept = _state;
    _set(_choices(kept, const HistoryState()));
    try {
      final holding = _readHolds();
      final page = await _repository.fetchHistory(limit: pageSize);
      final holds = await holding;
      _cursor = page.nextCursor;
      _set(
        _choices(
          kept,
          HistoryState(
            // Holds alone are a journal too.
            phase: page.items.isEmpty && holds.isEmpty
                ? HistoryPhase.empty
                : HistoryPhase.ready,
            matches: page.items,
            hasMore: page.nextCursor != null,
            holds: holds,
          ),
        ),
      );
      loaded = page.items.isNotEmpty;
    } on Exception catch (e) {
      _set(
        _choices(
          kept,
          HistoryState(phase: HistoryPhase.failed, errorMessage: _message(e)),
        ),
      );
    } finally {
      _fetching = false;
    }
    if (loaded) await _loadArchive(load);
  }

  /// Loads the next older page. Does nothing on the last page or while a
  /// load is running; a failure keeps what is shown and offers a retry.
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (_disposed || _fetching || cursor == null) return;
    if (_state.phase != HistoryPhase.ready) return;
    _fetching = true;
    _set(_state.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await _repository.fetchHistory(
        cursor: cursor,
        limit: pageSize,
      );
      _cursor = page.nextCursor;
      _set(
        _state.copyWith(
          matches: [..._state.matches, ...page.items],
          hasMore: page.nextCursor != null,
          loadingMore: false,
        ),
      );
    } on Exception {
      _set(_state.copyWith(loadingMore: false, loadMoreFailed: true));
    } finally {
      _fetching = false;
    }
  }

  /// Loads the summary after the first page, so the queued uploads the page
  /// sent are in it. A failure keeps the list and sets [HistoryState.statsFailed].
  Future<void> _loadArchive(int load) async {
    final stats = _stats;
    if (stats == null) return;
    try {
      final points = await stats.fetchStatsPoints();
      if (load != _loads) return;
      _set(
        _state.copyWith(
          archive: _calculator.archive(points, _now()),
          statsFailed: false,
          points: points,
        ),
      );
    } on Exception {
      if (load == _loads) _set(_state.copyWith(statsFailed: true));
    }
  }

  /// Lists only the battles [filter] keeps on the 경기 tab.
  void setFilter(ArchiveFilter filter) {
    if (filter != _state.filter) _set(_state.copyWith(filter: filter));
  }

  /// Shows [period] on the 전체 tab.
  void setPeriod(StatsPeriod period) {
    if (period != _state.period) _set(_state.copyWith(period: period));
  }

  /// Shows [exercise] on the 전체 tab.
  void setExercise(ExerciseType exercise) {
    if (exercise != _state.exercise) _set(_state.copyWith(exercise: exercise));
  }

  /// The 전체 tab's values for the chosen period and exercise; null until
  /// the battles load.
  ArchiveGrowth? get growth {
    final points = _state.points;
    if (points == null) return null;
    return ArchiveGrowth.of(points, _state.period, _state.exercise, _now());
  }

  /// The kept holds, newest first; none when the store fails.
  Future<List<HoldRecord>> _readHolds() async {
    final store = holdRecords;
    if (store == null) return const [];
    try {
      return await store.list();
    } on Object {
      return const [];
    }
  }

  /// The 전체 tab's holds of the chosen period; null without any hold.
  ArchiveHolds? get holdSummary {
    final holds = _state.holds;
    if (holds.isEmpty) return null;
    return ArchiveHolds.of(holds, _state.period, _now());
  }

  /// [next] with the user's chip, period and exercise from [kept].
  static HistoryState _choices(HistoryState kept, HistoryState next) =>
      next.copyWith(
        filter: kept.filter,
        period: kept.period,
        exercise: kept.exercise,
      );

  static String _message(Exception e) =>
      e is ApiException ? e.message : genericErrorMessage;

  void _set(HistoryState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
