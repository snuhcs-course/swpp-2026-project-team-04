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

The USB connection ended after installation, launch, and hash verification, during the follow-up pose-setup screenshot. Live exercise performance and the runtime activation log were therefore not captured. The selected build flag and its constructor activation are verified by the build command and focused tests. The artifact is C:/SWPP/iter4/mobile-pose-benchmark/gymrats-knee-forest-trial.apk. The installation preceded the PR integration commits.

### S1 post-merge verification for PR #69, 2026-11-16

Implementation commit 89403cb and merge c940d09 integrate the five-phase knee forest with remote S1 correction 327a9ff and main fe1aad1. An independent read-only Codex reviewer verified the resolved default counter and forest implementation with no actionable findings. The default counter retains its configured lockout guard. The optional model path retains its model-based validity rule. The known native-recording regression remains documented above.

Commands run from `gymrats_app` on c940d09

```powershell
flutter analyze --no-pub
flutter test --no-pub --coverage --concurrency=1 test/services/pose/pose_metrics_test.dart test/services/pose/rep_judge_test.dart test/services/pose/push_up_judge_adapter_test.dart test/services/pose/pushup_error_cases_test.dart
```

Analysis passed. The four-file coverage run passed 194 tests with nine existing known-error recording skips.

| Changed service | Covered lines | Coverage | Target |
| --- | ---: | ---: | ---: |
| pose_metrics.dart | 813/823 | 98.78% | 85% |
| rep_judge.dart | 779/800 | 97.38% | 85% |
| push_up_judge_adapter.dart | 36/40 | 90.00% | 85% |

| Test file | Verified behavior |
| --- | --- |
| pose_metrics_test.dart | Exact five-phase history, missing data, reset, dimension changes, exported forest examples and feature validation |
| rep_judge_test.dart | Optional forest activation, event sequencing, fractional timestamps and configured lockout regression |
| push_up_judge_adapter_test.dart | Existing judge-adapter behavior and phone-angle forwarding |
| pushup_error_cases_test.dart | Existing recorded and synthetic error-case expectations |

These are changed-service coverage measurements. Full-project layer coverage requires the separate CI coverage run. The logs are local files under C:/SWPP/iter4/mobile-pose-benchmark. Physical exercise validation after the merge has not been performed.

The complete ordinary-build suite then passed 3,316 tests with ten existing skips using `flutter test --no-pub --concurrency=1`. The comparison helper's 13 self-tests and mobile preparation/inference helper's five self-tests also passed after the merge. These results cover code commit c940d09. The following publication commit updates documentation only.

### S2 experimental continuity warning, 2026-11-16

- Main fe1aad1 merged into the separate S2 branch. The user confirmed owner/PM agreement for the battle and counter files; this prototype is disabled unless `S2_PERSON_GUARD=true` is supplied as a Dart define. No real-person identity guarantee is claimed.
- Fake-camera tests exercise abrupt changes and confirmation in AI push-up/squat and online push-up, withheld online pose publication, stale or invalid anchors, no-frame watchdog, failed camera retry without losing score, and setup re-entry with zero start delay. An identical-pose test demonstrates why geometric continuity cannot verify identity.
- Independent read-only Codex review reproduced paths involving stale online publication, failed-retry score loss and setup re-entry; subsequent changes and their tests were rechecked by the reviewer without independently rerunning tests. The author's focused regression run passed 129 tests before the final setup regression was added; that additional regression passed independently.
- An earlier full test run overlapped source edits and failed two cases against stale compiled code; the corresponding focused tests passed after the fixes. For the final results see the subsequent entry. A previous forced-on integration experiment failed 47 cases; the full suite with the experimental flag enabled has not been established as passing.
- No independently labelled two-person tracking/repetition dataset or physical-device UAT was available. The approximate 1,464-video landmark-stream screening has no true/false-positive labels and is not an accuracy measurement; details are in person-behind-findings.md.

- Final code verification: `flutter analyze --no-pub` passed; `flutter test --no-pub --concurrency=4 --reporter expanded` passed 3,239 tests with 10 existing skips. A scoped coverage collection failed when the Dart VM service disappeared, so no new coverage percentage is claimed. The server was unchanged.

### S2 review-ready verification, 2026-11-16

Code verified at `992de85`, with current main `fe1aad1` already present. The subsequent publication update changes these personal notes only.

```sh
cd gymrats_app
flutter analyze --no-pub
flutter test --no-pub --coverage --concurrency=1 --reporter expanded test/services/pose/pose_estimator_test.dart test/services/pose/person_behind_estimator_test.dart test/viewmodels/rep_counter_viewmodel_test.dart test/viewmodels/battle_viewmodel_test.dart test/screens/battle_screen_test.dart test/screens/online_preparation_test.dart test/design_tokens_test.dart
```

- Analysis completed with zero issues. The seven-file regression run passed 258 tests, with zero failures and zero skips. Serial coverage collection succeeded and supersedes the earlier failed scoped collection.
- The existing full-suite result on this code remains 3,239 passed and 10 existing skips. This publication pass reran the seven selected suites. Dedicated widget tests enable the guard through constructor injection for AI push-up, AI squat and online push-up.
- The earlier globally forced-on run produced 47 failures. Full-suite validation with `S2_PERSON_GUARD=true` remains open. The experimental build flag defaults to false.
- An independent read-only Codex reviewer inspected the current diff, guard lifecycle, setup handoff and online publication. It found no actionable defects within the opt-in prototype scope. The reviewer used source inspection and the author's test evidence.
- Physical two-person UAT, identity-labelled video replay, and missed/extra-repetition rates remain open. Similar or gradual person substitution can pass the geometry check. S1 PR #69 remains the prerequisite for merging S2 PR #72.

#### Changed-file line coverage

| Layer / file | Covered / executable | Coverage | Target | Met |
|---|---:|---:|---:|---|
| Service / pose_estimator.dart | 134 / 136 | 98.53% | 85% | yes |
| ViewModel / rep_counter_viewmodel.dart | 338 / 356 | 94.94% | 90% | yes |
| ViewModel / battle_viewmodel.dart | 320 / 324 | 98.77% | 90% | yes |
| View / battle_screen.dart | 184 / 195 | 94.36% | 75% | yes |
| View / online_battle_screen.dart | 309 / 315 | 98.10% | 75% | yes |

The continuity guard and its anchor implementation cover 84/84 executable lines. Across changed files, ViewModel coverage is 658/680 (96.76%) and View coverage is 493/510 (96.67%). These measurements concern changed files exercised by the seven selected suites. Whole-project layer coverage and server coverage were outside this rerun.

#### Test cases and acceptance mapping

| Layer | Updated or added test file | Verified behavior |
|---|---|---|
| Service | person_behind_estimator_test.dart | Synthetic detector target changes, identical-geometry limitation, abrupt jump, short/long loss, explicit fresh confirmation |
| ViewModel | rep_counter_viewmodel_test.dart | Scoring stops on suspected change, stale anchor, stream watchdog, retry failure preserves score and confirmation |
| ViewModel | battle_viewmodel_test.dart | Setup-to-round guard handoff and setup re-entry |
| View | battle_screen_test.dart | AI push-up and squat warning and confirmation |
| View | online_preparation_test.dart | Online warning, confirmation and withheld pose publication |

The prototype pause-and-confirm path maps to `a suspected person change stops scoring until explicit confirmation`, `a stalled stream warns and requires a fresh confirmed person`, and `experimental online guard pauses and requires confirmation`. The original-user identity-retention acceptance criterion still requires labelled physical testing.

### S2 integration after S1 PR #69, 2026-11-16

The PM merged S1 into main as `d188240`. S2 merged that main revision into its previously verified head `a0f5af6`. The three personal-note conflicts were resolved by retaining both histories and the original prompt wording. Source files merged automatically.

- `flutter analyze --no-pub`, run from `gymrats_app`, passed with zero issues.
- `flutter test --no-pub --concurrency=1 --reporter expanded` passed 3,329 tests with 10 existing skips and zero failures on the resolved merge tree.
- The seven-suite serial coverage command from the previous entry passed 258 tests with zero failures and zero skips. Changed-file results remained 134/136 for `pose_estimator.dart`, 338/356 for `rep_counter_viewmodel.dart`, 320/324 for `battle_viewmodel.dart`, 184/195 for `battle_screen.dart`, and 309/315 for `online_battle_screen.dart`. Every changed file remains above its layer target.
- Independent read-only review confirmed that the S1 judge, adapter and metrics files match incoming main, and that S2 abandonment/reset clears the newly integrated knee-forest history. The reviewer found no actionable integration defect. Both staged-file and branch-diff ownership checks passed for the 14 S2 paths.
- This merge satisfies the S1 prerequisite. Physical two-person UAT, globally enabled S2 full-suite validation and independently labelled identity-retention measurements remain open.

The earlier successful CI run belongs to `a0f5af6`; CI for the new merge must be checked separately. The local test logs are `C:/SWPP/iter4/s2-post-s1-full-tests.log`, `s2-post-s1-coverage.log` and `s2-post-s1-analyze.log`.

### S2 enabled-build and actual-video follow-up, 2026-11-17

The locally verified app and test files are in commit `f5c78e1` on
`test/person_behind_user`, based on `6343b63`. Results below were collected
on those files before committing. The associated PR is [#72](https://github.com/snuhcs-course/swpp-2026-project-team-04/pull/72).

The pre-fix enabled full suite reproduced **3,315 passed / 14 failed / 10
existing skipped**. The older 47-failure figure came from a scoped integration
run. Four test files now model an ongoing camera stream, retain queued fake
verdict timing, synchronize clocks and explicitly confirm after intentional
loss/restart. Helpers that had forced the guard off now honor the build define.
The sound-file fixture exception was explicitly approved by the user on behalf
of its owner/PM. Intentional stalls and all original sound/result assertions
remain covered.

Real video showed a one-frame shoulder-width collapse permanently latching a
false warning. A failing-before/fixed-after regression drove the service fix:
withhold anomalous scale-only frames without changing the anchor, allow return
to the old scale, and require confirmation for a sustained 200 ms change.
Position jumps and the 750 ms loss threshold are unchanged.

#### Test cases and acceptance mapping

| Layer | File | Evidence |
|---|---|---|
| Service | `person_behind_estimator_test.dart` (updated) | Isolated width outlier recovery; sustained scale change; position jump remains latched |
| ViewModel | `battle_viewmodel_test.dart` (updated) | Realistic camera cadence; explicit confirmation after restart/loss; setup holds and match-clock watchdog |
| View | `battle_screen_test.dart` (updated) | Guard enabled by define; existing warning/recovery and UI assertions |
| View | `online_preparation_test.dart` (updated) | Shared fake clock, continuous setup frames, deliberate loss and confirmation, blocked pose publication |
| View | `sound_battle_screen_test.dart` (updated with approval) | Continuous camera input preserves original sound/result checks |
| App counter/service replay | `person_behind_video_replay_test.dart` (new) | Nine actual native-video landmark streams through real counter/judges; guarded/unguarded event comparison; actual wrong-target withholding; confirmation restores publication |

- No added/lost reps because of background person **or pause and notify**:
  `real wrong-person stream is withheld until confirmation`,
  `S2-SQUAT-MULTI retains the original user and judge events`, the D015G/D015B
  counterparts, and existing AI/online tracking-warning widget tests.
- Recovery: `explicit confirmation resumes a returned real-video user` plus
  fake-camera UI/VM confirmation tests. The native clip proves publication
  recovery; later poor poses prevent a claim of uninterrupted counting.
- Transient and sustained scale behavior: the three new service regressions.

#### Final local verification

- `flutter analyze --no-pub`: zero issues.
- `flutter test --no-pub --dart-define=S2_PERSON_GUARD=true --concurrency=4 --reporter expanded`:
  **3,342 passed / 0 failed / 10 existing skipped**.
- `flutter test --no-pub --concurrency=4 --reporter expanded` (ordinary build):
  **3,342 passed / 0 failed / 10 existing skipped**.
- New native-video and guard-service tests together: **18 passed**, no skips.
- The combined coverage runs (parallel full suite and serial scoped suite)
  lost the VM service while collecting coverage (`getSourceReport: (112)`).
  Running the nine scoped files in separate processes with the guard enabled
  yielded **272 passed, zero failed, zero skipped**. Eight files produced
  nonempty LCOV data. The design-token suite checks source text and produced
  no executable-line coverage. Each command used `flutter test --no-pub
  --dart-define=S2_PERSON_GUARD=true --coverage --concurrency=1` with one file.
- Independent read-only Codex review: **APPROVE for code/fixture/evidence
  scope**, with final full-run/coverage results pending at review time. It
  checked native fixture provenance and guard safety and did not rerun the
  full suite independently. `git diff --check` and ownership checks passed.

Line coverage from the successful scoped runs:

| S2 production file | Covered / executable | Coverage | Layer target |
|---|---:|---:|---:|
| `pose_estimator.dart` | 144 / 146 | 98.63% | 85% |
| `rep_counter_viewmodel.dart` | 345 / 356 | 96.91% | 90% |
| `battle_viewmodel.dart` | 319 / 324 | 98.46% | 90% |
| `battle_screen.dart` | 184 / 195 | 94.36% | 75% |
| `online_battle_screen.dart` | 309 / 315 | 98.10% | 75% |

Actual-video evidence is detailed in `docs/iteration-4/person-behind-findings.md`
and the fixture README. Five fresh videos supplied 1,344 Android accurate/stream
frames; four existing hash-matched native captures were reused. The replay
fixture contains 2,751 frames / 2,685 at or after reviewed anchors. Eight source
videos (2,528 original frames) were visually reviewed frame by frame by a
separate Codex agent; O033 had sampled review. This is not human-adjudicated
ground truth or physical-phone NV21 UAT. In O027, all 256 reviewed wrong-target
frames were withheld; seven baseline *invalid* events were suppressed. The
multi-person squat retained the same three valid reps. Blurred controls still
cause visible pauses and interrupted attempts, explicitly included in the
report. No population accuracy or general identity-retention rate is claimed.

Logs and local source/capture/observation artifacts:
`C:/SWPP/iter4/s2-validation/`. Server unchanged; server tests not run.


### Per-frame knee observation, 2026-11-16

The user clarified that knee support must be classified continuously on every pose frame with touching, lifted or occluded output. The local implementation at base 4edc96a adds KneeFrameClassifier and snapshot.knee, independently of repetition completion. The diagnostic HUD shows the current state. The comparison build flag PUSHUP_FRAME_KNEE=true enables accumulated stable evidence as a repetition veto. Observations are available in ordinary builds too. This local experiment does not measure physical floor contact directly.

A new 32-tree, depth-four model uses 48 single-frame features. Five source-group development folds select threshold 0.67. Actual Dart evaluation covers 13,185 frames after two contradictory inherited labels are excluded. On the reused holdout, normal frames emit lifted 1001/1837, touching 18/1837, and occluded 818/1837. Knee-supported frames emit touching 279/523, lifted 169/523, and occluded 75/523. The occluded state includes low-confidence, missing or out-of-frame observations and a torso-overlap heuristic. Independent frame-level occlusion labels remain unavailable. These frame results do not establish completed-repetition accuracy. See pushup-frame-knee.md for the full method and reproduction.

- Flutter analyze --no-pub passed after the final correction.
- Five-file sequential coverage run passed 251 tests with nine existing known-error recording skips. Command from gymrats_app was flutter test --no-pub --coverage --concurrency=1 test/services/pose/pose_metrics_test.dart test/services/pose/rep_judge_test.dart test/services/pose/push_up_judge_adapter_test.dart test/services/pose/pushup_error_cases_test.dart test/demo/rep_judge_demo_test.dart.
- Changed-file coverage was pose_metrics.dart 912/923 (98.81%), rep_judge.dart 836/857 (97.55%), rep_judge_demo.dart 963/1029 (93.59%), adapter 38/40 (95.00%). Service files exceed the 85% target. The diagnostic entry point is outside normal View layer aggregation. Full-project layer coverage was not collected.
- Tests cover all three immediate states, low-confidence and overlapping joints, invalid model output, forty actual golden frames, stable evidence across hidden frames, a subsequent lifted rep, reset and camera gaps, no-face/no-event frames, the MLP path and the diagnostic status label.
- Independent read-only Codex review reproduced evidence leaking from an eventless short dip into the next normal repetition. Codex corrected eventless attempt completion and added the exact regression. The reviewer verified the corrected output. Eight dedicated integration tests passed.
- Forty golden probabilities match Python within 1.45e-15 and every expected state matches. Desktop classification timing was 4 microseconds median and 15 microseconds p95. Physical-device timing and live movement validation remain unmeasured for this model.
- The full Flutter suite was outside this scoped verification. The work is a local working-tree change. Logs and model artifacts are under C:/SWPP/iter4/frame-knee.

### Before/after knee sequence, 2026-11-18

The user requested the sequence `? -> touching -> full push-up -> touching -> ?`
as an additional knee veto and a phone build with that option enabled. Changes
are local on S1 base `4edc96a`. The phone build also includes S2 `212323a`.

- Preparation is sampled before the current movement frame is classified.
  It needs three distinct observations spanning 100 ms and a recent confirmed
  touching state, no older than `config.maxFrameGap` (500 ms by default).
  A current lifted preparation prevents reuse of an older touching state.
- Occluded frames during the attempt preserve the captured preparation.
  The closing top frame must also return touching. This endpoint uses one
  current classifier result. Repetition emission retains its existing timing.
- Missing/stale preparation, a hidden/lifted return, same-frame begin/finish,
  reset, S2 abandonment and camera gaps cannot manufacture the sequence.
  An eventless short attempt releases its preparation evidence.
- Three new endpoint regressions failed against the previous code. After the
  fix, the five S1 suites passed 260 tests with nine existing skips. A later
  added MLP sequence regression is included in the final combined run below.
- Final combined build analysis passed. Nine suites with both
  `S2_PERSON_GUARD=true` and `PUSHUP_FRAME_KNEE=true` passed **434 tests**
  with zero failures and zero skips. These include the actual-video S2 replay,
  both pose services, counter, AI/online screens, demo and design tokens.
- One initial combined failure came from a test of the older MLP knee model
  implicitly inheriting the new comparison flag. That fixture now explicitly
  selects its intended model, preserving its recorded-event assertions.
  A separate full-recording test verifies that the new sequence converts all
  four binary-accepted events to kneesDown with touching endpoint input.
- Separate enabled coverage runs of pose_metrics_test and rep_judge_test
  succeeded. Their merged line results are **915/935 (97.86%)** for
  pose_metrics.dart and **827/861 (96.05%)** for rep_judge.dart, exceeding
  the 85% service target. Full-project coverage was not collected.
- Independent read-only Codex review returned APPROVE for the sequence logic.
  Physical knee-contact accuracy remains a user phone test.

Commands ran from the corresponding gymrats_app directory. Test logs are
`C:/SWPP/iter4/frame-knee/sequence-*.log`, with two LCOV files in the same
folder. Combined analysis, test and build logs are in
`C:/SWPP/iter4/s2-frame-knee-phone-20261118/`.

The combined ARM64 release was installed over GymRats on SM-S901N with both
S2_PERSON_GUARD and PUSHUP_FRAME_KNEE enabled. MainActivity launched successfully
and the logged-in home screen was visible. Local and installed APK SHA-256
matched 24378d9f21faf9fbe4d69f734413b4c230e74367a0ff52316401be3555a4d808.
Filtered startup error logs were empty. Physical repetitions remain the user's
manual test. No commit or push was performed.

### Knee sequence PR publication, 2026-11-18

App, tests and model note are committed as3668908 on codex/pushup-knee-sequence,
based on main e0bcae2 after S1#69 and S2#72 merged. The endpoint rule is now
enabled by default with PUSHUP_FRAME_KNEE=false as comparison opt-out.

- Final branch analysis passed with zero issues.
- Before re-enabling one repaired label test, full ordinary and S2-enabled
  runs each passed3,376 tests, zero failures, ten existing skips. Commands
  were flutter test --no-pub --concurrency=4 --reporter expanded and the same
  with --dart-define=S2_PERSON_GUARD=true.
- Initial default run failed two recorded-output expectations. New endpoint
  outputs reject the third head-nod event and first145535knees event. The
  baseline tables and source labels are retained, with exact endpoint-mode
  overrides. The now-repaired nine-knee label check runs in enabled mode.
  Final focused error-case suite passed30tests/8existing skips by default and
  29tests/9existing skips with PUSHUP_FRAME_KNEE=false. This last change adds
  the repaired label assertion after the full runs above.
- Both per-file coverage commands succeeded with --coverage --concurrency=1.
  Merged service coverage remains915/935(97.86%) for pose_metrics.dart and
  827/861(96.05%) for rep_judge.dart. The service target is85%.
- Independent read-only Codex review approved source, model/golden provenance,
  sequence behavior and expectation changes. User approval covers the immediate
  non-draft PR. Physical contact accuracy remains the phone trial documented
  above. Server unchanged, server tests not rerun locally for this follow-up.

Logs are C:/SWPP/iter4/frame-knee/pr-final-analyze.log,
pr-final-default-full.log, pr-final-s2-full.log, pr-error-final-default.log,
pr-error-final-disabled.log, pr-metrics-final.log and pr-judge-final.log.
