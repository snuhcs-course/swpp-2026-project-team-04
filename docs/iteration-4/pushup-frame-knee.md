# Continuous knee observation prototype

## Per-frame contract

Each `RepJudge.update(frame)` classifies the current pose once and returns `update.snapshot.knee`, including frames that emit no repetition and frames whose face is unavailable.

| State | Display | Operational meaning |
| --- | --- | --- |
| `KneeFrameState.touching` | 무릎댐 | Observable input exceeds the fitted knee-support threshold |
| `KneeFrameState.lifted` | 무릎뗌 | Observable input falls at or below that threshold |
| `KneeFrameState.occluded` | 무릎가려짐 | Required observations are unavailable or the knee overlaps the projected torso |

The reading also includes `touchingProbability` when inference succeeds and a `reason` for unavailable observations. The third state covers missing, low-likelihood, out-of-image or unusable landmarks. The torso-overlap test is an image-space heuristic. Physical occlusion and floor contact still require visual validation.

The existing repetition diagnostic HUD displays this state. `KneeFrameClassifier.classify(frame)` can also be called directly without a repetition detector or calibration captures.

## Inference and sequence handling

The new model consumes 48 features from one frame. It contains 32 depth-four random-forest trees and uses the development-selected threshold 0.67. It uses the existing normalized-joint feature extraction. The runtime checks both wrists, hips, knees and ankles for finite, in-frame coordinates and likelihood of at least 0.65. Shoulder positions define the torso polygon. Missing inputs produce an immediate unavailable reading.

`KneeAttemptEvidence` receives every reading independently of the repetition result. Three distinct observations spanning at least 100 ms confirm the preparation state. At the start of an attempt, the judge records whether touching was confirmed before that frame, using preparation at most `config.maxFrameGap` old (500 ms by default). A current lifted preparation disqualifies the earlier touching state. Touching first discovered during descent cannot supply preparation for that same repetition.

An unavailable observation inside the attempt preserves its captured preparation evidence. When the full repetition returns to the top and emits its event, a current `touching` reading completes the sequence. This return endpoint uses that frame's classifier output. It requires no additional hold or delayed repetition result. Leading/trailing unavailable frames are optional.

| Preparation before attempt | Return frame | Additional veto |
| --- | --- | --- |
| Confirmed touching | Touching | Reject the otherwise-valid rep as knees down |
| Confirmed touching | Lifted or unavailable | Use the base judge result |
| Lifted, unavailable or stale | Any | Use the base judge result |

Reset, abandonment, camera-coordinate changes and excessive frame gaps clear tracking state. An eventless abandoned attempt also releases its captured preparation. The next attempt needs its own recent preparation.

The sequence veto is enabled by default. `PUSHUP_FRAME_KNEE=false` disables it for comparison while retaining current-frame readings. The rule works with the ordinary counter and with `PUSHUP_MLP=true`. In the latter combination it replaces the older knee-specific veto. A valid repetition with both endpoints matched becomes a `kneesDown` rejection. Existing invalid repetitions retain their reason.

Run from `gymrats_app` for the frame-evidence comparison build.

```powershell
flutter build apk --debug --target-platform android-arm64 --dart-define=PUSHUP_FRAME_KNEE=true
```

## Training and evaluation

The training tool uses the existing Accurate ML Kit predictions and source-group split. Frame labels inherit earlier weak clip-level normal/knees-down labels. Two frames with contradictory inherited labels are excluded. Five development folds select the model and threshold. The previously used holdout remains a reused holdout.

The actual Dart API was replayed on 13,185 frames. Its holdout results include the observability gates.

| Inherited label | Frames | Lifted output | Touching output | Unavailable output |
| --- | ---: | ---: | ---: | ---: |
| Normal push-up | 1,837 | 1,001 (54.49%) | 18 (0.98%) | 818 (44.53%) |
| Knees-down push-up | 523 | 169 (32.31%) | 279 (53.35%) | 75 (14.34%) |

There are no independent frame-level occlusion labels in this evaluation. Unavailable counts measure the classifier's coverage, and the experiment does not establish physical occlusion accuracy. The model needs further validation of visible knee support, especially the 169 knees-down frames emitted as lifted. These are frame-level results. Completed-repetition accuracy for this new evidence consumer remains unmeasured.

Forty golden-frame probabilities match the Python model with maximum absolute error 1.45e-15, and all forty expected API states match. Desktop Dart classification took 4 microseconds median and 15 microseconds p95 across this run. Phone end-to-end latency remains unmeasured for the new model.

## Reproduction and local evidence

```powershell
python tools/diagnose/train_frame_knee.py --root C:/SWPP/iter4/mobile-pose-benchmark --output C:/SWPP/iter4/frame-knee
dart run tools/diagnose/evaluate_frame_knee.dart
```

The evaluator uses the saved local corpus under `C:/SWPP/iter4/mobile-pose-benchmark`. Its output is `C:/SWPP/iter4/frame-knee/actual-classifier-report.json`. This path and the full source videos are local evidence. The repository includes training/evaluation tools and forty golden frames under `gymrats_app/test/fixtures/pushup_cases/frame_knee`.

Regression tests cover touching-hidden-touching, lifted-hidden-lifted, a subsequent lifted repetition, no-face observations, the MLP entry point, reset, abandonment, time gaps and an eventless short dip followed by a normal repetition.
