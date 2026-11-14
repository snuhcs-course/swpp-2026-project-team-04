import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the sound switch is kept between launches. Device-wide, not per
/// account: it is a phone setting, like the volume.
abstract interface class SoundSettingsStore {
  /// True when nothing is saved: sound is on by default.
  Future<bool> read();

  Future<void> write({required bool enabled});
}

class SecureSoundSettingsStore implements SoundSettingsStore {
  SecureSoundSettingsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'gymrats.sound_enabled';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> read() async => await _storage.read(key: key) != 'false';

  @override
  Future<void> write({required bool enabled}) =>
      _storage.write(key: key, value: '$enabled');
}

/// Keeps the switch only while the app runs. For tests and demos.
class MemorySoundSettingsStore implements SoundSettingsStore {
  MemorySoundSettingsStore({this.enabled = true});

  bool enabled;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write({required bool enabled}) async {
    this.enabled = enabled;
  }
}

/// The app's two sound switches, as the audio services read them:
/// [enabled] for the sound (BGM, effects, the rep beep) and [voiceEnabled]
/// for the voice guidance. They match 환경설정's 효과음 and 음성 안내
/// switches, which `SettingsViewModel` saves and passes on here.
///
/// [enabled] starts on unless given; [load] reads a value saved in [store]
/// ([SecureSoundSettingsStore] unless another is given; tests and demos pass
/// a [MemorySoundSettingsStore]). Listeners (the audio services) are notified
/// on every change.
class SoundSettings extends ChangeNotifier {
  SoundSettings({
    SoundSettingsStore? store,
    this._enabled = true,
    this._voiceEnabled = true,
  }) : _store = store ?? SecureSoundSettingsStore();

  final SoundSettingsStore _store;
  bool _enabled;
  bool _voiceEnabled;

  /// Whether the BGM and the sound effects play (and the rep beep where it is
  /// given these settings).
  bool get enabled => _enabled;

  /// Whether the voice guidance speaks.
  bool get voiceEnabled => _voiceEnabled;

  /// Turns the voice guidance on or off for this run (`SettingsViewModel`
  /// keeps it between launches).
  void setVoiceEnabled(bool enabled) {
    if (enabled == _voiceEnabled) return;
    _voiceEnabled = enabled;
    notifyListeners();
  }

  /// Reads the saved switch. A failing store means on, the default, so a
  /// set started silent (`enabled: false`) until the saved value is known
  /// still gets its sound.
  Future<void> load() async {
    try {
      _set(await _store.read());
    } catch (_) {
      _set(true);
    }
  }

  /// Turns the sound on or off and saves it. A failing store still flips
  /// the switch for this run.
  Future<void> setEnabled(bool enabled) async {
    _set(enabled);
    try {
      await _store.write(enabled: enabled);
    } catch (_) {
      // Kept for this run only.
    }
  }

  void _set(bool enabled) {
    if (enabled == _enabled) return;
    _enabled = enabled;
    notifyListeners();
  }
}
