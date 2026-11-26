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
| Model | flutter_test | 90% | 99.4% (841/846), CI on `dc5947b` (this code with `main` merged) | 11/24 | CI comment "Tests and coverage (GitHub Actions)" |
| ViewModel | flutter_test, fakes | 90% | 98.3% (1898/1930; no ViewModel changed), same run | 11/24 | same CI comment |
| Service | flutter_test, fakes | 85% | 97.5% (4796/4920), same run | 11/24 | same CI comment |
| View | flutter_test (widget) | 75% | 98.1% (11320/11542; no View changed), same run | 11/24 | same CI comment |
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
- **Coverage:** from the CI comment "Tests and coverage (GitHub Actions)" on PR #89's head `dc5947b` (this code
  with `main` merged in `da3a039`, the entry below, and a notes commit; 2026-11-24 13:19 KST; app and server jobs
  both succeeded; [run 45324655059](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/45324655059)):
  the table above; app total 98.0% (19235/19635), Other 95.7% (380/397); `flutter test` there 4034 passed,
  10 skipped, 0 failed; server 97% (157 passed). `test/screens/settings_screen_test.dart` timed out in the
  per-file coverage run, so its lines are not in the numbers (its tests ran; not an A2 file).
- **Shortfalls:** none: every layer is above its target (CI, above).
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

#### 2026-11-24 · merge `da3a039` of `origin/main` `69b0520` · step A2: `main` merged in before the draft ends
At the user's word (2026-11-24; the prompt is logged on A4's branch, `codex/iter5-hold-plank`), `origin/main` (#86 setup timeout, #93 Google
sign-in, #94 zero points for knee push-ups) was merged into this branch first, before the steps stacked on it. No
conflict: no file changed on `main` since `ad8a6f7` is one of A2's. A2's code is unchanged at `141c8df`.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter pub get` (#93 added a package),
`flutter analyze`, `flutter test`.

- **Tests:** `flutter analyze` found no issues. `flutter test` 4034 passed, 0 failed, 10 skipped (2026-11-24, on
  `da3a039`; the same 10 skips as above). The bot pins pass on the merged code.
- **Other checks:** `ownership_guard.py --check-diff` OK (21 paths against `origin/main`, as before). Server `pytest`
  was not run: `server/` is `main`'s, unchanged by A2, and `main`'s own checks cover it.
- **Coverage:** PR #89's CI comment on `dc5947b` (this merge and a notes commit; [run 45324655059](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/45324655059)):
  Model 99.4%, ViewModel 98.3%, Service 97.5%, View 98.1%, total 98.0%, all above target; the numbers are in
  the first A2 entry's table.

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

#### 2026-11-24 · merge `f482e99` of `origin/main` `69b0520` · step A3: `main` merged in before the draft ends
At the user's word (2026-11-24; the prompt is logged on A4's branch, `codex/iter5-hold-plank`), `origin/main`
(#86 setup timeout, #93 Google sign-in, #94 zero points for knee push-ups) was merged into this branch before the
steps stacked on it. No conflict: no file changed on `main` since this branch's base is one of A3's. A3's code is
unchanged.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter pub get` (#93 added a package),
`flutter analyze`, `flutter test`.

- **Tests:** `flutter analyze` found no issues. `flutter test` 3970 passed, 0 failed, 10 skipped (2026-11-24, on
  `f482e99`; the same 10 skips as `main`'s: a live server smoke test and 9 known push-up judge errors).
- **Other checks:** `ownership_guard.py --check-diff` OK (28 paths against `origin/main`). Server `pytest` was not run: `server/` is `main`'s,
  unchanged by A3, and `main`'s own checks cover it.
- **Coverage:** from the CI comment "Tests and coverage (GitHub Actions)" on PR #88's head `c1f5f5f` (this merge
  and a notes commit; 2026-11-24 13:25 KST; app and server jobs both succeeded;
  [run 45325092621](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/45325092621)): Model 99.3% (733/738), ViewModel 98.3%
  (1898/1930), Service 97.4% (4738/4862), View 98.1% (11533/11756), Other 95.7% (380/397), total 98.0%
  (19282/19683), all above target; `flutter test` there 3970 passed, 10 skipped, 0 failed; server 97% (157
  passed). `test/screens/settings_screen_test.dart` timed out in the per-file coverage run, so its lines are not
  in the numbers (its tests ran; not an A3 file). A3's own files were not split out for this run; its code is
  unchanged since `071c7f0` (99.5% above).

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #90's base is `codex/iter5-arcade-stages`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
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
- Phone check → above (2026-11-24); the effects' phone check, done at the last phone check, in the effects entry below.

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #90's base is `codex/iter5-arcade-stages`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #90's base is `codex/iter5-arcade-stages`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #90's base is `codex/iter5-arcade-stages`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #90's base is `codex/iter5-arcade-stages`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Phone check of the effects: the last phone check, done 2026-11-24 22:21–22:25** by the user on the Galaxy
  S26+ with the build of `21fc291` (it holds A4's `d56e1f5`), the phone off the laptop, checked on a screen
  recording. Recorded on P16's branch: A2–A5 take no more commits after their Codex reviews (the user,
  2026-11-24; the message is in P16's Prompt Log). STAGE 3 (the high plank), two rounds:
  - First round: a 30 s clear with three stars: "그대로 버텨!", ★1 "좋아!", ★2 "잘한다!", and the stars' pop.
  - Second round: warnings at 0:02 and 0:05 ("무릎 떼요"). At the second, "실패!" and the warning's words showed
    together for about 1.4 s and the leave button was gone; the fail screen had two reason chips.
  - The sounds, from the app's audio in the recording: the setup track, then the battle track right after GO; a
    short sound right after ★1 and right after ★2; the whistle at the first warning; at the second warning the
    battle track stopped and the jingle started; at the 30 s clear the jingle started (about 4 s).
  - Timed on the recording: "그대로 버텨!" was covered by the GO! text for its first 0.6–0.8 s and clearly seen
    for about 1.2 s; each star bubble for about 1 s. The user finds them too fast: a follow-up after the merge.
  - The second warning was standing up, but its reason read "무릎 떼요": checked in the follow-up.
  - Not in the recording: a clear ended by warnings after a star ("삐익!", the win jingle, the clear). It stands
    on the tests 'a clear by two warnings lights the stars held' and 'a clear ended by warnings plays the win
    jingle at once'. Leaving mid-stage is not in the results either ('leaving before a result brings the menu
    music back').

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #90's base is `codex/iter5-arcade-stages`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.

#### 2026-11-24 · code at commit `94f6416` · step A4, fourth follow-up on `codex/iter5-hold-plank` (the leave dialog at a stage's end; `main` merged in)
The P16 session found, and the user had it fixed (local task.md, A4 Decisions, 2026-11-24): in a second warning's
1.5 s (`HoldTiming.endShow`, with "실패!", or "삐익!" after a star) the leave dialog stayed open and could be opened,
and leaving then closed the stage without its result, so its stars were not kept. A battle closes the dialog when it
ends.
- **Now (`94f6416`, `lib/screens/hold_stage_screen.dart`):** the moment the stage ends (a second warning's moment, or
  the result at the third star) an open dialog closes, and until the result shows neither back nor the leave button
  opens one. The result and its stars always come with the result screen. The view model is unchanged.
- **`main` merged in (the user's word, 2026-11-24):** `origin/main` `69b0520` (#86, #93, #94) first (`166de3b`, no
  conflict), then A2 (`78e61dc`) and A3 (`6bda1e0`), each bringing only its own merge entry; the testing notes'
  conflicts kept both sides, each step's new entry after its own section. The user chose this order after the local
  harness blocked merging A2 straight in: the merge commit, made by hand for the notes' conflict, counted `main`'s
  62 files as outside A4's scope, and the harness leaves `main`'s files out only when the second parent is
  `origin/main`.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter pub get` (#93 added a package),
then the same as A4's entry above.

- **Before the fix:** the three new tests failed on the old screen (the dialog stayed in the moment, and opened in it).
- **Tests:** `flutter analyze` found no issues. `flutter test` 4238 passed, 0 failed, 10 skipped (2026-11-24, on
  `6bda1e0`; the same 10 skips as above): 4109 before, 3 new, and 126 that came with `main`.
  `test/screens/hold_stage_screen_test.dart`: 47 passed.
- **New tests:** 3, in `test/screens/hold_stage_screen_test.dart`.
- **Other checks:** `ownership_guard.py --check-staged` OK on the fix and on the two hand-made merge commits;
  `--check-diff` OK (64 paths against `origin/main`); the stacked-branch intersection with A2's and A3's branches
  still lists 21 paths. Server `pytest` was not run: `server/` is `main`'s, unchanged by A4.
- **Review:** local reviewer A4 run 12, APPROVE. It ran the three new tests on a copy with the old screen (each
  fails at its dialog check), checked the third-star path (the existing 'the hold ending while asking closes the
  question'), a dialog opened just before the end, and that each merge differs from the automatic one only in the
  notes, by exactly the lower step's own entry. Its Minors: these AI notes lacked the follow-ups' evidence (a short
  block added to A4's section), the local status row (updated), and one left for the user: in the 1.5 s the leave
  button is still drawn and announced, though it opens nothing, while the battle hides its button once decided.
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #90's base is `codex/iter5-arcade-stages`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.

### Test cases added in the fourth follow-up
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/hold_stage_screen_test.dart` | 'a second warning while asking closes the question at once, then the fail screen' (the dialog gone with "실패!", then 다시 도전, the screen not closed); 'in a second warning's moment back and the leave button open no dialog' (then the fail screen); 'a star, then a second warning while asking: the clear shows and its star is kept' ("삐익!", back opens nothing, then 클리어! and the store keeps 1 star) |

#### 2026-11-24 · code at commit `f28cac6` · step A4, fifth follow-up on `codex/iter5-hold-plank` (the leave button at a stage's end)
The reviewer's Minor in the fourth follow-up (run 12) was left to the user: in a second warning's 1.5 s the leave
button was still drawn and announced, though it opened nothing. The user had it hidden as in a battle (local
task.md, A4 Decisions, 2026-11-24).
- **Now (`f430051`):** `lib/screens/hold_stage_screen.dart` passes no leave action to `HoldStagePlay` once the stage
  is over, and `lib/screens/hold_stage_play.dart` takes it as nullable (null hides the button), as `BattleArena`
  does once a battle is decided. `BattleCameraArea` then draws no button and keeps its place empty, as in a battle.
  The third star goes straight to the result, which has no leave button (`f28cac6` asserts it). The view model is
  unchanged.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): the same as A4's entry above.

- **Before the fix:** the two new tests and the changed one failed on the old screen (the button was still found).
- **Tests:** `flutter analyze` found no issues. `flutter test` 4240 passed, 0 failed, 10 skipped (2026-11-24, on
  `f430051`; the same 10 skips as above): 4238 before and 2 new. `test/screens/hold_stage_screen_test.dart`: 49
  passed, on `f430051` and again on `f28cac6` (one assertion added to an existing test).
- **New tests:** 2, and 2 changed, in `test/screens/hold_stage_screen_test.dart`.
- **Other checks:** `ownership_guard.py --check-staged` OK on `f430051` and `f28cac6`. Server `pytest` was not run:
  `server/` is unchanged.
- **Review:** local reviewer A4 run 13, APPROVE. It checked the button and its semantics node are gone for the whole
  1.5 s in both cases, the third-star path and back in the moment, and that `94f6416` stays. Its three Minors were
  fixed: "optional" in this entry (the parameter is nullable, still required), the third-star check (`f28cac6`), and
  the PR body.
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #90's base is `codex/iter5-arcade-stages`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Phone check:** done at the last phone check (the effects entry above): at the second warning the leave
  button was gone while "실패!" showed.

### Test cases added or changed in the fifth follow-up
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/hold_stage_screen_test.dart` | 'a second warning with no star: the leave button is gone for the whole moment, on the screen and to a screen reader' and 'a second warning after a star: …' (the button's icon and its semantics label `게임 나가기` are there before the warning; from the warning, at 0.75 s and 0.1 s before the end, neither is found; then 다시 도전 or 클리어!, the screen not closed); renamed from the fourth follow-up's 'in a second warning's moment back and the leave button open no dialog': 'in a second warning's moment there is no leave button and back opens no dialog' (the button is not found, back opens nothing, then the fail screen); 'the hold ending while asking closes the question' now also finds no leave button on the clear (`f28cac6`) |

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #92's base is `codex/iter5-hold-plank`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Phone check (spec 7, Galaxy S26+), done 2026-11-24** by the user (the user's message of 2026-11-24 02:52, in the
  Prompt Log), with `lib/demo/hold_stage_demo.dart` built from the worktree's HEAD then, `e17e332` (the chair code of
  `77e1a75`, A4's code up to `4ef8a2f`). STAGE 5 · 1F: ⑤ sitting down slowly: no warning; ① 20 s held: a clear;
  ② the hips up: "더 앉아요"; ③ knees in: "무릎 벌려요". ④ leaving the picture: hard to do in a good pose, so another
  warning came first; left to the tests ('out of the picture for over 1 s is off screen' in `chair_hold_test.dart`,
  'out of the picture: the clock stops and the box says 화면 안으로' in `chair_hold_stage_test.dart`). Each warning
  came almost at once (the user's words). The USB cable was out, so neither the 0.5 s itself nor the console's
  `standingThigh`, depth and knee numbers were seen; by what the poses did, the 0.8 knee line was right. No line
  value changed.
- **Shortfall against spec 7:** its last item asks for the depth range of a good chair pose and the knee ratios
  (good, knees in) in these notes; they were not seen. The user's decision (2026-11-24): they are measured at the last
  phone check, with the USB cable in, from the `flutter run` console (the lines to read are in the start bubble's
  entry below). They could not be seen there: the last phone check (2026-11-24 22:21–22:25) did not try the chair
  pose and had to run with the phone off the laptop, so there was no console. TODO(Woohyun Song): whether and when
  to measure them (the user's decision).

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
- Phone check → above (2026-11-24); the start bubble's phone check is the last TODO, in the start bubble's entry below.

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #92's base is `codex/iter5-hold-plank`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Review:** local reviewer A5 run 4, APPROVE; it ran the new tests on the old reader (8 fail) and on a reader that
  never follows (the 3·2·1 tests fail), so both halves of the rule are guarded. Its Minors were fixed before the
  commit (the skips' reason here, two wording lines in the AI notes, a halfway-up step in 'after GO it never
  changes'), except one left for the phone check: a standing thigh taken after GO is taken once, so a user who sat
  through the 3·2·1 and then rises slowly after GO can have it taken before fully up (simulated: a 3 s rise, then a
  true 0.8 reads 0.739). The setup's auto start restarts its count on any frame that is not ready, so the user
  normally stands through the 3·2·1.
- **Phone check:** ⑤ (sitting down slowly) checks this change: done 2026-11-24 on `e17e332`, no warning (A5 entry
  above). The slow rise after GO above is not in the user's results. The user's decision (2026-11-24): the last phone
  check tries it once (the start bubble's entry below says how and which console lines to read). It could not
  be tried: the last phone check had to run with the phone off the laptop (no console), and the chair pose was
  not tried.

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #92's base is `codex/iter5-hold-plank`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Phone check of the start bubble (the last phone check, with A4's effects):** not done: the chair pose was not
  tried at the last phone check (2026-11-24 22:21–22:25, the build of `21fc291`, the phone off the laptop);
  recorded on P16's branch, as A4's. The chair's judging stands on the check of 02:52 on `e17e332` (the A5 entry
  above), the two-line start bubble on the tests (the criteria below). The two console checks planned with it
  (the user's decisions, 2026-11-24) could not be seen: they need the USB cable in (`flutter run -t
  lib/demo/hold_stage_demo.dart -d <device>`, a debug build), and the check had to run with the phone off the
  laptop. TODO(Woohyun Song): whether and when to run them (the user's decision). Left as planned:
  1. **The numbers of spec 7.** The reader prints twice a second, on Android after `I/flutter (…):`,
     `chair_hold <3-2-1|hold> depth=<0.000> knees=<0.000> standingThigh=<0.0> <reading>`; each number is `null`
     until it exists (depth and the standing thigh until a standing thigh is taken, knees until a frame shows both
     knees and both ankles, then the last such frame's). The reading is `HoldReading.ok`, `HoldReading.unknown`,
     `HoldReading.broken(chair.low)` ("더 앉아요") or `HoldReading.broken(chair.kneesIn)` ("무릎 벌려요"); "화면
     안으로" comes from the time's rule, not this line. Read the `chair_hold hold` lines (after GO): `depth=` while
     seated in a good chair pose (its lowest and highest; held from 0.75), `knees=` in a good pose and with the knees
     pulled in (knees in under 0.8), and `standingThigh=` (the standing thigh, fixed from GO). Write the ranges here.
  2. **The slow rise after GO (reviewer A5 run 4), once.** The case needs no standing thigh by GO. Two lines decide
     it: the setup counts a leg as standing from a thigh of 0.25 of the shin (`SetupChecker`, its standing check),
     the reader only from 0.7 (`ChairLines.standingThigh`), for 0.3 s (`ChairLines.standingFor`). A full sit restarts
     the 3·2·1, so bend to about a half squat in the setup, before the 3·2·1 can start, and hold that bend through
     the count. The `chair_hold 3-2-1` lines should then show `standingThigh=null` up to GO. A thigh once taken stays
     for the whole play (the reader is made at 자세 잡기): if a `3-2-1` line shows a number, leave and open the stage
     again. After GO, rise slowly, over about 3 s, then sit down into a good pose. The first `chair_hold hold` line
     with a number after `standingThigh=` shows the thigh taken; compare it with the `standingThigh=` of a play where
     you stood through the 3·2·1, and note the seated `depth=` and whether "더 앉아요" came. If no bend keeps the count
     going with `standingThigh=null`, write down the bends tried and whether the count restarted.
- **Acceptance criteria → tests (the effects spec, the chair's part):** 6.1 shown while entering and gone at the
  start → 'standing after GO: 0:00, 버틴 시간, a green frame, no warning', 'seated, the time starts with "시작" and
  runs'; 6.5 sizes → 'the two-line start bubble and "좋아!" fit …' (3 tests); 6.6 read out → the `said` checks in the
  same two entry tests.

### Test cases added or changed for the start bubble
| Layer | File | What it covers |
|---|---|---|
| Service | `test/services/pose/chair_hold_test.dart` | 'is set up as a squat, entered after GO, with its own words' now checks `startWords` |
| View | `test/services/pose/chair_hold_stage_test.dart` | 'standing after GO: 0:00, 버틴 시간, a green frame, no warning' (the two lines shown and read); 'seated, the time starts with "시작" and runs' (the bubble goes when the time starts); 'the two-line start bubble and "좋아!" fit 360 × 780 at 1.3x text / 320 × 640 at 1.3x / 320 × 640 at 1.0x' (new) |

#### 2026-11-24 · code at commit `4767873` (notes only) · step A5: the chair pose's phone check, A4's notes merged
No code changed. A4's notes of the same day (`f3f45ac`: the plank's phone check, the user's decision on a clear
ended by warnings) came in by `git merge` (`ac30f40`; the testing notes' conflict kept both sides, A4's entry before
A5's). The chair pose's phone check of 2026-11-24 went into the A5 entry above (spec 7, with the build it ran).

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): the same as the A5 entry above.

- **Tests:** `flutter analyze` found no issues. `flutter test` 4159 passed, 0 failed, 10 skipped (2026-11-24, on
  `ac30f40`, the code of `4767873`; the same 10 skips as above).
- **Review:** local reviewer A5 run 6, APPROVE (the merge checked against both parents, the results against the
  message). Its Minors were fixed before the commit: the slow sit's and the slow rise's lines said more than the
  message (now a TODO for the user's choice), the missing numbers of spec 7 named as a shortfall (TODO), one word
  added to the user's statement in the AI notes, these lines. One was left: `origin/main` is ahead of every stage
  branch; it is merged up the stack before the PRs leave draft (not a notes change).
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #92's base is `codex/iter5-hold-plank`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.

#### 2026-11-24 · code at commit `4767873` (A5 unchanged) · step A5: `main` and A4's leave dialog fix merged in
No A5 code changed. At the user's word (2026-11-24, the Prompt Log under A4's heading), `origin/main` `69b0520`
(#86, #93, #94) was merged first (`6a8ce7f`, no conflict), then A4 (`ca2cf6a`: its leave dialog fix `94f6416`, and
A2's and A3's `main` merges). That merge's conflicts were only in the testing notes and the AI notes, where A4's new
entries and A5's met at the same place; both kept, A4's first. The user's two decisions for the last phone check
(spec 7's numbers with the cable in; the slow rise after GO, once) are in the TODOs above, with the console lines.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter pub get` (#93 added a package),
then the same as the A5 entry above.

- **Tests:** `flutter analyze` found no issues. `flutter test` 4288 passed, 0 failed, 10 skipped (2026-11-24, on
  `ca2cf6a`; the same 10 skips as above): 4159 before, A4's 3 new and 126 from `main`.
- **Other checks:** `ownership_guard.py --check-staged` OK on `ca2cf6a` (the notes and A4's two inherited files);
  `--check-diff` OK (67 paths against `origin/main`); the stacked-branch diff against `codex/iter5-hold-plank` lists
  10 paths, as before. Server `pytest` was not run: `server/` is `main`'s, unchanged by A5.
- **Review:** local reviewer A5 run 7, CHANGES_REQUESTED: the slow rise's steps could not be done as written (a
  user upright when the 3·2·1 starts gives the reader 0.3 s of standing at once, and the thigh stays for the play),
  and their fallback ("the case cannot happen") did not follow from the code (the setup counts standing from 0.25 of
  the shin, the reader from 0.7); now a half squat held through the count, the two lines, what to do when a thigh
  was taken, and what to write if no bend works. Minors: the two fault ids, and `null` before a value exists. All
  fixed; run 8: APPROVE (its one Minor, run 7 missing from the AI notes, fixed before the commit).
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #92's base is `codex/iter5-hold-plank`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.

#### 2026-11-24 · code at commit `200816d` (tests only) · step A5: A4's leave button fix merged in
No A5 app code changed. At the user's word (2026-11-24, the Prompt Log under A4's heading), A4 `d56e1f5` was merged in
(`29e1337`): from a second warning to the result the leave button is gone from the screen and the semantics tree, as
in a battle (`f430051`, `f28cac6`). The chair pose's stages use the same screen; A4's tests drive the high plank,
so `200816d` checks it on a chair stage too (reviewer run 9's Minor). `origin/main` had not moved (`69b0520`, already merged), so it was not merged
again. The only conflict was in the testing notes, where A4's new entry and A5's met at the same place; both kept,
A4's first. The merge brings exactly A4's change (6 files, the same added and removed lines as `471885d..d56e1f5`).

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): the same as the A5 entry above.

- **Before the test:** the new chair test failed on A5's screen from before the merge (`b6e90d7`): the button was
  still found at the second warning.
- **Tests:** `flutter analyze` found no issues. `flutter test` 4290 passed, 0 failed, 10 skipped on `29e1337`, then
  4291 passed, 0 failed, 10 skipped on `200816d` (2026-11-24; the same 10 skips as above): 4288 before, A4's 2 new
  and 1 new here. `test/services/pose/chair_hold_stage_test.dart`: 14 passed.
- **New tests:** 1, and 1 changed, in `test/services/pose/chair_hold_stage_test.dart` (table below).
- **Other checks:** `ownership_guard.py --check-staged` OK on `29e1337` (A4's three inherited files and the notes)
  and on `200816d`;
  `--check-diff` OK (67 paths against `origin/main`); the stacked-branch diff against `codex/iter5-hold-plank` lists
  10 paths, as before. Server `pytest` was not run: `server/` is unchanged.
- **Review:** local reviewer A5 run 9, APPROVE. It checked the merge carries exactly A4's change (the three code
  files equal A4's), A5's own lines untouched, the conflict, and that `origin/main` had not moved. Its one Minor: no
  chair-stage test checked the leave button, though the entry has no time limit and the button is its way out
  (decision 9.3); fixed in `200816d`.
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #92's base is `codex/iter5-hold-plank`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.

### Test cases added or changed with A4's leave button fix
| Layer | File | What it covers |
|---|---|---|
| View | `test/services/pose/chair_hold_stage_test.dart` | 'standing after GO: 0:00, 버틴 시간, a green frame, no warning' now also finds the leave button's icon and its semantics label `게임 나가기` while entering; new 'a second warning: no leave button until the result' (hips up twice: the button there after the first, gone from the second, still gone 0.1 s before the end, then 다시 도전) |

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Shortfalls:** section 8 (hold stages) is not done: `codex/iter5-hold-chair` is not on origin yet. Until then the
  map's hold stages do nothing, so a player stops at STAGE 3 in the app.
- **Manual check:** on the Galaxy S26+ (spec 12), checked on 2026-11-24 on `9b59537` (the `b03ca98` entry below; the boss match through R2 and the 2F fever seen at the last phone check, the `7362fb4` entry's Manual check): 1F from the start to the boss once (with the
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
- Phone check → (above): done on 2026-11-24, on `9b59537` and at the last phone check on `21fc291` (the boss
  match through R2 and the 2F fever; the `7362fb4` entry's Manual check)

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Manual check:** on the Galaxy S26+ (spec 12), checked on 2026-11-24 on `9b59537` (the `b03ca98` entry below; the boss match through R2 and the 2F fever seen at the last phone check, the `7362fb4` entry's Manual check): 1F from STAGE 1 to the boss with STAGE 3 on
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
- Phone check → (above): done on 2026-11-24, on `9b59537` and at the last phone check on `21fc291` (the boss
  match through R2 and the 2F fever; the `7362fb4` entry's Manual check)

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
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Manual check (2026-11-24, Galaxy S26+ SM-S947N, One UI 9.0, Android 17; the build of `9b59537`, an account new
  to the arcade):**
  - Worked: 게임 시작's two cards; the arcade home; a fight stage's flow (the stage info, the opponent's intro, the
    floor's background, the clear, the report, back home); the fail screen and 다시 도전; the hold stages opening
    (STAGE 3 on the high plank, STAGE 5 on the chair pose) and opening the next cell; the home's star total and each
    cell's stars; the 2F floor shown on the home's map (its first stage still locked).
  - Not seen: winning the boss match through R2 to "1층 클리어!", and the 2F first stage's fever at 15 s. Both
    seen at the last phone check (the `7362fb4` entry's Manual check).
  - To fix: on the boss match's break, the words of "자세 잡기" nearly ran out of the button. Fixed in the next
    entry.

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
- Phone check → (above): done on 2026-11-24, on `9b59537` and at the last phone check on `21fc291` (the boss
  match through R2 and the 2F fever; the `7362fb4` entry's Manual check)

#### 2026-11-24 · code at commit `fcacca1` · step P16 `codex/iter5-ai-opponents`, the phone check and the boss button
The phone check on `9b59537` (the entry before) found that on the boss match's break the words of "자세 잡기" nearly ran
out of the button. In the design (`P16Boss` break) the button spans the screen's content, as on the intro; P16's
break made it as wide as its words, so the corners of the slanted words reached 2.4 px past its edge. Fixed:
- **The break's 자세 잡기** spans the content like the intro's: 320 wide on the design's 360 phone, 58 high, the words
  at 19.
- **The arcade's ink button (`ArcadeDarkButton`):** on a narrow button or with large text its words shrink to fit
  instead of being cut off with "…", with at least 4 of room on each side for the slant. Where they fit, nothing
  changes.
- **The other buttons** of the boss intro, the break and the floor cleared (자세 잡기, 그만하기, 2층으로, 리포트 보기)
  were checked the same way: all inside. The floor cleared's buttons are A4's (`ArcadeResultFrame`) and were only
  checked, not changed.

I ran the commands from the Plan in `gymrats_app/` on Windows, without coverage. Coverage comes from the PR's CI
comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/24 | CI comment "Tests and coverage (GitHub Actions)" |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/24 | same CI comment |
| Service | flutter_test, fakes | 85% | TODO(Woohyun Song): from the PR's CI comment (no P16 service) | 11/24 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment | 11/24 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 11/24 | – |

- **Tests:** `flutter test` 4319 passed, 0 failed, 10 skipped (the same 10 as on `main`). `flutter analyze` found
  no issues.
- **Count change since `b03ca98`:** P16's new test files now hold 149 tests (142 before): `arcade_boss_screen_test.dart`
  +5 (the words inside every button at four sizes, the break's button like the intro's), `arcade_parts_test.dart` +2
  (the ink button's words at their size, and shrunk on a narrow button).
- **The new tests against the old code:** with the two code files from `9b59537` put back for one run (then
  restored), 6 of the 7 new tests failed: the four sizes (자세 잡기 on the break painted 2.4 px left of its 127-wide
  button), the break's button width (127, not 320) and the narrow button ("다음 스테이지" cut off). The seventh, the
  words at their size where they fit, passes on both: it guards that the fix changes nothing there.
- **Reviewer:** run 6 APPROVE with one Minor: a new test checked only the words' top corners, which lean away from the edge; it now checks all four against the button's round shape and fails when the room for the slant is taken out. It checked that no A2–A5 file is changed, that the map's and the sheet's ink buttons are unaffected, and that A4's buttons on the floor cleared pass unchanged.
- **Other checks:** `ownership_guard.py --check-diff` ok (109 paths). Server `pytest` was not run because `server/`
  did not change.
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Manual check:** at the last phone check (the `7362fb4` entry's Manual check), the break "1라운드 승리!" had its
  자세 잡기 words inside the button. A large text size is not in the results (the tests at four sizes cover it).

### Test cases added or changed in this phase
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/arcade_boss_screen_test.dart` (updated) | the words of every button on the boss intro, the break and the floor cleared stay inside the button, slant and round corners included, at 360 x 780 and 320 x 640 with 1.0x and 1.3x text; the break's 자세 잡기 spans the content like the intro's, 58 high, its words at full size |
| View | `test/widgets/arcade_parts_test.dart` (updated) | the ink button keeps its words at their size where they fit, and shrinks them on a narrow button without cutting them off |

### Acceptance criteria → tests (the phone check's fix)
- "자세 잡기" inside its button with the default and 1.3x text, the design's shape kept → 'on $where every button keeps
  its words inside it: the intro, the break and the floor cleared' (4 sizes), "the break's 자세 잡기 is the intro's
  button: as wide as the screen's content, 58 high, its words at full size"
- Shrinks only on a narrow screen or with large text → 'the dark button keeps its words at their own size where they
  fit', 'on a narrow button the dark button shrinks its words to fit inside it, never cutting them off'
- The other buttons of the boss intro, the break and 1층 클리어 → the first test above (그만하기, 2층으로, 리포트 보기)
- Phone check of the fix → (above): the words inside the button at the last phone check

#### 2026-11-24 · code at commits `359ea18` and `5553521`, with A5 merged in `2ab24c3` · step P16 `codex/iter5-ai-opponents`, the hold stages' music
The A5 session finished the hold effects on A4 (`3ffed5f`: the battle's music on a hold stage, the owner's bubble
after GO, the effects and sound of the first and second stars, a second warning's "실패!" for 1.5 s and the fail
screen's reason chip) and A5 (`4767873`: the chair pose's start bubble), and merged them into
`codex/iter5-hold-chair` (`fafb0d4`). `git merge origin/codex/iter5-hold-chair` (`2ab24c3`): the app code merged
without a conflict; this file and the Prompt Log had content conflicts (both sides added entries at their ends),
resolved by keeping every entry (A5's entry above P16's here, the P16 prompts above A5's in the log).

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter analyze`, `flutter test`.

- **The music check (the user's item 2), traced in the code against a fight stage:**
  - A fight: the map, the stage sheet and the versus screen play nothing, so what plays goes on (the menu track from
    home); the battle (`BattleSounds.musicFor`) plays the setup track through the setup and the 3·2·1, the battle
    track (fever at the end) and, when it ends, the win or lose jingle; the battle closes on a result, so the jingle
    goes on through the arcade's result and the report, which play nothing; back on the map nothing new plays, and
    home's `SoundCues` brings the menu track back.
  - A hold (`HoldStageScreen._playMusic`): the briefing plays nothing; the setup track through the setup and the
    3·2·1; the battle track while holding; the jingle when the time runs out. On a second warning the jingle starts
    with the warning, and the result asks for the same jingle again, which `BackgroundMusicService.play` drops (the
    same cue as the last one); the stars, and so the jingle, are fixed at that warning (`HoldStageViewModel` sets
    them with `ending`; `_finish` keeps them). 아케이드로 and 다음 스테이지 close on a result, so the jingle goes on;
    leaving in the setup, the 3·2·1 or the hold brings the menu track back, as leaving a battle does. A hold's
    다음 스테이지 opens a fight's sheet or the boss intro (no two hold stages are next to each other).
  - No jingle plays twice. Each change is the music service's usual cross-fade, the old track fading out over 0.6 s
    while the new one fades in (`BackgroundMusicService.fade`), as on any screen change; both screens use the app's
    one music service (`SoundServices.shared`), so no track loops on beside another.
  - **One difference, fixed here:** a hold closed on its briefing, before any track of its own (opened from the map
    after a result, or after 다시 하기), asked for the menu track as it closed (`HoldStageScreen.dispose`: no result
    on screen), so after a jingle the menu came back on the map, where a fight's sheet and versus screen play nothing
    and the silence after its jingle stays. The hold screen is A4's, so `359ea18` changes the arcade's side:
    `ArcadeFlow.holdScreen` gives the screen the app's sound with its music in `ArcadeHoldMusic`
    (`lib/widgets/arcade_hold_music.dart`), which passes every cue on except that menu track when no setup or battle
    track was asked for since the stage opened or since its last jingle. Left in the setup, the 3·2·1 or the hold,
    the menu still comes back (A4's rule, as for a battle).
  - **A4's, reported, not changed:** in a second warning's 1.5 s moment the phase is still the hold, so back or the
    leave button still opens the leave dialog, and leaving there skips the result and keeps no star; a fight closes
    its dialog when it ends. With `ArcadeHoldMusic` the jingle goes on there instead of the menu track.
- **Tests:** `flutter test` 4357 passed, 0 failed, 10 skipped (2026-11-24, `5553521`; the same skips as
  above). `flutter analyze` found no issues. New: 8 tests in `arcade_hold_music_test.dart`, 1 in
  `arcade_screen_test.dart`, 1 in `design_tokens_test.dart` (`5553521`: the new file on its list); 1 changed (the
  app's way into a hold also checks the sound it gets). A4's and A5's new
  tests came with the merge (their entries above).
- **Old-code check:** with `ArcadeHoldMusic` taken out of `ArcadeFlow.holdScreen`, the two arcade-screen tests fail
  (closing the briefing after a jingle asked for `[win, menu]`); the unit tests need the new class.
- **The phone check's record:** "2F opening" in the entry above was the 2F floor shown on the home's map, its first
  stage still locked (the user, 2026-11-24); corrected there.
- **Other checks:** `ownership_guard.py --check-diff` OK (111 paths).
- **Review:** local reviewer run 7 CHANGES_REQUESTED (these notes said the order matched, that tracks never play
  together and that the map stays silent after any result, and the difference was left in the code), so the notes
  were corrected and the difference fixed; run 8 APPROVE (3 Minor: wording in the local progress file, fixed; the
  new file added to `design_tokens_test.dart`'s list in `5553521`; origin/main's #93 not yet in the A2–P16 stack,
  left to the user).
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Shortfalls:** coverage is not measured on this PC (the CI comment is pending). The whole way from the map through
  a hold's result back to the map is tested in parts (the wrapper's order, the briefing closed on the map, A4's
  tests of the hold screen's cues), not in one widget test, because the hold's camera setup is A4's and the arcade's
  way in takes no stand-in view model. The phone check below.
- **Manual check:** at the last phone check (the `7362fb4` entry's Manual check), from the app's audio in the screen
  recording, STAGE 3 from the arcade: the setup track, then the battle track right after GO, a short sound right
  after ★1 and ★2, the whistle at the first warning, at the second warning the battle track stopped and the jingle
  started, at the 30 s clear the jingle (about 4 s). After a jingle the result, the map and the
  next stage's briefing played nothing, as traced above (a follow-up asks whether the map should start a track
  again). STAGE 5 was not tried; a hold closed on its briefing after a jingle and leaving mid-stage are not in
  the results (the tests above).

### Test cases added or changed in this phase
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/arcade_hold_music_test.dart` | 'passes the hold screen's cues on: the setup, the hold, the jingle', 'left in the setup, the 3·2·1 or the hold, the menu comes back, as when a battle is left before its result', 'closed on its briefing before anything started: what plays goes on, as a fight's sheet and versus screen play nothing', 'closed on its briefing after a jingle (다시 하기, then back): the silence after the jingle stays, as after a fight', 'left in the second warning's moment, after its jingle started: the jingle goes on', 'played again after a jingle, then left mid-stage: the menu comes back', 'stop goes to the app's music; dispose leaves the app's music alone', 'around keeps the set's switches, voice and effects and wraps its music' |
| Design | `test/design_tokens_test.dart` (updated) | `lib/widgets/arcade_hold_music.dart` uses only design tokens |
| View | `test/screens/arcade_screen_test.dart` (updated) | 'closed on its briefing after a jingle, the map stays silent, as after backing out of a fight's versus screen' (new); 'the app's own way into a hold: …' also checks the wrapped music and the app's effects, voice and switches |

### Acceptance criteria → tests (the user's item 2)
- A hold's tracks from the map change in a fight's order → 'closed on its briefing after a jingle, the map stays
  silent, as after backing out of a fight's versus screen', 'closed on its briefing after a jingle (다시 하기, then
  back): the silence after the jingle stays, as after a fight', 'passes the hold screen's cues on: the setup, the
  hold, the jingle', and A4's 'the battle's music at the battle's moments'
- Left before a result, the menu comes back → 'left in the setup, the 3·2·1 or the hold, the menu comes back, as when
  a battle is left before its result', A4's 'leaving before a result brings the menu music back'
- No jingle twice → A4's 'a second warning with no star plays the lose jingle at once', 'a clear ended by warnings
  plays the win jingle at once', and `background_music_test.dart` 'the same cue on every state update plays the track
  once'
- The arcade's hold gets the app's sound → 'the app's own way into a hold: A4's screen for the stage, with the
  arcade's store, account and the user's character'

#### 2026-11-24 · code at commits `359ea18` and `5553521` (P16 unchanged), with `main` merged in `c92006c` and A5 in `670aecf` · step P16 `codex/iter5-ai-opponents`: `main` and A4's leave dialog fix merged in
At the user's word (2026-11-24, the Prompt Log), A2 and A3 merged `origin/main` `69b0520` (#86, #93 Google sign-in,
#94), A4 merged `main` and then A2 and A3 with its leave dialog fix (`94f6416`), and A5 merged `main` and then A4
(`b6e90d7`). My first fetch found none of the four branches with `main` and no dialog fix in A5, so nothing was merged
until A5's push. Then, in the order the user gave (the pre-commit guard leaves `main`'s files out of a merge's check
only when its second parent is `origin/main`):
- `git merge origin/main` (`c92006c`): one conflict, in `gymrats_app/lib/main.dart`, at two places where #93 and P16
  each added a line (the imports `viewmodels/social_signup_viewmodel.dart` and `widgets/gym_background_art.dart`;
  `GymRatsApp`'s `arcadeStore` and `googleSignIn`). Both kept, so against `main` the file differs only by P16's
  arcade lines and the art's warm-up call; every Google sign-in line of #93 is there.
  `test/screens/online_lobby_screen_test.dart` merged without a conflict: #86's new group '다시 매칭 after a cancel
  (P12)' and P16's card name '온라인 대결' are both in it.
- `git merge origin/codex/iter5-hold-chair` (`670aecf`): the app code merged without a conflict (A4's
  `hold_stage_screen.dart` and its test); this file had a content conflict where A5's two new entries met P16's
  (both kept, A5's first; the only lines dropped are A4's and A5's own, which their branches changed). The AI notes
  and the Prompt Log merged without a conflict.
- **A4's leave dialog fix against the hold music:** the dialog now closes when a stage is over (a second warning's
  moment or the result), does not open then, and back does nothing in that moment. `_playMusic` and `dispose` are
  unchanged, so the music trace in the entry above stands, and the dialog item reported there is fixed on A4's
  branch. No in-app path closes the screen in that moment now (back returns in `_back`, the leave button in
  `_askToLeave`). If the screen were disposed there, `ArcadeHoldMusic` would drop the menu cue ('left in the second
  warning's moment, after its jingle started: the jingle goes on', a unit test of the wrapper's cues).

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter pub get` (#93 added a package),
`flutter analyze`, `flutter test`.

- **Tests:** `flutter test` 4486 passed, 0 failed, 10 skipped (2026-11-24, `670aecf`; the same skips as above).
  `flutter analyze` found no issues. 4357 before: 126 came from `main` and 3 from A4's dialog fix (the same numbers as in A5's entry above). No P16 test was added or changed.
- **Other checks:** `ownership_guard.py --check-staged` OK in both merge commits' hook (`c92006c`: 111 paths
  against `origin/main`; `670aecf`: 5 paths, the notes and A4's two inherited files); `--check-diff` OK (111 paths);
  the diff against `codex/iter5-hold-chair` (PR #91's base) still lists 48 files. Server `pytest` was not run:
  `server/` is `main`'s.
- **Review:** local reviewer run 9 APPROVE: both merges rebuilt and checked against their parents (nothing of #93 or
  P16 lost, the notes' lines dropped only where hold-chair itself changed them), P16's 45 code files' changes the
  same as at run 8, the 48-file list unchanged; analyze clean, 231 targeted tests passed. Its 4 Minors were fixed
  before the commit: #93's tests named by their file (`auth_flow_test.dart`); the dialog sentence said more than the
  code; PR #91's body (updated after the push); the AI notes' P16 evidence and this line.
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Shortfalls:** coverage is not measured on this PC (the CI comment is pending). The merged `main.dart` is checked
  here only by tests (#93's `test/auth_flow_test.dart` and P16's app-flow tests in `main_test.dart`, both on the
  merged file), and the app's start with the arcade was seen at the last phone check (below; Google sign-in was not).
- **Manual check:** at the last phone check (the `7362fb4` entry's Manual check): the app started with the arcade
  screens, the boss match through R2 to 1층 클리어!, the 2F fever from 0:15, the fixed 자세 잡기 button and STAGE
  3's music from the arcade worked; Google sign-in (main #93) was not seen (the button did nothing: an environment
  issue, not code, as written there).

#### 2026-11-24 · code at commit `7362fb4` (one new P16 test file), with `main` `18b9259` merged in `18ea16c` and A5 `b9b5a45` in `03cac86` · step P16 `codex/iter5-ai-opponents`: `main`'s friend battles and A4's hidden leave button merged in
At the user's word (2026-11-24, the Prompt Log), A4 hides the leave button once a hold stage is over (`d56e1f5`) and
A5 merged it (`b9b5a45`). The message said `origin/main` was still `69b0520`; the fetch showed `18b9259` (#95, friend
battles), so, as the message said for that case, `origin/main` was merged first:
- `git merge origin/main` (`18ea16c`): five files conflicted, each where #95 and P16 changed the same lines.
  - `lib/main.dart`: five places where each side added lines next to the other's (`arcadeStore` and
    `friendRepository`, their fields, `_arcade` and the friends' fields, their disposal, the `/arcade` and `/friends`
    routes). All kept; against `main` the file differs only by P16's arcade lines.
  - `lib/screens/play_screen.dart`: P16's two cards (온라인 대결, 아케이드) with #95's 친구와의 대전 row under them,
    the place P16 spec 13.1 left empty for the friend battles. #95 also dropped the footer line "30초 · 점수 높은 쪽
    승리" (P16's note of 2026-11-23 had left that line to a later step); kept dropped. The AI 1v1 card, its route and
    the exercise list it used stay gone (P16 spec 3).
  - `test/screens/play_screen_test.dart`: 'shows the two cards and the rules, no AI 1v1 and no again row (P16 spec 3,
    13.1)' also finds 친구와의 대전 and no footer line; the online card's test taps 온라인 대결 and keeps #95's check
    that no mode is asked first; #95's AI card test is dropped (no AI 1v1); the tap-target test names all three
    entries; #95's 'it sits under the two cards and opens the friends page' measures against `ArcadePlayCard` instead
    of the removed `BattleModeCard`.
  - `test/screens/home_screen_test.dart`: both sides' checks kept (P16's read of the latest battle and #95's friend
    row; in the second, `lastMatch.opponentName` and `lastSetup.exercise`).
  - `test/main_test.dart`: P16's side (the online sheet's best); #95 had only dropped the play-again line there,
    which P16 had dropped too. `online_lobby_screen_test.dart` merged without a conflict.
- `git merge origin/codex/iter5-hold-chair` (`03cac86`): A4's `hold_stage_screen.dart`, `hold_stage_play.dart` and
  `hold_stage_screen_test.dart` and A5's `chair_hold_stage_test.dart` merged without a conflict; this file's
  conflict kept both sides, A5's entry first.
- **A4's hidden leave button with `ArcadeHoldMusic`:** the screen passes no leave action once the stage is over (a
  second warning's moment or the result); its music calls (`_playMusic`, `dispose`) are unchanged. The new
  `test/screens/arcade_hold_stage_test.dart` runs A4's screen with the sounds `ArcadeFlow.holdScreen` gives it, on a
  scripted setup and pose reader: after a second warning, with no star and after a star, the button is gone from the
  screen and to a screen reader for the whole moment and on the result; the lose or win jingle starts with the moment
  and stays; 아케이드로 or 다음 스테이지 brings no menu track. Before the end the button is there, and leaving from
  it brings the menu track back.
- **Found, not changed (for the user):** #95's invite alert hides only on named routes
  (`FriendInviteRouteWatch.busyRoutes`: the online lobby and battle, matching, versus, setup, battle). The arcade's
  fights and boss rounds open the named versus and battle routes, so the alert stays hidden there. The hold stages
  (`ArcadeFlow.openHold`), the boss intro (`ArcadeBossScreen.route`) and the break after R1 (`afterBattle`) open
  unnamed routes, so the alert can show over them (`FriendInviteRouteWatch.hides` is false there, checked in a
  throwaway test that is not committed). Accepting an invite there opens the online battle over the hold stage,
  whose camera and clock go on under it (the reviewer's reading of the code; not tried). `busyRoutes` is in #95's
  `friends_screen.dart`, outside P16.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter pub get`, `flutter analyze`,
`flutter test`.

- **Tests:** `flutter test` 4645 passed, 0 failed, 10 skipped; 159 more than at `670aecf`: 4 in the new P16 file, the rest from #95 and A4's and A5's leave-button tests, less #95's AI card test, dropped here (2026-11-24, `7362fb4`; the same skips as above). `flutter analyze` found no issues.
- **Other checks:** `ownership_guard.py --check-staged` OK in both merge commits' hook (`18ea16c`: 111 paths against
  `origin/main`; `03cac86`: 7 paths, the notes, three of A4's files and A5's `chair_hold_stage_test.dart`) and for the test commit;
  `--check-diff` OK (112 paths). The diff against `codex/iter5-hold-chair` (PR #91's base) now lists 77 files: P16's
  49 and 28 of #95's, which A2–A5 do not have yet. Server `pytest` was not run: `server/` is `main`'s.
- **Review:** local reviewer run 10 CHANGES_REQUESTED: both merges rebuilt (`merge-tree`) with exactly the five
  conflicts above, nothing of #95 or P16 lost beyond P16's intended removals, #95's other 27 files byte-equal to
  `18b9259`, A4's and A5's four files byte-equal to `b9b5a45`; the new test checked as meaningful; the invite alert
  item confirmed from the code; full suite 4645 / 0 / 10 in its own run. Its Major (this entry had no test-case
  table and no acceptance criteria → tests) and Minor (A5's test called one of A4's) were fixed; run 11 APPROVE (2 Minors, fixed: a test named without its group, the local progress file's review
  rows).
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Shortfalls:** coverage is not measured on this PC (the CI comment is pending). 게임 시작 with 친구와의 대전 under
  the arcade cards is checked by widget tests at 412x915, 360x640 and 360x780 at 2.0x text, and was seen on the phone
  at the last phone check (below); the invite alert over the arcade's unnamed routes was open then (fixed in the next
  entry).
- **Manual check: the last phone check, done 2026-11-24 22:21–22:25** by the user on the Galaxy S26+ (SM-S947N)
  with the build of `21fc291` (this entry's code), made in a separate copy of the repo, the phone off the laptop,
  checked on a screen recording. The user's message is in the Prompt Log.
  - Worked: the app's start; 게임 시작 with the 친구와의 대전 row under the two cards (main #95); the arcade home;
    STAGE 3 (hold): its clear, its fail, 다시 도전 and 아케이드로; the boss match: R1 (push-ups) won by KO, the
    break "1라운드 승리!" with its 자세 잡기 words inside the button (`fcacca1`), R2 (squats) won by KO, then
    "1층 클리어!" with "2층으로" and "리포트 보기"; 2층으로 opened 2F's first stage (STAGE 7), its fever
    started at 0:15, and a loss there showed the fail screen. The leave button gone once a hold stage is over
    (A4 `d56e1f5`): seen at the second warning (A4's effects entry above, with STAGE 3's other results).
  - The sounds, from the app's audio in the recording: in the boss match and the 2F stage the battle track went
    on to the end, and the jingle played on a KO and on a loss. STAGE 3's are in A4's effects entry and the
    hold music entry above.
  - Not seen: Google sign-in (main #93); the button did nothing. Per 박진영 (P7, Google sign-in), this PC's debug SHA-1 is not
    registered for Google sign-in, so it is written down as an environment issue, not code, and checked again
    with the login screen's redesign (P8).
  - Follow-ups after the merge (no code changed now; listed in the local progress file): the silence after a
    jingle on the result, the map and the next stage's briefing (about 16 s from the boss clear to the setup of
    2F's first stage; home has the menu track when the app starts); the win jingle cut without a fade on
    entering "1층 클리어!" (about 3 s heard of about 4 s); R1's KO button says "결과 보기" but opens the break;
    plain hold and break screens and a weak floor-cleared staging; the arcade bots' level (push-ups about 5%
    easier, squats about 5% harder); the hold bubbles' time and the standing-up reason (A4).

### Test cases added or changed in this phase
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/arcade_hold_stage_test.dart` (new) | 'the arcade's hold screen is A4's, its music in an ArcadeHoldMusic'; in the group 'a second warning from the arcade: A4's hidden leave button with the arcade's music': 'with no star: no leave button for the whole moment, the lose jingle from its start, and no menu track at the map after 아케이드로' and 'after a star: no leave button for the whole moment, the win jingle from its start, and no menu track at the map after 다음 스테이지'; 'before the end the leave button is there, and leaving from the arcade brings the menu track back' |
| View | `test/screens/play_screen_test.dart` (updated in the merge) | 'shows the two cards and the rules, no AI 1v1 and no again row (P16 spec 3, 13.1)' also finds 친구와의 대전 and its line, and no "30초 · 점수 높은 쪽 승리"; 'the online card asks for the exercise, then opens the lobby' taps 온라인 대결 and keeps #95's check that 메인 매치 is not asked; 'every button is big enough and has a name' names 온라인 대결, 아케이드 and the friend row; #95's group '친구와의 대전 row (P9)' as on `main`, its 'it sits under the two cards and opens the friends page' measured against `ArcadePlayCard`; #95's 'the AI card opens the AI 1v1 page on the same view model' dropped (no AI 1v1, P16 spec 3) |
| View | `test/screens/home_screen_test.dart` (updated in the merge) | '게임 시작 opens the play page on home's profile' also finds 친구와의 대전 (#95); in the group 'coming back to home loads it again': 'and the play page reads the battle saved meanwhile' checks both the latest battle's opponent (P16) and the last setup's exercise (#95) |

### Acceptance criteria → tests (the user's items 1 and 2)
- 게임 시작 keeps P16's two cards and gets #95's 친구와의 대전 under them, with no AI 1v1, 이어하기 or footer line →
  'shows the two cards and the rules, no AI 1v1 and no again row (P16 spec 3, 13.1)', 'it sits under the two cards
  and opens the friends page', 'fits a short phone without overflow, scrolling if it must', 'fits a large text size
  without overflow, scrolling if it must', 'every button is big enough and has a name'
- The online battle is unchanged → 'the online card asks for the exercise, then opens the lobby' and
  `online_lobby_screen_test.dart` as on `main`
- On a hold stage from the arcade, the leave button is gone once the stage is over, and `ArcadeHoldMusic` still plays
  the battle's order → the two tests in 'a second warning from the arcade: A4's hidden leave button with the
  arcade's music', 'the arcade's hold screen is A4's, its music in an ArcadeHoldMusic'
- Before the end the button still works with the arcade's music → 'before the end the leave button is there, and
  leaving from the arcade brings the menu track back'

#### 2026-11-24 · code at commits `c02a9ff` and `d3159cf` (a comment) · step P16 `codex/iter5-ai-opponents`: a friend's invite waits over the arcade's stage screens
At the user's word (2026-11-24, the Prompt Log), the item found in the entry above is a real bug: a friend's invite
could show over an arcade stage, and 수락 would open the online battle while a hold stage's camera and clock went on.
The fix, as the user set it:
- **Route names (`lib/main.dart`):** `GymRatsApp.arcadeSheetRoute` (a fight's sheet), `arcadeHoldRoute`,
  `arcadeBossRoute` (a boss match's intro), `arcadeBreakRoute` (the break between its rounds) and `arcadeResultRoute`
  (a stage's result). A fight itself already opens the named `/versus` and `/battle`. The names are set where the
  routes are opened: `ArcadeStageSheet.show` (a new optional `routeName`, given by `ArcadeScreen`),
  `ArcadeFlow.openHold`, `ArcadeBossScreen.route` (the intro or the break, by whether R1 is given) and
  `ArcadeFlow.afterBattle` (the break now opens through `ArcadeBossScreen.route`, the result with its name). Nothing
  else about these routes changed.
- **#95's `busyRoutes` (`lib/screens/friends_screen.dart`, P9's file):** the five names added, no other line of #95
  changed. Act first and report after (team rule): written down in the local exceptions list, and in PR #91's
  Exceptions with this push; the owner's and the PM's approval are pending.
- The arcade's map (`/arcade`) is not in the list, so the invite shows there as on home.
- **Also hidden, as #95's rule has it:** the alert hides while a busy route is anywhere below, so it also waits on
  the report opened from an arcade result (리포트 보기) and on 피드백 or 코치 opened from that report. After an AI
  1v1 the report replaces `/battle`, so it is not hidden there. Not tested on its own.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter analyze`, `flutter test`.

- **Tests:** `flutter test` 4657 passed, 0 failed, 10 skipped; 12 more than at `7362fb4`: the 7 new tests and 5 of #95's for the new names (2026-11-24, `c02a9ff`; the same skips as above). `flutter analyze` found no issues; `dart format`
  left the six changed code files as they were.
- **Checked against the old code:** with the five names taken out of `busyRoutes` again, the 7 new tests fail (4 of 4
  in `arcade_flow_test.dart`, 3 of 3 in `main_test.dart`), and all pass with them.
- **#95's own tests:** `friends_screen_test.dart` runs 'hidden while $route is open, back after it' for every name in
  `busyRoutes`, so it now also checks `/arcade/sheet`, `/arcade/hold`, `/arcade/boss`, `/arcade/break` and
  `/arcade/result` (5 more tests, all passing; the file is not changed).
- **Other checks:** `ownership_guard.py --check-paths` OK for the commit's eight paths, with the local exception for
  `friends_screen.dart`; `--check-staged` OK in the commit's hook (8 paths); `--check-diff` OK (113 paths, `friends_screen.dart` now among them). PR #91's diff against its base still lists 77 files: P16's 50 and 27 of #95's that P16 does not change.
- **Review:** local reviewer run 12 APPROVE: only route names changed (`isMap` still matches `/arcade` alone;
  `toMap`, `replay`, `leave`, `next` and the boss rounds' `/battle` unchanged; the sheet with no name as before), no
  online, A2–A5 or other #95 file in the commit, the 7 tests fail on a route with no other busy name; analyze clean,
  4657 / 0 / 10 in its own run, `--check-diff` 113. Its 5 Minors were fixed before the push: PR #91's body
  (Exceptions, the fixed item, the file count line) and the local Exceptions list; the new names in the design doc
  changes; `main.dart`'s comment named only `ArcadeFlow` as the opener (`d3159cf`); the report opened from an arcade
  result (above); two counts in this entry.
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Shortfalls:** coverage is not measured on this PC. The fix is checked by widget tests, not on a phone: the last
  phone check used `21fc291`, from before it (Manual check below).
- **Manual check:** not on the phone. The fix is not in the last phone check's build (`21fc291`), and an invite
  needs a second account and device, so it was left this time (user, 2026-11-24). Checked instead by the 4 tests
  in `arcade_flow_test.dart` and the 3 in `main_test.dart` (the real app), listed below.

### Test cases added or changed in this phase
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/arcade_flow_test.dart` (updated) | new group 'a friend's invite waits over the arcade's stage screens, as over a battle (#95's FriendInviteRouteWatch)': 'the map lets it show; a fight's sheet, then its versus screen, hide it', 'a hold stage hides it; back on its briefing lets it show again', 'a boss match's intro hides it, and so does the break after R1; 그만하기 lets it show again', 'a stage's result hides it, a fight's and a boss match's; 아케이드로 lets it show again' (each also checks the top route's name) |
| App flow | `test/main_test.dart` (updated) | new group 'a friend's invite on the arcade (#95's alert)', with the app's own alert and a friend's push-up invite: 'it shows on the arcade's map as on home, and waits while a fight's sheet is open', 'it waits while a hold stage is open, and shows again on the map', 'it waits while a boss match's intro is open' |

### Acceptance criteria → tests (the user's item 1)
- No invite over an arcade stage (sheet, hold stage, boss intro, break, result) → the four tests of 'a friend's
  invite waits over the arcade's stage screens, as over a battle (#95's FriendInviteRouteWatch)', 'it waits while a
  hold stage is open, and shows again on the map', 'it waits while a boss match's intro is open', and #95's 'hidden
  while $route is open, back after it' for the five names
- The invite still shows on the arcade's map, as now → 'it shows on the arcade's map as on home, and waits while a
  fight's sheet is open', 'the map lets it show; a fight's sheet, then its versus screen, hide it'

#### 2026-11-25 · code unchanged since `d3159cf` (notes only) · step P16 `codex/iter5-ai-opponents`, with A4's and A5's parts: the last phone check and the CI coverage
The user's results of the last phone check (2026-11-24 22:21–22:25, Galaxy S26+, the build of `21fc291`, the phone
off the laptop, checked on a screen recording; the message of 2026-11-24 in the Prompt Log) are written into the
TODO spots of the entries above: P16's in the `7362fb4` entry's Manual check (and the earlier P16 spots point there),
A4's in its effects entry, A5's in its start bubble's entry. A2–A5 take no more commits after their Codex reviews (the
user, 2026-11-24), so A4's and A5's parts are recorded on this branch; `codex/iter5-hold-chair` was not merged again
(no new commit). In short:
- **P16:** the app's start, 게임 시작 with 친구와의 대전, the arcade home, STAGE 3's clear, fail, 다시 도전 and 아케이드로,
  the boss match through R2 to 1층 클리어! (the break's 자세 잡기 inside its button), 2F's STAGE 7 with the fever at
  0:15 and its fail screen worked; in the boss match and on 2F the battle track went on to the end and the jingle
  played on a KO and on a loss. Google sign-in was not seen: the button did nothing, which per 박진영 (P7, Google sign-in) is this PC's
  debug SHA-1 not being registered (an environment issue, not code; checked again with the login screen's redesign,
  P8).
- **The invite fix (`c02a9ff`):** not in that build, and an invite needs a second account and device, so it was not
  tried on the phone (user, 2026-11-24); the 4 tests in `arcade_flow_test.dart` and the 3 in `main_test.dart` (the
  real app) check it instead.
- **A4:** the plank's clear with three stars and the cheers, two warnings with "실패!" and the leave button gone, the
  fail screen's two reasons, the sounds in order; the bubbles seen for about 1.2 s and 1 s; standing up read "무릎 떼요";
  the clear ended by warnings after a star stands on the tests.
- **A5:** the chair pose was not tried; its judging stands on the check of 02:52 (`e17e332`), the two-line start bubble
  on the tests; the console numbers of spec 7 and reviewer A5 run 4's slow rise could not be seen (the phone was off
  the laptop, so no console).
- **Follow-ups after the merge** (no code changed now; in the local progress file): the hold bubbles' time (the start
  bubble counted from when GO! is gone), the arcade bots' level (push-ups about 5% easier, squats about 5% harder),
  plain hold and break screens and a weak floor-cleared staging, R1's KO button "결과 보기" that opens the break, the
  standing-up reason, the silence after a jingle on the result, the map and the next stage's briefing (about 16 s from
  the boss clear to 2F's first setup; home has the menu track at the app's start), and the win jingle cut without a
  fade on entering "1층 클리어!" (about 3 s heard of about 4 s).
- **Coverage:** #89's (A2) and #88's (A3) CI comments are copied into A2's and A3's entries above: on `dc5947b` and
  `c1f5f5f`, every layer above its target (Model 99.4% / 99.3%, ViewModel 98.3%, Service 97.5% / 97.4%, View 98.1%).
  #90 (A4), #92 (A5) and #91 (P16) have no CI comment: their bases are the stage branches below them, not `main`, and
  `tests.yml` runs only on pull requests to and pushes to `main`. Not run by hand (the user, 2026-11-24); each
  entry's coverage line says so and stays a TODO until its PR targets `main`.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter analyze`, `flutter test`.

- **Tests:** `flutter analyze` found no issues. `flutter test` 4657 passed, 0 failed, 10 skipped (2026-11-25, on `d3159cf`'s code; the same 10 skips as above). No test or code file changed.
- **Review:** local reviewer run 13, APPROVE (notes only). It checked each result against the user's message, the
  CI numbers against the two comments, the cited tests, and the Prompt Log against the export. Its 5 Minors were
  fixed before the commit: three additions not in the message (two parentheticals; 박진영's step is P7, not P9);
  three lines that still said "not yet on a phone"; the AI notes' wording (where the CI numbers went, the
  placeholder body's 38 s, the review count); TODOs for the user's decision on A5's two shortfalls; and PR #91's
  body, updated after the push.
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Shortfalls:** coverage for A4, A5 and P16 waits for CI on `main`. Not seen on the phone: Google sign-in (the
  environment; again with P8's login screen), the invite fix (the tests instead), the chair pose and the console
  numbers (A5; TODO(Woohyun Song): whether and when to check them, the user's decision).

#### 2026-11-25 · code at commit `fbfef4c` · step P16 `codex/iter5-ai-opponents`: the stage asked for opens once its stars are kept (PR #91's Codex review)
PR #91's Codex review on `f27a7e8` (P2, `lib/screens/arcade_screen.dart` L78–79): a cleared fight or boss match
keeps its stars without waiting (`ArcadeViewModel.finishBattle` → `record`, not awaited); 다음 스테이지 or
"{n}층으로" asks for the next stage (`ArcadeFlow.next`) and goes back to the map, whose `didPopNext` started
`refresh()` without waiting and took the request on the next frame. If the save had not ended, the stage was still
locked, `_open` did nothing and the request was gone. Checked in the code (the user's item 1, 2026-11-25), it can
happen, and the store's order adds a second case: A2's `recordStage` reads and then writes, and a read is not ordered
with it, so a `refresh` begun while the stars were kept could be answered with the progress before them; answered
after the save, it put that older progress back (its read number was still the newest).

The fix, as the user set it (P16's own files; A2–A5 unchanged):
- **`ArcadeViewModel`:** `saving` while a play's stars are kept; `record` tells its listeners when the save ends,
  kept or failed, and drops a read begun meanwhile; `takeOpenRequest()` takes the stage asked for once the progress
  shows it open, keeps it while it is locked and a save goes on, and drops it when it is locked with nothing being
  kept (the save failed), so it never waits on its own; `hasRequest`.
- **`ArcadeScreen`:** back from a stage it waits for `refresh()` and then looks at the request, and again on each
  change while it waits. A waiting request is dropped when another page or a dialog goes over the map, when the map
  is not the current page by the time it looks, and when the map is gone, so it never opens later on its own. It
  waits from the moment the map is back, so a page opened during that read drops it as well.
- **Found, not changed (for the user):** a hold stage's 다음 스테이지 (`_playHold`) has the same window. A4's
  `HoldStageViewModel._finish` keeps the stars without waiting, straight to the store, so the arcade's view model
  neither waits for nor hears that save, and `_playHold`'s `refresh` can read before the write. A fix is either in
  A4's file or a P16-side store wrapper passed through `ArcadeFlow.openHold`.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter analyze`, `flutter test`.

- **Tests:** `flutter test` 4670 passed, 0 failed, 10 skipped (4657 at `f27a7e8`, plus the 13 new tests) (2026-11-25, on `fbfef4c`; the same 10 skips as above). `flutter analyze` found no issues.
- **New tests:** 8 in `test/screens/arcade_flow_test.dart` with a store whose saves end late (`_SlowSaveStore`), 5 in
  `test/viewmodels/arcade_viewmodel_test.dart`.
- **Checked against the old code:** on the screen before the fix, 'a fight's 다음 스테이지 waits for the save, then
  opens the next stage' and 'a boss match's 2층으로 waits the same way' fail (no sheet after the save). Without the
  `_reads` step at a save's end, 'a read begun while the stars are kept, answered after them, does not bring back the
  progress before them (PR #91 review)' fails. Each drop, taken out alone, fails its own test: the map gone ('leaving
  the map while the save goes on drops it: the next visit opens nothing on its own'), a page over it ('a page opened and closed again before the save ends
  drops it too'), not the current page ('a page over the map while the progress is still being read drops it: nothing opens
  over that page'). With the wait starting only after the read, 'a page opened and closed while the progress is
  still being read drops it too' fails.
- **Other checks:** `ownership_guard.py --check-diff` OK (113 paths).
- **Review:** local reviewer runs 14 and 15. Run 14, CHANGES_REQUESTED: (Major) a request still waiting when the map was left (popped during the save) stayed asked for, and a later visit opened STAGE 8's sheet by itself on a lost stage's 아케이드로; now dropped in `dispose`, with the test 'leaving the map while the save goes on drops it: the next visit opens nothing on its own'. Its Minors: the drops were not pinned one by one (two tests added) and a comment named `_playHold` as the safe pattern (reworded). Run 15, APPROVE, with 3 Minors: the hold stage's window (above, for the user); a page opened and closed during the read right after coming back was not dropped (the wait now starts before the read, with the test 'a page opened and closed while the progress is still being read drops it too'); the doc comments of `request` and `takeRequest` (fixed).
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Shortfalls:** the race needs a save slower than the tap, which the tests force with a fake store; it was not tried
  on a phone. The hold stage's window above is open.
- **Manual check:** none for this fix (a slow save cannot be made on demand on the phone).

### Test cases added or changed in this phase
| Layer | File | What it covers |
|---|---|---|
| ViewModel | `test/viewmodels/arcade_viewmodel_test.dart` (updated) | group 'record': 'saving while the stars are kept; the end is heard, kept or failed (PR #91 review)', 'a read begun while the stars are kept, answered after them, does not bring back the progress before them (PR #91 review)'; new group 'the stage asked for, taken once it is open (PR #91 review)': open taken at once, locked while kept then taken, locked with nothing kept or after a failed save dropped |
| View | `test/screens/arcade_flow_test.dart` (updated) | new group 'the stage asked for while its stars are still being kept (PR #91 review)': a fight's 다음 스테이지 and a boss match's 2층으로 open after a late save; a failed save drops it; a page over the map, a page opened and closed, a page while the progress is read, a page opened and closed during that read, and leaving the map each drop it |

### Acceptance criteria → tests (the user's items 2 and 3)
- The stage asked for opens once the progress shows it open, after a late save → 'a fight's 다음 스테이지 waits for
  the save, then opens the next stage', 'a boss match's 2층으로 waits the same way', 'locked while the stars are kept:
  still asked for, and taken once they are'
- A failed save drops it (no endless wait) → 'a save that fails drops it: the map stays, and a later read opens
  nothing', 'locked with nothing being kept, or after a failed save: dropped'
- A read during the save does not undo it → 'a read begun while the stars are kept, answered after them, does not
  bring back the progress before them (PR #91 review)'
- It never opens later out of place → 'another page over the map meanwhile drops it: nothing opens over that page or
  back on the map', 'a page opened and closed again before the save ends drops it too', 'a page over the map while
  the progress is still being read drops it: nothing opens over that page', 'a page opened and closed while the
  progress is still being read drops it too', 'leaving the map while the save goes on
  drops it: the next visit opens nothing on its own'

#### 2026-11-25 · code at commit `5b09d87` · step P16 `codex/iter5-ai-opponents`: a hold stage's 다음 스테이지 waits for its stars too
The entry above left one window open: a hold stage's 다음 스테이지 (`_playHold`). A4's `HoldStageViewModel._finish`
keeps the stars without waiting, straight to the store it is given, so the arcade's view model neither waited for nor
heard that save, and `_playHold`'s `refresh` could read before the write and `_open` did nothing. The user's decision
(2026-11-25): fix it in P16 only, A4's files read only, with the fight's rules.
- **`ArcadeViewModel.holdStore`:** a wrapper of the arcade's store. Reads and writes go to the store; a stage's stars
  go through the same path as `record` (`saving`, the progress after them, a read begun meanwhile dropped). A failed
  save still fails for A4's screen, which catches it; another account's save is only kept and does not count as this
  account's.
- **`ArcadeFlow.holdStore(context)`** gives it, and `ArcadeFlow.openHold` hands it to A4's screen as its store.
- **`ArcadeScreen._playHold`:** 다음 스테이지 asks for the stage after the hold and takes a fight's path back
  (`_backFromStage`): it opens once the progress shows it open, and is dropped by the same rules.
- No hold stage opens a new floor: the holds are 3, 5, 9, 11, 15, 17, 21 and 23, and each floor ends with its boss
  (6, 12, 18, 24). The nearest case, hold 5 → boss 6's intro, is tested.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter analyze`, `flutter test`.

- **Tests:** `flutter test` 4680 passed, 0 failed, 10 skipped (4670 at `70a1d2a`, plus the 10 new tests) (2026-11-25, on `5b09d87`; the same 10 skips as above). `flutter analyze` found no issues.
- **New tests:** 6 in `test/screens/arcade_screen_test.dart` (a stand-in hold that keeps its stars through
  `ArcadeFlow.holdStore` without waiting, as A4 does, with a store whose saves end late), the wiring test changed, 4 in
  `test/viewmodels/arcade_viewmodel_test.dart`.
- **Checked against the old code:** with the store handed over as before and the old `_playHold`, 'it waits for the
  save, then opens the stage after it', 'before a boss match it opens the boss's intro the same way' and 'a hold
  left from its own page, as A4's is: the stage after it opens once, after the save' fail. Without the drop when the
  map goes, 'leaving the map meanwhile drops it: the next visit opens nothing on its own' fails; 'a page over the map
  meanwhile drops it' fails with both cover drops taken out (each alone is pinned by the fight tests above).
- **Other checks:** `ownership_guard.py --check-diff` OK (113 paths). A slip: `dart format lib` reformatted two files of
  other steps (`lib/widgets/character_motion.dart`, `player_avatar.dart`); restored with `git checkout --` at once, and
  the reviewer confirmed them unchanged.
- **Review:** local reviewer run 16, APPROVE. Its 4 Minors were fixed before the commit: no test left the hold from a
  page of its own, so the map's two runs back (the page's close and `_playHold`) were not exercised (test added; it
  fails on the old `_playHold`); another account's save bumped this account's reads and `saving` (guarded, with a
  test); the `_saving` doc; the local progress file.
- **Coverage:** TODO(Woohyun Song): no CI comment yet: PR #91's base is `codex/iter5-hold-chair`, not `main`, and the
  CI (`tests.yml`) runs only on pull requests to `main`; not run by hand (user, 2026-11-24). Copy it once the
  PR targets `main`.
- **Shortfalls:** a slow save is forced by fakes only; A4's real screen is not driven to 다음 스테이지 in a test (its
  wiring test checks that it gets `holdStore` and that a save through it is seen).
- **Manual check:** none for this fix (a slow save cannot be made on demand on the phone).

### Test cases added or changed in this phase
| Layer | File | What it covers |
|---|---|---|
| ViewModel | `test/viewmodels/arcade_viewmodel_test.dart` (updated) | new group "holdStore, the store of A4's hold screens (PR #91 review)": reads and writes are the arcade's store's; a stage's stars kept as `record` keeps them (saving, the progress after, heard); a failed save still fails for the screen; another account's stars kept, not shown, not counted |
| View | `test/screens/arcade_screen_test.dart` (updated) | new group "a hold's 다음 스테이지 while its stars are still being kept (PR #91 review)": it waits for the save, then opens the stage after it; left from its own page it opens once; before a boss match the intro; a failed save, a page over the map and leaving the map drop it; the wiring test expects `arcade.holdStore` and a save seen through it |

### Acceptance criteria → tests (the user's items 1 and 2)
- Hold clear → 다음 스테이지 after a late save opens the next stage → 'it waits for the save, then opens the stage
  after it', 'a hold left from its own page, as A4's is: the stage after it opens once, after the save', 'before a
  boss match it opens the boss's intro the same way' (no hold opens a new floor)
- The same drops as a fight's → 'a save that fails drops it: the map stays', 'a page over the map meanwhile drops
  it', 'leaving the map meanwhile drops it: the next visit opens nothing on its own'
- A4's files only read; its screen gets the wrapped store → the wiring test 'the app's own way into a hold: A4's
  screen for the stage, with the arcade's store, account and the user's character'

#### 2026-11-25 · code at commit `c91a8f3`, `origin/main` merged in `def1c5e` · step P8 `codex/iter5-auth-screens` (Redesign the sign-in and sign-up screens, team order #5)
P8 redesigns the login screen and the first sign-up (nickname) step on top of P7's Google sign-in (#93). It follows
the design hand-off's spec `p8/SPEC.md` v1 (2026-11-25, not committed) and its `.dc.html` sources:
- **First screen (LoginB look d1):** the GYMMOUSE logo, the group photo of the six characters on a three-step
  podium, "Google로 시작하기" and the "아이디로 로그인" link.
- **States (LoginS):** L1 is a spinner in the Google button with the button and the link greyed. C2 is a grey line
  "로그인을 취소했어요". F1 is an error box over the button, with the button saying "Google로 다시 시도". An expired
  session shows in the same box, with the button left as "Google로 시작하기" (the user's decision).
- **Id sheet:** the app's id and password with `LoginViewModel`'s checks and messages, the lime 로그인 button, and
  the link to the id sign-up screen (unchanged).
- **Nickname step:** a count that stops at 12/12, input cut at 12 after a Korean letter is finished, the help or
  error line, an F1 box, and the lime 시작하기 button.
- **Group photo:** the six 18 s loops of `ChL.dc.html` (`motions.d1`) are converted number for number into the app's
  character engine (the home rig's form). The faces, the thumb and RepBot's back glove that the app lacked are added
  as a draw patch. The photo's clock stops while it is covered or the app is in the background. With the device's
  animations off it draws the design's still moment.
- **View model:** `LoginState` gets two fields with defaults, `cancelledWith` and `failedWith`, so the screen can
  tell a cancel and a Google failure apart. Messages and behavior are unchanged.
- **Line breaks:** the login screens' Korean breaks only at spaces (word joiners in the drawn text only). When the
  words need two lines, the break is balanced ("Google로 / 로그인하는 중…").

The branch starts at `origin/main` `18b9259`; the code is four commits, `68597e4`, `5e5c8aa`, `e1b88b1` and
`c91a8f3`. Before the push, `main` had moved to `9757854` (#96 telemetry, #89 A2), and I merged it in (`def1c5e`; it
touches none of P8's code, only these notes). I ran these in `gymrats_app/` on Windows on `def1c5e`, without coverage
(this PC's rule):

```sh
flutter pub get
flutter analyze
flutter test
flutter test test/widgets/auth_cast_test.dart test/widgets/auth_form_test.dart test/screens/login_screen_test.dart test/screens/auth_screens_test.dart test/screens/social_signup_screen_test.dart test/viewmodels/login_viewmodel_test.dart test/models/character_rig_test.dart test/theme/app_theme_test.dart test/design_tokens_test.dart test/auth_flow_test.dart test/demo/auth_history_demo_test.dart
```

No server, Google account, camera or secure storage is needed:
- **Auth fakes:** `ScriptedAuthRepository`, `InMemoryAuthRepository` and `FakeSocialSignIn` from
  `test/support/auth_fakes.dart`. The nickname test adds a subclass that holds the account's creation.
- **Golden values:** `test/widgets/auth_cast_golden.json` holds values from the design's own JavaScript.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | TODO(Woohyun Song): from the PR's CI comment (`character_rig.dart` only) | 11/25 | CI comment "Tests and coverage (GitHub Actions)" on the P8 PR |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the PR's CI comment (`login_viewmodel.dart`) | 11/25 | same CI comment |
| Service | flutter_test, fakes | 85% | not changed by P8 | 11/25 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment | 11/25 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not changed by P8 | 11/25 | same CI comment |

- **Tests:** `flutter test` passed 4340, failed 0 and skipped 10 (2026-11-25, `def1c5e`), and `flutter analyze`
  found no issues. Before the merge, the code's tree passed 4134/0/10. The 10 skipped tests are the ones already skipped on `main` (a live server smoke
  test and 9 known push-up judge errors), untouched.
- **The step's files:** the eleven files in the second command passed 267 tests:
  - new: auth_cast 22, auth_form 19, login_screen 15
  - changed: auth_screens 18, social_signup_screen 13, login_viewmodel 17, character_rig 34, app_theme + design_tokens 108
  - flows: auth_flow + auth_history_demo 21
- **Ownership:** `ownership_guard.py --check-staged` was OK on each commit, and `--check-diff` on `def1c5e` was OK
  (P8 · 20 paths against `origin/main`).
- **Against the design (group photo):** the first screen was drawn at 0 s to 7 s in a throwaway test (not committed)
  and compared by eye with `shots/cast_timeline_0-7s.png` and `shots/state_base.png`. The poses, faces, the thumb,
  the sparks, the seal's heart, the places and the podium match.
- **Against the design (states):** each state was captured with the app's fonts at 360 × 780 and at 320 × 640 with
  text 1.3 and compared with the `shots/state_*.png` files. Base, L1, C2, F1, the id sheet and its error, and the
  nickname step's base, empty error and busy match. The user checked all 27 images (2026-11-25).
- **Fixed after the user's check:** at 320 × 640 with text 1.3, "Google로 로그인하는 중…" and "Google 로그인에
  실패했어요." broke inside a word. They now break as "Google로 / 로그인하는 중…" and "Google 로그인에 / 실패했어요."
- **Not covered by a test:** with the device's bold text on, `AuthWords` measures its lines in bold, as they are
  drawn (reviewer run 3). The test font's bold and regular letters are equally wide, so a test could not fail.
- **Known differences, kept by the user's decision (2026-11-25):**
  - The nickname field has no placeholder.
  - The id sheet is about 16 px taller than LoginS: the close button and the sign-up link keep the app's 48 px tap
    area.
  - The links' underline sits at Flutter's default distance, not CSS's 3 px.
  - At 320 × 640 with text 1.3 the F1 box covers the lower part of the bottom row's characters. Nothing overflows.
- **Out-of-step files, act first and report after (the user's decision, 2026-11-25):**
  - `lib/models/character_rig.dart`: a rig color may be `#RRGGBBAA`, for ChL's half-clear blush.
  - `test/auth_flow_test.dart` (P7) and `test/demo/auth_history_demo_test.dart`: they now open the id sheet first
    and use the new words; the flows and their expectations are the same.
- **Coverage:** TODO(Woohyun Song): copy the P8 PR's CI comment (commit, run link, per-layer numbers, P8's files).
- **Phone check, done 2026-11-25** by the user (Galaxy S26+, a release build of the pushed branch, the cable out, two
  screen recordings of 31 s and 59 s; the user's message is in the Prompt Log):
  - **First screen:** the logo right under the status bar, the group photo, the Google button and the link sit as
    in the design. The characters move and change faces, and go on moving after a return from the recent apps.
  - **L1:** while Google's account picker was up, the turning ring, "Google로 로그인하는 중…" and the greyed button
    and link were as designed.
  - **C2:** closing the account picker showed "로그인을 취소했어요" over the button; a new tap cleared it.
  - **Id sheet:**
    - It opened from the link, three times, and the characters behind it kept moving.
    - With the keyboard up, the fields, the 로그인 button and the sign-up link stayed visible.
    - A wrong password showed the busy button (pale lime, spinner), then "아이디 또는 비밀번호가 맞지 않아요.";
      typing again cleared it.
    - "처음이신가요? 회원가입" opened the id sign-up screen, and back returned to the sheet.
    - The right password went home.
  - **Not seen on the phone:**
    - F1 and the nickname step: the build is signed with a debug key whose SHA-1 is not yet registered in the team's
      Google Cloud (asked of 박진영). Picking an account made the plugin report a cancel, so C2 showed. To check
      again after the registration; until then the widget tests above cover them.
    - The one-a-second start and the 18 s loop: not caught in the recordings; left to `auth_cast_test`.
  - **Fixed after the phone check (`dd08911`):** after a wrong password, closing the sheet made Samsung Pass offer
    to save the login. The sheet's autofill group committed when it closed. It now cancels on close, and the screen
    asks to save only after a login that worked (`TextInput.finishAutofillContext()`). New test in
    `auth_screens_test.dart`: 'the password manager is asked to save only after a login that worked, never when the
    sheet closes'. It fails without the fix ([true] instead of [false]). `flutter analyze` on the two files found no
    issues, and auth_screens, login_screen, auth_flow and auth_history_demo passed 55 tests (the user's call: no
    reviewer run for this fix).

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/auth_cast_test.dart` (new) | **Data:** the six places, scales, flips, teams and clocks of LoginB; the podium, the planes, the shadows; every loop is 18 s and holds each pose 6 s; every face and flag a loop uses has shapes; malformed data rejected.<br>**Golden:** each of the six matches ChL's own `RIGX.vals` at every sampled time (pose numbers, expression, hop and rock, flags and what they show, sparks and hearts).<br>**Timing:** one more character changes pose each second from 1 s to 6 s; animations off draws LoginB's `ft` moment.<br>**Stage:** one picture with the cast label; the clock starts at 0 and runs, never ticks with animations off, stops in the background and under an opaque screen and goes on after, not under a sheet; the band's scale. |
| View | `test/widgets/auth_form_test.dart` (new) | **Text:** `keepWordsWhole` (joiners only inside words, nothing lost, a decomposed letter kept whole); with joiners a narrow line breaks at a space where the plain sentence breaks inside a word; `authLines` (fits, balanced two lines, three lines or one word left to wrap); `AuthWords` finds and reads as written; `splitFirstSentence`.<br>**Parts:** the error box (bold first sentence, grey rest, amber mark, announced); the cancel line and field error announced; the Google button (G, busy spinner, grey words, no taps); the lime button (arrow, busy pale with spinner, no taps); the spinner turns and stands still with animations off; links (underlined, lighter when off, 48 high); round buttons (48 tap area); input fields (named, 17 text, spaced dots); every glyph draws. |
| View | `test/screens/login_screen_test.dart` (new) | **First screen:** logo, line, photo, Google and the link in order; no fields, no sign-up link; Google signs in; no Google service shows only the link; tap sizes.<br>**States:** L1 (spinner, words, no taps on the button or link); C2 (line over the button, announced, gone on a new tap or when the sheet opens); F1 (box over the button, bold and grey sentences, "Google로 다시 시도", gone on a new tap); each failure's words; the expired box with "Google로 시작하기".<br>**Sizes:** 360 × 780 and 320 × 640 with text 1.3, every state and the sheet with errors fit, a note never reaching the lowest row's feet; at the design's size the box covers the bottom step and the photo keeps its size. |
| View | `test/screens/auth_screens_test.dart` (updated) | **Id sheet:** opens from the link; X, back and outside close it and keep the text; field errors under the fields; the wrong-credentials line over the button; a network failure; busy; closed while logging in, a wrong password shows nowhere; the sign-up link; a login closes the sheet as the app does; the keyboard; the password manager saves only after a login that worked (`dd08911`).<br>**Google:** a new Google account opens the nickname step; (a) after a Google failure the sheet has no error; (b) a wrong password then closing leaves nothing; (c) the expired box goes when the sheet opens and closes.<br>**Unchanged:** the id sign-up screen's tests. |
| View | `test/screens/social_signup_screen_test.dart` (updated) | **Layout:** back, 회원가입, the photo, the nickname with count and help, the lime 시작하기, and only the design's words; back creates nothing.<br>**Input:** the count follows and stops at 12, a 13th letter is not taken; the cut waits for composition.<br>**States:** 시작하기 creates the account; the empty error replaces the help line; busy (pale, spinner, "계정을 만드는 중…", one request); a server failure's F1 box; the expired provider login.<br>**Sizes:** 360 × 780 and 320 × 640 with text 1.3, and the keyboard up. |
| ViewModel | `test/viewmodels/login_viewmodel_test.dart` (updated) | cancel told apart until the next try; the id form clears the cancel note; every Google failure sets `failedWith`; wrong credentials and the expired session do not |
| Model | `test/models/character_rig_test.dart` (updated) | `#RRGGBB` opaque, `#RRGGBBAA` with its alpha last (`#FF000080` is half red), other lengths rejected |
| Design | `test/theme/app_theme_test.dart`, `test/design_tokens_test.dart` (updated) | the Auth colors and text styles; the new screen and widget files use only tokens |
| App flow | `test/auth_flow_test.dart`, `test/demo/auth_history_demo_test.dart` (updated) | the same flows through the id sheet and the new words |

### Acceptance criteria → tests (the P8 spec, section 9; the local task.md left the step's criteria to the spec)
- 9-1 First screen → login_screen_test: 'the logo and its line, the group photo, Google and the id link; no fields and
  no sign-up link', 'Google로 시작하기 signs in with Google'
- 9-2 States → login_screen_test: 'L1: …', 'C2: backing out shows the grey line, …', 'C2: opening the id sheet clears
  it', 'F1: the box over the button, …', 'an expired session shows in the box, …'
- 9-3 First sign-up → auth_screens_test 'a new provider account opens the nickname step'; social_signup_screen_test
  'an empty nickname: …', 'while it creates the account: …', 'a server failure shows the F1 box over the button',
  'the count follows the text and stops at 12; a 13th letter is not taken'
- 9-4 Id sheet → auth_screens_test: 'the link opens it: …', 'X, back and a tap outside each close it, …', 'a wrong id
  or password shows one line over the button, …', 'the sign-up link opens the id sign-up screen', 'a login closes the
  sheet with the screen, as the app does', '(a) …', '(b) …', '(c) …'
- 9-5 Group photo → auth_cast_test: 'each second from 1 s to 6 s, exactly one more changes pose', 'animations off:
  never ticks', 'stops while another screen covers it, then goes on', 'stops while the app is in the background, then
  goes on', and the six golden tests
- 9-6 Overflow → login_screen_test and social_signup_screen_test: the '… text 1.3: …' tests at both sizes
- 9-7 Existing screens → the full `flutter test` above (home, battle and victory character tests unchanged and
  passing; the id sign-up screen's tests unchanged); character_rig_test's color test

#### 2026-11-26 · code at commits `4a1266d`, `c146864`, `d6c917e` and `cd7677e` · step A7 `feat/iter5-defeat-pose` (PvP 패배 포즈 추가 및 무승부 표시 수정, a separate task in the PM's merge plan)
A7 changes what the battle report plays when it opens after a PvP battle (online 1v1 and friend battles; both reach
`ResultScreen` through `onlineBattleResult`). Before it, only a win had a cut-in; a loss and a draw showed the same
frustration on a white stand, so a draw looked like a loss. It follows the design hand-off's `ldfx/SPEC.md` v2
(2026-11-26, not committed) and its mockup `LdA.dc.html` ("거울 컷인"), whose values are used as they are:
- **Loss:** a red panel (`AppColors.danger`) with white rain shuts down from the top. My character drops in and
  frustrates (the W5 `frustrate` motion) at 2.2 times under the band 패배, which comes in from the left and sags.
  The panel and the character then shrink onto the seat's white stand: the same end look as before.
- **Draw:** a lime half and a pink half meet on a slant. My character and the opponent hop in and bump fists (a
  spark, a shake), then spring back into the battle stage's guard pose under the band 무승부. The opponent leaves to
  the right and mine sits on a lime and pink stand. No frustration and no 패배 appear anywhere.
- **Unchanged:** the win's scenes (KO, time, opponent left), the sounds, the report's titles, the skip on a tap,
  and reduced motion showing only the end look (now the loss's or the draw's).
- **The opponent's character:** the online result now keeps it (`characterId: session.opponent?.character`), and
  the result screen passes the battle's opponent to the scene in one argument. Without one the scene draws the
  default character, or RepBot for a bot, as the stages do.

The branch starts at `origin/main` `cc0df4f`; `main` had not moved at the push. I ran these in `gymrats_app/` on
Windows, without coverage (this PC's rule):

```sh
flutter pub get
flutter analyze
flutter test
flutter test test/widgets/victory_defeat_scene_test.dart test/widgets/victory_pvp_outcome_test.dart test/widgets/victory_scene_test.dart test/widgets/victory_overlay_test.dart test/widgets/victory_seat_test.dart test/widgets/victory_motion_test.dart test/screens/result_screen_test.dart test/services/game/online_battle_result_test.dart test/design_tokens_test.dart test/demo/result_scene_demo_test.dart
```

No server, camera or device is needed:
- **Fakes:** a finished `OnlineBattleSession` set up by hand (no socket), `MemoryCharacterStore` for my character.
- **Golden values:** `test/widgets/victory_defeat_golden.json` holds values from the design's own JavaScript. A node
  script ran `LdA.dc.html`'s `renderVals()` with `toFixed` made exact (the design rounds positions to 0.1 px for CSS,
  coarser than the test's 0.01). The times are SPEC 6's and the times inside every stretch and next to every switch.
  The test file's header has the method; the script stays outside the repo (the user's decision).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | not changed by A7 | 11/26 | CI comment "Tests and coverage (GitHub Actions)" on the A7 PR |
| ViewModel | flutter_test, fakes | 90% | not changed by A7 | 11/26 | same CI comment |
| Service | flutter_test, fakes | 85% | TODO(Woohyun Song): from the PR's CI comment (`online_battle_result.dart`) | 11/26 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment (the victory files, `result_screen.dart`) | 11/26 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not changed by A7 | 11/26 | same CI comment |

- **Tests:** `flutter analyze` found no issues. The full `flutter test` on the code (the reviewer's second run, the
  same tree as the commits) passed 4903, failed 0 and skipped 10. The 10 skipped are the ones already skipped on
  `main` (a live server smoke test and 9 known push-up judge errors), untouched.
- **Timing tests that failed once in a full run:**
  - My first full run (before the last test was added) passed 4900, skipped 10 and failed 1:
    `online_battle_integration_test.dart` 'both phones show the same score, …'.
  - One of the reviewer's runs failed 2: `voice_guidance_test.dart` 'a line the engine never finishes gives way
    after maxUtterance' and `online_battle_integration_test.dart` 'server deduplicates verdicts, …'.
  - All three are timing tests in files A7 does not touch. Alone they passed: the integration file 3/3 times
    (74 tests), both files together 97/97. The next full run passed them.
- **The step's files:** the ten files in the last command passed 307 tests on `cd7677e`:
  - new: victory_defeat_scene 19, victory_pvp_outcome 15, result_scene_demo 3
  - changed: victory_scene 22, victory_overlay 25, victory_seat 17, result_screen 88, online_battle_result 9,
    design_tokens 83
  - unchanged, run with them: victory_motion 26 (the W5 rig data and motions)
- **Ownership:** `ownership_guard.py --check-staged` was OK on each commit, and `--check-worktree` was OK with 18
  paths before the commits.
- **Golden checks:**
  - Each loss sample is compared for all five characters (40 times each) and each draw sample (43 times) for all
    five. The compared values are the stand, the panel shapes and insets, the rain, the figure or both fighters
    (feet, scale, facing, pose, frustration clock), the spark, the shake and the band.
  - The reviewer ran the extraction again on `LdA.dc.html`: byte-identical output, within 5e-7 of the committed file.
  - Three deliberate mistakes in `victory_defeat.dart` each made the golden test fail (the band's sag ease, the
    frustration starting at 149 ms, the shake rate 0.34), and were undone.
- **Against the design (by eye):** a throwaway widget test (not committed) drew the result screen at LdAFrames'
  twelve times with the app's fonts into one sheet. Compared with `shots/LdAFrames.png`, every frame matches: the
  shutter, the fall, the landing with the band, the sag, the shrink, the seat; the halves, the hops, the fists and
  spark, the guard with 무승부, the opponent leaving, the half and half stand.
- **The draw's skip:** the reviewer's first run found no test that taps through a draw (SPEC 7.5). The test
  'draw (A7): a tap anywhere jumps to its end look and ends it once, …' was added, with the same for a loss. It fails
  when the draw's skip button is hidden.
- **Changed existing tests (old loss and draw only):** W5's "a loss and a draw are the same frustration, 760 ms
  (물렁범 820 ms), no panel or band" was pinned in victory_scene_test, victory_overlay_test, victory_seat_test and
  one result_screen_test test. Those expectations now check A7's scenes. No win expectation changed. The W5 golden's
  loss samples (`victory_golden.json` `lose`) are no longer read; its `loseStill` still checks the loss's end look.
- **Decisions kept as the design (the user, 2026-11-26):** 물렁범's frustration (820 ms) stops at 760 ms and then
  shows its end pose; the draw's two characters move as the stage's idle from 880 to 1500 ms.
- **Out-of-step files (PM approved 2026-11-26, except the last):**
  - `lib/screens/result_screen.dart` (P15): one argument line, `opponent: widget.result?.matchup.opponent,`.
  - `test/screens/result_screen_test.dart`: the one test that pinned the old scene, and a new opponent test.
  - `lib/services/game/online_battle_result.dart` and its test: the opponent's character.
  - `test/design_tokens_test.dart`: one line for `victory_defeat.dart` (act first and report after).
- **Coverage:** TODO(Woohyun Song): copy the A7 PR's CI comment (commit, run link, per-layer numbers, A7's files).
- **Phone check:** TODO(Woohyun Song): the user's check with `lib/demo/result_scene_demo.dart` (results, character
  pairs, reduced motion; screenshots or clips in the PR).

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/victory_defeat_scene_test.dart` (new) | **Golden:** every loss sample for the five characters and every draw sample, as listed above; the golden has SPEC 6's times.<br>**Loss:** the panel is `AppColors.danger`, stripes and rain white; the frustration at 2.2 times on the big feet line after landing, its clock from 150 ms; 물렁범 stops at 760 ms and ends on its end pose; the band 패배 from the left (a win's from the right, its turn the rig's).<br>**Draw:** every 5 ms never the frustration, 패배, a hit or knocked-out pose, the band 무승부, the opponent the one given; lime and pink halves with the design's stripes; the stage's idle 880–1500 ms on one clock, not before or after, the end still.<br>**Other screens:** 412 × 915: the halves meet in the middle, the big scene scaled, the shutter, the shrink and the end follow the seat. |
| View | `test/widgets/victory_pvp_outcome_test.dart` (new) | **PM acceptance**, for a server-ended draw, win and loss: the stage shows only DRAW, WIN! or LOSE and the matching poses (a draw: both in guard throughout); the report plays the draw, time-win or loss scene with the opponent, titled 무승부, 승리 or 패배, every 50 ms never the wrong motion or band, then the seat; the 기록보관소 row "푸쉬업 · 무승부/승리/패배" (a draw has no 패); the report opened from it shows only the end look and the title.<br>**Fit (SPEC 7.8):** loss and draw at 360 × 780 with text 1.3, 320 × 640, 320 × 640 with text 1.3: no exception while playing or after, the seat inside the screen. |
| View | `test/widgets/victory_overlay_test.dart` (updated) | **A7:** a loss: the red cut-in (red pixels where the report was), the band 패배, 2.2 times, the end at 2000 ms on the white stand; a draw: lime and pink pixels, both fighters bumping fists, every 10 ms no frustration or 패배, the end in guard on the lime and pink stand; the opponent drawn as the stages draw it (its own, RepBot for a bot without one, else the default); a tap skips a loss and a draw to the end look once; reduced motion for a win, a loss and a draw; the painter repaints for a new opponent and paints every result at the A7 times.<br>**Unchanged:** every win test. |
| View | `test/widgets/victory_scene_test.dart` (updated) | a loss ends on W5's end look (`loseStill`); a win 2100 ms, a loss and a draw 2000 ms; bands 패배 and 무승부, no confetti but a win's; the win tests unchanged |
| View | `test/widgets/victory_seat_test.dart` (updated) | the draw's seat: my character alone in guard at the seat's feet, on the lime and pink stand; win and loss seats unchanged |
| View | `test/screens/result_screen_test.dart` (updated) | a loss and a draw play A7's cut-in with their band, no confetti, and end on the seat at 2000 ms (was: no cut-in, 760/820 ms); the scene gets the battle's opponent, and a draw draws them beside my character |
| Service | `test/services/game/online_battle_result_test.dart` (updated) | the online result carries the opponent's character; none without an opponent |
| Design | `test/design_tokens_test.dart` (updated) | `victory_defeat.dart` uses only tokens |
| Demo | `test/demo/result_scene_demo_test.dart` (new) | a draw against 펭뚱이 with 곰탱이 plays both and ends on the seat, back returns to the picker; 애니메이션 줄이기 opens on the end look; the made-up battle for each result, RepBot as a bot, an opponent not known |

### Acceptance criteria → tests (SPEC 7; the PM's criteria are 7.9)
- 7.1 Result decision → victory_scene_test 'a win by KO, by time or by the opponent leaving; a loss; a draw'
  (unchanged); victory_defeat_scene_test golden loss vs draw; victory_pvp_outcome_test '<outcome>: the report plays
  the <scene> scene with the opponent, …'
- 7.2 Loss → victory_defeat_scene_test 'its panel is AppColors.danger, …', 'frustrates at 2.2 times on the big feet
  line, after landing', 'ends where W5's loss did: …', 'its band is 패배 and comes from the left; …';
  victory_overlay_test 'a loss: the red cut-in over the report, …'
- 7.3 Draw → victory_defeat_scene_test 'never shows the frustration, 패배, a knocked-out or hit pose; …';
  victory_overlay_test 'a draw: lime and pink halves, …'; result_screen_test 'the scene gets the battle's opponent:
  a draw draws them beside my character (A7)'; victory_seat_test 'draw: …'
- 7.4 No opponent → victory_overlay_test 'the draw's opponent is drawn as the stages draw it: …';
  online_battle_result_test 'carries the opponent's character, …'
- 7.5 Skip and reduced motion → victory_overlay_test 'lose (A7): a tap anywhere jumps to its end look …', 'draw (A7):
  …', '<result>: with reduced motion only the end look shows, from the start' (koWin, lose, draw)
- 7.6 Golden → victory_defeat_scene_test '<id>: a loss matches the design at every golden time', '<id>: a draw
  matches the design at every golden time', 'has SPEC 6's times and the times between, for every character'
- 7.7 Existing screens → the full `flutter test` above (win, report, home, stage and character tests pass; only the
  old loss/draw expectations changed, as listed)
- 7.8 Overflow → victory_pvp_outcome_test 'the scene fits (SPEC 7.8)' group
- 7.9 PM acceptance → victory_pvp_outcome_test 'PM acceptance (A7): an online battle the server ended' group (draw,
  win, loss)
- 7.10 Online opponent → online_battle_result_test 'carries the opponent's character, as the stage drew it, …'
