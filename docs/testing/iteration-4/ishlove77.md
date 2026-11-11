# Testing notes – Iteration 4 – Jinyoung Park (ishlove77)

Per-push Results for Jinyoung Park's Iteration 4 steps (team plan J1 `feat/voice_guidance`, J2 `feat/battle_bgm`,
J3 `feat/cumulative_feedback`, J4 `feat/squat_feedback`, J5 `feat/tutorial`), in the Testing Documentation format.
The PM merges these notes into `docs/testing/Testing-Documentation.md`.

## Results

#### 2026-11-08 · code at commit `4208543` · step `feat/voice_guidance` (team plan #3, P9 voice guidance)
This step adds the voice guidance behind an interface, with no screen edits: `VoiceCue` (the Korean lines),
`SpeechEngine` / `TtsSpeechEngine` (`flutter_tts`, the device's Korean TTS), `VoiceGuidanceService` (one line per
change, newest pending hint, interrupting events, sound off, background, an 8-second limit per line),
`VoiceCueTable` (setup reason / countdown / end / outcome → line), `SoundSettings` (the one sound switch, saved in
secure storage) and the rep beep following that switch. Fakes for J2 and others: `test/support/audio_fakes.dart`.
Commands from the Plan in `gymrats_app/` on macOS (Flutter 3.47.5 / Dart 3.13.4): `flutter analyze`, `flutter test`,
the per-file coverage run (`flutter test --coverage` file by file, merged into `coverage/lcov.info`) and a per-layer summary of it.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.4% (266/273) | 11/08 | `coverage_per_file.sh` + `coverage_by_layer.py` |
| ViewModel | flutter_test, fakes | 90% | 95.9% (929/969) (not changed in this step) | 11/08 | same |
| Service | flutter_test, MockClient, fakes | 85% | 94.7% (2378/2512); the step's files 100% (`sound_settings`, `tts_speech_engine`, `voice_guidance`, `voice_cue_table`, `device_controls`) | 11/08 | same; step files: `flutter test --coverage --coverage-path=coverage/step.info test/models/voice_cue_test.dart test/services/audio test/services/device/device_controls_test.dart` |
| View | flutter_test (widget) | 75% | 87.9% (3942/4487) (not changed in this step) | 11/08 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | `server/` unchanged; not re-measured | – | – |

- **Tests:** `flutter test` 1525 passed, 0 failed, 10 skipped (all pre-existing: the live team-server smoke test and the
  online tests marked skip on `main`). `flutter analyze` no issues. The step's own tests: 52 passed (46 new, 6 existing
  in `device_controls_test.dart`).
- **Coverage:** app total 91.2% (7556/8283). `lib/models/voice_cue.dart` and `lib/services/audio/speech_engine.dart` have no
  executable lines (constant-only enum, interface) and appear in the script's "not loaded" list by design.
  Not in the numbers: `test/screens/online_preparation_test.dart` hit the script's 180-second limit on this Mac (an
  existing heavy widget test, not touched by this step; it passes in `flutter test`), so View is slightly understated.
- **Shortfalls:** none in the changed files. The device part of `TtsSpeechEngine` (the real Android TTS engine and
  its Korean voice) is covered by the mocked `flutter_tts` channel in tests and by a manual check: on 2026-11-11 a local-only
  demo screen (not committed) drove the real `VoiceGuidanceService` + `TtsSpeechEngine` on a Galaxy S23 Ultra
  (SM-S918N): the countdown lines, a three-hint burst and the sound switch played through Google TTS ko-KR on the media
  stream (logcat shows each utterance start and completion). The app's screens hear the lines only after J2 wires them.
- **Reviewer rounds:** three (two Major findings from reading the `flutter_tts` Android source: the plugin never ends
  the awaited `speak` on a TTS error, and its callbacks name no utterance; both fixed with tests before this push).

Test cases added or changed in this step:

| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/voice_cue_test.dart` (new, 4) | every cue has a Korean line, the lines are distinct, which cues cut off the current line (ready, countdown, battle events) and which wait (setup hints) |
| Service | `test/services/audio/voice_guidance_test.dart` (new, 24) | one line per change (a hint repeated every frame, a battle event repeated on every state update, the countdown 3-2-1, a changed hint and back, reset, `repeatAfter`, own clock); while speaking (newest pending hint, a flicker back to the current line, an interrupting event, stop); sound off (silent, cuts the current line, drops the pending hint, back on); background (paused cuts and silences until resumed, inactive/hidden/detached, the binding's lifecycle, a service created while paused); robustness (engine errors ignored, failing stop, a line the engine never finishes gives way after `maxUtterance`, dispose twice) |
| Service | `test/services/audio/voice_cue_table_test.dart` (new, 6) | every `SetupReason` maps to a line, a stably ready status says ready, the countdown rounds seconds up and has no line beyond 3 s or without a countdown, `GameEnd` and `MatchOutcome` lines |
| Service | `test/services/audio/sound_settings_test.dart` (new, 5) | on by default and `load` reads the saved switch, `setEnabled` notifies once per change and saves, a failing store keeps the default and still flips for this run, the secure store's default and "false" handling, the switch survives a new store apart from the session key |
| Service | `test/services/audio/tts_speech_engine_test.dart` (new, 8) | first line configures ko-KR / rate 0.5 / pitch 1.0 / awaited completion then speaks, later lines only speak, stop, another language, a plugin error surfaces, `speak.onError`/`speak.onComplete` end the line only after its `speak.onStart`, a cut-off line's cancel/complete does not end its replacement, a callback before any line is harmless, a failed first configuration is retried |
| Service | `test/services/device/device_controls_test.dart` (updated, +2) | the rep beep follows the sound switch; the files folder comes from MainActivity or is null without one |

Acceptance criteria → tests:
- **Given a setup hint or a battle event, the service plays the matching voice line once (not every frame):**
  `a setup hint repeated every frame is spoken once`, `a battle event repeated with every state update is spoken once`,
  `the countdown says three, two, one`, `every setup reason has a "what to fix" line`; on-device robustness:
  `a cancel or completion of the line that was cut off does not end the line that replaced it`,
  `a line the engine never finishes gives way after maxUtterance`.
- **Given sound is off, nothing plays:** `nothing is spoken while the sound is off`, `turning the sound off cuts the
  current line`, `a pending hint is dropped when the sound goes off before its turn`, `the rep beep follows the sound switch`.
- **Settled: no sound in the background:** `a paused app cuts the current line and stays silent until resumed`,
  `inactive and hidden count as background too`, `the service hears the lifecycle from the binding`,
  `a service created while the app is paused starts silent`.
