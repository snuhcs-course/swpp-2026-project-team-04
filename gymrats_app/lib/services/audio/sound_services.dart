import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/voice_cue.dart';
import 'background_music.dart';
import 'just_audio_music_player.dart';
import 'sound_effects.dart';
import 'sound_settings.dart';
import 'tts_speech_engine.dart';
import 'voice_guidance.dart';

/// The app's sound, in one place: the sound switches, the voice guidance,
/// the background music and the battle's sound effects. Every screen shares
/// one set, so the music fades from one screen's cue into the next instead
/// of starting over.
///
/// The sound widget and the settings toggle read [SoundServices.shared]
/// unless they are given a set. Under `flutter test` the shared set is
/// [SoundServices.silent], so a screen's widget test that does not think
/// about sound never reaches the TTS or audio plugins or leaves timers.
class SoundServices {
  SoundServices({
    required this.settings,
    required this.voice,
    required this.music,
    required this.effects,
  });

  /// The real set: device TTS, `just_audio`. Silent until 환경설정's saved
  /// switches arrive (`SettingsViewModel.load` passes them on), so a user
  /// who turned sound off never hears the first moment of a track.
  factory SoundServices.device() {
    final settings = SoundSettings(
      store: MemorySoundSettingsStore(),
      enabled: false,
      voiceEnabled: false,
    );
    return SoundServices(
      settings: settings,
      voice: VoiceGuidanceService(
        engine: TtsSpeechEngine(),
        settings: settings,
      ),
      music: BackgroundMusicService(
        newPlayer: JustAudioMusicPlayer.new,
        settings: settings,
      ),
      effects: SoundEffectsService(
        newPlayer: JustAudioMusicPlayer.new,
        settings: settings,
      ),
    );
  }

  /// A set that plays nothing.
  factory SoundServices.silent() => SoundServices(
    settings: SoundSettings(store: MemorySoundSettingsStore()),
    voice: const SilentVoiceGuidance(),
    music: const SilentBackgroundMusic(),
    effects: const SilentSoundEffects(),
  );

  final SoundSettings settings;
  final VoiceGuidance voice;
  final BackgroundMusic music;
  final SoundEffects effects;

  /// Whether this runs under `flutter test`, where the shared set is silent.
  @visibleForTesting
  static bool underTest = Platform.environment.containsKey('FLUTTER_TEST');

  static SoundServices? _shared;

  /// The app-wide set, made on first use.
  static SoundServices get shared =>
      _shared ??= underTest ? SoundServices.silent() : SoundServices.device();

  /// Uses [services] as the app-wide set (or forgets it with null), for tests.
  static set shared(SoundServices? services) => _shared = services;
}

/// [VoiceGuidance] that says nothing.
class SilentVoiceGuidance implements VoiceGuidance {
  const SilentVoiceGuidance();

  @override
  void say(VoiceCue cue) {}

  @override
  void stop() {}

  @override
  void reset() {}

  @override
  void dispose() {}
}

/// [SoundEffects] that play nothing.
class SilentSoundEffects implements SoundEffects {
  const SilentSoundEffects();

  @override
  void prepare() {}

  @override
  void play(SoundEffect effect) {}

  @override
  void setDanger(bool on) {}

  @override
  void release() {}

  @override
  void dispose() {}
}

/// [BackgroundMusic] that plays nothing.
class SilentBackgroundMusic implements BackgroundMusic {
  const SilentBackgroundMusic();

  @override
  void play(MusicCue cue) {}

  @override
  void stop() {}

  @override
  void dispose() {}
}
