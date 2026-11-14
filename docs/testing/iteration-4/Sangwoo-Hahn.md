# Testing — Iteration 4: S3 push-up silhouette draft

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
