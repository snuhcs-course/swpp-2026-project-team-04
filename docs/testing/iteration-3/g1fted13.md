# Testing notes – Iteration 3 – Woohyun Song

Per-push Results for my Iteration 3 steps, in the Testing Documentation format. The PM merges them into
`docs/testing/Testing-Documentation.md`.

## Results

#### 2026-10-25 · code at commit `62f6a9d` · step W1 `docs/battle_rules` (P4 battle game rules design)
This step adds one design document, `docs/iteration-3/battle-rules.md`, and changes no code or tests. `task.md` says
"Tests: None (design doc)", so the checks below only confirm that the branch is still green. Commands come from the
Plan in `gymrats_app/`. I ran them on Windows without coverage; coverage comes from the PR's CI comment (see the
coverage rows).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | see the CI comment on PR #13 | 10/25 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| ViewModel | flutter_test, fakes | 90% | see the CI comment on PR #13 | 10/25 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| Service | flutter_test, MockClient, fakes | 85% | see the CI comment on PR #13 | 10/25 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| View | flutter_test (widget) | 75% | see the CI comment on PR #13 | 10/25 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 10/25 | – |

- **Tests:** `flutter test` 675 passed, 0 failed, 1 skipped. The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`. `flutter analyze` found no issues. Server `pytest` was not run because `server/` did not change.
- **Coverage:** not collected on this PC: `flutter test --coverage` and `coverage_per_file.sh` hang with "getSourceReport: Service has disappeared". Since 2026-10-26 the numbers come from the CI comment on the PR (see the next entry). W1 changes no code, so the per-layer numbers equal those of `main` at `62f6a9d`.
- **Shortfalls:** none against the targets in this step, since no code changed.
- **Test cases added or changed in this step:** none (design document). `task.md` asked for worked examples instead: section 6 of the document has two rep timelines with the resulting bar and score. The reviewer subagent recomputed them with a script.

#### 2026-10-26 · code at commit `fd8a76f` (`main` with PR #14, merged into the branch as `1e07378`) · step W1 `docs/battle_rules`
Before updating PR #13, I merged `origin/main` into the branch. The merge brings only the PM's CI files
(`.github/workflows/tests.yml`, `tools/`) and no app code. I re-ran the checks on Windows on `1e07378`. From now on,
coverage comes from the GitHub Actions run on the PR, which posts one comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 98.1% (210/214) | 10/27 | CI on `fb8e67c`, [run 40345709736](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/40345709736) |
| ViewModel | flutter_test, fakes | 90% | 94.4% (837/887) | 10/27 | (same) |
| Service | flutter_test, MockClient, fakes | 85% | 92.0% (1592/1731) | 10/27 | (same) |
| View | flutter_test (widget) | 75% | 91.6% (3169/3460) | 10/27 | (same) |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (76 passed; `server/` unchanged) | 10/27 | CI `pytest --cov=accounts --cov=matches --cov=gymrats` on `fb8e67c` |

- **Tests:** `flutter test` 675 passed, 0 failed, 1 skipped (`test/services/online/public_wss_smoke_test.dart`, opt-in with `RUN_PUBLIC_BATTLE_SMOKE`). `flutter analyze` found no issues. `ownership_guard.py --check-diff`: ok, the 4 changed files belong to W1. Server `pytest` was not run locally because `server/` did not change; CI runs it.
- **Coverage:** from the CI comment "Tests and coverage (GitHub Actions)" on PR #13, commit `fb8e67c`
  (2026-10-27 00:06 KST, app and server jobs success, run link above). App total 92.3% (5954/6452).
  CI also ran `flutter analyze` (no issues) and `flutter test` (675 passed, 1 skipped), matching the local run.
  Same numbers as the first CI run on `main` (#14, `df1ec0f`), as expected: W1 changes no code.
- **Shortfalls:** none; every layer and the server meet their targets.
- **Test cases added or changed in this step:** none.
