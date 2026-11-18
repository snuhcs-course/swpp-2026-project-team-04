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

## Initial remaining work (2026-11-12; see the later validation below)

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

## Enabled-build fixes and real-video replay, 2026-11-17

This follow-up resolves the enabled-build test fixtures and adds actual Android
ML Kit video replay. It does not establish biometric identity or change the
default-off `S2_PERSON_GUARD` flag.

The current pre-fix enabled full suite reproduced **14 failures**, with 3,315
passing tests and ten existing skips. Thirteen failures were in battle view
model fixtures and one was in a sound widget fixture. Earlier notes referred
to 47 failures in an older scoped integration run; that was not the current
full-suite failure count. Some screen helpers also explicitly forced the guard
off, so passing the build flag alone had not exercised their enabled paths.

Updated fixtures supply realistic intermediate camera frames, share the fake
server/counter/widget clock, and explicitly confirm the tracked person after
intentional loss, restart or lifecycle interruption. Queued judge results still
occur only at their original target timestamps. Intentional camera-loss tests
remain frame-free. Screen helpers now honor the build flag. No tests were
skipped to obtain a pass; ordinary-build behavior is also verified.

### Video-discovered correction

In single-person OLD-O048, ML Kit briefly collapsed the shoulder width at
867 ms while the shoulder center stayed near the original person. This caused
a permanent confirmation latch in the original guard. Similar width spikes
occur in OLD-O033. The guard now withholds such scale-only outlier frames
without adopting their anchor; a return to the previous scale can recover.
A scale mismatch persisting for **200 ms** requires explicit confirmation.
Large position changes, camera restarts and losses over **750 ms** still latch
immediately. This is temporal filtering, not a newly trained identity model.
The isolated-width regression failed before the fix and passed afterward.

### Actual-video evidence

Nine real source videos were replayed through the current app's
`RepCounterViewModel` both with and without the guard, using identical times
and native landmarks. Five videos were freshly processed on an Android API 36
emulator: **1,344 original frames**, accurate/stream ML Kit, sequential JPEG95
inputs, no crop/resize. Four matched existing native captures were reused.
The packaged fixture has 2,751 frames, of which 2,685 are at/after reviewed
anchors. Source SHA-256 and detector provenance are included.

A separate Codex reviewer inspected all **2,528 frames of eight sources** with
shoulders overlaid on the original video; O033 was inspected chronologically
at sampled timestamps. Observations were frozen before that source's guard
results were viewed. These are assistant-reviewed observations, not independent
human ground truth. Sources do not show the app's setup; each replay begins
from a visually verified original-user anchor.

| Source / scene | Guard off: valid / invalid events | Guard on: valid / invalid events | Observation |
|---|---:|---:|---|
| O027, ML Kit actually selects the background person | 2 / 7 | 0 / 0 | All 256 wrong-target frames withheld; confirmation required |
| O025, person walks behind at 17-19 s | 0 / 0 | 0 / 0 | Original target retained; one temporary uncertain frame |
| O048, single-person room control | 0 / 9 | 0 / 4 | Two temporary uncertain frames; no permanent false latch |
| O033, heavily blurred single-person stress clip | 1 / 4 | 0 / 0 | Remaining instability still causes visible pause |
| D009G, background stander | 0 / 7 | 0 / 4 | Five temporary uncertain frames interrupt some attempts |
| D015G, background stander | 0 / 13 | 0 / 13 | Same events and exact timestamps |
| D015B, background walker | 0 / 0 | 0 / 0 | No guard interruption during exercise interval |
| Squat multi-person, walker enters at 4.25 s | 3 / 0 | 3 / 0 | Same three valid reps and exact timestamps |
| Squat single-person control | 0 / 0 | 0 / 0 | Same target/events; baseline misses the visible cycle |

Counts include only the interval after the documented anchor. D015B is ended
before the exerciser rests on their knees. These counts measure guard impact,
not nine-class form accuracy. Several sources are unsuitable for the current
form judge (viewpoint, privacy blur, etc.); a zero baseline is not proof of
correct repetition recognition. Interruptions are explicitly reported rather
than treated as preserved counts.

The genuine O027 wrong-target intervals are **800-16067 ms** and
**16600-18267 ms**. All 256 frames are hidden from scoring and pose publication.
The seven baseline events in those intervals were *invalid* judgments, not
seven false valid reps. The warning begins at 267 ms during preceding loss and
remains latched even when the original person returns. Explicit confirmation
at 19067 ms restores pose publication; later poor frames still interrupt rep
attempts. This clip proves safe withholding/recovery, not perfect tracking.

The UI regressions cover the matching warning and explicit recovery in AI
push-up/squat and online push-up. Physical phone/live-camera UAT and an
independent human-labeled generalization study remain unperformed. Identical
or gradual person substitutions remain undetectable from these landmarks.

Reproduction: run `flutter test --dart-define=S2_PERSON_GUARD=true` and
`flutter test test/services/pose/person_behind_video_replay_test.dart` from
`gymrats_app`. The fixture README lists original-source hashes, detector
configuration and local observation/capture artifacts. Final suite and
coverage results are recorded in `docs/testing/iteration-4/Sangwoo-Hahn.md`.
