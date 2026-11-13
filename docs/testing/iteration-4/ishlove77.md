# Testing notes – Iteration 4 – Jinyoung Park (ishlove77)

Per-push Results for Jinyoung Park's Iteration 4 steps (team plan J1 `feat/voice_guidance`, J2 `feat/battle_bgm`,
J3 `feat/cumulative_feedback`, J4 `feat/squat_feedback`, J5 `feat/tutorial`), in the Testing Documentation format.
The PM merges these notes into `docs/testing/Testing-Documentation.md`.

## Results

#### 2026-11-14 · code at commit `8867160` · step `feat/battle_bgm` (team plan #8, P11 battle BGM and effects)
The battle's sound: music by screen and stage (menu, setup, battle, fever = battle track at 1.25x, win/lose jingle),
my reps' effects (Good punch, Excellent one-two, Average light hit, miss buzz), a looping danger alarm and a KO gong,
wired into both battle screens through W2's `onCue` and the stage state, and the 효과음 / 음성 안내 switches in
settings. No voice in the battle (the setup voice was dropped after the phone check). Commands from the Plan in
`gymrats_app/` on macOS (Flutter 3.47.5 / Dart 3.13.4): `flutter analyze`, `flutter test`,
the per-file coverage run (`flutter test --coverage` file by file, merged into `coverage/lcov.info`) and a per-layer summary of it.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.4% (266/273) (not changed in this step) | 11/14 | `coverage_per_file.sh` + `coverage_by_layer.py` |
| ViewModel | flutter_test, fakes | 90% | 96.6% (1106/1145); `settings_viewmodel` 98.7% | 11/14 | same |
| Service | flutter_test, MockClient, fakes | 85% | 95.2% (2678/2812); `background_music`, `sound_effects`, `sound_services`, `sound_settings`, `voice_guidance` 100%, `just_audio_music_player` 95.7% (the default `AudioPlayer()` constructor runs only on a device) | 11/14 | same |
| View | flutter_test (widget) | 75% | 92.9% (6016/6476); `sound_battle`, `sound_cues`, `home_screen` 100%, `battle_screen` 94.0% | 11/14 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | `server/` unchanged; not re-measured | – | – |

- **Tests:** `flutter test` 2189 passed, 0 failed, 10 skipped (pre-existing: the live team-server smoke test and the
  online tests marked skip on `main`). `flutter analyze` no issues. App total 94.0% (10107/10748).
- **Not in the numbers:** `test/screens/online_preparation_test.dart` hit the script's 180-second limit on this Mac (it
  passes in `flutter test`), so `online_battle_screen.dart` shows 64.0%; of J2's lines there only `_sounds.ended()`
  (a battle that ends without a result) is unmeasured. `music_player.dart` is an interface (no executable lines).
- **Shortfalls:** no widget test drives the online battle screen's sound; the same `BattleSounds` is tested on its own
  (`a battle that ends without a result stops the alarm and the music`) and through the real bot screen. Accepted by
  the reviewer as Minor.
- **Manual check (S23 Ultra SM-S918N, Android 15, 2026-11-14):** AI battle, one push-up and one squat round, with a
  screen recording (media sound) analysed on the Mac: menu, setup, battle and fever music, the lose jingle, Good and
  Excellent hits, the miss buzz (52.2 s), the alarm loop (53-56 s) and the KO gong (103.7 s) all play. No rep was
  graded Average in the run (result screen: Average 0), so the Average hit is not yet heard on a device. Online 1v1
  not run (needs two phones).
- **Reviewer:** phase 1 APPROVE in round 3, phase 2 APPROVE in round 2, the phone-check changes APPROVE (three Minor
  doc findings, fixed).

Test cases added or changed:

| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/audio/background_music_test.dart` (new, 25) | each cue's track, loop or once; fever = battle track faster; the battle track starts at its first beat with a quick fade; one play per cue across state updates; crossfade and freeing the old track; a track replaced while loading; stop; sound off/on; background; load failure; a set that starts silent until the saved switch |
| Service | `test/services/audio/just_audio_music_player_test.dart` (new, 6) | load from zero vs a clipped start in one load, loop mode, rate, volume, seek to start, dispose |
| Service | `test/services/audio/sound_effects_test.dart` (new, 15) | every effect has a file; a rep's sound by grade; prepare once; replay rewinds; skipped before ready; the alarm loop, its start during load, sound off, background; load failure; release and dispose; a player released while loading |
| Service | `test/services/audio/sound_services_test.dart` (new, 5) | the shared set is silent under `flutter test`; the device set starts silent; set and reset |
| Service | `test/services/audio/sound_settings_test.dart`, `voice_guidance_test.dart` (updated) | the 음성 안내 switch (`voiceEnabled`) and the voice following it |
| ViewModel | `test/viewmodels/settings_viewmodel_test.dart` (updated) | the app's sound follows the switches: after load, on each change, on a failed read (Exception and Error), kept with W's safety-notice tests |
| View | `test/widgets/sound_battle_test.dart` (new, 8) | music by stage phase; a whole round with the alarm on and off; the alarm only while playing; the server's pending result keeps the music, a draw stops it; my hit by grade, my miss, the KO, the opponent silent; no voice; ended without a result; the shared set |
| View | `test/widgets/sound_battle_screen_test.dart` (new, 1) | the real bot `BattleScreen`: setup music through 3-2-1, battle music, a counted rep plays the Good hit, no voice, leaving frees the effects |
| View | `test/widgets/sound_cues_test.dart` (new, 8) | a screen's cues on every build; the menu music comes back when the screen is uncovered |

Acceptance criteria → tests:
- **The BGM speeds up at fever and the win or lose jingle plays once:** `fever is the battle track played faster`,
  `a result jingle plays once`, `a whole round: prepares the effects, setup, battle, fever, the alarm on and off, the
  win jingle, no voice; leaving frees the effects`.
- **Each of my reps sounds by its result, an alarm repeats in danger, a gong at a KO, no voice:**
  `a rep sounds by its grade; one that earned nothing is a miss`, `the danger alarm loops while in danger and pauses
  after`, `the alarm sounds only while the round is on`, the real-screen test above.
- **Sound off silences everything:** `sound off silences the hits and pauses the alarm; on brings the alarm back while still in danger`,
  `turning sound off fades the music out and pauses it; on resumes the same track`.
- ~~The setup voice says what to fix~~: dropped by the user on 2026-11-14; the real-screen test asserts no voice.

#### 2026-11-11 · code at commit `779da5d` · step `feat/voice_guidance` (team plan #3, Codex review of PR #48)
Follow-up to the Codex review of PR #48: a cut-off line's late end callback can no longer end the line that replaced it
(the cut-off line owes one callback, which is dropped), `SoundSettings()` saves to secure storage by default, and the
manifest declares the `TTS_SERVICE` query so Android 11+ can find the TTS engine. Same commands as the entry below.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.4% (266/273) | 11/11 | `coverage_per_file.sh` + `coverage_by_layer.py` |
| ViewModel | flutter_test, fakes | 90% | 95.7% (927/969) (not changed in this step) | 11/11 | same |
| Service | flutter_test, MockClient, fakes | 85% | 94.8% (2388/2519); `tts_speech_engine` 31/31, `sound_settings` 22/22, `voice_guidance` 73/73, `voice_cue_table` 25/25 | 11/11 | same |
| View | flutter_test (widget) | 75% | 91.0% (4084/4487) (not changed in this step) | 11/11 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | `server/` unchanged; not re-measured | – | – |

- **Tests:** `flutter test` 1531 passed, 0 failed, 10 skipped (pre-existing, as below). `flutter analyze` no issues.
  App total 93.0% (7706/8290).
- **Shortfalls:** the manifest query is checked on the device only (no unit test reads the manifest); the S23 Ultra
  already found its engine before the change.
- **Reviewer:** APPROVE (one round; three Minor findings: a test for a line replaced before it started, a doc sentence
  on the one-callback debt, and these notes; all done).

Test cases added or changed:

| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/audio/tts_speech_engine_test.dart` (+5) | a late `speak.onComplete` / `speak.onError` / `speak.onCancel` of the cut-off line after the new line's `speak.onStart` does not end the new line; a cut-off line whose cancel came before the new line owes nothing; a line replaced before it started owes nothing |
| Service | `test/services/audio/sound_settings_test.dart` (+1) | without a store the switch is saved in secure storage and survives a restart |
| Service | `test/services/audio/voice_guidance_test.dart`, `test/services/device/device_controls_test.dart` (updated) | pass `MemorySoundSettingsStore` explicitly now that the default is secure storage |

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
