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

    group('the safety notice', () {
      test(
        'reads nothing saved as null for the switch and the seen mark',
        () async {
          FlutterSecureStorage.setMockInitialValues({});
          final saved = await SecureSettingsStore().readSafetyNotice();
          expect(saved.everyMatch, isNull);
          expect(saved.seen, isNull);
        },
      );

      test('the switch and the seen mark are there for a new store, as after '
          'a restart', () async {
        FlutterSecureStorage.setMockInitialValues({});
        await SecureSettingsStore().writeSafetyNoticeEveryMatch(false);
        await SecureSettingsStore().writeSafetyNoticeSeen();
        final saved = await SecureSettingsStore().readSafetyNotice();
        expect(saved.everyMatch, isFalse);
        expect(saved.seen, isTrue);
        await SecureSettingsStore().writeSafetyNoticeEveryMatch(true);
        expect(
          (await SecureSettingsStore().readSafetyNotice()).everyMatch,
          isTrue,
        );
      });

      test('each has its own key and leaves the sound switches and the '
          'login alone', () async {
        FlutterSecureStorage.setMockInitialValues({
          'gymrats.session': 'existing-login-session',
          'gymrats.settings.sound_effects': 'false',
        });
        await SecureSettingsStore().writeSafetyNoticeEveryMatch(false);
        await SecureSettingsStore().writeSafetyNoticeSeen();
        const storage = FlutterSecureStorage();
        expect(await storage.readAll(), {
          'gymrats.session': 'existing-login-session',
          'gymrats.settings.sound_effects': 'false',
          'gymrats.settings.safety_notice_every_match': 'false',
          'gymrats.settings.safety_notice_seen': 'true',
        });
        final sound = await SecureSettingsStore().read();
        expect(sound.soundEffectsOn, isFalse);
        expect(sound.voiceGuidanceOn, isNull);
      });

      test('anything but true or false reads as never saved', () async {
        FlutterSecureStorage.setMockInitialValues({
          'gymrats.settings.safety_notice_every_match': 'off',
          'gymrats.settings.safety_notice_seen': '1',
        });
        final saved = await SecureSettingsStore().readSafetyNotice();
        expect(saved.everyMatch, isNull);
        expect(saved.seen, isNull);
      });
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

  test(
    'MemorySettingsStore keeps the safety notice while the app runs',
    () async {
      final store = MemorySettingsStore();
      expect(await store.readSafetyNotice(), (everyMatch: null, seen: null));
      await store.writeSafetyNoticeEveryMatch(false);
      await store.writeSafetyNoticeSeen();
      expect(await store.readSafetyNotice(), (everyMatch: false, seen: true));
      // The sound switches are left as they were.
      expect(await store.read(), (soundEffectsOn: null, voiceGuidanceOn: null));
    },
  );
}
