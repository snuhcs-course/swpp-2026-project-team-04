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
- Codex PR review follow-up (2026-11-11): Codex (`chatgpt-codex-connector`) reviewed PR #48 and left three findings; Claude Code checked each against the code, fixed the two in `tts_speech_engine.dart` and `sound_settings.dart` with 6 tests, and added the `TTS_SERVICE` query to `AndroidManifest.xml` (PM-owned file, one-off exception approved by the user with the PM's agreement).
- Not used: the decision between device TTS and recorded clips (the user chose `flutter_tts` from the two options Claude Code laid out, 11-07); the Korean wording of the lines was AI-drafted and is open to the team's edits in `voice_cue.dart`.

## 2. Prompt History
[Jinyoung Park, 11-07] "task 수행해"
[Jinyoung Park, 11-11] "그리고 이제 codex review PR 댓글도 반영해야 하거든? 그것도 harness에 추가하고"
(Full log: [ishlove77-Prompt-Log.md](ishlove77-Prompt-Log.md))

## 3. What AI Did Well
- J1 in one session: the service, cue table, settings, fakes and 46 tests were written and green on the first full run (`flutter test` 1518 passed), with every new service file at 100 % line coverage (`coverage_by_layer.py --files`). TODO(Jinyoung Park): rough time saved.
- The ownership guard, the file list in the task file and the team-plan contract were followed without a block: only J1 files changed (`ownership_guard.py --check-diff` ok).

## 4. Hallucinations / Errors
- `TtsSpeechEngine` first relied only on `flutter_tts`'s `awaitSpeakCompletion(true)` to learn when a line ends. The reviewer subagent read the plugin's Android source (`FlutterTtsPlugin.kt`) and found that the awaited `speak` never returns on a TTS error, which would have left every later setup hint pending. Fixed the same session: the engine also ends the utterance from the plugin's completion/cancel/error callbacks, and the service waits at most 8 s per line (`voice_guidance.dart`, `maxUtterance`), with tests for both. Cost: ~20 min.
- The first version of that timeout used `Future.delayed`, which left an 8-second timer pending and failed two widget tests ("A Timer is still pending"); replaced by a cancellable `Timer`. Caught by `flutter test`. Cost: ~5 min.
- The first draft of `VoiceGuidanceService` used a non-existent default-clock expression (`(Stopwatch()..start()).elapsed_`) in the initializer list; caught by `flutter analyze` on the first run and replaced by a small static helper. Cost: ~1 min.
- A second AI reviewer caught what our own three review rounds missed (PR #48, Codex): (1) a cut-off line's end callback arriving *after* the replacement's `onStart` still ended the replacement, because the round-2 fix only guarded callbacks before `onStart`; (2) `SoundSettings()` defaulted to the in-memory store, so the production path would never persist the switch; (3) `flutter_tts` needs a `TTS_SERVICE` `<queries>` entry on Android 11+, which the J1 plan missed because `android/*` was outside the step's files. All three fixed on 11-11 in 779da5d (reviewer APPROVE in one round). Cost: ~40 min.
- `flutter analyze` then flagged two lints on the same constructor (`prefer_initializing_formals`, then `type_init_formals`); fixed in two passes. Cost: ~2 min.

## 5. Prompt Revisions
- 11-11: added a standing rule to the harness after the Codex findings ("codex review PR 댓글도 반영해야"): Codex findings on every open PR are read at session start and before every push, fixed or answered with a reason, and replied to on their threads.
- Before that, none: the one prompt was the task start; the open decision was asked and answered through a question dialog (flutter_tts vs recorded clips).

## 6. Manual Fixes and Why
- None so far in J1 (no manual-fix marker added).

## 7. Takeaway for Iteration 5
- TODO(Jinyoung Park): fill when the iteration closes.
