/// The account a user logged in with.
class Account {
  const Account({
    required this.id,
    required this.loginId,
    required this.nickname,
  });

  factory Account.fromJson(Map<String, Object?> json) => Account(
    id: json['id']! as int,
    loginId: json['login_id']! as String,
    nickname: json['nickname']! as String,
  );

  final int id;

  /// What the user types to log in, e.g. "woohyun".
  final String loginId;

  /// Name in the greeting, e.g. "우현".
  final String nickname;

  Map<String, Object?> toJson() => {
    'id': id,
    'login_id': loginId,
    'nickname': nickname,
  };
}

/// A logged-in user: the server's token and the account it belongs to.
class AuthSession {
  const AuthSession({required this.token, required this.account});

  factory AuthSession.fromJson(Map<String, Object?> json) => AuthSession(
    token: json['token']! as String,
    account: Account.fromJson(json['user']! as Map<String, Object?>),
  );

  /// Sent as `Authorization: Bearer <token>`. Never logged.
  final String token;

  final Account account;

  Map<String, Object?> toJson() => {'token': token, 'user': account.toJson()};

  /// Keeps the token out of logs and error messages.
  @override
  String toString() => 'AuthSession(${account.loginId})';
}
