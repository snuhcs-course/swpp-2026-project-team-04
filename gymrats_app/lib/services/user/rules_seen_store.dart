import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local "battle rules seen" flag, scoped to the account, next to
/// the avatar choice and apart from the session key.
///
/// Only a sign-up on this phone saves `false`. An account without a saved
/// flag (an older account, or a login on another phone) counts as seen, so
/// a normal login goes straight home.
abstract interface class RulesSeenStore {
  /// False only while `false` is saved for [accountId].
  Future<bool> read(int accountId);

  Future<void> write(int accountId, {required bool seen});
}

class SecureRulesSeenStore implements RulesSeenStore {
  SecureRulesSeenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(int accountId) => 'gymrats.rules_seen.$accountId';

  @override
  Future<bool> read(int accountId) async =>
      await _storage.read(key: _key(accountId)) != 'false';

  @override
  Future<void> write(int accountId, {required bool seen}) =>
      _storage.write(key: _key(accountId), value: '$seen');
}

/// Keeps the flags only while the app runs. For tests and demos.
class MemoryRulesSeenStore implements RulesSeenStore {
  final values = <int, bool>{};

  @override
  Future<bool> read(int accountId) async => values[accountId] ?? true;

  @override
  Future<void> write(int accountId, {required bool seen}) async {
    values[accountId] = seen;
  }
}
