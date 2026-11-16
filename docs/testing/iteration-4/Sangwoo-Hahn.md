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

## S1 limited readiness hold change (2026-11-15)

- Base: main `95b6d97`; the default initial top hold is 250 ms rather than 300 ms. A separate minimum preserves the previous 300 ms for clearing a knee latch. This does not relax the per-rep arm lockout or claim that S1 accuracy work is complete.
- `flutter analyze --no-pub`: no issues after `flutter pub get`. Full `flutter test --no-pub --reporter expanded`: 3,104 passed, 10 pre-existing skips. `flutter test --no-pub --coverage --reporter expanded test/services/pose/rep_judge_test.dart`: 85 passed, changed judge file 307/315 executable lines (97.5%); this is scoped file coverage, not full Service-layer coverage.
- Four synthetic 30 Hz tests exercise a full one-second rep, a knee-supported rep, a belly-down rep and a fast incomplete lockout; a separate hidden-hip test reproduced premature knee-latch release before the fix and passes with the release minimum.
- Frozen and historical fixture verdict sequences matched before/after the isolated hold change, with nonempty-data assertions. Frozen in-sample M1 50/63, M2 188/207, M3 124/207 were unchanged. Reducing arm lockout to 171 degrees introduced a frozen false count; an exploratory belly boundary improved frozen rejection but produced historical reason regressions. Neither was applied. Nine known push-up error cases remain skipped; an additional public-server smoke test remains skipped. No real-person or device UAT was run; server unchanged.
- Independent read-only Codex review found the knee-latch regression and approved the limited fix after the regression was corrected; see `docs/iteration-4/pushup-critical-cheats.md` for reproduced experiments and limitations.

## S1 nine-class push-up judge on recorded video (2026-11-16)

- Working tree based on `d866b45` on `fix/pushup_game_speed`. The AI and online push-up counters share the changed Dart judge. The selected classifier refines a partial-rep reason and preserves public event timing, scoring depth units and the invalid/valid contract.
- Recorded evaluation used 1,464 originals, 133,327 source-timed Android ML Kit frames and the revised attempt labels. Seventy-one rule/tree settings were ranked using only development groups and native regression gates. Thirty-six passed all gates. The selected setting was `tree5_small30_elev60_knees_tilt15_guarded`.
- Held out 294 originals / 83 groups / 848 unique labelled attempts. Baseline → selected: macro F1 10.68% → 19.08%, correct class and time 117 → 192, no verdict 568 → 419, extra verdicts 7 → 14. The selected default still miscounted 18/470 invalid attempts as valid (baseline 15/470). None of eight straight-arm attempts produced an event. Three classes have no video positives. No physical-phone UAT was performed in this run. See `docs/iteration-4/pushup-nine-benchmark.md` for all supports and method.
- `benchmark_pushup_nine.py verify` reproduced every event and source frame from the full fitted model in the actual app on all 1,464 originals (2,597 events). Independent native-fixture replay matched all 365 events across 44 recordings. Frozen M1 remained 50/63, M2 188/207 and M3 124/207. The original M1 and M3 performance targets remain unmet. No new false acceptance across the labelled critical phone cases. An ordinary full-depth recording with a hidden return retains its prior treatment.
- `rep_judge_test.dart` covers camera calibration, jointly observed flexion/descent/reopening, missing or one-sided joints, straight arms, stable score thresholds, short-cycle feedback without double counts, camera gaps, and learned reason selection. `phone_tilt_test.dart` and `rep_counter_viewmodel_test.dart` cover the native motion signal. The five offline scorer tests include one-to-one matching, misses, extras, unresolved labels, group separation and fixture regressions.
- Final app verification on the selected implementation passed. Flutter analysis was clean. The complete Flutter suite ran with `flutter test --no-pub --concurrency=4` and reported 3,113 passed and 10 pre-existing skips. Scoped coverage ran separately with 141 passed and 9 pre-existing skips. It covered 446/453 executable judge lines (98.45%) and 119/120 pose metric lines (99.17%). A combined full-suite coverage attempt hit a Flutter VM service teardown error. No whole-layer coverage is reported. The five independent scorer cases passed.
- Independent read-only Codex review approved the implementation after the added camera and occlusion controls. The ARM64 Android debug APK built successfully. This run did not include physical-device UAT or server changes.

## S1 binary recognition from 2D spans and measured phone angle (2026-11-16)

Local S1 tree based on `d866b45`. The same app judge runs in AI and online push-up matches. This run uses the existing Android landmark recordings, with no new physical-device UAT or server changes.

- Full Flutter analysis was clean. `flutter test --no-pub --concurrency=4 --reporter expanded` passed 3,128 tests with 10 pre-existing skips (nine known push-up inputs and the opt-in server smoke test). Four focused pose suites passed 149 tests with nine pre-existing skips. Scoped line coverage was 654/667 (98.05%) for the judge, 312/320 (97.50%) for pose metrics and 33/35 (94.29%) for the adapter, all above the 85% Service target. Whole-layer coverage was not measured. The five time-matching/scorer tests, three binary metric/feature tests and the measured-angle fixture replay passed.
- Regression tests cover fresh, missing and stale gravity samples, tilt band hysteresis, mirrored/rescaled poses, hidden wrists, slow movement, a phone angle changing mid-rep, real bilateral return, one shallow motion closing only once when the head lags the wrists, and a previous complete motion followed by a head bob. Seven synthetic camera probes retained the ordinary full-rep controls and no new critical acceptances. The actual app reproduced the independently fitted primary calibration on 1,170 development streams. Its final verdicts were identical to the previous default across all 44 phone recordings both with and without measured tilt.
- On 848 unique held-out video attempts the app counted 108/378 normal and explicitly rejected 188/470 faulty. The old default counted 106 and explicitly rejected 168. Final primary+span timing missed 391 and produced 16 unmatched verdicts including three points. Classification calibration was selected on development, with the final test opened after selection. The broader proposal finder plus binary MLP counted 299/378 and explicitly rejected 271/470, but assigned 50 unmatched points and newly accepted 70 previously protected critical faults in 36 per-rep-labelled phone recordings. The NN remains available for offline inference.
- The technical report `docs/iteration-4/pushup-span-benchmark.md` covers all methods, source split, angle-specific scores and checks. `C:/SWPP/iter4/pushup-nine-benchmark/span-pitch/method-comparison.csv` contains per-class binary denominators, missed attempts and extra events for each method.
- The independent read-only Codex reviewer approved the corrected implementation after checking duplicate verdicts, evidence borrowed from a previous rep, sensor-motion overrides and split integrity. The ARM64 debug APK built successfully with `flutter build apk --debug --target-platform android-arm64 --no-pub`.

## S1 user-requested binary MLP phone trial (2026-11-16)

- Built this uncommitted S1 tree using `flutter build apk --debug --target-platform android-arm64 --dart-define=PUSHUP_MLP=true --no-pub`. The flag selects the already-trained 466→64→32→1 model and broad causal proposals in both AI and online push-up battles. The previous native critical-fault regression was disclosed before the user requested this specific trial. The known model errors remain documented in `docs/iteration-4/pushup-mlp-device-test.md`.
- All 858 proposals across 294 native ML Kit test streams matched the original model's binary labels and frame timestamps through the actual app judge. All 466 feature values were identical. Maximum probability difference was 7.39e-7. Proposal-only parity also passed on 1,170 development recordings (3,383 proposals) and 44 phone recordings (518 proposals). The embedded source parameters match the NPZ arrays byte-for-byte.
- Flutter analysis was clean. Full `flutter test --no-pub --concurrency=4 --reporter expanded` passed 3,137 tests with the 10 existing skips. Three explicit experimental judge tests also passed with the compile-time flag enabled. Scoped coverage tests passed 129/129. Coverage was judge 742/772 lines (96.11%), pose metrics 431/450 (95.78%), adapter 36/39 (92.31%). These are changed-file values, not whole-layer coverage.
- Installed the APK with `adb install -r` on the connected Samsung SM-S901N (Galaxy S22). Installation returned Success. Android started `com.gymrats.gymrats_app/.MainActivity` with Status ok, and the app process remained running without a matching fatal or unhandled-error log. The installed APK and local APK SHA-256 both equal `5a6944053709edf1c33c30c6e8805b4702c2eb01ae826d8f00a3cd41efe4c828`.
- The phone was locked during verification, so visual screen operation and live exercise UAT were not completed. The app install and startup were verified. No server operation was part of this trial.
- Independent read-only Codex review approved the experimental implementation after checking the model bytes, all held-out event outputs, state handling, live movement veto, source ownership and final verification notes.
- 2026-11-16 unlocked-device follow-up. The user unlocked the Galaxy S22. Opened the visible GymRats home, selected AI 1v1 push-up using the displayed middle difficulty, completed the existing pre-game information flow, and reached pose setup. Camera preview, guide outline, timer and phone-placement prompt rendered correctly. Captured the actual process log `GymRats push-up judge: binary MLP 64/32, wide proposals.` The app is left at pose setup. No human repetitions or completed match were tested.

## 2026-11-16 knee-support specialist study

The user requested improved knee rejection with maximum preservation of normal push-ups after trying the binary-MLP phone build. Research based on local HEAD d866b45 compared 42 geometric configurations, 12 web specialists, 396 joint threshold choices and 19 native-assisted classifiers. The selected 466-to-32-to-16-to-1 knee MLP uses threshold 0.9204565286636353 and only vetoes existing accepted proposals.

Reused web test normal recall stays 299/378. Knee rejection rises from 74/105 to 76/105. Device-group model-selection cross-validation retains 49 previously accepted normal events in pure-posture recordings and reduces raw knee false accepted events from 65 to 37. These are weak whole-recording posture labels and threshold-selection estimates. Training-set native resubstitution, documented separately, is not a generalization score. See docs/iteration-4/pushup-knee-specialist.md for all denominators, extra events and remaining errors.

| Behavior | Verification | Result |
|---|---|---|
| The operating point respects both domains' normal-loss budgets | test_operating_point_enforces_each_domain_normal_budget | Passed |
| Boundary equality retains a normal decision | test_threshold_respects_normal_loss_and_strict_boundary | Passed |
| Knee veto removes acceptances without promoting rejected events | test_veto_counts_only_new_rejections_and_never_promotes_invalid | Passed |
| Portable inference matches fitting implementation | logistic, MLP and tree export tests | Passed |
| Full held-out source replay reproduces reported scores | 294 source streams, 858 proposals | Exact match |

Command `python -m unittest discover -s tools/diagnose -p 'test_*.py' -v` passed all 13 tests, including five new tests. Selected export parity is exact on all 4,449 web/native cached windows. Independent read-only Codex review approved the research scripts and checked the reported counts. Flutter/server checks and MVVM coverage were not rerun for this research-only implementation. Physical-workout validation of the new specialist is unmeasured. All model data and reports are local under C:/SWPP/iter4/pushup-nine-benchmark/knee-focus.

## 2026-11-16 knee specialist app integration and installation

Local implementation on fix/pushup_game_speed at base d866b45. The user authorized applying the selected model and installing it on the connected phone. Added shared-window knee veto to the actual MLP judge path and the existing Korean kneesDown reason. Both models retain their exported parameter precision.

| Check | Result |
|---|---|
| Flutter analyze --no-pub | Clean |
| Full flutter test --no-pub | 3,141 passed, 10 existing skips |
| Sequential scoped coverage tests | 133 passed |
| Pose metrics changed-file coverage | 456/474, 96.20%, above 85% Service target |
| Rep judge changed-file coverage | 744/774, 96.12%, above 85% Service target |
| Adapter changed-file coverage | 36/39, 92.31%, above 85% Service target |
| Parameter payload | All 69,412 bytes match selected NPZ |
| Numerical replay | Zero decisions differ on 4,449 cached windows |
| Actual app replay | 858 web plus 456 labelled native events match Python timestamps and binary/knee decisions |
| Independent read-only review | APPROVE |
| Android build and install | ARM64 debug, PUSHUP_MLP=true, install -r succeeded |
| Device startup | Galaxy S22, AI push-up camera pose setup visible, knee classifier activation logged |

Initial concurrent coverage collection failed with getSourceReport Service has disappeared after test execution. Retried with --concurrency=1 and obtained the successful scoped coverage above. New tests cover exact knee network output, single-window boundary advancement, veto of five previously accepted recorded knee events, and preservation of four recorded normal acceptances. Existing missing-pose, abandon and index-reset tests passed. The native examples include training data; no new-person or physical-workout accuracy claim is made.

Evidence root C:/SWPP/iter4/pushup-nine-benchmark/knee-device. APK installed at 13:28:49, SHA-256 e847a7e7a2a33340a30b0d5b75b74625ff74eb7d7953d16b52d17adbe7139ecd matches installed base.apk. Full-layer coverage was not remeasured; figures above concern the three changed services.

## S1 live knee-contact diagnostic, 2026-11-16

The user reported worse physical-phone behavior after the knee-specialist trial and requested a screen that shows current knee contact. The diagnostic is selected through `lib/demo/rep_judge_demo.dart` with `KNEE_CONTACT_DEMO=true` on the current uncommitted `d866b45` worktree.

The initial wrist-to-ankle geometric classifier produced false contact labels and no lifted labels on four existing frontal phone recordings. The delivered diagnostic therefore compares live normalized 2D hip, knee and ankle positions with two postures labelled by the user. Each capture starts after three seconds and requires a stable, visible sample window. Similar references, occlusion, stale frames and unfamiliar poses produce an unknown state. Camera changes and sustained phone-angle changes clear the references. This is an image-based estimate. Physical knee-floor contact accuracy has not been established.

### Verification

- `flutter analyze --no-pub` passed with no issues after correcting three new brace-style lint findings.
- Final sequential coverage run passed 206 tests with 9 existing known-error recording skips. Files were `pose_metrics_test.dart`, `rep_judge_test.dart`, `push_up_judge_adapter_test.dart`, `pushup_error_cases_test.dart` and `rep_judge_demo_test.dart`.
- The 15 new diagnostic service tests cover reference capture, stability, missing joints, ambiguous and unfamiliar poses, independent sides, coordinate scaling and tracking/reference resets. The 11 new widget tests cover camera startup, calibration controls and failure, current states, stale frames, permissions, retry, lifecycle, phone movement and compact layout.
- Changed service file coverage was 627/636 executable lines, 98.58 percent. The newly added contact-service region covered 162/162 lines. The demo file covered 927/991 lines, with 232/239 lines in its new diagnostic region. Demo entry points are excluded from the repository layer targets. Whole-layer and full-suite coverage were not rerun for this diagnostic task.
- Independent read-only Codex review returned APPROVE. Ownership `--check-diff` and whitespace checks passed. The index remained empty.
- `flutter build apk --debug --target-platform android-arm64 -t lib/demo/rep_judge_demo.dart --dart-define=KNEE_CONTACT_DEMO=true --no-pub` succeeded.
- Installed with `adb install -r` on SM-S901N and launched `com.gymrats.gymrats_app/.MainActivity`. The camera, unknown-state panel, two reference buttons and per-knee metric panels were visually verified. Filtered process logs showed no fatal exception, unhandled exception, missing plugin or overflow message.
- Installed and local APK SHA-256 both matched `feb46706c3c5bbba0c9aaca57d0002b8ea9864298dfb746c41e6cbd2853d954f`. USB disconnected after the hash was read, during the optional package timestamp query. Installation and visible launch had already succeeded.
- Device screenshot and final test log are stored locally under `C:/SWPP/iter4/pushup-nine-benchmark/knee-device/` as `contact-screen.png` and `contact-tests-final.log`. Live user reference capture and physical movement accuracy remain unverified. Changes remain local and uncommitted.

### Knee diagnostic waiting-state follow-up, 2026-11-16

The user reported that the screen stayed on the generic waiting label. The connected-device screenshot at inspection showed the ceiling, no detected person and two unsaved references. That snapshot does not establish what happened during the user's earlier exercise attempt. The UI had combined missing calibration, occluded joints and ambiguous comparisons into one generic message.

Added explicit per-side reasons and missing-joint lists, distinct top-level messages, and detailed reference-capture failure messages. Insufficient shoulder separation also has a separate framing hint. This follow-up changes explanations and preserves the classification thresholds and calibration acceptance criteria.

- Full Flutter analysis passed. Final five-file scoped suite passed 211 tests with 9 existing known-error recording skips. This includes 44 metric tests and 14 diagnostic widget tests.
- Changed service-file line coverage was 643/652, 98.62 percent. Demo-file coverage was 959/1023, 93.74 percent; demo entry points remain excluded from layer targets. Whole-layer/full-suite coverage was not measured in this follow-up.
- New tests exercise missing-reference and missing-joint explanations, concrete missing knee/ankle names, indistinguishable reference-capture failures, and insufficient shoulder separation. Existing contact-transition, stale-data and lifecycle assertions remain covered.
- Independent read-only review returned APPROVE. Ownership and whitespace checks passed, and the Git index remained empty.
- Rebuilt the ARM64 debug diagnostic entry and installed with `adb install -r`. Launched on SM-S901N and visually verified the absent-person message and per-side missing-joint lists without overflow. Process logs contained no fatal, unhandled, missing-plugin or overflow match.
- Local and installed APK SHA-256 matched `6bf4c20f338690fa1142ba2dcdc78f33676ff37842c737b805a312736aafbf0d`. Screenshot is `C:/SWPP/iter4/pushup-nine-benchmark/knee-device/contact-reasons-screen.png`, test log `contact-reasons-tests.log` in that same local directory. The user's original workout failure stage and physical contact accuracy remain unverified. Changes are local and uncommitted.

### Similar-reference calibration follow-up, 2026-11-16

The user clarified that the touching reference failed to save because it was too similar to the lifted reference. The earlier ceiling screenshot only described the inspection moment. The previous gate required both sides to exceed an absolute separation and a whole-vector noise margin, so small repeatable frontal knee changes could fail capture.

Stable, sufficiently observed references now save even when similar. Each side compares displacement along the reference-difference direction against noise measured in that direction. The prototype deadband is the greater of 0.02 shoulder-width units and twice the larger projected standard deviation. Identical or overlapping references remain ambiguous and show a weak-signal explanation. Existing missing-joint, unfamiliar-pose, stability, lifecycle and camera-reset checks remain covered.

- Full Flutter analysis passed. The sequential five-file coverage run passed 216 tests with 9 existing known-error recording skips. This includes 48 metric tests and 15 focused diagnostic widget tests.
- Regression cases cover identical references saving, a small knee-only difference, unrelated joint jitter, noisy reference overlap, and useful classification on one side when the other side is ambiguous. A widget test captures a six-pixel knee difference and exercises both live states.
- Changed-file line coverage was 664/673 for pose_metrics.dart, 98.66 percent, and 959/1025 for rep_judge_demo.dart, 93.56 percent. The demo entry point remains excluded from layer targets. Whole-layer and full-suite coverage were not measured. An accidental invocation of the all-files coverage runner was terminated and contributes no reported result.
- Independent read-only Codex review returned APPROVE. Ownership and whitespace checks passed. The index remains empty.
- The ARM64 debug diagnostic build succeeded and was installed with adb install -r on SM-S901N. MainActivity, camera preview, status and capture controls were visually verified. Filtered app-process logs had no fatal, unhandled, missing-plugin or overflow match.
- Installed and local APK SHA-256 matched `76a949c137bf18a02df89210dcacb3ecb7eef056c9c1ac3f5dc0281c66d8c1c8`. Evidence files are contact-close-reference-tests.log, contact-close-reference-analyze.log, contact-close-reference-build.log and contact-close-reference-screen.png under C:/SWPP/iter4/pushup-nine-benchmark/knee-device/.
- The app still uses ML Kit Accurate. This change addresses reference capture and comparison. The sensitivity constants and physical knee-contact accuracy require real-person validation. All changes remain local and uncommitted.


### S1 PR integration and lockout regression, 2026-11-16

- Merged current main into an isolated snapshot of the S1 branch, preserving both histories of the three personal course notes. The separate research worktree remained in use by the other chat.
- Independent read-only review found that the span calibration could promote an incomplete 168.42-degree lockout. Codex added a reproducing regression and required the configured lockout for promotion; subsequent review confirmed that case is fixed. Synthetic threshold and custom-config cases were also added.
- Flutter analyzer passed and the full suite passed 3,306 tests with 10 existing skips. A scoped coverage run failed because the Dart VM service disappeared during collection; no coverage number is claimed for this final run.
- Existing 32-video frozen replay: 50/63, 188/207 and 124/207 by the documented three measurements. A separate weakly-labelled 848-attempt holdout after the fix detected 106/378 normal attempts and rejected 189/470 invalid attempts, accepting 18/470 invalid attempts; 16 additional events occurred, 3 accepted. Labels are automated review proposals, not independently adjudicated truth. Forty-four old phone sequences were unchanged by the lockout fix.
- No fresh real-person UAT was performed. The opt-in MLP and knee-contact experiments are not established as accurate; a previously reported phone trial worsened. A custom-injected phone tilt monitor is not propagated to the adapter, although normal production uses the same singleton.

### Mobile pose comparison and opt-in knee forest, 2026-11-16

The user stopped Sapiens2-5B analysis and prioritized low-latency phone models. The comparison processed 13,187 frames from 1,050 videos and 2,706 canonical normal/knee intervals. Labels come from earlier Codex nine-frame chronological visual review and have no independent human verification. Development and reused holdout groups are separated. The experiment supplies interval boundaries and five phase times.

ML Kit Accurate was strongest on the two-class reused holdout with 359/378 normal intervals accepted and 97/105 knee intervals rejected. ML Kit Base scored 346/378 and 91/105, RTMPose-s scored 361/378 and 88/105, and RTMPose-m scored 364/378 and 93/105. ML Kit inference ran on the connected SM-S901N. Full RTMPose inference ran on CPU with the same mobile weights, with 434-frame phone parity and 87/87 identical interval decisions verified separately. All four selected depth-four random forests through the same development-only grid. The detailed report is docs/iteration-4/pushup-mobile-pose-comparison.md.

The user then requested app installation. An opt-in PUSHUP_KNEE_FOREST build connects the selected forest to the existing general binary-MLP proposal path. The forest replaces the previous knee-specific veto. It samples the detected attempt at 10/30/50/70/90 percent using raw upright pose coordinates, preserves microsecond attempt boundaries, and holds at most six seconds or 360 frames. Unavailable intervals produce an unknown knee result. Reset, abandonment, long frame gaps and image-dimension changes clear relevant history.

Recorded-phone replay exposed a material generalization problem. On 32 recordings containing 22,217 frames, normal recognition fell from 60/63 to 55/63, and incorrect repetitions left uncounted fell from 134/207 to 120/207. Across eight knee-related recordings raw accepted events rose from zero to 39. Every recording identifies the Accurate model. Counts, indexes and event timestamps were unchanged in all 32 recordings. A final replay after the timestamp fix reproduced these results. The user was informed and asked to choose the existing judge or the new comparison build before installation.

Verification at local HEAD d866b45 with uncommitted changes

- Comparison helper passed 13 tests and the preparation/inference helper passed five tests.
- Exported Dart features matched Python exactly on all 2,706 intervals. Every decision matched, with maximum probability error 4.44e-16.
- Flutter analyze --no-pub passed after the final timestamp correction.
- Flutter test --no-pub --coverage --concurrency=1 on pose_metrics_test.dart, rep_judge_test.dart, push_up_judge_adapter_test.dart and pushup_error_cases_test.dart passed 193 tests with nine existing known-error recording skips.
- Changed service coverage was 813/823 lines for pose metrics, 776/797 for RepJudge, and 36/40 for its adapter. Each exceeds the existing 85 percent service target. Full-project layer coverage and the full suite remain outside this scoped run.
- New regressions cover exact phase sampling, unavailable/truncated history, reset and dimension changes, duplicate/backward timestamps, insufficient frame coverage, Python-exported normal/knee examples, missing phase imputation, invalid feature inputs, proposal indexes and fractional-millisecond onset preservation.
- Independent read-only Codex review approved the benchmark and opt-in implementation correctness. The reviewer also confirmed that native replay fails to establish an accuracy improvement.
- A main-entry ARM64 debug build succeeded. A refreshed build follows the final timestamp fix. Installation is pending the user's version choice.

All experiment files and logs are under C:/SWPP/iter4/mobile-pose-benchmark. Git publication was not requested for this work.

The user explicitly selected the new knee-classifier comparison build after receiving the native-regression figures. The final selected build uses lib/main.dart and PUSHUP_KNEE_FOREST=true. The previous parallel build attempt was stopped, and the selected build is being repeated sequentially before installation.


### Selected comparison build installed

After reviewing the recorded-phone regression, the user explicitly chose the new knee-classifier comparison build. A fresh sequential build of lib/main.dart with PUSHUP_KNEE_FOREST=true succeeded and was installed with adb install -r on SM-S901N. The app launched successfully, the signed-in home screen was observed, and the AI push-up matching flow opened. The local APK and installed base.apk both have SHA256 ad65a33899b7727bcc1f5efc4af40a4f62dfac68eb46bbcc213bc0eb8f6a59c0.

The USB connection ended after installation, launch, and hash verification, during the follow-up pose-setup screenshot. Live exercise performance and the runtime activation log were therefore not captured. The selected build flag and its constructor activation are verified by the build command and focused tests. The artifact is C:/SWPP/iter4/mobile-pose-benchmark/gymrats-knee-forest-trial.apk. Source changes remain local and uncommitted.
