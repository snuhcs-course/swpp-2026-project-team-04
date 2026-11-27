import 'package:flutter/foundation.dart';

import '../services/api/api_client.dart';
import '../services/rankings/rankings_repository.dart';

/// The weekly rankings screen (P11): this week's global ranking, or the same
/// points among me and my friends. Each scope is read once when first shown
/// and kept; [retry] reads the shown one again.
class WeeklyRankingsViewModel extends ChangeNotifier {
  WeeklyRankingsViewModel({required this._repository});

  final RankingsRepository _repository;

  RankingScope scope = RankingScope.global;
  final _rankings = <RankingScope, WeeklyRanking>{};
  final _errors = <RankingScope, String>{};
  final _loading = <RankingScope>{};
  bool _disposed = false;

  /// The shown scope's week; null until read.
  WeeklyRanking? get ranking => _rankings[scope];

  /// Why the shown scope could not be read; null otherwise.
  String? get error => _errors[scope];

  bool get loading => _loading.contains(scope);

  /// Reads the shown scope unless it is read or being read.
  Future<void> load() => _load(scope);

  /// Shows [next], reading it the first time.
  Future<void> select(RankingScope next) async {
    if (next == scope) return;
    scope = next;
    _notify();
    await _load(next);
  }

  /// Reads the shown scope again after an error.
  Future<void> retry() {
    _rankings.remove(scope);
    return _load(scope);
  }

  Future<void> _load(RankingScope which) async {
    if (_loading.contains(which) || _rankings.containsKey(which)) return;
    _loading.add(which);
    _errors.remove(which);
    _notify();
    try {
      _rankings[which] = await _repository.fetchWeekly(which);
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
