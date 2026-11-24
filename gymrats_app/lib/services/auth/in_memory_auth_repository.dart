import 'dart:async';

import '../../models/auth_session.dart';
import 'auth_repository.dart';
import 'token_store.dart';

/// Accounts kept in memory, for tests and demos that need no server.
///
/// Follows the server's rules: a taken login id is refused, and a wrong id
/// or password gets the same error.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({TokenStore? store})
    : _store = store ?? MemoryTokenStore();

  final TokenStore _store;
  final _accounts = <String, ({Account account, String password})>{};
  final _expired = StreamController<void>.broadcast();
  AuthSession? _session;
  int _nextId = 1;
  final _social = <(SocialProvider, String), Account>{};

  /// The last saved height and weight of each account id.
  final bodyInfo = <int, ({double heightCm, double weightKg})>{};

  @override
  AuthSession? get session => _session;

  @override
  Stream<void> get sessionExpired => _expired.stream;

  /// Adds an account, as if it signed up earlier.
  void addAccount({
    required String loginId,
    required String nickname,
    required String password,
  }) {
    _accounts[loginId] = (
      account: Account(id: _nextId++, loginId: loginId, nickname: nickname),
      password: password,
    );
  }

  /// Drops the session as if the server rejected it.
  Future<void> expireSession() async {
    await logOut();
    _expired.add(null);
  }

  @override
  Future<AuthSession?> restoreSession() async => _session = await _store.read();

  @override
  Future<AuthSession> signUp({
    required String nickname,
    required String loginId,
    required String password,
  }) async {
    if (_accounts.containsKey(loginId)) throw const LoginIdTakenException();
    addAccount(loginId: loginId, nickname: nickname, password: password);
    return _signIn(_accounts[loginId]!.account);
  }

  @override
  Future<AuthSession> logIn({
    required String loginId,
    required String password,
  }) async {
    final entry = _accounts[loginId];
    if (entry == null || entry.password != password) {
      throw const InvalidCredentialsException();
    }
    return _signIn(entry.account);
  }

  /// A provider token is the identity itself here; an empty one is refused,
  /// as the server refuses a token it cannot check.
  @override
  Future<SocialSignIn> signInWith(
    SocialProvider provider,
    String token, {
    String? nickname,
  }) async {
    if (token.isEmpty) throw const SocialTokenRejectedException();
    final key = (provider, token);
    final existing = _social[key];
    if (existing == null && nickname == null) {
      throw const SocialSignUpRequiredException();
    }
    final account =
        existing ??
        Account(
          id: _nextId++,
          loginId: '${provider.name[0]}_$token',
          nickname: nickname!,
        );
    _social[key] = account;
    return (session: await _signIn(account), isNewAccount: existing == null);
  }

  @override
  Future<void> saveBodyInfo({
    required double heightCm,
    required double weightKg,
  }) async {
    final account = _session?.account;
    if (account == null) throw StateError('Not logged in');
    bodyInfo[account.id] = (heightCm: heightCm, weightKg: weightKg);
  }

  @override
  Future<void> logOut() async {
    _session = null;
    await _store.clear();
  }

  Future<AuthSession> _signIn(Account account) async {
    final session = AuthSession(token: 'local-${account.id}', account: account);
    _session = session;
    await _store.write(session);
    return session;
  }
}
