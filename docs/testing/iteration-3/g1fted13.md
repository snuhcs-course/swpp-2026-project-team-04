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

#### 2026-10-31 · code at commit `d0f056b` · step W2 `feat/help_screen` (P10 rules screen and '?' on home)
This step adds the battle rules screen, shown once before home after a sign-up and again from '?' on home:
- `lib/screens/help_screen.dart`, three swipe pages, with `lib/widgets/help_pictures.dart` (one picture per page, drawn in code) and `lib/widgets/help_rules.dart` (all rule texts and numbers in one place).
- `lib/services/user/rules_seen_store.dart` and `lib/viewmodels/help_viewmodel.dart`: a per-account flag in secure storage decides whether the rules show before home.
- `lib/main.dart` (the gate and the `/help` route) and `lib/viewmodels/signup_viewmodel.dart` (a sign-up marks the new account).
- A '?' button in the greeting header of `lib/screens/home_screen.dart`, which opens the same screen.

The branch started from `main` at `fd8a76f`. `origin/main` at `9baf937`, with #13, #15, #16, #18 and #19, is merged in as `d9c9c80`, with no conflict. That merge opened the `feat/squat_judge` lock on `home_screen.dart`, so the '?' came last. I ran the commands from the Plan in `gymrats_app/` on Windows, on this code, without coverage. Coverage comes from the PR's CI comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.7% (215/220 lines) | 10/31 | CI comment "Tests and coverage (GitHub Actions)" on PR #21, commit `b029ff8`, [run 41204004041](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/41204004041) |
| ViewModel | flutter_test, fakes | 90% | 94.5% (868/919) | 10/31 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 92.3% (1727/1872) | 10/31 | same CI comment |
| View | flutter_test (widget) | 75% | 91.5% (3418/3736) | 10/31 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (76 passed); `server/` unchanged | 10/31 | same CI comment, `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` 770 passed, 0 failed, 1 skipped.
  - The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`.
  - The nine test files in the table below alone: 101 passed.
  - `flutter analyze` found no issues.
  - Server `pytest` was not run locally because `server/` did not change.
- **Coverage:** not collected on this PC, because `flutter test --coverage` hangs with "getSourceReport: Service has disappeared". The numbers above come from the CI comment on PR #21 for commit `b029ff8` (2026-10-31 22:11 KST), filled in after that PR merged.
  - The app total is 92.3% (6387/6921 lines, with "Other" 91.4%).
  - The CI also reports `flutter analyze` with no issues and `flutter test` 770 passed, 1 skipped, 0 failed.
- **Left out of the coverage numbers:** `test/screens/setup_screen_test.dart`, which hit the 240 s per-file limit in the coverage run, as before. It still passed in `flutter test`, and it is not a W2 file.
- **Mutation check of the '?' (review round 4):** the reviewer ran 19 mutations against six of these test files in a scratch copy, and 17 failed a test. They included a wrong route, a target shrunk below 48×48, a removed button, a removed `Expanded`, and a removed or first-login `/help` route. The two survivors made the `/help` route write the flag when it opens. The two `auth_flow_test.dart` tests with "saves nothing" in their names were added for them. I reran both mutations in the working tree: `auth_flow_test.dart` then fails exactly those two tests. The mutations were reverted, and `main.dart` is unchanged.
- **Flaky test outside this step:** `test/services/online/battle_result_store_test.dart` "a forfeit is stored as a loss for the player who left" failed once in a full run in review on 2026-10-27 (expected `['win','loss']`, got `['loss','win']`), and passed alone 3 of 3. The full runs recorded since then passed. It is not a W2 file. W3's PR (#20, commit `d0ed8aa`) makes the players join in a fixed order in `playing`, the helper this test uses. That is the likely cause, not a proven one, and until W3 merges the test can still fail now and then on this branch.
- **Shortfalls:** none. Every layer is above its target. The phone check is still open (see Manual check).
- **Known limit, not fixed here:** the '?' takes 48 px from the greeting line. In the reviewer's scratch run with the real fonts, at 360 wide, names up to 4 characters stay on one line, and the 6- and 12-character names wrap to two lines, with no overflow. Only the 12-character name wraps at 412 wide.

Test cases added or changed in this step:

| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/user/rules_seen_store_test.dart` (new) | An account without a saved flag counts as seen. The flag survives a new store and is kept per account. Only a saved "false" means not seen. `MemoryRulesSeenStore` behaves the same |
| ViewModel | `test/viewmodels/help_viewmodel_test.dart` (new), fake in `test/support/help_fakes.dart` (new) | Checks until the flag is read. No account means home. Per-account decisions. An unreadable flag counts as seen. The same account logging in again keeps its decision, and a late read for an account that left is dropped. A sign-up shows the rules at once, before the flag is saved, and a failed save still shows them. A read that ended before the sign-up is overruled. `markSeen` goes home and saves, a failed save still goes home, and it does nothing while the rules are not showing. A read that ends after dispose changes nothing |
| ViewModel | `test/viewmodels/signup_viewmodel_test.dart` (updated) | A new account sees the rules before home. A refused sign-up or invalid fields mark no account |
| View | `test/screens/help_screen_test.dart` (new) | 다음 turns the three pages, with their texts, pictures and icon colors. Swiping turns them too. After sign-up: no back arrow, 건너뛰기 calls `onStart`, and the last page has 시작하기 and its hint. From home: no 건너뛰기, and back or 확인 returns home. Every page fits 412×915 and 360×740 with no overflow and one `AccentButton` |
| View | `test/widgets/help_rules_test.dart` (new) | The base time and fever add up to the battle length. Three pages in order. Every number on the pages comes from the constants |
| View | `test/screens/home_screen_test.dart` (updated) | '?' opens the real `HelpScreen` with no 건너뛰기, and back returns home. '?' is 48×48, left of the profile button, in the secondary text color. A long name wraps beside all three buttons at 360×640 with no overflow |
| App flow | `test/auth_flow_test.dart` (updated) | Sign-up shows the rules before home, and 시작하기 opens home. The rules show again after a restart before 시작하기, never after it. A returning user logs in straight to home. Each new account sees the rules once. Slow storage: sign-up never shows home first, and a login waits, then opens home. '?' after a sign-up or a login saves nothing, by back or by 확인, and a restart stays on home |
| App flow | `test/main_test.dart` (updated) | '?' on the real `GymRatsApp` opens the rules over home with no 건너뛰기, and back returns home |
| Design | `test/design_tokens_test.dart` (updated) | `help_screen.dart`, `help_pictures.dart` and `help_rules.dart` use only design tokens |

Acceptance criteria → tests:
- **A new account, when sign-up succeeds, sees the rules before home, once:** `auth_flow_test.dart` "sign-up shows the rules before home; 시작하기 opens home", "the rules show once: again after a restart before 시작하기, never after it", "each new account on the phone sees the rules once", "with slow phone storage, sign-up never shows home before the rules".
- **A returning user who logs in gets home directly:** `auth_flow_test.dart` "a returning user logs in straight to home", "with slow phone storage, a login waits, then opens home".
- **On home, '?' opens the rules and back returns home:** `main_test.dart` "'?' on home opens the rules over home; back returns home", `home_screen_test.dart` "'?' opens the rules from the greeting; back returns home", "'?' has a 48×48 tap target and sits left of the profile", `auth_flow_test.dart` "'?' after sign-up saves nothing, and a restart stays on home", "'?' after a login saves nothing when 확인 returns home".

**Manual check:** 아직 (not done yet). This step has not been checked on a phone.

#### 2026-10-31 · code at commit `b9f9195` · step W3 `feat/fever_score` (P8 game layer: bar, judgments, fever, danger, KO)
This step turns the battle into the game of `docs/iteration-3/battle-rules.md`, for bot and online battles:
- The rules in one config, `lib/models/battle_rules.dart`, and the pure-Dart game layer in `lib/services/game/`, which the battle server also imports.
- The battle server scores each rep from the grade the phone sends, and ends the match on a KO.
- The battle and result screens, with new widgets `game_health_bar`, `game_fever_chip`, `game_danger_edge`, and tokens `AppColors.fever` and `AppColors.danger`.
- `POST /matches` accepts an optional `outcome` and `reason`, and the app sends them for a bot battle.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `b9f9195`, without coverage. Coverage comes from the PR's CI comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 98.3% (232/236 lines) | 10/31 | CI comment "Tests and coverage (GitHub Actions)" on PR #20, commit `e863b51` (the same code, with the notes), [run 41185365660](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/41185365660) |
| ViewModel | flutter_test, fakes | 90% | 94.7% (884/933) | 10/31 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 93.9% (1717/1828) | 10/31 | same CI comment |
| View | flutter_test (widget) | 75% | 91.9% (3458/3763) | 10/31 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (81 passed) | 10/31 | same CI comment, `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` 851 passed, 0 failed, 1 skipped.
  - The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`.
  - `flutter analyze` found no issues.
  - `server/` changed, so CI's `pytest` is the result for these notes. For information, the 5 new Django tests also passed in a local scratch environment on Python 3.12 before `d98d219` was committed (81 passed in all), and `makemigrations --check` found no changes.
- **Coverage:** not collected on this PC, because `flutter test --coverage` hangs with "getSourceReport: Service has disappeared". The numbers above come from the CI comment on PR #20 for commit `e863b51` (2026-10-31 17:43 KST).
  - The app total is 93.0% (6437/6920 lines, with "Other" 91.2%).
  - The CI also reports `flutter analyze` with no issues and `flutter test` 851 passed, 1 skipped, 0 failed.
- **Left out of the coverage numbers:** `test/screens/setup_screen_test.dart`, which hit the 240 s per-file limit in the coverage run, as before. It still passed in `flutter test`, and it is not a W3 file.
- **Flaky test found and fixed:** `battle_result_store_test.dart` "a started battle is recorded with both players" failed in 1 of 4 full runs in review. Its message was not captured. The likely cause is both players joining the queue at once on two sockets while the test expects a fixed player order, so the test now waits for the first join. After the fix: 6 of 6 alone, and clean in the full runs.
- **Shortfalls:** none. Every layer is above its target. Phone checks are still open (see Manual check).
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

#### 2026-10-31 · code at commit `65dfe2b` · step W3 `feat/fever_score` (after W2 merged: the judge's pass depth, help numbers, red icon, home hint)
This push merges `origin/main` at `ea83fc1`, with S1 (#18), S2 (#19) and W2 (#21), as `2e373ca`, and then changes:
- The game grades a rep by its judge's pass depth, not the push-up judge's constant: `BattleViewModel` reads `counter.passDepth`, and `OnlineBattleScreen` hands `_counter.passDepth` to `OnlineBattleSession.submitRep`. For push-ups it is the same 1.1.
- `lib/widgets/help_rules.dart` reads its numbers from `BattleRules`. The words on the rules screen stay the same; a probe in review compared them with W2's file.
- The rules page's danger icon is red, like the danger edge.
- The online button's hint on home says `30초가 끝나면 점수가 높은 쪽 승리`, in the rules screen's words. The old hint said more reps win.
- The battle demo's long press gives only push-up reasons. S2's squat reasons had reached it through `RejectReason.values`, a side effect of the merge that review round 14 found.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `65dfe2b`, without coverage. Coverage comes from the PR's CI comment, "Tests and coverage (GitHub Actions)", on `7de22f2`, the merged head: `65dfe2b` plus these notes. [Run 41210352997](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/41210352997): 912 passed, 1 skipped.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.9% (237/242) | 10/31 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #20, commit `7de22f2`, run 41210352997 |
| ViewModel | flutter_test, fakes | 90% | 94.9% (915/964) | 10/31 | same |
| Service | flutter_test, MockClient, fakes | 85% | 94.1% (1852/1969) | 10/31 | same |
| View | flutter_test (widget) | 75% | 92.3% (3683/3989) | 10/31 | same |
| Total, with Other at 91.4% (159/174) | | | 93.3% (6846/7338) | 10/31 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (81 passed); `server/` unchanged in this push | 10/31 | same, `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` 912 passed, 0 failed, 1 skipped.
  - The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`.
  - `flutter analyze` found no issues.
  - Server `pytest` was not run locally because this push does not change `server/`.
- **Coverage:** not collected on this PC, because `flutter test --coverage` hangs with "getSourceReport: Service has disappeared". The numbers above come from the CI comment on PR #20 and were filled in at the next push (W3b). All layers met their targets. As in earlier runs, `test/screens/setup_screen_test.dart` is left out of the coverage numbers by CI's 240 s limit; it still ran in `flutter test`.
- **Mutation check (review round 14):** the reviewer ran 22 mutations in a scratch copy, and 19 failed a test. They included a hard-coded pass depth, the screen not handing the depth in, the session ignoring it, an amber icon, wrong help numbers, and the old hint. The three survivors: one help number equal to today's default, caught once the config changes; which reason a rejected bot rep carries, which nothing reads; and two squat wire codes swapped, which the server only validates.
- **Shortfalls:** none: CI met every target. Phone checks were still open at this push (see Manual check). W2 and the W3 bot battle are done in the W3b entry below; online on real devices is still open.
- **Known issues, not fixed here:**
  - A squat battle, once #17 brings one. `BattleGame` grades both players against one pass depth, so S2's 0.75 makes the threshold 1.2, and the bot's depths are 1.4 and 1.9. The reviewer's probe over 1000 seeded rounds, with a user at the bot's pace whose reps are all Good:

    | Battle | Threshold | Bot Excellent | User loses | Danger edge shows |
    |---|---|---|---|---|
    | Push-up | 1.76 | 19.8% | 93.9% | 0.1% |
    | Squat | 1.20 | 100% | 100% | 99.7% |

    W3 builds cannot reach this: home and the online screen play push-ups only. It goes in the PR's note for #17 after this push's CI.
  - The hint fits one line on a 360 wide phone with the real fonts up to text scale 1.15 and wraps to two lines from 1.2, with no overflow up to 2.0. It also wraps at 320 wide.
  - When the numbers are tuned, `test/models/game_rules_test.dart` and the literals `KO 100점 차` and `20초부터 ×2` in `test/screens/help_screen_test.dart` change with them: they pin today's values.
  - The largest-font issues in the W3 entry above still stand.

Test cases added or changed in this step:

| Layer | File | What it covers |
|---|---|---|
| ViewModel | `test/viewmodels/battle_viewmodel_test.dart` (updated) | A rep's grade goes by its judge's pass depth: at 0.75, a depth of 1.2 is excellent and 1.19 is good |
| Service | `test/services/online/online_battle_integration_test.dart` (updated) | Over real sockets, a rep's grade goes by the pass depth it is given; with none, by the push-up judge's. From S2: the `RejectReason.values` loop covers the two squat reasons |
| Service | `test/support/game_fakes.dart` (updated) | `DepthRepJudge` takes a judge config |
| View | `test/screens/online_preparation_test.dart` (updated) | The screen hands its counter's pass depth: at 0.75, a depth of 1.2 says `+15 EXCELLENT` |
| View | `test/widgets/help_rules_test.dart` (updated) | The help numbers are `battleRules`' numbers |
| View | `test/screens/help_screen_test.dart` (updated) | The danger row's icon is red, the others lime |
| View | `test/screens/home_screen_test.dart` (updated) | The new hint on the online button |
| View | `test/demo/battle_demo_test.dart` (updated) | Long presses take turns over the push-up reasons only, and start over after the last |
| Design | `test/design_tokens_test.dart` (merge, both sides kept) | The `game_*` and `help_*` widgets use only design tokens |

Acceptance criteria → tests:
- **The game grades by the judge's pass depth:** `battle_viewmodel_test.dart` "a rep's grade goes by its judge's pass depth"; `online_preparation_test.dart` "a rep's grade goes by the counter's pass depth"; `online_battle_integration_test.dart` "a rep's grade goes by the pass depth it is given; with none, by the push-up judge's".
- **The rules screen's numbers come from `BattleRules`:** `help_rules_test.dart` "the numbers are the game's", "every number on the pages comes from the constants".
- **The rules page's danger icon is red:** `help_screen_test.dart` "다음 turns through the three pages with their pictures".
- **The home hint says the higher score wins:** `home_screen_test.dart` "shows the greeting, exercise card and start button".
- **A push-up battle never shows a squat reason in the demo:** `battle_demo_test.dart` "long presses take turns over the push-up reasons only".

- **Manual check:**
  - Bot battle, round 2, the user doing push-ups, on the user's phone (reported 2026-10-31, on the committed W3 code as the user had planned, commit not stated; `main`'s judge, before H2's 0.68 fix, so H2 may change depth judging). This predates this push's changes.
    - Try 1, hands about shoulder width: the user could not go low enough, and almost no rep counted.
    - Try 2, hands a little wider than the shoulders, going deep: most reps counted, and +N and the Good banner were right.
    - The cyan clock with FEVER ×2 and the amber last 5 s were right.
    - Excellent never showed. Whether the cause is the user's form or the threshold (pass depth 1.1 × 1.6 = 1.76) is an open item the user is sharing with the team; it needs teammates' tests. The numbers are not changed.
    - Not reported: the bar's move on the user's own reps, the rejected banner's words, a time-up end.
  - Not done at this push: this push on a phone, including W2's whole check, the red icon and the new hint. Done on `0465943` on 2026-11-01, except the new hint's words: see the W3b entry below.
  - Not done yet: online on real devices, for the same reason as above.

#### 2026-11-01 · code at commit `d5e9c54` · step W3b `feat/average_score` (team order #6b: Average +5, three score grades)
This push adds the Average grade, as the user decided with the PM on 11-01, and an optional pass depth on the bot:
- A rep rejected with Go lower whose `minElbowAngle` is 105° or less earns 5 points: 10 in fever, no combo bonus, the combo breaks, not a valid rep. Any other reason, a larger angle, or no angle earns 0. The judge's verdict and reason do not change.
- Bot battle: the banner shows the reason with `+5 AVERAGE`; the scoreboard and the health bar move. Result screen: `Excellent N`, `Good N`, `Average N`.
- Online: `rep.submit` carries `grade: "average"`, and the server scores it with the same code. The server announces `average_points`, and the app sends the grade only when it was announced.
- `BotOpponent(passDepth:)` scales its depths; with the default 1.1 they stay exactly 1.4 and 1.9.
- The rules screen's score table has a fourth tile.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `d5e9c54`, without coverage. Coverage comes from the PR's CI comment, "Tests and coverage (GitHub Actions)", on `5ddac4f`, the pushed head: `d5e9c54` plus these notes. [Run 41227896404](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/41227896404): 1067 passed, 9 skipped.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 98.4% (242/246) | 11/01 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #23, commit `5ddac4f`, run 41227896404 |
| ViewModel | flutter_test, fakes | 90% | 96.1% (927/965) | 11/01 | same |
| Service | flutter_test, MockClient, fakes | 85% | 94.3% (1942/2060) | 11/01 | same |
| View | flutter_test (widget) | 75% | 92.4% (3746/4052) | 11/01 | same |
| Total, with Other at 70.1% (122/174) | | | 93.1% (6979/7497) | 11/01 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (81 passed); Django unchanged in this push | 11/01 | same, `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` 1067 passed, 0 failed, 9 skipped. The count includes the Dart battle server's tests.
  - One skip is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`.
  - Eight skips are the `knownErrors` cases in `test/services/pose/pushup_error_cases_test.dart`, from H1 and H2 (#22). None is a W3b test.
  - `flutter analyze` found no issues. `dart analyze` on `server/lib/battle_server.dart` and `server/bin/server.dart` found no issues.
  - Server `pytest` was not run locally because this push does not change Django.
- **Coverage:** not collected on this PC, because `flutter test --coverage` hangs. The numbers above come from the CI comment on PR #23 and were filled in at the next push. All layers met their targets. As in earlier runs, `test/screens/setup_screen_test.dart` is left out of the coverage numbers by CI's 240 s limit; it still ran in `flutter test`.
- **Other fell from 91.4% on #20 to 70.1%; cause not found.** All of it is `shared/battle_protocol.dart` (41/42 to 4/42), which this step does not change. `online_battle_integration_test.dart` passed all its tests, but in the CI artifacts its coverage report lists 14 source files, against 101 on #20's run. Other has no target.
- **Probes and mutations, in scratch copies, not committed:**
  - Review round 17, against the real `0465943` code. A new app with a W3 server sent no grade and got 0 points, with no error. A W3 app with a new server showed the same score, bar and outcome, with no error. An Average rep held back and sent again after `REP_OUT_OF_ORDER` scored correctly.
  - Review round 19: bot plans over 500 seeds at 30, 45 and 60 s were byte-identical to `origin/main`, by `cmp`.
  - Review round 17: 16 mutations, 12 failed a test. The 4 survivors got tests (the result's pass depth, the online counts' rules and pass depth, another grade on Go lower), and round 18 confirmed each now fails.
  - Review round 18: of 10 more mutations, 7 failed a test. The 3 survivors got checks, and round 19 confirmed each now fails.
  - Review round 19: removing the rules page's points shrink left the test green, because it compared "+10" with "+15". The check now compares both with "+5".
  - Review round 18: the plain reject banner was byte-identical to `origin/main` in 44 full-screen renders (11 reasons, 4 text scales, 360x780, real fonts).
  - Replay of the team's recorded sets in `test/fixtures/pushup_cases` through today's judge, with a temporary test I then deleted: 95 judged reps, 6 of them Go lower. Half-rep head nods at 127.8°, 137.8° and 145.2°, a belly-down rep at 151.7° and a knee rep at 175.2° earn 0. The last rep of a normal set, at 43.9°, earns Average. No recorded rep is at 90–91°, so this checks only the side above 105°.
- **Shortfalls:** none: CI met every target. The phone check of W3b itself was open at this push; see the next entry.
- **Known issues, not fixed here:**
  - 105° comes from one person's recordings; the next entry replaces it with 120°. The rule has no lower limit, so an angle such as 43.9° also counts.
  - The result's grade counts use this phone's records. Online they can differ from the server's score in rare cases: a rep closed in the round's last moment, or an app restarted mid-round. `battle-rules.md` 3.6 says so.
  - The result screen reads the pass depth from `judgeFor(exercise)`, and the game reads `counter.passDepth`. They are the same today. #17 injects `SquatDemoJudge` through `judge:`, which gives the game 1.1 and the result 0.75; both grade Good only because that judge sets no `maxDepth`. In the PR's note for #17.
  - Passing `passDepth` to a squat bot is #17's: until then, a squat bot still plays push-up depths.
  - `BattleState.myLastScore`'s comment in `battle_viewmodel.dart` still says "latest valid rep": only one line of that file was approved.
  - At text scale 1.5 on 360x640 and 360x740, and at 2.0 on 360x780, the panel overflows with any banner, as on `main` (round 18 measured the Average banner at the same pixels as the plain one).
  - Shrunk words make the rules-page tiles uneven in height at larger text: slightly at 1.3 and 1.5, and from 88.6 to 116 at 2.0 on 360 wide.

Test cases added or changed in this step:

| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/game_rules_test.dart` (updated) | The numbers 5 and 105; the angle's boundary; no angle; 0 points turn Average off; a tuned config; points with fever; the label |
| Service | `test/services/game/battle_game_test.dart` (updated) | Angles that earn 5 and angles that earn 0, every other reason, a valid rep's angle ignored, fever, combo, the opponent, a KO on Average, the tie by valid reps |
| Service | `test/services/game/rep_grade_test.dart` (new) | `gradeOf`, `earnsAverage`, `addRep`, and `GameGradeCounts` by pass depth and rules |
| Service | `test/services/opponent/bot_opponent_test.dart` (updated) | Default depths exactly 1.4 and 1.9; a squat pass depth scales them, keeps a fifth Excellent, and changes only the depths; rejected reps earn nothing |
| Service | `test/services/online/online_battle_integration_test.dart` (updated) | Server: score, combo, fever, KO, re-send, snapshot, refused combinations, an older app. Phones: same score and bar on both, no grade for a rep that earned nothing, the preview, a server with no Average |
| Service | `test/support/game_fakes.dart` (updated) | Reps with an elbow angle |
| ViewModel | `test/viewmodels/battle_viewmodel_test.dart` (updated) | The angle reaches the game (fails without the approved line); above the angle or with none; the final score; the bot's rejected rep |
| View | `test/screens/battle_screen_test.dart` (updated) | The banner with the reason and `+5 AVERAGE`, score and bar; `+10` in fever; no points on a later rejected rep; a valid rep's own banner after it |
| View | `test/screens/result_screen_test.dart` (updated) | The three grades, zeros, a squat by its pass depth, hidden with no report or no game, 360 wide and text scale 2 |
| View | `test/screens/online_preparation_test.dart` (updated) | The online words for an Average rep and for the rep after it; a server with no Average; the result's grades by the server's rules and the counter's pass depth |
| View | `test/widgets/game_panel_fonts_test.dart` (updated) | Real fonts: the Average banner at 360x780, 360x640 and 412x915 and at larger text; four tiles at 360 wide up to text scale 2; the result's grades at 360 wide up to text scale 2 |
| View | `test/widgets/help_rules_test.dart`, `test/screens/help_screen_test.dart` (updated) | Average's points from `BattleRules`; the fourth tile on the page |

Acceptance criteria → tests:
- **Go lower at 105° or less earns +5 (+10 in fever), breaks the combo, is not a valid rep:** `battle_game_test.dart` group "average"; `battle_viewmodel_test.dart` "a Go lower rep with bent elbows reaches the game with its angle: the score and the bar move, and it stays rejected".
- **Above 105°, no angle, or another reason earns 0:** `battle_game_test.dart` "a Go lower rep with no elbow angle earns nothing", "every other reject reason earns nothing, however bent the elbows"; `battle_viewmodel_test.dart` "a Go lower rep above the angle, or with none, scores nothing".
- **The banner shows the reason and +5 AVERAGE, and the score and bar move:** `battle_screen_test.dart` "shows the reason with +5 AVERAGE, and the score and the bar move while the valid reps stay".
- **The result shows all three grades:** `result_screen_test.dart` "all three show how many of my reps got them"; `online_preparation_test.dart` "the result counts the user's grades".
- **Both phones get the same score:** `online_battle_integration_test.dart` "an average rep shows the same score and bar on both phones, and stays rejected".
- **Old server or old app, nothing breaks:** `online_battle_integration_test.dart` "a server with the game but no Average gets no grade on a rejected rep, which it would refuse", "an older app sends no grade for the same rep, and it earns nothing"; review round 1's probes against the real `0465943` code above.
- **The bot's depths scale, and stay exact by default:** `bot_opponent_test.dart` "with no pass depth, its reps go exactly 1.4 or 1.9 deep", "its depths scale by the same multiples".

- **Manual check:**
  - W2, on the user's phone, `origin/main` `0465943` (reported 2026-11-01): pass. Right after a sign-up, the three rules pages (skip on pages 1 and 2, 시작하기 on page 3). Killing the app without pressing anything shows the rules again on the next start; after 건너뛰기 or 시작하기 it goes straight home. An existing account's login goes straight home. '?' on home opens the rules with no skip; back and 확인 both return. The danger icon is red.
  - W3 bot battle, same phone and commit (reported 2026-11-01): pass. +N and the bar's move; a rejected rep shows the amber banner with its Korean reason; after 30 s the result shows the scores, valid reps and why it was decided; a deliberately deep rep shows `+15 EXCELLENT`. Excellent did show on this build, which has H2; round 2 had not seen it. Whether H2 or the rep's depth made the difference is unknown, and the team's check of the threshold stays open.
  - Not reported: W3's new home hint's words.
  - Not done at this push: W3b on a phone, including a real Go lower rep showing `+5 AVERAGE`. See the next entry.
  - Not done yet: online on real devices. It needs the battle server rebuilt, or the temporary local patch.

#### 2026-11-01 · code at commit `5c47a3e` · step W3b `feat/average_score`: the Average line moves from 105° to 120°
The user played the release build of `5ddac4f` on a phone: at 105°, Average almost never showed. So the line moves to 120°:
- `BattleRules.averageMaxElbowAngle` is 120. Nothing else in the rule changes.
- The rules page now states the angle, read from `BattleRules`: "팔꿈치 각도가 120° 이하면 Average 점수를 받아요".
- `battle-rules.md` 3.6 has the new evidence, and `docs/iteration-2-protocol.md` the new number.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `5c47a3e`, without coverage. Coverage comes from the PR's CI comment.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | see the CI comment on PR #23 | 11/01 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #23 |
| ViewModel | flutter_test, fakes | 90% | see the CI comment on PR #23 | 11/01 | same |
| Service | flutter_test, MockClient, fakes | 85% | see the CI comment on PR #23 | 11/01 | same |
| View | flutter_test (widget) | 75% | see the CI comment on PR #23 | 11/01 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | not run locally: Django unchanged in this push; see the CI comment on PR #23 | 11/01 | same, `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` 1069 passed, 0 failed, 9 skipped, the same 9 as above. `flutter analyze` found no issues. Server `pytest` was not run locally because this push does not change Django.
- **Coverage:** not collected on this PC. The numbers for this head are in the CI comment on PR #23 and the PR body; they go here at the next push.
- **Replay:** another temporary test, since deleted, printed each rep's reason and angle for the team's head-nod recording `20261027-142000_halfRepHeadNod`. Reps 1, 2 and 5 are Go lower at 127.8°, 137.8° and 145.2°; reps 3 and 4 are `kneesDown` at 112.5° and 129.8°. By the rule, all five earn 0. The `kneesDown` rejection is a known error in `pushup_error_cases_test.dart`: if the 112.5° rep ever closes as Go lower, it earns +5.
- **Shortfalls:** none known; the CI comment decides. The phone recheck at 120° is open (see Manual check).
- **Known issues, not fixed here:**
  - No single angle separates honest reps from cheats: the user's recordings have tired reps at 110–126° and head nods at 109–135°. At 120°, nods at 109–120° earn +5, and tired reps at 121–126° do not. `battle-rules.md` 3.6 says so.
  - Among reps closed as Go lower, Average reads only the angle. Depth is the nose's, so dropping the head can still close an attempt as Go lower, which a shallower nose would leave with no verdict, or as a valid rep.

Test cases added or changed in this step:

| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/game_rules_test.dart` (updated) | The default 120; 120 is average, just above is not; a tuned line of 100 |
| Service | `test/services/game/battle_game_test.dart` (updated) | 90, 110 and 120 earn 5; 120.1, 126, 127.8, 145.2, 169 and 175 earn nothing; example 1's rejected rep at 130 |
| Service | `test/services/game/rep_grade_test.dart` (updated) | 120 is average, 121 is not; the counts with a rep at 130 |
| Service | `test/services/online/online_battle_integration_test.dart` (updated) | An online rep at exactly 120 scores on both phones; a rep at 121 sends no grade and earns nothing |
| ViewModel | `test/viewmodels/battle_viewmodel_test.dart` (updated) | A rep at 130 scores nothing |
| View | `test/screens/battle_screen_test.dart` (updated) | No points on a later rep at 130 |
| View | `test/screens/online_preparation_test.dart` (updated) | The online words at 120, and none at 121 |
| View | `test/widgets/help_rules_test.dart` (updated) | The page's sentence and its angle; `degreesText` for 120 and 120.5 |

Acceptance criteria → tests:
- **Go lower at 120° or less earns +5:** `game_rules_test.dart` "an elbow angle up to 120 degrees is average"; `battle_game_test.dart` group "average"; `online_battle_integration_test.dart` "an average rep shows the same score and bar on both phones, and stays rejected".
- **Above 120° earns 0:** `game_rules_test.dart` "a larger angle is not, nor is no angle"; `online_battle_integration_test.dart` "a shallow rep just above the line, or with straight arms, or another reason, sends no grade and earns nothing".
- **The rules page states the line from the config:** `help_rules_test.dart` "every number on the pages comes from the constants", "an angle shows exactly, and a whole one has no decimals".

- **Manual check:**
  - W3b at 105°, on the user's phone, release build of `5ddac4f`, AI battle (reported 2026-11-01): done. Average almost never showed when the user played, which is why the line moved. The user reported this as an interim result.
  - Not done yet: the recheck at 120° on a real device.
  - Not done yet: online on real devices. It needs the battle server rebuilt.
  - Seen by the user at a very large system text size, not from W3b and not fixed here: the match-found title, the battle screen's name chips and the reject banner's reason are cut, and the pose guide chip sits behind the opponent's card.
  - For the team to discuss, not changed here: Good, the bar for a counted rep, also felt strict to the user. It is the judge's setting.
