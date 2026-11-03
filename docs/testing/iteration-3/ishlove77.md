# Testing notes – Iteration 3 – Jinyoung Park (ishlove77, PM)

Per-push Results for the PM's Iteration 3 steps, in the Testing Documentation format: the CI workflow (team plan #2),
the AI module evaluation plan, set, runner and runs (team plan #5, #15, #17), and the documentation pushes. The PM
merges these notes into `docs/testing/Testing-Documentation.md` 4.2 and 5.

## Results

#### 2026-10-26 · code at commit `df1ec0f` · step `ci/test_coverage` (team plan #2, PR #14): tests and coverage on every pull request
This step adds no app or server code. It adds `.github/workflows/tests.yml` (two jobs: Flutter app and Django API),
`tools/coverage_per_file.sh` (one test file at a time, four shards, merged by line, because a full
`flutter test --coverage` hangs) and `tools/ci_test_report.py`, which posts one sticky comment "Tests and coverage
(GitHub Actions)" on the PR. The workflow ran on itself; the numbers below are from that comment.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 98.1% (210/214 lines) | 10/26 | CI comment on PR #14, commit `df1ec0f`, [run 40304086138](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/40304086138) |
| ViewModel | flutter_test, fakes | 90% | 94.4% (837/887) | 10/26 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 92.0% (1592/1731) | 10/26 | same CI comment |
| View | flutter_test (widget) | 75% | 91.6% (3169/3460) | 10/26 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (76 passed) | 10/26 | CI `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** CI `flutter test` 675 passed, 0 failed, 1 skipped (`test/services/online/public_wss_smoke_test.dart`, the
  live team-server check, opt-in with `RUN_PUBLIC_BATTLE_SMOKE`). `flutter analyze` no issues. Server 76 passed.
  Locally only the comment builder was run: `python3 tools/ci_test_report.py <results dir>` on a saved pair of job
  outputs (no network).
- **Coverage:** app total 92.3% (5954/6452), "Other" 91.2%; every layer and the server above target. Flutter 3.47.5 /
  Dart 3.13.4, Python 3.12, ubuntu-latest.
- **Shortfalls:** none. Known gap kept from Iteration 2: no line coverage for the Dart battle server.
- **Test cases added or changed in this step:** none (tooling). From this push on, members copy the CI numbers into
  their PR body and their `docs/testing/iteration-3/<github-id>.md`.

#### 2026-10-30 · code at commit `46dfde4` · step `test/ai_eval_frozen_set` (team plan #5, PR #16): evaluation plan, thresholds and scorer
This step adds `gymrats_app/test/ai_eval/README.md` (the plan), `eval_plan.dart` (the eight sets of the recording
standard, the positions A–D, and the thresholds M1 ≥ 90%, M2 ≥ 90%, M3 ≥ 80%, committed before any evaluation run) and
`eval_scorer.dart` (per-rep alignment of label and verdict, the tallies and the report). No judge code changes. Commands
from the Plan in `gymrats_app/`, on macOS; coverage from the CI comment.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 98.1% (210/214); no change in this step | 10/30 | CI comment on PR #16, commit `46dfde4`, [run 40918179883](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/40918179883) |
| ViewModel | flutter_test, fakes | 90% | 94.4% (837/887); no change | 10/30 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 92.0% (1592/1731); no change | 10/30 | same CI comment |
| View | flutter_test (widget) | 75% | 91.6% (3169/3460); no change | 10/30 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (76 passed); `server/` unchanged | 10/30 | same CI comment |

- **Tests:** `flutter test test/ai_eval` 16 passed; CI `flutter test` 691 passed, 0 failed, 1 skipped (the smoke test,
  as above). `flutter analyze test/ai_eval` no issues.
- **Coverage:** unchanged from PR #14: the scorer lives under `test/`, so it adds no `lib/` lines. App total 92.3%.
- **Shortfalls:** none.

Test cases added or changed in this step:

| Layer | File | What it covers |
|---|---|---|
| Test support (scorer) | `test/ai_eval/eval_scorer_test.dart` (new, 16) | expected labels per set (a normal set counts every rep, a cheat set rejects every rep with its reason, set 4 rejects all but the last), the positions of the recording standard; alignment when the judge never closed a rep or closed an extra one; M1–M3 on a perfect run, a counted cheat rep (fails M2 and M3), a wrong reason (M2 only), an unclosed cheat rep, a missed good rep, extra judged reps reported apart; the record-sheet label wins over the plan; the report splits by position and person, prints the thresholds and results, and reads "no data" for a metric with no reps |

Acceptance criteria → tests:
- **Each case is judged by a declared assertion, not string matching (Testing Documentation 5.1):** `a counted cheat rep fails M2 and M3`, `a wrong reason still counts for M2 but not M3`, `a rep the judge never closed does not shift later reps`.
- **Thresholds are declared before the run and printed with every result:** `prints the metric table with thresholds and results`.

#### 2026-11-03 · code at commit `eee6525` (labels `08bd2e9`, runner `47643fd`, documents `55429f5`) · step `test/ai_eval_cases` (team plan #15, PR #30): the frozen set and its replay runner
This step adds the 32 recordings (`test/ai_eval/cases/{HS,JP,SWH,HSW}/`, eight sets each, labelled rep by rep from
the record sheets), `eval_cases.dart` (loader, set from kind and position, replay through the current `RepJudge`,
per-set and per-case tables) and `ai_eval_test.dart` (the run: prints the report, writes `build/ai_eval/report.md`,
asserts the thresholds only with `--dart-define=AI_EVAL_STRICT=true`). Hyunwoo checked all 32 files on 11-02 (open,
kinds and counts as on the sheets, 17–26 fps). The branch had `origin/main` `e6b16fe` merged in. Commands from the
Plan in `gymrats_app/`, on macOS, on `55429f5`; coverage from the CI comment on `eee6525` (same code).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.4% (266/273); no change in this step | 11/03 | CI comment on PR #30, commit `eee6525`, [run 41585898477](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/41585898477) |
| ViewModel | flutter_test, fakes | 90% | 96.1% (931/969); no change | 11/03 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 94.3% (2219/2354); no change | 11/03 | same CI comment |
| View | flutter_test (widget) | 75% | 91.0% (4053/4452); no change | 11/03 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (101 passed); `server/` unchanged | 11/03 | same CI comment |

- **Tests:** `flutter test test/ai_eval` 27 passed (≈ 3 s). `flutter test` 1467 passed, 0 failed, 9 skipped (the 8
  known push-up errors in `test/services/pose/pushup_error_cases_test.dart` and the smoke test), locally and in CI.
  `flutter analyze` no issues.
- **Coverage:** unchanged under `lib/` (nothing in this step is app code). App total 92.3% (7593/8226). Left out of
  the numbers as on `main`: `test/screens/setup_screen_test.dart` (240 s per-file limit; passes in `flutter test`).
- **AI module evaluation on this head** (judge = `main` `e6b16fe`): M1 46.0% (29/63) fail · M2 91.3% (189/207) pass ·
  M3 57.0% (118/207) fail. Failure analysis in Testing Documentation 5.2.
- **Shortfalls:** none against the coverage targets. M1 and M3 are below their thresholds; the judge work goes to the
  judge owner (Hyunwoo).
- **Reviewer subagent:** APPROVE; four of five Minor findings fixed (the position letter must stand alone; a case
  without `label.perRep` is an error, not a fallback; the per-case error column; README wording), the fifth (a stray
  untracked `tools/__pycache__`) skipped.

Test cases added or changed in this step:

| Layer | File | What it covers |
|---|---|---|
| Service (judge, replay) | `test/ai_eval/ai_eval_test.dart` (new, 1) | the run over the frozen set: 32 cases, correct and incorrect reps present, report printed and written; thresholds asserted under `AI_EVAL_STRICT` |
| Test support (loader) | `test/ai_eval/eval_cases_test.dart` (new, 10) | set from kind + position for every placement format in the files; unknown pairs, an empty placement and a word starting with a letter throw; a missing folder loads nothing; the frozen set has four people × eight sets; every case is labelled rep by rep with as many reps as it holds and the counted reps match `expected`; set 4's last rep counted; the per-set table has one row per set; the replay keeps the label; the per-case table names `false count`, `missed rep`, `wrong reason` or `ok` |
| Fixtures | `test/ai_eval/cases/**/*.json` (new, 32) | the frozen set with labels |

Acceptance criteria → tests:
- **The evaluation set holds ≥ 30 cases with expected labels, committed before the run:** `the frozen set has four people with the eight sets each`, `every case is labelled rep by rep, as many reps as it holds`.
- **Each case is scored by the declared assertion against the declared thresholds:** `frozen set: M1-M3 of the current judge against the thresholds` (strict mode), `keeps the label and replays the judge over the recording`.
- **A recording outside the standard cannot be scored silently:** `a kind at a position the standard does not use is an error`.
- **Results per position, per person and per set:** `has one row per set that has a case`, `the case table has one row per case with its errors`.

#### 2026-11-03 · code at commit `caf6e97` · step `test/ai_eval_results` (team plan #17, PR #31): the evaluation runs on `main`
Documents and generated reports only: `test/ai_eval/results/2026-11-03_main-dccd84a.md` (the official first run, on
`main` right after PR #30) and `2026-11-03_main-269eba7_after-pr32.md` (the same runner after Hyunwoo's judge tuning
PR #32), plus Testing Documentation 4.2 and 5 and the AI collaboration report. Command from `gymrats_app/`:
`flutter test test/ai_eval` → `build/ai_eval/report.md`, copied unchanged.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.4% (266/273); no change in this step | 11/03 | CI comment on PR #31, commit `caf6e97`, [run 41619941393](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/41619941393) |
| ViewModel | flutter_test, fakes | 90% | 96.1% (931/969); no change | 11/03 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 94.3% (2232/2367); #32's judge lines | 11/03 | same CI comment |
| View | flutter_test (widget) | 75% | 91.0% (4053/4452); no change | 11/03 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (101 passed); `server/` unchanged | 11/03 | same CI comment |

- **Tests:** `flutter test` 1476 passed, 0 failed, 10 skipped (9 known push-up errors after #32, one more than before,
  and the smoke test), locally and in CI. `flutter analyze` no issues.
- **AI module evaluation:** on `dccd84a` M1 46.0% (29/63) fail · M2 91.3% (189/207) pass · M3 57.0% (118/207) fail;
  on `269eba7` (after #32) M1 79.4% (50/63) fail · M2 90.8% (188/207) pass · M3 59.9% (124/207) fail. The second run is
  in-sample: #32's four config changes were chosen on these same recordings. Test settings unchanged between the runs
  (same set, scorer, thresholds and command; only the judge's default config changed, as listed in the report).
- **Coverage:** app total 92.3% (7606/8239). Same note as above on `setup_screen_test.dart`.
- **Shortfalls:** M1 and M3 still below threshold; plan in Testing Documentation 5.2.
- **Test cases added or changed in this step:** none (the reports are the output of `ai_eval_test.dart`).
- **Merge:** documents only; merged by the PM on the user's decision without a teammate's approval, merge commit
  `f03a460`.

#### 2026-11-03 · code at commit `00aead4` (these notes in the following commits) · step `docs/testing_rev23`: Testing Documentation Rev.2.3 and these notes
Documents only: 3.2 keeps the "no CI" plan and adds the PR #14 revision next to it; 4.2 moves the Iteration 3 results
to `main` `f03a460` (CI on `a643088`, the head of #32: 1476 passed, 10 skipped; Model 97.4%, ViewModel 96.1%, Service
94.3%, View 91.0%, server 96%, screenshot `docs/images/testing/iter3-ci-coverage-a643088.png`); 5.1 states that no
case was added, edited or removed since the set was frozen in PR #30. The app code equals `main`, so the CI comment
on the PR should repeat the `a643088` numbers.

- **Tests:** `flutter test` on the same app code (the `iteration-3-demo` worktree after merging `main` `f03a460`):
  1476 passed, 0 failed, 10 skipped; `flutter analyze` no issues. No test file changed.
- **Shortfalls:** none.
