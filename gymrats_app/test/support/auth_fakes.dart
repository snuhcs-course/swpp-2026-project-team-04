import 'dart:async';

import 'package:gymrats_app/models/auth_session.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';

/// Records calls and fails or waits on request, like a scripted server.
class ScriptedAuthRepository implements AuthRepository {
  final logIns = <(String, String)>[];
  final signUps = <(String, String, String)>[];
  final socialSignIns = <(SocialProvider, String, String?)>[];
  final bodyInfos = <(double, double)>[];

  /// Thrown by the next signInWith / saveBodyInfo while set.
  Exception? socialError;
  Exception? bodyInfoError;

  /// Whether the provider account is new: signInWith then needs a nickname
  /// and creates the account with it.
  bool socialIsNew = true;

  Completer<void>? _bodyInfoGate;

  /// Makes saveBodyInfo wait until the returned completer completes.
  Completer<void> holdBodyInfo() => _bodyInfoGate = Completer();

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
  Future<SocialSignIn> signInWith(
    SocialProvider provider,
    String token, {
    String? nickname,
  }) async {
    socialSignIns.add((provider, token, nickname));
    if (socialError case final error?) throw error;
    if (socialIsNew && nickname == null) {
      throw const SocialSignUpRequiredException();
    }
    _session = _sessionFor('${provider.name[0]}_1', nickname ?? '우현');
    final created = socialIsNew;
    socialIsNew = false;
    return (session: _session!, isNewAccount: created);
  }

  @override
  Future<void> saveBodyInfo({
    required double heightCm,
    required double weightKg,
  }) async {
    bodyInfos.add((heightCm, weightKg));
    await _bodyInfoGate?.future;
    if (bodyInfoError case final error?) throw error;
  }

  @override
  Future<void> logOut() async => _session = null;

  static AuthSession _sessionFor(String loginId, String nickname) =>
      AuthSession(
        token: 'token',
        account: Account(id: 1, loginId: loginId, nickname: nickname),
      );
}

/// A provider sign-in that returns [token] or throws [error], counting calls.
class FakeSocialSignIn implements SocialSignInService {
  FakeSocialSignIn(this.provider, {this.token = 'provider-token', this.error});

  @override
  final SocialProvider provider;
  String token;
  Exception? error;
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<String> signIn() async {
    calls++;
    await gate?.future;
    if (error case final error?) throw error;
    return token;
  }
}
