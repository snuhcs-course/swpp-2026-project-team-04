# Testing — Iteration 4: S3 push-up silhouette draft

## Issue #47: replay the stored match mode (2026-11-15)
- Based on `origin/main` f652bc1. `flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 3,002 passed, 10 existing skips, 0 failed. The home ViewModel and home screen suites passed 97 tests. Individually collecting coverage for `test/viewmodels/home_viewmodel_test.dart` passed 24 tests and covered 55/55 executable lines (100%) of `home_viewmodel.dart`; this is a scoped file result, not full ViewModel-layer coverage.
- Cases: an online opponent named `RepBot` or an AI difficulty name remains online; stored bot mode and named levels are retained; unknown bot names fall back to the legacy expert level; records without a mode preserve the former name-based behavior. An independent read-only Codex reviewer approved the change. The currently deployed server was not checked, so a server or older record lacking `is_online` retains the legacy ambiguity.
- The user confirmed owner/PM agreement and a narrowly scoped separate branch. Server files did not change and server tests were not run.

## Scope
Push-up setup framing overlay, portrait/landscape setup layout, and matching-screen controls. Camera, detector and network are faked in widget tests. Online setup, squat silhouettes, distance/angle guidance and alignment validation are not implemented by this draft.

## Results
- 2026-11-12: integration checkout based on `origin/main` 6e87a0f with the same feature changes: `flutter test --no-pub test/widgets/pose_silhouette_guide_test.dart test/screens/setup_screen_test.dart test/screens/match_setup_screen_test.dart` — 34 passed, 0 failed. Tests run before the final merge; rerun results for the merged branch are recorded in the PR.
- Android debug ARM64 build installed on the connected phone. A reference pose was observed before the final outline revisions; alignment of the final outline has not been verified on a real person.
- Independent review: `BoxFit.cover` can crop the preview while the setup checker analyzes the full frame, allowing hidden landmarks to count. Needs a follow-up fix and real-device verification.
- On merged branch base 7e3dbcf, `flutter analyze` passed; `flutter test --no-pub` passed 1,557 tests with 10 skipped; targeted tests passed 34. `flutter test --coverage` and the targeted coverage run failed to complete because the VM service disappeared during coverage collection. Coverage by layer is therefore not measured. Server tests were not run because the server did not change.

## S3 follow-up: silhouette alignment and countdown (2026-11-13)
- Base: `origin/main` 1ed57ca. Targeted tests: `flutter test --no-pub --coverage test/models/setup_silhouette_alignment_test.dart test/viewmodels/setup_viewmodel_test.dart test/screens/setup_screen_test.dart test/screens/match_setup_screen_test.dart test/widgets/pose_silhouette_guide_test.dart` — 74 passed, 0 failed. Camera and detector were faked.
- Targeted line coverage after the diagnostic fix: alignment model 100%, SetupViewModel 94.4%, SetupScreen 93.4%. Full-suite and full-layer coverage were not measured for this follow-up. Server unchanged; server tests not run.
- An ARM64 release build of the pre-integration revision was installed on the connected Samsung SM-S901N; the user reported completing their test. Detailed results were not specified. The latest-main integration has not been installed or retested on-device.
- The guide alignment thresholds are initial heuristics and need calibration across devices, body shapes and poses. Online setup follows a separate path and is not changed. An independent reviewer was not available in this session.

- Subsequent regression run: the five setup suites plus both diagnostic demo suites passed 94 tests after preserving diagnostic manual-start behavior. Full app suite: 2,119 passed, 10 skipped, 0 failed. Full `flutter analyze --no-pub`: no issues.

## S3 follow-up: squat silhouette in setup and battles (2026-11-15)
- Base: `origin/main` 8c8757a. `flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 2,853 passed, 10 existing skips, 0 failed. Nine skipped recorded-pose cases document known push-up classification limitations; the public WebSocket smoke test is disabled unless explicitly enabled. See test source for individual reasons. No server files changed, so server tests were not run.
- Relevant tests: `flutter test --no-pub` with the eight changed setup/battle model, widget, ViewModel and screen suites plus `test/design_tokens_test.dart`: 289 passed, 0 failed. These use fake cameras, pose detectors and online sessions. They cover contained-image projection, mirrored poses, missing landmarks, valid and invalid holds, dropped frames, reconnects, AI and online readiness, UI guide states and existing push-up paths.
- Whole-suite `flutter test --coverage` failed to collect coverage because the VM service disappeared; a combined scoped coverage run encountered the same issue. Eight scoped test files were then run one at a time with `--coverage`: all 244 tests passed and their LCOV data was merged by line. Changed-file line coverage: squat alignment model 100% (44/44); squat guide widget 100% (82/82); BattleCameraView 97.2% (105/108); SetupViewModel 95.2% (177/186); BattleViewModel 98.8% (317/321); SetupScreen 97.7% (256/262); BattleScreen 93.7% (164/175); OnlineBattleScreen 98.1% (316/322). These are scoped, not whole-layer coverage; team-wide layer targets were not measured.
- Independent read-only Codex review: APPROVE after fixes to stale bot frames, online reconnect freshness and theme tokens. The setup landmark regions remain provisional. No physical-person pose calibration, online two-device session, or real-device auto-start test was performed for this PR; hands are illustrated but not checked for clasping.

## S3 follow-up: merge current main into squat silhouette PR (2026-11-15)
- Merged `origin/main` f652bc1 into PR #65 and resolved the `AppColors` conflict by retaining both `chartBar` from main and `squatGuideReady` from the PR. The resulting diff against main adds only the squat token to this theme file.
- `flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 3,014 passed, 10 skipped, 0 failed. The existing skips comprise the public-server smoke test and nine known push-up pose cases. Tests ran on the resolved merge tree before its merge commit; subsequent edits are documentation only.
- Earlier physical-device and two-person online verification limitations still apply. Full layer coverage was not remeasured locally for this merge.

## S4 / issue #59 — depth reports and shared AI/online squat judge (2026-11-14)

Base: main `eb336c3`; verified working-tree implementation on `fix/squat_judge_accuracy`, prepared for the user's authorized commit/push. Source and tests have not changed since the runs below. No server changes. Test inputs are synthetic landmarks, with fake camera/detector/phone/network/storage dependencies.

### Results
- Initial regression run: 8 passed, 2 failed, reproducing missing demo depth and missing shared-judge guide coordinates. After snapshot fixes, service tests passed 17/17. The bot-wiring regressions then reproduced zero shallow rejections and the demo phone-movement bypass before the bot factory was changed.
- `flutter analyze --no-pub`: no issues (also independently rerun by the read-only reviewer after the factory change).
- `flutter test --no-pub --coverage test/services/pose/squat_demo_judge_test.dart test/services/pose/squat_report_depth_test.dart test/services/pose/squat_rep_judge_test.dart test/services/pose/squat_bot_counter_test.dart test/viewmodels/battle_viewmodel_test.dart test/viewmodels/rep_counter_viewmodel_test.dart --reporter expanded`: **92 passed, 0 failed, 0 skipped**.
- `flutter test --no-pub --reporter expanded`: **2,734 passed, 0 failed, 10 skipped** (existing skips; no skip added or changed).
- Full `flutter test --no-pub --coverage --reporter expanded` stalled after 181 reported passes with no active tester process and was interrupted. Full-project coverage is not claimed. The completed six-suite coverage report below is preserved.
- An earlier service coverage command mistakenly included the nonexistent `squat_error_cases_test.dart`; reran using the three actual service test files, 17 passed. It did not expose a product failure.
- Server tests not run: server unchanged. Physical-phone UAT not run; real-camera squat accuracy remains unverified.
- Independent read-only Codex review: APPROVE for this implementation, no actionable defects; it independently ran analysis and the 92-test selection. Broader S4 accuracy and physical UAT were outside this approval.

### Scoped changed-file coverage vs target
These are line counts from the completed six-suite run, not whole-project per-layer coverage.

| Layer / changed file | Covered / executable | Actual | Target | Met |
|---|---:|---:|---:|---|
| Service: squat_demo_judge.dart | 72 / 72 | 100% | 85% | yes |
| Service: squat_rep_judge.dart | 102 / 105 | 97.1% | 85% | yes |
| ViewModel: battle_viewmodel.dart | 269 / 274 | 98.2% | 90% | yes |

Unchanged Model/View and server layers were not separately measured for this fix. Existing service gaps include the real stopwatch and attempt-timeout paths.

### Test cases and acceptance mapping
| Layer | Test file | Behavior |
|---|---|---|
| Service | test/services/pose/squat_demo_judge_test.dart (updated) | Current frame depth differs from rep peak; depth unavailable before calibration, on missing frames and after abandon/reset; existing prototype counting retained |
| Service | test/services/pose/squat_report_depth_test.dart (new) | Calibrated zero, ascent/descent depth, hip/knee guide coordinates from usable sides, one visible leg, unavailable frame and reset/abandon |
| App-flow-style counter / report | test/services/pose/squat_bot_counter_test.dart (new) | Actual AI and online factories: four full plus two shallow squats, equal events/samples, JSON round trip, analyzer shallow finding; AI phoneMoved rejection |
| ViewModel | test/viewmodels/battle_viewmodel_test.dart (updated) | Production bot setup and shared threshold; changed old demo-only moved-phone expectation to a rejected rep, at realistic camera cadence |

- Issue #59 (time-depth graph data) → `each tracked frame reports its current depth, not the rep peak`, `squat snapshots expose current depth and visible hip/knee guides`, `AI and online squats produce four valid and two shallow reps with depth samples`.
- UAT-4-style counting/reporting → the same 4-full/2-shallow synthetic counter test; **not a physical UAT result**.
- Shared phone rule → `the AI squat counter applies the online phone-movement rejection`, `a squat bot battle uses the shared judge and rejects a moved phone`.
- The pre-existing shallow, incomplete-standing, tracking-loss and smoothing tests in `squat_rep_judge_test.dart` remain passing. No claim that the full S4 real-world accuracy work is complete.

### S4 #59 current-main integration (2026-11-15)
- Merged current `origin/main` f652bc1 into the existing `fix/squat_judge_accuracy` branch (merge 38b2e06). `flutter analyze --no-pub` found no issues; `flutter test --no-pub` passed 3,003 tests with 10 pre-existing skips and zero failures. Tests ran on the merge tree before the merge commit; later changes are documentation only.
- An independent read-only Codex reviewer approved the #59 implementation against this main baseline. The same reviewer identified conflicts if the pending S3 squat silhouette PR #65 enters main: preserve both sides of the personal course notes and `battle_viewmodel_test.dart`, merge main again and rerun affected checks after #65 merges. Previous physical-person and real-camera accuracy limitations still apply.

### S4 #59 integration after #65 (2026-11-15)
- Merged main `95b6d97` into PR #66. Both personal-note histories were retained; the battle test now supplies continuously fresh setup frames before checking the shared squat judge's `phoneMoved` rejection.
- `flutter analyze --no-pub`: no issues. Four scoped battle/squat suites: 67 passed. Full `flutter test --no-pub --reporter expanded`: 3,102 passed, 10 pre-existing skips, 0 failed. No full-layer coverage was remeasured for this merge. No server changes.
- Independent read-only Codex review approved the merge resolution. Physical-device and real-person UAT remain unverified.

## S3 UAT phone-angle display (2026-11-16)

- Base: main `52fb957`. The angle chip is compiled in only with `--dart-define=UAT_PHONE_ANGLE=true`. It uses the shared gravity monitor and shows degrees from flat; it reports measuring when no fresh usable sample is available.
- `flutter analyze --no-pub`: no issues. Full ordinary-build `flutter test --no-pub --reporter expanded`: 3,225 passed, 10 existing skips. The 54-test setup/camera/widget suite passed both without and with the UAT define, including the UAT lifecycle/shared-subscription test.
- `flutter test --no-pub --dart-define=UAT_PHONE_ANGLE=true --coverage test/widgets/pose_silhouette_phone_angle_test.dart`: 4 passed; angle widget 54/56 lines (96.4%). This is scoped widget coverage, not total View-layer coverage. Tests use fake sensors/cameras and check 60 and 30/45 degree readings, invalid/stale samples, lifecycle, shared monitor retention, both exercises and control overlap.
- Independent read-only Codex review found setup-control overlap in an initial layout; moving the label and adding geometry checks fixed it. The reviewer approved the corrected scope and separately verified real battle-screen widget geometry and shared-monitor lifecycle. No physical-phone UAT was performed; no device was connected. Server unchanged; server tests were not run.
- UAT release build: `flutter build apk --release --dart-define=UAT_PHONE_ANGLE=true` succeeded on 2026-11-16 and produced `build/app/outputs/flutter-apk/app-release.apk` (115.2 MB). It was not installed or tested on a physical device.
