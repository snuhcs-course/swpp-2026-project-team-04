import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/voice_cue.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/audio/sound_effects.dart';
import 'package:gymrats_app/services/audio/sound_services.dart';
import 'package:gymrats_app/services/audio/voice_guidance.dart';

import '../../support/audio_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final wasUnderTest = SoundServices.underTest;
  tearDown(() {
    SoundServices.shared = null;
    SoundServices.underTest = wasUnderTest;
  });

  test('flutter test is detected, so screens tested without a sound set '
      'stay silent', () {
    expect(SoundServices.underTest, isTrue);
    final shared = SoundServices.shared;
    expect(shared.voice, isA<SilentVoiceGuidance>());
    expect(shared.music, isA<SilentBackgroundMusic>());
    expect(shared.effects, isA<SilentSoundEffects>());
    expect(SoundServices.shared, same(shared));
  });

  test('the silent set takes every call and does nothing', () {
    final silent = SoundServices.silent();
    silent.voice
      ..say(VoiceCue.ready)
      ..stop()
      ..reset()
      ..dispose();
    silent.music
      ..play(MusicCue.battle)
      ..stop()
      ..dispose();
    silent.effects
      ..prepare()
      ..play(SoundEffect.good)
      ..setDanger(true)
      ..dispose();
    expect(silent.settings.enabled, isTrue);
  });

  test('the device set shares the switches between voice, music and '
      'effects, and is silent until 환경설정 passes them on', () {
    final services = SoundServices.device();
    expect(services.voice, isA<VoiceGuidanceService>());
    expect(services.music, isA<BackgroundMusicService>());
    expect(services.effects, isA<SoundEffectsService>());
    expect(services.settings.enabled, isFalse);
    expect(services.settings.voiceEnabled, isFalse);
    services.voice.dispose();
    services.music.dispose();
    services.effects.dispose();
  });

  test('outside flutter test the shared set is the device set, made once', () {
    SoundServices.underTest = false;
    final shared = SoundServices.shared;
    expect(shared.music, isA<BackgroundMusicService>());
    expect(SoundServices.shared, same(shared));
    shared.voice.dispose();
    shared.music.dispose();
    shared.effects.dispose();
  });

  test('tests can put in their own set', () {
    final fake = fakeSoundServices();
    SoundServices.shared = fake;
    expect(SoundServices.shared, same(fake));
  });
}
