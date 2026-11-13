import 'package:flutter/foundation.dart';

import '../models/character_rig.dart';
import '../services/user/character_store.dart';

/// The signed-in account's character (W3), the same on every screen: the
/// battle stage, 게임 시작's 캐릭터 row, and later home and the tutorial.
///
/// One for the whole app, above the navigator. GymRatsApp loads it when an
/// account signs in and clears it when it signs out; until it has read the
/// account's choice it holds the default (`mouse`).
class CharacterViewModel extends ChangeNotifier {
  CharacterViewModel({required this._store, CharacterRig? rig})
    : _rig = rig ?? CharacterRig.standard,
      _characterId = (rig ?? CharacterRig.standard).defaultCharacter;

  final CharacterStore _store;
  final CharacterRig _rig;

  /// The account the character belongs to; null while signed out.
  int? _accountId;
  String _characterId;

  /// Counts the changes, so a slow read does not undo a newer one.
  int _version = 0;
  bool _disposed = false;

  /// The character id: one a person may pick (never `bot`).
  String get characterId => _characterId;

  CharacterArt get art => _rig.art(_characterId);

  /// Reads [accountId]'s saved choice after a login. The store gives the
  /// default for nothing saved or a value it cannot read.
  Future<void> load(int accountId) async {
    if (accountId == _accountId) return;
    _accountId = accountId;
    final version = ++_version;
    _set(_rig.defaultCharacter);
    final saved = await _store.read(accountId);
    if (_disposed || version != _version) return;
    _set(saved);
  }

  /// Back to the default after a logout.
  void clear() {
    _accountId = null;
    _version++;
    _set(_rig.defaultCharacter);
  }

  /// Makes [characterId] the account's character and saves it. Returns
  /// whether it was saved; a character a person may not pick changes
  /// nothing. If saving fails the choice still holds until the app closes.
  Future<bool> choose(String characterId) async {
    if (_rig.selectableOrDefault(characterId) != characterId) return false;
    _version++;
    _set(characterId);
    final accountId = _accountId;
    if (accountId == null) return false;
    try {
      await _store.write(accountId, characterId);
      return true;
    } on Object {
      return false;
    }
  }

  void _set(String characterId) {
    if (characterId == _characterId || _disposed) return;
    _characterId = characterId;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
