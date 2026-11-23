# Testing notes – Iteration 5 – Woohyun Song

Per-push Results for my Iteration 5 steps, in the Testing Documentation format. The PM merges them into
`docs/testing/Testing-Documentation.md` (P26).

## Results

#### 2026-11-23 · code at commit `141c8df` · step A2 `codex/iter5-arcade-stages` (Build arcade stage rules; team order #8 before the PM's renumbering)
The arcade (P16 before the PM's renumbering) is split into five steps. A2 is the arcade's values and rules, with no
screen:
- **Data:** the 4 floors, 24 stages and 16 AI levels of the design hand-off `arcade_data.json` (version arcade-1), as
  Dart constants (`ArcadeCatalog`, `ArcadeAiLevel`).
- **Bot:** `BotOpponent` takes a `BotPace`, which `BotDifficulty` and `ArcadeAiLevel` implement. 초보, 중수 and 고수 play
  exactly as before.
- **Rules:** each floor's rule as `BattleRules`; the stars of a fight, a boss match and a hold (`ArcadeStarJudge`).
- **Progress:** the most stars per stage (`ArcadeProgress`), kept per account in secure storage
  (`ArcadeProgressStore`).

The branch starts at `origin/main` `25509ee`. Before the push, `main` moved to `ad8a6f7` (#87, push-up grading), and
I merged it in (`03edd7f`). I ran the commands from the Plan in `gymrats_app/` on Windows, on `141c8df`, without
coverage. Coverage comes from the PR's CI comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | CI comment "Tests and coverage (GitHub Actions)" |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the PR's CI comment (no ViewModel changed) | 11/23 | same CI comment |
| Service | flutter_test, fakes | 85% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment (no View changed) | 11/23 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 11/23 | – |

- **Tests:** `flutter test` 3908 passed, 0 failed, 10 skipped. `flutter analyze` found no issues. The skipped tests
  were already skipped on `main`, and A2 does not touch them:
  - `test/services/online/public_wss_smoke_test.dart`: a live team-server check that runs only with
    `RUN_PUBLIC_BATTLE_SMOKE`.
  - 9 recordings in `test/services/pose/pushup_error_cases_test.dart`: known push-up judge errors, each with its
    reason in `knownErrors`.
- **Count change:** A2 adds 124 tests: 115 in the seven new arcade test files and 9 in the two bot test files.
  The other 4 new tests came with `main`'s #87. Before the merge, the branch had 3904 passed on `6b6b2b4`.
- **One failed run, not from this step:** the first full run on `6b6b2b4` had one failure in
  `test/services/online/online_battle_integration_test.dart`, 'server deduplicates verdicts, rejects conflicts,
  relays only pose whitelist' (L922: `valid_reps` 0, expected 1). A2 does not touch online battles. That run was
  slow (`flutter analyze` took 150 s instead of 75 s, with another test run on this PC). The file then passed 3 times
  out of 3 on its own (59 tests each), and the next full run on `6b6b2b4` passed (3904). It also passed in the earlier
  full run on `3bf2515` (3901 passed) and in the run on `141c8df` above.
- **The bot is unchanged (spec 3):** before editing `bot_opponent.dart`, I printed `planRound` with the code at
  `25509ee` for 초보, 중수 and 고수: the rounds of seeds 1 and 7, and for seeds 0 to 499 the counts of reps, valid
  reps and deep reps, the sum of their end times and the rejected reps by reason. The printed 고수 rounds equal the ones
  already pinned in the test from `8fc6cb3`. The new tests pin these values, and they pass on the changed code. As a
  check that the pins catch a change, I set the bot's `_jitter` from 0.15 to 0.16 for one run: 7 of the 8 new tests
  failed. The 8th checks only the valid reps of an arcade level, so it does not depend on `_jitter`. Then I set it
  back.
- **The pins after the merge:** #87 maps the bot's simulated `kneesDown` misses to `insufficientDepth`, so `main`'s
  bot is no longer the one pinned at `25509ee`. I printed the same values again from an export of `ad8a6f7` (outside
  the working tree). Only the rejection reasons differ: 초보 seed 1's `kneesDown` rep is now `insufficientDepth`, and
  the `kneesDown` count of seeds 0 to 499 moved to `insufficientDepth` (초보 125 + 107 = 232, 중수 55 + 53 = 108,
  고수 42 + 57 = 99). The times, counts and depths are the same. The pins now hold the `ad8a6f7` values (`141c8df`),
  and they pass on the merged code.
- **A field the merge added:** #87 also added `BattleRules.kneeAverageEnabled`, which a floor's rules did not copy
  from their base. Fixed in `9f14b6f`. The floor test's base now turns it off, and without the copy 'fever sets its
  start, and keeps the base's other values' fails.
- **The data test catches a changed value:** for one run I changed stage 7's label '무효 2회 이하'. The test
  'the 24 stages, every field and star' failed at stage 7. Then I set it back.
- **The JSON copy:** the step's ownership covers only `test/models/arcade_*_test.dart`, so the copy of
  `arcade_data.json` is a raw string in `test/models/arcade_catalog_test.dart` instead of a fixture file. Only the line
  breaks differ from the hand-off file (checked with Python `json.loads(copy) == json.load(file)`).
- **Other checks:** `ownership_guard.py --check-diff` ok (21 files: 18 code and test files, 3 notes), run with the local harness of the time. On 2026-11-23 I also
  matched the 21 files with the A2 paths of the PM's new harness: none is outside them. Server `pytest` was not run because
  `server/` did not change.
- **Coverage:** TODO(Woohyun Song): copy the numbers, commit and run link from the PR's CI comment "Tests and coverage
  (GitHub Actions)".
- **Shortfalls:** none known before CI reports coverage.
- **Manual check:** none. A2 has no screen. The arcade screens (P16) use these values.
- **Notes-only push (2026-11-23):** the PM's new harness names this step A2, "Build arcade stage rules"; these
  notes, the AI notes and the PR now use that name. The code is unchanged at `141c8df`, so the results above
  stand. The tests were not rerun for this push.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/arcade_catalog_test.dart` (new) | every floor, stage, star and AI level equals the JSON copy; the version and 5F; the characters are the character rig's, with the same names; the JSON's default score rules are `battleRules`; 초보 = LV 1, 중수 counts like LV 4 (combo chance 0.08 vs 0.10), 고수 has no level; six stages per floor in the order push-up, squat, plank, push-up, chair, boss; six characters fight twice each, never twice on a floor, never on their own floor, never in two fights in a row; AI LV 1 to 16 through the fight and boss stages; holds and bosses meet the floor owner; boss rounds push-up then squat; the stars of each kind; the star numbers get harder each floor; 4F's 무효 0회; lookups and range errors |
| Model | `test/models/arcade_ai_level_test.dart` (new) | 16 levels in order; `of(1..16)`, range errors at 0, -1 and 17; LV 1 has every number of 초보 and plans exactly its rounds (100 seeds); one more valid rep at both ends per level; LV 16 counts 20 to 22 in 30 s; every level stays inside its valid and rejected counts (200 seeds each); a bot takes a level |
| Model | `test/models/arcade_floor_test.dart` (new) | 1F is `battleRules`; 2F fever from 15 s; 3F combo bonus 10; 4F excellent 30; every other value (all 12) stays the default; the times multiply the base's own value; fever keeps the base's other values, incl. `kneeAverageEnabled` off |
| Model | `test/models/arcade_stage_test.dart` (new) | `HoldPose` plank and chair with their labels; `ExerciseType` is still push-up and squat; stage kinds; a hold's star times and end time; `ArcadeStars` count, cleared, lit, equality |
| Model | `test/models/arcade_progress_test.dart` (new) | the first state; a stage opens after a star in the one before; the stage to play; a floor cleared only by its boss; 5F after stage 24; all 24 cleared; star total up to 72; playing again never lowers a stage's stars; range errors; 24 counts from 0 to 3; equality; the saved form `{"v":1,"best":[...]}` and 13 broken values |
| Service | `test/services/arcade/arcade_star_judge_test.dart` (new) | fight: loss, win only, condition, KO only, all three, the boundaries n and n ± 1 of 무효 (incl. 0회), 콤보 and Excellent, a wrong second star throws; boss: R1 lost, R2 lost, both won, the excellent sum at its boundary, KO in one round only, both KO, all three; hold: each star second's boundary, ended by two warnings (17 s clears, 9 s fails), each stage's own seconds; a round from a `BattleResult`: win, KO win, loss by KO, draw, rejected reps, longest combo, excellent reps, 3F and 4F rules, no form |
| Service | `test/services/arcade/arcade_progress_store_test.dart` (new) | secure storage: writes and reads under `gymrats.arcade.<account>`, accounts apart, nothing saved, 7 broken values, a failing read; memory store; `recordStage` writes once per stage and keeps the most stars, writes nothing when the storage read fails (the saved progress stays), replaces a broken value |
| Service | `test/services/opponent/bot_opponent_test.dart` (updated) | 초보 and 중수 seeds 1 and 7 plan exactly the rounds printed at `ad8a6f7` (main before this step); seeds 0 to 499 of all three levels plan the same reps; the bot and `planRound` take an arcade level |
| Model | `test/models/bot_difficulty_test.dart` (updated) | every level is a `BotPace` and reads the same through it |

### Acceptance criteria → tests
- Data equals `arcade_data.json` (spec 9) → 'the four floors: name, owner and rule', 'the 24 stages, every field and
  star', 'the 16 AI levels', 'the characters are the rig's, with the same names'
- Stage rules → 'every floor plays push-up, squat, plank, push-up, chair, boss', 'the six characters each fight twice
  in the twelve fights', 'no character fights twice on a floor, nor on its own floor', 'no character fights in two
  fights in a row', 'the AI goes up one level per fight and boss stage, 1 to 16', 'the floor's owner judges its holds
  and plays its boss match'
- AI levels → 'LV 1 has every number of 초보', 'a level outside 1 to 16 throws', 'LV 1 plans exactly the rounds of
  초보', 'LV <n> stays inside its valid and rejected counts' (16 tests)
- 초보·중수·고수 unchanged (user's condition) → '초보 seed 1 plans exactly the same round' and the three other
  seed pins, '초보: seeds 0 to 499 plan the same reps' and the same for 중수 and 고수, the existing 고수 'seed 1 / seed 7
  plans exactly the same round'
- Floor rules → '1F plays by the default rules', '2F: fever from 15 s, the rest as by default', '3F: combo bonus 10,
  twice the default, the rest as by default', '4F: excellent 30, twice the default, the rest as by default'
- Fight and boss stars → 'a loss lights no star, whatever else happened', 'a KO win without the condition lights the
  first and third', '무효 n회 이하: n and fewer meet it, n + 1 does not', '콤보 n 이상: n and more meet it, n - 1 does
  not', 'losing R2 lights no star', 'the excellent reps of both rounds count together, from n', 'a KO in one round
  only is no third star'
- Hold stars and decision 11.1 → 'each star lights at its seconds, not a moment before', 'ended by two warnings: the
  time held so far counts (spec 11.1)'
- Progress and decision 11.2 → 'a stage opens once the one before it has a star', 'the stage to play is the first one
  with no star', 'a floor is cleared by a star in its boss match', '5F shows once the 4F boss match has a star',
  'playing again keeps the most stars of the stage (spec 11.2)', 'all 24 cleared: no stage left, every floor and 5F'
- Storage (spec 7) → 'accounts keep their own progress', 'a broken value, another version, another length or a count
  outside 0 to 3 is the first state', 'a store that fails to read is the first state', 'a store that fails to read
  keeps the saved progress: nothing is written'

#### 2026-11-23 · code at commit `a5f0d7d` · step A3 `codex/iter5-arcade-art` (Create arcade artwork, team order #8)
The arcade is split into steps. A3 is the arcade's pictures, with no screen:
- **Data:** the design hand-off `gym_art.json` (version arcade-art-1, 701 shapes) kept as
  `gymrats_app/assets/arcade/gym_art.json` and copied unchanged into the Dart string `gymArtJson`.
- **Owners:** `GymOwnerFigure`, the four goggled gym owners (물렁범, 펭뚱이, 그루, 곰탱이) in three faces (watch, blow,
  ok), with optional breathing.
- **Backgrounds:** `GymBackground`, the stage background of 1F–5F, cut to its 360 × 390 picture.

The branch starts at `origin/main` `25509ee` and does not wait for P16-1. The code is three commits: `de3a969` (the
art), `c00eced` (`GymArt.warmUp`) and `a5f0d7d` (opacity tests, after the first review). I ran these in
`gymrats_app/` on Windows, on `a5f0d7d`, without coverage (this PC's rule):

```sh
flutter pub get
flutter analyze
flutter test
flutter test test/widgets/gym_background_art_test.dart test/widgets/gym_background_test.dart test/widgets/gym_owner_figure_test.dart
```

Coverage comes from the PR's CI comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.3% (733/738; not changed by A3) | 11/23 | CI comment "Tests and coverage (GitHub Actions)" on PR #88, commit `071c7f0`, [run 45149879412](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/45149879412) |
| ViewModel | flutter_test, fakes | 90% | 97.6% (1750/1793; not changed by A3) | 11/23 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 95.6% (4573/4785; not changed by A3) | 11/23 | same CI comment |
| View | flutter_test (widget) | 75% | 98.1% (11325/11548); A3's files 99.5% (213/214) | 11/23 | same CI comment; A3's files from the run's lcov parts |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (114 passed; `server/` not changed by A3) | 11/23 | same CI comment |

- **Tests:** `flutter test` 3840 passed, 0 failed, 10 skipped (2026-11-23, `a5f0d7d`). `flutter analyze` found no issues. The
  skipped tests were already skipped on `main`, and A3 does not touch them:
  - `test/services/online/public_wss_smoke_test.dart`: a live team-server check that runs only with
    `RUN_PUBLIC_BATTLE_SMOKE`.
  - 9 recordings in `test/services/pose/pushup_error_cases_test.dart`: known push-up judge errors, each with its
    reason in `knownErrors`.
- **New tests:** 60, in the three files below (43 + 12 + 5). The first review's run on `de3a969` had 3838 passed;
  `a5f0d7d` adds the opacity test and the warm-up test.
- **Mutation check (2026-11-23):** with the opacity taken out of the paints (`withValues` removed in
  `gym_background_art.dart`), "the parser reads a shape: matrix, path, colors, line ends and opacity" and "GymArtPainter
  paints a see-through fill and a faint outline at their opacity, as the floor lines are" fail; the shot tests alone
  would not notice (their channel tolerance of 64 hides the faint floor lines).
- **Other checks:** `ownership_guard.py --check-staged` ok on every commit (25 files, all inside the step's file list in the local harness; none changed outside them).
- **Checks after merging `origin/main`:** `git fetch origin && git merge origin/main` brought in `ad8a6f7` (PR #87,
  push-up grading; no A3 file). On the merge commit `0b3475a` (2026-11-23): `flutter analyze` found no issues and
  `flutter test` had 3844 passed, 0 failed, 10 skipped (the same skips; PR #87 adds 4 tests).
  `ownership_guard.py --check-diff` ok (25 files). Server `pytest` was not run because
  `server/` did not change.
- **Against the design shots:** the 17 shots of the hand-off (`shots/`, now `assets/arcade/shots/`) are compared pixel
  by pixel at 2x, as for the W3 characters (a pixel differs when a channel is off by more than 64; at most 0.03% may
  differ). On 2026-11-23 no pixel of any shot differed by more than 20 in a channel (the owners by at most 8). The same
  check fails for a wrong face, a wrong floor and a missing shape. Nothing differs from the design.
  - In the design itself, 펭뚱이's `watch` and `ok` are the same picture: its mouth is an empty path (`M0 0`) in both
    faces (`design/CoachB.dc.html` L276). Reported to the user, who decided to keep it as it is (2026-11-23).
- **Coverage:** from the CI comment "Tests and coverage (GitHub Actions)" on PR #88, commit `071c7f0` (2026-11-23 18:58
  KST; app and server jobs both succeeded; [run 45149879412](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/45149879412)). App total 97.4% (18751/19250), Other 95.9% (370/386).
  - CI also ran `flutter analyze` (no issues) and `flutter test` (3844 passed, 10 skipped, 0 failed), the same as the
    local run on `0b3475a`; `071c7f0` changes only the notes.
  - A3's files, merged by line from the run's four lcov parts: `gym_background.dart` 13/13, `gym_owner_figure.dart`
    42/42, `gym_background_art.dart` 158/159 (`gym_background_art_data.dart` is a constant with no executable line).
    The one line not hit, L265, is the `StateError` for a matrix that is not six numbers, which the parser rejects
    before any shape is built.
  - Left out of the coverage numbers by CI's 240 s per-file limit, none of them A3's: `test/screens/settings_screen_test.dart`,
    `test/services/audio/background_music_test.dart`, `test/services/pose/person_behind_video_replay_test.dart`,
    `test/services/pose/pushup_error_cases_test.dart`. Their tests still ran in `flutter test`.
- **Shortfalls:** none. Every layer and the server meet their targets.
- **Manual check (2026-11-23, widget capture, per the spec's section 4):** the real widgets (`GymOwnerFigure` in
  all 12 owner × face pairs, and `GymBackground` 1F–5F with each floor's owner flipped to face left and standing on
  `gymBackgroundFloorLineY`) were captured at 2x in a throwaway widget test and compared by eye with
  `_owners_overview.png` and `_floors_overview.png`: the same pictures, the owners' feet on the floor line, and no
  floor line drawn outside a background. The phone check waits for the map and the hold stage (P16-3, P16).

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/gym_background_art_test.dart` (new) | the Dart string equals `assets/arcade/gym_art.json` character for character; version arcade-art-1, the 140 × 160 box with feet at (70, 150), the 360 × 390 background and floor line 296; the four owners with their names and three faces; the breathing values; the shape counts of spec 4 (701); every owner in `AppColors.opponent`; the 93 faint floor lines; the parser reads matrix, path, colors, line ends and opacity, and the paints it builds (alpha, width, ends, joins), and rejects an unknown command, a wrong count of numbers, a color that is not #RRGGBB, an empty path or command, a bad matrix, line end, join, outline width or opacity, non-object JSON, a missing face and a bad floor; `GymArt.warmUp` builds all 701 paths and paints and can run again; paths and paints are built once; the painter fills then outlines under each matrix, in order, paints a see-through fill and outline at their opacity, scales the window the same both ways and centres it, draws nothing for a lone move, cuts a background at its window while the floor lines run past it unclipped, repaints only on a change; all 17 design shots match, and the comparison catches another face, another floor and a missing shape |
| View | `test/widgets/gym_owner_figure_test.dart` (new) | the size is the 140 × 160 box times its scale; each owner and face draws its own drawing in its box, unclipped; watch by default; an unknown id draws the seal; screen readers hear "체육관 관장 {name}" as an image, without the face; it stands still unless asked to breathe; breathing about the feet (0.988 × 1.02 a quarter into the 2.2 s cycle, 1 at the half, 1.012 × 0.98 at three quarters, the sine in between); no breathing with reduced motion, stopping and restarting when it changes; the clock stops when it leaves the screen; the face centres of spec 3; the faces match the data |
| View | `test/widgets/gym_background_test.dart` (new) | the width it is given and 390/360 of it as height (360, 412, 180); each floor's drawing, cut to its 360 × 390 picture; an unknown floor (0, 6, −1, 42) draws 1F; decoration that screen readers skip; the published size and floor line equal the data |

### Acceptance criteria → tests (the A3 spec, section 4; the local task.md left the step's criteria to the spec)
- Data equals `gym_art.json`, version arcade-art-1 → "is assets/arcade/gym_art.json character for character", "is
  arcade-art-1: owners in a 140 x 160 box standing on (70, 150), backgrounds 360 x 390 with the floor line at y 296"
- Parser rejects an unknown command, a wrong count of numbers, a non-#RRGGBB color, an empty path → "rejects an unknown
  path command", "rejects a command with the wrong count of numbers", "rejects a color that is not #RRGGBB", "rejects an
  empty path or an empty command"
- Shape counts → "has the shape counts of spec 4 (701 in all)"
- Owner size 140·scale × 160·scale; background width × 390/360 → "is the 140 x 160 box times its scale", "takes the
  width it is given and 390/360 of it as height"
- The background draws nothing outside its picture → "with clip, a background shows nothing outside its window; its
  floor lines run past it", "draws its floor, cut to the 360 x 390 picture"
- Unknown owner id and floor → "an unknown owner draws the seal", "an unknown floor draws 1F"
- Accessibility → "screen readers hear "체육관 관장" and the name, not the face", "is decoration: screen readers skip it"
- Breathing stops with reduced motion → "does not breathe when the device asks for reduced motion", "stops and settles
  when reduced motion is turned on, and starts again when it is turned off"; the formula → "breathes about its feet:
  1.2% narrower and 2% taller a quarter into its 2.2 s cycle, back at the half"
- Picture check, 12 owners and 5 backgrounds → "owner_<id>_<face> matches the design but for edges" (12), "floor_<n>
  matches the design but for edges" (5), "the comparison catches a wrong picture (another face, another floor, a
  missing shape)"
- Drawing rules of spec 2 (order, matrix, fill then outline, opacity) → "draws the shapes in order, the later ones on
  top", "fills, then outlines, each shape under its matrix", "paints a see-through fill and a faint outline at their
  opacity, as the floor lines are", "the parser reads a shape: matrix, path, colors, line ends and opacity"
- Public constants of spec 3 → "publishes each owner face centre in its box (spec 3)", "publishes the picture size and
  the floor line of the art data"
- The PM's redeployed task.md, "9개 자산 로딩 확인" (the 9 pictures: 4 owners, 5 floors) → each one rendered and compared
  with its design shot: "owner_<id>_<face> matches the design but for edges" (each owner in its 3 faces, 12 tests) and
  "floor_<n> matches the design but for edges" (5 tests). The art is drawn from Dart data, not loaded as asset files
  (see the PR's Exceptions).

#### 2026-11-23 · code at commit `1dbf9ec` · step A4 `codex/iter5-hold-plank` (Implement high-plank hold stages, team order #8.3)
A4 is the arcade's hold stage, played with the high plank (the local design hand-off's spec `p16-3/SPEC.md` v3, not committed):
- **Common part:** `HoldTimeline` and `HoldJudge` (`lib/services/pose/hold_judge.dart`): the time runs only while the pose
  is held; 0.5 s broken gives a warning and stops it; 0.6 s held runs it again; no new warning while stopped; the second
  warning or the third star ends the stage; an unknown pose keeps the last reading for 1 s, then is off screen; a pose
  set up standing (the chair pose, A5) first has to be held 0.6 s after GO. The frames of the 3·2·1 reach the pose's
  reader only.
- **Pose bundle:** `HoldPoseDefinition` and the one place that picks it, `HoldPoses.of` (`hold_poses.dart`).
- **High plank:** `HighPlankReader` and `highPlankHold` (`high_plank_hold.dart`), with the push-up judge's and the
  setup's own numbers.
- **Screen:** `HoldStageScreen` and `HoldStageViewModel`: briefing, the battle's push-up setup and 3·2·1, holding,
  warnings, clear and fail, and the stars kept by A2's store.

The branch starts at A2's `f074474` and merges A3 (`f45aa9b`, then `32893b5` for `3d7dee8`). I ran these in
`gymrats_app/` on Windows on the code commit, without coverage (this PC's rule):

```sh
flutter pub get
flutter analyze
flutter test
flutter test test/services/pose/hold_judge_test.dart test/services/pose/high_plank_hold_test.dart test/viewmodels/hold_stage_viewmodel_test.dart test/screens/hold_stage_screen_test.dart
```

No camera, ML Kit, server or secure storage is needed: the tests use a scripted `SetupViewModel` over
`FakeCameraService` and `FakePoseEstimator`, scripted pose readers, `MemoryArcadeProgressStore`, `FakeSoundEffects`,
synthetic pose frames (`test/support/pose_fixtures.dart`) and fake clocks (`fakeAsync`, a test-controlled clock).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | CI comment "Tests and coverage (GitHub Actions)" on the A4 PR |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | same CI comment |
| Service | flutter_test, fakes | 85% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not changed by A4 | 11/23 | same CI comment |

- **Tests:** `flutter test` 4074 passed, 0 failed, 10 skipped (2026-11-23, `1dbf9ec`). `flutter analyze` found no issues. The 10 skipped
  tests are the ones already skipped on `main` (a live server smoke test and 9 known push-up judge errors), untouched.
- **New tests:** 106, in the four files below (26 + 32 + 22 + 26). The A4 files with `test/design_tokens_test.dart`:
  172 passed.
- **Other checks:** `ownership_guard.py --check-staged` OK on every commit and `--check-diff` OK on `1dbf9ec`
  (64 paths against `origin/main`, A2's and A3's counted as inherited; the stacked-branch
  intersection with A2's and A3's branches lists only the 18 A4 files and the three personal notes). The rules of `test/design_tokens_test.dart`, run by hand over the five `lib/screens/hold_stage_*.dart` files
  (the test's own list does not include them; it is not an A4 file): no problem.
- **Against the design shots:** the briefing, holding, warning, clear and fail scenes were captured with the app's fonts
  at 360 × 780, 2x, in a throwaway widget test (not committed) and compared by eye with `shots/hold_plank_brief.png`,
  `hold_plank_hold.png`, `hold_plank_warn.png`, `result_holdClear.png` and `result_holdFail.png`. Fixed after the first
  capture: the stage tag stretched across the top, the clock was centred on the screen instead of between the tag and
  the warning marks, and the results sat 28 dp low. After the fixes the scenes match within a few pixels. Where the
  camera picture is, the shots show a gray figure; the app shows the camera, and the figure only while there is no
  picture.
- **Coverage:** TODO(Woohyun Song): copy the CI comment of the A4 PR (commit, run link, per-layer numbers, A4's files).
- **Phone check (spec 9, Galaxy S26+):** TODO(Woohyun Song): with `flutter run -t lib/demo/hold_stage_demo.dart`, open
  STAGE 3 · 1F and try ① 30 s held (clear, 3 stars), ② bent arms, ③ knees down, ④ head down, ⑤ standing up; note
  whether each warning comes with the right words about 0.5 s after the break, and whether the time runs again right
  after fixing it. Write any changed line values here with the reason.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/pose/hold_judge_test.dart` (new) | nothing runs before GO; the time runs between held frames and ends at the third star; a clock going back; broken 0.49 s no warning, 0.5 s a warning and a stop; no time while broken or stopped; held 0.59 s still stopped, 0.6 s running; a break going on while stopped adds no warning; the second warning ends it; the warning's fault is the one read most (the latest of a tie); the fault shown while stopped follows the latest; an unknown pose keeps a held or a broken reading for 1 s, then is off screen; an unknown pose after GO starts nothing; an entry keeps the time at 0 with no warning until 0.6 s held; `HoldJudge` gives the 3·2·1 frames to the reader only, times frames from GO, reads a missing frame as unknown, reads nothing after the end; `HoldFault`, `HoldReading`, `HoldProgress` values |
| Service | `test/services/pose/high_plank_hold_test.dart` (new) | the bundle (push-up setup, no entry, checks, words, icons, figure, guide); the chair pose stopped until A5; the lines are the judge's and setup's (155°, 0.35, 0.6); arms 156° held, 154° bent; hands above the shoulders and an upright body off screen, one hand not seen never; no shoulders, one shoulder, no arm, low likelihood, an empty frame unknown, one arm enough; the head's place from the held frames of the first 0.5 s after GO, never from the 3·2·1, never again; 0.349 held, 0.351 head down; a missing nose waits; knees: the classifier's touching, knees beside the hands at both ends of the judge's range, the hip fold 25° from one plank angle and 20° after three, two kept as their mean, a kneeling start never kept, bent arms read as bent arms; the order of faults; a plank held in a `HoldJudge` to the third star |
| ViewModel | `test/viewmodels/hold_stage_viewmodel_test.dart` (new) | opens on the briefing with its stage, floor and owner; a fight stage and a chair stage are stopped; 자세 잡기 opens the push-up setup once; the setup counting down is the 3·2·1 and a broken pose goes back; 3·2·1 frames reach the reader only, counting; the guide crop and viewport reach the setup check (push-up and squat); GO starts the hold and the guide judge; held to the third star: star cues, the end, 3 stars kept, the camera let go; warning and resumed cues; two warnings before a star is a fail kept as 0; ended by warnings, the stars count the time held; no frame is unknown, then off screen; the clock stands while the camera is not running; a failing store keeps the result; no account keeps nothing; 다시 하기 back to the briefing with a new camera; playing again only after a result; leaving lets the camera go |
| View | `test/screens/hold_stage_screen_test.dart` (new) | the briefing (stage, owner, pose, stars, checks, rule, button) at 412 × 915 and 360 × 780; its back and the system back return `arcade`; the setup in the battle's camera area, the camera switch; the 3·2·1 numbers and the clock at 0:00; the camera failures; GO!, the clock and the green frame, the figure without a camera; the bar and its star marks; each warning (팔 펴요, 무릎 떼요, 머리 들어요, 화면 안으로): 멈춤, red frame, 삐익!, the owner's whistle, a red mark, an amber bar, the reject sound, then gone when held again; the leave dialog (stay, leave = `left`, nothing kept), back asks too, a hold ending while asking; the clear (time, stars, next stage card, buttons, stars kept, `nextStage`); a clear by two warnings; the fail (no star, 경고 2번, buttons, 다시 도전, `arcade`); results at 360 × 780; the next stage names; the chair pose's icon, warnings and figure with a stand-in bundle; the announcements; a fight stage does not open |

### Acceptance criteria → tests (the A4 spec, section 9; the local task.md left the step's criteria to the spec)
- Time and warnings, fake clock → hold_judge_test: 'a broken pose after GO keeps the time at 0, with no warning', 'the
  time starts once the pose is held for 0.6 s' (entry); 'frames of the 3·2·1 reach the reader, not the time or
  warnings'; 'held all along, the hold ends at the third star'; 'broken for 0.49 s gives no warning', 'broken for
  0.5 s gives one warning and stops the time'; 'the time does not run while broken or paused'; 'held for 0.59 s stays
  paused, for 0.6 s runs again'; 'a break that goes on while paused adds no warning'; 'the second warning ends the
  hold'; 'within 1 s an unknown pose keeps a held one: the time runs', 'past 1 s it is off screen, warned 0.5 s
  later'; 'the warning names the fault read most in its run'
- High plank reading → high_plank_hold_test: 'arms at 156° are held, at 154° bent'; 'the head's place is taken from the
  held frames of the first 0.5 s', '0.349 shoulder widths lower is held, 0.351 is the head down'; 'hands above the
  shoulders read as off screen: the user stood up'; 'a frame without the shoulders is unknown'; the knee group ('the
  knee classifier reading touching is knees down', 'knees beside the hands are knees down, far behind them not', 'hips
  folded 25° from the first plank angle are knees down')
- Stars by the time held after two warnings → hold_stage_viewmodel_test 'ended by warnings, the stars count the time
  really held'; hold_stage_screen_test 'a clear by two warnings lights the stars held'
- Screens → hold_stage_screen_test: the briefing, holding and result groups; 'a warning for … stops the clock and
  says …' (4 tests); 'the bar fills toward the third star, its marks light'; 'the leave button asks with the battle's
  dialog'
- Chair icons and figure with a stand-in bundle (spec 3) → 'the chair pose's drawings, with a stand-in bundle' (3 tests)
- Phone check → TODO(Woohyun Song) above.

#### 2026-11-23 · code at commit `1c325ab` · step A4 follow-up on `codex/iter5-hold-plank` (two gaps found while starting A5)
Starting A5 (the chair pose, spec `p16-4/SPEC.md` v2, not committed) showed two things the chair pose needs from A4's
common part. The user chose to fix them on the A4 branch and merge them into A5 (local task.md, A4 Decisions,
2026-11-23):
- **`014e4f0` guide lines from the reader:** the hold ran the setup exercise's rep judge from GO only for its guide
  lines. The squat judge drops a squat 12 s after it starts down (`RepPhase.lost`), and `SquatHeightOverlay` hides on
  `lost`, so the chair pose (held 20 to 45 s) would lose its squat height lines. A reader that also implements
  `HoldGuideReader` (`hold_pose_definition.dart`) now gives the snapshot itself (`HoldJudge.guide`), and the view model
  makes no rep judge for the lines then.
- **`1c325ab` "시작":** a pose entered after GO keeps the time at 0 until first held; a screen reader now hears "시작"
  once when the time begins (`HoldStageCueKind.started`; the chair spec's section 6).
- **Checked, not changed:** the high plank's push-up guide also comes from a rep judge of its own, but the push-up
  judge's 12 s limit (`maxAttempt`) applies only once a push-up starts down; held at the top it stays `up`, and
  `ChestHeightOverlay` draws whenever both shoulders are seen. A new test runs the real judge (`judgeFor`) on the
  hold's clock through a 60 s plank (stage 21) and finds it `up` with its start height (`topShoulderY`) at 5, 15, 30,
  45 and 59.9 s.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): the same as A4's entry above.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | not changed by the follow-up | 11/23 | CI comment "Tests and coverage (GitHub Actions)" on the A4 PR |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the PR's CI comment on `1c325ab` or later | 11/23 | same CI comment |
| Service | flutter_test, fakes | 85% | TODO(Woohyun Song): from the PR's CI comment on `1c325ab` or later | 11/23 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment on `1c325ab` or later | 11/23 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not changed | 11/23 | same CI comment |

- **Tests:** `flutter test` 4080 passed, 0 failed, 10 skipped (2026-11-23, the content of `1c325ab`); the same 10 skips
  as above. `flutter analyze` found no issues. The four A4 test files: 112 passed (110 on `014e4f0` alone).
  `397f498` only rewords one test comment (local reviewer run 5); the four files still pass (112).
- **New tests:** 6, plus one more check in an existing test: `hold_judge_test.dart` 2, `hold_stage_viewmodel_test.dart`
  4, and the "시작" line in `hold_stage_screen_test.dart`'s announcement test.
- **Other checks:** `ownership_guard.py --check-staged` OK on both commits; `--check-diff` OK (64 paths against
  `origin/main`); the stacked-branch intersection with A2's and A3's branches still lists 21 paths (the 18 A4 files and
  the three personal notes).
- **Coverage:** TODO(Woohyun Song): copy the A4 PR's CI comment for this head.

### Test cases added or changed in the follow-up
| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/pose/hold_judge_test.dart` | a reader without guide lines gives none (`readsGuide` false, `guide` null); a `HoldGuideReader` gives its snapshot after each frame |
| ViewModel | `test/viewmodels/hold_stage_viewmodel_test.dart` | a reader that gives the guide lines draws them, and no guide judge is made; the real push-up judge keeps the chest guide through a 60 s plank; an entry's end is one `started` cue, and a later resume is `resumed`; without an entry there is no `started` cue |
| View | `test/screens/hold_stage_screen_test.dart` | the announcement for `started` is "시작" |

#### 2026-11-23 · code at commit `f78ac2b` · step A4, second follow-up on `codex/iter5-hold-plank` (overflows found by the P16 session)
The P16 session found two overflows in A4's result screen (passed on by the user; local task.md, A4 Decisions):
- **The ink button's words** (`HoldDarkButton`: "다음 스테이지", P16's "R1부터 다시") overflowed by 28 px at 360 × 780 with
  1.3x text, and by 12 px at 320 × 640 (48 px with 1.3x text). These are widget-test numbers with the test font,
  whose every glyph is 1 em wide. With the app's font (measured by the reviewer, run 7) the words overflow only at
  320 × 640 with 1.3x text: 5 px for "R1부터 다시", 16 px for "다음 스테이지". The words now sit in a `Flexible`
  `FittedBox` (scale down, one line), in a 4-point side margin that the design's size already leaves free.
- **The result's star row** (`ArcadeResultFrame`, 3 × 92 + 2 × 12 = 300 points) overflowed by 20 px on a 320-wide phone,
  whose content is 280 wide (with any font). The row now sits in a `FittedBox` (scale down).
- Both keep the design's sizes where they fit: at 360 × 780 with 1x text (the design's size), 412 × 915 and 600 × 1000
  the stars and the words are drawn at full size; they shrink only on a narrower phone or with larger text.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): the same as A4's entry above.

- **Before the fix:** the three new screen tests failed with the reported overflows: 28 px (360 × 780, 1.3x); 20 and
  48 px (320 × 640, 1.3x); 20 and 12 px (320 × 640, 1x).
- **Tests:** `flutter test` 4084 passed, 0 failed, 10 skipped (2026-11-23, `f78ac2b`); the same 10 skips as above.
  `flutter analyze` found no issues. The four A4 test files with `test/design_tokens_test.dart`: 182 passed.
- **New tests:** 4, in `test/screens/hold_stage_screen_test.dart`.
- **Other checks:** `ownership_guard.py --check-staged` OK; `--check-diff` OK (64 paths).
- **Review:** local reviewer run 7, APPROVE; it also ran the new tests on the old code (they fail with the reported
  numbers). Its two Minors were fixed before the commit: the side margin above, and the font note above.
- **Coverage:** TODO(Woohyun Song): copy the A4 PR's CI comment for this head.

### Test cases added in the second follow-up
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/hold_stage_screen_test.dart` | 'a clear and a fail fit 360 × 780 at 1.3x text', '… 320 × 640 at 1.3x text', '… 320 × 640 at 1.0x text': a clear and a fail with no overflow (a short phone scrolls to its buttons); 'the frame keeps the design sizes where they fit': `ArcadeResultFrame` with "R1부터 다시" draws its words and its middle star (72) at full size at 600 × 1000, 412 × 915 and 360 × 780, has no overflow at the three sizes, and shrinks the stars at 320 wide and the words at 1.3x text on a 360 phone |

#### 2026-11-23 · code at commit `0579a65` · step A5 `codex/iter5-hold-chair` (Add chair-pose judging, team order #8.4)
A5 adds the second held pose, the chair pose, on A4's hold stage (the local design hand-off's spec `p16-4/SPEC.md` v2,
not committed): the chair reading and the chair pose's bundle (`lib/services/pose/chair_hold.dart`). The screen, the
time and warnings, the icons, the sitting figure and the squat guide are A4's; the bundle only picks them. The user's
answers to the spec's section 9: knees in below 0.8 of the ankles' gap (a fixed line); sitting deeper than a level
thigh is held; no time limit on the entry.
- **Depth:** `SquatRepJudge.update`'s formula, worked in `ChairHoldReader` because that judge drops a squat 12 s after
  it starts down. Its public numbers (`passDepth` 0.75, `minLikelihood` 0.6, `smoothingTau` 65 ms, `baselineTau`
  500 ms) are read from the class; its private literals (0.7 standing, 300 ms, the 0.25 / 0.15 lines of the
  standing thigh's follow) are copied into `ChairLines`.
- **Reading:** unknown without a leg or the standing thigh; hips too high under 0.75 (standing up too); knees in when
  both knees and both ankles are seen and the knees are under 0.8 of the ankles' gap; both: the hips.
- **Earlier-stage files changed, approved by the user (act first, report after):** the chair line of
  `hold_poses.dart`, the demo's chair stages, and the two A4 tests that asserted the chair was stopped.
- **Built on A4's follow-up** (`014e4f0`, `1c325ab`, above): the reader gives the squat lines itself
  (`HoldGuideReader`), and the start after the entry is read as "시작".

The branch starts at A4's `82e281a`; A5's code is `7f26016` and `e1b0a76`, and A4's small-screen fix came in by
`git merge` (`0579a65`), so the runs below are on `0579a65`. I ran these in `gymrats_app/` on Windows on the code commit, without coverage
(this PC's rule):

```sh
flutter pub get
flutter analyze
flutter test
flutter test test/services/pose/chair_hold_test.dart test/services/pose/chair_hold_stage_test.dart
flutter test test/services/pose/chair_hold_test.dart test/services/pose/chair_hold_stage_test.dart test/services/pose/hold_judge_test.dart test/services/pose/high_plank_hold_test.dart test/viewmodels/hold_stage_viewmodel_test.dart test/screens/hold_stage_screen_test.dart
```

No camera, ML Kit, server or secure storage is needed: the tests use synthetic pose frames
(`test/support/pose_fixtures.dart`), the real `SquatRepJudge` and `HoldJudge` on a test clock, and for the screen a
scripted `SetupViewModel` over `FakeCameraService` and `FakePoseEstimator`, `MemoryArcadeProgressStore`,
`FakeSoundEffects` and a camera controller that is never opened.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | not changed by A5 | 11/23 | CI comment "Tests and coverage (GitHub Actions)" on the A5 PR |
| ViewModel | flutter_test, fakes | 90% | not changed by A5 (A4's view model, run with the chair bundle) | 11/23 | same CI comment |
| Service | flutter_test, fakes | 85% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | same CI comment |
| View | flutter_test (widget) | 75% | not changed by A5 (A4's screens, run with the chair bundle) | 11/23 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not changed by A5 | 11/23 | same CI comment |

- **Tests:** `flutter test` 4124 passed, 0 failed, 10 skipped (2026-11-23, `0579a65`). `flutter analyze` found no issues. The 10 skipped tests are
  the ones already skipped on `main` (a live server smoke test and 9 known push-up judge errors), untouched. In the
  notes review's own run (2026-11-24, same commit) one test outside A5 failed once under load,
  `test/services/online/online_battle_integration_test.dart` 'two real Flutter sessions match, exchange avatar pose
  and use server result', and passed twice when run alone; nothing in `lib/services/online/`, its tests or `server/`
  changed here.
- **New tests:** 40, in two files (30 + 10). Two A4 tests changed (the exception above). The two chair files with A4's
  four hold test files: 156 passed.
- **Other checks:** `ownership_guard.py --check-staged` OK on every commit and `--check-diff` OK on `0579a65` (67 paths against `origin/main`, A2's, A3's and A4's counted as inherited). The stacked-branch
  diff against `codex/iter5-hold-plank` lists 7 paths on `0579a65` (the three A5 files and the four approved
  earlier-stage files), and 10 after the notes commit (with the three personal notes).
- **Against the design shots:** the briefing, holding and both warnings of STAGE 5 were captured with the app's fonts
  at 360 × 780, 2x, with the real chair bundle, in a throwaway widget test (not committed), and compared by eye with
  `shots/hold_chair_brief.png`, `hold_chair_hold.png`, `hold_chair_warn.png` and `hold_chair_warn_knees.png`: the pose
  name and icon, the star times, the two checks, the clock, the warning words and icons and the sitting figure match.
  The "삐익!" bubble first looked half its size: it pops in over 0.22 s and the capture was taken in that frame; taken
  0.5 s later it matches. Where the shots draw the "엉덩이" line on the gray figure, the app draws the squat lines over
  the camera (`chair_hold_stage_test.dart` checks them with a camera controller).
- **Coverage:** TODO(Woohyun Song): copy the A5 PR's CI comment (commit, run link, per-layer numbers, A5's file).
- **Phone check (spec 7, Galaxy S26+):** TODO(Woohyun Song): with `flutter run -t lib/demo/hold_stage_demo.dart`, open
  STAGE 5 · 1F and try ① 20 s held (clear, 3 stars), ② lifting the hips midway, ③ knees in, ④ leaving the picture,
  and ⑤ sitting down slowly, over 3–4 s (reviewer A5 run 1: the copied follow rule can lower the standing thigh
  then, so a good pose may read just under 0.75; watch `standingThigh`);
  note whether each warning comes with the right words about 0.5 s after the break, and whether the time runs again
  right after fixing it. In the `flutter run` console the reader prints `chair_hold … depth=… knees=…` twice a second
  (debug builds only): write the depth range of a good chair pose, the knee ratio of a good one and of knees pulled in,
  and any changed line with the reason.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/pose/chair_hold_test.dart` (new) | the bundle (squat setup, entry, checks, words, icons, figure, guide; `HoldPoses.of` on stages 5, 11, 17, 23); the numbers are the squat judge's and one new knee line; the same frames give `SquatRepJudge`'s depth exactly within 12 s, and past 12 s the squat judge drops it while the reader goes on; a frame gap keeps the standing thigh; depth 0.751 held, 0.749 hips too high; standing up is hips too high; a depth over 1 is held; knees 0.79 in, 0.81 held; hips and knees together read as hips; each knee or ankle not seen skips the knees; no leg, an ankle above its knee, or no standing thigh is unknown; the standing thigh from 300 ms standing in the 3·2·1, or after GO, unchanged while seated or halfway up, following slowly while standing; the guide's hips, knees and phases; no lines without a leg; the debug print twice a second; with `HoldJudge` on a fake clock: no time or warning while standing after GO, the start 0.6 s after first held, a hips-too-high and a knees-in warning ending the stage, off screen after 1 s unseen, the third star at 20 s |
| View | `test/services/pose/chair_hold_stage_test.dart` (new) | STAGE 5 with the real bundle: the briefing at 412 × 915 and 360 × 780 (pose, icon, stars, two checks); the squat setup and its standing figure; standing after GO keeps 0:00 in a green frame with no warning; seated, "시작" is read once and the clock runs; the squat lines stay over the camera past 12 s with no squat judge of their own; each warning (더 앉아요, 무릎 벌려요, 화면 안으로): words, icon, red frame, 멈춤, the reject sound, the announcement, and the time running again; held to the third star, a clear with three stars kept |
| Service | `test/services/pose/high_plank_hold_test.dart` (changed, approved exception) | 'the chair pose is A5's bundle, not this one' replaces 'the chair pose is stopped until A5' |
| ViewModel | `test/viewmodels/hold_stage_viewmodel_test.dart` (changed, approved exception) | 'a chair stage opens on A5's chair pose' replaces 'a chair stage is stopped until A5 gives its pose' |

### Acceptance criteria → tests (the A5 spec, section 7; the local task.md left the step's criteria to the spec)
- Depth → chair_hold_test: 'the same frames give the squat judge's depth, within 12 s', 'past 12 s down the squat
  judge drops it; the depth goes on'
- Judging → chair_hold_test: 'a depth of 0.751 is held, 0.749 is the hips too high' (0.75 line), 'knees at 0.79 of the
  ankles' gap are knees in, at 0.81 held' (0.8 line), '… not seen: the knees are not read' (4 tests), 'no leg seen is
  unknown', 'without the standing thigh it is unknown', 'hips under the knees (a depth over 1) are held'
- Standing thigh → chair_hold_test: 'standing in the 3·2·1 takes it after 300 ms', 'not standing in the 3·2·1, it is
  taken after GO', 'it does not change while seated, nor halfway up'
- Entry, fake clock → chair_hold_test: 'standing after GO: the time stays at 0, with no warning', 'seated, the time
  starts 0.6 s after the pose is first held', 'then a warning is A4's: 0.5 s of hips too high, then knees in'
- Screens → chair_hold_stage_test: 'names the chair pose, its stars and its two checks at …' (2 tests); '… the box
  says …' (3 tests: words and icon per reason); '자세 잡기 opens the squat battle's setup and its figure'; 'the squat
  height lines stay over the camera past 12 s'
- Regression → the full `flutter test` above (A4's high plank and the squat battle's tests pass)
- Phone check → TODO(Woohyun Song) above.

#### 2026-11-24 · code at commit `77e1a75` · step A5 follow-up: the standing thigh after GO
The user decided (2026-11-24, local task.md, A5 Decisions) to narrow the spec's "the standing thigh follows while
standing" to the 3·2·1, without waiting for the phone check. `SquatRepJudge`'s rule lets the standing thigh follow
while the depth is under 0.25 and the thigh still counts as standing (at least 0.7 of the shin), which is also true
on the way down; a slow sit therefore lowered it, and a true 0.8 read under 0.75 ("더 앉아요"; reviewer A5 run 1).
- **Now:** the 3·2·1's frames take the standing thigh and follow it as the squat judge's does (the depth parity of
  section 7 holds there); from GO on it is fixed for the play. Without one by GO, the first 300 ms standing after GO
  takes it, once, and it is not followed either.
- This replaces, for frames after GO, the A5 entry's "the standing thigh's follow" above; that entry is kept as it was.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): the same as the A5 entry above.

- **Tests:** `flutter test` 4131 passed, 0 failed, 10 skipped (2026-11-24, `77e1a75`; the same 10 skips as above). `flutter analyze` found no issues. The two chair files: 47
  passed (37 + 10).
- **New tests:** 7 in `test/services/pose/chair_hold_test.dart`; 4 changed (the depth parity test now reads the frames
  as the 3·2·1 does; the 12 s test takes GO at 1 s and expects the real 0.9; the two follow tests run in the 3·2·1).
- **Coverage:** TODO(Woohyun Song): copy the A5 PR's CI comment for this head.
- **Review:** local reviewer A5 run 4, APPROVE; it ran the new tests on the old reader (8 fail) and on a reader that
  never follows (the 3·2·1 tests fail), so both halves of the rule are guarded. Its Minors were fixed before the
  commit (the skips' reason here, two wording lines in the AI notes, a halfway-up step in 'after GO it never
  changes'), except one left for the phone check: a standing thigh taken after GO is taken once, so a user who sat
  through the 3·2·1 and then rises slowly after GO can have it taken before fully up (simulated: a 3 s rise, then a
  true 0.8 reads 0.739). The setup's auto start restarts its count on any frame that is not ready, so the user
  normally stands through the 3·2·1.
- **Phone check:** ⑤ (a slow sit over 3–4 s) now checks this change; the rest as in the A5 entry.

### Test cases added or changed in the follow-up
| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/pose/chair_hold_test.dart` | 'down to 0.8 over 3 s / 4 s / 6 s reads 0.8 and is held, where the squat judge's rule reads under 0.75' (3 tests: the reader's depth is the true 0.8 and held, while `SquatRepJudge` on the same frames reads under 0.75); 'the entry ends and the time runs, with no warning' (a slow sit after GO on A4's `HoldJudge`); 'sitting again slowly after a warning runs the time again'; 'after GO it never changes: standing, halfway up or seated'; 'taken after GO, it is taken once and not followed'; changed: 'the same frames give the squat judge's depth, within 12 s' (as the 3·2·1 reads them), 'past 12 s down the squat judge drops it; the depth goes on' (GO at 1 s, the real 0.9), 'in the 3·2·1 it does not change while seated, nor halfway up', 'in the 3·2·1, standing, it follows slowly' (renamed from the A5 entry's 'it does not change while seated, nor halfway up' and 'standing, it follows slowly', which ran after GO) |

#### 2026-11-23 · code at commit `c8d6044` · step P16 `codex/iter5-ai-opponents` (Build arcade screens, team order #8.5)
P16 builds the arcade's screens on A2's rules and A3's art (P16 spec v2):
- **게임 시작:** two cards, 온라인 대결 and 아케이드 (design `PlayX`); the AI 1v1 card and the 이어하기 row are gone.
- **아케이드 홈:** the building's map with the 24 stages, the stars of 72, the bar with the stage to play, the stage
  sheet.
- **Stages:** a fight through the versus screen and the battle to its clear or fail; a boss match with its intro, R1,
  the break, R2 and the floor cleared (4F: 4층 클리어 with 5F 공사중). Stars are kept per account.
- **Shared screens, values only:** the battle gets the stage's character, AI level, floor rules, floor picture and
  boss round; the versus screen and the report name the stage. Online battles do not change.
- **Not yet:** section 8, the hold stages, waits for `codex/iter5-hold-chair` (A4 and A5) on origin.

The branch starts at `1ae69d1` (A2 `f074474` + A3 `071c7f0`). I ran the commands from the Plan in `gymrats_app/` on
Windows, on `7677fb6` (code `c8d6044`; `7677fb6` only merges A3's two newer note commits), without coverage. Coverage
comes from the PR's CI comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | CI comment "Tests and coverage (GitHub Actions)" |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | same CI comment |
| Service | flutter_test, fakes | 85% | TODO(Woohyun Song): from the PR's CI comment (no service changed) | 11/23 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 11/23 | – |

- **Tests:** `flutter test` 4131 passed, 0 failed, 10 skipped. `flutter analyze` found no issues. The 10 skipped tests
  are the same as on `main` (the live team-server smoke test and 9 known push-up judge errors).
- **Count change:** the 10 new test files hold 128 tests (view model 30, map 13, parts 26, flow 16, home 12, boss 9,
  matchup 9, sheet 6, result frame 4, play card 3). Changed files gained 26 (result screen 6, versus 5, battle 5,
  stage 4, arena 2, theme 2, report 1, exit button 1). In `play_screen_test.dart` and `main_test.dart` 7 AI 1v1 tests
  were replaced by 7 arcade ones (spec 3, 13.1).
- **Bugs the tests found before the phone:** the stage sheet's route semantics asserted (`scopesRoute` without
  `explicitChildNodes`); a band row and a star row overflowed (the design's 1-point gap is between the three stars,
  not after each); the floors' name tags did not show until the first scroll. Each test failed first, then passed.
- **Earlier failing runs, fixed in this step:** the first full run after the play page changed had 20 failing tests
  in `main_test.dart`, `play_screen_test.dart`, `home_screen_test.dart` and `online_lobby_screen_test.dart`: they went
  through the AI 1v1 card, the 이어하기 row or the card name "온라인 1v1". They were rewritten for the arcade, or their
  one line was changed (the two exception files list).
- **Reviewer:** run 1 CHANGES_REQUESTED (4 Major, 5 Minor), run 2 APPROVE with one Minor, fixed. The fixes added 11
  view-model tests (the battle's outcome; the AI level and floor rules handed to the battle).
- **Power loss:** at about 19:50 the laptop lost power during a test run. Afterwards the branch, `index.lock`, the
  diffs and the line endings were checked; nothing was half-written.
- **Other checks:** `ownership_guard.py --check-diff` ok (46 paths, run by the reviewer on the uncommitted tree; the
  commits passed `--check-staged` in the hook). The design-token rules of `test/design_tokens_test.dart` now also
  check the 9 new arcade screen and widget files. Server `pytest` was not run because `server/` did not change.
- **Coverage:** TODO(Woohyun Song): copy the numbers, commit and run link from the PR's CI comment "Tests and coverage
  (GitHub Actions)".
- **Shortfalls:** section 8 (hold stages) is not done: `codex/iter5-hold-chair` is not on origin yet. Until then the
  map's hold stages do nothing, so a player stops at STAGE 3 in the app.
- **Manual check:** TODO(Woohyun Song): on the Galaxy S26+ (spec 12): 1F from the start to the boss once (with the
  hold stages, after section 8), the 2F first stage's fever from 15 s, and the map's stars and locks.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/matchup_test.dart` (new) | `Opponent.arcade`: record name "STAGE n · 캐릭터" and "STAGE n Rk · 캐릭터", character, pace, stage, round; other opponents unchanged; `isArcadeName` |
| ViewModel | `test/viewmodels/arcade_viewmodel_test.dart` (new) | progress per account, a failed read, a late answer dropped, refresh, sign-out; `record` keeps the most stars, a failed store keeps the progress; boss run; stage request; `finishBattle` for every fight and boss case and outside the arcade; `rulesOf`, `botOf`, `battleOf`; `ArcadeWords` |
| View | `test/screens/arcade_screen_test.dart` (new) | header only while reading; 17 of 72 stars; the bar; first scroll (STAGE 8 in the middle, STAGE 1 at the end, all cleared at the top); the sheet; cell taps (fight, hold hook, boss, locked); back from a stage reads again and opens the stage asked for; tap targets and labels |
| View | `test/screens/arcade_flow_test.dart` (new) | fight won by KO, lost, draw; 다시 도전, 아케이드로, back, 다음 스테이지; boss R1 lost, break then R2 lost, both won with the next floor open, 4F with 5F and the map at the top, R1부터 다시, R2 without R1; leave, replay |
| View | `test/screens/arcade_boss_screen_test.dart` (new) | intro: owner, rounds, star conditions lit by the best, 자세 잡기 to R1, back; break: score, R2 next, no rest timer, 자세 잡기 to R2, 그만하기 and back; tap targets |
| View | `test/widgets/arcade_map_test.dart` (new) | `ArcadeMapLayout` numbers, places, cell sizes, first scroll; a new account, STAGE 8 with 3F and 4F locked, 5F from the start, grey locked floors, taps, the user idling or celebrating, floor tags, HOLD and BOSS tags |
| View | `test/widgets/arcade_parts_test.dart` (new) | every glyph draws; star fill; face crop; white outline; mirrored figures; buttons; star goals and result stars; score line; title band; round pip; stripes; pedestal |
| View | `test/widgets/arcade_stage_sheet_test.dart` (new) | STAGE 8's sheet, 1F without a rule chip, stars lit by the best, 닫기 and 도전, route name |
| View | `test/widgets/arcade_result_frame_test.dart` (new) | the fail frame, the lost stand, a stand of its own, a short screen scrolls |
| View | `test/widgets/arcade_play_card_test.dart` (new) | the two cards' size, taps, arrow colors, labels |
| View | `test/screens/play_screen_test.dart` (updated) | two cards, no AI 1v1 or 이어하기, the PlayX pictures, the online card's fixed GYM마우스, the arcade card opens the arcade |
| View | `test/screens/versus_screen_test.dart` (updated) | an arcade stage: STAGE n, 아케이드로, the character with AI LV n, 자세 세팅 시작, leaving to the map; a bot outside the arcade unchanged |
| View | `test/screens/battle_screen_test.dart` (updated) | the stage's character on its floor's gym named by the character; the boss round on the stage and the camera; leaving ends the boss run; the end opens the arcade's clear and keeps stars; nothing added outside the arcade |
| View | `test/screens/result_screen_test.dart` (updated) | an arcade report: no scene, the record's name, 홈으로 and back to the map, 다시 대결 replays a fight or opens the boss intro, a past arcade record opens the arcade |
| View | `test/widgets/battle_stage_test.dart`, `battle_arena_test.dart` (updated) | the ROUND chip, fever and before the start; the floor picture over the grid and under the fever; passed through the arena; none online |
| View | `test/widgets/result_report_test.dart`, `exit_game_button_test.dart` (updated) | an arcade bot's name in the report; the 아케이드로 label |
| Design | `test/theme/app_theme_test.dart`, `test/design_tokens_test.dart` (updated) | the arcade's color and text tokens; the new files use tokens only |
| App flow | `test/main_test.dart` (updated) | 게임 시작 → 아케이드 → STAGE 1's sheet → versus → leaving returns to the map; STAGE 2 once STAGE 1 has a star; the matching page by its route; back steps; the online sheet's best |
| View | `test/screens/home_screen_test.dart`, `online_lobby_screen_test.dart` (updated) | the play page reads home's view model; the online card's new name |

### Acceptance criteria → tests (spec 12; the local task.md left the step's criteria to the spec)
- 게임 시작: two cards, the arcade card opens the arcade, no AI 1v1, online as before → 'shows the two cards and the rules, no AI 1v1 and no again row (P16 spec 3, 13.1)', 'the arcade card opens the arcade', 'the online card asks for the exercise, then opens the lobby'
- 홈: first progress, STAGE 8, all cleared → 'a new account: only STAGE 1 is open, and it is the one to play', 'STAGE 8: 1 to 7 with their stars, 3F and 4F locked (spec 12)', 'all 24 cleared: no bar, 72 stars, at the top with 5F'
- 홈: taps, star total, first scroll → 'cells: a played fight opens its sheet again, a boss its intro, a hold the hold screen; a locked one nothing (spec 4)', 'STAGE 8: 17 of 72 stars, and the bar with the stage to play (design ArcMap cur)', 'it opens with the stage to play about the middle of the map (spec 4)'
- 대결 판: versus, values handed, win, loss, 다시 도전, 다음 스테이지 → 'the header says STAGE n and the exit 아케이드로', 'the stage's character fights on its floor's gym, named by its character', 'rulesOf: the stage's floor's rules; outside the arcade the default', 'botOf: the stage's AI level; outside the arcade the chosen level', 'won by KO: 클리어!, the stars got, the next stage's card, and the stars kept', 'lost: 실패 with the score and no star; no star is kept', '다시 도전 opens the versus again over the map', '다음 스테이지 opens the next stage over the map: a fight's sheet, a hold's screen'
- 보스 매치: R1 lost, break and 그만하기, R2 lost, both won, 4F → 'R1 lost ends it: R1 패배, R2 locked, no stars', '그만하기 and back end the match: the map, no stars', 'R1 won: the break; R2 lost: R2 패배 with R1 checked', 'both won: n층 클리어!, the rounds, the next floor open; {n+1}층으로 opens its first stage', '4F: 4층 클리어! with 5F 공사중, and the map at the top (spec 1.6)'
- Online regression → 'without them, as online, neither is there', 'outside the arcade nothing is added to the stage', 'a bot outside the arcade keeps "AI" and 게임 나가기', and the full suite
- Phone check → TODO(Woohyun Song) (above)

#### 2026-11-23 · code at commit `8b975cf`, merged with A4 in `6074bf4` · step P16 `codex/iter5-ai-opponents`, section 8 and the results on A4's frame
After the first push the user chose not to wait for A5. A4 (`codex/iter5-hold-plank`, PR #90) was merged in
(`f9d1eba`, then `6074bf4` for A4's four follow-up commits), and:
- **Section 8, hold stages:** a hold cell opens A4's `HoldStageScreen` with the arcade's store, account and the
  user's character; its 다음 스테이지 reads the progress again and opens the next stage on the map.
- **Chair stages (5, 11, 17, 23) as high plank until A5:** only the way in changes (`ArcadeFlow.holdScreen`); the
  stage data, star seconds included, stay. A4's briefing still says "의자 자세" over the plank figure. Remove with A5.
- **Results on A4's frame (spec 6):** the fight and boss results use A4's `ArcadeResultFrame`; P16's interim frame
  (`lib/widgets/arcade_result_frame.dart`) and its test are deleted.
- **Boss screens scroll (reviewer run 3):** the intro and the break fill the view and scroll on short phones and
  with large text.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `6074bf4`, without coverage. Coverage comes from
the PR's CI comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | CI comment "Tests and coverage (GitHub Actions)" |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | same CI comment |
| Service | flutter_test, fakes | 85% | TODO(Woohyun Song): from the PR's CI comment (no P16 service) | 11/23 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 11/23 | – |

- **Tests:** `flutter test` 4250 passed, 0 failed, 10 skipped (the same 10 as on `main`). `flutter analyze` found
  no issues.
- **Count change since `c8d6044`:** P16's new test files now hold 131 tests (128 before): `arcade_flow_test.dart` +3
  (hold stages), `arcade_screen_test.dart` +3 (a hold's 다음 스테이지, a hold left, the app's own way into a hold),
  `arcade_boss_screen_test.dart` +2 (a short phone, large text), `arcade_parts_test.dart` -1 (the removed result
  stars), `arcade_result_frame_test.dart` -4 (deleted with its frame). A4's tests come with the merges.
  `test/design_tokens_test.dart` now also checks A4's five `lib/screens/hold_stage_*.dart` files; they already pass
  (an exception, user decision 2026-11-23).
- **Bugs the tests found:** at 360 x 640 and with 1.3x text the boss screens' buttons were cut off (reviewer run 3).
  The new tests failed first, and also showed the break's score line overflowing at 1.3x; it now scales down.
- **Reviewer:** run 3 CHANGES_REQUESTED (1 Major, 4 Minor), run 4 APPROVE with 3 Minor. The character test now checks
  a chosen character, and A4's follow-up commits were merged; the third is below.
- **Known, in A4's files (not changed here):** with 1.3x text on 360 x 780, the label of A4's dark button
  (`HoldDarkButton`) overflows by 28 px with "R1부터 다시" and "다음 스테이지" (12 px on 320 x 640), and the frame's star
  row (three 92-wide columns) overflows by 20 px on a 320-wide phone. Found by the reviewer's own layout check and
  reported for A4's branch; once it is fixed there, a P16 test at these sizes on `ArcadeResultScreen` can guard it.
- **Other checks:** `ownership_guard.py --check-diff` ok (105 paths, after `6074bf4`). Server `pytest` was not run
  because `server/` did not change.
- **Coverage:** TODO(Woohyun Song): copy the numbers, commit and run link from the PR's CI comment "Tests and coverage
  (GitHub Actions)".
- **Manual check:** TODO(Woohyun Song): on the Galaxy S26+ (spec 12): 1F from STAGE 1 to the boss with STAGE 3 on
  A4's screen and its stars on the map, a chair stage opening as high plank (the briefing says "의자 자세"), the 2F
  first stage's fever from 15 s, the map's stars and locks, and the boss screens with large text.

### Test cases added or changed in this phase
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/arcade_screen_test.dart` (updated) | a hold's 다음 스테이지 reads the progress again and opens the next stage; a hold left stays on the map; the app's own way into a hold: A4's screen for the stage with the arcade's store, account and the chosen character |
| View | `test/screens/arcade_flow_test.dart` (updated) | a plank stage opens A4's screen as it is; a chair stage runs as a high plank with its data unchanged; every chair stage and no plank stage takes the fallback; the results in A4's frame, each star read on its own |
| View | `test/screens/arcade_boss_screen_test.dart` (updated) | the intro and the break at 360 x 640 and with 1.3x text: no overflow, the buttons reachable |
| View | `test/widgets/arcade_parts_test.dart` (updated) | the result stars' test removed with them |
| View | `test/widgets/arcade_result_frame_test.dart` (deleted) | deleted with the interim frame (spec 6: A4's frame) |
| Design | `test/design_tokens_test.dart` (updated) | A4's five hold screens added to the checked files; the interim frame removed |

### Acceptance criteria → tests (spec 8 and 6)
- A hold cell opens A4's screen with the arcade's store and account → 'the app's own way into a hold: A4's screen for
  the stage, with the arcade's store, account and the user's character', 'a plank stage opens A4's screen as it is,
  with the arcade's store and account'
- A hold's 다음 스테이지 opens the next stage; leaving stays on the map → 'a hold's 다음 스테이지 reads the progress
  again and opens the stage after it (spec 8)', 'a hold left by 아케이드로 or mid-stage stays on the map'
- Chair stages as high plank until A5 → 'until A5, a chair stage runs as a high plank; its data stay', 'every chair
  stage takes the fallback, no plank stage does'
- Fight and boss results on A4's frame → 'won by KO: 클리어!, the stars got, the next stage's card, and the stars
  kept', 'lost: 실패 with the score and no star; no star is kept' (both find `ArcadeResultFrame`)
- Boss screens on small phones and large text → 'fits $label without overflow, scrolling to its buttons' (run for
  "a short phone" and "a large text size")
- Phone check → TODO(Woohyun Song) (above)

#### 2026-11-24 · code at commit `b03ca98`, merged with A5 in `0deb979` · step P16 `codex/iter5-ai-opponents`, the chair stages on A5
A5 (`codex/iter5-hold-chair`, PR #92) came up with A4's newer commits in it, including A4's fix for the two result
overflows (`f78ac2b`). It was merged in (`0deb979`; the three notes kept every step's section), and:
- **Chair stages on the chair pose:** the high-plank stand-in for STAGE 5, 11, 17 and 23 is removed. A4's screen now
  judges each stage's own pose (`HoldPoses.of(stage.pose)`: A5's chair pose or A4's high plank).
- **The results on small screens:** a new test runs the five arcade results (fight cleared and failed, boss failed in
  R2, floor cleared, 4F cleared) on a 320 x 640 phone and with 1.3x text on 360 x 780, and reaches every button.

I ran the commands from the Plan in `gymrats_app/` on Windows, without coverage. Coverage comes from the PR's CI
comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/24 | CI comment "Tests and coverage (GitHub Actions)" |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/24 | same CI comment |
| Service | flutter_test, fakes | 85% | TODO(Woohyun Song): from the PR's CI comment (no P16 service) | 11/24 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment | 11/24 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 11/24 | – |

- **Tests:** `flutter test` 4312 passed, 0 failed, 10 skipped (the same 10 as on `main`). `flutter analyze` found
  no issues.
- **Count change since `8b975cf`:** P16's new test files now hold 142 tests (131 before): the new
  `arcade_result_screen_test.dart` 10, `arcade_screen_test.dart` +1 (a chair stage on the chair pose). In
  `arcade_flow_test.dart` the two stand-in tests were replaced by two that check no hold stage gets a stand-in. A5's
  tests come with the merge.
- **The new test against the old frame:** with A4's result files from before `f78ac2b` put back for one run (then
  restored), 7 of the 10 result tests failed with overflows of 28, 20 and 12 px; all pass on the merged tree.
- **Reviewer:** run 5 APPROVE with one Minor (progress.md still described the stand-in; updated). It checked that no A2–A5 file is changed and that the merge kept every line of both sides of the three notes.
- **Other checks:** `ownership_guard.py --check-diff` ok (109 paths). Server `pytest` was not run because `server/`
  did not change.
- **Coverage:** TODO(Woohyun Song): copy the numbers, commit and run link from the PR's CI comment "Tests and coverage
  (GitHub Actions)".
- **Manual check:** TODO(Woohyun Song): on the Galaxy S26+ (spec 12): as above, with STAGE 5 on the chair pose.

### Test cases added or changed in this phase
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/arcade_result_screen_test.dart` (new) | the five arcade results on a 320 x 640 phone and with 1.3x text: no overflow, every button reachable |
| View | `test/screens/arcade_screen_test.dart` (updated) | a chair stage opens the hold screen with the chair pose (A5), not a stand-in |
| View | `test/screens/arcade_flow_test.dart` (updated) | a chair stage opens A4's screen as it is; no hold stage gets a stand-in view model |

### Acceptance criteria → tests (spec 8 with A5)
- Chair stages on the chair pose → 'a chair stage opens the hold screen with the chair pose (A5), not a stand-in',
  'a chair stage opens A4's screen as it is too, which judges the chair pose (A5)', 'no hold stage gets a stand-in
  view model: each runs its own pose'
- Results on small phones and large text → '$name fits ${size.width.toInt()} x ${size.height.toInt()} with
  ${scale}x text, every button reachable' (5 results x 2 sizes)
- Phone check → TODO(Woohyun Song) (above)
