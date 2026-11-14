import 'dart:async';

import 'package:flutter/widgets.dart';

import 'music_player.dart';
import 'sound_settings.dart';

/// How much faster the battle track plays during fever (speed and pitch).
const feverRate = 1.25;

/// The battle music's volume, lower than the menus so the hit sounds stand
/// out (the team page's mix: effects about twice as loud as the music).
const battleVolume = 0.5;

/// The first beat of the battle track; its quiet build-up before it is
/// skipped.
const battleStart = Duration(milliseconds: 1540);

/// What the music should be for the screen or round phase now. All tracks
/// are CC0 from OpenGameArt; sources in `docs/iteration-4/sound-battle-bgm.md`.
enum MusicCue {
  /// Home, lobby and the other menu screens: "Menu Theme" (tamesu).
  menu('assets/audio/bgm_menu.mp3'),

  /// Pose setup and waiting for the opponent: "Laid Back".
  setup('assets/audio/bgm_setup.ogg'),

  /// The round before fever: "Fast Fight / Battle Music", from its first
  /// beat (the quiet 1.5 s build-up is skipped) and faded in quickly, so the
  /// music hits when the round starts.
  battle(
    'assets/audio/bgm_battle.ogg',
    start: battleStart,
    fadeIn: Duration(milliseconds: 150),
    volume: battleVolume,
  ),

  /// Fever, the last 10 s of the round: the battle track played faster.
  fever(
    'assets/audio/bgm_battle.ogg',
    rate: feverRate,
    start: battleStart,
    fadeIn: Duration(milliseconds: 150),
    volume: battleVolume,
  ),

  /// The round was won: the "Victory" jingle, once.
  win('assets/audio/bgm_win.mp3', loop: false),

  /// The round was lost: the "Game Over!" jingle, once.
  lose('assets/audio/bgm_lose.m4a', loop: false);

  const MusicCue(
    this.asset, {
    this.loop = true,
    this.rate = 1,
    this.start = Duration.zero,
    this.fadeIn,
    this.volume = 1,
  });

  final String asset;

  /// Where the track starts, and where its loop comes back to.
  final Duration start;

  /// How long the track takes to fade in; the service's fade when null.
  final Duration? fadeIn;

  /// The track's full volume, 0 to 1.
  final double volume;

  /// Loops until the next cue; otherwise plays once (a result jingle).
  final bool loop;

  /// Playback rate, 1 for normal.
  final double rate;
}

/// The background music of the menus and the battle. What screens and the
/// sound widget talk to; the audio plugin stays behind [MusicPlayer].
///
/// [play] may be called on every frame or state change with the current cue:
/// the music changes only when the cue does.
abstract interface class BackgroundMusic {
  /// Changes the music to [cue]; the same cue again does nothing.
  void play(MusicCue cue);

  /// Fades the music out and forgets the cue.
  void stop();

  /// Stops at once and stops listening to the sound switch and the app
  /// lifecycle.
  void dispose();
}

/// [BackgroundMusic] on two [MusicPlayer]s, fading from one track into the
/// next.
///
/// - A new track fades in over [fade] (or its cue's [MusicCue.fadeIn]) while
///   the old one fades out.
/// - Battle and fever share a track: fever only raises the rate, so the music
///   keeps its place instead of starting over.
/// - [SoundSettings.enabled] false, or the app not in the foreground, fades
///   the music out and pauses it; it resumes when sound is back. A result
///   jingle that was cut off is not replayed.
/// - Player failures (a missing file, no audio output) are ignored: the music
///   is not worth stopping the battle for.
class BackgroundMusicService
    with WidgetsBindingObserver
    implements BackgroundMusic {
  BackgroundMusicService({
    required this._newPlayer,
    required this._settings,
    this.fade = const Duration(milliseconds: 600),
    this.fadeSteps = 12,
  }) : assert(fadeSteps > 0) {
    _settings.addListener(_onSilenceChanged);
    final binding = WidgetsBinding.instance;
    final state = binding.lifecycleState;
    _inForeground = state == null || state == AppLifecycleState.resumed;
    _wasSilenced = _silenced;
    binding.addObserver(this);
  }

  final MusicPlayer Function() _newPlayer;
  final SoundSettings _settings;

  /// How long a track takes to fade in or out.
  final Duration fade;

  /// Volume steps per fade.
  final int fadeSteps;

  MusicCue? _cue;
  _Track? _active;

  /// Old tracks still fading out after a change; freed at once on dispose.
  final _fading = <_Track>{};
  late bool _inForeground;
  bool _wasSilenced = false;
  bool _disposed = false;

  /// The cue asked for last, playing or not (null after [stop]).
  MusicCue? get cue => _cue;

  bool get _silenced => !_settings.enabled || !_inForeground;

  @override
  void play(MusicCue cue) {
    if (_disposed || cue == _cue) return;
    _cue = cue;
    final active = _active;
    if (active != null && active.cue.asset == cue.asset && cue.loop) {
      // Battle <-> fever: same track, new rate.
      active.cue = cue;
      _quietly(() => active.player.setRate(cue.rate));
      return;
    }
    if (_silenced) {
      // Started when sound is back, unless it is a one-off jingle.
      _release(active, fadeOut: false);
      _active = null;
      return;
    }
    _start(cue);
  }

  void _start(MusicCue cue) {
    final old = _active;
    _release(old, fadeOut: true);
    final track = _Track(_newPlayer(), cue);
    _active = track;
    unawaited(_load(track));
  }

  Future<void> _load(_Track track) async {
    final player = track.player;
    try {
      await player.setVolume(0);
      await player.load(
        track.cue.asset,
        loop: track.cue.loop,
        start: track.cue.start,
      );
      await player.setRate(track.cue.rate);
    } on Object {
      if (identical(_active, track)) _active = null;
      _release(track, fadeOut: false);
      return;
    }
    if (!identical(_active, track)) return; // Replaced while loading.
    track.loaded = true;
    if (!_silenced) _resume(track);
  }

  void _resume(_Track track) {
    _quietly(track.player.play);
    _ramp(track, track.cue.volume, over: track.cue.fadeIn);
  }

  /// Fades [track] out (or cuts it) and frees its player.
  void _release(_Track? track, {required bool fadeOut}) {
    if (track == null || track.released) return;
    track.released = true;
    if (fadeOut && track.loaded && track.volume > 0) {
      _fading.add(track);
      _ramp(track, 0, then: () => _free(track));
    } else {
      _free(track);
    }
  }

  void _free(_Track track) {
    _fading.remove(track);
    track.fade?.cancel();
    _quietly(track.player.stop);
    _quietly(track.player.dispose);
  }

  void _ramp(_Track track, double to, {Duration? over, void Function()? then}) {
    track.fade?.cancel();
    final from = track.volume;
    var step = 0;
    track.fade = Timer.periodic((over ?? fade) ~/ fadeSteps, (timer) {
      step++;
      track.volume = from + (to - from) * step / fadeSteps;
      _quietly(() => track.player.setVolume(track.volume));
      if (step < fadeSteps) return;
      timer.cancel();
      track.fade = null;
      then?.call();
    });
  }

  void _onSilenceChanged() {
    if (_disposed) return;
    final silenced = _silenced;
    if (silenced == _wasSilenced) return;
    _wasSilenced = silenced;
    final active = _active;
    if (silenced) {
      if (active == null) return;
      if (!active.cue.loop) {
        // A jingle that was cut off, or still loading, is not played later
        // (Codex, PR #53).
        _release(active, fadeOut: true);
        _active = null;
        return;
      }
      if (!active.loaded) return; // It loads paused and starts with sound.
      _ramp(active, 0, then: () => _quietly(active.player.pause));
      return;
    }
    if (active != null) {
      if (active.loaded) _resume(active);
      return;
    }
    final cue = _cue;
    if (cue != null && cue.loop) _start(cue);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    _onSilenceChanged();
  }

  @override
  void stop() {
    _cue = null;
    _release(_active, fadeOut: true);
    _active = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cue = null;
    _release(_active, fadeOut: false);
    _active = null;
    _fading.toList().forEach(_free);
    _settings.removeListener(_onSilenceChanged);
    WidgetsBinding.instance.removeObserver(this);
  }

  static void _quietly(Future<void> Function() action) {
    unawaited(Future.sync(action).catchError((Object _) {}));
  }
}

/// One track on its own player.
class _Track {
  _Track(this.player, this.cue);

  final MusicPlayer player;
  MusicCue cue;
  double volume = 0;
  bool loaded = false;
  bool released = false;
  Timer? fade;
}
