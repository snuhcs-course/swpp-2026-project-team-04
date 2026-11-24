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
- **Phone check (spec 9, Galaxy S26+), done 2026-11-24** by the user (the user's message of 2026-11-24 02:52, logged
  in A5's Prompt Log under `codex/iter5-hold-chair`), with `lib/demo/hold_stage_demo.dart` built from the worktree's
  HEAD then, A5's `e17e332`, which holds A4's code up to `4ef8a2f` (the one-arm fix). The USB cable was out, so no console numbers were seen. STAGE 3 · 1F: ① 30 s held: a
  clear; ② one arm bent: "팔 펴요"; ④ head down: "머리 들어요"; after fixing, the time ran again; a second warning: the
  fail. ③ knees down and ⑤ standing up were tried as the second warning: the stage failed at the right moment, but it
  went straight to the fail screen before their words could be read. Each warning came almost at once (the user's
  words; with the cable out, the 0.5 s itself was not measured). No line value changed. The missing reason at a second warning is fixed by the
  effects (entry `3ffed5f` below: the owner's "실패!" for 1.5 s with the warning's words kept, then the reasons as
  chips on the fail screen); ③'s and ⑤'s words are seen again in the last phone check (TODO in that entry).

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
- Phone check → above (2026-11-24); the effects' phone check is the last TODO, in the effects entry below.

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

#### 2026-11-24 · code at commit `4ef8a2f` · step A4, third follow-up on `codex/iter5-hold-plank` (one arm bent, Codex review)
The Codex review of PR #90 at `be6509a` (P2, "Check each arm against the plank angle") found that the high plank's
arms-bent check used `PoseMetrics.elbowAngle`, the mean of the two arms: one arm at 180° and the other at 130° make
155°, which passed, so a user could hold with one arm bent and earn time and stars. The user had it fixed on A4's
branch (local task.md, A4 Decisions, 2026-11-24):
- **Now:** each arm seen is measured alone (`PoseMetrics.leftElbowAngle`, `rightElbowAngle`, each there only when its
  shoulder, elbow and wrist reach the judge's likelihood line), and the less straight one under the setup's 155° is
  arms bent; with one arm seen, that one. It is chosen in `high_plank_hold.dart`; `pose_metrics.dart` is unchanged.
  The other straight-arm checks (the knees, the hip fold, the plank angle kept) keep the judge's mean.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): the same as A4's entry above.

- **Before the fix:** the two new tests of a bent arm failed on the old reader; the third (one arm seen) passes on both,
  since the mean of one arm is that arm, and guards the new one-arm path.
- **Tests:** `flutter test` 4087 passed, 0 failed, 10 skipped (2026-11-24, `4ef8a2f`; the same 10 skips as above). `flutter analyze` found no issues.
  `test/services/pose/high_plank_hold_test.dart`: 35 passed.
- **New tests:** 3, in `test/services/pose/high_plank_hold_test.dart`.
- **Other checks:** `ownership_guard.py --check-staged` OK; `--check-diff` OK (64 paths); the stacked-branch
  intersection with A2's and A3's branches still lists 21 paths.
- **Review:** local reviewer A4 run 8, APPROVE. It checked the test geometry by hand (the spliced arm keeps the
  shoulder width and the hands under the shoulders) and that keeping the mean for the other straight-arm checks
  loses no fault: a frame with one arm under 155° is still broken (at most it reads "무릎 떼요" first, when the hips
  are folded too), as the push-up judge also uses the mean for its top and the smaller arm only for its lockout. Its
  Minors were fixed before the commit: two comments named the review as "Codex review on A4" (now "PR #90 review"),
  and this entry lacked these two lines.
- **Coverage:** TODO(Woohyun Song): copy the A4 PR's CI comment for this head.

### Test cases added in the third follow-up
| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/pose/high_plank_hold_test.dart` | 'one arm bent, 180° and 130°, is arms bent though the mean is 155°' (either side; the metrics' mean is 155°); 'the less straight arm decides: 156° held, 154° bent' (the other arm at 180°); 'with one arm seen, that arm decides' (the right elbow and wrist unseen: the left at 180° held, at 130° bent) |

#### 2026-11-24 · code at commit `3ffed5f` · step A4, effects on `codex/iter5-hold-plank` (the user's picks after the phone check)
After the phone check of 2026-11-24 the user picked the hold stage's effects on the design canvas (local spec
`p16-3-fx/SPEC-FX.md`, not committed; local task.md, A4 Decisions, 2026-11-24). All new times are in `HoldTiming`:
- **Music:** the battle's tracks at the battle's moments, through the same `SoundServices.music` and `MusicCue`s:
  `setup` through the setup and the 3·2·1, `battle` while holding, the `win` or `lose` jingle as the stage ends
  (at a second warning's moment already, as a battle's jingle starts when it ends), and `menu` when the stage is left
  before a result. The battle's `BattleSounds` takes a `BattleStageState`, so the hold
  screen picks the same cues itself; no music or battle file changed.
- **Start bubble (C1):** right after GO the owner's white bubble, as "삐익!"'s, says the pose's start words
  (`HoldPoseDefinition.startWords`; the high plank's "그대로 버텨!") for `startBubble` (2 s), or until the time starts
  for a pose with an entry. A warning takes its place.
- **Stars (B2 revised + sound):** at the first and second star the star pops on the bar (`starPop`, 0.3 s; not with
  reduced motion), the owner smiles (`GymOwnerFace.ok`) behind a big lime bubble "좋아!" / "잘한다!" for `cheer`
  (1 s), its right end per owner as the design's `bubR`, and the app's short `SoundEffect.good`
  (`assets/audio/sfx_hit_good.wav`) plays. The third star is the clear. A warning takes the bubble's place.
- **Second warning (A2 + A3, shown as F4):** the owner's big red "실패!" (the cheer's widget, its color and words
  changed) comes in big and settles (`failPop`, 0.2 s) in place of "삐익!"; the camera box keeps the warning's words,
  the clock says "멈춤", nothing is judged for `endShow` (1.5 s), then the fail screen lists the two warnings' reasons
  as red chips in order where "경고 2번" was. A clear ended by warnings (a star already earned) keeps "삐익!" for the
  same 1.5 s, with the win jingle, then shows the clear: a call beyond the spec that the user kept (2026-11-24, local
  task.md, A4 Decisions), as "실패!" on a clear would not match the clear screen after it.
  This fixes what the phone check of 2026-11-24 found (A4 entry above): a second warning went straight to the fail
  screen, so its reason could not be read.
- **Screen reader:** the start words and "실패!" are announced as the warnings are (a `callout` cue), and the first two
  stars' announcements end with their cheer.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): the same as A4's entry above.

- **Tests:** `flutter test` 4109 passed, 0 failed, 10 skipped (2026-11-24, `3ffed5f`; the same 10 skips as above). `flutter analyze` found no
  issues. The four A4 test files with `test/design_tokens_test.dart`: 207 passed.
- **New tests:** 22 (view model 8, screen 14). Changed for the new behavior: the start words' cue in two
  cue lists, the result after `endShow` in four screen test bodies (six runs, with the size cases) and one view model
  test, the reasons in place of "경고 2번" in the fail test, and the stars' announcements with their cheer.
- **Other checks:** `ownership_guard.py --check-staged` OK; `--check-diff` OK (64 paths); the stacked-branch
  intersection with A2's and A3's branches still lists 21 paths.
- **Review:** local reviewer A4 run 9, CHANGES_REQUESTED: the result jingle came 1.5 s after a second warning, while a
  battle's starts when it ends (now at once), and the local design-doc list lacked the new API (added); Minors: a
  screen check that could not fail (now: the frames in the moment are not read), and this entry's counts and lines.
  The clear ended by warnings (no "실패!") was the session's call: said in the PR and asked of the user, who kept it
  on 2026-11-24. Run 10: APPROVE (all fixed; no new code finding).
- **Coverage:** TODO(Woohyun Song): copy the A4 PR's CI comment for this head.
- **Phone check of the effects (the last phone check):** TODO(Woohyun Song): with the demo, see the start bubble, both
  cheers with the star pop and the sound, the fail bubble with the warning kept, the reasons on the fail screen (also
  for ③ knees down and ⑤ standing up as the second warning, whose words the first check could not read), a clear
  ended by warnings ("삐익!", the win jingle, the clear), and the music through a stage and after leaving.

### Test cases added in the effects follow-up
| Layer | File | What it covers |
|---|---|---|
| ViewModel | `test/viewmodels/hold_stage_viewmodel_test.dart` | 'GO shows the pose's start words for 2 s, read out'; 'with an entry the start words stay until the time starts'; 'a warning takes the start bubble'; 'the first two stars are cheered for 1 s, the third is not'; 'a warning takes the cheer'; 'a second warning with no star: 실패! for 1.5 s, nothing judged'; 'a second warning after a star: the whistle stays, then a clear'; 'leaving in the moment shows no result and keeps nothing' |
| View | `test/screens/hold_stage_screen_test.dart` | 'GO: "그대로 버텨!" in the white bubble for 2 s, read out'; 'a warning takes the start bubble's place'; 'the first and second stars: a lime cheer, a smile, a pop and the good sound, once each'; 'the cheer ends at the owner on every floor' (142, 140, 150); '"잘한다!" fits 360 × 780 at 1.3x text / 320 × 640 at 1.3x / 320 × 640 at 1.0x'; 'with reduced motion the stars do not pop'; 'a warning takes the cheer's place'; 'a second warning with no star: "실패!" over the stage, the warning kept below for 1.5 s, then the reasons in order'; 'the battle's music at the battle's moments'; 'a second warning with no star plays the lose jingle at once'; 'a clear ended by warnings plays the win jingle at once'; 'leaving before a result brings the menu music back'; the size tests 'a clear and a fail fit …' now also see "실패!" |

#### 2026-11-24 · code at commit `3ffed5f` (notes only) · step A4: the phone check and the user's answers
No code changed. The user's phone check of 2026-11-24 went into A4's entry above (spec 9, with the build it ran),
and the user's answer on a clear ended by warnings into the effects entry (local task.md, A4 Decisions, 2026-11-24).

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): the same as A4's entry above.

- **Tests:** `flutter analyze` found no issues. `flutter test` 4109 passed, 0 failed, 10 skipped (2026-11-24, on
  `47ea0d1`, the code of `3ffed5f`; the same 10 skips as above). The first full run had one failure outside A4:
  `test/services/online/online_battle_integration_test.dart`, 'the game on the phones +5 AVERAGE shows at once; the
  same answer keeps it, and a third phone's average rep reads as average'. It is an intermittent failure outside A4;
  its cause was not found (that run kept only the summary, not the failure message). The file then passed twice alone
  (60 tests each time), and the full rerun passed. Nothing in `lib/services/online/`, its tests or `server/` changed
  here. Plan: watch it in the PR's CI run; it is not A4's file, so it is left to that file's owner if it fails again.
- **Review:** local reviewer A4 run 11, APPROVE; its five Minors were fixed before the commit (two references a reader
  of this branch could not follow, the timing note, this failure's reason and plan, the local status row).
- **Coverage:** TODO(Woohyun Song): copy the A4 PR's CI comment for this head.

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

#### 2026-11-24 · code at commit `4767873` · step A5: the chair pose's start bubble (A4's effects merged)
A4's hold effects (`3ffed5f`, its entry above) came in by `git merge` (`37e987c`; the notes' add/add conflicts kept every
entry). The chair pose's part (the effects spec 3 and 7): its start words "스쿼트 자세로" / "버텨!" on two lines
(`chairHold.startWords`), shown from GO and gone when the time starts, when "시작" is read.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): the same as the A5 entry above.

- **Tests:** `flutter test` 4159 passed, 0 failed, 10 skipped (2026-11-24, `4767873`; the same 10 skips as above). `flutter analyze` found no
  issues. The two chair files: 50 passed (37 + 13).
- **New tests:** 3 (the size cases); 3 changed: the bundle test checks the two lines, and the two entry tests now see
  the bubble and hear "스쿼트 자세로 버텨!" before "시작".
- **Other checks:** `ownership_guard.py --check-staged` OK; `--check-diff` OK (67 paths).
- **Review:** local reviewer A5 run 5, APPROVE; its Minors fixed before the commit (stronger size checks, these
  lines, the Prompt Log's order).
- **Coverage:** TODO(Woohyun Song): copy the A5 PR's CI comment for this head.
- **Phone check of the start bubble:** TODO(Woohyun Song): STAGE 5 · 1F, the two lines from GO while standing and
  sitting down, gone when the time starts.
- **Acceptance criteria → tests (the effects spec, the chair's part):** 6.1 shown while entering and gone at the
  start → 'standing after GO: 0:00, 버틴 시간, a green frame, no warning', 'seated, the time starts with "시작" and
  runs'; 6.5 sizes → 'the two-line start bubble and "좋아!" fit …' (3 tests); 6.6 read out → the `said` checks in the
  same two entry tests.

### Test cases added or changed for the start bubble
| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/pose/chair_hold_test.dart` | 'is set up as a squat, entered after GO, with its own words' now checks `startWords` |
| View | `test/services/pose/chair_hold_stage_test.dart` | 'standing after GO: 0:00, 버틴 시간, a green frame, no warning' (the two lines shown and read); 'seated, the time starts with "시작" and runs' (the bubble goes when the time starts); 'the two-line start bubble and "좋아!" fit 360 × 780 at 1.3x text / 320 × 640 at 1.3x / 320 × 640 at 1.0x' (new) |
