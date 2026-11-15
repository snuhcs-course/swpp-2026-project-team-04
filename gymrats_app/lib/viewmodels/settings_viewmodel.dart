import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/audio/sound_services.dart';
import '../services/audio/sound_settings.dart';
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

/// The '매 경기 안전 안내' switch of 환경설정 and whether the safety notice
/// was seen on this phone: on, the notice shows before every match; off,
/// only until it was seen once.
@immutable
class SafetyNoticeSetting {
  const SafetyNoticeSetting({this.everyMatch = true, this.seen = false});

  /// The switch: the notice before every match. On, as designed.
  final bool everyMatch;

  /// Whether the notice was ever seen to its end (확인, or closed by itself
  /// online).
  final bool seen;

  /// Whether the next match opens with the notice.
  bool get showsBeforeMatch => everyMatch || !seen;
}

/// The app's settings, one for the whole app (provided in main.dart above
/// every screen), so 환경설정 shows the same values each time it opens and
/// any screen can read them.
///
/// The switches are saved in [SettingsStore] and read back by [load], so
/// they stay after the app restarts. Read [state] (or listen) where sound
/// plays; every setter call notifies. The safety notice's switch and
/// whether the notice was seen are [safetyNotice], kept the same way.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    SettingsStore? store,
    bool soundEffectsOn = true,
    bool voiceGuidanceOn = false,
    this._sound,
  }) : _store = store ?? MemorySettingsStore(),
       _state = SettingsState(
         soundEffectsOn: soundEffectsOn,
         voiceGuidanceOn: voiceGuidanceOn,
       );

  final SettingsStore _store;

  /// The app's sound switches the 효과음 and 음성 안내 switches feed; the
  /// shared sound set's when null.
  final SoundSettings? _sound;
  SettingsState _state;
  bool _disposed = false;

  /// Switches the user turned while [load] was reading; theirs win.
  bool _soundEffectsTurned = false;
  bool _voiceGuidanceTurned = false;

  SettingsState get state => _state;

  SafetyNoticeSetting _safetyNotice = const SafetyNoticeSetting();

  /// The safety switch turned while [load] was reading; the user's wins.
  bool _safetyNoticeTurned = false;

  SafetyNoticeSetting get safetyNotice => _safetyNotice;

  /// Shows the saved switches; one never saved keeps its default. Until it
  /// finishes the defaults show. If reading fails the defaults stay.
  Future<void> load() async {
    final bool safetyNoticeRead;
    try {
      safetyNoticeRead = await _loadSafetyNotice();
    } catch (_) {
      _passToSound(); // The app's sound waits for the switches: defaults.
      rethrow;
    }
    final SavedSettings saved;
    try {
      saved = await _store.read();
    } on Exception {
      if (safetyNoticeRead && !_disposed) notifyListeners();
      _passToSound(); // The app's sound waits for the switches: defaults.
      return;
    } catch (_) {
      _passToSound();
      rethrow;
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
    _passToSound();
  }

  void setSoundEffects(bool on) {
    if (_disposed) return;
    _soundEffectsTurned = true;
    _setState(_state.copyWith(soundEffectsOn: on));
    _passToSound();
    _save(_store.writeSoundEffects(on));
  }

  void setVoiceGuidance(bool on) {
    if (_disposed) return;
    _voiceGuidanceTurned = true;
    _setState(_state.copyWith(voiceGuidanceOn: on));
    _passToSound();
    _save(_store.writeVoiceGuidance(on));
  }

  /// Turns '매 경기 안전 안내' on (the notice before every match) or off
  /// (only until it was seen once), and saves it.
  void setSafetyNoticeEveryMatch(bool on) {
    if (_disposed) return;
    _safetyNoticeTurned = true;
    _safetyNotice = SafetyNoticeSetting(
      everyMatch: on,
      seen: _safetyNotice.seen,
    );
    notifyListeners();
    _save(_store.writeSafetyNoticeEveryMatch(on));
  }

  /// Notes that the safety notice was seen to its end, and saves it once.
  void markSafetyNoticeSeen() {
    if (_disposed || _safetyNotice.seen) return;
    _safetyNotice = SafetyNoticeSetting(
      everyMatch: _safetyNotice.everyMatch,
      seen: true,
    );
    notifyListeners();
    _save(_store.writeSafetyNoticeSeen());
  }

  /// Reads the safety notice's saved values into [safetyNotice] without
  /// telling the listeners ([load] does once); false when nothing was read.
  /// A switch the user turned meanwhile stays; a notice seen stays seen.
  Future<bool> _loadSafetyNotice() async {
    final SavedSafetyNotice saved;
    try {
      saved = await _store.readSafetyNotice();
    } on Exception {
      return false;
    }
    if (_disposed) return false;
    _safetyNotice = SafetyNoticeSetting(
      everyMatch: _safetyNoticeTurned
          ? _safetyNotice.everyMatch
          : saved.everyMatch ?? _safetyNotice.everyMatch,
      seen: _safetyNotice.seen || (saved.seen ?? false),
    );
    return true;
  }

  /// The app's sound follows the switches: 효과음 turns the BGM and the
  /// effects on or off, 음성 안내 the voice guidance. The sound starts
  /// silent and waits for [load] to pass the saved switches on.
  void _passToSound() {
    final sound = _sound ?? SoundServices.shared.settings;
    unawaited(sound.setEnabled(_state.soundEffectsOn));
    sound.setVoiceEnabled(_state.voiceGuidanceOn);
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
