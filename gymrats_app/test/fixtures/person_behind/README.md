# S2 real-video landmark regression fixtures

`reviewed_native.json.gz` contains recorded Android ML Kit accurate/stream
landmarks, not synthetic pose motion. Tests replay them through the real
`RepCounterViewModel` with fake camera/inference IO. Raw videos stay local.

- Fixture SHA-256: `79ad4251de9366d7f00b4a10d4585360df005b16d6ef4d7b23efdaeb0888ee55`.
- Nine source videos; 2,751 frames in the fixture and 2,685 after the selected
  anchor times. One repetition test replays O027 again with confirmation.
- Five fresh captures on 2026-11-17: 1,344 original frames, eight empty poses.
  Existing four captures: Android native streams produced for the earlier
  push-up benchmark, matched by original video SHA-256.
- Capture: `google_mlkit_pose_detection` 0.16.1, accurate/stream, sequential
  original frames as upright JPEG quality 95. Fresh detector for each video.
  No cropping/resizing. Fresh capture used x86_64 Android API 36 emulator.
- Evaluator APK SHA-256:
  `c8a5a47961399c39150bb235f0dc7bd153e0248669ad8992c72306df3ebfe501`.
- Frame format: `[original_frame_index, milliseconds, [[x,y,likelihood],...]]`.
  Exactly 33 ML Kit landmark positions when present; null for missing poses.
  Z is omitted because these guards and judges use 2D coordinates.
- The recordings do not contain the app's preparation screen. An explicitly
  reviewed correct-person pose anchors each replay. Setup/UI flows are tested
  separately with fakes. JPEG replay is not live NV21 camera or phone UAT.

## Sources and observations

| ID | Source | Scene / anchor ms |
|---|---|---|
| OLD-O025 | Mendeley subject 001 good frontal | Actual background walker at 17-19 s; anchor 0 |
| OLD-O027 | Mendeley subject 003 good frontal | Actual wrong-person ML Kit output; anchor 133 |
| OLD-O033 | Mendeley subject 009 good frontal | Blurred single-person stress control; anchor 1467 |
| OLD-O048 | Mendeley subject 024 good frontal | Empty-room control with intermittent source blur; anchor 0 |
| S2-D009-G | Mendeley subject 009 good diagonal | Background stander; anchor 667 |
| S2-D015-G | Mendeley subject 015 good diagonal | Background stander; anchor 800 |
| S2-D015-B | Mendeley subject 015 bad diagonal | Background walker; anchor 1333; end 12533 |
| S2-SQUAT-MULTI | HF `6dddd176-2460-48cf-bd01-3eaaa0dc754f.mp4` | Background walker and later third person; anchor 0 |
| S2-SQUAT-CONTROL | HF `squat_18.mp4` | Single-person frontal control; anchor 0 |

HF source: [Real Time Exercise Recognition Dataset](https://huggingface.co/datasets/RickyRiccio/Real_Time_Exercise_Recognition_Dataset).
Dataset card states CC BY-NC-SA 4.0 and mixed origins. No original media is
redistributed here. Original source hashes remain in each fixture row.
Mendeley source: [A Multi-View Raw Video Dataset of Seven Fitness Exercises
with Good/Bad Form Labels](https://data.mendeley.com/datasets/kgbb3yn47p/3),
Sai Prashanth et al., 2026, version 3, DOI `10.17632/kgbb3yn47p.3`,
dataset license CC BY 4.0. Videos use privacy blur in several views; it affects
detection. Landmark excerpts here preserve the source's framing and timestamps.

Codex reviewed all 2,528 native frames of eight videos with shoulders drawn on
the original images. O033 had chronological sampled review only. Labels were
frozen separately from guard outputs; they are assistant visual observations,
not independently adjudicated human ground truth or population accuracy.

O027 has 256 verified wrong-target frames at **800-16067 ms** and
**16600-18267 ms**. The baseline judge emits seven *invalid* events there;
these are not seven false valid reps. S2 withholds all 256 frames and emits no
events until explicit confirmation. A valid pose returns at 19067 ms; the
second replay checks publication recovery, not a promised completed rep.

D015B becomes kneeling/resting at 12667 ms. The fixture ends at 12533 ms to
isolate the exercise-with-walker interval without labelling rest as a switch.
Pauses in blurred controls and dropped attempts are explicitly retained in
the tests/report; equality to the original counter is not claimed there.

Local audit/reproduction artifacts: `C:/SWPP/iter4/s2-validation/`:
`native-capture-verification.json`, `all-native-anchored.jsonl`,
`all-native-results.json`, `visual-observations-frozen-v1.json`,
`visual-observations-addendum-v2.json`,
`diagonal-native-observations-frozen-v1.json`,
`squat-observations-frozen-v1.json`, and
`squat-native-observations-frozen-v1.json`.
