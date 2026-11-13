import 'package:flutter/foundation.dart';

import '../models/character_rig.dart';
import '../services/user/character_store.dart';

/// The signed-in account's character (W3), the same on every screen: the
/// battle stage, 게임 시작's 캐릭터 row, and later home and the tutorial.
///
/// One for the whole app, above the navigator. GymRatsApp loads it when an
/// account signs in and clears it when it signs out; until it has read the
/// account's choice it holds the default (`mouse`) and is [loading], and
/// GymRatsApp keeps home closed, so no screen takes that stand-in for the
/// account's character.
class CharacterViewModel extends ChangeNotifier {
  CharacterViewModel({required this._store, CharacterRig? rig})
    : _rig = rig ?? CharacterRig.standard,
      _characterId = (rig ?? CharacterRig.standard).defaultCharacter;

  final CharacterStore _store;
  final CharacterRig _rig;

  /// The account the character belongs to; null while signed out.
  int? _accountId;
  String _characterId;
  bool _loading = false;

  /// Counts the changes, so a slow read does not undo a newer one.
  int _version = 0;
  bool _disposed = false;

  /// The character id: one a person may pick (never `bot`).
  String get characterId => _characterId;

  CharacterArt get art => _rig.art(_characterId);

  /// Whether the signed-in account's saved choice is still being read:
  /// [characterId] is only the default until then.
  bool get loading => _loading;

  /// Whether [characterId] is [accountId]'s own: its saved choice was read,
  /// or a choice was made since.
  bool isReadyFor(int? accountId) =>
      accountId != null && accountId == _accountId && !_loading;

  /// Reads [accountId]'s saved choice after a login. The store gives the
  /// default for nothing saved or a value it cannot read; a read that fails
  /// all the same counts as nothing saved, so the loading always ends.
  Future<void> load(int accountId) async {
    if (accountId == _accountId) return;
    _accountId = accountId;
    final version = ++_version;
    _update(_rig.defaultCharacter, loading: true);
    String saved;
    try {
      saved = await _store.read(accountId);
    } on Object {
      saved = _rig.defaultCharacter;
    }
    if (_disposed || version != _version) return;
    _update(saved, loading: false);
  }

  /// Back to the default after a logout.
  void clear() {
    _accountId = null;
    _version++;
    _update(_rig.defaultCharacter, loading: false);
  }

  /// Makes [characterId] the account's character and saves it. Returns
  /// whether it was saved; a character a person may not pick changes
  /// nothing. If saving fails the choice still holds until the app closes.
  /// A choice made while the saved one is read wins over it, and ends the
  /// loading.
  Future<bool> choose(String characterId) async {
    if (_rig.selectableOrDefault(characterId) != characterId) return false;
    _version++;
    _update(characterId, loading: false);
    final accountId = _accountId;
    if (accountId == null) return false;
    try {
      await _store.write(accountId, characterId);
      return true;
    } on Object {
      return false;
    }
  }

  void _update(String characterId, {required bool loading}) {
    if (_disposed) return;
    if (characterId == _characterId && loading == _loading) return;
    _characterId = characterId;
    _loading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
