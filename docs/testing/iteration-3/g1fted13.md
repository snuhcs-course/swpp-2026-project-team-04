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
| Model | flutter_test | 90% | see the CI comment on PR #13 | 10/26 | CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| ViewModel | flutter_test, fakes | 90% | see the CI comment on PR #13 | 10/26 | CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| Service | flutter_test, MockClient, fakes | 85% | see the CI comment on PR #13 | 10/26 | CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| View | flutter_test (widget) | 75% | see the CI comment on PR #13 | 10/26 | CI comment "Tests and coverage (GitHub Actions)" on PR #13 |
| API server | pytest, pytest-django, pytest-cov | 90% | see the CI comment on PR #13 (`server/` unchanged) | 10/26 | CI `pytest --cov` |

- **Tests:** `flutter test` 675 passed, 0 failed, 1 skipped (`test/services/online/public_wss_smoke_test.dart`, opt-in with `RUN_PUBLIC_BATTLE_SMOKE`). `flutter analyze` found no issues. `ownership_guard.py --check-diff`: ok, the 4 changed files belong to W1. Server `pytest` was not run locally because `server/` did not change; CI runs it.
- **Coverage:** from the CI run on this push. The commit hash and run link go here when the run finishes.
- **Shortfalls:** none expected, since no code changed.
- **Test cases added or changed in this step:** none.
