import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'music_player.dart';

/// [MusicPlayer] on `just_audio` (ExoPlayer on Android).
///
/// `just_audio` handles audio focus itself: while the voice guidance speaks
/// (it asks for transient focus that may duck), the music is ducked.
class JustAudioMusicPlayer implements MusicPlayer {
  JustAudioMusicPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> load(
    String asset, {
    required bool loop,
    Duration start = Duration.zero,
  }) async {
    await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    if (start == Duration.zero) {
      await _player.setAsset(asset);
      return;
    }
    // A clip, not a seek: the loop must come back to [start] too. One load,
    // so the clipped track is ready as soon as a plain one.
    await _player.setAudioSource(
      ClippingAudioSource(child: AudioSource.asset(asset), start: start),
    );
  }

  @override
  Future<void> play() async {
    // Completes only when playback pauses or ends, so it is not awaited.
    unawaited(_player.play().catchError((Object _) {}));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekToStart() => _player.seek(Duration.zero);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setRate(double rate) async {
    await _player.setSpeed(rate);
    try {
      await _player.setPitch(rate);
    } on Object {
      // A platform without pitch control plays it faster at the same pitch.
    }
  }

  @override
  Future<void> dispose() => _player.dispose();
}
