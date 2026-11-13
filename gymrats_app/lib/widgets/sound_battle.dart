import '../services/audio/background_music.dart';
import '../services/audio/sound_effects.dart';
import '../services/audio/sound_services.dart';
import '../services/device/device_controls.dart';
import 'battle_stage_model.dart';

/// The battle's sound, for the bot and the online battle screens. A screen
/// keeps one for its life and gives it what its stage shows:
///
/// - [show] with the stage's state on every build: the music by phase (setup,
///   battle, fever, the result's jingle) and the danger alarm;
/// - [cue] as the stage's `onCue`: my rep's hit by grade, my miss, the KO.
///
/// The effects say how each rep went, and the opponent's reps make no sound
/// (user 2026-11-12). The battle has no voice: the setup's spoken hints were
/// dropped after the phone check (user 2026-11-14). [dispose] stops the
/// alarm and frees the effects.
class BattleSounds {
  BattleSounds({SoundServices? services})
    : _services = services ?? SoundServices.shared {
    _services.effects.prepare();
  }

  final SoundServices _services;
  bool _disposed = false;

  /// The music for the stage; null keeps what plays: while the server's
  /// result is awaited the battle music goes on, and a draw lets it fade out
  /// (see [show]).
  static MusicCue? musicFor(BattleStageState stage) => switch (stage.phase) {
    BattleStagePhase.setup || BattleStagePhase.countdown => MusicCue.setup,
    BattleStagePhase.playing => stage.fever ? MusicCue.fever : MusicCue.battle,
    BattleStagePhase.ended => switch (stage.end?.winner) {
      BattleSide.me => MusicCue.win,
      BattleSide.opponent => MusicCue.lose,
      null => null,
    },
  };

  /// Follows the stage: the music and the danger alarm, which repeats only
  /// while the round is on. The same state again changes nothing.
  void show(BattleStageState stage) {
    if (_disposed) return;
    final music = musicFor(stage);
    if (music != null) {
      _services.music.play(music);
    } else if (stage.phase == BattleStagePhase.ended &&
        (stage.end?.decided ?? false)) {
      _services.music.stop(); // A draw: no jingle.
    }
    _services.effects.setDanger(
      stage.danger && stage.phase == BattleStagePhase.playing,
    );
  }

  /// A moment of the stage, as it shows. Only my reps and the KO sound.
  void cue(BattleStageCue cue) {
    if (_disposed) return;
    final effect = switch (cue.kind) {
      BattleCueKind.hit when cue.side == BattleSide.me => SoundEffect.forRep(
        cue.grade,
      ),
      BattleCueKind.miss when cue.side == BattleSide.me => SoundEffect.reject,
      BattleCueKind.knockout => SoundEffect.ko,
      _ => null,
    };
    if (effect != null) _services.effects.play(effect);
  }

  /// The battle ended without a result (cancelled, void, a connection
  /// error): the alarm and the battle music stop. Safe to call on every
  /// build.
  void ended() {
    if (_disposed) return;
    _services.effects.setDanger(false);
    _services.music.stop();
  }

  /// Stops the alarm and frees the effects; the music goes on into the next
  /// screen.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _services.effects
      ..setDanger(false)
      ..release();
  }
}

/// A rep beep that stays quiet: in the battle the hit sounds take its place.
class NoRepBeep implements RepSound {
  const NoRepBeep();

  @override
  void playRepCounted() {}
}
