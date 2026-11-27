import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/exercise_type.dart';
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
