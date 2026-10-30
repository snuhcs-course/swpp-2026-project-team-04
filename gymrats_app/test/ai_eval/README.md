# AI evaluation: push-up judge (frozen set)

The plan of the push-up judge evaluation (P6/P7/P17), **committed on 2026-10-30, before any evaluation run**.
The metric definitions, thresholds, and expected labels here and in `eval_plan.dart` do not change after results
exist. Owner: PM (Jinyoung Park). Only the PM adds files to this folder.

## Protocol
Hyunwoo's "푸시업 녹화 테스트 기준서" (2026-10-29, revised 2026-10-30: set 8).
- 4 team members × 8 sets × 10 reps = **32 cases**, recorded with `lib/demo/rep_judge_demo.dart` (fixture format
  `gymrats-pushup-case` v1, `test/fixtures/pushup_cases/README.md`). Only landmarks and phone sensor values, no video.
- Settings, the same for every set: ML Kit `accurate`, 60 s round, lighting `bright`, the default `RepJudgeConfig` of
  the evaluated commit, devices as recorded in each file (at least S22 and S23).
- Phone positions (distance from the phone's bottom edge to the fingertip line, angle between floor and screen):

| Position | Distance | Angle |
|---|---|---|
| A | 50 cm (±5) | 60–65° |
| B | 50 cm (±5) | 75–80° |
| C | 100 cm (±5) | 60–65° |
| D | 100 cm (±5) | 75–80° |

## Sets and expected labels
| # | Position | Motion | Expected per rep (10 reps) |
|---|---|---|---|
| 1 | A | Normal push-ups | counted |
| 2 | A | Kneeling bow (knees down, hips back, then arms bend to the floor) | `kneesDown` |
| 3 | B | Elbows only to ~120°, then head nod | `insufficientDepth` |
| 4 | B | Full depth, come up only to ~140°; lock out only on the last rep | `incompleteExtension` × 9, then counted |
| 5 | C | Knee push-ups | `kneesDown` |
| 6 | C | Belly and hips touch the floor first | `bellyDown` |
| 7 | D | Normal push-ups | counted |
| 8 | D | Kneeling, arms straight, hips back, head down to the floor | `armsStraight` |

**Ground truth** is the motion the person actually did. A rep that went differently from the plan, the real rep
count, and the real distance and angle are written on the record sheet, and the PM writes them into the case's
`label.perRep` (and `label.expected`). The message on screen never changes a label.

## Metrics (declared before any run)
Labelled and judged reps are lined up by the fewest edits (`align` in `eval_scorer.dart`). A correct rep is a
labelled rep that should be counted (sets 1 and 7, the last rep of set 4, and any rep the sheet marks as correct);
an incorrect rep is one that should be rejected.

| Metric | Definition | Threshold |
|---|---|---|
| M1 Count accuracy | correct reps counted ÷ correct reps done | **≥ 90%** |
| M2 Rejection rate | incorrect reps not counted ÷ incorrect reps done | **≥ 90%** |
| M3 Right reason | incorrect reps rejected with the labelled reason ÷ incorrect reps done | **≥ 80%** |

- The judge passes when all three meet their threshold over all 32 cases.
- M1–M3 are also reported per position A–D and per person, with no threshold.
- An incorrect rep the judge never closed (e.g. a set 4 rep that came up too low) counts as not counted for M2 and
  as wrong for M3. A different reason (e.g. `kneesDown` in set 8) counts for M2 and as wrong for M3.
- Judged reps with no labelled partner are reported apart (counted / rejected) and are not in M1–M3.
- M1 and M2 are the "Accuracy" non-functional requirement on the wiki.

## Procedure and order
1. This plan and the scorer are merged to `main` (this commit) before any case is added.
2. The 32 recordings and record sheets are collected by 10-31; the PM writes the labels and commits the cases here
   in one commit. From then on cases can only be added: each addition gets a line below with date, case, and reason.
3. On 11-01 the replay runner (added with the cases, after the judge fixes on `fix/pushup_judge_accuracy` are on
   `main`) replays every case through the current `RepJudge` and prints `EvalReport.toMarkdown()`. The results,
   date, and commit go to `test/ai_eval_results` and the wiki Testing Documentation.

## Additions after freezing
None yet.
