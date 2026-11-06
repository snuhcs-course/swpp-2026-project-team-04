import 'package:flutter/foundation.dart';

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
/// The two sound switches only keep their state here. To make them work,
/// read [state] (or listen) where sound plays, pass saved values to the
/// constructor, and save in [setSoundEffects] and [setVoiceGuidance].
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({bool soundEffectsOn = true, bool voiceGuidanceOn = false})
    : _state = SettingsState(
        soundEffectsOn: soundEffectsOn,
        voiceGuidanceOn: voiceGuidanceOn,
      );

  SettingsState _state;
  bool _disposed = false;

  SettingsState get state => _state;

  void setSoundEffects(bool on) =>
      _setState(_state.copyWith(soundEffectsOn: on));

  void setVoiceGuidance(bool on) =>
      _setState(_state.copyWith(voiceGuidanceOn: on));

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
