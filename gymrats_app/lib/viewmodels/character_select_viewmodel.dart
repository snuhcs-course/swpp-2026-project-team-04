import 'package:flutter/foundation.dart';

import '../models/character_rig.dart';
import 'character_viewmodel.dart';

/// The character selection screen (W3 spec 7): which cell is picked, and
/// saving it. Picking only changes the preview; [confirm] makes it the
/// account's character, and leaving without it changes nothing.
///
/// Home opens only once the account's character is read, so the screen
/// normally starts on it. Should it open while the read still runs, it is
/// not [ready]: [confirm] does nothing (it would save the default over
/// the saved choice), and when the read ends the preview takes the saved
/// character, unless a cell was picked meanwhile.
class CharacterSelectViewModel extends ChangeNotifier {
  CharacterSelectViewModel({required this._account, CharacterRig? rig})
    : _rig = rig ?? CharacterRig.standard,
      _selected = _account.characterId {
    _account.addListener(_follow);
  }

  final CharacterViewModel _account;
  final CharacterRig _rig;
  String _selected;
  bool _saving = false;

  /// Whether a cell was picked here; then the read no longer moves it.
  bool _picked = false;

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

  /// Whether the account's saved character has been read, so [confirm]
  /// can save over it.
  bool get ready => !_account.loading;

  /// Picks [characterId] for the preview; RepBot or an unknown id is
  /// ignored.
  void select(String characterId) {
    if (_rig.selectableOrDefault(characterId) != characterId) return;
    if (characterId == _selected) return;
    _picked = true;
    _selected = characterId;
    notifyListeners();
  }

  /// Makes the picked character the account's and saves it. A second tap
  /// while saving, or a tap before the saved character is read, does
  /// nothing.
  Future<void> confirm() async {
    if (_saving || !ready) return;
    _saving = true;
    notifyListeners();
    await _account.choose(_selected);
    _saving = false;
    if (!_disposed) notifyListeners();
  }

  /// The account's character changed (its read ended): the preview takes
  /// it unless a cell was picked here; [ready] may have changed too.
  void _follow() {
    if (_disposed || _saving) return;
    if (!_picked) _selected = _account.characterId;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _account.removeListener(_follow);
    super.dispose();
  }
}
