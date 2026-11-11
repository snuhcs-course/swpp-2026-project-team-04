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

/// The one sound switch: voice guidance, BGM, and the rep beep all follow it.
///
/// Starts on; [load] reads the saved value. Listeners (the audio services,
/// a toggle) are notified on every change.
class SoundSettings extends ChangeNotifier {
  SoundSettings({SoundSettingsStore? store, bool enabled = true})
    : _store = store ?? MemorySoundSettingsStore(enabled: enabled),
      _enabled = enabled;

  final SoundSettingsStore _store;
  bool _enabled;

  bool get enabled => _enabled;

  /// Reads the saved switch. A failing store leaves the current value.
  Future<void> load() async {
    try {
      _set(await _store.read());
    } catch (_) {
      // The default (on) stands.
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
