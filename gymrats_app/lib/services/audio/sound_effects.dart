import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../models/game_score.dart';
import 'music_player.dart';
import 'sound_settings.dart';

/// A short battle sound. In the battle the effects take the voice's place:
/// each of the user's reps sounds by its result. Sources and the team's pick
/// in `docs/iteration-4/sound-battle-bgm.md`.
enum SoundEffect {
  /// A Good rep: one punch.
  good('assets/audio/sfx_hit_good.wav'),

  /// An Excellent rep: a one-two punch.
  excellent('assets/audio/sfx_hit_excellent.wav'),

  /// A rejected rep that still earned Average points: a light hit.
  average('assets/audio/sfx_hit_average.wav'),

  /// A rejected rep with no points: a low double buzz.
  reject('assets/audio/sfx_reject.wav'),

  /// The round ended by KO: a gong.
  ko('assets/audio/sfx_ko.wav');

  const SoundEffect(this.asset);

  final String asset;

  /// The sound of one of the user's reps: the hit for its [grade], or
  /// [reject] for a rep that earned nothing (null). The opponent's reps make
  /// no sound (user 2026-11-12).
  static SoundEffect forRep(GameGrade? grade) => switch (grade) {
    null => reject,
    GameGrade.average => average,
    GameGrade.good => good,
    GameGrade.excellent => excellent,
  };
}

/// The warning that repeats while the user is in danger (60 points behind):
/// a two-tone beep, about 1 s, looped.
const dangerAlarmAsset = 'assets/audio/sfx_danger.wav';

/// The battle's sound effects. What the battle sound widget talks to; the
/// audio plugin stays behind [MusicPlayer].
abstract interface class SoundEffects {
  /// Loads every effect so the first hit plays at once. Safe to call again.
  void prepare();

  /// Plays [effect] from the start, cutting off the same effect if it is
  /// still playing.
  void play(SoundEffect effect);

  /// Starts the looping danger alarm, or stops it.
  void setDanger(bool on);

  /// Stops everything and frees the players until the next [prepare]; the
  /// battle screen calls it when it closes.
  void release();

  /// Releases the players and stops listening to the sound switch and the
  /// app lifecycle for good.
  void dispose();
}

/// [SoundEffects] with one loaded [MusicPlayer] per effect, so a hit only
/// has to rewind and play: no file is opened when the rep lands.
///
/// - [SoundSettings.enabled] false, or the app not in the foreground,
///   silences the effects and pauses the alarm; the alarm comes back with
///   the sound if the user is still in danger.
/// - Player failures are ignored: a missing effect is not worth stopping the
///   battle for.
class SoundEffectsService with WidgetsBindingObserver implements SoundEffects {
  SoundEffectsService({required this._newPlayer, required this._settings}) {
    _settings.addListener(_onSilenceChanged);
    final binding = WidgetsBinding.instance;
    final state = binding.lifecycleState;
    _inForeground = state == null || state == AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  final MusicPlayer Function() _newPlayer;
  final SoundSettings _settings;

  final _players = <SoundEffect, MusicPlayer>{};
  final _ready = <MusicPlayer>{};
  MusicPlayer? _alarm;
  bool _danger = false;
  late bool _inForeground;
  bool _disposed = false;

  bool get _silenced => !_settings.enabled || !_inForeground;

  /// Whether the danger alarm should be sounding (it may be silenced).
  bool get danger => _danger;

  @override
  void prepare() {
    if (_disposed || _alarm != null) return;
    for (final effect in SoundEffect.values) {
      _players[effect] = _loaded(effect.asset, loop: false);
    }
    _alarm = _loaded(dangerAlarmAsset, loop: true);
  }

  MusicPlayer _loaded(String asset, {required bool loop}) {
    final player = _newPlayer();
    unawaited(() async {
      try {
        await player.load(asset, loop: loop);
      } on Object {
        return; // Never ready: that effect stays silent.
      }
      // Released (or disposed) while it loaded: never used.
      if (_disposed || !_isCurrent(player)) return;
      _ready.add(player);
      if (identical(player, _alarm) && _danger && !_silenced) _startAlarm();
    }());
    return player;
  }

  bool _isCurrent(MusicPlayer player) =>
      identical(player, _alarm) || _players.containsValue(player);

  @override
  void play(SoundEffect effect) {
    if (_disposed || _silenced) return;
    final player = _players[effect];
    if (player == null || !_ready.contains(player)) return;
    _quietly(() async {
      await player.seekToStart();
      await player.play();
    });
  }

  @override
  void setDanger(bool on) {
    if (_disposed || on == _danger) return;
    _danger = on;
    if (on && !_silenced) {
      _startAlarm();
    } else {
      _pauseAlarm();
    }
  }

  void _startAlarm() {
    final alarm = _alarm;
    if (alarm == null || !_ready.contains(alarm)) return;
    _quietly(() async {
      await alarm.seekToStart();
      // Danger may have ended, or the sound gone, while it rewound.
      if (_danger && !_silenced && !_disposed) await alarm.play();
    });
  }

  void _pauseAlarm() {
    final alarm = _alarm;
    if (alarm != null) _quietly(alarm.pause);
  }

  void _onSilenceChanged() {
    if (_disposed) return;
    if (_silenced) {
      _pauseAlarm();
    } else if (_danger) {
      _startAlarm();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    _onSilenceChanged();
  }

  @override
  void release() {
    _danger = false;
    final alarm = _alarm;
    for (final player in [..._players.values, ?alarm]) {
      _quietly(player.stop);
      _quietly(player.dispose);
    }
    _players.clear();
    _ready.clear();
    _alarm = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    release();
    _settings.removeListener(_onSilenceChanged);
    WidgetsBinding.instance.removeObserver(this);
  }

  static void _quietly(Future<void> Function() action) {
    unawaited(Future.sync(action).catchError((Object _) {}));
  }
}
