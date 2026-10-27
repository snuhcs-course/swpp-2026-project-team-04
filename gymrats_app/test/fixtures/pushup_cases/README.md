# Push-up error cases

Recorded push-up sets, replayed through `RepJudge` by
`test/services/pose/pushup_error_cases_test.dart`. Each `.json` file is one set.
Only pose landmarks and phone sensor values are stored, never camera images.

## Recording a set
1. From `gymrats_app/`: `flutter run -t lib/demo/rep_judge_demo.dart -d <device-id> --dart-define=GIT_COMMIT=$(git rev-parse --short HEAD)`
   (debug build; the commit goes into each recording).
2. In the form, pick what the set shows (normal push-ups, knees on the floor, half rep + head nod, ...), the
   number of reps you will do, and the setup: person, height, device, phone placement, lighting, ML Kit model.
3. Do the set. Stop (or the end of the round) saves it on the phone and shows the expected and live result.
4. Copy the files here: `powershell tools/diagnose/Pull-PushupCases.ps1` (Windows) or
   `bash tools/diagnose/pull_pushup_cases.sh` (macOS, Linux), from the repo root.

## Labels
- The kind and rep count give the expected result: a normal set expects every rep counted; a cheat set expects
  every rep rejected with that cheat's reason (knees on the floor → `kneesDown`, half rep + head nod →
  `insufficientDepth`, ...). A "Free (no label)" set is kept for analysis and not checked.
- If a set did not go as labelled (a mixed set, or one rep went wrong), fix `label.expected` in the JSON by hand,
  for example `{"valid": 8, "rejected": {"kneesDown": 2}}`, and say why in `label.note`.
- For a mixed set, also add `label.perRep`: one entry per rep in order, `"valid"` or the reason name, for example
  `["valid", "kneesDown", "valid"]`. The replay then compares the reps in order, so a counted knee rep and a
  rejected good rep cannot cancel out in the totals. Its length must equal `reps` and it must agree with `expected`.
- A case that today's judge gets wrong stays here: add its id to `knownErrors` in the replay test with a
  `known error: ...` reason, and log it in `docs/iteration-3/pushup-error-cases.md`.

## Format (version 1)
- `format`, `version`, `id` (also the file name), `recordedAt`.
- `label`: `kind`, `reps`, `expected` (`valid`, `rejected` by reason name; null when unlabelled), optional
  `perRep`, `note`.
- `setup`: `person`, `heightCm`, `armCm`, `shoulderCm` (optional, measured on the person), `device`, `placement`,
  `lighting`, `model` (`base` or `accurate`), `roundSeconds`.
- `frontCamera`, `frameRotation`, and `landmarks`: the 33 ML Kit landmark names, in the order used below.
- `judge`: the build `commit` (null without `--dart-define=GIT_COMMIT=...`) and the `RepJudgeConfig` values that
  made `live`. The replay test uses the judge of the current code, so after a judge change `live` and the replay
  may differ on purpose.
- `live`: the reps the judge closed while filming (`index`, `valid`, `reason`, `t` in µs, `maxDepth`, ...).
- `frames`, one per line, every frame the judge saw:
  `t` (µs, the time the judge read), `w`/`h` (upright image size), `p` (x, y, z, likelihood for each landmark,
  in `landmarks` order; nulls for a missing one), `tilt` (phone degrees from flat), `gyro` (rad/s), `moved`
  (phone leaned or shook), `fps` (frames the counter processed in the second before), `g` (raw gravity x, y, z in
  m/s², Android axes: x right, y to the top of the phone, z out of the screen; the screen-plane roll is
  `atan2(x, y)`), `luma` (mean image brightness 0–255 of the latest camera frame; only the number is kept). A frame with `"mark": "abandon"` is where the counter dropped the attempt in progress.
- Values are rounded (0.1 px, likelihood to 4 places), so a replay can very rarely differ from `live` at a
  threshold edge.
