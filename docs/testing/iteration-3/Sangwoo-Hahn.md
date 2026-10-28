# Testing notes – Iteration 3 – Sangwoo Hahn

Per-push Results for my Iteration 3 steps, in the Testing Documentation format. The PM merges them into
`docs/testing/Testing-Documentation.md`.

## Results

#### 2026-10-28 · code at commit `94956b5` (`origin/main`) · step S1 `docs/squat_judge_design` (P5 squat rep judge design)
This step adds one design document, `docs/iteration-3/squat-judge-design.md`, and one diagram,
`docs/iteration-3/images/squat-setup-and-depth.svg`. It changes no code or tests. `task.md` says "Tests: None (design
doc)", so the checks below only confirm that the branch is still green. I ran the commands on Windows in
`gymrats_app/`, without coverage. Coverage comes from the CI comment "Tests and coverage (GitHub Actions)" on the PR.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | unchanged from `main` (no code change); see the CI comment on the S1 PR | 10/28 | `flutter test`; coverage: CI comment on the PR |
| ViewModel | flutter_test, fakes | 90% | unchanged from `main`; see the CI comment on the S1 PR | 10/28 | (same) |
| Service | flutter_test, MockClient, fakes | 85% | unchanged from `main`; see the CI comment on the S1 PR | 10/28 | (same) |
| View | flutter_test (widget) | 75% | unchanged from `main`; see the CI comment on the S1 PR | 10/28 | (same) |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 10/28 | – |

- **Commands:** `flutter analyze` and `flutter test` in `gymrats_app/`; `python .claude/hooks/ownership_guard.py --check-diff` (ok: 5 changed files, all owned by S1).
- **Tests:** `flutter test` 675 passed, 0 failed, 1 skipped. The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`. `flutter analyze` found no issues. Server `pytest` was not run because `server/` did not change.
- **Coverage:** not collected locally for this step, since no code changed. The per-layer numbers equal those of `main` at `94956b5` and appear in the PR's CI comment.
- **Shortfalls:** none against the targets in this step.
- **Checks on the design itself:** the reviewer subagent compiled stand-ins for the doc's Dart code (`ExerciseRepJudge`, `judgeFor`, `PushUpJudgeAdapter`, `RejectReason.forExercise`, the `RepCounterViewModel` constructor) with `dart analyze`: no issues. It also recomputed the worked examples in §5.

**Test cases added or changed in this step:** none (design document). `task.md` asked for worked examples instead: §5
of the document has two rep timelines (a valid rep and a rejected half squat). §7 lists the unit tests S2 will add:

| Layer | Planned test (S2) | Covers |
|---|---|---|
| Service | `SquatRepJudge`: §5.1 frames → one valid rep, `maxDepth` 0.94, `descent` 400 ms | valid rep, depth units |
| Service | `SquatRepJudge`: §5.2 frames → `shallowSquat` | half squat rejected |
| Service | `SquatRepJudge`: sit down again after the bottom → `standUpFully`; small dip, < 200 ms, > 12 s, frame gap → no event | other rules |
| Service | `PushUpJudgeAdapter` forwards to `RepJudge`; `passDepth == bottomDepth` | push-up unchanged |
| Service | `judgeFor` returns the judge for each exercise, with the injected clock | interface |
| Service | `SetupChecker` squat parts and `notStanding`; `ExerciseType.values` test updated | setup |
| Model | `RejectReason.forExercise` keeps push-up and squat reasons apart; Korean text for every value | reasons |
| ViewModel | `RepCounterViewModel` defaults to push-up; `exercise: squat` uses the squat judge; `passDepth` follows the judge | wiring |
