# P18 · Push-up and squat battle judging

Evaluated on November 28, 2026 against [main at d10d0dc](https://github.com/snuhcs-course/swpp-2026-project-team-04/commit/d10d0dcef2b383e5cc16d201c0de3010c6d91f9c). The 48 recordings contain 350 human-labelled repetitions. On the November 18 recordings, all ten knee push-ups earned zero, six of ten incomplete-extension push-ups counted, and only eleven of twenty in-range squats counted. The frozen push-up set missed all three historical accuracy targets. The PR adds evaluation evidence and a replay test.

## Counts, reasons and points

| Recordings | Correct motion counted (M1) | Incorrect motion uncounted (M2) | Exact rejection reason (M3) | Incorrect with no event | Extra valid / rejected events | Count expected → replay | Base points expected → replay |
|---|---:|---:|---:|---:|---:|---:|---:|
| Nov 18 push-ups · 8 clips / 40 reps | 9/10 (90.0%) | 21/30 (70.0%) | 11/30 (36.7%) | 0 | 0 / 6 | 10 → 18 | 100–150 → 220 |
| Nov 18 squats · 8 clips / 40 reps | 11/20 (55.0%) | 20/20 (100%) | 10/20 (50.0%) | 7 | 0 / 0 | 20 → 11 | 200–300 → 135 |
| Frozen push-ups · 32 clips / 270 reps | 52/63 (82.5%) | 158/207 (76.3%) | 88/207 (42.5%) | 0 | 6 / 130 | 63 → 107 | 630–1,125 → 1,385 |

The [frozen protocol](../../gymrats_app/test/ai_eval/README.md) specifies ≥90%, ≥90% and ≥80% for M1–M3 over its 32 clips. The November 18 sets are descriptive. The labels specify an ordered verdict per repetition without event times. We align each clip separately using minimum edits, keeping extra events out of the denominators. An incorrect motion without a matching event contributes to M2 alone. The actual count and points include all emitted events, including extras. A score inside a reference range can still contain an incorrect verdict.

- **Push-ups.** In both knee-only clips the judge returned five knee rejections and zero points. In the two normal clips it also emitted three knee rejections alongside nine valid reps. Across the two belly-down clips it counted three reps, awarded 45 base points and emitted no belly-down reason. One incomplete-extension clip earned 55 points for five false counts.
- **Squats.** All twenty shallow or incompletely extended squats went uncounted, but seven produced no feedback event and three gave the wrong reason. The two normal clips counted one and five reps. The chair clips counted zero and five. The confirmed chair policy judges depth and full standing, so all ten chair reps here should count.
- **Model evidence.** The current battle path enables the binary validity MLP (64/32), knee specialist (32/16), frame-level knee evidence and the battle depth gate. Other faults still use geometric rules. The [earlier comparison](../iteration-4/pushup-mlp-combined-evaluation.md) measured the trade-off between catching knee push-ups and rejecting normal reps. This run measures the deployed-in-code defaults only. The model and thresholds were previously developed or inspected on related data. The results describe these recordings, with no new training, unseen-person estimate or live camera validation.

## Reproduce

From `gymrats_app/` with Flutter 3.47.5 and Dart 3.13.4:

```sh
flutter pub get
flutter test --reporter expanded --dart-define=P18_REPORT=true test/services/pose/iter5_pose_evaluation_test.dart
```

The [runner](../../gymrats_app/test/services/pose/iter5_pose_evaluation_test.dart) writes `build/p18/evaluation.json` with each human sequence, emitted event time, reason, grade and base points. The test checks scoring boundaries and the explicit knee verdicts on the two confirmed knee clips. Other measured accuracy differences are reported above. The November recordings run via `judgeFor` using recorded frame times and their evaluation windows. No phone IMU is recorded for those clips. The older push-up recordings use `RepJudge.forBattle` and replay recorded tilt, phone-movement flags and abandonment. The [November 18 record sheets](../../gymrats_app/test/ai_eval/cases_iter4) and [frozen human labels](../../gymrats_app/test/ai_eval/cases) supply the expected verdicts. No camera, new video or network service is needed.

**Score comparison.** For base points, each event is scored as the first rep at time zero through `BattleGame.addMyRep`. A labelled valid rep can be Good (10) or Excellent (15), and insufficient depth can earn 0 or 5 because the human sheets omit exact depth and elbow angle. A knee push-up earns 0 even with the Average grade. Other rejections earn 0. The solo-round column separately applies recorded times from clip start to a single 30-second battle against a zero-point opponent, with normal combo, fever and KO. The recordings contain no matched opponent or human-labelled round clock, so there is no reference match total for that column.

The separate scorer test checks Good +10, Excellent on a 1.5-second combo +20, shallow push-up at 120° +5, at 121° or missing angle +0, fever shallow +10, knee Average +0 both before and during fever, and squat rejections +0. Every case checks the point delta and cumulative valid-rep count.

## Recording detail

Verdicts appear in event order. **V** valid, **K** kneesDown, **E** incompleteExtension, **B** bellyDown, **D** insufficientDepth, **A** armsStraight, **S** shallowSquat, **U** standUpFully. **∅** means that the judge emitted nothing in the labelled window.

### November 18 recordings

| Recording ID / scenario | Human labels | Emitted verdicts | Count expected → replay | Base points expected → replay | Solo round reps / points |
|---|---|---|---:|---:|---:|
| `20261118140716241591_normal_gymrats` · normal | V×5 | K V×4 K | 5 → 4 | 50–75 → 40 | 4 / 55 |
| `20261118140732357228_knees_gymrats` · kneesDown | K×5 | K×5 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261118140748211269_bent_arms_gymrats` · incompleteExtension | E×5 | V×5 | 0 → 5 | 0 → 55 | 5 / 75 |
| `20261118140806566477_belly_gymrats` · bellyDown | B×5 | K×8 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261118140831130646_squat_normal_gymrats` · normal | V×5 | V S×3 | 5 → 1 | 50–75 → 10 | 1 / 10 |
| `20261118140847280825_squat_shallow_gymrats` · shallowSquat | S×5 | ∅ | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261118140901505813_squat_not_standing_gymrats` · standUpFully | U×5 | S×3 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261118140919140749_squat_chair_gymrats` · chair | V×5 | S | 5 → 0 | 50–75 → 0 | 0 / 0 |
| `20261118153146739950_normal_gymrats` · normal | V×5 | V×5 K | 5 → 5 | 50–75 → 70 | 5 / 90 |
| `20261118153203817106_knees_gymrats` · kneesDown | K×5 | K×5 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261118153221618003_bent_arms_gymrats` · incompleteExtension | E×5 | V D×2 K×2 E | 0 → 1 | 0 → 10 | 1 / 10 |
| `20261118153251158085_belly_gymrats` · bellyDown | B×5 | V×3 K×2 | 0 → 3 | 0 → 45 | 3 / 45 |
| `20261118153318437596_squat_normal_gymrats` · normal | V×5 | V×5 | 5 → 5 | 50–75 → 75 | 5 / 75 |
| `20261118153357549759_squat_shallow_gymrats` · shallowSquat | S×5 | S×5 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261118153419912431_squat_not_standing_gymrats` · standUpFully | U×5 | U×5 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261118153457145385_squat_chair_gymrats` · chair | V×5 | V×5 | 5 → 5 | 50–75 → 50 | 5 / 50 |

### Frozen push-up recordings

| Recording ID / scenario | Human labels | Emitted verdicts | Count expected → replay | Base points expected → replay | Solo round reps / points |
|---|---|---|---:|---:|---:|
| `20261031-220208_s26-fe_normal` · normalA | V×10 | V×10 D | 10 → 10 | 100–150 → 150 | 7 / 105 |
| `20261031-220257_s26-fe_normal` · kneelingBow | K×10 | K×17 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261031-220505_s26-fe_normal` · halfRepHeadNod | D×10 | V×8 K×2 | 0 → 8 | 0–50 → 115 | 7 / 100 |
| `20261031-220617_s26-fe_normal` · noLockout | E×10 V | V K×2 V×3 K×2 A V K V K | 1 → 6 | 10–15 → 80 | 6 / 105 |
| `20261031-220713_s26-fe_normal` · kneePushUp | K×10 | K×10 D K | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261031-220830_s26-fe_normal` · bellyDown | B×10 | K×15 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261031-220917_s26-fe_normal` · normalD | V×5 | V×5 D K | 5 → 5 | 50–75 → 75 | 5 / 75 |
| `20261031-220955_s26-fe_normal` · kneelingStraightArms | A×10 | K×13 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261101-204311_SM-S901N_normal` · normalA | V×5 | K×2 V×3 D | 5 → 3 | 50–75 → 40 | 3 / 40 |
| `20261101-204453_SM-S901N_knees` · kneelingBow | K×5 | K×6 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261101-204924_SM-S901N_halfRepHeadNod` · halfRepHeadNod | D×5 | V×3 D V | 0 → 4 | 0–25 → 45 | 4 / 55 |
| `20261101-205247_SM-S901N_unlabelled` · noLockout | E×4 V | V K×2 D K D | 1 → 1 | 10–15 → 25 | 1 / 25 |
| `20261101-205441_SM-S901N_knees` · kneePushUp | K×5 | K×6 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261101-205709_SM-S901N_bellyDown` · bellyDown | B×5 | K×2 V×2 K×3 | 0 → 2 | 0 → 25 | 2 / 25 |
| `20261101-205901_SM-S901N_normal` · normalD | V×5 | K×2 V×3 K | 5 → 3 | 50–75 → 45 | 3 / 50 |
| `20261101-210056_SM-S901N_armsStraight` · kneelingStraightArms | A×5 | K×13 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261031-232452_S23-Ultra_normal` · kneelingBow | K×10 | K×24 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261031-233250_S23-Ultra_normal` · halfRepHeadNod | D×10 | D×11 K D×3 | 0 → 0 | 0–50 → 15 | 0 / 15 |
| `20261031-233831_S23-Ultra_normal` · noLockout | E×9 V | D E D×2 V E D E D E K V K V K×2 D K V K | 1 → 4 | 10–15 → 65 | 3 / 75 |
| `20261031-234831_S23-Ultra_normal` · kneePushUp | K×10 | K×12 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261031-235349_S23-Ultra_normal` · bellyDown | B×10 | V×5 D V×6 | 0 → 11 | 0 → 110 | 6 / 70 |
| `20261101-002312_S23-Ultra_normal` · kneelingStraightArms | A×10 | K V K V D K×3 V K×5 | 0 → 3 | 0 → 30 | 2 / 20 |
| `20261101-003018_S23-Ultra_normal` · normalD | V×10 | K V K×2 V D×2 V×4 D K V×3 K×2 | 10 → 9 | 100–150 → 95 | 6 / 85 |
| `20261101-003825_S23-Ultra_normal` · normalA | V×10 | V×3 D K V×2 D K V×2 D V D K×5 | 10 → 8 | 100–150 → 85 | 6 / 80 |
| `20261030-214001_S947N_knees` · kneelingBow | K×10 | K×14 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261030-215315_S947N_halfRepHeadNod` · halfRepHeadNod | D×10 | V×4 K V×5 | 0 → 9 | 0–50 → 105 | 7 / 105 |
| `20261030-220435_S947N_knees` · kneePushUp | K×9 | K×18 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261030-220901_S947N_bellyDown` · bellyDown | B×10 | D V B K×2 V D V×5 K×4 | 0 → 7 | 0 → 115 | 5 / 100 |
| `20261030-221617_S947N_armsStraight` · kneelingStraightArms | A×10 | D K×12 | 0 → 0 | 0 → 0 | 0 / 0 |
| `20261031-211941_S947N_normal` · normalA | V×5 | V×5 D K | 5 → 5 | 50–75 → 60 | 5 / 60 |
| `20261102-010449_S947N_unlabelled` · noLockout | E×9 V | V E D E K E D K×9 V K×4 | 1 → 2 | 10–15 → 35 | 1 / 25 |
| `20261102-010750_S947N_normal` · normalD | V×3 D V×6 | V×4 K×6 V K×2 B K V×2 K×3 | 9 → 7 | 90–140 → 70 | 4 / 40 |
