# AI collaboration notes: Iteration 4, Jinyoung Park (ishlove77)
Status: draft (iteration open)
Written by: Jinyoung Park
Tools used: Claude Code (Fable 5.1)

These notes cover Jinyoung Park's Iteration 4 steps (team plan J1–J5), items a–f per the guideline; the PM merges them into the one-page team report. Prompt log: `ishlove77-Prompt-Log.md` (filled by the course Session Exporter before every push).

## 1. Where AI Was Used
### J1 `feat/voice_guidance` (team plan #3, P9 voice guidance, 2026-11-07)
- Voice cue model `gymrats_app/lib/models/voice_cue.dart` (whole file: the `VoiceCue` enum with the Korean lines, group and interrupt flag): Claude Code, from the J1 spec in the task file and the setup messages in `setup_checker.dart`.
- Audio service `gymrats_app/lib/services/audio/` (whole folder: `speech_engine.dart`, `tts_speech_engine.dart`, `voice_guidance.dart`, `voice_cue_table.dart`, `sound_settings.dart`): Claude Code. The de-duplication rules (one line per change, newest pending hint, interrupting events, stop/completion generation counter) were designed by Claude Code and checked by the tests it wrote.
- `gymrats_app/lib/services/device/device_controls.dart` (`DeviceRepSound` follows `SoundSettings`), `gymrats_app/test/support/audio_fakes.dart`, the six test files under `test/models/voice_cue_test.dart`, `test/services/audio/`, `test/services/device/device_controls_test.dart`, and `docs/iteration-4/sound-voice-guidance.md`: Claude Code.
- `pubspec.yaml`: `flutter pub add flutter_tts` run by Claude Code (one line).
- Not used: the decision between device TTS and recorded clips (the user chose `flutter_tts` from the two options Claude Code laid out, 11-07); the Korean wording of the lines was AI-drafted and is open to the team's edits in `voice_cue.dart`.

## 2. Prompt History
[Jinyoung Park, 11-07] "task 수행해"
(Full log: [ishlove77-Prompt-Log.md](ishlove77-Prompt-Log.md))

## 3. What AI Did Well
- J1 in one session: the service, cue table, settings, fakes and 46 tests were written and green on the first full run (`flutter test` 1518 passed), with every new service file at 100 % line coverage (`coverage_by_layer.py --files`). TODO(Jinyoung Park): rough time saved.
- The ownership guard, the file list in the task file and the team-plan contract were followed without a block: only J1 files changed (`ownership_guard.py --check-diff` ok).

## 4. Hallucinations / Errors
- `TtsSpeechEngine` first relied only on `flutter_tts`'s `awaitSpeakCompletion(true)` to learn when a line ends. The reviewer subagent read the plugin's Android source (`FlutterTtsPlugin.kt`) and found that the awaited `speak` never returns on a TTS error, which would have left every later setup hint pending. Fixed the same session: the engine also ends the utterance from the plugin's completion/cancel/error callbacks, and the service waits at most 8 s per line (`voice_guidance.dart`, `maxUtterance`), with tests for both. Cost: ~20 min.
- The first version of that timeout used `Future.delayed`, which left an 8-second timer pending and failed two widget tests ("A Timer is still pending"); replaced by a cancellable `Timer`. Caught by `flutter test`. Cost: ~5 min.
- The first draft of `VoiceGuidanceService` used a non-existent default-clock expression (`(Stopwatch()..start()).elapsed_`) in the initializer list; caught by `flutter analyze` on the first run and replaced by a small static helper. Cost: ~1 min.
- `flutter analyze` then flagged two lints on the same constructor (`prefer_initializing_formals`, then `type_init_formals`); fixed in two passes. Cost: ~2 min.

## 5. Prompt Revisions
- None this step: the one prompt was the task start; the open decision was asked and answered through a question dialog (flutter_tts vs recorded clips).

## 6. Manual Fixes and Why
- None so far in J1 (no manual-fix marker added).

## 7. Takeaway for Iteration 5
- TODO(Jinyoung Park): fill when the iteration closes.
