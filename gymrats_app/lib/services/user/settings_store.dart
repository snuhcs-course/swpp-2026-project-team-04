import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The sound switches of 환경설정 as saved; null for one never saved.
typedef SavedSettings = ({bool? soundEffectsOn, bool? voiceGuidanceOn});

/// The 환경설정 switches, kept on this phone across app restarts. One set
/// for the phone, the same for every account, like the device itself.
abstract interface class SettingsStore {
  Future<SavedSettings> read();

  Future<void> writeSoundEffects(bool on);

  Future<void> writeVoiceGuidance(bool on);
}

class SecureSettingsStore implements SettingsStore {
  SecureSettingsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _soundEffectsKey = 'gymrats.settings.sound_effects';
  static const _voiceGuidanceKey = 'gymrats.settings.voice_guidance';

  @override
  Future<SavedSettings> read() async => (
    soundEffectsOn: _flag(await _storage.read(key: _soundEffectsKey)),
    voiceGuidanceOn: _flag(await _storage.read(key: _voiceGuidanceKey)),
  );

  @override
  Future<void> writeSoundEffects(bool on) =>
      _storage.write(key: _soundEffectsKey, value: '$on');

  @override
  Future<void> writeVoiceGuidance(bool on) =>
      _storage.write(key: _voiceGuidanceKey, value: '$on');

  /// Null for nothing saved, or for anything but what [write] saves.
  static bool? _flag(String? value) => switch (value) {
    'true' => true,
    'false' => false,
    _ => null,
  };
}

/// Keeps the switches only while the app runs. For tests and demos.
class MemorySettingsStore implements SettingsStore {
  bool? soundEffectsOn;
  bool? voiceGuidanceOn;

  @override
  Future<SavedSettings> read() async =>
      (soundEffectsOn: soundEffectsOn, voiceGuidanceOn: voiceGuidanceOn);

  @override
  Future<void> writeSoundEffects(bool on) async => soundEffectsOn = on;

  @override
  Future<void> writeVoiceGuidance(bool on) async => voiceGuidanceOn = on;
}
