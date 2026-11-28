import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/battle_result.dart';
import '../models/exercise_type.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import '../models/ranking_ladder.dart';
import '../services/rankings/rankings_repository.dart';

/// The rank ladder of an online battle's report (A15): reads this week's
/// global ranking of the battle's exercise after the battle, keeps it once
/// it has the battle, and gives the victory scene its path, its ladder and
/// the rank chip the report keeps.
///
/// The battle server sends the result before it stores it, so the first
/// ranking read may not have the battle yet: [load] reads it at once and
/// again 0.4, 1, 2 and 4 seconds after, and takes no answer after 6 seconds.
/// Nothing waits for it: the report opens and the scene plays meanwhile.
/// The scene calls [decide] at [RankingLadder.decideMs]; a ranking
/// confirmed only after that shows the chip alone. Every rank given is the
/// server's (the PM's condition, 2026-11-29).
class RankingLadderViewModel extends ChangeNotifier {
  RankingLadderViewModel({
    required this._repository,
    required this.exercise,
    required this.ranked,
    required this.before,
    required this.points,
    Duration Function()? elapsed,
  }) : _elapsed = elapsed ?? _stopwatch();

  static Duration Function() _stopwatch() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  /// The ladder of [result], a battle just played: its exercise, whether it
  /// counts, the ranking read before it, and its points.
  factory RankingLadderViewModel.of(
    BattleResult result, {
    required RankingsRepository repository,
    Duration Function()? elapsed,
  }) => RankingLadderViewModel(
    repository: repository,
    exercise: result.matchup.exercise,
    ranked: result.ranked,
    before: result.rankingBefore,
    points: pointsOf(result),
    elapsed: elapsed,
  );

  final RankingsRepository _repository;

  /// A running clock, to drop answers that come too long after [load].
  final Duration Function() _elapsed;

  /// [_elapsed] when [load] started.
  Duration? _loadedAt;

  bool get _tooLate => _loadedAt == null || _elapsed() - _loadedAt! >= giveUp;

  final ExerciseType exercise;

  /// Whether the battle counts in the weekly ranking: an online battle
  /// that is not a friend battle.
  final bool ranked;

  /// The ranking read when the battle started; null when it failed or had
  /// not come when the report opened.
  final RankingSnapshot? before;

  /// The battle's weekly points.
  final int points;

  /// When the ranking is read again if it does not have the battle yet,
  /// after the first read at once.
  static const retries = [
    Duration(milliseconds: 400),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  /// No answer is taken after this.
  static const giveUp = Duration(seconds: 6);

  final _timers = <Timer>[];
  RankingSnapshot? _after;
  LadderPath? _path;
  RankingLadder? _ladder;
  bool _disposed = false;

  /// The ranking after the battle, once it has the battle; null before.
  RankingSnapshot? get after => _after;

  /// Whether the battle has the points layer at all: a ranked battle with a
  /// ranking from before it and points.
  bool get _layered => ranked && before != null && points > 0;

  /// The scene's path once [decide] chose it; null before.
  LadderPath? get path => _path;

  /// Chooses the scene's path from what has come by now, once, and keeps
  /// it: the scene calls it at [RankingLadder.decideMs], or at once when it
  /// does not play (skipped, reduced motion). Later calls give the same.
  LadderPath decide() {
    if (_path case final chosen?) return chosen;
    final chosen = RankingLadder.pathOf(
      ranked: ranked,
      before: before,
      after: _after,
      points: points,
    );
    if (chosen == LadderPath.confirmed) {
      _ladder = RankingLadder.of(
        before: before!,
        after: _after!,
        points: points,
      );
    }
    return _path = chosen;
  }

  /// Whether the scene holds its big moment for the ladder: the path was
  /// chosen and is confirmed.
  bool get holds => _path == LadderPath.confirmed;

  /// The ladder to play, made once when the path was chosen confirmed;
  /// null otherwise.
  RankingLadder? get ladder => _ladder;

  /// The rank chip; null without a confirmed ranking (late, until it
  /// comes) and for a battle without the points layer. It does not choose
  /// the path.
  RankChipValues? get chip => switch (_after) {
    final after? when _layered => RankingLadder.chipOf(after, points),
    _ => null,
  };

  /// Starts reading the ranking, once; returns at once. A battle without
  /// the points layer reads nothing.
  void load() {
    if (_loadedAt != null || _disposed) return;
    _loadedAt = _elapsed();
    if (!_layered) return;
    unawaited(_read());
    for (final wait in retries) {
      _timers.add(Timer(wait, () => unawaited(_read())));
    }
    _timers.add(Timer(giveUp, _stop));
  }

  Future<void> _read() async {
    if (_after != null || _disposed || _tooLate) return;
    final WeeklyRanking ranking;
    try {
      ranking = await _repository.fetchWeekly(RankingScope.global, exercise);
    } on Object {
      return;
    }
    if (_after != null || _disposed || _tooLate) return;
    final snapshot = snapshotOf(ranking);
    if (!RankingLadder.confirms(before!, snapshot)) return;
    _after = snapshot;
    _stop();
    notifyListeners();
  }

  void _stop() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    super.dispose();
  }

  /// The ranking before a battle of [exercise], read when it starts: this
  /// week's global one; null when it cannot be read.
  static Future<RankingSnapshot?> fetchBefore(
    RankingsRepository repository,
    ExerciseType exercise,
  ) async {
    try {
      return snapshotOf(
        await repository.fetchWeekly(RankingScope.global, exercise),
      );
    } on Object {
      return null;
    }
  }

  /// [ranking] as the ladder reads it.
  static RankingSnapshot snapshotOf(WeeklyRanking ranking) => RankingSnapshot(
    entries: [for (final entry in ranking.entries) _entryOf(entry)],
    me: switch (ranking.me) {
      final me? => _entryOf(me),
      null => null,
    },
  );

  static LadderEntry _entryOf(RankingEntry entry) => (
    userId: entry.userId,
    nickname: entry.nickname,
    points: entry.points,
    rank: entry.rank,
    battles: entry.battles,
  );

  /// The battle's weekly points as the server counts them ([RankingPoints]):
  /// a KO win 10, another win 5 (by time or because the opponent left), a
  /// draw 3, a loss 1, and 0 when my connection stayed down (the server's
  /// forfeit and disconnect timeout).
  static int pointsOf(BattleResult result) => switch (result.outcome) {
    MatchOutcome.win when result.end == GameEnd.ko => RankingPoints.koWin,
    MatchOutcome.win => RankingPoints.win,
    MatchOutcome.draw => RankingPoints.draw,
    MatchOutcome.lose
        when result.departure == BattleDeparture.myConnectionLost =>
      RankingPoints.leftBattle,
    MatchOutcome.lose => RankingPoints.loss,
  };
}
