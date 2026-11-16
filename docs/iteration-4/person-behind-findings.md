# S2: reference video screening and tracking limitation

2026-11-12. Desired behaviour: retain the original exercising user, not the person behind.

## Existing app

The app uses ML Kit's stream-mode pose detector and returns its first pose.
The output has no persistent identity identifier. Setup and battle instantiate
separate estimators, so identity is not carried over by this component. If the
detector changes its chosen person, the output is passed through as the new pose.
`person_behind_estimator_test.dart` demonstrates this with a synthetic fake;
it is not a claim that ML Kit switched in a real recording.

## Downloaded video screening

Screened all 144 Mendeley push-up clips at three timestamps with a separate
MediaPipe multi-pose model. Twelve clips produced two or more candidate poses
at a sampled timestamp. Manual inspection of the contact sheet found background
people in some gym scenes, but also apparent duplicate/false detections or
reflections. These are candidates, not labelled identity-switch test cases.
The scan does not establish whether ML Kit changes target or whether any counts
are missed, and does not cover the requested squat scenario. Source and results:
`C:/SWPP/iter4/pushup-reference-videos/s2-person-candidate-scan.json` and
`s2-candidate-contact.jpg`. Video files must stay local.

## Remaining work

Replay actual video frames through the same ML Kit stream configuration used by
the app, and independently label the original user, any occlusion/switch, and
expected repetition counts. A landmark-only jump detector cannot identify a
person with certainty and may confuse ordinary exercise movement or gradual
transitions with a switch. There is no safe basis yet to claim original-user
continuity or to silently reject/continue a user's reps. If identity cannot be
retained reliably, implementation needs a tested pause-and-notify flow across
the setup/battle boundary, respecting team ownership.


## Experimental continuity warning, 2026-11-16

A limited, default-off prototype is available with `--dart-define=S2_PERSON_GUARD=true`. It locks a fresh setup pose, pauses scoring on a large shoulder-position/scale discontinuity or a lost stream, clears uncertain online pose publication, and asks the player to confirm after a fresh pose returns. The match clock continues while scoring is paused. Retry and lifecycle interruption preserve the need for confirmation. It does not identify people: an identical or gradual change can pass, and ordinary movement can trigger a warning. A confirmation is an explicit user check, not detector proof that only one person is present.

Initial diagnostic simulation over existing ML Kit landmark streams from 1,464 unlabelled source videos flagged a large movement in 161 and a >750 ms gap in 27; 1,276 had neither first alert. This was an approximate first-alert-per-clip simulation, not app end-to-end evaluation: videos can contain edits and other people, and alerts cannot be classified as true or false positives without ground truth. The threshold therefore remains uncalibrated and the feature is not enabled by default.

Dedicated fake-camera tests cover abrupt changes and confirmation in AI push-up/squat and online push-up, including blocked online publication. Other tests cover invalid coordinates, stale frames, stream watchdog and detector retry. Actual two-person videos with independent identity and repetition labels, missed-count/wrong-count evaluation, and physical-device setup and battle UAT are required before considering default enablement or calling S2 complete.
