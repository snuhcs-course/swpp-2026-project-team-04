import 'dart:async';

import 'package:gymrats_app/models/auth_session.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';

/// Records calls and fails or waits on request, like a scripted server.
class ScriptedAuthRepository implements AuthRepository {
  final logIns = <(String, String)>[];
  final signUps = <(String, String, String)>[];

  /// Thrown by the next logIn / signUp while set.
  Exception? logInError;
  Exception? signUpError;

  Completer<void>? _logInGate;
  Completer<void>? _signUpGate;

  AuthSession? _session;
  final _expired = StreamController<void>.broadcast();

  /// Makes logIn wait until the returned completer completes.
  Completer<void> holdLogIn() => _logInGate = Completer();

  /// Makes signUp wait until the returned completer completes.
  Completer<void> holdSignUp() => _signUpGate = Completer();

  @override
  AuthSession? get session => _session;

  @override
  Stream<void> get sessionExpired => _expired.stream;

  @override
  Future<AuthSession?> restoreSession() async => _session;

  @override
  Future<AuthSession> logIn({
    required String loginId,
    required String password,
  }) async {
    logIns.add((loginId, password));
    await _logInGate?.future;
    if (logInError case final error?) throw error;
    return _session = _sessionFor(loginId, '우현');
  }

  @override
  Future<AuthSession> signUp({
    required String nickname,
    required String loginId,
    required String password,
  }) async {
    signUps.add((nickname, loginId, password));
    await _signUpGate?.future;
    if (signUpError case final error?) throw error;
    return _session = _sessionFor(loginId, nickname);
  }

  @override
  Future<void> logOut() async => _session = null;

  static AuthSession _sessionFor(String loginId, String nickname) =>
      AuthSession(
        token: 'token',
        account: Account(id: 1, loginId: loginId, nickname: nickname),
      );
}
