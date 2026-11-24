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

/// The accounts a user can sign up and log in with besides an id and
/// password.
enum SocialProvider {
  google('Google', '/auth/google', 'id_token');

  const SocialProvider(this.label, this.path, this.tokenField);

  /// Its name on screen, e.g. "Google".
  final String label;

  /// The server's login path and the body field the token goes in.
  final String path;
  final String tokenField;
}

/// A Google login on the server: the session, and whether this
/// login created the account (the app then asks for the optional body info).
typedef SocialSignIn = ({AuthSession session, bool isNewAccount});

/// The provider's token was refused by the server: expired, or not for this
/// app.
class SocialTokenRejectedException implements Exception {
  const SocialTokenRejectedException();
}

/// The server cannot use the provider right now (not configured there, or
/// the provider is unreachable).
class SocialLoginUnavailableException implements Exception {
  const SocialLoginUnavailableException();
}

/// The provider account has no GymRats account yet: sign in again with a
/// nickname to create it.
class SocialSignUpRequiredException implements Exception {
  const SocialSignUpRequiredException();
}

/// The user closed the provider's sign-in without picking an account.
class SocialSignInCancelledException implements Exception {
  const SocialSignInCancelledException();
}

/// The provider's sign-in on the device failed, e.g. the app is not set up
/// for it or the provider answered with an error. [reason] is for debugging
/// only; it never holds a token.
class SocialSignInFailedException implements Exception {
  const SocialSignInFailedException(this.reason);

  final String reason;

  @override
  String toString() => 'SocialSignInFailedException($reason)';
}

/// Runs a provider's own sign-in on the device and returns the token the
/// GymRats server checks, e.g. a Google ID token.
abstract interface class SocialSignInService {
  SocialProvider get provider;

  /// Throws [SocialSignInCancelledException] when the user backs out and
  /// [SocialSignInFailedException] for any other failure.
  Future<String> signIn();
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

  /// Logs in with a [SocialSignInService.signIn] token. A provider account
  /// seen for the first time needs [nickname] to create its GymRats account;
  /// without one this throws [SocialSignUpRequiredException] and creates
  /// nothing. Also throws [SocialTokenRejectedException] and
  /// [SocialLoginUnavailableException].
  Future<SocialSignIn> signInWith(
    SocialProvider provider,
    String token, {
    String? nickname,
  });

  /// Saves the logged-in user's height and weight; the user agreed to it.
  Future<void> saveBodyInfo({
    required double heightCm,
    required double weightKg,
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
  Future<SocialSignIn> signInWith(
    SocialProvider provider,
    String token, {
    String? nickname,
  }) async {
    final Object? json;
    try {
      json = await _api.post(provider.path, {
        provider.tokenField: token,
        'nickname': ?nickname,
      }, authorized: false);
    } on ApiException catch (e) {
      if (e.statusCode == 404 && e.code == 'signup_required') {
        throw const SocialSignUpRequiredException();
      }
      if (e.statusCode == 401) throw const SocialTokenRejectedException();
      if (e.statusCode == 503) throw const SocialLoginUnavailableException();
      rethrow;
    }
    final created = json is Map && json['created'] == true;
    return (session: await _signedIn(json), isNewAccount: created);
  }

  @override
  Future<void> saveBodyInfo({
    required double heightCm,
    required double weightKg,
  }) async {
    await _api.post('/users/me/body', {
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'consent': true,
    });
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
