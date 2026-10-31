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
| Model | flutter_test | 90% | see the CI comment on the W2 PR | 10/31 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on the W2 PR |
| ViewModel | flutter_test, fakes | 90% | see the CI comment on the W2 PR | 10/31 | same |
| Service | flutter_test, MockClient, fakes | 85% | see the CI comment on the W2 PR | 10/31 | same |
| View | flutter_test (widget) | 75% | see the CI comment on the W2 PR | 10/31 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | not run locally: `server/` unchanged; see the CI comment on the W2 PR | 10/31 | same, `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` 770 passed, 0 failed, 1 skipped.
  - The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`.
  - The nine test files in the table below alone: 101 passed.
  - `flutter analyze` found no issues.
  - Server `pytest` was not run locally because `server/` did not change.
- **Coverage:** not collected on this PC, because `flutter test --coverage` hangs with "getSourceReport: Service has disappeared". The numbers come from the CI comment on the W2 PR. Until the next W2 push, they are in that comment and in the PR body, not here.
- **Mutation check of the '?' (review round 4):** the reviewer ran 19 mutations against six of these test files in a scratch copy, and 17 failed a test. They included a wrong route, a target shrunk below 48×48, a removed button, a removed `Expanded`, and a removed or first-login `/help` route. The two survivors made the `/help` route write the flag when it opens. The two `auth_flow_test.dart` tests with "saves nothing" in their names were added for them. I reran both mutations in the working tree: `auth_flow_test.dart` then fails exactly those two tests. The mutations were reverted, and `main.dart` is unchanged.
- **Flaky test outside this step:** `test/services/online/battle_result_store_test.dart` "a forfeit is stored as a loss for the player who left" failed once in a full run in review on 2026-10-27 (expected `['win','loss']`, got `['loss','win']`), and passed alone 3 of 3. The full runs recorded since then passed. It is not a W2 file. W3's PR (#20, commit `d0ed8aa`) makes the players join in a fixed order in `playing`, the helper this test uses. That is the likely cause, not a proven one, and until W3 merges the test can still fail now and then on this branch.
- **Shortfalls:** none known; the CI comment decides. The phone check is still open (see Manual check).
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
