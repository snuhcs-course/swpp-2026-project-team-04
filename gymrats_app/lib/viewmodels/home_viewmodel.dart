import 'package:flutter/foundation.dart';

import '../models/match_record.dart';
import '../models/user_profile.dart';
import '../services/api/api_client.dart';
import '../services/user/user_repository.dart';
import 'login_viewmodel.dart';

/// What the home screen is showing.
enum HomePhase {
  /// Fetching the profile.
  loading,

  /// The profile is shown.
  ready,

  /// Loading failed; the user can retry.
  failed,
}

/// Immutable state rendered by the home screen.
class HomeState {
  const HomeState({
    this.phase = HomePhase.loading,
    this.profile,
    this.recent = const [],
    this.recentIsFallback = false,
    this.errorMessage,
  });

  final HomePhase phase;

  /// The last loaded profile; null until a load succeeds.
  final UserProfile? profile;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Up to [HomeViewModel.recentCount] newest battles, newest first, each
  /// with its one-line feedback.
  final List<MatchRecord> recent;

  /// [recent] is only the profile's latest battle, which carries no
  /// feedback, because the recent battles could not be loaded. Its row then
  /// shows no feedback line rather than a wrong "피드백 없음".
  final bool recentIsFallback;

  /// Why the load failed, e.g. no network; null for the default message.
  final String? errorMessage;

  HomeState copyWith({
    HomePhase? phase,
    UserProfile? profile,
    List<MatchRecord>? recent,
    bool? recentIsFallback,
    String? errorMessage,
  }) => HomeState(
    phase: phase ?? this.phase,
    profile: profile ?? this.profile,
    recent: recent ?? this.recent,
    recentIsFallback: recentIsFallback ?? this.recentIsFallback,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

/// Loads the user's profile and recent battles for the home screen.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required this._repository});

  /// How many battles "최근 경기" shows.
  static const recentCount = 3;

  final UserRepository _repository;

  HomeState _state = const HomeState();
  bool _fetching = false;
  bool _disposed = false;

  HomeState get state => _state;

  /// Fetches the profile. Does nothing while a fetch is running.
  ///
  /// The first load shows the loading state, and the failed state on an
  /// [Exception] from the repository. A reload keeps the profile on screen
  /// until the new one arrives, and keeps it if the reload fails. The
  /// profile load sends queued battles first, so the recent battles are
  /// read after it and include them.
  Future<void> load() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    final reloading = _state.profile != null;
    if (!reloading) _setState(_state.copyWith(phase: HomePhase.loading));
    try {
      final profile = await _repository.fetchProfile();
      final (recent, fallback) = await _loadRecent(profile);
      _setState(
        _state.copyWith(
          phase: HomePhase.ready,
          profile: profile,
          recent: recent,
          recentIsFallback: fallback,
        ),
      );
    } on Exception catch (e) {
      if (!reloading) {
        _setState(
          _state.copyWith(
            phase: HomePhase.failed,
            errorMessage: e is ApiException ? e.message : genericErrorMessage,
          ),
        );
      }
    } finally {
      _fetching = false;
    }
  }

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// The recent battles; when they cannot be loaded, the profile's latest
  /// battle, so home still shows something.
  Future<(List<MatchRecord>, bool)> _loadRecent(UserProfile profile) async {
    try {
      return (await _repository.fetchRecent(limit: recentCount), false);
    } on Exception {
      return (<MatchRecord>[?profile.lastMatch], true);
    }
  }

  void _setState(HomeState state) {
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
