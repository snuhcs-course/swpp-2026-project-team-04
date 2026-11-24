import 'package:flutter/foundation.dart';

import '../services/api/api_client.dart';
import 'auth_viewmodel.dart';
import 'login_viewmodel.dart';

/// What the body info step shows besides the typed text.
class BodyInfoState {
  const BodyInfoState({
    this.heightError,
    this.weightError,
    this.consentError,
    this.formError,
    this.submitting = false,
  });

  /// Shown under each field or the consent box; null when it is fine.
  final String? heightError;
  final String? weightError;
  final String? consentError;

  /// Shown above the buttons, e.g. no network.
  final String? formError;

  /// A save is running: both buttons do nothing.
  final bool submitting;

  bool get hasFieldError =>
      heightError != null || weightError != null || consentError != null;
}

/// Value rules, the same as the server's.
abstract final class BodyInfoRules {
  static const heightMin = 100.0;
  static const heightMax = 250.0;
  static const weightMin = 20.0;
  static const weightMax = 300.0;

  /// The number typed, e.g. "175" or "72.5"; null when it is not one.
  static double? parse(String value) {
    final number = double.tryParse(value.trim().replaceAll(',', '.'));
    return number == null || !number.isFinite ? null : number;
  }

  static String? height(String value) {
    if (value.trim().isEmpty) return '키를 입력해 주세요.';
    final cm = parse(value);
    if (cm == null || cm < heightMin || cm > heightMax) {
      return '키는 ${heightMin.round()}~${heightMax.round()}cm로 입력해 주세요.';
    }
    return null;
  }

  static String? weight(String value) {
    if (value.trim().isEmpty) return '몸무게를 입력해 주세요.';
    final kg = parse(value);
    if (kg == null || kg < weightMin || kg > weightMax) {
      return '몸무게는 ${weightMin.round()}~${weightMax.round()}kg으로 입력해 주세요.';
    }
    return null;
  }

  static String? consent(bool agreed) =>
      agreed ? null : '키·몸무게를 저장하려면 개인정보 수집·이용에 동의해 주세요.';
}

/// The optional step right after a new account: height and weight with
/// consent ([submit], 다음), or nothing at all ([skip], 건너뛰기). Either
/// ends the step through [AuthViewModel.finishBodyInfo].
class BodyInfoViewModel extends ChangeNotifier {
  BodyInfoViewModel({required this._auth});

  final AuthViewModel _auth;
  BodyInfoState _state = const BodyInfoState();
  bool _disposed = false;

  BodyInfoState get state => _state;

  /// Clears the form-wide error once the user changes something.
  void edited() {
    if (_state.submitting || _state.formError == null) return;
    _set(
      BodyInfoState(
        heightError: _state.heightError,
        weightError: _state.weightError,
        consentError: _state.consentError,
      ),
    );
  }

  /// Saves both values when they are in range and the user agreed. True on
  /// success; the app then moves on by itself.
  Future<bool> submit({
    required String height,
    required String weight,
    required bool consent,
  }) async {
    if (_state.submitting) return false;
    final checked = BodyInfoState(
      heightError: BodyInfoRules.height(height),
      weightError: BodyInfoRules.weight(weight),
      consentError: BodyInfoRules.consent(consent),
    );
    if (checked.hasFieldError) {
      _set(checked);
      return false;
    }

    _set(const BodyInfoState(submitting: true));
    try {
      await _auth.saveBodyInfo(
        heightCm: BodyInfoRules.parse(height)!,
        weightKg: BodyInfoRules.parse(weight)!,
      );
      _set(const BodyInfoState());
      return true;
    } on ApiException catch (e) {
      _set(BodyInfoState(formError: e.message));
    } on Exception {
      _set(const BodyInfoState(formError: genericErrorMessage));
    }
    return false;
  }

  /// Moves on without sending anything.
  void skip() {
    if (_state.submitting) return;
    _auth.finishBodyInfo();
  }

  void _set(BodyInfoState state) {
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
