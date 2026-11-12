import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The sound switches of 환경설정 as saved; null for one never saved.
typedef SavedSettings = ({bool? soundEffectsOn, bool? voiceGuidanceOn});

/// The '매 경기 안전 안내' switch of 환경설정 as saved: whether the safety
/// notice shows before every match, and whether it was ever seen; null for
/// one never saved.
typedef SavedSafetyNotice = ({bool? everyMatch, bool? seen});

/// The 환경설정 switches, kept on this phone across app restarts. One set
/// for the phone, the same for every account, like the device itself.
abstract interface class SettingsStore {
  Future<SavedSettings> read();

  Future<void> writeSoundEffects(bool on);

  Future<void> writeVoiceGuidance(bool on);

  /// The safety notice's switch and whether the notice was seen.
  Future<SavedSafetyNotice> readSafetyNotice();

  Future<void> writeSafetyNoticeEveryMatch(bool on);

  /// Notes that the safety notice was seen; nothing takes it back.
  Future<void> writeSafetyNoticeSeen();
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

  static const _safetyNoticeEveryMatchKey =
      'gymrats.settings.safety_notice_every_match';
  static const _safetyNoticeSeenKey = 'gymrats.settings.safety_notice_seen';

  @override
  Future<SavedSafetyNotice> readSafetyNotice() async => (
    everyMatch: _flag(await _storage.read(key: _safetyNoticeEveryMatchKey)),
    seen: _flag(await _storage.read(key: _safetyNoticeSeenKey)),
  );

  @override
  Future<void> writeSafetyNoticeEveryMatch(bool on) =>
      _storage.write(key: _safetyNoticeEveryMatchKey, value: '$on');

  @override
  Future<void> writeSafetyNoticeSeen() =>
      _storage.write(key: _safetyNoticeSeenKey, value: 'true');

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

  bool? safetyNoticeEveryMatch;
  bool? safetyNoticeSeen;

  @override
  Future<SavedSafetyNotice> readSafetyNotice() async =>
      (everyMatch: safetyNoticeEveryMatch, seen: safetyNoticeSeen);

  @override
  Future<void> writeSafetyNoticeEveryMatch(bool on) async =>
      safetyNoticeEveryMatch = on;

  @override
  Future<void> writeSafetyNoticeSeen() async => safetyNoticeSeen = true;
}
