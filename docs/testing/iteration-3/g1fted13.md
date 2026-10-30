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
| Model | flutter_test | 90% | see the CI comment on PR #15 | 10/30 | CI comment "Tests and coverage (GitHub Actions)" on PR #15 |
| ViewModel | flutter_test, fakes | 90% | see the CI comment on PR #15 | 10/30 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | see the CI comment on PR #15 | 10/30 | same CI comment |
| View | flutter_test (widget) | 75% | see the CI comment on PR #15 | 10/30 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | see the CI comment on PR #15; `server/` unchanged | 10/30 | same CI comment |

- **Tests:** `flutter test` 714 passed, 0 failed, 1 skipped.
  - The 16 more than the last entry are `test/ai_eval/` from PR #16 on `main`; this push adds no tests.
  - The skipped test is `test/services/online/public_wss_smoke_test.dart`, as before.
  - The four W4 test files alone: 55 passed.
  - `flutter analyze` found no issues.
- **Coverage:** the last posted numbers are for `4cc0218` ([run 40803648440](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/40803648440)): Model 98.1%, ViewModel 94.4%, Service 92.0%, View 91.0%, server 96%, all above target and the same as in the entry above. This push's only W4 changes are the PNGs and one label string; it also brings in `test/ai_eval/` from #16. The CI comment on PR #15 updates for the new head.
- **Shortfalls:** none known.
- **Test cases added or changed in this step:** none. `safe_warning_dialog_test.dart` still checks the PNG sizes (240×150, 480×300, 720×450), and the tests read the label from `SafeWarningDialog.pictureLabel`.
- **Manual check (the user's phone, 2026-10-29, on the earlier picture):**
  - Bot match found: the warning shows.
  - Back on the warning: the leave question appears.
  - Online match: not checked yet.
  - The new picture has not been checked on a phone yet.
