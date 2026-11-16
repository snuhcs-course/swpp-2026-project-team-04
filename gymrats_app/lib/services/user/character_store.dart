import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/character_rig.dart';

/// The character each account picked (W3), kept on this phone. One value
/// per account, like the avatar before it; apart from the login session.
abstract interface class CharacterStore {
  /// The account's character id: one a person may pick, or the default
  /// (`mouse`) when nothing is saved, the value cannot be read, or it is
  /// not one of them.
  Future<String> read(int accountId);

  Future<void> write(int accountId, String characterId);
}

class SecureCharacterStore implements CharacterStore {
  SecureCharacterStore([FlutterSecureStorage? storage, CharacterRig? rig])
    : _storage = storage ?? const FlutterSecureStorage(),
      _rig = rig ?? CharacterRig.standard;

  final FlutterSecureStorage _storage;
  final CharacterRig _rig;

  static String key(int accountId) => 'gymrats.character.$accountId';

  @override
  Future<String> read(int accountId) async {
    String? saved;
    try {
      saved = await _storage.read(key: key(accountId));
    } on Object {
      // A store that cannot be read (e.g. its key was lost after a
      // restore) is the same as nothing saved.
      saved = null;
    }
    return _rig.selectableOrDefault(saved);
  }

  @override
  Future<void> write(int accountId, String characterId) =>
      _storage.write(key: key(accountId), value: characterId);
}

/// Keeps the choices only while the app runs. For tests and demos.
class MemoryCharacterStore implements CharacterStore {
  MemoryCharacterStore([CharacterRig? rig])
    : _rig = rig ?? CharacterRig.standard;

  final CharacterRig _rig;
  final values = <int, String>{};

  @override
  Future<String> read(int accountId) async =>
      _rig.selectableOrDefault(values[accountId]);

  @override
  Future<void> write(int accountId, String characterId) async {
    values[accountId] = characterId;
  }
}
