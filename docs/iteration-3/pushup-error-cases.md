# Push-up judge error cases (Iteration 3, P9)

Owner: Hyunwoo Song (`hyun-1210`) | Status: two recording sessions done (2026-10-26: 4 sets, 23 reps; 2026-10-27: 7 sets, 52 reps)

Where the push-up judge (`gymrats_app/lib/services/pose/rep_judge.dart`) is wrong, measured on recorded sets.
Every case is a replayable fixture in `gymrats_app/test/fixtures/pushup_cases/` (format in that folder's
README). `test/services/pose/pushup_error_cases_test.dart` replays them; cases the judge gets wrong today are
named skips (`knownErrors`) until the judge fix (P14, `fix/pushup_judge_accuracy`) turns them on.

## Method
- **Recorder:** `lib/demo/rep_judge_demo.dart`. Every frame the judge sees is saved with its 33 landmarks
  (x, y, z, likelihood), the phone tilt and gyro, and the live verdicts. No camera images.
- **Labels:** the person doing the set picks what it shows and how many reps, before the set. Mixed sets get
  their expected result fixed by hand, with a note.
- **Error types:**
  - *false count*: more reps counted than labelled (a cheat or a bad rep counted).
  - *missed rep*: fewer reps counted than labelled (a good rep not counted, or a cheat set with a rep dropped).
  - *wrong reason*: the count is right, but a rep is rejected with another reason than labelled.
- **Command:** from `gymrats_app/`, `flutter test test/services/pose/pushup_error_cases_test.dart`.

## Experiment plan
Each set is about 10 reps. Vary one thing at a time from a baseline setup.

| Axis | Values |
|---|---|
| Set kind | normal (slow, normal, fast tempo; elbows tucked and flared), knees on the floor (from the start, partway through), half rep + head nod, belly on the floor, straight arms with the head dipping |
| Phone placement | baseline floor placement; nearer, farther, higher; phone angle within the setup range |
| Lighting | bright, dim, backlit |
| People | at least two people of different height and arm length |
| Devices | Galaxy S22, Galaxy S23, the PM's phone (not recorded in H1, see Limitations) |
| ML Kit model | base (shipped), accurate (for comparison) |

Suspected causes to confirm or rule out, from reading the judge (2026-10-25):
- The top baseline follows the nose while the elbows still read straight from the front, so slow or
  tucked-elbow descents lose depth.
- A noisy elbow angle at the top blocks the lockout and turns a good rep into `incompleteExtension`.
- Depth comes from the nose only, so a half rep with a head nod can count; the shoulder drop is not checked.
- The knee checks depend on hip and knee landmarks that are usually hidden from the front; ML Kit's likelihood
  is "in frame", so hidden joints may still pass the 0.6 filter.
- The knee latch turns on below 155° but only clears at 160°, so a plank that reads 155–160° can stay latched.

## Cases
Session 1 (2026-10-26): one person (183 cm), Galaxy SM-S741N, front camera, phone on the floor at 68–73° from flat
(roll under 1°), bright room (mean luma 149–162), recorder built from `62f6a9d` + the H1 working tree. Replay equals
the live verdicts on all 23 reps.

| Case id | Model, fps (median) | Labelled | Live = replay (per rep) | Error type | Cause (from the rule trace) |
|---|---|---|---|---|---|
| `20261026-000317_normal` | accurate, 23 | 4 valid, rep 5 belly down | KD, OK, OK, KD, KD | missed rep (reps 1, 4), wrong reason (rep 5) | reps 1, 4: hip angle < 110° for 3 frames at the bottom; rep 5: top-of-rep hip 148° ≤ baseline 170° − 20°, so `kneesDown` before the belly check (hips never reached the belly band, min hip–hand gap −0.37) |
| `20261026-000418_normal` | base, 27 | 6 valid | KD × 6 | missed rep (6 of 6) | the base model reads the plank hip at 127–139° (accurate: 157–170°), so the top-of-rep latch fires on every rep |
| `20261026-000522_normal` | accurate, 25 | 7 valid | KD, KD, OK, KD, OK, OK, OK | missed rep (reps 1, 2, 4) | reps 1, 4: hip < 110° at the bottom; rep 2: one top frame at 141° ≤ 162° − 20° |
| `20261026-000615_knees` | accurate, 25 | 5 × kneesDown | KD × 5 | none (passes) | top-of-rep hip 123–141° against baseline 169° (4 reps); knee–hand gap in the knee band (2 reps) |

Session 2 (2026-10-27): same person and phone, accurate model only, bright room, one kind per set. Labels from
the user's account; the shoulder width in the image (median per rep) shows where the user moved away from the phone.

| Case id | fps (median) | Labelled | Live = replay (per rep) | Error type | Cause (from the rule trace) |
|---|---|---|---|---|---|
| `20261027-142000_halfRepHeadNod` | 24 | 5 × half rep + head nod | KD × 5 | wrong reason (5 of 5) | nose depth 1.53–1.80 passes the 1.1 bottom line on every rep; only the knee–hand gap rule rejects them |
| `20261027-142116_bellyDown` | 25 | 5 × belly down | depth, KD × 4 | wrong reason (5 of 5) | reps 2–5: top-of-rep hip 85–121° latches `kneesDown`; hip–hand gap peaked at −0.07 to +0.02, around the −0.05 belly line |
| `20261027-142240_knees` | 25 | reps 1–5 normal, 6–9 knees | KD, KD, OK, OK, OK, KD × 4 | missed rep (reps 1, 2) | reps 1, 2: hip < 110° at the bottom; reps 6–9 caught by the top-of-rep hip (133–143° vs baseline 165°) |
| `20261027-142341_normal` | 26 | 8 valid (reps 7, 8 farther) | KD, OK × 5, KD, KD | missed rep (reps 1, 7, 8) | hip < 110° at the bottom; shoulder width 0.41–0.44 → 0.28–0.30 of the image at reps 7, 8 |
| `20261027-142432_normal` | 25 | 5 valid, farther | KD × 4, depth | missed rep (5 of 5) | reps 1–4: hip < 110°; rep 5: depth 0.84 although the elbow reached 44° (cause not found yet) |
| `20261027-145535_knees` | 25 | 9 × knees, done like a deep kneeling bow (hips back, head down) | KD, arms, KD × 7 | wrong reason (rep 2) | rep 2 kept the elbows at 166°, so `armsStraight`; reps 1–4 read as a plank at the top (hip 165–168°, knees far behind the hands) and are caught only by hip < 110° at the bottom |
| `20261027-145620_knees` | 25 | 7 × knees, then 4 × straight arms on the knees | KD × 7, arms × 4 | none (passes) | reps 1–7: top-of-rep hip folded 86–110° below the baseline for 7–72 frames; reps 8–11: elbows 169–174° with the knee latch on |

KD = rejected as `kneesDown`; depth = `insufficientDepth`; arms = `armsStraight`.

## Summary by error type
| Error type | Cases | Frequency (session 1) | Setups |
|---|---|---|---|
| false count | 0 seen live, 3 latent (`20261027-142000_halfRepHeadNod`, `20261027-142116_bellyDown`, `20261027-145535_knees`) | 0 of 75 closed reps; with the knee rules off, 5 of 5 head-nod reps and 5 of 6 belly reps count; with the hip < 110° rule off, 4 of 9 kneeling-bow reps count | half rep + head nod, belly down, kneeling bow |
| missed rep | 6 | accurate: 15 of 29 normal reps (usual distance 8 of 22, farther 7 of 7); base: 6 of 6 | every setup |
| wrong reason | 4 | 6 of 6 belly-down reps (5 `kneesDown`, 1 `insufficientDepth`); 5 of 5 head-nod reps (`kneesDown`); 1 of 9 kneeling-bow reps (`armsStraight`) | accurate |

The latent false counts are kept as cases on purpose: the head-nod and belly reps are rejected only by knee rules, so a
knee fix alone would make the judge count them. The kneeling bow is caught only by the hip < 110° rule.

## Findings (session 1)
- **Hidden joints come with full likelihood.** Knee and hip likelihood had a median of 1.00 and the hip angle was
  available on 100 % of normal-set frames, although the hips and knees are behind the body from the front. So the
  judge's "a hidden part never rejects" never applies: the lower-body rules always run on ML Kit's guesses.
- **Which knee rule fired** (accurate sets, from a replay that mirrors the judge's knee state):

  | Rule | Knee set (5 reps) | Normal reps (11) |
  |---|---|---|
  | top-of-rep hip angle vs the personal baseline | caught 4 | wrongly rejected 1 (plus the belly rep) |
  | knee–hand gap in the knee band | caught 2 (one also by the rule above) | 0 |
  | hip angle < 110° for 3 frames, any phase (in practice the bottom) | 0 | wrongly rejected 4 |

- **Without the < 110° rule** (replay with `kneeBentAngle: 0`, no other change): wrongly rejected normal reps on
  accurate 5 of 11 → 1 of 11, the knee set still 5 of 5, the belly rep still `kneesDown`. Base is unchanged (6 of 6),
  because its errors come from the top-of-rep angle.
- **Model:** accurate ran at 23–25 fps against 27 for base, and its plank hip angle (157–170°) is far from base's
  (127–139°). The top-of-rep knee rule only works with accurate.

## Findings (session 2)
- **Replay with config changes only** (judge code unchanged; accurate sets of both sessions):

  | Config | Normal reps wrongly rejected (29) | Knee reps caught (9: session 1's 5, reps 6–9 of `20261027-142240_knees`) | Half rep + head nod (5) | Belly-down reps (6) |
  |---|---|---|---|---|
  | current | 15 | 9 | 0 counted, 5 `kneesDown` | 0 counted, 0 `bellyDown` |
  | no hip < 110° rule (`kneeBentAngle: 0`) | 2 | 9 | 0 counted, 5 `kneesDown` | 0 counted, 0 `bellyDown` |
  | no knee rules at all | 1 | 0 | **5 counted** | **5 counted** |

- **The < 110° rule fails most often on the first rep and farther from the phone:** it rejected rep 1 in all 5 accurate
  normal or mixed sets, and 6 of 7 reps done farther away. Without it the far reps count (4 of 5 and
  2 of 2).
- **Depth does not filter a head nod:** the half-rep nose depth (1.53–1.80) is in the normal range (1.32–2.13, one far rep at 0.84). The
  shoulder drop planned for H2 overlaps too (half reps 0.41–0.80 shoulder widths, normal 0.42–0.73), so it needs
  another measure or a smoothed one; the minimum elbow angle (half reps 113–145°) also overlaps the knee set's normal
  reps (134–150°).
- **`bellyDown` never fired** (0 of 6), and the belly reps also count once the knee rules are off (5 of 6): the hip–hand gap reached −0.07 to +0.02, so the −0.05 line is crossed only
  for a few frames, and the top-of-rep knee latch closes the rep as `kneesDown` first.
- **Setup:** the user reports that with the accurate model the push-up setup screen only passed with the knees bent.
  Not measured (the setup phase is not recorded); the first 1.5 s of every round show a straight plank (hip
  162–173°), so the knee baseline was not affected.

- **The hip < 110° rule is the only check that catches the kneeling bow** (`20261027-145535_knees`, reps 1–4). The
  hip angle cannot tell the bow from a normal rep: its longest run under 110° was 3–12 frames (10–48 % of the
  attempt) against 0–10 (0–38 %) for normal reps at the usual distance and 0–17 (0–62 %) farther away. Dropping the
  rule (decided for P14, 2026-10-27) therefore lets 4 of the 9 bow reps count; this is logged as a latent false count.
- **Straight-arm reps on the knees** (`20261027-145620_knees`, reps 8–11) get `armsStraight` only while the knee latch
  is on. For reps 9–11 the latch came from the hip < 110° rule; with the rule dropped they fall back to `kneesDown`
  unless the straight-arm check also accepts the knee–hand gap.

## Limitations
- One person and one phone (SM-S741N), floor placement at the usual distance plus one farther position. The user
  could not record other devices or placements for H1 (2026-10-27); the device and placement fields of session 2 were
  filled from the user's account and the recorded shoulder width.
