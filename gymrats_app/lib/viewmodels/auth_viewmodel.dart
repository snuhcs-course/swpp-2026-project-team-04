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
/// from [status]; the login and sign-up forms call [logIn] and [signUp].
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
  bool _disposed = false;

  AuthStatus get status => _status;

  /// The logged-in account; null while logged out.
  Account? get account => _repository.session?.account;

  /// True after the server rejected the session, until the next login, so
  /// the login screen can say why it is showing.
  bool get sessionExpired => _sessionExpired;

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
    _sessionExpired = false;
    _set(AuthStatus.signedIn);
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
    _sessionExpired = false;
    _set(AuthStatus.signedIn);
  }

  Future<void> logOut() async {
    await _repository.logOut();
    _signOut(expired: false);
  }

  void _signOut({required bool expired}) {
    if (_status == AuthStatus.signedOut) return;
    _sessionExpired = expired;
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
