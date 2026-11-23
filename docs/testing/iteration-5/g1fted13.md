# Testing notes – Iteration 5 – Woohyun Song

Per-push Results for my Iteration 5 steps, in the Testing Documentation format. The PM merges them into
`docs/testing/Testing-Documentation.md` (P26).

## Results

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
