import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/exercise_type.dart';
import '../models/ranking_standing.dart';
import '../services/api/api_client.dart';
import '../services/rankings/rankings_repository.dart';

/// The weekly rankings screen (P11): this week's global ranking, or the same
/// points among me and my friends, of push-ups or of squats. Each ranking is
/// read once when first shown and kept until its week ends; [retry] reads the
/// shown one again.
class WeeklyRankingsViewModel extends ChangeNotifier {
  WeeklyRankingsViewModel({
    required this._repository,
    this._now = DateTime.now,
  });

  final RankingsRepository _repository;
  final DateTime Function() _now;

  /// Reads the shown ranking again when its week ends on screen.
  Timer? _weekEnd;

  RankingScope scope = RankingScope.global;
  ExerciseType exercise = ExerciseType.pushUp;
  final _rankings = <RankingKey, WeeklyRanking>{};
  final _errors = <RankingKey, String>{};
  final _loading = <RankingKey>{};
  bool _disposed = false;

  RankingKey get _shown => (scope, exercise);

  /// The shown ranking's week; null until read.
  WeeklyRanking? get ranking => _rankings[_shown];

  /// Why the shown ranking could not be read; null otherwise.
  String? get error => _errors[_shown];

  bool get loading => _loading.contains(_shown);

  // The screen's words for the shown ranking (A13 spec 3.6), worked out in
  // `ranking_standing.dart` with this view model's clock.

  bool get _friends => scope == RankingScope.friends;

  /// The banner's week, "11월 4주차"; null until read.
  String? get weekName => switch (ranking) {
    final shown? => RankingWeek.name(shown.weekStart),
    null => null,
  };

  /// The banner's flag, "1일 9시간 남음" now; null until read.
  String? get timeLeft => switch (ranking) {
    final shown? => RankingWeek.timeLeft(shown.weekEnd, _now()),
    null => null,
  };

  /// How much of the shown week has gone by now, 0 to 1; 0 until read.
  double get weekProgress => switch (ranking) {
    final shown? => RankingWeek.progress(
      shown.weekStart,
      shown.weekEnd,
      _now(),
    ),
    null => 0,
  };

  /// My row in the shown ranking: the server's for everyone (also below the
  /// list), mine among the rows for friends; null before my first battle
  /// of the week in the global ranking, or until read.
  RankingEntry? get myEntry {
    final shown = ranking;
    if (shown == null) return null;
    return _friends
        ? shown.entries.where((entry) => entry.isMe).firstOrNull
        : shown.me;
  }

  /// My card's rank, points and goal line; null until read.
  RankingStanding? get standing {
    final shown = ranking;
    if (shown == null) return null;
    return RankingStanding.of(
      me: _row(shown.me),
      entries: [for (final entry in shown.entries) ?_row(entry)],
      friends: _friends,
    );
  }

  /// My name on my card: my row's, else [accountNickname] (no global row
  /// before my first battle), else '나'.
  String myName(String? accountNickname) =>
      myEntry?.nickname ?? accountNickname ?? '나';

  /// My record this week, "4전 2승 · KO 1" or '이번 주 기록 없음'.
  String get myRecord => recordOf(myEntry);

  /// [entry]'s record as a row writes it; '이번 주 기록 없음' for none.
  static String recordOf(RankingEntry? entry) => RankingWeek.record(
    battles: entry?.battles ?? 0,
    wins: entry?.wins ?? 0,
    koWins: entry?.koWins ?? 0,
  );

  /// The friends tab with nobody but me: the card asking for friends
  /// instead of a list.
  bool get noFriends => _friends && (ranking?.entries.length ?? 0) < 2;

  /// The list's name, 'TOP 50' or '나와 친구 n명'; null until read.
  String? get listTitle => switch (ranking) {
    final shown? => RankingList.title(
      friends: _friends,
      count: shown.entries.length,
    ),
    null => null,
  };

  /// The note right of the list's name; null until read.
  String? get listNote => switch (ranking) {
    final shown? => RankingList.note(
      friends: _friends,
      me: _row(shown.me),
      entries: [for (final entry in shown.entries) ?_row(entry)],
    ),
    null => null,
  };

  static StandingRow? _row(RankingEntry? entry) => switch (entry) {
    final e? => (
      rank: e.rank,
      points: e.points,
      battles: e.battles,
      isMe: e.isMe,
    ),
    null => null,
  };

  /// Reads the shown ranking unless it is read or being read.
  Future<void> load() {
    _dropEnded();
    return _load(_shown);
  }

  /// Checks the week again, e.g. when the app comes back to the front: a
  /// ranking whose week has ended is dropped and the shown one read anew.
  Future<void> refreshIfWeekEnded() async {
    if (!_dropEnded()) {
      // Early by this clock (e.g. it was set back): wait again.
      _watchWeekEnd();
      return;
    }
    _notify();
    await _load(_shown);
  }

  /// Shows the [next] scope of the shown exercise, reading it the first time.
  Future<void> select(RankingScope next) async {
    if (next == scope) return;
    scope = next;
    _dropEnded();
    _notify();
    await _load(_shown);
    // Also for a tab kept from before, which _load does not read.
    _watchWeekEnd();
  }

  /// Shows the [next] exercise in the shown scope, reading it the first time.
  Future<void> selectExercise(ExerciseType next) async {
    if (next == exercise) return;
    exercise = next;
    _dropEnded();
    _notify();
    await _load(_shown);
    // Also for a tab kept from before, which _load does not read.
    _watchWeekEnd();
  }

  /// Reads the shown ranking again after an error.
  Future<void> retry() {
    _rankings.remove(_shown);
    return _load(_shown);
  }

  Future<void> _load(RankingKey which) async {
    if (_loading.contains(which) || _rankings.containsKey(which)) return;
    _loading.add(which);
    _errors.remove(which);
    _notify();
    try {
      final asked = _now();
      var answer = await _repository.fetchWeekly(which.$1, which.$2);
      if (answer.weekEnd.isAfter(asked) && !answer.weekEnd.isAfter(_now())) {
        // The week ended while this was read: read the new one, once. (Asked
        // after its end, an old week means the phone's clock is ahead.)
        answer = await _repository.fetchWeekly(which.$1, which.$2);
      }
      _rankings[which] = answer;
    } on Object catch (error) {
      _errors[which] = error is ApiException
          ? error.message
          : '랭킹을 불러오지 못했어요. 다시 시도해 주세요.';
    } finally {
      _loading.remove(which);
      _watchWeekEnd();
      _notify();
    }
  }

  /// Drops every kept ranking whose week has ended; true when the shown one
  /// was among them.
  bool _dropEnded() {
    final now = _now();
    final ended = [
      for (final MapEntry(:key, :value) in _rankings.entries)
        if (!value.weekEnd.isAfter(now)) key,
    ];
    ended.forEach(_rankings.remove);
    return ended.contains(_shown);
  }

  void _watchWeekEnd() {
    _weekEnd?.cancel();
    final shown = ranking;
    if (shown == null || _disposed) return;
    final left = shown.weekEnd.difference(_now());
    // A week already over here (the phone's clock ahead of the server's) is
    // not read again and again; choosing a tab or coming back reads it.
    if (left <= Duration.zero) return;
    _weekEnd = Timer(left, () => unawaited(refreshIfWeekEnded()));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _weekEnd?.cancel();
    super.dispose();
  }
}
