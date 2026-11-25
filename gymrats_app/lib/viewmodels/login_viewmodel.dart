import 'package:flutter/foundation.dart';

import '../services/api/api_client.dart';
import '../services/auth/auth_repository.dart';
import 'auth_viewmodel.dart';
import 'social_signup_viewmodel.dart';

/// What the login form shows besides the typed text.
class LoginState {
  const LoginState({
    this.loginIdError,
    this.passwordError,
    this.formError,
    this.submitting = false,
    this.signingInWith,
    this.cancelledWith,
    this.failedWith,
  });

  /// Shown under the field; null when the field is fine.
  final String? loginIdError;
  final String? passwordError;

  /// Shown above the button, e.g. a wrong password or no network.
  final String? formError;

  /// A login request is running: the button does nothing.
  final bool submitting;

  /// The Google login that is running; null when none is.
  final SocialProvider? signingInWith;

  /// The Google login the user backed out of, until the next attempt or
  /// edit (the login screen's grey "로그인을 취소했어요" line, P8).
  final SocialProvider? cancelledWith;

  /// The Google login whose failure [formError] tells; null when
  /// [formError] comes from the id form or an expired session (P8).
  final SocialProvider? failedWith;

  /// Any login is running: every login button does nothing.
  bool get busy => submitting || signingInWith != null;
}

/// Checks the login form and logs in through [AuthViewModel], with an id
/// and password or with Google ([signInWith]).
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required this._auth, this.google})
    : _state = LoginState(
        formError: _auth.sessionExpired ? expiredMessage : null,
      );

  static const expiredMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';

  /// One message for a wrong id and a wrong password.
  static const wrongCredentialsMessage = '아이디 또는 비밀번호가 맞지 않아요.';

  final AuthViewModel _auth;

  /// The Google sign-in; null hides its button.
  final SocialSignInService? google;
  LoginState _state;
  SocialSignupRequest? _signupRequest;
  bool _disposed = false;

  LoginState get state => _state;

  /// Clears the errors, and a cancelled Google login's note, once the user
  /// types again or turns to the id form.
  void edited() {
    if (_state.busy) return;
    if (_state.loginIdError == null &&
        _state.passwordError == null &&
        _state.formError == null &&
        _state.cancelledWith == null) {
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
    if (_state.busy) return false;
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

  /// Logs in with [service]'s provider. True when an existing account
  /// logged in. A provider account seen for the first time creates nothing
  /// yet: [takeSignupRequest] then holds what the nickname step needs.
  /// Backing out of the provider's screen shows no error.
  Future<bool> signInWith(SocialSignInService service) async {
    if (_state.busy) return false;
    final provider = service.provider;
    _signupRequest = null;
    _set(LoginState(signingInWith: provider));
    try {
      final token = await service.signIn();
      try {
        await _auth.signInWith(provider, token);
      } on SocialSignUpRequiredException {
        _signupRequest = (provider: provider, token: token);
        _set(const LoginState());
        return false;
      }
      _set(const LoginState());
      return true;
    } on SocialSignInCancelledException {
      _set(LoginState(cancelledWith: provider));
    } on SocialSignInFailedException {
      _failed(provider, socialFailedMessage(provider));
    } on SocialTokenRejectedException {
      _failed(provider, socialFailedMessage(provider));
    } on SocialLoginUnavailableException {
      _failed(provider, socialUnavailableMessage(provider));
    } on ApiException catch (e) {
      _failed(provider, e.message);
    } on Exception {
      _failed(provider, genericErrorMessage);
    }
    return false;
  }

  void _failed(SocialProvider provider, String message) =>
      _set(LoginState(formError: message, failedWith: provider));

  /// The new provider account the last [signInWith] found, once; null
  /// otherwise. LoginScreen opens the nickname step with it.
  SocialSignupRequest? takeSignupRequest() {
    final request = _signupRequest;
    _signupRequest = null;
    return request;
  }

  static String socialFailedMessage(SocialProvider provider) =>
      '${provider.label} 로그인에 실패했어요. 다시 시도해 주세요.';

  static String socialUnavailableMessage(SocialProvider provider) =>
      '지금은 ${provider.label} 로그인을 쓸 수 없어요. 잠시 후 다시 시도해 주세요.';

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
