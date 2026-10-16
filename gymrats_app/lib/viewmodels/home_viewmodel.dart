import 'package:flutter/foundation.dart';

import '../models/form_report.dart';
import '../models/user_profile.dart';
import '../services/feedback/form_report_store.dart';
import '../services/user/user_repository.dart';

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
    this.latestForm,
  });

  final HomePhase phase;

  /// The last loaded profile; null until a load succeeds.
  final UserProfile? profile;

  /// The newest form report saved on this device; null when there is none.
  final FormReport? latestForm;

  HomeState copyWith({
    HomePhase? phase,
    UserProfile? profile,
    FormReport? latestForm,
    bool clearLatestForm = false,
  }) => HomeState(
    phase: phase ?? this.phase,
    profile: profile ?? this.profile,
    latestForm: clearLatestForm ? null : latestForm ?? this.latestForm,
  );
}

/// Loads the user's profile, and the latest form report, for the home
/// screen.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required this._repository, this._formReports});

  final UserRepository _repository;
  final FormReportStore? _formReports;

  HomeState _state = const HomeState();
  bool _fetching = false;
  bool _disposed = false;

  HomeState get state => _state;

  /// Fetches the profile. Does nothing while a fetch is running.
  ///
  /// The first load shows the loading state, and the failed state on an
  /// [Exception] from the repository. A reload keeps the profile on screen
  /// until the new one arrives, and keeps it if the reload fails. The form
  /// report is extra: failing to read it changes nothing else.
  Future<void> load() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    final reloading = _state.profile != null;
    if (!reloading) _setState(_state.copyWith(phase: HomePhase.loading));
    try {
      final profile = await _repository.fetchProfile();
      _setState(_state.copyWith(phase: HomePhase.ready, profile: profile));
    } on Exception {
      if (!reloading) _setState(_state.copyWith(phase: HomePhase.failed));
    } finally {
      _fetching = false;
    }
    await _loadLatestForm();
  }

  Future<void> _loadLatestForm() async {
    final store = _formReports;
    if (store == null) return;
    try {
      final latest = await store.latest();
      _setState(
        _state.copyWith(latestForm: latest, clearLatestForm: latest == null),
      );
    } on Exception {
      // The home screen shows no feedback entry.
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
