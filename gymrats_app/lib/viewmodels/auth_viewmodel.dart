import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../services/auth/auth_repository.dart';

/// Whether someone is logged in.
enum AuthStatus {
  /// Reading the saved session at app start.
  restoring,

  /// Nobody is logged in: the login screen shows.
  signedOut,

  /// A user is logged in: the home screen shows.
  signedIn,
}

/// The app-wide login state. GymRatsApp shows the login or home screen
/// from [status]; the login and sign-up forms call [logIn], [signUp] and
/// [signInWith]. A new account first sees the optional body info step
/// ([needsBodyInfo]).
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required this._repository}) {
    _expiredSubscription = _repository.sessionExpired.listen(
      (_) => _signOut(expired: true),
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _expiredSubscription;

  AuthStatus _status = AuthStatus.restoring;
  bool _sessionExpired = false;
  bool _needsBodyInfo = false;
  bool _disposed = false;

  AuthStatus get status => _status;

  /// The logged-in account; null while logged out.
  Account? get account => _repository.session?.account;

  /// True after the server rejected the session, until the next login, so
  /// the login screen can say why it is showing.
  bool get sessionExpired => _sessionExpired;

  /// True right after this device created the account (id and password,
  /// Google), until the user saves or skips height and weight.
  /// Not kept across app restarts: the step is optional.
  bool get needsBodyInfo => _needsBodyInfo;

  /// Loads the session saved on the device. A device without one, or one
  /// whose storage cannot be read, shows the login screen.
  Future<void> restore() async {
    AuthSession? session;
    try {
      session = await _repository.restoreSession();
    } on Exception {
      session = null;
    }
    _set(session == null ? AuthStatus.signedOut : AuthStatus.signedIn);
  }

  /// Throws what [AuthRepository.logIn] throws; stays logged out then.
  Future<void> logIn({
    required String loginId,
    required String password,
  }) async {
    await _repository.logIn(loginId: loginId, password: password);
    _signIn(isNewAccount: false);
  }

  /// Throws what [AuthRepository.signUp] throws; stays logged out then.
  Future<void> signUp({
    required String nickname,
    required String loginId,
    required String password,
  }) async {
    await _repository.signUp(
      nickname: nickname,
      loginId: loginId,
      password: password,
    );
    _signIn(isNewAccount: true);
  }

  /// Logs in with a Google token; a new provider account needs
  /// [nickname] to be created. Returns whether it was created. Throws what
  /// [AuthRepository.signInWith] throws; stays logged out then.
  Future<bool> signInWith(
    SocialProvider provider,
    String token, {
    String? nickname,
  }) async {
    final result = await _repository.signInWith(
      provider,
      token,
      nickname: nickname,
    );
    _signIn(isNewAccount: result.isNewAccount);
    return result.isNewAccount;
  }

  /// Saves height and weight the user agreed to share. Throws what
  /// [AuthRepository.saveBodyInfo] throws; [needsBodyInfo] stays then.
  Future<void> saveBodyInfo({
    required double heightCm,
    required double weightKg,
  }) async {
    await _repository.saveBodyInfo(heightCm: heightCm, weightKg: weightKg);
    finishBodyInfo();
  }

  /// Ends the body info step, saved or skipped.
  void finishBodyInfo() {
    if (!_needsBodyInfo) return;
    _needsBodyInfo = false;
    if (_disposed) return;
    notifyListeners();
  }

  void _signIn({required bool isNewAccount}) {
    _sessionExpired = false;
    _needsBodyInfo = isNewAccount;
    _set(AuthStatus.signedIn);
  }

  Future<void> logOut() async {
    await _repository.logOut();
    _signOut(expired: false);
  }

  void _signOut({required bool expired}) {
    if (_status == AuthStatus.signedOut) return;
    _sessionExpired = expired;
    _needsBodyInfo = false;
    _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiredSubscription.cancel();
    super.dispose();
  }
}
