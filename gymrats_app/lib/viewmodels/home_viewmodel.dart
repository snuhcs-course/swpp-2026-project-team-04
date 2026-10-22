import 'package:flutter/foundation.dart';

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
    this.errorMessage,
  });

  final HomePhase phase;

  /// The last loaded profile; null until a load succeeds.
  final UserProfile? profile;

  /// Why the load failed, e.g. no network; null for the default message.
  final String? errorMessage;

  HomeState copyWith({
    HomePhase? phase,
    UserProfile? profile,
    String? errorMessage,
  }) => HomeState(
    phase: phase ?? this.phase,
    profile: profile ?? this.profile,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

/// Loads the user's profile for the home screen.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required this._repository});

  final UserRepository _repository;

  HomeState _state = const HomeState();
  bool _fetching = false;
  bool _disposed = false;

  HomeState get state => _state;

  /// Fetches the profile. Does nothing while a fetch is running.
  ///
  /// The first load shows the loading state, and the failed state on an
  /// [Exception] from the repository. A reload keeps the profile on screen
  /// until the new one arrives, and keeps it if the reload fails.
  Future<void> load() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    final reloading = _state.profile != null;
    if (!reloading) _setState(_state.copyWith(phase: HomePhase.loading));
    try {
      final profile = await _repository.fetchProfile();
      _setState(_state.copyWith(phase: HomePhase.ready, profile: profile));
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
