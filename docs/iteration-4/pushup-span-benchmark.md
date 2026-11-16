# Push-up recognition from screen coordinates and phone inclination

The two primary outcomes are the proportion of normal repetitions awarded a point and the proportion of faulty repetitions receiving an explicit rejection. Both use all labelled repetitions of that kind as their denominator. Their arithmetic mean is the balanced accuracy. A rep without any verdict is a miss in either class. A fault that does not earn a point is a separate gameplay statistic, since it can include a missing verdict. An extra verdict is also reported separately. A wrong explanation still counts as a correct binary rejection.

## Data and split

The same Android ML Kit accurate-stream replay covers 133,327 sampled frames across 1,464 originals. Original recordings sharing a source group stay together. Development contains 1,170 originals from 304 groups and 3,312 unique labelled attempts. The previous held-out split contains 294 originals from 83 groups, including 378 labelled normal and 470 labelled faulty attempts. The corrected cut intervals are used. Confirmed duplicate attempts and unlabelled examples are excluded from recognition-rate denominators. Their source frames still pass through the continuous judge. The comparison uses the existing, previously inspected test set and previously assigned visual labels. Independent human adjudication was outside this experiment.

No camera angle or IMU stream was available for the 1,464 web originals. Measured phone inclination is evaluated separately on 44 team recordings. A gyro alone measures rotation rate. GymRats gets the placement angle from gravity, with 0° flat and 90° upright. The classifier uses bands around 60° and 80°. An initial 70° split with a 68–72° deadband avoids switching on ordinary sensor noise. A missing, stale or disturbed reading uses the image-only path.

## The app calculation

The judge tracks both arms using the projected vertical shoulder-to-wrist gap and their two-dimensional straight-line reach. It divides movement by observed arm length, checks a downward excursion and a return, and measures relative shoulder, elbow, hip, knee and ankle positions over the attempt. At the more inclined 60° placement, more weight goes to two-dimensional reach. Vertical span features used to judge form also receive a modest projection correction. The two bands are approximations rather than a 3D reconstruction.

Both AI and online push-up battles use the same judge. A weakly observed joint cannot supply positive evidence for a correction. The original head and chest paths get precedence when their attempt is open so one movement receives one verdict. The prototype only uses pose coordinates in memory on the device.

A separate binary calibration can reconsider a soft primary verdict. It can award a rep only after both arms were seen extended, then bent together while both shoulders descended relative to the wrists, then extended again in the actual return frame. The bottom must belong to the currently open repetition. A previous completed repetition cannot validate a later head bob. It protects direct knee, belly, upright, straight-arm and phone-motion faults. It preserves the original event time, index and score-related measurements.

## Neural network comparison

Each MLP receives 13 visible body landmarks and 18 joint-to-joint spans in the upright image. The feature vector preserves horizontal and vertical movement relative to the same window reference and scale. Six chronological bins, movement ranges and landmark visibility describe each attempt. Scaling and neural weights are fitted on development groups alone. Two ReLU hidden-layer configurations (32/16 and 64/32), optional class reweighting and three epoch counts were ranked using five grouped validation folds. Binary balanced accuracy determines selection and reason-level F1 breaks ties. The binary target trains directly on normal versus faulty. The reason target trains on the observed exercise labels and collapses its prediction to normal versus faulty during binary scoring.

For the pre-cut experiment the input is the annotated start and end of a single repetition. This estimates the classifier's performance with supplied boundaries. For the continuous comparison the event finder runs from the start of each original without seeing any labels or cut boundaries. At each actual emitted event the MLP sees up to 1.6 seconds of preceding frames since the previous event. Events are matched in time, at most once, with the same 200 ms allowance as the earlier nine-class benchmark. Diagnostic MLPs are trained separately for each distinct proposal stream. Unmatched events are included in the extra-verdict count.

The labels contain no positive web examples for belly on the floor, wall/upright push-ups, or phone movement. The eight held-out straight-arm examples are insufficient for a precise reason-level estimate. The web binary results therefore describe the mix of faults actually present.

## Held-out results

All rows use the same 378 normal and 470 faulty attempts. Extra points count normal events that could not be matched to any reference. The two rows with supplied boundaries bypass event detection, so they have no extra-event measurement.

| Method | Normal recognized | Fault explicitly rejected | Balanced accuracy | Missed attempts | Extra points |
|---|---:|---:|---:|---:|---:|
| Original depth rules | 98/378 (25.9%) | 68/470 (14.5%) | 20.2% | 568 | 2 |
| Previous nine-class judge | 106/378 (28.0%) | 168/470 (35.7%) | 31.9% | 419 | 3 |
| Relative spans, before binary calibration | 106/378 (28.0%) | 189/470 (40.2%) | 34.1% | 391 | 3 |
| GymRats default with binary calibration | 108/378 (28.6%) | 188/470 (40.0%) | 34.3% | 391 | 3 |
| App event times, binary MLP | 213/378 (56.3%) | 160/470 (34.0%) | 45.2% | 391 | 11 |
| App event times, reason-trained MLP | 203/378 (53.7%) | 162/470 (34.5%) | 44.1% | 391 | 10 |
| Wide motion proposals, binary MLP | 299/378 (79.1%) | 271/470 (57.7%) | 68.4% | 113 | 50 |
| Wide motion proposals, reason-trained MLP | 310/378 (82.0%) | 252/470 (53.6%) | 67.8% | 113 | 57 |
| Supplied boundaries, binary MLP | 287/378 (75.9%) | 377/470 (80.2%) | 78.1% | 0 by design | — |
| Supplied boundaries, reason-trained MLP | 325/378 (86.0%) | 360/470 (76.6%) | 81.3% | 0 by design | — |

The wide proposal finder combines normal judge events with cycles detected from arm span and from elbow flexion or shoulder height. It uses only frames already received. The minimum spacing and movement thresholds were fixed on development footage. It matched 735 of the 848 test attempts and produced 86 unmatched events. The binary MLP gave 126 of the 470 faults a point, correctly rejected 271 and missed 73. The selected app gave 19 of those faults a point, rejected 188 and missed 263. It also missed 128 normal attempts and rejected 142. Its reason-level macro F1 was 20.88% on the six represented labels (previously 19.08%). It matched the exact reason and time for 207/848 attempts (previously 192).

The app's compact calibrated model was chosen on development folds subject to the phone regression cases. The wide-proposal binary MLP maximized the average of the two recognition rates on continuous web video. The saved MLP is an offline hypothesis for the video corpus. It failed the phone regression criterion for previously rejected critical faults and is excluded from the battle scoring path.

## Recorded phone performance

All 44 native phone recordings retain the previous verdict sequences with the final app. The 32 frozen recordings with the course evaluation labels have 63 normal and 207 faulty reps. The app counted 50 normal (79.4%) and explicitly rejected 187 faulty (90.3%). It missed three normal attempts and one faulty attempt. The angle checks feed true frame-by-frame sensor readings and also replay the very same poses with no tilt input.

| Median measured phone angle | Normal recognized | Fault explicitly rejected |
|---|---:|---:|
| Near 60° | 14/16 (87.5%) | 77/84 (91.7%) |
| Near 80° | 36/47 (76.6%) | 110/123 (89.4%) |

Providing the measured angle changed no final verdict in these recordings. These are existing regression controls, not an estimate of angle correction on new people or devices. On the larger subset of 36 recordings with per-repetition labels (314 repetitions including four additional historical recordings), the wide binary MLP newly awarded 70 previously protected faults: 18 incomplete lockouts, 38 knee-supported reps and 14 belly-down reps. It awarded 62 unmatched extra points where the app awarded none. The wide reason-trained MLP newly accepted 53 critical faults and awarded 65 extra points on the same subset. These recordings have ordered reference labels without individual time stamps, so their comparisons use the project’s sequence alignment.

## Reproduction

Run from this worktree with Dart on PATH, Python, NumPy, scikit-learn and the recorded native pose replay. The directory `C:/SWPP/iter4/pushup-nine-benchmark` contains `native-all/replay.jsonl`, `native-all/units.jsonl`, and the previous release replay at `native-final/shipping.jsonl`. The web videos are not needed after the source hashes and native keypoints have been verified.

1. Run `python -B tools/diagnose/run_pushup_nine.py --shipping REPLAY NEW_EVENTS.jsonl` for the actual Dart default. Use `--fixtures` instead of the replay path for the phone controls. The angle-specific fixture tool also passes the recorded gravity-derived degrees.
2. Run `python -B tools/diagnose/score_pushup_span.py UNITS REPORT.json previous=OLD_EVENTS span=NEW_EVENTS`. This aggregates binary counts from the time-matched nine-way confusion matrix and exports one row per reference or extra verdict for each split.
3. Run `python -B tools/diagnose/pushup_span_mlp.py REPLAY UNITS NEW_EVENTS OUTPUT --mode cuts --target binary`. Repeat with `--target reasons`, then run both with `--mode stream`. Use `--phone FIXTURE_POSES FIXTURE_EVENTS` to check the two stream classifiers on real phone recordings. CSVs keep the reference, prediction, source group and frame for each test decision. Each run refits its scaler and classifier; the test labels never select a model epoch or parameter.
4. Run `python -B -m unittest discover -s tools/diagnose -p test_pushup_binary_metrics.py` to check binary miss handling, extras and feature extraction on an empty pose.
5. `tools/diagnose/pushup_wide_proposals.py` generates and freezes the broader proposal stream. To run the saved binary MLP without labels or training, use `python -B tools/diagnose/infer_pushup_mlp.py MODEL.npz REPLAY.jsonl PROPOSALS.jsonl OUTPUT.jsonl`. The model specification and inference inputs are in the local `span-wide-mlp` result directory. Exported probabilities and predictions matched the fit on all 858 proposals from the 294 held-out originals.

The complete comparison of recognition rates, errors and extra points is in `C:/SWPP/iter4/pushup-nine-benchmark/span-pitch/method-comparison.csv`. Per-clip results for the shipped default are in `final-comparison-app-holdout.csv` in the same directory. The exportable model and its known phone failure cases are in `C:/SWPP/iter4/pushup-nine-benchmark/span-wide-mlp/binary-model.npz` and `binary-model.json`.
