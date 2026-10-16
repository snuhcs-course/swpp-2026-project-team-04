import 'dart:async';

import '../../models/auth_session.dart';
import '../api/api_client.dart';
import 'token_store.dart';

/// Sign-up was refused because another account has that login id.
class LoginIdTakenException implements Exception {
  const LoginIdTakenException();
}

/// Login was refused. Says nothing about which field was wrong.
class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException();
}

/// Creates accounts, logs in and out, and remembers the session.
///
/// Other failures throw an [Exception], an [ApiException] for the server
/// implementation.
abstract interface class AuthRepository {
  /// The logged-in session; null while logged out.
  AuthSession? get session;

  /// Fires when the server rejects the saved session, after it is cleared.
  Stream<void> get sessionExpired;

  /// Loads the session saved on the device, if any. It is checked against
  /// the server on the first request that needs it.
  Future<AuthSession?> restoreSession();

  /// Throws [LoginIdTakenException] when [loginId] is taken.
  Future<AuthSession> signUp({
    required String nickname,
    required String loginId,
    required String password,
  });

  /// Throws [InvalidCredentialsException] for a wrong id or password.
  Future<AuthSession> logIn({
    required String loginId,
    required String password,
  });

  /// Forgets the session on this device.
  Future<void> logOut();
}

/// [AuthRepository] backed by the GymRats API.
class ServerAuthRepository implements AuthRepository {
  ServerAuthRepository({required this._api, required this._store}) {
    _api.unauthorized.listen((_) => _expire());
  }

  final ApiClient _api;
  final TokenStore _store;
  final _expired = StreamController<void>.broadcast();
  AuthSession? _session;

  @override
  AuthSession? get session => _session;

  @override
  Stream<void> get sessionExpired => _expired.stream;

  @override
  Future<AuthSession?> restoreSession() async {
    _use(await _store.read());
    return _session;
  }

  @override
  Future<AuthSession> signUp({
    required String nickname,
    required String loginId,
    required String password,
  }) async {
    try {
      final json = await _api.post('/auth/signup', {
        'nickname': nickname,
        'login_id': loginId,
        'password': password,
      }, authorized: false);
      return await _signedIn(json);
    } on ApiException catch (e) {
      if (e.statusCode == 409) throw const LoginIdTakenException();
      rethrow;
    }
  }

  @override
  Future<AuthSession> logIn({
    required String loginId,
    required String password,
  }) async {
    try {
      final json = await _api.post('/auth/login', {
        'login_id': loginId,
        'password': password,
      }, authorized: false);
      return await _signedIn(json);
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized) {
        throw const InvalidCredentialsException();
      }
      rethrow;
    }
  }

  @override
  Future<void> logOut() async {
    _use(null);
    await _store.clear();
  }

  Future<AuthSession> _signedIn(Object? json) async {
    final AuthSession session;
    try {
      session = AuthSession.fromJson(json! as Map<String, Object?>);
    } on Object {
      throw const ApiException(ApiErrorKind.server);
    }
    _use(session);
    await _store.write(session);
    return session;
  }

  Future<void> _expire() async {
    if (_session == null) return;
    await logOut();
    _expired.add(null);
  }

  void _use(AuthSession? session) {
    _session = session;
    _api.token = session?.token;
  }
}
