# Testing notes – Iteration 3 – Woohyun Song

Per-push Results for my Iteration 3 steps, in the Testing Documentation format. The PM merges them into
`docs/testing/Testing-Documentation.md`.

## Results

#### 2026-10-25 · code at commit `62f6a9d` · step W1 `docs/battle_rules` (P4 battle game rules design)
This step adds one design document, `docs/iteration-3/battle-rules.md`, and changes no code or tests. `task.md` says
"Tests: None (design doc)", so the checks below only confirm that the branch is still green. Commands come from the
Plan in `gymrats_app/`. I ran them on Windows without coverage; coverage comes from the PR's CI comment (see the
coverage rows).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | see the CI comment on PR #13 | 10/25 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| ViewModel | flutter_test, fakes | 90% | see the CI comment on PR #13 | 10/25 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| Service | flutter_test, MockClient, fakes | 85% | see the CI comment on PR #13 | 10/25 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| View | flutter_test (widget) | 75% | see the CI comment on PR #13 | 10/25 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 10/25 | – |

- **Tests:** `flutter test` 675 passed, 0 failed, 1 skipped. The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`. `flutter analyze` found no issues. Server `pytest` was not run because `server/` did not change.
- **Coverage:** not collected on this PC: `flutter test --coverage` and `coverage_per_file.sh` hang with "getSourceReport: Service has disappeared". Since 2026-10-26 the numbers come from the CI comment on the PR (see the next entry). W1 changes no code, so the per-layer numbers equal those of `main` at `62f6a9d`.
- **Shortfalls:** none against the targets in this step, since no code changed.
- **Test cases added or changed in this step:** none (design document). `task.md` asked for worked examples instead: section 6 of the document has two rep timelines with the resulting bar and score. The reviewer subagent recomputed them with a script.

#### 2026-10-26 · code at commit `fd8a76f` (`main` with PR #14, merged into the branch as `1e07378`) · step W1 `docs/battle_rules`
Before updating PR #13, I merged `origin/main` into the branch. The merge brings only the PM's CI files
(`.github/workflows/tests.yml`, `tools/`) and no app code. I re-ran the checks on Windows on `1e07378`. From now on,
coverage comes from the GitHub Actions run on the PR, which posts one comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 98.1% (210/214) | 10/27 | CI on `fb8e67c`, [run 40345709736](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/40345709736) |
| ViewModel | flutter_test, fakes | 90% | 94.4% (837/887) | 10/27 | (same) |
| Service | flutter_test, MockClient, fakes | 85% | 92.0% (1592/1731) | 10/27 | (same) |
| View | flutter_test (widget) | 75% | 91.6% (3169/3460) | 10/27 | (same) |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (76 passed; `server/` unchanged) | 10/27 | CI `pytest --cov=accounts --cov=matches --cov=gymrats` on `fb8e67c` |

- **Tests:** `flutter test` 675 passed, 0 failed, 1 skipped (`test/services/online/public_wss_smoke_test.dart`, opt-in with `RUN_PUBLIC_BATTLE_SMOKE`). `flutter analyze` found no issues. `ownership_guard.py --check-diff`: ok, the 4 changed files belong to W1. Server `pytest` was not run locally because `server/` did not change; CI runs it.
- **Coverage:** from the CI comment "Tests and coverage (GitHub Actions)" on PR #13, commit `fb8e67c`
  (2026-10-27 00:06 KST, app and server jobs success, run link above). App total 92.3% (5954/6452).
  CI also ran `flutter analyze` (no issues) and `flutter test` (675 passed, 1 skipped), matching the local run.
  Same numbers as the first CI run on `main` (#14, `df1ec0f`), as expected: W1 changes no code.
- **Shortfalls:** none; every layer and the server meet their targets.
- **Test cases added or changed in this step:** none.

#### 2026-10-27 · code at commit `1fd3ef5` · step W4 `feat/safe_warning` (P12 safety warning)
This step adds the safety warning that opens when a match is found, before the pose setup:
- `lib/widgets/safe_warning_dialog.dart`, the dialog.
- Its pictogram, `assets/images/safe_warning.png` at 1x, 2x and 3x.
- The hook-up in `lib/screens/versus_screen.dart` and `lib/screens/online_lobby_screen.dart`. Bot battles wait for 확인; online ones also close after 5 s.

The branch sits on `main` at `fd8a76f`, with PR #14's CI. I ran the commands from the Plan in `gymrats_app/` on Windows, on `1fd3ef5`, without coverage. Coverage comes from the PR's CI comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 98.1% (210/214 lines); no W4 change | 10/27 | CI comment "Tests and coverage (GitHub Actions)" on PR #15, commit `915f825`, [run 40354323954](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/40354323954) |
| ViewModel | flutter_test, fakes | 90% | 94.4% (837/887); no W4 change | 10/27 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 92.0% (1592/1731); no W4 change | 10/27 | same CI comment |
| View | flutter_test (widget) | 75% | 91.0% (3221/3538) | 10/27 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (76 passed); `server/` unchanged | 10/27 | same CI comment, `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` 698 passed, 0 failed, 1 skipped.
  - The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`.
  - `flutter analyze` found no issues.
  - Server `pytest` was not run locally because `server/` did not change.
- **Coverage:** not collected on this PC, because `flutter test --coverage` hangs with "getSourceReport: Service has disappeared". The numbers above come from the CI comment on PR #15 for commit `915f825` (2026-10-27 01:02 KST).
  - CI measures one test file at a time in 4 shards and merges them by line.
  - App total is 92.0% (6006/6530 lines, with "Other" 91.2%).
  - The CI also reports `flutter analyze` with no issues and `flutter test` 698 passed, 1 skipped, 0 failed.
- **Left out of the coverage numbers:** `test/screens/setup_screen_test.dart`, which hit the 240 s per-file limit in the coverage run. It still passed in `flutter test`. It is not a W4 file, so `SetupScreen` lines count as not hit.
- **Shortfalls:** none. Every layer is above its target.

Test cases added or changed in this step:

| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/safe_warning_dialog_test.dart` (new) | Content and order: picture, title, message, 확인, note. Tokens: card background, lighter picture box, secondary text. Answers: 확인 gives true, back false, removed by the app null. A tap outside keeps it open. The countdown runs each second and closes it with true. 확인 or back during the countdown stops it. Fits 360×640 and 640×360. The PNGs are 240×150, 480×300 and 720×450, and pubspec lists `assets/images/` |
| View | `test/screens/versus_screen_test.dart` (updated) | The warning opens over MATCH FOUND. Setup starts only after 확인. A tap outside keeps it. Back asks whether to leave, and 계속하기 shows it again. Back then 게임 나가기 goes home with no warning left. A logout that closes every screen asks nothing. Every match shows it. Online: counts down from 5 and closes itself; 확인 before the end stops it. The existing tests close the warning first |
| View | `test/screens/online_lobby_screen_test.dart` (updated) | Online match found: the warning shows "확인 (5)" before setup. It closes itself after 5 s, shorter than `BattleServer`'s default `readyTimeoutMs`. A match cancelled while it is open closes it with the screen. A match found while the cancel dialog is open waits, then shows the warning after 계속하기 |
| Design | `test/design_tokens_test.dart` (updated) | `lib/widgets/safe_warning_dialog.dart` uses only design tokens |

Acceptance criteria → tests:
- **Bot match found, then the warning shows, and pose setup starts only after confirm:** `versus_screen_test.dart` "the pose setup starts only after 확인" and "opens over MATCH FOUND with the picture, the message and 확인".
- **Online match found, then the warning shows, and the match does not time out because of it:** `online_lobby_screen_test.dart` "live flow uses AI radar then real-player VS before camera setup" (closes itself after 5 s, shorter than the server's ready limit) and "leaving … closes both battle and lobby to home" (확인 (5)).

#### 2026-10-30 · code at commit `50b8a18` · step W4 `feat/safe_warning` (simpler pictogram after the device check)
After a check on a phone, the pictogram drops the "×100" text and the repetition lines, and its screen reader label now matches the picture. No logic changed. The branch also has `main` merged in, with #13 and #16. I ran the commands from the Plan in `gymrats_app/` on Windows, on this code, without coverage.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 98.1% (210/214 lines); no W4 change | 10/30 | CI comment "Tests and coverage (GitHub Actions)" on PR #15, commit `8bc26b3`, [run 41049767309](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/41049767309) |
| ViewModel | flutter_test, fakes | 90% | 94.4% (837/887); no W4 change | 10/30 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 92.0% (1592/1731); no W4 change | 10/30 | same CI comment |
| View | flutter_test (widget) | 75% | 91.0% (3221/3538) | 10/30 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (76 passed); `server/` unchanged | 10/30 | same CI comment, `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` 714 passed, 0 failed, 1 skipped.
  - The 16 more than the last entry are `test/ai_eval/` from PR #16 on `main`; this push adds no tests.
  - The skipped test is `test/services/online/public_wss_smoke_test.dart`, as before.
  - The four W4 test files alone: 55 passed.
  - `flutter analyze` found no issues.
- **Coverage:** from the CI comment on PR #15 for `8bc26b3` (2026-10-30 20:46 KST). The app total is 92.0% (6006/6530 lines), all layers are above target, and the numbers are the same as in the entry above. The CI also reports `flutter analyze` with no issues and `flutter test` 714 passed, 1 skipped, 0 failed. The push's only W4 changes are the PNGs and one label string; it also brought in `test/ai_eval/` from #16.
- **Left out of the coverage numbers:** `test/screens/setup_screen_test.dart`, which hit the 240 s per-file limit in the coverage run, as before. It still passed in `flutter test`, and it is not a W4 file.
- **Shortfalls:** none. Every layer is above its target.
- **Test cases added or changed in this step:** none. `safe_warning_dialog_test.dart` still checks the PNG sizes (240×150, 480×300, 720×450), and the tests read the label from `SafeWarningDialog.pictureLabel`.
- **Manual check (done by the user):**
  - Phone, 2026-10-29, earlier picture: on a bot match found the warning shows, and back on the warning brings up the leave question.
  - Phone, reported 2026-10-30, simplified picture: checked, and the picture stays as it is.
  - Online match, phone and emulator, reported 2026-10-30: on the phone, left untouched, the warning closed by itself after 5 s; on the emulator, 확인 closed it. Both went on to the pose setup, and the match was not cancelled.

#### 2026-10-31 · code at commit `b9f9195` · step W3 `feat/fever_score` (P8 game layer: bar, judgments, fever, danger, KO)
This step turns the battle into the game of `docs/iteration-3/battle-rules.md`, for bot and online battles:
- The rules in one config, `lib/models/battle_rules.dart`, and the pure-Dart game layer in `lib/services/game/`, which the battle server also imports.
- The battle server scores each rep from the grade the phone sends, and ends the match on a KO.
- The battle and result screens, with new widgets `game_health_bar`, `game_fever_chip`, `game_danger_edge`, and tokens `AppColors.fever` and `AppColors.danger`.
- `POST /matches` accepts an optional `outcome` and `reason`, and the app sends them for a bot battle.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `b9f9195`, without coverage. Coverage comes from the PR's CI comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | see the CI comment on the W3 PR | 10/31 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on the W3 PR |
| ViewModel | flutter_test, fakes | 90% | see the CI comment on the W3 PR | 10/31 | same |
| Service | flutter_test, MockClient, fakes | 85% | see the CI comment on the W3 PR | 10/31 | same |
| View | flutter_test (widget) | 75% | see the CI comment on the W3 PR | 10/31 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | see the CI comment on the W3 PR | 10/31 | same, `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` 851 passed, 0 failed, 1 skipped.
  - The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`.
  - `flutter analyze` found no issues.
  - `server/` changed, so CI's `pytest` is the result for these notes. For information, the 5 new Django tests also passed in a local scratch environment on Python 3.12 before `d98d219` was committed (81 passed in all), and `makemigrations --check` found no changes.
- **Coverage:** not collected on this PC, because `flutter test --coverage` hangs with "getSourceReport: Service has disappeared". The numbers come from the CI comment on the W3 PR. Until the next W3 push, they are in that comment and in the PR body, not here.
- **Flaky test found and fixed:** `battle_result_store_test.dart` "a started battle is recorded with both players" failed in 1 of 4 full runs in review. Its message was not captured. The likely cause is both players joining the queue at once on two sockets while the test expects a fixed player order, so the test now waits for the first join. After the fix: 6 of 6 alone, and clean in the full runs.
- **Shortfalls:** none known; the CI comment decides. Phone checks are still open (see Manual check).
- **Known issues on the largest system fonts, not fixed here (found in review with real fonts; the default font size is clean):**
  - The bot battle's panel overflows on a 360 wide phone at text scale 1.7 and up (360×780: clean up to 1.5). At 360×640 and scale 2.0 the verdict banner is pushed off the panel. 412×915 is clean up to 2.0.
  - Above scale 1.0 a health bar label shrinks when its side's first popup appears, for example from 28 to 16 px high at scale 2.0.
  - The online words line ends in an ellipsis from about scale 1.5.

Test cases added or changed in this step:

| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/game_rules_test.dart` (new) | The v0.1 numbers. Fever's start. Grades at the 1.6× depth and for a rep with no depth. The combo window. The points table. Bar movement and its ends. KO on either side. Danger. A KO round length rounded up and capped. Another config |
| Model | `test/models/battle_result_test.dart` (updated) | The game's outcome wins over the reps. Big numbers and margin with and without a game. The record says how the game stopped |
| Model | `test/models/match_record_test.dart` (updated) | The record keeps how the game stopped; a record from elsewhere has none |
| Service | `test/services/game/battle_game_test.dart` (new) | Combo, fever, the time-up winner, KO, the two worked examples of `battle-rules.md` section 6, and its 4.4 table against a bot |
| Service | `test/services/opponent/bot_opponent_test.dart` (updated) | About a fifth of the valid reps are excellent at the push-up pass depth; rejected reps have no depth; the same seed plans the same depths |
| Service | `test/services/user/server_user_repository_test.dart` (updated) | A game's outcome and reason go in the upload (`win`/`ko`, `loss`/`time_up`, `draw`/`time_up`); a record without a game sends neither |
| Service | `test/services/online/online_battle_integration_test.dart` (updated) | On the server, over real sockets: rules in `match.found`, points, combo, grade, a bad grade refused, fever, the winner by game score, KO after the ACK, a re-sent KO rep, the snapshot. On the phones: the same score and a mirrored bar, the rules from the server, +N and label at once, the answer correcting it, no second popup, a stale answer ignored, final scores, the frozen clock, an older server gets no grade |
| Service | `test/services/online/battle_result_store_test.dart` (updated) | A KO is stored with its reason, without the game score; the join order no longer races |
| Service | `test/support/game_fakes.dart` (new) | Fakes: `gameRep`, `DepthRepJudge` (its clock is an hour per rep, so a game fed the wrong clock fails), `TimedOpponentSource` |
| ViewModel | `test/viewmodels/battle_viewmodel_test.dart` (updated) | Each rep's score and bar, combo by round time, fever, danger, my KO and the opponent's, the KO round length, the last-frame rep, retry from zero |
| View | `test/screens/battle_screen_test.dart` (updated) | +N and the banner words, clock colors, the fever chip, the danger edge, K.O., fits 360×640 |
| View | `test/screens/result_screen_test.dart` (updated) | Points big and reps under them, the KO and level-points lines, fits 360×640, no reps line without a game |
| View | `test/screens/online_preparation_test.dart` (updated) | The online screen with the game: scores, valid reps, bar, words at once, Korean reject reason, combo and fever words, clock colors, the chip gone at the end, danger edge on and off, KO text and report with the time played, a frozen plain clock, the largest font. An older server keeps the reps screen |
| View | `test/widgets/game_health_bar_test.dart` (new) | Share, labels and semantics, each +N in its side's color, fade, a new rep pops again, both popups at the largest font, the bar keeps its place |
| View | `test/widgets/game_fever_chip_test.dart` (new) | The multiplier in dark letters on cyan |
| View | `test/widgets/game_danger_edge_test.dart` (new) | Off when not active, red flash slower than once a second, pixel check that only the edge lights, taps pass through, steady with animations off, screen reader label |
| View | `test/widgets/game_panel_fonts_test.dart` (new) | With real fonts: the banner never cuts its words, and three digits stay the size of two |
| Design | `test/theme/app_theme_test.dart`, `test/design_tokens_test.dart` (updated) | The two new tokens; the new widgets use only design tokens |
| View | `test/demo/battle_demo_test.dart` (updated) | The demo with the game's scores |
| Server | `server/tests/test_matches.py` (updated) | A bot upload keeps the game's outcome and reason; without them it goes by the reps and `time_up`; other values refused; a retry keeps the first outcome |
| Server | `server/tests/test_results.py` (updated) | A KO is stored with its reason whatever the reps |

Acceptance criteria → tests:
- **Bot battle, valid reps move the bar and show +N with the right label:** `battle_viewmodel_test.dart` "a valid rep pushes the bar and scores by its depth"; `battle_screen_test.dart` "a deep rep says EXCELLENT, and the banner names a combo and fever".
- **In fever a valid rep scores double:** `battle_viewmodel_test.dart` "fever turns on at its start and doubles the points"; `online_battle_integration_test.dart` "fever doubles the points on both phones".
- **A fully pushed bar ends the match early with that winner:** `battle_viewmodel_test.dart` "my KO ends the round at once, and the battle is saved" and "the opponent's KO ends the round; later reps count for nothing"; `online_battle_integration_test.dart` "a KO ends the match at once, after the ACK, for both".
- **A player close to losing sees the danger edge:** `battle_viewmodel_test.dart` "the opponent's reps push the bar back and bring danger"; `online_preparation_test.dart` "the danger edge is on 60 points behind, off once it ends".
- **Online, both phones show the same bar and winner:** `online_battle_integration_test.dart` "both phones show the same score, the bar mirrored, and +N with its grade; a deep rep goes as excellent". Checked over real sockets, not yet on two devices.

- **Manual check:**
  - Bot battle, round 1, the user staying still, on the user's phone (reported 2026-10-31, code at `d98d219`): pass. +N and the bar moved, the red edge showed, the clock turned cyan with FEVER ×2, then the K.O. screen and a result with game scores and valid reps. The reps were the bot's.
  - Not done yet: bot round 2 (own +N and the Good/Excellent banner, the amber last 5 s, a time-up end).
  - Not done yet: online on real devices. The team server runs the old battle server until it is redeployed, so online needs that redeploy or a temporary local patch.
