# Iteration4 supplemental coordinate evaluation set

Recorded date: 2026-11-18. Participants selected explicitly by the user:
**hyunwoo8 + sangwoo8**, four push-up and four squat scenarios each. This differs
from the participant names in the forwarded PM draft. No source MP4, JPEG,
camera frame or absolute local filesystem path is published here. Original
filenames, SHA-256 hashes and capture metadata link coordinates to the private
videos. This folder is separate from the unchanged frozen `../cases` set.
Video/capture hashes cover original bytes. Coordinate JSON hashes cover UTF-8
text with LF line endings, preserving verification across Git CRLF checkouts.

## Ground truth is pending

All16 cases start with `label.status=pending`, `actualReps=null` and `perRep=null`.
The recorder or PM supplies actual counts and one label per actual repetition
in each person's `record-sheet.md`. Filenames describe filming intentions,
not ground truth. Neither app predictions nor visual count estimates were
copied into confirmed labels. Pending cases produce **N/A M1/M2/M3** and
unscored prediction diagnostics. They do not count as zero accuracy or benefit.

After confirmation, transfer the sheet to each case's JSON, for example:

```json
{"status":"confirmed","actualReps":3,
 "perRep":["valid","kneesDown","valid"],
 "confirmedBy":"recorder or PM, confirmation date",
 "note":"Describe any departure from the filming plan"}
```

The example is a format illustration, not a label for any included video.
The label count must exactly match `actualReps`. Count0 with an empty label
list is valid for an observed no-repetition control. An optional
`evaluationWindowUs:[start,end]` excludes approach/recovery events from scored
movement while retaining all input frames for calibration. Without a window,
the full clip uses the frozen scorer's sequence alignment semantics; late
approach events can align with a missed movement. Review them explicitly.

## Label criteria

Labels follow observed movement, independently of predictions. Push-up labels
use the existing `RejectReason` meanings: full normal motion is `valid`, knee
support is `kneesDown`, incomplete return is `incompleteExtension`, and observed
belly support is `bellyDown`. Hidden physical contact is not confirmed merely
from projected ML Kit joints. Add notes or leave the case pending if uncertain.

For squat, use the shared `SquatRepJudge` route used by AI and online modes:

| Filming scenario | Per-repetition ground-truth criterion | Label |
|---|---|---|
| Normal | Agreed full descent and complete upright return | `valid` |
| Shallow | Starts/returns upright but does not reach agreed depth | `shallowSquat` |
| Does not stand up | Descends sufficiently but begins another descent before full upright return | `standUpFully` |
| Chair | Same depth and complete upright return criteria; chair use itself is allowed | `valid`, `shallowSquat` or `standUpFully` |

Implementation thresholds are recorded for interpretation, **not used to label
the video**: standing thigh gap at least0.7shin, 300ms standing acquisition,
depth `1-currentThighGap/standingThighGap`, candidate entry0.25, sufficient
depth0.75 and upright return at depth0.15 or less. A bottom followed by return
to0.4 and renewed descent of0.3 triggers standUpFully. Closing shallow motion
needs at least200ms and peak depth0.45. These are 2D image proxies, not measured
physical joint angles or independent definitions of correct exercise form.

The user confirmed on 2026-11-18 that chair squats are valid when sufficient
depth and full standing are achieved. Both chair cases use
`chairPolicy: range_only`. Chair use itself is not a rejection reason.
Actual counts and per-repetition labels still await recorder/PM confirmation.

## Metrics and conservative default

The new scorer preserves the frozen set's minimum-edit alignment and formulas:
M1 = labelled valid repetitions counted / labelled valid repetitions;
M2 = labelled invalid repetitions not counted / labelled invalid repetitions;
M3 = labelled invalid repetitions rejected for the exact labelled reason /
labelled invalid repetitions. A missed invalid rep contributes to M2 but not
M3. Explicit rejections, missed incorrect reps and unmatched accepted/rejected
events are reported separately. Tests compare alignment with the immutable
frozen scorer on200 deterministic synthetic sequences.

Frozen and Iteration4 results are separate. New results are also separated by
exercise and participant. No denominator exists for a pending label. The
original fixed-set90%/90%/80% thresholds are unchanged; they are not silently
relaxed for this addition. A proposed default-on benefit requires complete
human labels, no regression in new-set M1/M2 and at least one strict improvement.
M3 is additionally reported for review. The evaluator never edits app defaults.
`PUSHUP_FRAME_KNEE` stays false until that evidence is available and reviewed.

## Capture and reuse limits

All16 originals were decoded at full720x1280 upright resolution with JPEG95,
then passed sequentially through Android ML Kit Accurate/stream0.16.1. There
are5,325 frames. Timestamp `t` is original millisecond PTS multiplied by1000
for fixture microseconds; this does not create sub-millisecond precision.
There is no IMU, live camera scheduling, original setup/identity gate or frame
busy-drop simulation. `p` is33ML Kit landmarks in x/y/z/likelihood order; null
means no pose. Model predictions, if present in the extraction app's historical
export, were discarded before publication.

Hyunwoo push-up clips informed knee-rule development. Both participants' videos
have already been inspected in local experiments. This addition is not a new
untouched holdout or an estimate of population/physical-contact accuracy.

## Reproduction

From `gymrats_app`:

```sh
flutter test --no-pub test/ai_eval/iter4
flutter test --no-pub --dart-define=PUSHUP_FRAME_KNEE=false test/ai_eval/iter4/comparison_test.dart
flutter test --no-pub --dart-define=PUSHUP_FRAME_KNEE=true test/ai_eval/iter4/comparison_test.dart
```

Reports are written to `build/ai_eval_iter4/comparison-off.md/json` and
`comparison-on.md/json`. Each contains frozen and new-set results separately,
source revision/blob IDs, pending status and raw predicted event diagnostics.
Published snapshots live in `../results/`; do not overwrite older reports.

From the repository root, verify the coordinate package without original videos:

```sh
python tools/diagnose/import_iter4_video_cases.py --verify-only --output gymrats_app/test/ai_eval/cases_iter4
```

After transferring confirmed human labels/windows into coordinate JSONs, update
their manifest hashes with `--refresh-manifest` instead of `--verify-only`, then
rerun both evaluation modes. This operation does not need private videos.

The importer accepts the private video root and native coordinate exports for
recreation, verifies original hashes/frame counts and preserves existing labels.
Record-sheet confirmation remains a human step. No private video is required
to run the committed coordinate replay.
