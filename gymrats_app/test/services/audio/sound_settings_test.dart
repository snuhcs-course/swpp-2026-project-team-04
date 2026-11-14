import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/audio/sound_settings.dart';

class _BrokenStore implements SoundSettingsStore {
  @override
  Future<bool> read() async => throw StateError('no storage');

  @override
  Future<void> write({required bool enabled}) async =>
      throw StateError('no storage');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundSettings', () {
    test('sound is on until the saved switch says otherwise', () async {
      final settings = SoundSettings(
        store: MemorySoundSettingsStore(enabled: false),
      );
      expect(settings.enabled, isTrue);
      await settings.load();
      expect(settings.enabled, isFalse);
    });

    test('turning the sound off notifies and is saved', () async {
      final store = MemorySoundSettingsStore();
      final settings = SoundSettings(store: store);
      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setEnabled(false);
      expect(settings.enabled, isFalse);
      expect(store.enabled, isFalse);
      expect(notified, 1);

      await settings.setEnabled(false);
      expect(notified, 1, reason: 'no change, no notification');

      await settings.setEnabled(true);
      expect(settings.enabled, isTrue);
      expect(store.enabled, isTrue);
      expect(notified, 2);
    });

    test('without a store the switch is saved securely and survives a '
        'restart', () async {
      FlutterSecureStorage.setMockInitialValues({});
      await SoundSettings().setEnabled(false);
      final restarted = SoundSettings();
      await restarted.load();
      expect(restarted.enabled, isFalse);
    });

    test('a failing store turns on a set that started silent', () async {
      final settings = SoundSettings(store: _BrokenStore(), enabled: false);
      await settings.load();
      expect(settings.enabled, isTrue);
    });

    test('a failing store keeps the default and still flips the switch for '
        'this run', () async {
      final settings = SoundSettings(store: _BrokenStore());
      await settings.load();
      expect(settings.enabled, isTrue);
      await settings.setEnabled(false);
      expect(settings.enabled, isFalse);
    });
  });

  group('voice switch', () {
    test('on unless given; changes alone and tells the listeners once', () {
      final settings = SoundSettings(store: MemorySoundSettingsStore());
      expect(settings.voiceEnabled, isTrue);
      expect(
        SoundSettings(
          store: MemorySoundSettingsStore(),
          voiceEnabled: false,
        ).voiceEnabled,
        isFalse,
      );
      var calls = 0;
      settings
        ..addListener(() => calls++)
        ..setVoiceEnabled(false)
        ..setVoiceEnabled(false);
      expect(settings.voiceEnabled, isFalse);
      expect(settings.enabled, isTrue, reason: 'the sound switch stays');
      expect(calls, 1);
    });
  });

  group('SecureSoundSettingsStore', () {
    test('nothing saved means on; only a saved "false" means off', () async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await SecureSoundSettingsStore().read(), isTrue);
      FlutterSecureStorage.setMockInitialValues({
        SecureSoundSettingsStore.key: 'unexpected',
      });
      expect(await SecureSoundSettingsStore().read(), isTrue);
    });

    test('the switch survives a new store, apart from the session', () async {
      FlutterSecureStorage.setMockInitialValues({
        'gymrats.session': 'existing-login-session',
      });
      await SecureSoundSettingsStore().write(enabled: false);
      expect(await SecureSoundSettingsStore().read(), isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'gymrats.session'),
        'existing-login-session',
      );
      await SecureSoundSettingsStore().write(enabled: true);
      expect(await SecureSoundSettingsStore().read(), isTrue);
    });
  });
}
