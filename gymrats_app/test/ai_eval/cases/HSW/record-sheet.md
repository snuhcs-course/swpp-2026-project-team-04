# Record sheet: HSW

Device: SM-S901N (Galaxy S22); height: 179 cm; arm length: 64 cm; shoulder width: 50 cm, as entered in the recording app. Date: 2026-11-01.
Recorder build: `fix/pushup_judge_accuracy` at `15c5fe8`; ML Kit `accurate`, lighting `bright`, 30-second rounds.

The participant confirmed that all sets were performed as instructed, five repetitions each. For set 4, that means four partial extensions followed by one full extension. Labels represent the participant-reported intended motion, not the application's result. Each JSON's `label.perRep` was added after recording; set 4's `label.expected` was also filled in from the participant's confirmation. The camera-derived frames, sensor samples and live verdicts were not changed.

**Protocol deviation for PM review:** These sets used 5 reps and 30-second rounds according to the team chat, whereas the frozen plan specifies 10 reps and 60 seconds. Phone placement values are targets entered in the app, not confirmed measurements. The tilt column below is the median from all recorded frames, not an independently measured placement angle. The PM should decide how to use these recordings and confirm the final labels.

| Set | Target position | File | Reps reported | Median sensor tilt | App result |
|---|---|---|---:|---:|---|
| 1 | A | `20261101-204311_SM-S901N_normal.json` | 5 | 81.2° | counted 5 |
| 2 | A | `20261101-204453_SM-S901N_knees.json` | 5 | 69.7° | kneesDown 5 |
| 3 | B | `20261101-204924_SM-S901N_halfRepHeadNod.json` | 5 | 82.6° | insufficientDepth 5 |
| 4 | B | `20261101-205247_SM-S901N_unlabelled.json` | 5 | 83.0° | incompleteExtension 3, kneesDown 2 |
| 5 | C | `20261101-205441_SM-S901N_knees.json` | 5 | 66.8° | kneesDown 3, counted 1, insufficientDepth 1 |
| 6 | C | `20261101-205709_SM-S901N_bellyDown.json` | 5 | 68.8° | counted 4, kneesDown 1 |
| 7 | D | `20261101-205901_SM-S901N_normal.json` | 5 | 77.7° | insufficientDepth 1, counted 4 |
| 8 | D | `20261101-210056_SM-S901N_armsStraight.json` | 5 | 76.5° | kneesDown 5 |

Targets: A = 50 cm, 60–65°; B = 50 cm, 75–80°; C = 100 cm, 60–65°; D = 100 cm, 75–80°. Distance and angle targets were not confirmed as measured values.

Set 4 was recorded as `unlabelled` because the app has no dedicated mixed partial-extension option; its expected sequence was added from the participant's confirmation. Set 8 was reported as kneeling with arms straight and hips back; the app reported `kneesDown` rather than the planned `armsStraight` for all five. These discrepancies are not reasons to change the participant-reported labels.
