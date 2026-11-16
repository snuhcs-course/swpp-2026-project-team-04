# Mobile pose model comparison

Generated 2026-11-16 05:31 UTC.

## Evaluation setup

The comparison covers 2,706 presegmented normal/knees-down clips and 13,187 unique sampled frames. Each clip supplies five known phase positions. Development contains 2,223 clips from 281 source groups. The reused holdout contains 483 clips from 74 groups, including 378 normal and 105 knees-down clips. [Evaluation manifest](C:/SWPP/iter4/mobile-pose-benchmark/full/evaluation-manifest.json)

Existing labels came from Codex visual review of nine frames per clip. Human verification is recorded for 0/2706 clips (`human_verified=false` for the remaining clips). The holdout had already been inspected in earlier experiments. Participant overlap across different source groups remains possible.

Classifier selection uses the same 5 frozen grouped development folds and maximizes balanced accuracy. Inputs use 12 shared joints, normalized 2D positions, angles, support-line distances and five-phase statistics. Confidence scores are omitted. Insufficient pose observations produce an unknown result, which stays in each recall denominator. [Evaluation details](C:/SWPP/iter4/mobile-pose-benchmark/full/eval-rtmpose-s/comparison.json)

RTMPose accuracy uses full-corpus PC inference with the official model weights. Its phone pilot uses those same weights and is checked against aligned PC outputs. ML Kit Accurate and Base accuracy use fresh Android inference on the same selected frames, with the streaming detector reset between source videos. Sapiens2-5B benchmarking was stopped after the user prioritized low-latency phone inference.

## Holdout clip classification

Normal acceptance is normal clips classified as normal. Knees-down rejection is knees-down clips classified as knees-down. Balanced accuracy is the average of those two recalls. Unknown counts are shown as normal / knees-down.

| Pose model | Normal accepted | Knees-down rejected | Balanced accuracy | Unknown |
| --- | ---: | ---: | ---: | ---: |
| ML Kit Accurate | 359/378 (94.97%) | 97/105 (92.38%) | 93.68% | 6 / 0 |
| ML Kit Base | 346/378 (91.53%) | 91/105 (86.67%) | 89.10% | 13 / 0 |
| RTMPose-s | 361/378 (95.50%) | 88/105 (83.81%) | 89.66% | 0 / 0 |
| RTMPose-m | 364/378 (96.30%) | 93/105 (88.57%) | 92.43% | 0 / 0 |

| Pose model | Selected classifier | Development balanced accuracy |
| --- | --- | ---: |
| ML Kit Accurate | Random forest, depth 4 | 86.64% |
| ML Kit Base | Random forest, depth 4 | 84.07% |
| RTMPose-s | Random forest, depth 4 | 87.24% |
| RTMPose-m | Random forest, depth 4 | 87.09% |

[RTMPose-s results](C:/SWPP/iter4/mobile-pose-benchmark/full/eval-rtmpose-s/comparison.json), [RTMPose-m results](C:/SWPP/iter4/mobile-pose-benchmark/full/eval-rtmpose-m/comparison.json), [ML Kit Base results](C:/SWPP/iter4/mobile-pose-benchmark/full/eval-mlkit-base/comparison.json)

## Complete-cycle sensitivity check

The following subset contains clips marked as having a complete movement cycle. The fitted classifiers and decision rules are reused for this subset.

| Pose model | Normal accepted | Knees-down rejected | Balanced accuracy | Unknown |
| --- | ---: | ---: | ---: | ---: |
| ML Kit Accurate | 354/373 (94.91%) | 74/80 (92.50%) | 93.70% | 6 / 0 |
| ML Kit Base | 341/373 (91.42%) | 69/80 (86.25%) | 88.84% | 13 / 0 |
| RTMPose-s | 356/373 (95.44%) | 66/80 (82.50%) | 88.97% | 0 / 0 |
| RTMPose-m | 359/373 (96.25%) | 70/80 (87.50%) | 91.87% | 0 / 0 |

## Paired source-group uncertainty

Cells show the change from ML Kit Accurate in percentage points and its 95% paired source-group bootstrap interval. Intervals describe sampling uncertainty within this reused, automatically labeled corpus.

| Pose model | Normal acceptance delta | Knees-down rejection delta | Balanced accuracy delta |
| --- | ---: | ---: | ---: |
| ML Kit Base | -3.44 [-6.35, -0.90] | -5.71 [-13.54, +0.67] | -4.58 [-8.89, -1.25] |
| RTMPose-s | +0.53 [-2.64, +3.67] | -8.57 [-16.46, -1.47] | -4.02 [-8.22, -0.07] |
| RTMPose-m | +1.32 [-1.24, +4.02] | -3.81 [-9.82, +1.71] | -1.24 [-4.51, +1.86] |

Each interval uses 2000 bootstrap resamples.

## Comparable Android latency

All four jobs use the same 434 JPEG frames from 73 source videos on samsung SM-S901N (qcom, Android API 33). RTMPose-s requests XNNPACK with 4 threads, and RTMPose-m uses 4 threads. ML Kit uses automatic hardware selection. The table reports p50 / p95 milliseconds for frames following each source's first frame. Pipeline time is preprocessing plus synchronous inference plus postprocessing.

| Pose model | Prepare | Infer | Post | Pipeline | JPEG decode | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ML Kit Accurate | 0.06 / 0.09 | 16.19 / 30.86 | 0.10 / 0.16 | 16.31 / 31.08 | 4.36 / 10.96 | 20.51 / 38.74 |
| ML Kit Base | 0.06 / 0.11 | 16.96 / 31.82 | 0.09 / 0.15 | 17.11 / 31.99 | 4.08 / 9.87 | 21.32 / 39.83 |
| RTMPose-s | 7.10 / 9.33 | 18.18 / 20.76 | 0.29 / 0.36 | 25.70 / 31.91 | 2.89 / 8.04 | 28.67 / 38.73 |
| RTMPose-m | 7.08 / 8.81 | 44.85 / 47.61 | 0.30 / 0.36 | 52.46 / 56.19 | 2.97 / 8.16 | 55.69 / 59.75 |

| Pose model | First / subsequent frames | First-frame inference p50 / p95 ms | Thermal states and frame counts |
| --- | ---: | ---: | --- |
| ML Kit Accurate | 73 / 361 | 277.67 / 290.83 | 3 severe (434) |
| ML Kit Base | 73 / 361 | 227.58 / 243.37 | 3 severe (434) |
| RTMPose-s | 73 / 361 | 17.79 / 18.77 | 2 moderate (434) |
| RTMPose-m | 73 / 361 | 44.31 / 46.59 | 2 moderate (81), 3 severe (353) |

ML Kit recreates its detector at each source boundary. RTMPose retains its warmed inference session. Thermal differences can affect cross-job timing. Per-state distributions, initialization and warmup timings are retained in the detailed summary. [Latency and parity summary](C:/SWPP/iter4/mobile-pose-benchmark/latency-parity-summary.json)

ML Kit receives the original upright bitmap through `InputImage.fromBitmap(bitmap, 0)` with SDK-internal preprocessing. RTMPose uses a full-frame box with 1.25 padding and a normalized 192×256 RGB tensor. The summary's `effective_preprocessing` field corrects an earlier shared metadata label in raw ML Kit jobs.

## PC-to-phone RTMPose coordinate comparison

The following statistics use shared joints on aligned pilot frames with matching JPEG hashes, dimensions and model-weight hashes.

| Pose model | Frames | Mean / p95 / max coordinate distance, px | Null-mask mismatches |
| --- | ---: | ---: | ---: |
| RTMPose-s | 434 | 0.002658 / 0.000007 / 13.333333 | 0/7378 |
| RTMPose-m | 434 | 0.000286 / 0.000007 / 2.083332 | 0/7378 |

## Integration choice

The presegmented benchmark selects ML Kit Accurate with random forest, depth 4. It achieved 97/105 (92.38%) knees-down rejections and 359/378 (94.97%) normal acceptances, with a 16.31 ms median and 31.08 ms p95 sampled-frame pipeline. ML Kit Accurate provides the strongest observed knees-down rejection with a short sampled-frame pipeline. The subsequent native counter replay below shows that the new forest's benefit did not transfer to existing phone recordings. The requested app experiment remains subject to that observed regression and a separate live check.

## Native app-counter replay

A subsequent native Flutter VM check replayed 32 existing phone recordings (22,217 saved pose frames per variant) through the app's repetition-counter code. All 32 recording files identify their pose model as Accurate in `setup.model`. The existing `PushUpRecording` parser and minimum-edit label alignment scorer were reused. The check performed no model fitting, threshold tuning, fixture modification, or image reinference.

| Counter variant | Labelled normal accepted | Labelled incorrect uncounted | Correct rejection reason | Extra accepted / rejected |
| --- | ---: | ---: | ---: | ---: |
| Existing MLP knee decision | 60/63 (95.24%) | 134/207 (64.73%) | 77/207 (37.20%) | 26 / 110 |
| New five-phase knee forest | 55/63 (87.30%) | 120/207 (57.97%) | 51/207 (24.64%) | 43 / 93 |

The existing scorer treats an incorrect labelled repetition with no matching emitted event as uncounted. The incorrect category covers all recorded form faults. Extra events remain separately reported.

All 32 recordings retained identical event counts, indices and timestamps. Raw accepted events changed from 159 to 185, rejected events from 247 to 221, and knees-down rejection events from 206 to 155. Across the 8 knee-push-up and kneeling-bow recordings, raw accepted events increased from 0 to 39. Raw event totals include extra detections.

Normal acceptance fell in 5 recordings. The saved-recording replay therefore shows a regression after integration, despite the favorable presegmented-video score. Transfer to camera-driven cycle boundaries and the recorded phone poses needs further validation before selecting the forest as the app default. These replay results measure the saved landmark sequences and app counter behavior. Desktop VM execution time provides no phone-latency measurement. [Native replay results](C:/SWPP/iter4/mobile-pose-benchmark/native-knee-forest-replay.json)

## Validation boundary

The image-model benchmark uses supplied clip boundaries and sampled poses. The native replay adds recorded continuous landmark sequences and the app's repetition-boundary logic. Continuous live camera tracking, camera acquisition and image conversion, display latency, and the downstream classifier's phone runtime remain outside these measurements. A live GymRats deployment requires a separate end-to-end validation.

## Reproduction

```powershell
Set-Location 'C:/SWPP/iter4/mobile-pose-benchmark'
.\.venv\Scripts\python.exe .\summarize_mobile_pose_benchmark.py
.\.venv\Scripts\python.exe .\make_comparison_report.py
```

The report generator requires all three completed accuracy comparisons, all four completed, manifest-matched latency pilot jobs, and the native counter replay results.


### Selected comparison build installed

After reviewing the recorded-phone regression, the user explicitly chose the new knee-classifier comparison build. A fresh sequential build of lib/main.dart with PUSHUP_KNEE_FOREST=true succeeded and was installed with adb install -r on SM-S901N. The app launched successfully, the signed-in home screen was observed, and the AI push-up matching flow opened. The local APK and installed base.apk both have SHA256 ad65a33899b7727bcc1f5efc4af40a4f62dfac68eb46bbcc213bc0eb8f6a59c0.

The USB connection ended after installation, launch, and hash verification, during the follow-up pose-setup screenshot. Live exercise performance and the runtime activation log were therefore not captured. The selected build flag and its constructor activation are verified by the build command and focused tests. The artifact is C:/SWPP/iter4/mobile-pose-benchmark/gymrats-knee-forest-trial.apk. The installation preceded the PR integration commits.

Run the following command from `gymrats_app` to build the comparison variant.

```powershell
flutter build apk --debug --target-platform android-arm64 -t lib/main.dart --dart-define=PUSHUP_KNEE_FOREST=true --no-pub
```

The flag enables the existing general binary-MLP proposal path and the new knee-specific forest. The ordinary build leaves both paths disabled unless their respective build flags are supplied. Earlier S1 calibration, short-cycle, joint-span and shared phone-angle changes also affect the ordinary build. Its configured 172-degree lockout check is preserved by the PR integration. The experimental MLP path derives validity from its model score and knee veto, so that angle check does not describe the trial's decision rule.

Paths beginning with `C:/SWPP/` refer to local evidence files on the author's computer. The repository includes the inference code, exported forest, regression fixtures and comparison scripts. The video corpus, full benchmark outputs and installed APK remain local artifacts.
