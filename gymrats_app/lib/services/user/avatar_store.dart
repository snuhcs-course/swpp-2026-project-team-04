import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/avatar_model.dart';

/// Device-local avatar preference, scoped to the signed-in account.
/// This is separate from login credentials and never edits the session key.
abstract interface class AvatarStore {
  Future<AvatarModel> read(int accountId);
  Future<void> write(int accountId, AvatarModel avatar);
}

class SecureAvatarStore implements AvatarStore {
  SecureAvatarStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  String _key(int accountId) => 'gymrats.avatar.$accountId';

  @override
  Future<AvatarModel> read(int accountId) async {
    final id = await _storage.read(key: _key(accountId));
    return AvatarModel.values.firstWhere(
      (model) => model.protocolId == id,
      orElse: () => AvatarModel.astronaut,
    );
  }

  @override
  Future<void> write(int accountId, AvatarModel avatar) =>
      _storage.write(key: _key(accountId), value: avatar.protocolId);
}

class MemoryAvatarStore implements AvatarStore {
  final values = <int, AvatarModel>{};
  @override
  Future<AvatarModel> read(int accountId) async =>
      values[accountId] ?? AvatarModel.astronaut;
  @override
  Future<void> write(int accountId, AvatarModel avatar) async {
    values[accountId] = avatar;
  }
}
