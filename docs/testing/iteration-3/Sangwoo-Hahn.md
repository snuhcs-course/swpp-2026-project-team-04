# Testing notes – Iteration 3 – Sangwoo Hahn

Per-push Results for my Iteration 3 steps, in the Testing Documentation format. The PM merges them into
`docs/testing/Testing-Documentation.md`.

## Results

#### 2026-11-01 · S4 online squat battle

- `flutter analyze --no-pub lib test`: no issues.
- `flutter test --no-pub --concurrency=1`: 1,079 passed and 9 skipped.
- Focused Flutter tests for home, lobby, online preparation and matching, profile, app flow, and squat judging: 138 passed.
- Django: `python -m pytest -q --cov=accounts --cov=matches --cov=gymrats --cov-report=term-missing`: 82 passed, 96% total line coverage.
- Local Flutter coverage was not obtained: the concurrent coverage run reported test-process/coverage collection errors and was stopped. See PR CI for the coverage run on the submitted commit.
- The combined app was installed on one Android phone. A complete two-device online squat battle and squat judge accuracy were not verified.

#### 2026-10-28 · code at commit `94956b5` (`origin/main`) · step S1 `docs/squat_judge_design` (P5 squat rep judge design)
This step adds one design document, `docs/iteration-3/squat-judge-design.md`, and one diagram,
`docs/iteration-3/images/squat-setup-and-depth.svg`. It changes no code or tests. `task.md` says "Tests: None (design
doc)", so the checks below only confirm that the branch is still green. I ran the commands on Windows in
`gymrats_app/`, without coverage. Coverage comes from the CI comment "Tests and coverage (GitHub Actions)" on the PR.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | unchanged from `main` (no code change); see the CI comment on the S1 PR | 10/28 | `flutter test`; coverage: CI comment on the PR |
| ViewModel | flutter_test, fakes | 90% | unchanged from `main`; see the CI comment on the S1 PR | 10/28 | (same) |
| Service | flutter_test, MockClient, fakes | 85% | unchanged from `main`; see the CI comment on the S1 PR | 10/28 | (same) |
| View | flutter_test (widget) | 75% | unchanged from `main`; see the CI comment on the S1 PR | 10/28 | (same) |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 10/28 | – |

- **Commands:** `flutter analyze` and `flutter test` in `gymrats_app/`; the team ownership guard `ownership_guard.py --check-diff` (ok: 5 changed files, all owned by S1).
- **Tests:** `flutter test` 675 passed, 0 failed, 1 skipped. The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`. `flutter analyze` found no issues. Server `pytest` was not run because `server/` did not change.
- **Coverage:** not collected locally for this step, since no code changed. The per-layer numbers equal those of `main` at `94956b5` and appear in the PR's CI comment.
- **Shortfalls:** none against the targets in this step.
- **Checks on the design itself:** the reviewer subagent compiled stand-ins for the doc's Dart code (`ExerciseRepJudge`, `judgeFor`, `PushUpJudgeAdapter`, `RejectReason.forExercise`, the `RepCounterViewModel` constructor) with `dart analyze`: no issues. It also recomputed the worked examples in §5.

**Test cases added or changed in this step:** none (design document). `task.md` asked for worked examples instead: §5
of the document has two rep timelines (a valid rep and a rejected half squat). §7 lists the unit tests S2 will add:

| Layer | Planned test (S2) | Covers |
|---|---|---|
| Service | `SquatRepJudge`: §5.1 frames → one valid rep, `maxDepth` 0.94, `descent` 400 ms | valid rep, depth units |
| Service | `SquatRepJudge`: §5.2 frames → `shallowSquat` | half squat rejected |
| Service | `SquatRepJudge`: sit down again after the bottom → `standUpFully`; small dip, < 200 ms, > 12 s, frame gap → no event | other rules |
| Service | `PushUpJudgeAdapter` forwards to `RepJudge`; `passDepth == bottomDepth` | push-up unchanged |
| Service | `judgeFor` returns the judge for each exercise, with the injected clock | interface |
| Service | `SetupChecker` squat parts and `notStanding`; `ExerciseType.values` test updated | setup |
| Model | `RejectReason.forExercise` keeps push-up and squat reasons apart; Korean text for every value | reasons |
| ViewModel | `RepCounterViewModel` defaults to push-up; `exercise: squat` uses the squat judge; `passDepth` follows the judge | wiring |

## 2026-11-02 — S3 SOMA sportswear
- Base: `origin/main` at `5e0be5e`. The profile picker and its tests were included with owner/PM agreement relayed by the user.
- `flutter analyze --no-pub`: passed before the final test-only additions; rerun before PR.
- `flutter test --no-pub test/models/avatar_catalog_test.dart test/screens/profile_screen_test.dart test/services/online/online_battle_integration_test.dart --reporter expanded`: 58 passed on this worktree before adding a profile search regression; profile test separately rerun with 4 passing.
- `node tools/avatar-preview/test-retarget.mjs`: all 28 avatar rigs passed, including SOMA root-joint lookup and directional pose mapping.
- Full `flutter test --coverage` was interrupted after the Flutter coverage service repeatedly disconnected (`getSourceReport: Service has disappeared`); layer coverage is not available from that run. Full non-coverage suite result to be recorded after completion.
- Manual: earlier prototype installed on a Galaxy S22; SOMA fixed push-up starting pose visually checked after root-joint fix. A real two-device SOMA battle and the final main-based PR build have not been manually verified.
- Test map: `avatar_catalog_test.dart` checks assets, IDs and persistence; `profile_screen_test.dart` checks picker, search, restoration, failure and online-session selection; `online_battle_integration_test.dart` checks the matched avatar roster and session flow; `test-retarget.mjs` checks rig mapping.
- Full non-coverage suite (`flutter test --no-pub --concurrency 2 --reporter expanded`): 1,069 passed, 9 skipped, 0 failed. Skipped cases include existing documented push-up recognition errors; inspect the test output for the individual reasons.
- `flutter analyze --no-pub`: clean after the final implementation changes.
- `flutter build apk --debug --target-platform android-arm64 --no-pub`: passed for this main-based worktree.

## 2026-11-02 — S3b opponent avatar view
- Base: `origin/main` at `757a6e2`, after S3 PR #25 and S4 PR #17 merged. This branch preserves the previously uncommitted S3b prototype and adds the fixed push-up renderer and remote-pose depth/knee estimation.
- `flutter analyze --no-pub`: clean.
- `flutter test --no-pub test/services/pose/avatar_pose_payload_test.dart test/widgets/opponent_avatar_panel_test.dart test/widgets/pose_avatar_toggle_view_test.dart --reporter expanded`: 18 passed.
- `node tools/avatar-preview/test-retarget.mjs`: 28 avatars passed. `test-fixed-pushup.mjs`: seven avatar rigs passed. `test-exercise-prior.mjs` and `test-screen-root-motion.mjs` passed.
- Coverage was not measured locally in this run. Independent review and a real two-device manual test of this branch were not performed.
- Cases: pose payload tests cover stable calibration, rejected standing baselines, noisy/missing data and independent knee estimates; panel tests cover opponent-view and exercise propagation; JS tests cover pose mapping, fixed contacts, priors, and screen-root behavior.
- Before the S4 main update, `flutter test --no-pub --concurrency 2 --reporter expanded`: 1,078 passed, 9 skipped, 0 failed. Skips include existing documented push-up judge cases.
- Before the S4 main update, `flutter build apk --debug --target-platform android-arm64 --no-pub`: passed.
- After S4 merged, the selected exercise is forwarded to the opponent avatar; the squat screen regression passed.
- On latest main (`757a6e2`), `flutter analyze --no-pub` and the Android arm64 debug APK build passed. A targeted squat-screen test verifies the exercise forwarded to the opponent panel.
- On latest main, `flutter test --no-pub --concurrency 2 --reporter expanded`: 1,088 passed, 9 skipped, 0 failed. Skips include existing documented push-up recognition errors.

## 2026-11-02 — S4 follow-up: squat demo depth
- For each counted squat, `SquatDemoJudge` reports the largest observed standing-relative hip/knee displacement as `maxDepth`; detection and count thresholds are unchanged.
- `flutter test --no-pub test/services/pose/squat_demo_judge_test.dart test/services/game/battle_game_test.dart test/services/game/rep_grade_test.dart`: 55 passed.
- `flutter analyze --no-pub`: passed. Local layer coverage was not measured; no real-person phone validation has been performed for this scoring change.
- The depth is an estimate using the shin-normalized hip/knee gap, not a verified physical measurement. Follow-up: test real front-camera squat recordings and calibrate scoring if needed.
