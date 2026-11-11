import 'dart:async';

import 'package:gymrats_app/models/voice_cue.dart';
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
