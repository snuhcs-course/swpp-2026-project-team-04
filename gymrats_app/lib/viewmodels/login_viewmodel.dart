import 'package:flutter/foundation.dart';

import '../services/api/api_client.dart';
import '../services/auth/auth_repository.dart';
import 'auth_viewmodel.dart';

/// What the login form shows besides the typed text.
class LoginState {
  const LoginState({
    this.loginIdError,
    this.passwordError,
    this.formError,
    this.submitting = false,
  });

  /// Shown under the field; null when the field is fine.
  final String? loginIdError;
  final String? passwordError;

  /// Shown above the button, e.g. a wrong password or no network.
  final String? formError;

  /// A login request is running: the button does nothing.
  final bool submitting;
}

/// Checks the login form and logs in through [AuthViewModel].
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required this._auth})
    : _state = LoginState(
        formError: _auth.sessionExpired ? expiredMessage : null,
      );

  static const expiredMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';

  /// One message for a wrong id and a wrong password.
  static const wrongCredentialsMessage = '아이디 또는 비밀번호가 맞지 않아요.';

  final AuthViewModel _auth;
  LoginState _state;
  bool _disposed = false;

  LoginState get state => _state;

  /// Clears the errors once the user types again.
  void edited() {
    if (_state.submitting) return;
    if (_state.loginIdError == null &&
        _state.passwordError == null &&
        _state.formError == null) {
      return;
    }
    _set(const LoginState());
  }

  /// Logs in when both fields are filled. True on success; the app then
  /// shows home by itself.
  Future<bool> submit({
    required String loginId,
    required String password,
  }) async {
    if (_state.submitting) return false;
    final id = loginId.trim();
    final idError = id.isEmpty ? '아이디를 입력해 주세요.' : null;
    final passwordError = password.isEmpty ? '비밀번호를 입력해 주세요.' : null;
    if (idError != null || passwordError != null) {
      _set(LoginState(loginIdError: idError, passwordError: passwordError));
      return false;
    }

    _set(const LoginState(submitting: true));
    try {
      await _auth.logIn(loginId: id, password: password);
      _set(const LoginState());
      return true;
    } on InvalidCredentialsException {
      _set(const LoginState(formError: wrongCredentialsMessage));
    } on ApiException catch (e) {
      _set(LoginState(formError: e.message));
    } on Exception {
      _set(const LoginState(formError: genericErrorMessage));
    }
    return false;
  }

  void _set(LoginState state) {
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

/// For a failure that is neither the user's input nor the network.
const genericErrorMessage = '문제가 생겼어요. 잠시 후 다시 시도해 주세요.';
