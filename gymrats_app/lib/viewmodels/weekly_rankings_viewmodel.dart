import 'package:flutter/foundation.dart';

import '../models/exercise_type.dart';
import '../services/api/api_client.dart';
import '../services/rankings/rankings_repository.dart';

/// The weekly rankings screen (P11): this week's global ranking, or the same
/// points among me and my friends, of push-ups or of squats. Each ranking is
/// read once when first shown and kept; [retry] reads the shown one again.
class WeeklyRankingsViewModel extends ChangeNotifier {
  WeeklyRankingsViewModel({required this._repository});

  final RankingsRepository _repository;

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
  Future<void> load() => _load(_shown);

  /// Shows the [next] scope of the shown exercise, reading it the first time.
  Future<void> select(RankingScope next) async {
    if (next == scope) return;
    scope = next;
    _notify();
    await _load(_shown);
  }

  /// Shows the [next] exercise in the shown scope, reading it the first time.
  Future<void> selectExercise(ExerciseType next) async {
    if (next == exercise) return;
    exercise = next;
    _notify();
    await _load(_shown);
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
      _rankings[which] = await _repository.fetchWeekly(which.$1, which.$2);
    } on Object catch (error) {
      _errors[which] = error is ApiException
          ? error.message
          : '랭킹을 불러오지 못했어요. 다시 시도해 주세요.';
    } finally {
      _loading.remove(which);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
