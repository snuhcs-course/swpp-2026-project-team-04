import 'package:flutter/foundation.dart';

import '../models/exercise_type.dart';
import '../models/feedback_stats.dart';
import '../services/api/api_client.dart';
import '../services/feedback/feedback_stats.dart';
import 'login_viewmodel.dart';

/// What the statistics screen is showing.
enum FeedbackStatsPhase {
  /// Fetching the battles.
  loading,

  /// The statistics are shown (a period without battles shows zeros).
  ready,

  /// The battles failed to load; the user can retry.
  failed,
}

/// Immutable state rendered by the statistics screen.
class FeedbackStatsState {
  const FeedbackStatsState({
    this.phase = FeedbackStatsPhase.loading,
    this.period = StatsPeriod.week,
    this.exercise,
    this.stats,
    this.errorMessage,
  });

  final FeedbackStatsPhase phase;

  /// The chosen period tab.
  final StatsPeriod period;

  /// Only this exercise's battles; both exercises when null.
  final ExerciseType? exercise;

  /// The values of [period] and [exercise]; null until loaded.
  final PeriodStats? stats;

  /// Why loading failed, for the failed phase.
  final String? errorMessage;
}

/// The statistics of UAT-4 AC3: average counted reps, reps by date and form
/// issue counts for every record, this month or this week.
///
/// Loads every battle once; switching the period or the exercise is computed
/// on the phone without another request.
class FeedbackStatsViewModel extends ChangeNotifier {
  FeedbackStatsViewModel({
    required this._source,
    DateTime Function()? now,
    StatsPeriod period = StatsPeriod.week,
    ExerciseType? exercise,
  }) : _now = now ?? DateTime.now,
       _state = FeedbackStatsState(period: period, exercise: exercise);

  final FeedbackStatsSource _source;
  final DateTime Function() _now;
  static const _calculator = FeedbackStatsCalculator();

  FeedbackStatsState _state;
  List<StatsPoint> _points = const [];
  bool _fetching = false;
  bool _disposed = false;

  FeedbackStatsState get state => _state;

  /// Loads the battles, or loads them again after a failure. Does nothing
  /// while a load is running.
  Future<void> load() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    _set(_with(phase: FeedbackStatsPhase.loading));
    try {
      _points = await _source.fetchStatsPoints();
      _set(_computed());
    } on Exception catch (e) {
      _set(
        _with(
          phase: FeedbackStatsPhase.failed,
          errorMessage: e is ApiException ? e.message : genericErrorMessage,
        ),
      );
    } finally {
      _fetching = false;
    }
  }

  /// Shows [period]'s values.
  void selectPeriod(StatsPeriod period) {
    if (period == _state.period) return;
    _set(_recomputed(period: period, exercise: _state.exercise));
  }

  /// Shows only [exercise]'s battles, or both when null.
  void selectExercise(ExerciseType? exercise) {
    if (exercise == _state.exercise) return;
    _set(_recomputed(period: _state.period, exercise: exercise));
  }

  FeedbackStatsState _recomputed({
    required StatsPeriod period,
    required ExerciseType? exercise,
  }) {
    final next = FeedbackStatsState(
      phase: _state.phase,
      period: period,
      exercise: exercise,
      errorMessage: _state.errorMessage,
    );
    if (next.phase != FeedbackStatsPhase.ready) return next;
    _state = next;
    return _computed();
  }

  FeedbackStatsState _computed() {
    final exercise = _state.exercise;
    final points = exercise == null
        ? _points
        : [
            for (final p in _points)
              if (p.exercise == exercise) p,
          ];
    return FeedbackStatsState(
      phase: FeedbackStatsPhase.ready,
      period: _state.period,
      exercise: exercise,
      stats: _calculator.period(points, _state.period, _now()),
    );
  }

  FeedbackStatsState _with({
    required FeedbackStatsPhase phase,
    String? errorMessage,
  }) => FeedbackStatsState(
    phase: phase,
    period: _state.period,
    exercise: _state.exercise,
    errorMessage: errorMessage,
  );

  void _set(FeedbackStatsState state) {
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
