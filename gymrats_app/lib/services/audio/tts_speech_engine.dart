import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'speech_engine.dart';

/// The device's Korean text-to-speech, through `flutter_tts`.
///
/// The engine is configured on the first call: Korean, a normal rate, and
/// `speak` futures that wait for the end of the utterance so the voice
/// guidance knows when it may say the next line. The plugin's awaited
/// `speak` only returns on a normal end or a stop, not on a TTS error, so
/// the end is also taken from its completion, error and cancel callbacks.
/// Those callbacks name no utterance, so a line that is cut off after it
/// started still owes one of them: the next callbacks pay that debt first
/// and are dropped, whether they come before or after the new line's
/// `onStart`, and only a callback after the line's own `onStart` ends it.
/// A late callback of a cut-off line therefore cannot end the line that
/// replaced it. A line that fails before it starts, or an engine that never
/// reports the cut-off line's end, is left to the plugin's awaited `speak`
/// and the voice guidance's time limit.
/// The debt is one callback per cut-off line: an engine that reported two
/// ends for one line (the stock Android and iOS plugins report one) could
/// still end the replacement early.
class TtsSpeechEngine implements SpeechEngine {
  TtsSpeechEngine({FlutterTts? tts, this.language = 'ko-KR'})
    : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final String language;
  Future<void>? _configured;
  Completer<void>? _utterance;
  bool _started = false;

  /// End callbacks still due from lines that were cut off after they
  /// started; they are dropped instead of ending the current line.
  int _owed = 0;

  Future<void> _configure() async {
    _tts.setStartHandler(() => _started = true);
    _tts.setCompletionHandler(_endUtterance);
    _tts.setErrorHandler((_) => _endUtterance());
    _tts.setCancelHandler(_endUtterance);
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  void _endUtterance() {
    if (_owed > 0) {
      _owed--;
      return;
    }
    final utterance = _utterance;
    if (!_started || utterance == null || utterance.isCompleted) return;
    utterance.complete();
  }

  @override
  Future<void> speak(String text) async {
    try {
      await (_configured ??= _configure());
    } catch (_) {
      _configured = null; // The TTS service may bind later: retry next time.
      rethrow;
    }
    final previous = _utterance;
    if (_started && previous != null && !previous.isCompleted) {
      // Cut off while speaking: its end callback is still on the way.
      _owed++;
      previous.complete();
    }
    final utterance = Completer<void>();
    _utterance = utterance;
    _started = false;
    // `focus` asks Android for transient audio focus, so music ducks.
    final Future<void> plugin = _tts.speak(text, focus: true);
    await Future.any([plugin, utterance.future]);
  }

  @override
  Future<void> stop() => _tts.stop();
}
