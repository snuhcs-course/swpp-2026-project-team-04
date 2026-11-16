# Front-view video replay (2026-11-12)

The framing reference is `0b78db8e-3c32-4248-bbff-b483f9d910d3.mp4`.
The video contains edits, instructional overlays and held/incorrect poses, so
it is a framing reference, not a verified continuous-repetition label.
Four additional front-view candidates are listed in
`C:/SWPP/iter4/pushup-reference-videos/front-view-candidates.md`.

## Method

Frames were sampled at 10 fps from five clips; for the reference both the
original and a fixed crop were tested. The crop was estimated from MediaPipe
landmarks sampled throughout each clip, with 35% padding; dimensions and crop
bounds are recorded in `C:/SWPP/iter4/pose-eval-target/manifest.json`.
It preserves aspect ratio and does not move between frames. Some occluded or
poorly detected body parts can fall outside the crop, so inspect each clip.

In an Android emulator, ML Kit's **accurate** model in stream mode processed
each JPEG frame. This uses the app's model and `RepJudge`, but image-file input
and 10 fps are not identical to the app's live NV21 camera input or a physical
phone's timing. The standalone app at `C:/SWPP/iter4/pose_video_eval` uses
byte-identical copies of the model/pose/judge files from this branch (verified
using SHA-256), without changing or replacing GymRats. Every landmark, its
likelihood, judge phase and events are in `C:/SWPP/iter4/pose-eval-results.json`.

| Clip | Frames with a pose | Baseline events |
| --- | ---: | --- |
| reference, original | 78/78 | none |
| reference, crop | 76/78 | none |
| push-up_10, crop | 50/50 | 1 knees-down rejection |
| push-up_12, crop | 50/50 | 3 valid |
| push-up_17, crop | 50/50 | none |
| push-up_20, crop | 27/28 | none |

These are model outputs, **not** accuracy scores. Pose present does not prove
that every joint is correct. The reference video spends 61/78 frames in the
judge's initial phase, and is edited/held, so failure to emit an event here
does not prove a real-time missed rep. Cropping reduced the reference pose
availability from 78 to 76 frames; it is not established as an improvement.

## Candidate rule comparison

`tools/diagnose/video_pose_replay_test.dart` feeds the captured landmarks back
to the unmodified judge and changes one setting at a time. Reducing top hold
from 300 to 200 ms changed push-up_17 from no events to two valid and one
rejected; it did not change the reference's lack of events. At 100 ms the
uncropped reference produced three valid events, but these are not verified
repetitions and include instructional footage of incorrect form. On the frozen
evaluation, 200 ms reduced M1 from 50/63 to 48/63 and 100 ms caused one new
false count (see `pushup-critical-cheats.md`). Neither was deployed.

No ground-truth joint annotations or per-rep labels are available for these
clips, so replacing the pose model or changing app thresholds on these outputs
alone is not justified. Next: label repetitions and required cheat reasons on
front-view clips, replay at original frame rate and compare candidate rules
against those labels and frozen critical-cheat fixtures. S2 identity tracking
requires separate multi-person labelled video validation.
