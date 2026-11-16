# Nine-way push-up judging on the Iteration 4 recuts

> Historical experiment before the later span calibration and PR-integration lockout correction; see `pushup-span-benchmark.md` for the latest replay.

## Result on the Android landmark stream

The app uses `tree5_small30_elev60_knees_tilt15_guarded`. It ranked first among 71 evaluated settings, with development macro F1 of 18.97% against the old judge's 11.38%. Thirty-six settings passed the phone-recording and visibility controls. The Android replay covered 133,327 sampled frames across all 1,464 originals. ML Kit returned no person on 1,911 frames. Those frames remained in the stream.

| Held-out metric | Original | Selected |
|---|---:|---:|
| Macro F1 on the six represented classes | 10.68% | 19.08% |
| Matching time and correct class, out of 848 attempts | 117 (13.8%) | 192 (22.6%) |
| Labelled attempts with no corresponding verdict | 568 | 419 |
| Extra verdicts | 7 | 14 |
| Labelled invalid attempts counted as valid, out of 470 | 15 | 18 |

The paired increase in macro F1 was 8.40 percentage points. Resampling the 83 source groups gave a 95% interval of +5.41 to +11.46 points across 980 of 1,000 bootstrap samples containing all six classes. Across development and held-out groups together, the refitted judge agreed on 986/4,160 distinct labelled attempts. Including duplicate rows gives 987/4,230. The 848 held-out attempts are the independent test.

| Legacy reference class | Held-out examples | Original correct | Selected correct | Selected F1 |
|---|---:|---:|---:|---:|
| Normal | 378 | 98 | 106 | 42.0% |
| Insufficient depth | 141 | 7 | 60 | 37.5% |
| Incomplete extension | 82 | 7 | 7 | 9.1% |
| Shoulders not level | 134 | 0 | 9 | 12.0% |
| Knees down | 105 | 5 | 10 | 13.9% |
| Arms straight on descent | 8 | 0 | 0 | 0.0% |
| Belly down | 0 | — | — | Unmeasured |
| Non-floor push-up | 0 | — | — | Unmeasured |
| Phone moved | 0 | — | — | Unmeasured |

The largest improvement was in shallow attempts. A clearly observed chest dip with elbow flexion and reopening can now produce feedback on a movement the original judge dropped. For a shorter movement to **count** under the elevated-camera adjustment, the attempt must show the required shoulder travel, arm flexion and return. An already rejected partial movement can get a more specific shoulder or knee correction from the small decision tree. The phone-movement verdict still uses the live device motion signal. Internet videos have no recorded device IMU.

The 32 frozen team phone recordings kept M1 at 50/63 normal reps counted, M2 at 188/207 incorrect reps not counted and M3 at 124/207 incorrect reps given the right reason. Extra rejected events on those recordings increased from one to five. These recordings include 35 labelled belly-down attempts. The existing wall and motion-sensor tests exercise the other two unsupported corpus categories. The annotated collapse `Q00011226__001` produced no count and no specific knee correction. All three `Q00001357` intervals remain unlabelled and are excluded from class agreement.

## What was measured

The target is the original GymRats form label on each revised attempt. The 4,975 cuts came from 1,464 downloaded videos. Of those cuts, 4,230 have a primary label and 745 remain unassigned. The nine labels are normal, insufficient depth, incomplete extension, unlevel shoulders, knees down, arms straight, belly down, non-floor push-up and phone movement.

The primary evaluation uses the 2026-11-15 visually reviewed **recut** boundaries and hashes. The older core cut and the later replacement taxonomy have different meanings. The replacement taxonomy supplies only source/group identity, the frozen split and links between confirmed duplicate attempts. Removing 130 duplicate records leaves 4,160 labelled attempts (3,312 development, 848 held out) and 685 unlabelled intervals. The report also scores the original rows with duplicates included. Four multi-cause records use their primary label. The user confirmed that `Q00011226__001` was invalid. Its more specific knee label is the reviewer's proposal.

The group split keeps the same source video, known participant or source group on one side. Development contains 1,170 originals in 304 groups. The held-out set contains 294 originals in 83 groups. Some internet participants have no independent identity verification. The form labels were proposed after reviewing sampled frames. Agreement with these labels measures this corpus and does not certify form on a live phone.

## From recordings to decisions

The Android evaluator runs the same accurate, streaming ML Kit pose detector used by the app, with a new detector for each original. The video path feeds upright JPEG frames; a phone supplies camera frames in NV21. A separate replay of the existing MediaPipe Full cache provides a detector comparison. The detector gets the original field of view, with the same sampled source frames and times for each candidate. A missing frame of pose observations is preserved. No video, clip boundary, time of a labelled repetition, filename, dataset name or known verdict enters the live classifier.

The Dart replay starts one judge per original and keeps its state across frames. Each verdict has a source frame index. The scorer pairs verdicts and reference intervals in time order, one to one, without seeing either class. It maximizes the number of pairs, then prefers the event nearest the end of the annotated interval where return to lockout is expected. It allows a fixed 200 ms after the end for filtering. A missing verdict is a false negative. An extra event is a false positive. An event paired to an unresolved reference is recorded separately. Some unmatched events outside all annotated windows may be real movements.

Selection uses development macro F1 for classes with positive support. Ties use micro F1 and then rule simplicity. A candidate cannot introduce newly counted critical faults or extra false counts in the frozen phone suite. A changed historical sequence must improve agreement with its recorded expectation. Shallow decision trees using evidence from an attempted repetition or from the preceding 650 and 1,650 milliseconds compete with the fixed rules. Four synthetic regressions check occluded shoulders and arms on descent, hidden arms on return, arms staying straight and a wrist raised above its shoulder at setup. An ordinary-depth control must still count. Each development source gets a prediction from a tree trained on other groups. A fitted tree can refine a rejected partial repetition when the corresponding body signal was observed. A leaf that would rewrite an existing frozen phone verdict abstains. The final trained tree for held-out use sees development data only.

## Reproducing the evaluation

Run from the S1 checkout with Python (NumPy, OpenCV and scikit-learn), Dart on PATH, the external corpus and the dedicated Android evaluation AVD. The corpus, extracted landmark streams, emulator state and per-attempt outputs stay outside Git. The candidate runner reconstructs the research algorithms in a temporary directory from commit `d866b456a2bb0b9df863c811e2e7402da2ad01db`.

1. Run `python tools/diagnose/prepare_pushup_nine_replay.py COLLECTION OUTPUT` to verify the source and recut hashes and recreate the continuous streams and unit manifest.
2. Use `capture_pushup_nine_mlkit.py --help` for the checkpointed native capture. Use the same evaluator and frame index for both splits.
3. Run `python tools/diagnose/benchmark_pushup_nine.py compare OUTPUT NEW_RESULTS` once both native capture folders are verified. It replays each candidate, trains the group-separated trees, runs the phone and synthetic regression checks, and writes the development-only ranking and SHA-256 input hashes in `selection.json`.
4. After setting the app default, run `python tools/diagnose/benchmark_pushup_nine.py verify OUTPUT NEW_RESULTS` to compare the shipped judge to the refitted winner. The verification checks every source event frame and reason and writes `scores.json` and `selected-events.csv`. Development results in the ranking use out-of-fold predictions. The all-data results use the final fitted judge and include the training groups.
5. Run `python -B -m unittest discover -s tools/diagnose -p test_score_pushup_nine.py` for controlled examples of matching, group separation and regression gating.

The first frozen patch reproduces the original 49 presets. A second patch adds five guarded elevated-view presets. Run `python tools/diagnose/run_pushup_nine.py --probe NEW_REPORT.json` to replay the same seven controlled streams against every preset. Add `--shipping` to run the app default instead. The four negative streams contain a missing bottom, a missing return, straight arms throughout, and one raised wrist during setup. A candidate must add no count on these streams and count exactly once on both ordinary full-depth controls. A separate visible elevated control shows whether it can recognize a properly observed shorter movement. Synthetic observations are reported separately from the recorded videos.

The local result directory also contains `all-recut-rows.csv` for inspecting individual clips. It lists the 4,975 revised clip IDs, their expected and predicted verdicts, duplicate references and separate rows for unmatched predictions.
