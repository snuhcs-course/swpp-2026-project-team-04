import 'dart:async';

import 'package:gymrats_app/models/voice_cue.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/audio/music_player.dart';
import 'package:gymrats_app/services/audio/sound_effects.dart';
import 'package:gymrats_app/services/audio/sound_services.dart';
import 'package:gymrats_app/services/audio/sound_settings.dart';
import 'package:gymrats_app/services/audio/speech_engine.dart';
import 'package:gymrats_app/services/audio/voice_guidance.dart';

/// Records what was spoken. By default an utterance ends at once; with
/// [manual], it lasts until [finish] (or [stop]) so tests can queue lines.
class FakeSpeechEngine implements SpeechEngine {
  FakeSpeechEngine({this.manual = false});

  final bool manual;
  final spoken = <String>[];
  int stops = 0;

  /// Thrown by [speak] and [stop] when set: a phone without a Korean voice.
  Object? failure;

  Completer<void>? _utterance;

  bool get speaking => !(_utterance?.isCompleted ?? true);

  @override
  Future<void> speak(String text) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    spoken.add(text);
    if (!manual) return;
    final utterance = Completer<void>();
    _utterance = utterance;
    return utterance.future;
  }

  /// Ends the current utterance, as the TTS engine does when it is done.
  void finish() {
    final utterance = _utterance;
    if (utterance != null && !utterance.isCompleted) utterance.complete();
  }

  @override
  Future<void> stop() async {
    stops++;
    final failure = this.failure;
    if (failure != null) throw failure;
    finish();
  }
}

/// Records the cues a screen or widget asked for.
///
/// A widget that owns a real `VoiceGuidanceService` must call `dispose()`
/// (or `stop()`) when it goes away: the service keeps a timer per line, and
/// a widget test ends with "A Timer is still pending" otherwise.
class FakeVoiceGuidance implements VoiceGuidance {
  final said = <VoiceCue>[];
  int stops = 0;
  int resets = 0;
  bool disposed = false;

  @override
  void say(VoiceCue cue) => said.add(cue);

  @override
  void stop() => stops++;

  @override
  void reset() => resets++;

  @override
  void dispose() => disposed = true;
}

/// Records what one player was told. [failLoad] makes [load] throw: a missing
/// file or no audio output.
class FakeMusicPlayer implements MusicPlayer {
  FakeMusicPlayer({this.failLoad = false});

  final bool failLoad;
  String? asset;
  bool? loop;
  Duration? start;
  double volume = 1;
  double rate = 1;
  bool playing = false;
  bool stopped = false;
  bool disposed = false;
  final volumes = <double>[];

  /// Completes [load]; null loads at once.
  Completer<void>? loadGate;

  @override
  Future<void> load(
    String asset, {
    required bool loop,
    Duration start = Duration.zero,
  }) async {
    await loadGate?.future;
    if (failLoad) throw StateError('no such asset');
    this.asset = asset;
    this.loop = loop;
    this.start = start;
  }

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;

  /// How many times it went back to the start.
  int rewinds = 0;

  @override
  Future<void> seekToStart() async => rewinds++;

  @override
  Future<void> stop() async {
    playing = false;
    stopped = true;
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
    volumes.add(volume);
  }

  @override
  Future<void> setRate(double rate) async => this.rate = rate;

  @override
  Future<void> dispose() async => disposed = true;
}

/// Hands out [FakeMusicPlayer]s and keeps them, newest last.
class FakeMusicPlayers {
  final made = <FakeMusicPlayer>[];

  /// The next player's load fails when true.
  bool failNext = false;

  FakeMusicPlayer call() {
    final player = FakeMusicPlayer(failLoad: failNext);
    failNext = false;
    made.add(player);
    return player;
  }

  FakeMusicPlayer get last => made.last;
}

/// Records the music cues a screen or widget asked for.
///
/// A widget test that uses a real `BackgroundMusicService` must `dispose()`
/// it: fades run on timers.
class FakeBackgroundMusic implements BackgroundMusic {
  final played = <MusicCue>[];
  int stops = 0;
  bool disposed = false;

  @override
  void play(MusicCue cue) => played.add(cue);

  @override
  void stop() => stops++;

  @override
  void dispose() => disposed = true;
}

/// Records the effects asked for and the danger alarm's state.
class FakeSoundEffects implements SoundEffects {
  int prepares = 0;
  final played = <SoundEffect>[];

  /// Every change of the alarm, in order.
  final dangers = <bool>[];
  bool get danger => dangers.isNotEmpty && dangers.last;
  bool disposed = false;

  @override
  void prepare() => prepares++;

  @override
  void play(SoundEffect effect) => played.add(effect);

  @override
  void setDanger(bool on) {
    if (on != danger) dangers.add(on);
  }

  int releases = 0;

  @override
  void release() {
    releases++;
    if (danger) dangers.add(false);
  }

  @override
  void dispose() => disposed = true;
}

/// A sound set of fakes, with the switches on.
SoundServices fakeSoundServices() => SoundServices(
  settings: SoundSettings(store: MemorySoundSettingsStore()),
  voice: FakeVoiceGuidance(),
  music: FakeBackgroundMusic(),
  effects: FakeSoundEffects(),
);
