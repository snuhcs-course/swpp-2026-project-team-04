import 'package:flutter/foundation.dart';

import '../services/api/api_client.dart';
import '../services/auth/auth_repository.dart';
import 'auth_viewmodel.dart';
import 'login_viewmodel.dart';

/// What the sign-up form shows besides the typed text.
class SignupState {
  const SignupState({
    this.nicknameError,
    this.loginIdError,
    this.passwordError,
    this.confirmError,
    this.formError,
    this.submitting = false,
  });

  /// Shown under each field; null when the field is fine.
  final String? nicknameError;
  final String? loginIdError;
  final String? passwordError;
  final String? confirmError;

  /// Shown above the button, e.g. no network.
  final String? formError;

  /// A sign-up request is running: the button does nothing.
  final bool submitting;

  bool get hasFieldError =>
      nicknameError != null ||
      loginIdError != null ||
      passwordError != null ||
      confirmError != null;
}

/// Field rules, the same as the server's.
abstract final class SignupRules {
  static const nicknameMax = 12;
  static const passwordMin = 8;
  static const passwordMax = 64;
  static final loginIdPattern = RegExp(r'^[a-z0-9_]{4,20}$');

  static String? nickname(String value) {
    final nickname = value.trim();
    if (nickname.isEmpty) return '닉네임을 입력해 주세요.';
    if (nickname.runes.length > nicknameMax) {
      return '닉네임은 $nicknameMax자 이하로 입력해 주세요.';
    }
    return null;
  }

  static String? loginId(String value) {
    if (value.isEmpty) return '아이디를 입력해 주세요.';
    if (!loginIdPattern.hasMatch(value)) {
      return '아이디는 영문 소문자, 숫자, _ 로 4~20자여야 해요.';
    }
    return null;
  }

  static String? password(String value) {
    if (value.isEmpty) return '비밀번호를 입력해 주세요.';
    // Characters as the server counts them (code points, not UTF-16 units).
    final length = value.runes.length;
    if (length < passwordMin) return '비밀번호는 $passwordMin자 이상이어야 해요.';
    if (length > passwordMax) return '비밀번호는 $passwordMax자 이하여야 해요.';
    return null;
  }

  static String? confirm(String password, String confirm) {
    if (confirm.isEmpty) return '비밀번호를 한 번 더 입력해 주세요.';
    if (confirm != password) return '비밀번호가 일치하지 않아요.';
    return null;
  }
}

/// Checks the sign-up form and creates the account through
/// [AuthViewModel]. On success the user is logged in.
class SignupViewModel extends ChangeNotifier {
  SignupViewModel({required this._auth});

  static const takenMessage = '이미 사용 중인 아이디예요.';

  final AuthViewModel _auth;
  SignupState _state = const SignupState();
  bool _disposed = false;

  SignupState get state => _state;

  /// Clears the form-wide error once the user types again. Field errors
  /// stay until the next submit, so the user can see what to fix.
  void edited() {
    if (_state.submitting || _state.formError == null) return;
    _set(
      SignupState(
        nicknameError: _state.nicknameError,
        loginIdError: _state.loginIdError,
        passwordError: _state.passwordError,
        confirmError: _state.confirmError,
      ),
    );
  }

  /// True when the account was created and the user is logged in.
  Future<bool> submit({
    required String nickname,
    required String loginId,
    required String password,
    required String confirm,
  }) async {
    if (_state.submitting) return false;
    final checked = SignupState(
      nicknameError: SignupRules.nickname(nickname),
      loginIdError: SignupRules.loginId(loginId),
      passwordError: SignupRules.password(password),
      confirmError: SignupRules.confirm(password, confirm),
    );
    if (checked.hasFieldError) {
      _set(checked);
      return false;
    }

    _set(const SignupState(submitting: true));
    try {
      await _auth.signUp(
        nickname: nickname.trim(),
        loginId: loginId,
        password: password,
      );
      _set(const SignupState());
      return true;
    } on LoginIdTakenException {
      _set(const SignupState(loginIdError: takenMessage));
    } on ApiException catch (e) {
      _set(SignupState(formError: e.message));
    } on Exception {
      _set(const SignupState(formError: genericErrorMessage));
    }
    return false;
  }

  void _set(SignupState state) {
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
