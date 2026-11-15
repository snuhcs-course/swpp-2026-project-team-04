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
