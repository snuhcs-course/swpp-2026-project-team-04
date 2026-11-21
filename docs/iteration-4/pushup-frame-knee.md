# Unified frontal knee observation

## Per-frame contract

Each `RepJudge.update(frame)` classifies the current pose once and returns `update.snapshot.knee`, including frames that emit no repetition and frames whose face is unavailable.

| State | Display | Operational meaning |
| --- | --- | --- |
| `KneeFrameState.touching` | 무릎댐 | Observable support evidence is positive |
| `KneeFrameState.lifted` | 무릎뗌 | Observable support evidence is negative |
| `KneeFrameState.occluded` | 무릎가려짐·불확실 | Missing, unreliable, occluded or ambiguous support evidence |

The reading also includes `touchingProbability` when inference succeeds and a `reason` for unavailable observations. The third state covers missing, low-likelihood, out-of-image or unusable landmarks. The torso-overlap test is an image-space heuristic. Physical occlusion and floor contact still require visual validation.

The existing repetition diagnostic HUD displays this state. `KneeFrameClassifier.classify(frame)` can also be called directly without a repetition detector or calibration captures.

## Inference and sequence handling

The unchanged model consumes 48 features using 32 depth-four forest trees.
The runtime gates all twelve feature joints (shoulders, elbows, wrists, hips,
knees and ankles) for finite in-frame coordinates and likelihood at least 0.65.
In the supported frontal floor view, a mean elbow angle below 150 degrees
makes support unavailable: projected anatomy under the descending torso must
not clear a touching mode. The torso-overlap gate remains. These gates indicate
operational uncertainty, not independently measured physical occlusion.

A raw forest score above 0.67 supplies touching evidence; at or below 0.33 it
supplies lifted evidence. Intermediate scores normally abstain. Bilateral
ankle-minus-knee image height, in shoulder widths, can corroborate a gray score:
score above 0.5 plus mean gap at most -0.15, each leg at most -0.08, supplies
touching; score below 0.5 plus mean at least -0.10, each leg at least -0.16,
supplies lifted. Exactly 0.5 remains ambiguous. Readings identify
`corroborated_projection` or `ambiguous_support` in their reason. Reported
probability remains the raw forest score, not a calibrated combined posterior.
Image height is not measured floor distance. The policy was developed using
inspected Hyunwoo clips.

`KneeAttemptEvidence` receives every raw reading independently of the repetition result. Three consecutive distinct touching frames confirm touching. Three consecutive distinct lifted frames confirm lifted. There is no minimum time hold in addition to the frame count. One or two opposite observations retain the confirmed state. An occluded frame interrupts an unfinished streak while retaining the confirmed state.

At attempt start the judge captures the confirmed mode before processing that frame. Touching first confirmed during descent cannot become preparation for the same repetition. The confirmed mode persists through continuously delivered occluded frames. Reset, abandonment, image-coordinate changes and camera gaps over `config.maxFrameGap` (500 ms by default) clear it. Freshness refers to frame delivery, rather than the age of the last visible touching observation.

At the closing top frame the judge uses the current confirmed mode. Captured touching preparation and confirmed touching at completion reject an otherwise-valid repetition. This permits an occluded return or one/two lifted return observations while touching remains confirmed. Three consecutive lifted observations change that mode, and subsequent occlusion cannot restore old touching. A new three-frame touching streak is required to restore touching. Leading/trailing unavailable frames are optional.

| Confirmed preparation before attempt | Confirmed mode at return | Additional veto |
| --- | --- | --- |
| Confirmed touching | Touching | Reject the otherwise-valid rep as knees down |
| Confirmed touching | Lifted | Use the base judge result |
| Lifted, unconfirmed or reset | Any | Use the base judge result |

An eventless abandoned attempt also releases its captured preparation. The next attempt captures its own confirmed preparation. `JudgeSnapshot.knee` continues to report the raw current-frame observation, while the sequence uses the confirmed mode described above.

The unified policy is opt-in with `PUSHUP_FRAME_KNEE=true`. Primary, short-cycle, calibration,
span and optional MLP knee decisions consume the same completed-attempt
predicate. Old hip/shin/bow latches cannot independently reject a lifted or
unconfirmed mode. Non-knee checks and observed-return/lockout promotion gates
remain. Existing invalid reasons remain when the final endpoint veto runs.
The default `PUSHUP_FRAME_KNEE=false` retains legacy geometric judging,
while retaining current-frame observations. Old geometry unit tests explicitly
select that comparison mode. Unified-policy tests cover sequence behavior,
bypass prevention and partial feedback separately.

The PM's 2026-11-18 publication instruction requires demonstrated benefit on
the supplemental human-labelled set before enabling this rule by default.
The new Hyunwoo8 + Sangwoo8 coordinate set is available separately at
`gymrats_app/test/ai_eval/cases_iter4`, but its actual repetition labels are
pending recorder/PM confirmation. Thus no new-set benefit is established and
the default remains OFF. Both modes still provide current-frame knee readings.
Frozen/new-set ON/OFF reports are kept in `gymrats_app/test/ai_eval/results`.

Run from `gymrats_app` for the frame-evidence comparison build.

```powershell
flutter build apk --debug --target-platform android-arm64 --dart-define=PUSHUP_FRAME_KNEE=true
```

## Historical v1 model training and frame evaluation

The following figures are archived results of the eight-support-joint,
single-threshold policy at `c046947`, before unification. They do not measure
the current runtime. Forest weights have not been retrained for this change.

The training tool uses the existing Accurate ML Kit predictions and source-group split. Frame labels inherit earlier weak clip-level normal/knees-down labels. Two frames with contradictory inherited labels are excluded. Five development folds select the model and threshold. The previously used holdout remains a reused holdout.

The actual Dart API was replayed on 13,185 frames. Its holdout results include the observability gates.

| Inherited label | Frames | Lifted output | Touching output | Unavailable output |
| --- | ---: | ---: | ---: | ---: |
| Normal push-up | 1,837 | 1,001 (54.49%) | 18 (0.98%) | 818 (44.53%) |
| Knees-down push-up | 523 | 169 (32.31%) | 279 (53.35%) | 75 (14.34%) |

There are no independent frame-level occlusion labels in this evaluation. Unavailable counts measure the classifier's coverage, and the experiment does not establish physical occlusion accuracy. The model needs further validation of visible knee support, especially the 169 knees-down frames emitted as lifted. These are frame-level results. Completed-repetition accuracy for this new evidence consumer remains unmeasured.

Forty golden-frame probabilities match the Python model with maximum absolute error 1.45e-15, and all forty expected API states match. Desktop Dart classification took 4 microseconds median and 15 microseconds p95 across this run. Phone end-to-end latency remains unmeasured for the new model.

## Reproduction and local evidence

The Python training helper retains the historical v1 observability/selection
policy for the original model experiment. The Dart evaluator imports the
current API, so rerunning it would produce new runtime-policy measurements,
not reproduce the archived tally verbatim. This corpus was not rerun for the
current task, following the user's Hyunwoo-only video restriction.

```powershell
python tools/diagnose/train_frame_knee.py --root C:/SWPP/iter4/mobile-pose-benchmark --output C:/SWPP/iter4/frame-knee
dart run tools/diagnose/evaluate_frame_knee.dart
```

The evaluator uses the saved local corpus under `C:/SWPP/iter4/mobile-pose-benchmark`. Its output is `C:/SWPP/iter4/frame-knee/actual-classifier-report.json`. This path and the full source videos are local evidence. The repository includes training/evaluation tools and forty golden frames under `gymrats_app/test/fixtures/pushup_cases/frame_knee`.

Regression tests cover touching-hidden-touching, lifted-hidden-lifted, a subsequent lifted repetition, no-face observations, the MLP entry point, reset, abandonment, time gaps and an eventless short dip followed by a normal repetition.

## 2026-11-18 Hyunwoo-only inspected development replay

Only the four push-up MP4s in `gymrats-recordings-1118/2_hyunwoo_1407-1409`
are included: 1,161 original-PTS frames and twenty reviewed motion cycles.
The four squat videos are outside this push-up rule. Already captured full
720x1280 Android ML Kit accurate/stream landmarks are replayed without phone
IMU, setup gating, identity guard or live camera scheduling. Independent visual
cycle times were frozen before judge output. Matching is ordered 1:1 within
0.75 seconds; recovery extras and missing verdicts remain separate.

| Intended scenario | Old accepted / rejected / missed | Unified accepted / rejected / missed |
|---|---|---|
| Normal, five cycles |1 /4 /0|5 /0 /0|
| Knees, five cycles |2 /3 /0|0 /5 /0|
| Bent arms, five cycles |0 /3 /2|0 /3 /2|
| Belly, five cycles |1 /4 /0|1 /4 /0|

All five knee rejections use `kneesDown`. Normal recovery at 10.324 seconds
still produces an extra rejection, now `shouldersNotLevel` instead of
`kneesDown`; this is not an exercise cycle. Bent-arm verdicts are depth faults
and belly verdicts are extension faults, so binary rejection is distinct from
correct-reason accuracy. Two bent-arm attempts remain undetected and one belly
attempt remains accepted.

These are inspected, single-person development/rule-tuning results, not an
untouched test set or population-accuracy estimate. The policy was examined on
these same clips. No 1118 video trained forest weights, and no model trained
on older phone recordings was adopted. Independent framewise floor-contact
labels and live-phone end-to-end accuracy/latency are unavailable.

Local evidence: `C:/SWPP/iter4/unified-knee-1118/`, including the four-source
`hyunwoo-native.json`, `replay_test.dart`, `hyunwoo-results.json` and summaries.
Numeric model goldens remain unchanged. Software API-state expectations alone
are updated, with their earlier values preserved in the fixtures.


## 2026-11-22 selected combined battle policy

The user chose MLP plus both knee layers after the five-way comparison. Production `judgeFor(pushUp)` now constructs `RepJudge.forBattle`, which enables MLP, retains the old knee specialist and adds the current endpoint veto by default. The unnamed constructor still has historical defaults for replay and diagnostics. Explicit build definitions allow either policy to be compared. This dated choice supersedes the previous OFF-by-default policy for normal battles only; it does not turn provisional labels into confirmed ground truth. See [the combined-policy evaluation](pushup-mlp-combined-evaluation.md) for all gains, regressions and limitations.
