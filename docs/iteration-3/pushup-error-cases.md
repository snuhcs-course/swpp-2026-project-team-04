# Push-up judge error cases (Iteration 3, P9)

Owner: Hyunwoo Song (`hyun-1210`) | Status: judge fix replayed (P14, 2026-10-27); two recording sessions done (2026-10-26: 4 sets, 23 reps; 2026-10-27: 7 sets, 52 reps)

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

Session 3 (2026-10-27 evening): same person and phone, accurate model, recorded with the first H2 build (judge fix
plus setup recording). Nine sets were saved; only the latest could be labelled from memory, the other eight are kept
outside the repo as raw data (setup analysis below).

| Case id | fps (median) | Labelled | Live = replay (per rep) | Error type | Cause (from the rule trace) |
|---|---|---|---|---|---|
| `20261027-222907_knees` | 24 | reps 1–11 kneeling bow, 12–19 knee push-ups; a rock back with straight arms after rep 19 is not a rep | lockout × 2, KD × 2, lockout × 3, OK, lockout × 2, KD × 2, OK, KD × 2, OK, OK, depth, OK, depth | false count (reps 8, 13, 16, 17, 19), wrong reason | bow reps never locked the arms out between reps (`incompleteExtension`); the knee push-ups kept the knees 0.25–0.31 shoulder widths past the hands, beyond the −0.22 knee line |

KD = rejected as `kneesDown`; depth = `insufficientDepth`; arms = `armsStraight`; lockout = `incompleteExtension`.

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
  shoulder drop planned for H2 overlaps too when measured raw from the last top frame (half reps 0.41–0.80 shoulder
  widths, normal 0.42–0.73), so it needs another measure or a smoothed one (the judge's own measure separates better,
  see "After the judge fix"); the minimum elbow angle (half reps 113–145°) also overlaps the knee set's normal
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

## After the judge fix (P14, `fix/pushup_judge_accuracy`)
Changes, each decided from the cases above (2026-10-27):
- the hip angle under 110° rule is off (`kneeBentAngle: 0`);
- the bottom also needs the shoulders 0.70 shoulder widths down (`minShoulderDrop`), so a head nod stays shallow.
  Measured as the judge's `JudgeSnapshot.shoulderDrop`: the smoothed shoulder height against the top pose the judge
  follows between reps, per rep the peak of the attempt. Valid reps reached 0.75–0.98, head-nod half reps 0.57, 0.61,
  0.65, 0.78, 0.90 (the raw measure in the session-2 findings overlapped more). The margin is 0.05, from one person
  and one phone;
- belly: 3 attempt frames with the hips within the hand band (`minHipOnFloorGap: -0.08`) and a torso drop of 1.10
  (`minBellyTorsoDrop`) as the attempt's peak, checked before the knees. Peak torso drop per rep: belly reps 2–5
  1.13–1.30, normal reps 1.08 at most, knee reps up to 1.10 (kneeling bow) and 1.64 (straight arms on the knees), the
  latter two without three hip frames at the hands. Requiring the torso drop in the same frames as the hip gap lost
  all four belly reps: the two peaks never coincided;
- `armsStraight` also when the knees show by the hands, not only through the hip-fold latch;
- the app uses the ML Kit accurate model.

Not adopted: a 3-frame top-of-rep knee fold. It lost knee reps 2 and 3 of `20261026-000615_knees` (2-frame folds of
38° and 63°) to save one normal rep (a 2-frame 33° dip), so the two cannot be told apart by frame count or angle.

Replay of every case (live verdict at recording → current judge):

| Case id | Before | After |
|---|---|---|
| `20261026-000317_normal` | KD, OK, OK, KD, KD | OK, OK, OK, OK, KD |
| `20261026-000418_normal` (base model) | KD × 6 | KD × 6 |
| `20261026-000522_normal` | KD, KD, OK, KD, OK, OK, OK | OK, KD, OK × 5 |
| `20261026-000615_knees` | KD × 5 | KD × 5 |
| `20261027-142000_halfRepHeadNod` | KD × 5 | depth, depth, KD, KD, depth |
| `20261027-142116_bellyDown` | depth, KD × 4 | depth, belly × 4 |
| `20261027-142240_knees` | KD, KD, OK × 3, KD × 4 | OK × 5, KD × 4 |
| `20261027-142341_normal` | KD, OK × 5, KD, KD | OK × 8 |
| `20261027-142432_normal` | KD × 4, depth | OK × 4, depth |
| `20261027-145535_knees` (kneeling bow) | KD, arms, KD × 7 | **OK × 4**, KD × 5; second fix: KD, arms, KD × 7 |
| `20261027-145620_knees` | KD × 7, arms × 4 | KD × 7, arms × 4 |

Totals on the accurate sets (69 closed reps):

| | Before | After |
|---|---|---|
| Verdict equals the label | 42 of 69 | 59 of 69 |
| Normal reps wrongly rejected | 15 of 29 | 2 of 29 |
| Knee reps rejected (`kneesDown`) | 16 of 16 | 16 of 16 |
| Straight-arm reps on the knees as `armsStraight` | 4 of 4 | 4 of 4 |
| Head-nod half reps counted / as `insufficientDepth` | 0 / 0 of 5 | 0 / 3 of 5 |
| Belly reps counted / as `bellyDown` | 0 / 0 of 6 | 0 / 4 of 6 |
| Kneeling-bow reps counted | 0 of 9 | **4 of 9** |

Superseded by the second fix below (the bow is now caught by the hips at the bottom). Accepted trade-off at the time
(user, 2026-10-27): the kneeling bow is caught only by the hip under 110° rule, which also rejected
half of the normal reps; its four counted reps stay a named known error until the setup guide makes the lower body
visible. Still open: normal rep 2 of `20261026-000522_normal` (2-frame hip dip at the top) and rep 5 of
`20261027-142432_normal` (farther, shoulders 0.27 down). Recordings from now on also keep the setup frames
(`setupFrames`, see the fixture README) for the setup fix.

## Second fix (2026-10-27 evening, session 3)
- **Kneeling bow** (`bowHipHandGap: -0.6`, `bowTorsoDrop: 0.3`): at the attempt's deepest frame, hips at least 0.6
  shoulder widths above the hands with a torso drop of 0.3 or less are a bow (`kneesDown`). At that frame the bow reps
  read −1.21 to −0.36 (16 of 20 past the line), normal reps −0.79 to −0.08 (the closest with a small torso drop:
  −0.54), six far-normal reps of a session-3 set −0.16 to −0.13, knee push-ups −0.32 to −0.14. Elbow angles and
  shoulder height overlap between bows and normal reps from the front, so the arms cannot tell them apart; the bow
  is caught even when the arms lock out. Checking the bow before `armsStraight` turned the straight-arm knee reps of
  `20261027-145620_knees` into `kneesDown`, so the order stayed.
- **Shins lifted at the top** (`maxShinLiftGap: -0.20`, new `PoseMetrics.ankleKneeGap`): at least half of the last 10
  straight-arm top frames before the descent with the ankles 0.20 shoulder widths or more above the knees are a knee
  push-up. Per-rep medians at the top: normal −0.14 to +0.02, knee push-ups −0.27 to −0.19. Measured during the
  descent the two overlap (−0.30 already rejected far normal reps), and the whole top phase failed too: walking back
  from the phone between reps 6 and 7 of `20261027-142341_normal` read −0.56. Line sweep on all 21 sets (12 labelled,
  9 raw): −0.22 catches knee reps 13 and 19 of `20261027-222907_knees`; −0.21 to −0.19 also catch reps 16 and 17
  and change one more rep, rep 6 of the unlabelled set `20261027-221743_normal`. Its last top frames read −0.13 to
  −0.25, like the kneeling reps 8–11 after it (−0.13 to −0.28) and unlike reps 1–5 before it (−0.03 to −0.10) at the
  same distance, so it was most likely already on the knees; that set stays out of the fixtures because its labels
  are uncertain. −0.20 was chosen (user, 2026-10-27).
- **Not adopted: a wider knee line.** Moving `minKneeHandGap` from −0.22 to −0.28 rejected 9 normal reps (3 of 6
  far-normal) and caught none of the four counted knee reps; −0.35 rejected 31 and caught 3.
- **Setup** (`SetupConfig.maxPushUpTorsoDrop` 1.0 → 1.5): of 506 setup frames that showed "Get into a push-up with
  straight arms", 492 had straight arms and failed only on a torso drop above 1.0. The top of a plank reads 1.05–1.22
  on the labelled sets (one rep 1.54) and an upright body over 2, so 1.0 turned good planks away; a kneel with the
  hips pushed back reads lower and passed, which matches the user's report. No set showed "too far".

Totals after the second fix, on the accurate sets with the session-3 set (88 labelled reps): kneeling-bow reps counted
0 of 20 (was 4 of 9 in session 2, plus 1 of 11 live in session 3); knee push-ups counted 0 of 8 in
`20261027-222907_knees` (was 4 of 8 live); normal reps wrongly rejected unchanged at 2 of 29; the first-fix rows above
are otherwise unchanged.

Replay after the second fix: `20261027-145535_knees` KD, arms, KD × 7 (the four counted bows are rejected);
`20261027-222907_knees` KD × 17, depth, KD, depth (every bow and knee rep rejected; knee rep 18 as
`insufficientDepth`). Every other case is unchanged.

## Limitations
- One person and one phone (SM-S741N), floor placement at the usual distance plus one farther position. The user
  could not record other devices or placements for H1 (2026-10-27); the device and placement fields of session 2 were
  filled from the user's account and the recorded shoulder width.
