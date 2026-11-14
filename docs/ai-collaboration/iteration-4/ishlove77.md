# AI collaboration notes: Iteration 4, Jinyoung Park (ishlove77)
Status: draft (iteration open)
Written by: Jinyoung Park
Tools used: Claude Code (Fable 5.1, Opus 5.5)

These notes cover Jinyoung Park's Iteration 4 steps (team plan J1–J5), items a–f per the guideline; the PM merges them into the one-page team report. Prompt log: `ishlove77-Prompt-Log.md` (filled by the course Session Exporter before every push).

## 1. Where AI Was Used
### J1 `feat/voice_guidance` (team plan #3, P9 voice guidance, 2026-11-07)
- Voice cue model `gymrats_app/lib/models/voice_cue.dart` (whole file: the `VoiceCue` enum with the Korean lines, group and interrupt flag): Claude Code, from the J1 spec in the task file and the setup messages in `setup_checker.dart`.
- Audio service `gymrats_app/lib/services/audio/` (whole folder: `speech_engine.dart`, `tts_speech_engine.dart`, `voice_guidance.dart`, `voice_cue_table.dart`, `sound_settings.dart`): Claude Code. The de-duplication rules (one line per change, newest pending hint, interrupting events, stop/completion generation counter) were designed by Claude Code and checked by the tests it wrote.
- `gymrats_app/lib/services/device/device_controls.dart` (`DeviceRepSound` follows `SoundSettings`), `gymrats_app/test/support/audio_fakes.dart`, the six test files under `test/models/voice_cue_test.dart`, `test/services/audio/`, `test/services/device/device_controls_test.dart`, and `docs/iteration-4/sound-voice-guidance.md`: Claude Code.
- `pubspec.yaml`: `flutter pub add flutter_tts` run by Claude Code (one line).
- Codex PR review follow-up (2026-11-11): Codex (`chatgpt-codex-connector`) reviewed PR #48 and left three findings; Claude Code checked each against the code, fixed the two in `tts_speech_engine.dart` and `sound_settings.dart` with 6 tests, and added the `TTS_SERVICE` query to `AndroidManifest.xml` (PM-owned file, one-off exception approved by the user with the PM's agreement).
- Not used: the decision between device TTS and recorded clips (the user chose `flutter_tts` from the two options Claude Code laid out, 11-07); the Korean wording of the lines was AI-drafted and is open to the team's edits in `voice_cue.dart`.
### J2 `feat/battle_bgm` (team plan #8, P11 battle BGM and effects, 2026-11-11 ~ 11-14)
- Music and effects services `gymrats_app/lib/services/audio/` (`music_player.dart`, `just_audio_music_player.dart`, `background_music.dart`, `sound_effects.dart`, `sound_services.dart`; `sound_settings.dart` and `voice_guidance.dart` gained the 음성 안내 switch): Claude Code, from the J2 spec and the user's sound decisions.
- Screen wiring `gymrats_app/lib/widgets/sound_battle.dart`, `sound_cues.dart`, a few lines each in `battle_screen.dart`, `online_battle_screen.dart` (W2's hooks `onCue`), `home_screen.dart` (approved exception), `settings_viewmodel.dart`: Claude Code.
- Candidate search and preparation of the tracks and effects (CC0 packs on OpenGameArt; trimming, leveling) and a team listening page (claude.ai artifact) used to pick the preset: Claude Code. The picks themselves were the user's and the team's.
- Phone check analysis (11-14): Claude Code pulled the S23 screen recording over adb and analysed it (audio matched against each effect file, frames read from the video) to tell which sounds played.
- Tests (`test/services/audio/*`, `test/widgets/sound_*`, `test/viewmodels/settings_viewmodel_test.dart`, `test/support/audio_fakes.dart`) and `docs/iteration-4/sound-battle-bgm.md`: Claude Code.
- Not used: which sounds to keep, cut or change (no voice in the battle, no sound for the opponent, the alarm, fever 1.25x, dropping the setup voice); all decided by the user by ear.

### J3 `feat/cumulative_feedback` (team plan #9, P12 cumulative feedback, 2026-11-14)
- Server statistics API `server/matches/views.py` (`MatchStatsView`, `_online_flag`), `serializers.py` (summary `issues` codes, `is_online` on rows), `urls.py`, `server/tests/test_stats.py`: Claude Code, from the J3 decisions (light server API, app-side grouping).
- App models and calculator `gymrats_app/lib/models/feedback_stats.dart`, `gymrats_app/lib/services/feedback/feedback_stats.dart` (`FeedbackStatsSource`, `FeedbackStatsCalculator`), issue codes in `form_analyzer.dart` / `form_summary.dart` / `feedback_summary.dart`, `MatchRecord.isOnline/gameEnd/opponentLeft` read in `server_user_repository.dart`, `HistoryViewModel` archive summary, new `FeedbackStatsViewModel`, and all the tests and `test/support/feedback_fakes.dart`: Claude Code.
- A temporary dummy-data demo (34 battles) run on the Android emulator to see the values, then deleted (never committed): Claude Code.
- Not used: the definitions of `weekDaily`, `streakDays` and `bestGain` (from 송우현, forwarded by the user) and the value names (송우현's data list document).

## 2. Prompt History
[Jinyoung Park, 11-07] "task 수행해"
[Jinyoung Park, 11-11] "그리고 이제 codex review PR 댓글도 반영해야 하거든? 그것도 harness에 추가하고"
[Jinyoung Park, 11-14] "J3 task 수행해보자"
[Jinyoung Park, 11-14] "아티팩트를 못본다고?"
[Jinyoung Park, 11-14] "더미 데이터 만들어서 android studi에서 확인할 수 있게 해주삼"
(Full log: [ishlove77-Prompt-Log.md](ishlove77-Prompt-Log.md))
[Jinyoung Park, 11-12] "세팅할떄만 voice 놓고 게임도중에는 voice를 빼고 대신 점수에 따라나 실패 할떄 효과음을 넣는 식으로 하자. 때리는 효과음으로 하고, 죽기 직전이면 경고음 효과음을 넣을건데 시안을 몇개 뽑아줘. 브금도 포함해서"
[Jinyoung Park, 11-12] "battle 소리가 3초 load되는데 artifact 보니까"
[Jinyoung Park, 11-14] "효과음중 가장 크면 안되지 그러면 차이가 없자나"
[Jinyoung Park, 11-14] "혹시 average 점수가 아예 안나오느건 아니지 지금?"

## 3. What AI Did Well
- J1 in one session: the service, cue table, settings, fakes and 46 tests were written and green on the first full run (`flutter test` 1518 passed), with every new service file at 100 % line coverage (`coverage_by_layer.py --files`). TODO(Jinyoung Park): rough time saved.
- The ownership guard, the file list in the task file and the team-plan contract were followed without a block: only J1 files changed (`ownership_guard.py --check-diff` ok).
- J2: the listening page let the team pick the effects by ear over the real battle music before any app code; the app reproduces its preset (volumes, fever 1.25x, music start 1.54 s into the track).
- J2: the screen-recording analysis settled a disputed bug in minutes: the result screen frame showed Average 0 and the audio showed the buzz, alarm and gong at the right times, so the "missing Average sound" was a rep that was never graded Average, not an audio fault.
- J3: server API, calculator, two view models and their tests in one session; every J3 client file at 100 % line coverage except the untouched lines of `form_analyzer.dart`, and the server stats tests pass on the first full run after one status-code fix.
- J3: the emulator demo showed the values computed from 34 dummy battles (7-day 136 reps / 10 battles, 8-day streak, this-week average 13.8 = 124 / 9), which matched counting the dummy data by hand.

## 4. Hallucinations / Errors
- `TtsSpeechEngine` first relied only on `flutter_tts`'s `awaitSpeakCompletion(true)` to learn when a line ends. The reviewer subagent read the plugin's Android source (`FlutterTtsPlugin.kt`) and found that the awaited `speak` never returns on a TTS error, which would have left every later setup hint pending. Fixed the same session: the engine also ends the utterance from the plugin's completion/cancel/error callbacks, and the service waits at most 8 s per line (`voice_guidance.dart`, `maxUtterance`), with tests for both. Cost: ~20 min.
- The first version of that timeout used `Future.delayed`, which left an 8-second timer pending and failed two widget tests ("A Timer is still pending"); replaced by a cancellable `Timer`. Caught by `flutter test`. Cost: ~5 min.
- The first draft of `VoiceGuidanceService` used a non-existent default-clock expression (`(Stopwatch()..start()).elapsed_`) in the initializer list; caught by `flutter analyze` on the first run and replaced by a small static helper. Cost: ~1 min.
- A second AI reviewer caught what our own three review rounds missed (PR #48, Codex): (1) a cut-off line's end callback arriving *after* the replacement's `onStart` still ended the replacement, because the round-2 fix only guarded callbacks before `onStart`; (2) `SoundSettings()` defaulted to the in-memory store, so the production path would never persist the switch; (3) `flutter_tts` needs a `TTS_SERVICE` `<queries>` entry on Android 11+, which the J1 plan missed because `android/*` was outside the step's files. All three fixed on 11-11 in 779da5d (reviewer APPROVE in one round). Cost: ~40 min.
- `flutter analyze` then flagged two lints on the same constructor (`prefer_initializing_formals`, then `type_init_formals`); fixed in two passes. Cost: ~2 min.
- J2: `JustAudioMusicPlayer` first loaded a track with `setAsset` and then `setClip`, decoding it twice; the reviewer caught it and it became one `ClippingAudioSource` load. Cost: ~10 min.
- J2: the reviewer found that an online battle ending without a result (connection error, void) kept the danger alarm and the battle music playing (Major); fixed with `BattleSounds.ended()` and a test.
- J2 (11-14): Claude Code explained the unheard Average hit as "lost under the music" and made it the loudest effect without evidence. The user objected ("효과음중 가장 크면 안되지") and then asked whether Average was graded at all; the recording showed it was not (Average needs a push-up rejected as "더 깊게" with the elbow bent to 120° or less). Cost: two needless rebuilds, ~20 min.
- J2: Codex reviewed PR #53 twice and found three P2 gaps our reviewer rounds missed, each on a different exit path: a hit or the KO gong already playing went on after the sound was turned off (6ef8614; the reviewer then found a hit still rewinding could start too, same commit); leaving an online battle early left the battle music over the play screen (only the bot battle goes home, where the menu music restarts); a jingle still loading when the sound went off played later (both 6d9fb89). Listing every screen exit and every silence moment up front would have caught them earlier.
- J3: 송우현's data list is a Claude Docs document shared only with his account. Claude Code tried the artifact reader (it returned only the title "Claude Docs") and the docs reader (access denied), said so, and built from the task file and his three forwarded answers. When the document arrived as a file, comparing it found two gaps the build had missed: the growth type is `ScoreGrowth` in the document, and J3 also owes `opponentLeft` for past battles (a paragraph in the result-report section, not the archive table). Both fixed before the commit. Cost: one extra review round.
- J3: the first server tests expected HTTP 400 for bad input; this API returns 422 (`gymrats/exceptions.py`). Caught by the test run. Cost: ~2 min.
- J3: the reviewer found the day cut used the time's own zone (a UTC time would split days at 09:00 in Korea), that a battle stamped after now (phone clock ahead) counted in totals without a bar, that the stats view built an `IN` list as long as the user's battles (SQLite parameter limit), and in round 2 that `firstPlayedAt` could name a battle without a score. All fixed with tests.

## 5. Prompt Revisions
- 11-11: added a standing rule to the harness after the Codex findings ("codex review PR 댓글도 반영해야"): Codex findings on every open PR are read at session start and before every push, fixed or answered with a reason, and replied to on their threads.
- Before that, none: the one prompt was the task start; the open decision was asked and answered through a question dialog (flutter_tts vs recorded clips).
- J2: "소리가 거의 안들리는디" → "battle 소리가 3초 load되는데 artifact 보니까": naming the exact symptom (3 s before the music) led to prefetching the track and starting it at its first beat (1.54 s) instead of only raising volumes.
- J2: "Average를 조금더 키워야 할듯" → "효과음중 가장 크면 안되지 그러면 차이가 없자나": the second prompt gave the constraint (Excellent > Good > Average), so the level was set just under Good.
- J3: a 288-line paste reached Claude Code only as "[Pasted text #2 +288 lines]"; the user saved the document as a file and sent the path ("~/Downloads/GymRats-화면별-데이터-목록.md"), which worked.

## 6. Manual Fixes and Why
- None so far in J1 (no manual-fix marker added).
- None in J2 (no manual-fix marker added).
- None in J3 (no manual-fix marker added).

## 7. Takeaway for Iteration 5
- TODO(Jinyoung Park): fill when the iteration closes.
