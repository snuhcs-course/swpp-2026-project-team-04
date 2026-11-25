import '../services/audio/background_music.dart';
import '../services/audio/sound_services.dart';

/// A hold stage's music from the arcade, in a fight stage's order (P16, with
/// A4's hold effects).
///
/// The hold screen asks for the battle's cues (setup, battle, the result's
/// jingle) and, when it closes before a result, for the menu track. This
/// passes them all on, except that menu track when the stage has not
/// started a track since it opened or since its last jingle:
///
/// - Left in the setup, the 3·2·1 or the hold: the menu comes back, as when
///   a battle is left before its result.
/// - Closed on its briefing, or in the second warning's moment after its
///   jingle started: what plays goes on, as a fight's sheet and versus
///   screen play nothing. After a jingle the map stays silent, as after a
///   fight; opened over the menu track, that track goes on.
class ArcadeHoldMusic implements BackgroundMusic {
  ArcadeHoldMusic(this._music);

  final BackgroundMusic _music;

  /// Whether a setup or battle track was asked for since the stage opened
  /// or since its last jingle.
  bool _started = false;

  /// [sounds] with its music in an [ArcadeHoldMusic]; its switches, voice
  /// and effects as they are.
  static SoundServices around(SoundServices sounds) => SoundServices(
    settings: sounds.settings,
    voice: sounds.voice,
    music: ArcadeHoldMusic(sounds.music),
    effects: sounds.effects,
  );

  @override
  void play(MusicCue cue) {
    switch (cue) {
      case MusicCue.menu:
        if (!_started) return;
        _started = false;
      case MusicCue.win || MusicCue.lose:
        _started = false;
      case MusicCue.setup || MusicCue.battle || MusicCue.fever:
        _started = true;
    }
    _music.play(cue);
  }

  @override
  void stop() => _music.stop();

  /// The app's music goes on after the stage: nothing to free here.
  @override
  void dispose() {}
}
