# Testing notes – Iteration 3 – Woohyun Song

Per-push Results for my Iteration 3 steps, in the Testing Documentation format. The PM merges them into
`docs/testing/Testing-Documentation.md`.

## Results

#### 2026-10-25 · code at commit `62f6a9d` · step W1 `docs/battle_rules` (P4 battle game rules design)
This step adds one design document, `docs/iteration-3/battle-rules.md`, and changes no code or tests. `task.md` says
"Tests: None (design doc)", so the checks below only confirm that the branch is still green. Commands come from the
Plan in `gymrats_app/`. I ran them on Windows, without coverage (see the coverage rows).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | not measured on this Windows PC (coverage collection hangs); TODO(Woohyun Song): measure on macOS | 10/25 | `flutter test` |
| ViewModel | flutter_test, fakes | 90% | not measured on this Windows PC (coverage collection hangs); TODO(Woohyun Song): measure on macOS | 10/25 | `flutter test` |
| Service | flutter_test, MockClient, fakes | 85% | not measured on this Windows PC (coverage collection hangs); TODO(Woohyun Song): measure on macOS | 10/25 | `flutter test` |
| View | flutter_test (widget) | 75% | not measured on this Windows PC (coverage collection hangs); TODO(Woohyun Song): measure on macOS | 10/25 | `flutter test` |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 10/25 | – |

- **Tests:** `flutter test` 675 passed, 0 failed, 1 skipped. The skipped test is `test/services/online/public_wss_smoke_test.dart`, a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`. `flutter analyze` found no issues. Server `pytest` was not run because `server/` did not change.
- **Coverage:** not collected. `flutter test --coverage` and `coverage_per_file.sh` hang on this PC with "getSourceReport: Service has disappeared". W1 changes no code, so the per-layer numbers equal those of `main` at `62f6a9d`.
- **Shortfalls:** none against the targets in this step, since no code changed.
- **Test cases added or changed in this step:** none (design document). `task.md` asked for worked examples instead: section 6 of the document has two rep timelines with the resulting bar and score. The reviewer subagent recomputed them with a script.
