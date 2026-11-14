# Testing notes – Iteration 4 – Jinyoung Park (ishlove77)

Per-push Results for Jinyoung Park's Iteration 4 steps (team plan J1 `feat/voice_guidance`, J2 `feat/battle_bgm`,
J3 `feat/cumulative_feedback`, J4 `feat/squat_feedback`, J5 `feat/tutorial`), in the Testing Documentation format.
The PM merges these notes into `docs/testing/Testing-Documentation.md`.

## Results

#### 2026-11-14 · code at commit `ddef3f7` · step `feat/squat_feedback` (team plan #12, P15 squat feedback)
Squat form feedback and the view-model values of the result report and the form feedback (no screen: 송우현's W6/W8
draw them). Squat battles (bot and online) now save a form report that keeps its exercise; `FormAnalyzer` judges a
squat by its rejected reps and late depth loss, with tips, and leaves the push-up arm/hand/head rules out;
`FeedbackViewModel` gives mean depth, depth trend, arm balance and pace by the analyzer's own rules and can start from
a report in hand; the new `ResultViewModel` gives the previous best, the recent 8 scores and the recent-5 average from
the earlier battles of the same exercise (J3's statistics source), the next tip and the rematch. Branch based on
`origin/main` 690c873 (J3 #56 merged). Commands from the Plan in `gymrats_app/` on macOS (Flutter 3.47.5 / Dart 3.13.4).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.3% (545/549); `form_report` 100% | 11/14 | `coverage_per_file.sh` + `coverage_by_layer.py` |
| ViewModel | flutter_test, fakes | 90% | 97.4% (1425/1463); `result_viewmodel`, `feedback_viewmodel` 100%, `battle_viewmodel` 98.6% | 11/14 | same |
| Service | flutter_test, MockClient, fakes | 85% | 95.9% (2636/2749); `form_analyzer` 98.5% (the unreached lines are an older push-up flare branch), `form_summary` 100% | 11/14 | same |
| View | flutter_test (widget) | 75% | 95.2% (6793/7138); `online_battle_screen` 64.5% in the numbers (see below) | 11/14 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | not changed in this step | – | – |

- **Tests:** `flutter test` 2725 passed, 0 failed, 10 skipped (pre-existing, as in the J2 entry). `flutter analyze` no
  issues. App total 95.8% (11443/11944).
- **Not in the numbers:** `test/screens/online_preparation_test.dart` hit the script's 180-second limit again (it passes
  in `flutter test`, including the changed squat test), so `online_battle_screen.dart` shows only what other tests reach.
- **Manual check (Android emulator Medium_Phone, 2026-11-14):** a temporary demo (not committed) with dummy reports and
  battles: the current result screen offers the feedback for a squat; the current feedback screen shows 인정 4 · 무효 2,
  '얕은 스쿼트 2회' with its tip and 6 rep rows (UAT-4 squat run); the view-model values matched hand counts (push-up
  185→240 new best, recent 8, average 136 of 5, this battle's own upload left out; a past online battle compared only
  with the 4 battles before it). Not run on a phone: bot squat battles use `SquatDemoJudge` (S4), which never rejects,
  so the 2 rejected squats appear only online until S4 changes the judge.
- **Reviewer:** CHANGES_REQUESTED in round 1 (Major: a squat with even arms got the push-up praise '양팔 균형'; Major:
  missing Design doc rows; three Minor), APPROVE in round 2 after the fixes and +3 tests.

Test cases added or changed:

| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/feedback_form_report_test.dart` (new, 4) | push-up by default; a squat report keeps its exercise through JSON; an old report without it and an unknown exercise read as push-up |
| Service | `test/services/feedback/squat_form_analyzer_test.dart` (new, 18) | UAT-4 squat run: shallow squats the one issue with a tip, highlight and code; push-up rules quiet for a squat; the summary's squat code; not standing up; a rejected squat's figure; clean squats praised; even arms in a squat get no push-up praise (push-ups still do); late depth: squat 0.15 line, push-up 0.25 line, too few reps, the middle rep of an odd count; arm balance: unknown for squats, even, left/right deeper as in the finding, too few or top-only samples |
| ViewModel | `test/viewmodels/feedback_viewmodel_test.dart` (updated, +9) | server and phone reports come with their feedback; a report in hand is ready at once and never loads; UAT-4 squat run values; mean depth over counted reps only; pace per 5 s slice; a KO round's shorter slices; a round without length; the given analyzer's rules |
| ViewModel | `test/viewmodels/result_viewmodel_test.dart` (new, 26) | a battle just played: values, loading state, next tip (push-up, squat, none), online without rematch and with the opponent leaving; comparison: best/recent 8/average (the data list's 185→240, 136), only the last 7 earlier battles, first battle, fewer than 5, this battle's own upload left out, no score/other exercise/later left out, no game score, failure, retry, double load, dispose; a past battle: values, only battles before it, its form report for the tip, no feedback no request, missing or failed report, no scores, no server id, no time |
| ViewModel / View | `test/viewmodels/battle_viewmodel_test.dart`, `test/screens/online_preparation_test.dart` (one test each, approved one-off exceptions, 송우현's files) | bot and online squat battles save a squat form report |
| Support | `test/support/form_report_fixtures.dart` (updated) | `squatReport`: the UAT-4 squat run (4 full, 2 shallow) with push-up-only numbers the squat rules must ignore |

Acceptance criteria → tests:
- **UAT-4 squat run (4 full and 2 shallow squats → 4 counted, 2 rejected, the squat issues with tips, one row per
  rep):** `UAT-4 squat run: 4 counted, 2 rejected, the issue, a row per rep`, the group `UAT-4 squat run: 4 full and 2
  shallow squats`, `a squat bot battle is saved too, with a squat form report`, `a squat result saves and carries a
  squat form report`. On a phone only online for now (see Manual check).
- **Result report values (previousBest/isNewBest, recentScores/recentFrom, recentAverage/Of, nextTip, form, rematch;
  battle just played and past battle):** `previous best, recent 8 and the 5-battle average`, `compares only with the
  battles before it`, `the next tip is the first issue's fix`, `online: no rematch, and the opponent leaving is said`.
- **Feedback values moved out of the screen (meanDepth, depthTrend, armBalance, paceBuckets/sliceSeconds/
  repsPerSecond):** the group `feedback values the screen shows`, `the more bent arm is named, as in the imbalance
  finding`, `a push-up losing 0.25 is dropped, the same as its finding`.

#### 2026-11-14 · code at commit `51052b7` · step `feat/cumulative_feedback` (team plan #9, P12 cumulative feedback)
The data for the archive and the statistics (UAT-4 AC3), no screen (the screens are 송우현's W7): the server's
`GET /matches/stats` gives every battle of a period as a compact point, summaries keep stable issue codes, and rows
carry `is_online`; the app groups by local midnight. `HistoryViewModel` adds the archive summary (last 7 days, streak,
score growth, best gains) next to the list, and `FeedbackStatsViewModel` gives, per period (all, this month, this
week), the average counted reps, reps by day and issue counts. Match records read KO, bot or online, and a win by the
opponent leaving. Commit `a21a431` is the feature; `51052b7` merges `origin/main` (c3866e5) into it. Commands from the
Plan in `gymrats_app/` on macOS (Flutter 3.47.5 / Dart 3.13.4), and the server tests in `server/`
(`.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats`).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.3% (542/546); `feedback_stats`, `feedback_summary`, `match_record` 100% | 11/14 | `coverage_per_file.sh` + `coverage_by_layer.py` |
| ViewModel | flutter_test, fakes | 90% | 97.1% (1254/1292); `history_viewmodel`, `feedback_stats_viewmodel` 100% | 11/14 | same |
| Service | flutter_test, MockClient, fakes | 85% | 95.8% (2613/2727); `feedback_stats`, `form_summary`, `server_user_repository` 100%, `form_analyzer` 97.7% (its unreached lines are not J3's) | 11/14 | same |
| View | flutter_test (widget) | 75% | 95.0% (6342/6676) (no view file changed in this step) | 11/14 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% total; `matches/serializers.py` 100%, `matches/views.py` 93% (the uncovered lines are IntegrityError race paths from before J3) | 11/14 | pytest `--cov` |

- **Tests:** `flutter test` 2504 passed, 0 failed, 10 skipped (pre-existing, as in the J2 entry). `flutter analyze` no
  issues. Server `pytest` 114 passed, 0 failed. App total 95.6% (10795/11286).
- **Not in the numbers:** `test/screens/online_preparation_test.dart` hit the script's 180-second limit again (it passes
  in `flutter test`); no J3 file depends on it.
- **Manual check (Android emulator Medium_Phone, 2026-11-14):** a temporary demo (not committed) fed 34 dummy battles
  over 5 weeks into both view models: 7-day 136 reps / 10 battles, 8-day streak, bars Sunday to today, growth 80→240
  (push-up) and 84→200 (squat), +25/+30 best-gain chips, KO and online rows, load more; this week's average 13.8 =
  124 / 9 with Monday-to-Sunday bars and six issue codes; the period and exercise tabs recompute. All matched counting
  the dummy data by hand. Not checked against the team server (needs the redeploy, planned with the PM).
- **Reviewer:** APPROVE in round 1 (four Minor fixed: UTC day cut, battles after now, unbounded `IN` list, a comment)
  and round 2 after aligning with 송우현's data list (three Minor fixed: `firstPlayedAt` of the first scored battle,
  future battles out of streak/growth/gains, a doc row).

Test cases added or changed:

| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/feedback_stats_test.dart` (new, 6) | point defaults; value equality of day reps and issue counts; a `reject.` code names its reason (unknown reason null); average per battle, none without battles; growth first and best score; best gain by match id |
| Model | `test/models/feedback_summary_test.dart`, `match_record_test.dart` (updated) | issue codes read and written, missing ones empty; `isOnline` unknown by default, `opponentLeft` false by default |
| Service | `test/services/feedback/feedback_stats_test.dart` (new, 20) | week starts Monday at local midnight (Monday, Sunday, across a year); month from the 1st; per period: average, 7 slots Mon–Sun, one slot per day of the month, only battle days for all, issue counts sorted; empty period; the second before Monday; the last 7 days with zeros; streak from today or yesterday, 0 when older, across a month; growth and best gains (ties, lower scores, the first battle, no score, same time by id); a UTC time cut at local midnight; a battle after now left out everywhere |
| Service | `test/services/feedback/form_analyzer_test.dart`, `form_summary_test.dart` (updated) | each issue's stable code and count (rejections per rep); good points and notes have none; the summary's codes |
| Service | `test/services/user/server_user_repository_test.dart` (updated, +7) | rows read KO, time up, online and a win by the opponent leaving; statistics points with codes; exercise and start sent in UTC; an old server reads as offline; queued battles go first; unreadable points are a server error |
| ViewModel | `test/viewmodels/history_viewmodel_test.dart` (updated, +12) | the summary after the first page; best gain per row; the list before the summary; a failed summary keeps the list and retries; later pages keep it; no request without battles or after a failed page; an earlier load's summary or failure dropped; dispose; a repository that is a statistics source; none without a source |
| ViewModel | `test/viewmodels/feedback_stats_viewmodel_test.dart` (new, 12) | loading; this week by default; switching period or exercise without a new request; same tab no notify; a tab chosen while loading; first tab given; zeros without battles; failure and retry; generic message; double load; dispose; the clock at each computation |
| Server | `server/tests/test_stats.py` (new, 13) | points oldest first with codes and fields; old feedback without codes; exercise and `since` filters (the start included); uncapped; bad queries 422; login 401; only the user's battles; online flag in history and stats; a single match's flag; issue-code checks; codes kept in the list summary; at most 3 queries for stats and history |
| Support | `test/support/feedback_fakes.dart` (new) | `FakeFeedbackStatsSource`, `FakeStatsUserRepository`, `statsPoint` (for W7's screen tests too) |

Acceptance criteria → tests:
- **UAT-4 AC3 (average counted reps, the graph and the issue counts for all / this month / this week):**
  `this week: average, 7 slots Monday to Sunday, issue counts`, `this month: one slot per day from the 1st to today`,
  `every record: only the days with battles, oldest first`, `switching the period needs no new request (UAT-4 AC3)`,
  `test_points_are_oldest_first_with_issue_codes`, `test_points_filter_by_exercise_and_since`. The screen is W7.
- **Archive values (weekReps, weekMatches, streakDays, weekDaily, growth, bestGain, isOnline, gameEnd):** the `archive`
  group in `feedback_stats_test.dart`, `loads after the first page, over every battle`, `the best gain of each row`,
  `history rows read KO, time up and the online flag`.

#### 2026-11-14 · code at commit `6d9fb89` · step `feat/battle_bgm` (team plan #8, Codex review of PR #53, round 2)
Two more Codex findings (P2): leaving an online battle before its result left the battle music playing over the play
screen, and a win or lose jingle still loading when the sound went off played once the sound came back. A battle left
before a decided result now goes back to the menu music, and a loading jingle is dropped on silence. Same commands as
below; coverage not re-measured (two methods changed, both new branches run by the new tests).

- **Tests:** `flutter test` 2364 passed, 0 failed, 10 skipped (pre-existing). `flutter analyze` no issues.
- **Reviewer:** APPROVE (one round; Minor: doc lines (done), these notes (done), a screen-level test of the online
  leave path (not added: the same `BattleSounds` path is unit-tested, and the online screen tests are heavy)).

| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/audio/background_music_test.dart` (+1) | a jingle still loading when sound goes off is dropped, not played when sound is back |
| View | `test/widgets/sound_battle_test.dart` (+1) | leaving before a result (mid-round, waiting for the server, ended without one) brings the menu music back; after a result its jingle, or a draw's silence, goes on |

#### 2026-11-14 · code at commit `6ef8614` · step `feat/battle_bgm` (team plan #8, Codex review of PR #53)
Follow-up to the Codex review of PR #53 (P2): turning the sound off or leaving the app now also cuts off an effect still
sounding (a hit, the KO gong), and a hit whose rewind ends after the sound went off stays silent. Same commands as the
entry below; coverage not re-measured (one method changed, both new branches run by the new tests).

- **Tests:** `flutter test` 2362 passed, 0 failed, 10 skipped (pre-existing, as below). `flutter analyze` no issues.
- **Reviewer:** APPROVE (one round; Minor: re-check after the rewind, the doc rule, these notes; all done).

| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/audio/sound_effects_test.dart` (+2) | sound off, or the app going to the background, cuts off a hit and the gong still sounding (not resumed when sound is back); a hit whose rewind ends after the sound went off stays silent |
| Service | `test/support/audio_fakes.dart` (updated) | `FakeMusicPlayer.seekGate` holds a rewind open |

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
