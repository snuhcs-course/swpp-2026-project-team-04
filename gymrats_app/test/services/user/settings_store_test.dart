import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/user/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureSettingsStore', () {
    test('reads nothing saved as null for both switches', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final saved = await SecureSettingsStore().read();
      expect(saved.soundEffectsOn, isNull);
      expect(saved.voiceGuidanceOn, isNull);
    });

    test(
      'a saved switch is there for a new store, as after a restart',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        await SecureSettingsStore().writeSoundEffects(false);
        await SecureSettingsStore().writeVoiceGuidance(true);
        final saved = await SecureSettingsStore().read();
        expect(saved.soundEffectsOn, isFalse);
        expect(saved.voiceGuidanceOn, isTrue);
      },
    );

    test('each switch has its own key and leaves the others alone', () async {
      FlutterSecureStorage.setMockInitialValues({
        'gymrats.session': 'existing-login-session',
      });
      await SecureSettingsStore().writeVoiceGuidance(true);
      const storage = FlutterSecureStorage();
      expect(
        await storage.read(key: 'gymrats.settings.voice_guidance'),
        'true',
      );
      expect(await storage.read(key: 'gymrats.settings.sound_effects'), isNull);
      expect(
        await storage.read(key: 'gymrats.session'),
        'existing-login-session',
      );
    });

    test('anything but true or false reads as never saved', () async {
      FlutterSecureStorage.setMockInitialValues({
        'gymrats.settings.sound_effects': 'yes',
        'gymrats.settings.voice_guidance': '',
      });
      final saved = await SecureSettingsStore().read();
      expect(saved.soundEffectsOn, isNull);
      expect(saved.voiceGuidanceOn, isNull);
    });
  });

  test(
    'MemorySettingsStore keeps what was written while the app runs',
    () async {
      final store = MemorySettingsStore();
      expect(await store.read(), (soundEffectsOn: null, voiceGuidanceOn: null));
      await store.writeSoundEffects(false);
      await store.writeVoiceGuidance(true);
      expect(await store.read(), (
        soundEffectsOn: false,
        voiceGuidanceOn: true,
      ));
    },
  );
}
