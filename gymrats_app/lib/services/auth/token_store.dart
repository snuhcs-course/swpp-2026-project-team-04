import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/auth_session.dart';

/// Keeps the logged-in session on the device between app starts.
abstract interface class TokenStore {
  /// The saved session; null when there is none or it cannot be read.
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

/// Android Keystore-backed storage, so the token is encrypted at rest.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'gymrats.session';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved == null) return null;
      return AuthSession.fromJson(jsonDecode(saved) as Map<String, Object?>);
    } on Object {
      // Unreadable (e.g. the keystore was reset): start logged out.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object {
      // Nothing more to do; the next read fails and clears again.
    }
  }
}

/// Keeps the session only while the app runs. For tests and demos.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.session]);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}
