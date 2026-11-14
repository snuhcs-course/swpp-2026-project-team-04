import 'package:flutter/foundation.dart';

import '../models/feedback_stats.dart';
import '../models/match_record.dart';
import '../services/api/api_client.dart';
import '../services/feedback/feedback_stats.dart';
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
  }) => HistoryState(
    phase: phase ?? this.phase,
    matches: matches ?? this.matches,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    errorMessage: errorMessage ?? this.errorMessage,
    archive: archive ?? this.archive,
    statsFailed: statsFailed ?? this.statsFailed,
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
    DateTime Function()? now,
  }) : _stats =
           stats ??
           (_repository is FeedbackStatsSource
               ? _repository as FeedbackStatsSource
               : null),
       _now = now ?? DateTime.now;

  final UserRepository _repository;
  final int pageSize;
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
    _set(const HistoryState());
    try {
      final page = await _repository.fetchHistory(limit: pageSize);
      _cursor = page.nextCursor;
      _set(
        HistoryState(
          phase: page.items.isEmpty ? HistoryPhase.empty : HistoryPhase.ready,
          matches: page.items,
          hasMore: page.nextCursor != null,
        ),
      );
      loaded = page.items.isNotEmpty;
    } on Exception catch (e) {
      _set(HistoryState(phase: HistoryPhase.failed, errorMessage: _message(e)));
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
        ),
      );
    } on Exception {
      if (load == _loads) _set(_state.copyWith(statsFailed: true));
    }
  }

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
