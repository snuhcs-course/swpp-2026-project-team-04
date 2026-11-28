import 'package:flutter/foundation.dart';

import '../services/api/api_client.dart';
import '../services/user/user_repository.dart';
import 'auth_viewmodel.dart';
import 'body_info_viewmodel.dart';
import 'login_viewmodel.dart';

/// What the 키·몸무게 settings page shows besides the typed text.
class BodySettingsState {
  const BodySettingsState({
    this.loading = true,
    this.heightCm,
    this.weightKg,
    this.heightError,
    this.weightError,
    this.consentError,
    this.formError,
    this.saving = false,
    this.saved = false,
  });

  /// The saved values are being read.
  final bool loading;

  /// The values saved now; null when none was given (or could not be read).
  final double? heightCm;
  final double? weightKg;

  /// Shown under each field or the consent box; null when it is fine.
  final String? heightError;
  final String? weightError;
  final String? consentError;

  /// Shown above the button, e.g. no network.
  final String? formError;

  /// A save is running: the button does nothing.
  final bool saving;

  /// The last save went through.
  final bool saved;

  /// Whether the user had given both values before.
  bool get hasValues => heightCm != null && weightKg != null;

  BodySettingsState copyWith({
    bool? loading,
    double? heightCm,
    double? weightKg,
    String? heightError,
    String? weightError,
    String? consentError,
    String? formError,
    bool? saving,
    bool? saved,
  }) => BodySettingsState(
    loading: loading ?? this.loading,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    heightError: heightError,
    weightError: weightError,
    consentError: consentError,
    formError: formError,
    saving: saving ?? false,
    saved: saved ?? false,
  );
}

/// 키·몸무게 in settings (PM, 2026-11-29): the height and weight given at
/// sign-up, read from the profile ([load]) and saved again with consent
/// ([save]) through the same server call as the sign-up step, with its
/// rules ([BodyInfoRules]).
class BodySettingsViewModel extends ChangeNotifier {
  BodySettingsViewModel({required this._profiles, required this._auth});

  final UserRepository _profiles;
  final AuthViewModel _auth;

  BodySettingsState _state = const BodySettingsState();
  bool _disposed = false;

  BodySettingsState get state => _state;

  /// The saved values, as the fields' starting text: "175" or "72.5".
  static String textOf(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  /// Reads the saved values; a failed read leaves the fields empty.
  Future<void> load() async {
    try {
      final profile = await _profiles.fetchProfile();
      _set(
        BodySettingsState(
          loading: false,
          heightCm: profile.heightCm,
          weightKg: profile.weightKg,
        ),
      );
    } on Exception {
      _set(const BodySettingsState(loading: false));
    }
  }

  /// Clears the errors once the user changes something.
  void edited() {
    if (_state.formError == null &&
        _state.heightError == null &&
        _state.weightError == null &&
        _state.consentError == null &&
        !_state.saved) {
      return;
    }
    _set(_state.copyWith(loading: _state.loading));
  }

  /// Saves both values when they are in range and the user agreed. True on
  /// success.
  Future<bool> save({
    required String height,
    required String weight,
    required bool consent,
  }) async {
    if (_state.saving || _state.loading) return false;
    final heightError = BodyInfoRules.height(height);
    final weightError = BodyInfoRules.weight(weight);
    final consentError = BodyInfoRules.consent(consent);
    if (heightError != null || weightError != null || consentError != null) {
      _set(
        _state.copyWith(
          heightError: heightError,
          weightError: weightError,
          consentError: consentError,
        ),
      );
      return false;
    }
    _set(_state.copyWith(saving: true));
    final cm = BodyInfoRules.parse(height)!, kg = BodyInfoRules.parse(weight)!;
    try {
      await _auth.saveBodyInfo(heightCm: cm, weightKg: kg);
      _set(_state.copyWith(heightCm: cm, weightKg: kg, saved: true));
      return true;
    } on ApiException catch (e) {
      _set(_state.copyWith(formError: e.message));
    } on Exception {
      _set(_state.copyWith(formError: genericErrorMessage));
    }
    return false;
  }

  void _set(BodySettingsState state) {
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
