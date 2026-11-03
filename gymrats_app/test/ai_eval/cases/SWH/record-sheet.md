# Record sheet: SWH
Phone: Galaxy S947N · Height: 175.6 cm (left empty in the app, so `heightCm` is null in the files) · Shoulder width: 45 cm · Date: 2026-10-30, 2026-10-31, 2026-11-02

Recorder builds: sets 2, 3, 5, 6, 8 with `fix/pushup_judge_accuracy` `cff4b68` (shoulder line 0.70); set 1 with `15c5fe8` (0.68); sets 4 and 7 with `feat/bot_difficulty` `2962f7b` (its push-up judge, recorder and pose code are the same as `main` `5e0be5e`, shoulder line 0.68; only `bot_opponent.dart` differs).
Distance and angle were not measured with a tape or the tilt reading: positions were set by eye (A/B about 50 cm, C/D about 100 cm; A/C lower angle, B/D higher angle). For sets 4 and 7 the median tilt in the file is 81.9° and 80.9°, a little above the 75–80° target.

| # | Pos | Expected | File | Time | Distance | Angle | Reps done | Result screen (counted / rejected per message) | Reps that differed from the plan |
|---|---|---|---|---|---|---|---|---|---|
| 1 | A | +1 | 20261031-211941_S947N_normal.json | 2026-10-31 21:19 | about 50 cm | not measured (lower) | 5 (Reps set to 5) | 3 counted / Go lower 2 (reps 1, 5) | none: all 5 were normal push-ups. Reps 1 and 5 went to about 90° elbows, like counted rep 4 |
| 2 | A | Knees up | 20261030-214001_S947N_knees.json | 2026-10-30 21:40 | about 50 cm | not measured (lower) | 10 | 0 counted / Knees up 10 | none. The Note was typed wrong while recording; fixed in `label.note` |
| 3 | B | Go lower | 20261030-215315_S947N_halfRepHeadNod.json | 2026-10-30 21:53 | about 50 cm | not measured (higher) | 10 | 0 counted / Go lower 10 | none |
| 4 | B | Lock out your arms × 9, then +1 | 20261102-010449_S947N_unlabelled.json | 2026-11-02 01:04 | about 50 cm | 81.9° (median tilt in the file) | 10 | 0 counted / Go lower 7, Knees up 2 (9 verdicts for 10 reps) | Done in blocks of 4, 2, 2 and 2 reps, resting with the knees on the floor between blocks. Reps 1–9 stopped short of lockout (aimed at about 140°); rep 10 locked out. Recorded as `Free (no label)`; `label.expected` and `label.perRep` set by hand |
| 5 | C | Knees up | 20261030-220435_S947N_knees.json | 2026-10-30 22:04 | about 100 cm | not measured (lower) | 9 (Reps set to 10, the round ran out) | 0 counted / Knees up 8, Go lower 1 | label fixed to 9 reps. Which rep showed Go lower was not seen. A first take at 21:57 was discarded (depth not consistent) |
| 6 | C | Hips up | 20261030-220901_S947N_bellyDown.json | 2026-10-30 22:09 | about 100 cm | not measured (lower) | 10 | 0 counted / Hips up 10 | none |
| 7 | D | +1 | 20261102-010750_S947N_normal.json | 2026-11-02 01:07 | about 100 cm | 80.9° (median tilt in the file) | 10 | 0 counted / Knees up 7, Go lower 1 (8 verdicts for 10 reps) | Reps 1–3 were normal push-ups with the knees clearly off the floor (the tester is sure of this), and the tester saw Knees up on screen for each of them. Rep 4 was shallow (tired), so it is labelled `insufficientDepth`; the other 9 were normal push-ups. Once during the set the tester rested with the knees on the floor (when exactly was not noted) |
| 8 | D | Bend your arms | 20261030-221617_S947N_armsStraight.json | 2026-10-30 22:16 | about 100 cm | not measured (higher) | 10 | 0 counted / Go lower 9, Knees up 1 | none: knees down, arms straight every rep |

## Notes (the tester's opinion, not the team's criteria)
- When the knees are down and the rep is also shallow, Go lower shows instead of Knees up (set 5, set 8). Knees on the floor is the bigger error, so Knees up should come first.
- Set 8 is a kneeling bow, so Knees up on every rep would also be a sensible result.
- Set 1: in the files, reps 1, 4 and 5 all reached about 90° elbows and a head depth of 1.44 to 1.60, above the 1.1 bottom depth. Only rep 4 counted, so the 0.68 shoulder line seems to sit right at a 90° push-up.

## Observations from the files (live results of sets 4 and 7)
- Set 7 (D): Knees up came 7 times, while the knees touched the floor once (a rest). Reps 1–3 closed as Knees up although the knees were clearly off the floor: the tester is sure of this and saw Knees up on screen for each rep at the time. In the live results these three reps had a head depth of 1.44–1.55 and elbows at 60–71°, deeper than the 1.1 bottom depth.
- Set 4 (B): no rep closed as Lock out your arms. The 7 Go lower verdicts had a head depth of 1.07–1.43 and elbows at 68–94°. The first Knees up (at about 4 s) came before the first rest. Judging by the elbow angle in the frames, the last rep (locked out) closed as Go lower at about 51.5 s (depth 1.43, elbows 81°), and rep 9 has no verdict of its own.
