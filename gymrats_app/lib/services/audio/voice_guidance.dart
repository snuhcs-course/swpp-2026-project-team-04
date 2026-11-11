import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../models/voice_cue.dart';
import 'sound_settings.dart';
import 'speech_engine.dart';

/// Says the voice lines of setup and battle. What screens and the sound
/// widget talk to; the TTS plugin stays behind [SpeechEngine].
///
/// [say] may be called on every frame or state change with the current cue:
/// a line is spoken once per change, not repeated while the cue stays the
/// same. Nothing is said while sound is off or the app is in the background.
abstract interface class VoiceGuidance {
  /// Requests [cue]. Spoken at once, queued behind the current line, or
  /// dropped when it is the same cue as before; see [VoiceGuidanceService].
  void say(VoiceCue cue);

  /// Cuts off the current line and drops the queued one.
  void stop();

  /// Forgets the last cue, so the next [say] speaks even if it is the same
  /// cue. For a new screen or a new round.
  void reset();

  /// Stops speaking and stops listening to the app lifecycle.
  void dispose();
}

/// [VoiceGuidance] on a [SpeechEngine], with the de-duplication, mute, and
/// background rules.
///
/// - A cue equal to the newest requested cue is dropped (one line per change).
/// - While a line is spoken, a hint waits as the single pending cue (the
///   newest wins); a cue with [VoiceCue.interrupts] cuts the line off.
/// - [SoundSettings.enabled] false, or the app not in the foreground, stops
///   the current line and silences new ones.
/// - With [repeatAfter], the same cue is said again once that long has passed
///   since it was last started (a user stuck on one hint hears it again).
/// - Engine failures (no TTS, no Korean voice) are ignored, and a line is
///   waited for at most [maxUtterance]: the voice is not worth stopping the
///   battle for.
class VoiceGuidanceService
    with WidgetsBindingObserver
    implements VoiceGuidance {
  VoiceGuidanceService({
    required this._engine,
    required this._settings,
    this.repeatAfter,
    this.maxUtterance = const Duration(seconds: 8),
    Duration Function()? clock,
  }) : _clock = clock ?? _stopwatchClock() {
    _settings.addListener(_onSettings);
    final binding = WidgetsBinding.instance;
    final state = binding.lifecycleState;
    _inForeground = state == null || state == AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  final SpeechEngine _engine;
  final SoundSettings _settings;
  final Duration Function() _clock;

  /// After this long, the same cue may be spoken again. Null: never.
  final Duration? repeatAfter;

  /// The longest a line is waited for. An engine that never reports the end
  /// of an utterance (a TTS error the plugin swallows) must not block the
  /// next hint.
  final Duration maxUtterance;

  VoiceCue? _current;
  Duration? _currentStartedAt;
  VoiceCue? _pending;
  bool _speaking = false;
  late bool _inForeground;
  bool _disposed = false;

  /// The line being spoken, or the last one spoken since [reset].
  VoiceCue? get current => _current;

  /// Whether a line is being spoken right now.
  bool get isSpeaking => _speaking;

  bool get _silenced => _disposed || !_settings.enabled || !_inForeground;

  @override
  void say(VoiceCue cue) {
    if (_silenced) return;
    final newest = _pending ?? _current;
    if (cue == newest && !_dueAgain(cue)) return;
    if (_speaking) {
      if (cue.interrupts) {
        _pending = null;
        unawaited(Future.sync(_engine.stop).catchError(_ignore));
        _start(cue);
      } else {
        _pending = cue;
      }
      return;
    }
    _start(cue);
  }

  bool _dueAgain(VoiceCue cue) {
    final after = repeatAfter;
    final startedAt = _currentStartedAt;
    if (after == null || _speaking || _pending != null) return false;
    if (cue != _current || startedAt == null) return false;
    return _clock() - startedAt >= after;
  }

  void _start(VoiceCue cue) {
    _current = cue;
    _currentStartedAt = _clock();
    _speaking = true;
    final generation = ++_generation;
    _utteranceLimit?.cancel();

    // Once per line: when the engine reports the end, or after [maxUtterance].
    void end() {
      if (generation != _generation) return; // Cut off by a newer line.
      _utteranceLimit?.cancel();
      _utteranceLimit = null;
      _speaking = false;
      final next = _pending;
      _pending = null;
      if (next != null && next != _current && !_silenced) _start(next);
    }

    _utteranceLimit = Timer(maxUtterance, end);
    unawaited(
      Future.sync(() => _engine.speak(cue.text))
          .catchError(_ignore)
          .whenComplete(end),
    );
  }

  Timer? _utteranceLimit;
  int _generation = 0;

  @override
  void stop() {
    _pending = null;
    if (!_speaking) return;
    _speaking = false;
    _generation++;
    _utteranceLimit?.cancel();
    _utteranceLimit = null;
    unawaited(Future.sync(_engine.stop).catchError(_ignore));
  }

  @override
  void reset() {
    stop();
    _current = null;
    _currentStartedAt = null;
  }

  void _onSettings() {
    if (!_settings.enabled) stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (!_inForeground) stop();
  }

  @override
  void dispose() {
    if (_disposed) return;
    stop();
    _disposed = true;
    _settings.removeListener(_onSettings);
    WidgetsBinding.instance.removeObserver(this);
  }

  static void _ignore(Object _) {}

  static Duration Function() _stopwatchClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }
}
