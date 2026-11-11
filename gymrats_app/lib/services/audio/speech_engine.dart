/// Speaks text aloud. The real one wraps the TTS plugin; tests use a fake.
///
/// Screens and view models never see this: they go through `VoiceGuidance`.
abstract interface class SpeechEngine {
  /// Speaks [text] and completes when the utterance has ended (or was cut
  /// off). A new call while speaking replaces the current utterance.
  Future<void> speak(String text);

  /// Cuts off the current utterance, if any.
  Future<void> stop();
}
