# Shared AI/online squat judging and depth reports

Date: 2026-11-14. Branch: `fix/squat_judge_accuracy`. Base: `eb336c3` (main including J4 #57).
Issue: [#59](https://github.com/snuhcs-course/swpp-2026-project-team-04/issues/59).

## Behavior

The production AI counter previously injected `SquatDemoJudge`. Its snapshots
omitted the depth already computed by the judge, so `FormSample.depth` was null
throughout the report. The prototype also ignored shallow attempts rather than
emitting the online judge's rejection events, and its type bypassed the phone
movement check.

`BattleViewModel.botCounter` now uses the default `judgeFor(exercise)` path,
as the online counter does. Both production squat paths use `SquatRepJudge`:
standing calibration, smoothing, depth threshold, shallow/incomplete-standing
reasons and the counter's phone-movement rule are shared. Existing wire codes
and scoring thresholds stay in use. Motions too small to be a detected attempt
are still ignored according to the existing online judge; this change does not
make every tiny motion an invalid repetition.

`SquatRepJudge` supplies current-frame depth after calibration, including zero
at the calibrated standing frame. Hip/knee guide coordinates come from the same
usable sides as the measurements, so switching the AI counter does not remove
the guide lines. Missing measurements and uncalibrated frames have null depth.

The legacy `SquatDemoJudge` class remains for explicitly injected diagnostic
uses and its existing tests. It now also emits its computed frame depth, while
preserving the prototype's existing counting behavior. The production AI path
no longer selects it. The legacy counter type exception is therefore not used
by production AI or online squats.

## Decisions and scope

The user explicitly chose to unify AI and online judging, then confirmed the
owner/PM's agreement to the bot factory and its tests in `battle_viewmodel.dart`
and `battle_viewmodel_test.dart`. Dated one-off exceptions are recorded in the
local harness. No ownership map or public API was changed. #58 remains W8's
screen task; this change does not alter its graph wording or conclusions.

## Verification

The regression tests initially reproduced null demo depth and absent guide
coordinates. The actual bot-counter replay also initially produced zero shallow
rejections and allowed a moved-phone rep. After the fix:

- Six targeted suites: 92 passed, zero failed.
- The synthetic UAT-4-style sequence produces four counted and two shallow
  rejected squats in both AI and online counters, with equal events and depth
  samples. Report JSON round trips retain the samples and the analyzer reports
  the two shallow squats.
- The bot path rejects a repetition after the phone has moved.
- Current depth falls again on ascent while the repetition's maximum stays at
  its peak; null/missing frames and reset/abandon are covered.
- Independent read-only Codex review found no actionable defects; scoped
  implementation approved. This is not approval of all broader S4 accuracy work.

Full-suite results are recorded in `docs/testing/iteration-4/Sangwoo-Hahn.md`.
Inputs in these tests are synthetic landmarks with fake camera/detector/phone
services. Real-camera accuracy across different people and phone angles, and
physical UAT, have not been established by these tests.
