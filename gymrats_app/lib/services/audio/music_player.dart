/// Plays one audio file: a music track or a sound effect. The real one wraps
/// `just_audio`; tests use a fake.
///
/// Screens never see this: they go through `BackgroundMusic`, which keeps
/// two of these to fade from one track into the next, and `SoundEffects`,
/// which keeps one per effect loaded and ready.
abstract interface class MusicPlayer {
  /// Loads the bundled [asset], e.g. `assets/audio/bgm_battle.ogg`, to play
  /// from [start] (the file's start by default), looping when [loop] is
  /// true. A loop also goes back to [start], so a skipped intro stays skipped.
  Future<void> load(
    String asset, {
    required bool loop,
    Duration start = Duration.zero,
  });

  /// Starts or resumes playback. Returns at once: `just_audio`'s own `play`
  /// only completes when playback stops.
  Future<void> play();

  Future<void> pause();

  /// Goes back to the start (the clip's start), so [play] plays it again
  /// from the top, also after it ended.
  Future<void> seekToStart();

  Future<void> stop();

  /// 0 (silent) to 1 (full).
  Future<void> setVolume(double volume);

  /// Playback rate: speed and pitch together, like a record played faster.
  /// 1 is normal.
  Future<void> setRate(double rate);

  /// Releases the player. It is not used again.
  Future<void> dispose();
}
