# Project: GymRats — Real-Time 1v1 Exercise Battles

## Table of contents
* [1. Document Revision History](#1-document-revision-history)
* [2. Overview](#2-overview)
* [3. Test Responsibility & Schedule](#3-test-responsibility--schedule)
> * [3.1 Who](#31-who)
> * [3.2 When](#32-when)
* [4. Unit & Integration Testing](#4-unit--integration-testing)
> * [4.1 Plan](#41-plan)
> * [4.2 Results](#42-results)
* [5. AI Module Testing](#5-ai-module-testing) (Iteration 3)
* [6. Acceptance Testing](#6-acceptance-testing) (Iteration 3 plan, Iteration 4 results)
> * [6.1 How the UAT is run](#61-how-the-uat-is-run)
> * [6.2 UAT stories](#62-uat-stories)
> * [6.3 Stories, acceptance criteria, and test procedures](#63-stories-acceptance-criteria-and-test-procedures)
> * [6.4 Results](#64-results)
* [7. Alpha & Beta Testing](#7-alpha--beta-testing) (Iteration 5)

# 1. Document Revision History

|Version|Date|Description|
|-------|----|-----------|
|Rev.1.0|2026-10-22|Initial version: test responsibility and schedule; unit and integration test plan and the first results (Iteration 2)|
|Rev.1.1|2026-10-23|Added the PR #10 results (phone tilt fix) to 4.2|
|Rev.1.2|2026-10-23|App tests re-run on the final Iteration 2 `main` (`9e9a911`); second app coverage attempt on Windows; PR #11 (coverage script)|
|Rev.1.3|2026-10-23|App coverage measured on the final Iteration 2 `main` (`62f6a9d`) with the report as evidence; PR #12 (demo README and video)|
|Rev.2.0|2026-11-01|Added 6. Acceptance Testing plan: how the UAT is run, six UAT stories (UAT-1 to UAT-6) with acceptance criteria and test procedures, frozen from 2026-11-06; results follow in Iteration 4|
|Rev.2.1|2026-11-03|Added the Iteration 3 results so far to 4.2 (all team-plan PRs merged, `main` `e6b16fe`, the heuristic-evaluation build); 5. AI Module Testing: the frozen set, labels and runner (5.1) and the first run with its failure analysis (5.2)|
|Rev.2.2|2026-11-03|5.2: the run on the pinned `main` commit `dccd84a` (PR #30 merged) and the re-run after the judge tuning of PR #32 (tuned on the same set); 5.3: what the AI testing changed in the app (judge rules and pose model from the first recordings, the Good / Excellent / Average points from the recorded depths and elbow angles, the setup relaxation for far placements, the four judge changes of #32 from the evaluation, the HE clothing advice) and what it leaves to Iteration 4|
|Rev.2.3|2026-11-03|3.2: the CI revision of PR #14 noted; 4.2 Iteration 3 results moved to the final Iteration 3 `main` (`f03a460`, CI on `a643088`) with the coverage screenshot; 5.1: no additions since freezing|
|Rev.2.4|2026-11-03|3.1 and 4.1: Iteration 3 revisions (PM and new areas' owners; the coverage script and versions); 4.2: who ran the suite, the plan change noted, the test-case bullet shortened to a pointer; 5.1: per-set table (cases and labelled reps), the assertion per case and the threshold commit stated in the page, deterministic replay noted; 5.2: the two run headings in the per-push format of the members' notes|
|Rev.2.5|2026-11-03|Final guideline audit: the required iteration stated under each section heading, the threshold commit date in KST, one Korean word translated|

# 2. Overview

This page says who tests what, when the tests run, and what they measured, so that anyone on the team can run the same commands and get the same numbers. Each section has a **Plan** and **Results**. Plans are commitments: if a goal changes, the original stays next to the revised one, and the reason is given in that iteration's Results.

| Iteration | Newly required | Keep updated |
|---|---|---|
| 2 | Test Responsibility & Schedule; Unit & Integration Testing (plan and first results) | – |
| 3 | AI Module Testing (thresholds and first results); Acceptance Testing (plan) | Unit & Integration |
| 4 | Acceptance Testing (results) | Unit & Integration, AI Module |
| 5 | Alpha & Beta Testing (plan, execution, results) | All of the above |

# 3. Test Responsibility & Schedule

## 3.1 Who

Each component has one owner who writes and maintains its tests. The areas match the ownership in [Design Documentation 2.3.11](Design-Documentation#2311-who-owns-what).

| Component | Code | Tests | Owner |
|---|---|---|---|
| Rep judging, pose setup, phone placement (on-device AI module) | `lib/services/pose/`, `lib/services/device/`, `rep_counter_viewmodel.dart`, `setup_viewmodel.dart`, `setup_screen.dart`, `match_setup_screen.dart` | `test/services/pose/`, `test/services/device/`, `test/viewmodels/rep_counter_*`, `setup_viewmodel_*`, `test/screens/setup_*`, `match_setup_*` | Hyunwoo Song |
| AI battle and form feedback | `lib/services/opponent/`, `lib/services/feedback/` (analysis and phone store), `battle_viewmodel.dart`, `battle_screen.dart`, `result_screen.dart`, `feedback_screen.dart` | `test/services/opponent/`, `form_analyzer_test`, `form_report_store_test`, `battle_viewmodel_test`, `battle_screen_test`, `result_screen_test`, `feedback_screen_test` | Hyunwoo Song |
| Accounts, history, saved feedback (app) | `lib/services/auth/`, `lib/services/user/`, `lib/services/api/`, `lib/services/feedback/form_summary.dart`, the auth, login, sign-up, home, history and feedback view models, the login, sign-up, home shell, history and match feedback screens, `match_record_card.dart` | `test/services/auth/`, `test/services/user/`, `test/services/api/`, `form_summary_test`, the tests of those view models and screens, `auth_flow_test`, `test/models/` (auth session, match record, feedback summary) | Jinyoung Park |
| REST API (Django) | `server/accounts/`, `server/matches/`, `server/gymrats/` | `server/tests/` | Jinyoung Park |
| Battle result saving (battle server ↔ Django) | `server/lib/result_store.dart`, `server/matches/internal.py` | `test/services/online/battle_result_store_test.dart`, `server/tests/test_results.py` | Jinyoung Park |
| Online battle and avatars (app and battle server) | `lib/services/online/`, `lib/shared/battle_protocol.dart`, `server/lib/battle_server.dart`, `api_authenticator.dart`, the online lobby, online battle and profile screens, avatar widgets | `online_battle_integration_test`, `api_authenticator_test`, `public_wss_smoke_test`, `online_*` and `profile` screen tests, avatar model, store and widget tests | Sangwoo Hahn |
| Home, AI matching and versus screens, shared widgets, theme | `lib/services/matching/`, `home_screen.dart`, `matching_screen.dart`, `versus_screen.dart`, `lib/widgets/` (others), `lib/theme/` | `home_*`, `matching_*`, `versus_*` tests, `test/widgets/` (others), `test/theme/`, `design_tokens_test`, `main_test` | Woohyun Song (PM) |

**Policy for new code**
* The author of a feature or a fix writes its tests and submits them in the same pull request. A bug fix starts with a test that fails before the fix.
* Whoever changes a file updates its tests in the same pull request, even in another owner's area.
* Tests never use the real network, the team server, the camera, ML Kit, or secure storage. They use the fakes in `gymrats_app/test/support/`.
* The PM runs the full suite with coverage on the submitted commit at the end of each iteration and updates 4.2.

*Revision (Iteration 3, 2026-11-03):* the PM role passed to Jinyoung Park for Iteration 3 (the end-of-iteration run in 4.2 and the AI module evaluation in 5 are his). Areas added in Iteration 3 and their test owners, as merged ([Design Documentation 2.3.11](Design-Documentation#2311-who-owns-what)): battle game rules, fever, KO and bot levels (`lib/services/game/`, `test/services/game/`, `bot_difficulty_test`), the rules screen and the safety warning (`help_*`, `safe_warning_*` tests), score history and the new Home: Woohyun Song; squat judge and setup, squat battles and matching per exercise, SOMA avatars and the opponent view (`squat_*`, `matching_*`, `avatar_catalog_test`, the online tests): Sangwoo Hahn; push-up recordings and judge accuracy (`test/fixtures/pushup_cases/`, `pushup_error_cases_test`): Hyunwoo Song; the CI workflow (`.github/`, `tools/`) and the AI evaluation set and runner (`test/ai_eval/`): Jinyoung Park. The rows above stay as planned; cross-owner edits were agreed in the PRs.

## 3.2 When

| When | What runs | Who | Must pass to merge |
|---|---|---|---|
| Before opening a pull request, and again after the last change | `flutter analyze`, `flutter test` in `gymrats_app/`; `pytest` in `server/` when `server/` changed | PR author | Yes. The PR description lists the commands, the commit, and the pass/fail counts. |
| Pull request review | Reviewer checks the reported results and that new code has tests | AI review (Claude Code, Codex), then the PM | The PM approves only with passing results. |
| After a battle server deploy (opt-in) | `public_wss_smoke_test.dart` against the team server (see 4.1) | Sangwoo Hahn | – |
| End of each iteration | Full suite with coverage on the submitted commit; results recorded in 4.2 | PM | – |

There is no CI (GitHub Actions) yet; all tests run on the developers' machines.

*Revision (2026-10-26, PR #14):* GitHub Actions now runs on every pull request: `flutter analyze` and `flutter test`, the per-layer coverage in four shards (`tools/coverage_per_file.sh` + `tools/coverage_by_layer.py`), and `pytest --cov` for `server/`, and posts the numbers as a sticky comment on the PR (`tools/ci_test_report.py`). The rows above still hold: the author runs the tests before opening the PR, and the PM merges only with the CI comment green.

# 4. Unit & Integration Testing

*Required from Iteration 2; kept up to date every iteration.*

## 4.1 Plan

### Frameworks

| Component | Test framework | Mocking / isolation | Coverage tool |
|---|---|---|---|
| Model, ViewModel, Service (app) | `flutter_test` | Hand-written fakes in `test/support/` (camera, pose estimator, repositories, matchmaker, opponent, rep sound); `MockClient` from `package:http/testing.dart` for `ApiClient` | `flutter test --coverage` (lcov) + `tools/coverage_by_layer.py` |
| View (screens, widgets) | `flutter_test` widget tests | Fake repositories, fake camera and pose estimator, in-memory stores | Same |
| Battle server (Dart, `server/lib/`) | `flutter_test`, real `BattleServer` on loopback sockets | Fake result store, local `HttpServer` standing in for Django | Not measured (outside the Flutter package) |
| REST API (Django) | `pytest`, `pytest-django` | Django test client, in-memory SQLite, fixed test secrets (`gymrats/test_settings.py`) | `pytest-cov` |

### Unit and integration tests

Most tests are unit tests of one class with fakes around it. These tests check several parts working together:

| Integration test | Parts together |
|---|---|
| `test/services/online/online_battle_integration_test.dart` | `OnlineBattleSession` clients and the real `BattleServer` over loopback WebSockets: login check, FIFO matching, ready timeout, rep deduplication and conflicts, pose relay, reconnect grace, forfeit and void, the server-decided result |
| `test/services/online/battle_result_store_test.dart` | `BattleServer` → `HttpResultStore` → a local HTTP server: start, result and void saved once, retries, restart recovery |
| `test/auth_flow_test.dart`, `test/main_test.dart` | `GymRatsApp` with in-memory repositories: log-in and sign-up to home, home → matching → versus → setup → battle → result → home |
| `test/demo/*_test.dart` | The demo apps (pose setup, rep judging, AI battle, accounts and history) driven through their view models and screens with the fake camera and pose fixtures |
| `server/tests/` | URL routing, serializers, views, JWT authentication and the database together, through the Django test client |
| `test/services/online/public_wss_smoke_test.dart` (opt-in) | The app's session against the deployed server over WSS. Skipped by default. |

### Coverage goals by layer (line coverage)

| Layer | Code | Target | Why |
|---|---|---|---|
| Model | `lib/models/` | 90% | Plain data and JSON parsing; cheap to test fully |
| ViewModel | `lib/viewmodels/` | 90% | Holds the app's logic and state transitions |
| Service | `lib/services/` | 85% | Rep judging, networking and storage; a few platform calls need a real device |
| View | `lib/screens/`, `lib/widgets/` | 75% | Some widgets wrap platform views (camera preview, WebView) that widget tests cannot drive |
| REST API (Django) | `server/accounts/`, `server/matches/`, `server/gymrats/` | 90% | Business rules, authentication, and data integrity |
| Battle server (Dart) | `server/lib/` | – (no number yet) | Behavior-tested through the integration tests above; line coverage once it has its own Dart package |

### Scope & exclusions

* **Excluded from the numbers:** `lib/demo/` (manual entry points). `lib/main.dart`, `lib/config/`, `lib/shared/` and `lib/theme/` are counted in "Other", not in a layer. Files that no test loads (interfaces, constants) do not appear in lcov.
* **Covered only by manual checks on a phone:** the device parts of `camera_service.dart`, `pose_estimator.dart` and `pose_camera_view.dart` (real camera, ML Kit), the gravity and gyroscope channel in `MainActivity.kt`, and the three.js avatar page in the WebView. Their logic is tested through fakes.
* **Server:** tests use an in-memory SQLite database and a fast password hasher (`MD5PasswordHasher` in `test_settings.py`); production uses bcrypt. `wsgi.py` is only loaded by gunicorn.

### Reproducible commands

Environment: Flutter stable with Dart `^3.13.4` (`gymrats_app/pubspec.yaml`), Python 3.12. No environment variables are needed: the server tests set their own throwaway secrets.

```sh
# App (from the repository root)
cd gymrats_app
flutter pub get
flutter analyze
flutter test --coverage                     # all tests; writes coverage/lcov.info
python3 ../tools/coverage_by_layer.py coverage/lcov.info --html coverage/by-layer.html

# If a single coverage run crashes (macOS: flutter_tester segfault) or stops after
# "getSourceReport: Service has disappeared" (Windows), run each file and merge:
mkdir -p coverage/parts
for f in $(find test -name '*_test.dart'); do
  flutter test --coverage --coverage-path "coverage/parts/$(echo "$f" | tr / _).info" "$f"
done
python3 ../tools/coverage_by_layer.py 'coverage/parts/*.info' --html coverage/by-layer.html

# Opt-in live check against the team server (signs up two throwaway test_ accounts)
flutter test test/services/online/public_wss_smoke_test.dart --dart-define=RUN_PUBLIC_BATTLE_SMOKE=true

# REST API (from the repository root)
cd server
python3.12 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats --cov-report=term-missing
```

`tools/coverage_by_layer.py` merges one or more lcov files and prints the per-layer table used in 4.2 (a line counts as covered when any test hit it).

*Revision (2026-10-26, PR #14):* `bash ../tools/coverage_per_file.sh` (from `gymrats_app/`) runs the per-file loop above with a 240 s limit per file and is what CI runs in four shards; the merge step is unchanged. Versions used for every Iteration 3 number: Flutter 3.47.5 / Dart 3.13.4, Python 3.12.

## 4.2 Results

### Iteration 2

**Summary**

| Component | Frameworks | Target | Actual | Date | Commit | Command / Report |
|---|---|---|---|---|---|---|
| Model | flutter_test | 90% | 98.1% (210 / 214 lines) | 10/23 | `62f6a9d` | per-file `flutter test --coverage`, merged with `tools/coverage_by_layer.py` |
| ViewModel | flutter_test, fakes | 90% | 94.4% (837 / 887) | 10/23 | `62f6a9d` | same |
| Service | flutter_test, MockClient, fakes | 85% | 92.0% (1592 / 1731) | 10/23 | `62f6a9d` | same |
| View | flutter_test (widget) | 75% | 91.6% (3169 / 3460) | 10/23 | `62f6a9d` | same |
| App, other (`main.dart`, `shared/`, `theme/`) | flutter_test | – | 91.2% (146 / 160) | 10/23 | `62f6a9d` | same |
| App, total | | – | 92.3% (5954 / 6452) | 10/23 | `62f6a9d` | same |
| REST API (Django) | pytest, pytest-django, pytest-cov | 90% | **96%** (484 statements, 20 missed) | 10/22 | `bf141af` | `.venv/bin/python -m pytest --cov=…` |
| Battle server (Dart) | flutter_test, loopback sockets | – | not measured | 10/21 | `706694f` | 34 tests in three files in `test/services/online/` |

`62f6a9d` is `main` at the end of Iteration 2 and the head of `iteration-2-demo`. It adds only the demo README and video (PR #12) to `9e9a911`, so the app tests run on `9e9a911` cover the same code. Since `bf141af` (`main` after PR #9), only the app's phone-tilt code and its tests (PR #10), `tools/coverage_by_layer.py` (PR #11) and the demo README and video (PR #12) changed; the server did not, so the REST API results on `bf141af` also hold for `62f6a9d`.

App coverage on `62f6a9d` was measured by Jinyoung Park one test file at a time, with the commands in 4.1: 73 lcov files, one for each test file except the opt-in live check (`public_wss_smoke_test.dart`, skipped by default), merged with `tools/coverage_by_layer.py`. The report is under **Evidence** below. On Windows the same measurement stopped in coverage collection (`getSourceReport: Service has disappeared`) on `bf141af` (10/22) and `9e9a911` (10/23), even one file at a time and with `--concurrency=1`. The first results, reported in PR #9 on `706694f` (10/21), were Model 95.8%, ViewModel 94.4%, Service 91.3% and View 91.7%.

**Tests**

* App coverage, `62f6a9d` (10/23, Jinyoung Park): each of the 73 test files run on its own with `flutter test --coverage`, then merged: 5,954 of 6,452 lines in `lib/` (92.3%; `lib/demo/` excluded).
* App, `9e9a911` (10/23, Windows, after `flutter clean`): `flutter test` 675 passed, 0 failed, 1 skipped.
* App, `bf141af` (10/22, Flutter 3.47.5, Dart 3.13.4, Windows): `flutter test` 673 passed, 0 failed, 1 skipped (`public_wss_smoke_test`, the opt-in live check). `flutter analyze`: no issues.
* App, `706694f` (10/21, Flutter 3.47.5, macOS): 663 passed, 0 failed, 1 skipped; `flutter analyze`: no issues. Coverage was measured one test file at a time, because a single `flutter test --coverage` run crashed (flutter_tester segfault).
* REST API, `bf141af`: `pytest` 76 passed, 0 failed, 0 skipped (Python 3.12.3, Django 5.2.7).
* Every layer meets its target. Gaps: the least-covered app files are the camera preview (`widgets/pose_camera_view.dart`, 8.8%) and the 3D avatar WebView (`widgets/pose_avatar_view.dart`, 30.3%), which widget tests cannot drive, and the debug-only synthetic battle for testing the network with one phone (`screens/online_synthetic_battle_screen.dart`, `services/online/synthetic_battle_pose.dart`, both 0%); none of them pulls its layer below the target. The battle server has no line coverage number yet (it sits outside the Flutter package; plan: give it its own `pubspec.yaml` and measure it with `dart test --coverage`), and the REST API misses `wsgi.py` and the branches for two uploads of the same battle racing each other (`IntegrityError` in `matches/views.py` and `matches/internal.py`).

**Results reported in pull requests** (each PR states its own run before merge)

| PR | Branch | Commit | `flutter analyze` | `flutter test` | `pytest` |
|---|---|---|---|---|---|
| #6 | `feat/auth_history` | `982afcc` | no issues | 444 passed | 39 passed |
| #7 | `feat/round_30s` | `3103a30` | did not finish (analyzer crash on that machine) | 506 passed | not re-run (server unchanged) |
| #8 | `feat/online-battle` | – | passed | 571 passed, 1 skipped | – |
| #9 | `feat/history_feedback` | `706694f` | no issues | 663 passed, 1 skipped | 74 passed; 76 passed after merging `main` |
| #10 | `fix/phone-tilt-during-round` | `e7b0ab0` | not run on the author's machine; no issues on the PM's re-run (10/23) | 128 passed in the 5 related test files; 675 passed, 1 skipped on the PM's re-run (10/23) | not re-run (server unchanged) |
| #11 | `docs/coverage-script` | `2b33aea` | – | – (adds `tools/coverage_by_layer.py` only) | – |
| #12 | `docs/iteration-2-demo` | `a37a2c6` | – | – (adds the demo README and video only) | – |

**Evidence**

App line coverage by layer on `62f6a9d` (`tools/coverage_by_layer.py` HTML report: input files and layer totals, then every file):

<p align="center">
<img width="700" alt="App coverage by layer: input files and layer totals" src="images/testing/iter2-app-coverage-summary.png" />
</p>

<p align="center">
<img width="480" alt="App coverage per file, part 1" src="images/testing/iter2-app-coverage-files-1.png" />
<img width="480" alt="App coverage per file, part 2" src="images/testing/iter2-app-coverage-files-2.png" />
</p>

REST API coverage and test output on `bf141af`:

<p align="center">
<img width="700" alt="REST API coverage report" src="images/testing/iter2-server-coverage.png" />
</p>

<p align="center">
<img width="900" alt="REST API pytest output" src="images/testing/iter2-server-pytest.png" />
</p>

### Iteration 3

#### 2026-11-03 · commit `f03a460` · every Iteration 3 PR merged (#13–#32); heuristic-evaluation build

`main` after the last Iteration 3 PR (#32, the push-up judge tuning; its app code is the PR head `a643088`, which CI measured). The branch `iteration-3-demo` and the APK for the heuristic evaluation (`submission.zip` → `app.apk`, `flutter build apk --release`) are built from this app code, and the team server was redeployed on 2026-11-03 from `e6b16fe`, whose server code is unchanged since (Django with migration `matches.0003_match_scores`, battle server release `20261102T174257Z-main-e6b16fe`).

Commands as in 4.1, run by Jinyoung Park (PM) on a clean checkout of `f03a460` (macOS, Flutter 3.47.5 / Dart 3.13.4, Python 3.12) and by CI on `a643088` (ubuntu-latest, same versions; same counts). Plan change this iteration: CI added (3.2 and 4.1 revisions), so the coverage numbers come from the CI run rather than a developer's machine; the targets are unchanged.

- `flutter analyze`: no issues.
- `flutter test`: **1476 passed, 0 failed, 10 skipped**. The skipped tests are the 9 recorded push-up cases the judge still gets wrong (`test/services/pose/pushup_error_cases_test.dart`, each skipped with its reason in code and listed in `docs/iteration-3/pushup-error-cases.md`; 8 before PR #32, 9 after) and the live team-server check in `test/services/online/public_wss_smoke_test.dart`, skipped unless `RUN_PUBLIC_BATTLE_SMOKE` is set.
- Server `.venv/bin/python -m pytest`: **101 passed, 0 failed**.
- Per PR, GitHub Actions (PR #14) ran the same commands plus the per-layer coverage on every head commit; each PR body has its own results table (date, head commit, counts, coverage).

**Summary** (coverage from the CI run on `a643088`, 2026-11-03 16:03 KST, 1476 passed and 10 skipped; the app code of `main` `f03a460`; screenshot below)

| Component | Frameworks | Target | Actual | Date | Commit | Command / Report |
|---|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.4% (266 / 273 lines) | 11/03 | `a643088` | CI `Flutter coverage` shards (`tools/coverage_per_file.sh`, merged by `tools/coverage_by_layer.py`) |
| ViewModel | flutter_test, fakes | 90% | 96.1% (931 / 969) | 11/03 | `a643088` | same |
| Service | flutter_test, MockClient, fakes | 85% | 94.3% (2232 / 2367) | 11/03 | `a643088` | same |
| View | flutter_test (widget) | 75% | 91.0% (4053 / 4452) | 11/03 | `a643088` | same |
| App, other (`main.dart`, `shared/`, `theme/`) | flutter_test | – | 69.7% (124 / 178) | 11/03 | `a643088` | same |
| Total (app) | | – | 92.3% (7606 / 8239) | 11/03 | `a643088` | same |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% | 11/03 | `a643088` | CI `Django API` job: `pytest --cov=accounts --cov=matches --cov=gymrats` |
| Battle server (Dart) | flutter_test, loopback sockets | – | not measured | 11/03 | `f03a460` | behavior tests in `gymrats_app/test/services/online/` (run inside `flutter test`) |

- Left out of the client coverage numbers: `test/screens/setup_screen_test.dart` (240 s timeout in the per-file run; its tests pass in `flutter test`). Files no test loads are interfaces or constant-only files, as in Iteration 2.
- Shortfalls: none against the targets. Gap carried over: no line coverage for the Dart battle server (same reason and plan as Iteration 2).

<p align="center">
<img width="800" alt="GitHub Actions coverage comment on PR #32 (a643088): per-layer table and Django coverage" src="images/testing/iter3-ci-coverage-a643088.png" />
</p>

- Test cases added or changed in Iteration 3 are listed per PR in the PR bodies and per push in each member's notes under `docs/testing/iteration-3/`.

# 5. AI Module Testing

*Required from Iteration 3 (thresholds declared and first results); kept up to date from Iteration 4.*

Plan committed before the first run: `gymrats_app/test/ai_eval/README.md` and `eval_plan.dart` (PR #16, merged 2026-10-30 KST) declare the protocol, the 32 cases (four members × 8 sets, positions A–D, in `gymrats_app/test/ai_eval/cases/`, complete on 2026-11-02), the expected labels, the per-case assertion and the thresholds M1 count accuracy ≥ 90%, M2 rejection rate ≥ 90%, M3 right reason ≥ 80%. Results follow in this section after the run on a pinned `main` commit (Iteration 3). The module under test is the on-device rep judging ([Design Documentation 2.3.2](Design-Documentation#232-rep-judging-on-device-ai-module)).

## 5.1 Set, labels and runner (frozen 2026-11-03)
- Cases: `gymrats_app/test/ai_eval/cases/{HS,JP,SWH,HSW}/` — 4 recorders × 8 sets = 32 recordings (landmarks and phone sensors only, no video), 270 labelled reps. Labels (`label.perRep`) come from the record sheets; each recorder's sheet is in the folder. Deviations from the protocol (Sangwoo's sets 5 reps / 30 s, Hyunwoo's set 4 with 11 descents and set 7 with 5 reps, Woohyun's set 1 with 5 and set 5 with 9 reps, Jinyoung's distances not measured) are listed in `gymrats_app/test/ai_eval/README.md` and kept as recorded.
- Ground truth: the motion the recorder actually did, written on the sheet during the recording; the PM transferred it to the files (10-31 ~ 11-03). Hyunwoo checked all 32 files on 11-02 (open, kinds and counts as on the sheets, 17–26 fps). No case has been added, edited or removed since the set was frozen in PR #30 (`dccd84a`); an addition would be listed in the README with its date and reason.
- Per set (the recording standard, Hyunwoo's recording standard sheet of 2026-10-29/30): one case per recorder and set, 10 reps planned per case (Sangwoo's cases 5), 60-second round, lighting `bright`, phone at A/B = 50 cm and C/D = 100 cm from the fingertip line, A/C at 60–65° and B/D at 75–80°.

| Set | Position | Motion | Expected per rep | Cases | Labelled reps (correct / incorrect) |
|---|---|---|---|---|---|
| 1 | A | Normal push-ups | counted | 4 | 30 (30 / 0) |
| 2 | A | Kneeling bow | `kneesDown` | 4 | 35 (0 / 35) |
| 3 | B | Elbows only to ~120°, then a head nod | `insufficientDepth` | 4 | 35 (0 / 35) |
| 4 | B | Full depth, no lock-out until the last rep | `incompleteExtension` × (reps − 1), then counted | 4 | 36 (4 / 32) |
| 5 | C | Knee push-ups | `kneesDown` | 4 | 34 (0 / 34) |
| 6 | C | Belly and hips touch the floor first | `bellyDown` | 4 | 35 (0 / 35) |
| 7 | D | Normal push-ups | counted | 4 | 30 (29 / 1) |
| 8 | D | Kneeling, arms straight, head to the floor | `armsStraight` | 4 | 35 (0 / 35) |
| **All** | A–D | | | **32** | **270** (63 / 207) |

- Assertion per case: the labelled reps and the reps the judge closed in the replay are aligned by the fewest edits (`align` in `eval_scorer.dart`); each aligned pair is compared on counted / rejected and on the reject reason. M1 = correct reps counted ÷ correct reps done; M2 = incorrect reps not counted ÷ incorrect reps done; M3 = incorrect reps rejected with the labelled reason ÷ incorrect reps done. An incorrect rep the judge never closed counts as not counted (M2) and wrong (M3); judged reps with no labelled partner are reported apart. No string matching: the comparison is on the verdict enum per rep.
- Thresholds, declared before any run and committed with the plan in PR #16 (`a3576ce`, 2026-10-30 02:38 KST; `eval_plan.dart`): M1 ≥ 90%, M2 ≥ 90%, M3 ≥ 80%, all three over the 32 cases; per position and per person the metrics are reported without a threshold.
- Runner: `gymrats_app/test/ai_eval/ai_eval_test.dart` replays every recording through the current `RepJudge` (default `RepJudgeConfig`, `test/support/pushup_case_loader.dart`) and scores it with `eval_scorer.dart` (reps aligned by the fewest edits). Command, from `gymrats_app/`: `flutter test test/ai_eval` (report printed and written to `build/ai_eval/report.md`); `--dart-define=AI_EVAL_STRICT=true` turns the thresholds into assertions.
- Settings under test: ML Kit pose detection 0.16.1, `accurate` model, `RepJudgeConfig` defaults of the commit (minLikelihood 0.6, bottomDepth 1.1, minShoulderDrop 0.68, maxTorsoDrop 1.2). The replay is deterministic: no model sampling, seed or prompt is involved, so two runs on the same commit give the same numbers.

## 5.2 Results

#### 2026-11-03 · code at commit `269eba7` · AI module evaluation, re-run after the judge tuning of PR #32 (tuned on the same set)
The four judge changes of PR #32 (5.3) were chosen from these same 32 recordings, so this run is **in-sample**; it is reported beside the first run, not instead of it, and a check on new recordings at other phone angles is Iteration 4 work. Full report: `gymrats_app/test/ai_eval/results/2026-11-03_main-269eba7_after-pr32.md`; Hyunwoo's own run on the branch gave the same numbers.

| Metric | First run (`dccd84a`) | After #32 (`269eba7`) | Threshold | Result |
|---|---|---|---|---|
| M1 Count accuracy | 46.0 % (29/63) | 79.4 % (50/63) | ≥ 90 % | **fail** |
| M2 Rejection rate | 91.3 % (189/207) | 90.8 % (188/207) | ≥ 90 % | pass |
| M3 Right reason | 57.0 % (118/207) | 59.9 % (124/207) | ≥ 80 % | **fail** |

Per person M1: JP 14.3 → 90 %, SWH 20 → 53 %, HS 87.5 → 88 %, HSW 81.8 → 82 %. Per set: set 1 M1 63.3 → 86.7 %, set 7 34.5 → 75.9 %, set 4 M1 0 → 50 % and M3 9.4 → 34.4 %, sets 2, 3 and 5 unchanged (set 2 M3 100 → 94.3 %), set 6 (belly down) unchanged at M2 62.9 %. Cost on the 12 earlier fixtures: 3 cheat reps now count (two head nods, one bow). Still open: belly-down reps (13 of 35 counted, phone angle suspected), the lower-body jitter of SWH set 7, the set 4 and set 8 reasons.

#### 2026-11-03 · code at commit `dccd84a` · AI module evaluation, first run on `main` (PR #30 merged)
Re-run on `main` right after the merge, on the branch `test/ai_eval_results` (full report with the per-set and per-case tables: `gymrats_app/test/ai_eval/results/2026-11-03_main-dccd84a.md`). The numbers are identical to the first run below, as the judge code did not change between `e6b16fe` and `dccd84a`, and to Hyunwoo's independent run during the review of PR #30.

### First run · 2026-11-03 · branch `test/ai_eval_cases` (labels `08bd2e9`, judge code = `main` `e6b16fe`)

| Metric | Value | Threshold | Result |
|---|---|---|---|
| M1 Count accuracy | 46.0% (29/63) | ≥ 90% | **fail** |
| M2 Rejection rate | 91.3% (189/207) | ≥ 90% | pass |
| M3 Right reason | 57.0% (118/207) | ≥ 80% | **fail** |

32 cases; 1 judged rep without a labelled partner (rejected). Per position: A 63.3 / 100 / 100 %, B 0 / 94.0 / 56.7 %, C – / 79.7 / 53.6 %, D 34.5 / 100 / 22.2 % (M1 / M2 / M3). Per person: HS 87.5 / 91.7 / 53.3 %, HSW 81.8 / 82.8 / 55.2 %, JP 14.3 / 86.4 / 50.8 %, SWH 20.0 / 100 / 67.8 %. Per set: set 1 M1 63.3 %, set 7 M1 34.5 %; set 2 and 3 M2 = M3 = 100 %; set 4 M1 0 %, M2 87.5 %, M3 9.4 %; set 5 M2 97.1 %, M3 79.4 %; set 6 M2 62.9 %, M3 28.6 %; set 8 M2 100 %, M3 20.0 %.

**Verdict: the judge does not pass the plan** (M1 and M3 below threshold). The replay verdicts equal the verdicts recorded on the phones for every case made with the current judge (`live` column of the report), so these are the numbers users get.

**Failure analysis (first pass, PM 2026-11-03; the judge is Hyunwoo's, changes follow in Iteration 4):**
1. Normal push-ups missed (M1): Jinyoung's and Woohyun's normal sets are rejected as `insufficientDepth` or `kneesDown` (JP set 1: 2/10 counted, set 7: 1/10; SWH set 7: 0/9, its rep 4 being labelled `insufficientDepth`, set 1: 3/5), while Hyunwoo's and Sangwoo's are counted (HS 14/15, rep 6 of set 1 rejected as `insufficientDepth`; HSW 9/10). Jinyoung's phone stood at 79–85°, outside the 60–65° of positions A and D. The `kneesDown` part is explained by Woohyun's analysis of 11-03 (shoulder–hip–knee angle at the top below the 155° default with the knees hidden behind the torso and reported at likelihood 1.0; loose clothes in the floor's colour make it worse).
2. Set 4, no lock-out (M1 0 %, M3 9.4 %): the judge rarely produces `incompleteExtension` (3 of Sangwoo's 4 partial reps, none in the other three recordings); the other partial lock-outs are read as `insufficientDepth` (JP) or `kneesDown` (SWH, HSW), or counted as valid (4 of Hyunwoo's 10 partial reps, false counts), and the final locked-out rep is not counted in any of the four recordings.
3. Set 8, kneeling with straight arms (M3 20 %): rejected, but as `kneesDown` or `insufficientDepth` instead of `armsStraight` for JP, SWH and HSW; Hyunwoo's own set gets `armsStraight` 7/10.
4. Set 6, belly down (M2 62.9 %): Sangwoo's and Jinyoung's belly reps are mostly counted (false counts); Hyunwoo's are rejected as `kneesDown` (5) or `insufficientDepth` (4) with 1 counted; only Woohyun's are `bellyDown`.
5. Sets 2, 3 and 5 are right for everyone (M2 ≥ 97 %, M3 ≥ 79 %).

## 5.3 What the AI testing changed

The recordings were used twice: the first 12 sets (10-26 ~ 10-27, `gymrats_app/test/fixtures/pushup_cases/`, replayed by `test/services/pose/pushup_error_cases_test.dart`) drove the judge fix of PR #22 before the set was frozen, and the frozen 32-case set (5.1) measured the result and set the thresholds of the battle game. Changes made from the recordings, in order:

| Date / PR | What the recordings showed | What changed in the app |
|---|---|---|
| 10-31 · #22 (Hyunwoo) | The `base` pose model read a straight plank's hip at 127–139°, so normal reps were rejected as knees down | Pose model `base` → `accurate` (`lib/services/pose/pose_estimator.dart`); 23–25 fps instead of 27 on the test phone, above the 15 fps requirement |
| 10-31 · #22 | A head nod with the shoulders still up reached the depth line | A bottom now also needs the shoulders at least 0.68 shoulder widths below the top pose (`RepJudgeConfig.minShoulderDrop`); a nod alone is "Go lower" |
| 10-31 · #22 | The "hip angle below 110°" rule fired on normal reps and missed a kneeling bow | That rule removed; new knee rules for a kneeling bow (hips behind the hands, `bowHipHandGap`, `bowTorsoDrop`, `bowHipRise`) and for shins lifted at the top (`maxShinLiftGap`) |
| 10-31 · #22 | Belly-down reps were caught only by the hip height, which a shallow normal rep also hits | `bellyDown` now also needs the torso sagged at least 1.1 (`minBellyTorsoDrop`) |
| 10-31 · #22 | At 100 cm (positions C and D) the setup refused a good plank: the top of a plank read 1.05–1.22 (one rep 1.54) against the 1.0 line | Setup `maxPushUpTorsoDrop` 1.0 → 1.5 (`lib/services/pose/setup_checker.dart`), so a far placement can start; 8 cases the judge still gets wrong are kept as `knownErrors` in the replay test and listed in `docs/iteration-3/pushup-error-cases.md` |
| 10-31 · #20 (Woohyun) | Normal push-ups in the test recordings reached a depth of about 1.4–1.9 shoulder widths (`RepJudgeConfig` notes) | Excellent needs `maxDepth ≥ 1.6 × passDepth` (push-up 1.76), so only the deepest reps earn 15 points; the first proposal of 1.2 × would have made almost every normal rep Excellent. Good stays 10 |
| 11-01 · #23 (Woohyun) | Elbow angles measured on the recordings: a normal rep that was rejected for depth 90–91°; honest but tired shallow reps 110–126°; the half-rep-with-head-nod cheat 109–135° (team recording `20261027-142000_halfRepHeadNod` 127.8–145.2°); straight arms with a head dip 169–175° | A rep rejected only for depth earns Average +5 when `minElbowAngle ≤ 120°`; the line was raised from 105° after a phone test showed almost no Average at 105°. 120° is a compromise that misses some tired reps (121–126°) and pays some cheats (109–120°) |
| 11-03 · #32 (Hyunwoo) | From 5.2: one tester's normal reps bent the elbows to 68–89° while the head went down only 1.03–1.34 and the shoulders stayed under the 0.68 line; a single frame under the 155° default latched knees on planks that read 160–162°; with the phone at 79–85° normal reps read a bow gap of −0.74 against the −0.6 line; the arm average let one bent arm hide, so short reps counted | Four judge changes, tuned on the same 32 recordings (`rep_judge.dart`): a bottom is also reached with the elbows at 100° or less and the head 0.8 down (`deepElbowAngle`); the kneel check before the first plank is off (`defaultKneeHip` 155 → 0; the fold from the personal baseline stays); the bow line moves to −0.9 (`bowHipHandGap`); a rep closes only when the less extended arm reaches 172° (`lockoutArmAngle`). Result on the set: M1 46.0 → 79.4 %, M2 91.3 → 90.8 % (still a pass), M3 57.0 → 59.9 %; per person JP 14 → 90 %, SWH 20 → 53 %, HS 88 %, HSW 82 %; set 4 right reason 9 → 34 %. Cost on the earlier 12 fixtures: 3 cheat reps now count (two head nods, one bow). Not addressed: belly-down reps (13 of 35 still counted, phone angle suspected) and the lower-body jitter of SWH set 7 |
| 11-03 · from 5.2 and Woohyun's analysis | At 100 cm the judge fails most (position C M2 79.7 %, D M3 22.2 %; JP's phone at 79–85° outside the standard; hidden knees reported at likelihood 1.0; loose clothes in the floor's colour) | For the heuristic evaluation and the demo, players wear clothes that show the knees and contrast with the floor, and keep the phone within the standard's 50–100 cm and 60–80° |

What the AI testing leaves to Iteration 4 (judge owner Hyunwoo), after #32: the set 4 lock-out reason (34 % right), the `armsStraight` reason of set 8 (20 %), belly-down reps counted for two recorders (set 6 M2 62.9 %), the remaining normal reps of SWH set 7 (lower-body coordinates jitter), and a check of the #32 tuning on new recordings at other phone angles, since it was fitted on the same 32 cases. The set is frozen; a judge change is measured by re-running `flutter test test/ai_eval` on the new `main` commit and adding the run to 5.2.

# 6. Acceptance Testing

*Plan required in Iteration 3; results in Iteration 4.*

Plan written in Iteration 3 (PM, 2026-11-01). The six stories below are marked "UAT key story" in [Requirements & Specifications 5](Requirements-and-Specifications#5-functional-requirements) and are **frozen from 2026-11-06**, the end of Iteration 3 (Requirements guideline: once chosen, they cannot be altered afterwards). Results (pass/fail, date, tester, deviations) are reported in Iteration 4 in 6.4.

## 6.1 How the UAT is run
- **Testers:** each story is run by a team member who did not build the feature under test. Iteration 4 adds one person from outside the team for UAT-3 and UAT-5 if available.
- **Build:** release APK built from `main` at the commit given in the results. The same build is used for every story.
- **Devices:** Samsung Galaxy S22 and Galaxy S23, the phone on the floor as the setup screen asks, indoors with normal room light. Online stories use both phones on the team server.
- **Accounts:** two test accounts made for the session (one per phone). No personal accounts.
- **Pass rule:** a story passes only if every acceptance criterion passes. Each criterion is recorded as pass or fail with a note. A failure gets a GitHub issue linked from the results.
- **Results table (Iteration 4):** story, criterion, pass/fail, test date, tester, build commit, deviation and issue.

## 6.2 UAT stories

| ID | Story | Requirements section | Criteria under test |
|---|---|---|---|
| UAT-1 | Setting up the phone and pose | 5.3 | 1–3 |
| UAT-2 | Counting only fair push-ups | 5.4 | 1–3 |
| UAT-3 | Battling an online opponent in real time | 5.2, 5.5 | 5.2-1; 5.5-1, 3, 4 |
| UAT-4 | Seeing the result and form feedback | 5.6 | 1–2 |
| UAT-5 | Squat battle (vs AI) | 5.8 (new in Iteration 3) | 1–3 |
| UAT-6 | Fever time | 5.9 (new in Iteration 3) | 1–3 |

Not in the UAT, and free to change: 5.1 account, 5.7 match history, the help and rules screens, the safety warning, avatar skins, bot difficulty, and the game-point grades (Average, Good, Excellent) and KO.

## 6.3 Stories, acceptance criteria, and test procedures

### UAT-1. Setting up the phone and pose
**User story:** As a user exercising at home, I want the app to tell me how to place my phone and myself, so that my reps are counted correctly once the battle starts.

**Acceptance criteria**
1. **Placement guide.** Given the pose setup screen is open, when the phone lies too flat or my head, shoulders, elbows, and wrists are not all visible, then the app tells me what to fix (for example, to stand the phone up or which body part is not visible) and does not start.
2. **Ready and start.** Given the phone is placed correctly, when I hold a push-up position with straight arms, then the app marks me ready by itself after a countdown, and the battle starts.
3. **Camera permission denied.** Given camera access is not allowed, when the setup screen opens, then the app asks me to allow the camera and offers a button that opens the phone's settings.

**Test procedure**
1. Fresh install of the build; log in with test account A; tap "1v1 vs AI".
2. (AC1) Lay the phone almost flat → check the guide message. Stand it up, then step so the left wrist is out of the frame → check the message names the missing part. Check that no countdown starts in either case.
3. (AC2) Place the phone correctly and hold a straight-arm push-up position → check that a countdown runs and the battle starts without any tap.
4. (AC3) Deny the camera permission in Android settings → open setup again → check the message and that the button opens the app's settings page.

### UAT-2. Counting only fair push-ups
**User story:** As a beginner, I want only correct push-ups to count and to be told right away why a rep did not count, so that the score is fair and I can fix my form during the battle.

**Acceptance criteria**
1. **Valid rep.** Given a battle is running and I start with straight arms, when I lower my body far enough and push back up until my arms are straight, then my count goes up by one.
2. **Rejected rep.** Given a battle is running, when a rep is too shallow or my knees are on the floor, then the rep is not counted and the reason appears on screen at once.
3. **Phone moved.** Given a battle is running, when the phone tilts or shakes, then reps finished during that time are not counted and the app tells me to hold the phone still.

**Test procedure**
1. Start "1v1 vs AI" with test account A and complete setup.
2. (AC1) Do 5 full push-ups at a normal pace → the count shows 5. A second team member counts by eye at the same time.
3. (AC2) In the next battle do 3 half reps (elbows barely bent), then 3 push-ups with the knees on the floor → the count does not change and a reason appears within about a second of each rep. (A half rep may still add Average game points; the count must not change.)
4. (AC3) In the next battle, have the second person tap the phone so it tilts while you do 2 reps → those reps do not count and the "hold the phone still" message appears.

### UAT-3. Battling an online opponent in real time
**User story:** As a user in an online battle, I want to see my opponent move and score live, so that it feels like working out against a real person.

**Acceptance criteria**
1. **Match found.** Given two users tap "Online 1v1 battle" at about the same time, when the app pairs them, then both phones show the match-found screen with both nicknames.
2. **Live opponent.** Given an online battle is running, when my opponent moves or scores a rep, then I see their avatar follow their movement and their score go up, and no camera video is sent.
3. **Short network drop.** Given an online battle is running, when my connection drops, then the app shows that it is reconnecting while the timer keeps running; if I am not back within 10 seconds, I lose by disconnection.
4. **Leaving the battle.** Given an online battle has started, when I press Back and confirm leaving, then I forfeit and the match is recorded as my loss.

**Test procedure**
1. Phone 1 with test account A, phone 2 with test account B, both on Wi-Fi.
2. (AC1) Both tap "Online 1v1 battle" within 5 seconds → both show the match-found screen with "A" and "B".
3. (AC2) Complete setup on both. B does 3 push-ups → on phone 1, B's avatar moves down and up, and B's score reaches 3. (Video check: the protocol sends only joint coordinates; confirm in the battle server's log that no image data arrives.)
4. (AC3) In a new match, turn on airplane mode on phone 1 for 5 seconds, then off → phone 1 shows reconnecting and the battle continues. Next match: keep airplane mode on for 15 seconds → phone 1 loses by disconnection.
5. (AC4) In a new match, press Back on phone 1 and confirm → phone 1's history shows a loss; phone 2 shows a win.

### UAT-4. Seeing the result and form feedback
**User story:** As a beginner, I want to see who won and what to fix in my form after each battle, so that I improve next time instead of only counting reps.

**Acceptance criteria**
1. **Result.** Given a battle is running, when the round ends (time up, or a KO), then the app stops counting and shows win, loss, or draw with both final scores.
2. **Form feedback.** Given the result of a push-up battle is shown, when I open the form feedback, then I see my counted and rejected reps, my top form issues each with one tip to fix it, and a per-rep record.

**Test procedure**
1. Run a "1v1 vs AI" push-up battle with account A to the end of the 30-second round, mixing 4 valid reps and 2 knee reps.
2. (AC1) Check the result screen shows win, loss, or draw and both scores, and that the count no longer changes when you keep moving.
3. (AC2) Open the form feedback → check it shows 4 counted and 2 rejected reps (with the knee reason), at least one form issue with a tip, and one row per rep.

### UAT-5. Squat battle
**User story:** As a beginner who cannot do many push-ups yet, I want to battle with squats too, so that I can compete with an exercise I am able to do.

**Acceptance criteria**
1. **Choosing squat.** Given I am on Home, when I choose squat and start a match against the AI rival, then the setup and the battle are for squats (the screens name the exercise).
2. **Squat setup.** Given the squat setup screen is open, when my whole body is not visible or I am not standing, then the app tells me what to fix; when I stand fully in view, the battle starts as in UAT-1.
3. **Fair squats.** Given a squat battle is running, when I squat low enough and stand back up, then my count goes up by one; when a squat is too shallow, it is not counted and the reason appears at once.

**Test procedure**
1. Log in with account A; on Home choose squat, then "1v1 vs AI".
2. (AC1) Check the setup, battle, and result screens show squat, not push-up.
3. (AC2) Stand so the feet are out of the frame → check the message; then stand fully in view → the battle starts.
4. (AC3) Do 5 full squats → the count shows 5. Do 3 quarter squats → no count, and a reason appears for each.

### UAT-6. Fever time
**User story:** As a user who is behind near the end of a battle, I want a fever time where my reps score double, so that the battle stays exciting until the last second and I still have a chance to win.

**Acceptance criteria**
1. **Fever starts.** Given a battle is running, when the fever time begins near the end of the round (at 20 s of the 30-second round), then the screen clearly shows that fever is on until the round ends.
2. **Double score.** Given fever is on, when I complete a valid rep, then it earns twice the points the same rep earns before fever, and the health bar moves toward me accordingly.
3. **Rejected rep.** Given fever is on, when a rep is rejected with the knees on the floor, then it earns no points and my score does not change, the same as before fever.

**Test procedure**
1. Run a "1v1 vs AI" push-up battle with account A.
2. Before fever, do one valid rep and note the points it adds to my game score.
3. (AC1) Wait for the fever time (20 s) → check the fever display appears and stays until the round ends.
4. (AC2) During fever do one valid rep of the same kind → the score rises by twice the points from step 2, and the health bar moves toward me.
5. (AC3) During fever do one knee rep → my score does not change.

## 6.4 Results

To be completed in Iteration 4.

# 7. Alpha & Beta Testing

*Required in Iteration 5 (plan, execution and results).*

To be completed in Iteration 5.
