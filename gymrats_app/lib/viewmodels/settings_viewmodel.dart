import 'package:flutter/foundation.dart';

import '../services/user/settings_store.dart';

/// Immutable state of the app's settings.
@immutable
class SettingsState {
  const SettingsState({
    this.soundEffectsOn = true,
    this.voiceGuidanceOn = false,
  });

  /// Whether battles play sound effects.
  final bool soundEffectsOn;

  /// Whether the countdown, matching and judgments are spoken.
  final bool voiceGuidanceOn;

  SettingsState copyWith({bool? soundEffectsOn, bool? voiceGuidanceOn}) =>
      SettingsState(
        soundEffectsOn: soundEffectsOn ?? this.soundEffectsOn,
        voiceGuidanceOn: voiceGuidanceOn ?? this.voiceGuidanceOn,
      );
}

/// The app's settings, one for the whole app (provided in main.dart above
/// every screen), so 환경설정 shows the same values each time it opens and
/// any screen can read them.
///
/// The switches are saved in [SettingsStore] and read back by [load], so
/// they stay after the app restarts. Read [state] (or listen) where sound
/// plays; every setter call notifies.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    SettingsStore? store,
    bool soundEffectsOn = true,
    bool voiceGuidanceOn = false,
  }) : _store = store ?? MemorySettingsStore(),
       _state = SettingsState(
         soundEffectsOn: soundEffectsOn,
         voiceGuidanceOn: voiceGuidanceOn,
       );

  final SettingsStore _store;
  SettingsState _state;
  bool _disposed = false;

  /// Switches the user turned while [load] was reading; theirs win.
  bool _soundEffectsTurned = false;
  bool _voiceGuidanceTurned = false;

  SettingsState get state => _state;

  /// Shows the saved switches; one never saved keeps its default. Until it
  /// finishes the defaults show. If reading fails the defaults stay.
  Future<void> load() async {
    final SavedSettings saved;
    try {
      saved = await _store.read();
    } on Exception {
      return;
    }
    _setState(
      SettingsState(
        soundEffectsOn: _soundEffectsTurned
            ? _state.soundEffectsOn
            : saved.soundEffectsOn ?? _state.soundEffectsOn,
        voiceGuidanceOn: _voiceGuidanceTurned
            ? _state.voiceGuidanceOn
            : saved.voiceGuidanceOn ?? _state.voiceGuidanceOn,
      ),
    );
  }

  void setSoundEffects(bool on) {
    if (_disposed) return;
    _soundEffectsTurned = true;
    _setState(_state.copyWith(soundEffectsOn: on));
    _save(_store.writeSoundEffects(on));
  }

  void setVoiceGuidance(bool on) {
    if (_disposed) return;
    _voiceGuidanceTurned = true;
    _setState(_state.copyWith(voiceGuidanceOn: on));
    _save(_store.writeVoiceGuidance(on));
  }

  /// A save that fails keeps the switch as it is for this run; the next
  /// start shows the last value that was saved.
  void _save(Future<void> writing) => writing.catchError((Object _) {});

  void _setState(SettingsState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
