import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/audio/just_audio_music_player.dart';
import 'package:just_audio/just_audio.dart';

/// Records the calls the adapter makes; everything else is unused.
class _RecordingAudioPlayer implements AudioPlayer {
  final calls = <String>[];
  bool failPitch = false;
  final playback = Completer<void>();

  @override
  Future<void> setLoopMode(LoopMode mode) async => calls.add('loop $mode');

  @override
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async {
    calls.add('asset $assetPath');
    return const Duration(seconds: 27);
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource audioSource, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    final clip = audioSource as ClippingAudioSource;
    final child = clip.child;
    calls.add('clip ${child.uri} from ${clip.start}');
    return const Duration(seconds: 25);
  }

  // Like just_audio: completes only when playback stops.
  @override
  Future<void> play() {
    calls.add('play');
    return playback.future;
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration? position, {int? index}) async =>
      calls.add('seek $position');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> setVolume(double volume) async => calls.add('volume $volume');

  @override
  Future<void> setSpeed(double speed) async => calls.add('speed $speed');

  @override
  Future<void> setPitch(double pitch) async {
    if (failPitch) throw UnimplementedError('setPitch');
    calls.add('pitch $pitch');
  }

  @override
  Future<void> dispose() async => calls.add('dispose');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingAudioPlayer audio;
  late JustAudioMusicPlayer player;

  setUp(() {
    audio = _RecordingAudioPlayer();
    player = JustAudioMusicPlayer(player: audio);
  });

  test('load sets the loop mode, then the bundled asset', () async {
    await player.load('assets/audio/bgm_menu.mp3', loop: true);
    await player.load('assets/audio/bgm_win.mp3', loop: false);
    expect(audio.calls, [
      'loop ${LoopMode.one}',
      'asset assets/audio/bgm_menu.mp3',
      'loop ${LoopMode.off}',
      'asset assets/audio/bgm_win.mp3',
    ]);
  });

  test('a start after zero clips the track, so its loop skips the intro '
      'too', () async {
    await player.load(
      'assets/audio/bgm_battle.ogg',
      loop: true,
      start: const Duration(milliseconds: 1540),
    );
    expect(audio.calls, [
      'loop ${LoopMode.one}',
      'clip asset:///assets/audio/bgm_battle.ogg from '
          '${const Duration(milliseconds: 1540)}',
    ]);
  });

  test('play returns at once although just_audio waits for the end', () async {
    await player.play().timeout(const Duration(milliseconds: 50));
    expect(audio.calls, ['play']);
    audio.playback.completeError(StateError('interrupted'));
    await pumpEventQueue();
  });

  test('pause, rewind, stop, volume and dispose pass through', () async {
    await player.pause();
    await player.seekToStart();
    await player.stop();
    await player.setVolume(0.25);
    await player.dispose();
    expect(audio.calls, [
      'pause',
      'seek ${Duration.zero}',
      'stop',
      'volume 0.25',
      'dispose',
    ]);
  });

  test('the rate sets speed and pitch together', () async {
    await player.setRate(feverRate);
    expect(audio.calls, ['speed $feverRate', 'pitch $feverRate']);
  });

  test('without pitch control the rate still sets the speed', () async {
    audio.failPitch = true;
    await player.setRate(feverRate);
    expect(audio.calls, ['speed $feverRate']);
  });
}
