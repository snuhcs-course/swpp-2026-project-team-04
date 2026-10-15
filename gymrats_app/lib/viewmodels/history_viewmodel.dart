import 'package:flutter/foundation.dart';

import '../models/match_record.dart';
import '../services/api/api_client.dart';
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

  HistoryState copyWith({
    HistoryPhase? phase,
    List<MatchRecord>? matches,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    String? errorMessage,
  }) => HistoryState(
    phase: phase ?? this.phase,
    matches: matches ?? this.matches,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

/// Loads the user's battles page by page for the history screen.
class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({required this._repository, this.pageSize = 20});

  final UserRepository _repository;
  final int pageSize;

  HistoryState _state = const HistoryState();
  String? _cursor;
  bool _fetching = false;
  bool _disposed = false;

  HistoryState get state => _state;

  /// Loads the first page, or loads it again after a failure. Does nothing
  /// while a load is running.
  Future<void> load() async {
    if (_disposed || _fetching) return;
    _fetching = true;
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
    } on Exception catch (e) {
      _set(HistoryState(phase: HistoryPhase.failed, errorMessage: _message(e)));
    } finally {
      _fetching = false;
    }
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
