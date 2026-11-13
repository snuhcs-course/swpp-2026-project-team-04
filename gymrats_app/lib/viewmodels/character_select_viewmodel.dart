import 'package:flutter/foundation.dart';

import '../models/character_rig.dart';
import 'character_viewmodel.dart';

/// The character selection screen (W3 spec 7): which cell is picked, and
/// saving it. Picking only changes the preview; [confirm] makes it the
/// account's character, and leaving without it changes nothing.
class CharacterSelectViewModel extends ChangeNotifier {
  CharacterSelectViewModel({required this._account, CharacterRig? rig})
    : _rig = rig ?? CharacterRig.standard,
      _selected = _account.characterId;

  final CharacterViewModel _account;
  final CharacterRig _rig;
  String _selected;
  bool _saving = false;

  /// The one-line words under the name (spec 7), after the animal.
  static const _lines = {
    'mouse': '대표 캐릭터',
    'kangaroo': '키 큰 점프 선수',
    'bear': '가장 큰 덩치',
    'penguin': '지느러미로 때려요',
    'seal': '가장 통통해요',
  };

  /// The cells, in the rig's order: every character but RepBot.
  List<CharacterArt> get options => _rig.selectable;

  /// The picked cell's character id.
  String get selected => _selected;

  CharacterArt get selectedArt => _rig.art(_selected);

  /// The line under the name band, e.g. "쥐 · 대표 캐릭터".
  String captionOf(CharacterArt art) {
    final line = _lines[art.id];
    return line == null ? art.species : '${art.species} · $line';
  }

  /// Whether [confirm] is running.
  bool get saving => _saving;

  /// Picks [characterId] for the preview; RepBot or an unknown id is
  /// ignored.
  void select(String characterId) {
    if (_rig.selectableOrDefault(characterId) != characterId) return;
    if (characterId == _selected) return;
    _selected = characterId;
    notifyListeners();
  }

  /// Makes the picked character the account's and saves it. A second tap
  /// while saving does nothing.
  Future<void> confirm() async {
    if (_saving) return;
    _saving = true;
    notifyListeners();
    await _account.choose(_selected);
    _saving = false;
    if (!_disposed) notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
