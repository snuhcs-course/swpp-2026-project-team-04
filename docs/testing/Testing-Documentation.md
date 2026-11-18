# Project: GymMouse — Real-Time 1v1 Exercise Battles

## Table of contents
* [1. Document Revision History](#1-document-revision-history)
* [2. Overview](#2-overview)
* [3. Test Responsibility & Schedule](#3-test-responsibility--schedule)
> * [3.1 Who](#31-who)
> * [3.2 When](#32-when)
* [4. Unit & Integration Testing](#4-unit--integration-testing)
> * [4.1 Plan](#41-plan)
> * [4.2 Results](#42-results)
* [5. AI Module Testing](#5-ai-module-testing) (Iteration 3, re-run in Iteration 4)
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
|Rev.1.1|2026-10-23|Added the PR #10 results (phone tilt fix) to 4.2; App tests re-run on the final Iteration 2 `main` (`9e9a911`); second app coverage attempt on Windows; PR #11 (coverage script); App coverage measured on the final Iteration 2 `main` (`62f6a9d`) with the report as evidence; PR #12 (demo README and video)|
|Rev.2.0|2026-11-01|Added 6. Acceptance Testing plan: how the UAT is run, six UAT stories with criteria and procedures, frozen from 2026-11-06; results follow in Iteration 4|
|Rev.2.1|2026-11-03|Iteration 3 results in 4.2 (final main, CI coverage screenshot, who ran the suite); 5. AI Module Testing: the frozen set with its per-set table, labels, assertion per case and threshold commit (5.1), the first run and the re-run after the judge tuning with failure analyses (5.2), what the testing changed and what it leaves to Iteration 4 (5.3); 3.1, 3.2 and 4.1 Iteration 3 revisions; final guideline audit|
|Rev.2.2|2026-11-04|6. Acceptance Testing follows Requirements Rev.2.3: UAT-1 pose guide, UAT-3 both-ready and live-opponent game elements (no avatar), UAT-4 feedback over time, UAT-5 game points and fever, UAT-6 tutorial; every story run with push-ups and squats. Readability: file paths, branch names and narrative PR numbers taken out; commands, result commits, the evaluation set path and the threshold commit kept|
|Rev.2.3|2026-11-09|Project renamed from GymRats to GymMouse|
|Rev.2.4|2026-11-12|6.3 follows Requirements Rev.2.6: UAT-2, UAT-3 and UAT-5 user stories reworded (team meeting 11-11, UAT sheet); UAT-5 criterion 3 and procedure steps 2–3 use the new battle screen's labels (GOOD then +10, EXCELLENT then +20 with 2 HIT, FEVER ×2 in the chip beside the timer). Display wording only; the acceptance criteria are unchanged|
|Rev.2.5|2026-11-14|6.3 follows the new result report: UAT-5 procedure step 5 (the result shows win or loss with both final scores, "KO" after a KO) and UAT-6 procedure step 5 (button "자세 피드백 전체 보기"). Display wording only; the acceptance criteria are unchanged|
|Rev.2.6|2026-11-15|UAT-6 procedure step 1 follows the team decision to drop the separate rules screen: the tutorial opens right after sign-up, and "?" on Home opens the same tutorial. Wording only; the acceptance criteria are unchanged|
|Rev.2.7|2026-11-15|UAT-6 criteria and procedure revised to the tutorial the team built (team decision 2026-11-15): the separate rules screen became a short tutorial on the game rules (intro, then push-up and squat: setup, health bar, grades, combo, fever, KO, report). Dropped from UAT-6: the AI levels, the phone position and setup messages, the rejection reasons and the 기록 tab with its statistics (setup messages and rejection reasons stay covered by UAT-1 and UAT-2, the records by UAT-4). A change after the 11-06 freeze, made by the team; to be confirmed with the TA|
|Rev.2.8|2026-11-16|6.1 says how cycle 1 was run (in class, testers from other teams, one account per tester, sheet in app-flow order); 6.2 notes the cycle 2 date and the characters; UAT-5 procedure step 3 reads the countdown timer; 6.4 cycle 1 results (73/74 steps, 98.6 %), failure analysis and the changes planned from the comments|
|Rev.2.9|2026-11-18|5.2: AI module evaluation re-run on main `9841a60` after the setup cue, the character's talk and the person check were merged (same numbers as Iteration 3); 6.4: cycle 2 plan (28 steps in user-flow order, the cycle 1 step UAT-1 step 4 split into B3 and D1, the setup cue wording in the expected results). Acceptance criteria unchanged|
|Rev.2.10|2026-11-18|5.2: the unified push-up knee rule (build flag `PUSHUP_FRAME_KNEE`, off by default) measured off and on on the frozen set at `a9e6cd4`, and the new supplemental Iteration 4 set (16 coordinate-only cases, push-ups and squats, labels pending, M1–M3 N/A) with its commands. The frozen set and its thresholds unchanged|
|Rev.2.11|2026-11-18|4.2: Iteration 4 results on the final main `7680df6` (CI run on main: test counts, skips, coverage per layer; per-member summary from the members' notes, with the PM's notes); 5.2: final re-run of the frozen set on `7680df6` (rule off by default, same numbers as `9841a60`)|

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

| Component | Owner |
|---|---|
| Rep judging, pose setup, phone placement (on-device AI module) | Hyunwoo Song |
| AI battle and form feedback | Hyunwoo Song |
| Accounts, history, saved feedback (app) | Jinyoung Park |
| REST API (Django) | Jinyoung Park |
| Battle result saving (battle server ↔ Django) | Jinyoung Park |
| Online battle and avatars (app and battle server) | Sangwoo Hahn |
| Home, AI matching and versus screens, shared widgets, theme | Woohyun Song (PM) |

**Policy for new code**
* The author of a feature or a fix writes its tests and submits them in the same pull request. A bug fix starts with a test that fails before the fix.
* Whoever changes a file updates its tests in the same pull request, even in another owner's area.
* Tests never use the real network, the team server, the camera, ML Kit, or secure storage. They use the hand-written fakes kept with the app tests.
* The PM runs the full suite with coverage on the submitted commit at the end of each iteration and updates 4.2.

*Revision (Iteration 3, 2026-11-03):* the PM role passed to Jinyoung Park for Iteration 3 (the end-of-iteration run in 4.2 and the AI module evaluation in 5 are his). Areas added in Iteration 3 and their test owners, as merged ([Design Documentation 2.3.11](Design-Documentation#2311-who-owns-what)): battle game rules, fever, KO and bot levels, the rules screen and the safety warning, score history and the new Home: Woohyun Song; squat judge and setup, squat battles and matching per exercise, SOMA avatars and the opponent view: Sangwoo Hahn; push-up recordings and judge accuracy: Hyunwoo Song; the CI workflow and the AI evaluation set and runner: Jinyoung Park. The rows above stay as planned; cross-owner edits were agreed in the PRs.

## 3.2 When

| When | What runs | Who | Must pass to merge |
|---|---|---|---|
| Before opening a pull request, and again after the last change | `flutter analyze` and `flutter test` for the app; `pytest` for the REST API when the server code changed | PR author | Yes. The PR description lists the commands, the commit, and the pass/fail counts. |
| Pull request review | Reviewer checks the reported results and that new code has tests | AI review (Claude Code, Codex), then the PM | The PM approves only with passing results. |
| After a battle server deploy (opt-in) | The live check of the app's session against the team server (see 4.1) | Sangwoo Hahn | – |
| End of each iteration | Full suite with coverage on the submitted commit; results recorded in 4.2 | PM | – |

There is no CI (GitHub Actions) yet; all tests run on the developers' machines.

*Revision (2026-10-26):* GitHub Actions now runs on every pull request: `flutter analyze` and `flutter test`, the per-layer coverage in four shards (the per-file coverage script and the per-layer merge script of 4.1), and `pytest --cov` for the REST API, and posts the numbers as a sticky comment on the PR. The rows above still hold: the author runs the tests before opening the PR, and the PM merges only with the CI comment green.

# 4. Unit & Integration Testing

*Required from Iteration 2; kept up to date every iteration.*

## 4.1 Plan

### Frameworks

| Component | Test framework | Mocking / isolation | Coverage tool |
|---|---|---|---|
| Model, ViewModel, Service (app) | `flutter_test` | Hand-written fakes (camera, pose estimator, repositories, matchmaker, opponent, rep sound); the `http` package's `MockClient` for the API client | `flutter test --coverage` (lcov) + the per-layer coverage script (4.1 commands) |
| View (screens, widgets) | `flutter_test` widget tests | Fake repositories, fake camera and pose estimator, in-memory stores | Same |
| Battle server (Dart) | `flutter_test`, the real battle server on loopback sockets | Fake result store, a local HTTP server standing in for Django | Not measured (outside the Flutter package) |
| REST API (Django) | `pytest`, `pytest-django` | Django test client, in-memory SQLite, fixed test secrets in the test settings | `pytest-cov` |

### Unit and integration tests

Most tests are unit tests of one class with fakes around it. These tests check several parts working together:

| Integration test | Parts together |
|---|---|
| Online battle | The app's online battle session clients and the real battle server over loopback WebSockets: login check, FIFO matching, ready timeout, rep deduplication and conflicts, pose relay, reconnect grace, forfeit and void, the server-decided result |
| Battle result saving | The battle server → its HTTP result store → a local HTTP server: start, result and void saved once, retries, restart recovery |
| App flow | The whole app with in-memory repositories: log-in and sign-up to home, home → matching → versus → setup → battle → result → home |
| Demo apps | The demo apps (pose setup, rep judging, AI battle, accounts and history) driven through their view models and screens with the fake camera and pose fixtures |
| REST API | URL routing, serializers, views, JWT authentication and the database together, through the Django test client |
| Live server check (opt-in) | The app's session against the deployed server over WSS. Skipped by default. |

### Coverage goals by layer (line coverage)

| Layer | Target | Why |
|---|---|---|
| Model | 90% | Plain data and JSON parsing; cheap to test fully |
| ViewModel | 90% | Holds the app's logic and state transitions |
| Service | 85% | Rep judging, networking and storage; a few platform calls need a real device |
| View (screens, widgets) | 75% | Some widgets wrap platform views (camera preview, WebView) that widget tests cannot drive |
| REST API (Django: accounts, matches, project settings) | 90% | Business rules, authentication, and data integrity |
| Battle server (Dart) | – (no number yet) | Behavior-tested through the integration tests above; line coverage once it has its own Dart package |

### Scope & exclusions

* **Excluded from the numbers:** the demo entry points (manual testing). The app entry point, the config, the shared protocol code and the theme are counted in "Other", not in a layer. Files that no test loads (interfaces, constants) do not appear in lcov.
* **Covered only by manual checks on a phone:** the device parts of the camera service, the pose estimator and the camera preview widget (real camera, ML Kit), the gravity and gyroscope channel on the Android side, and the three.js avatar page in the WebView. Their logic is tested through fakes.
* **Server:** tests use an in-memory SQLite database and a fast password hasher (MD5, in the test settings); production uses bcrypt. The WSGI entry point is only loaded by gunicorn.

### Reproducible commands

Environment: Flutter stable with Dart `^3.13.4` (the app's pubspec constraint), Python 3.12. No environment variables are needed: the server tests set their own throwaway secrets.

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

The per-layer coverage script (the last command of each app block above) merges one or more lcov files and prints the per-layer table used in 4.2 (a line counts as covered when any test hit it).

*Revision (2026-10-26):* `bash ../tools/coverage_per_file.sh` (from `gymrats_app/`) runs the per-file loop above with a 240 s limit per file and is what CI runs in four shards; the merge step is unchanged. Versions used for every Iteration 3 number: Flutter 3.47.5 / Dart 3.13.4, Python 3.12.

## 4.2 Results

### Iteration 2

**Summary**

| Component | Frameworks | Target | Actual | Date | Commit | Command / Report |
|---|---|---|---|---|---|---|
| Model | flutter_test | 90% | 98.1% (210 / 214 lines) | 10/23 | `62f6a9d` | per-file `flutter test --coverage`, merged with the per-layer coverage script |
| ViewModel | flutter_test, fakes | 90% | 94.4% (837 / 887) | 10/23 | `62f6a9d` | same |
| Service | flutter_test, MockClient, fakes | 85% | 92.0% (1592 / 1731) | 10/23 | `62f6a9d` | same |
| View | flutter_test (widget) | 75% | 91.6% (3169 / 3460) | 10/23 | `62f6a9d` | same |
| App, other (entry point, shared code, theme) | flutter_test | – | 91.2% (146 / 160) | 10/23 | `62f6a9d` | same |
| App, total | | – | 92.3% (5954 / 6452) | 10/23 | `62f6a9d` | same |
| REST API (Django) | pytest, pytest-django, pytest-cov | 90% | **96%** (484 statements, 20 missed) | 10/22 | `bf141af` | `.venv/bin/python -m pytest --cov=…` |
| Battle server (Dart) | flutter_test, loopback sockets | – | not measured | 10/21 | `706694f` | 34 tests in the three online battle test files |

`62f6a9d` is main at the end of Iteration 2 and the commit of the Iteration 2 demo. It adds only the demo README and video to `9e9a911`, so the app tests run on `9e9a911` cover the same code. Since `bf141af`, only the app's phone-tilt code and its tests, the per-layer coverage script and the demo README and video changed; the server did not, so the REST API results on `bf141af` also hold for `62f6a9d`.

App coverage on `62f6a9d` was measured by Jinyoung Park one test file at a time, with the commands in 4.1: 73 lcov files, one for each test file except the opt-in live check (skipped by default), merged with the per-layer coverage script. The report is under **Evidence** below. On Windows the same measurement stopped in coverage collection (`getSourceReport: Service has disappeared`) on `bf141af` (10/22) and `9e9a911` (10/23), even one file at a time and with `--concurrency=1`. The first results, reported on `706694f` (10/21), were Model 95.8%, ViewModel 94.4%, Service 91.3% and View 91.7%.

**Tests**

* App coverage, `62f6a9d` (10/23, Jinyoung Park): each of the 73 test files run on its own with `flutter test --coverage`, then merged: 5,954 of 6,452 app lines (92.3%; the demo entry points excluded).
* App, `9e9a911` (10/23, Windows, after `flutter clean`): `flutter test` 675 passed, 0 failed, 1 skipped.
* App, `bf141af` (10/22, Flutter 3.47.5, Dart 3.13.4, Windows): `flutter test` 673 passed, 0 failed, 1 skipped (the opt-in live check). `flutter analyze`: no issues.
* App, `706694f` (10/21, Flutter 3.47.5, macOS): 663 passed, 0 failed, 1 skipped; `flutter analyze`: no issues. Coverage was measured one test file at a time, because a single `flutter test --coverage` run crashed (flutter_tester segfault).
* REST API, `bf141af`: `pytest` 76 passed, 0 failed, 0 skipped (Python 3.12.3, Django 5.2.7).
* Every layer meets its target. Gaps: the least-covered app files are the camera preview widget (8.8%) and the 3D avatar WebView widget (30.3%), which widget tests cannot drive, and the debug-only synthetic battle screen and its pose generator for testing the network with one phone (both 0%); none of them pulls its layer below the target. The battle server has no line coverage number yet (it sits outside the Flutter package; plan: give it its own Dart package and measure it with `dart test --coverage`), and the REST API misses the WSGI entry point and the branches for two uploads of the same battle racing each other (the `IntegrityError` handling in the match views and the internal result endpoint).

**Results reported in pull requests** (each PR states its own run before merge)

| PR | Commit | `flutter analyze` | `flutter test` | `pytest` |
|---|---|---|---|---|
| #6 | `982afcc` | no issues | 444 passed | 39 passed |
| #7 | `3103a30` | did not finish (analyzer crash on that machine) | 506 passed | not re-run (server unchanged) |
| #8 | – | passed | 571 passed, 1 skipped | – |
| #9 | `706694f` | no issues | 663 passed, 1 skipped | 74 passed; 76 passed after merging main |
| #10 | `e7b0ab0` | not run on the author's machine; no issues on the PM's re-run (10/23) | 128 passed in the 5 related test files; 675 passed, 1 skipped on the PM's re-run (10/23) | not re-run (server unchanged) |
| #11 | `2b33aea` | – | – (adds the per-layer coverage script only) | – |
| #12 | `a37a2c6` | – | – (adds the demo README and video only) | – |

**Evidence**

App line coverage by layer on `62f6a9d` (HTML report of the per-layer coverage script: input files and layer totals, then every file):

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

#### 2026-11-03 · commit `f03a460` · every Iteration 3 pull request merged; heuristic-evaluation build

main after the last Iteration 3 pull request (the push-up judge tuning of 2026-11-03; its app code is the commit `a643088`, which CI measured). The Iteration 3 demo build and the APK for the heuristic evaluation (`submission.zip` → `app.apk`, `flutter build apk --release`) are built from this app code, and the team server was redeployed on 2026-11-03 from `e6b16fe`, whose server code is unchanged since (Django with migration `matches.0003_match_scores`, battle server release `20261102T174257Z-main-e6b16fe`).

Commands as in 4.1, run by Jinyoung Park (PM) on a clean checkout of `f03a460` (macOS, Flutter 3.47.5 / Dart 3.13.4, Python 3.12) and by CI on `a643088` (ubuntu-latest, same versions; same counts). Plan change this iteration: CI added (3.2 and 4.1 revisions), so the coverage numbers come from the CI run rather than a developer's machine; the targets are unchanged.

- `flutter analyze`: no issues.
- `flutter test`: **1476 passed, 0 failed, 10 skipped**. The skipped tests are the 9 recorded push-up cases the judge still gets wrong (each skipped with its reason in code and listed in the push-up error-case notes, `docs/iteration-3/pushup-error-cases.md`; 8 before the judge tuning of 2026-11-03, 9 after) and the live team-server check, skipped unless `RUN_PUBLIC_BATTLE_SMOKE` is set.
- Server `.venv/bin/python -m pytest`: **101 passed, 0 failed**.
- Per pull request, GitHub Actions ran the same commands plus the per-layer coverage on every head commit; each PR body has its own results table (date, head commit, counts, coverage).

**Summary** (coverage from the CI run on `a643088`, 2026-11-03 16:03 KST, 1476 passed and 10 skipped; the app code of main `f03a460`; screenshot below)

| Component | Frameworks | Target | Actual | Date | Commit | Command / Report |
|---|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.4% (266 / 273 lines) | 11/03 | `a643088` | CI `Flutter coverage` shards (the per-file coverage script, merged by the per-layer coverage script) |
| ViewModel | flutter_test, fakes | 90% | 96.1% (931 / 969) | 11/03 | `a643088` | same |
| Service | flutter_test, MockClient, fakes | 85% | 94.3% (2232 / 2367) | 11/03 | `a643088` | same |
| View | flutter_test (widget) | 75% | 91.0% (4053 / 4452) | 11/03 | `a643088` | same |
| App, other (entry point, shared code, theme) | flutter_test | – | 69.7% (124 / 178) | 11/03 | `a643088` | same |
| Total (app) | | – | 92.3% (7606 / 8239) | 11/03 | `a643088` | same |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% | 11/03 | `a643088` | CI `Django API` job: `pytest --cov=accounts --cov=matches --cov=gymrats` |
| Battle server (Dart) | flutter_test, loopback sockets | – | not measured | 11/03 | `f03a460` | the online battle behavior tests (run inside `flutter test`) |

- Left out of the client coverage numbers: the setup screen's widget test file (240 s timeout in the per-file run; its tests pass in `flutter test`). Files no test loads are interfaces or constant-only files, as in Iteration 2.
- Shortfalls: none against the targets. Gap carried over: no line coverage for the Dart battle server (same reason and plan as Iteration 2).

<p align="center">
<img width="800" alt="GitHub Actions coverage comment on PR #32 (a643088): per-layer table and Django coverage" src="images/testing/iter3-ci-coverage-a643088.png" />
</p>

- Test cases added or changed in Iteration 3 are listed per PR in the PR bodies and per push in each member's notes under `docs/testing/iteration-3/`.

### Iteration 4

#### 2026-11-18 · commit `7680df6` · final Iteration 4 main (every Iteration 4 pull request merged)

main after the last Iteration 4 pull request (#77, the setup cue board above the camera). 30 pull requests, #45–#77, were merged between 2026-11-11 and 2026-11-18; the three merged after PR #74 were #76 (the next battle's mission), #75 (the unified push-up knee rule, off by default, and the Iteration 4 evaluation set, 5.2) and #77. Coverage and test counts come from the GitHub Actions workflow "Tests and coverage" that ran on the push of `7680df6` to main ([run 44285881008](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/44285881008), 2026-11-18 19:29 KST, every job succeeded). CI ran on ubuntu-latest with Flutter 3.47.5 / Dart 3.13.4 and Python 3.12, using the commands in 4.1: the per-file coverage script in four shards, merged with the per-layer coverage script. The plan and the targets are unchanged this iteration.

- `flutter analyze`: no issues.
- `flutter test`: **3758 passed, 0 failed, 10 skipped**. The skipped tests are the same 10 as at the end of Iteration 3. Nine are recorded push-up cases the judge still gets wrong, each skipped with its reason in code (the known-errors list of the push-up error-case test). The tenth is the live team-server check, which is skipped unless `RUN_PUBLIC_BATTLE_SMOKE` is set. Every member's notes report the same 10 skips throughout the iteration.
- Server `pytest --cov=accounts --cov=matches --cov=gymrats`: **114 passed, 0 failed** (1 warning). The 13 new tests are the statistics endpoint tests of PR #56.
- Earlier runs for comparison: main `9841a60` after PR #74 had 3559 passed (CI on the PR #74 head `d724c56`, same tree); main `82113be` after PR #75 had 3751 passed ([run 44281677233](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/44281677233)); all with 0 failed and the same 10 skipped.

**Summary** (CI run on main `7680df6`)

| Component | Frameworks | Target | Actual | Date | Commit | Command / Report |
|---|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.4% (693 / 697 lines) | 11/18 | `7680df6` | CI `Flutter coverage` shards (the per-file coverage script, merged by the per-layer coverage script) |
| ViewModel | flutter_test, fakes | 90% | 98.1% (1752 / 1786) | 11/18 | same | same |
| Service | flutter_test, MockClient, fakes | 85% | 95.5% (4529 / 4741) | 11/18 | same | same |
| View | flutter_test (widget) | 75% | 98.0% (11105 / 11326) | 11/18 | same | same |
| App, other (entry point, shared code, theme) | flutter_test | – | 95.9% (370 / 386) | 11/18 | same | same |
| Total (app) | | – | 97.4% (18449 / 18936) | 11/18 | same | same |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (535 statements, 20 missed) | 11/18 | same | CI `Django API` job: `pytest --cov=accounts --cov=matches --cov=gymrats` |
| Battle server (Dart) | flutter_test, loopback sockets | – | not measured | 11/18 | same | the online battle behavior tests (run inside `flutter test`) |

Change since Iteration 3 (`a643088`, 4.2 above): 1476 → 3758 passing app tests, 101 → 114 server tests, and 8239 → 18936 measured app lines. Every layer went up: Model 97.4 → 99.4%, ViewModel 96.1 → 98.1%, Service 94.3 → 95.5%, View 91.0 → 98.0%.

- **Left out of the client coverage numbers:** the same four test files as on `9841a60` hit CI's 240 s per-file limit: the settings screen test, the background music test, the person-behind video replay test and the push-up error-case test. Their tests still ran and passed in `flutter test` above. The lines they alone reach are therefore counted as not covered, so the layer numbers are a lower bound. Files that no test loads are interfaces or constant-only files, as in Iteration 2.
- **Shortfalls:** none against the targets. Two gaps carry over. The Dart battle server still has no line coverage number (same reason and plan as in Iteration 2). Full-suite `flutter test --coverage` cannot be run on the members' Windows machines: it stops with "getSourceReport: Service has disappeared" or stalls. Members therefore measured coverage one file at a time or on the changed files only, and the team-level layer numbers come from CI.

<!-- TODO(hyun-1210): add the screenshot of the CI coverage summary of run 44285881008 (main 7680df6) as images/testing/iter4-ci-coverage-7680df6.png -->

**Per member** (each member's per-push notes are in `docs/testing/iteration-4/`; every pull request body also has its own results table with the head commit, the counts and the CI coverage)

| Member | Pull requests (merged) | What their tests cover | Their runs (app `flutter test`, all 0 failed, 10 skipped) | Coverage they report |
|---|---|---|---|---|
| Woohyun Song (`g1fted13`) | #45, #50, #52, #54, #55, #61, #62, #63, #68, #70, #73, #74, #76, #77 | home lobby and settings, the one-stage battle screen, the drawn characters and character select, the matching and end screens, the result report, the archive and statistics, the form feedback screen, the victory scene, no ready button in setup, setup cues readable from a distance, the character's talk after a battle, the next battle's mission, the setup cue board above the camera | 1490 on `38c44b1` (11-08) to 3687 on `bfd9ac2` and 3694 on `a628cff` (11-18); 3417 on `79c2e80` with the S2 person check on and off | CI comments on #45, #50, #52, #54, #55, #61, #62, #73, #76 and #77: every layer above target in each run (lowest: Service 92.6% on #55, View 92.3% on #45; #76 on `ba066ea`: Model 99.4%, ViewModel 98.1%, Service 95.4%, View 98.0%). For #63, #68, #70 and #74 the notes leave the layer numbers as TODOs for the CI comment. The team numbers above cover that code. |
| Jinyoung Park (`ishlove77`) | #48, #53, #56, #57, #60, #64 | voice guidance and its settings, battle music and hit sounds, the cumulative statistics (app and the stats endpoint), squat form feedback and the result view model, the tutorial | 1525 on `4208543` (11-08) to 2771 on `71f73aa` (11-15); server 114 passed on `51052b7` | `coverage_per_file.sh` + `coverage_by_layer.py`: every layer above target in each step (e.g. on `3850426`: Model 99.3%, ViewModel 97.5%, Service 95.9%, View 95.3%); the new files of each step at or near 100%. |
| Sangwoo Hahn (`Sangwoo-Hahn`) | #49, #51, #65, #66, #67, #69, #71, #72, #75 | push-up and squat setup silhouettes and alignment, squat depth in bot reports and the shared squat judge, the replay of the stored match mode, the push-up judge (S1), the UAT phone-angle chip, the person continuity warning (S2, off by default), the unified push-up knee rule (off by default) and the Iteration 4 evaluation set with its scorer | 1557 on base `7e3dbcf` (11-12) to 3342 on `f5c78e1` (11-17), in both the ordinary build and the `S2_PERSON_GUARD=true` build; 3751 after merging main into #75 (`a9e6cd4`, 11-18) | Changed files only (full-layer coverage not measured locally): all above their layer target, e.g. on `c940d09` `rep_judge.dart` 97.4%, `pose_metrics.dart` 98.8%, `push_up_judge_adapter.dart` 90.0%; on `f5c78e1` `rep_counter_viewmodel.dart` 96.9%, `battle_screen.dart` 94.4%; on #75 with the knee rule on, `pose_metrics.dart` 97.9%, `rep_judge.dart` 96.3%. |
| Hyunwoo Song (`hyun-1210`, PM) | – (merged #45–#77 in the team-plan order) | the AI module re-runs of 5.2 on main `9841a60` and on the final tree `7680df6`, the acceptance test sessions of 6.4, and this page (notes: `docs/testing/iteration-4/hyun-1210.md`) | `flutter test test/ai_eval/ai_eval_test.dart`: 1 passed on `9841a60` and on `7680df6` (11-18) | not measured (no app code changed); the team numbers above come from CI |

- Test cases added or changed in Iteration 4 are listed per PR in the PR bodies and per push in each member's notes under `docs/testing/iteration-4/`.

# 5. AI Module Testing

*Required from Iteration 3 (thresholds declared and first results); kept up to date from Iteration 4.*

Plan committed before the first run: the evaluation plan and the README in the evaluation set's folder (merged 2026-10-30 KST) declare the protocol, the 32 cases (four members × 8 sets, positions A–D, complete on 2026-11-02), the expected labels, the per-case assertion and the thresholds M1 count accuracy ≥ 90%, M2 rejection rate ≥ 90%, M3 right reason ≥ 80%. Results follow in this section after the run on a pinned main commit (Iteration 3). The module under test is the on-device rep judging ([Design Documentation 2.3.2](Design-Documentation#232-rep-judging-on-device-ai-module)).

## 5.1 Set, labels and runner (frozen 2026-11-03)
- Cases: `gymrats_app/test/ai_eval/cases/{HS,JP,SWH,HSW}/` — 4 recorders × 8 sets = 32 recordings (landmarks and phone sensors only, no video), 270 labelled reps. Labels (`label.perRep`) come from the record sheets; each recorder's sheet is in the folder. Deviations from the protocol (Sangwoo's sets 5 reps / 30 s, Hyunwoo's set 4 with 11 descents and set 7 with 5 reps, Woohyun's set 1 with 5 and set 5 with 9 reps, Jinyoung's distances not measured) are listed in the README of the evaluation set's folder and kept as recorded.
- Ground truth: the motion the recorder actually did, written on the sheet during the recording; the PM transferred it to the files (10-31 ~ 11-03). Hyunwoo checked all 32 files on 11-02 (open, kinds and counts as on the sheets, 17–26 fps). No case has been added, edited or removed since the set was frozen on main at `dccd84a`; an addition would be listed in the README with its date and reason.
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

- Assertion per case: the labelled reps and the reps the judge closed in the replay are aligned by the fewest edits (the scorer's alignment step); each aligned pair is compared on counted / rejected and on the reject reason. M1 = correct reps counted ÷ correct reps done; M2 = incorrect reps not counted ÷ incorrect reps done; M3 = incorrect reps rejected with the labelled reason ÷ incorrect reps done. An incorrect rep the judge never closed counts as not counted (M2) and wrong (M3); judged reps with no labelled partner are reported apart. No string matching: the comparison is on the verdict enum per rep.
- Thresholds, declared before any run and committed with the plan (`a3576ce`, 2026-10-30 02:38 KST): M1 ≥ 90%, M2 ≥ 90%, M3 ≥ 80%, all three over the 32 cases; per position and per person the metrics are reported without a threshold.
- Runner: the evaluation test replays every recording through the current rep judge with its default configuration (through the shared case loader) and scores it with the evaluation scorer (reps aligned by the fewest edits). Command, from `gymrats_app/`: `flutter test test/ai_eval` (report printed and written to `build/ai_eval/report.md`); `--dart-define=AI_EVAL_STRICT=true` turns the thresholds into assertions.
- Settings under test: ML Kit pose detection 0.16.1, `accurate` model, the rep judge's default configuration at the commit (minLikelihood 0.6, bottomDepth 1.1, minShoulderDrop 0.68, maxTorsoDrop 1.2). The replay is deterministic: no model sampling, seed or prompt is involved, so two runs on the same commit give the same numbers.

## 5.2 Results

#### 2026-11-18 · code at commit `7680df6` · AI module evaluation, final Iteration 4 main (frozen set unchanged)
Final re-run (schedule P20) on main after every Iteration 4 pull request was merged, including PR #75 (Sangwoo Hahn, merged as `82113be`), which unified the push-up knee evidence into one rule behind the build flag `PUSHUP_FRAME_KNEE`, **off by default**. The frozen set of 5.1 (32 cases, 270 labelled reps) and the thresholds are unchanged; no commit since `dccd84a` touches the cases folder. The PM ran `flutter test --no-pub test/ai_eval/ai_eval_test.dart` from `gymrats_app/` on 2026-11-18 (19:46 KST) on a tree whose `gymrats_app/` is identical to main `7680df6` (1 test passed; Windows, Flutter 3.47.5 / Dart 3.13.4; default build).

| Metric | Default build, rule off (main `7680df6`) | Rule on (`PUSHUP_FRAME_KNEE=true`, `a9e6cd4`, entry below) | Threshold | Result (default build) |
|---|---|---|---|---|
| M1 Count accuracy | 79.4 % (50/63) | 81.0 % (51/63) | ≥ 90 % | **fail** |
| M2 Rejection rate | 90.8 % (188/207) | 87.4 % (181/207) | ≥ 90 % | pass |
| M3 Right reason | 59.9 % (124/207) | 63.3 % (131/207) | ≥ 80 % | **fail** |

- The default build gives the same numbers as main `9841a60`, the off run of PR #75 at `a9e6cd4` and the Iteration 3 result after the tuning: with the flag off, the judge's verdicts on the frozen set do not change.
- **Why the rule stays off:** with the rule on, M1 and M3 rise (one more normal rep counted, seven more rejections with the right reason), but M2 falls below its threshold (seven more incorrect reps not rejected), and the supplemental Iteration 4 set (`gymrats_app/test/ai_eval/cases_iter4/`, 16 cases; evaluator in `gymrats_app/test/ai_eval/iter4/`; reports `gymrats_app/test/ai_eval/results/2026-11-18_pr75_fixed_iter4_{on,off}.md`) has no confirmed labels yet, so its M1–M3 are N/A. Sangwoo Hahn's notes add that Hyunwoo's new clips informed the rule, so that set is not a fresh holdout for it (`docs/testing/iteration-4/Sangwoo-Hahn.md`).
- **TODO(hyun-1210):** confirm the per-rep labels of the 16 Iteration 4 cases (record sheets of Hyunwoo and Sangwoo), then re-run both modes and add their M1–M3 here before deciding the default of `PUSHUP_FRAME_KNEE` (Iteration 5).

#### 2026-11-18 · code at commit `a9e6cd4` (the knee-evidence change with main `0a17580` merged in; merged to main as `82113be`) · unified knee rule off and on, and the supplemental Iteration 4 set
The change adds a unified push-up knee rule behind the build flag `PUSHUP_FRAME_KNEE` (default false; [Design Documentation 2.3.2](Design-Documentation#232-rep-judging-on-device-ai-module)) and a separate supplemental set. Both modes were run on the same code; the frozen set of 5.1 and its scorer are unchanged.

| Metric (frozen 32 cases) | Rule off (default build) | Rule on (`PUSHUP_FRAME_KNEE=true`) | Threshold | Result (off / on) |
|---|---|---|---|---|
| M1 Count accuracy | 79.4 % (50/63) | 81.0 % (51/63) | ≥ 90 % | **fail** / **fail** |
| M2 Rejection rate | 90.8 % (188/207) | 87.4 % (181/207) | ≥ 90 % | pass / **fail** |
| M3 Right reason | 59.9 % (124/207) | 63.3 % (131/207) | ≥ 80 % | **fail** / **fail** |

Off gives the same numbers as main. On raises M1 and M3 but lowers M2 below the threshold. Per person M1 off → on: HS 87.5 → 87.5 %, HSW 81.8 → 72.7 %, JP 90.5 → 85.7 %, SWH 53.3 → 73.3 %; M2: HS 98.3 → 91.7 %, HSW 79.3 → 93.1 %, JP 79.7 → 72.9 %, SWH 100 → 94.9 %. Per position M3 B 68.7 → 82.1 %, the other positions within 3 points. In both modes 5 judged reps have no labelled partner (all rejected). The default build keeps the rule off.

**Supplemental Iteration 4 set** (`gymrats_app/test/ai_eval/cases_iter4/{hyunwoo,sangwoo}/`, kept apart from the frozen set): 16 coordinate-only cases recorded on 2026-11-18, Hyunwoo 8 and Sangwoo 8, each with four push-up cases (normal, knees, bent arms, belly) and four squat cases (normal, shallow, not standing up, chair); 5,325 native ML Kit frames with the capture hashes, no video, images or camera frames. The squat cases are replayed through `SquatRepJudge`, as in both battle modes; a chair squat is labelled by depth and standing like any squat (`chairPolicy: range_only`). All 16 labels are still pending (`label.status=pending`), so **M1–M3 are N/A in both modes** (0 confirmed, 16 pending); the judge's predictions are listed as unscored diagnostics, not as labels or results. Each recorder's record sheet is in the set's folder.

Run by Sangwoo Hahn on 2026-11-18 (a report for each mode and the paired JSON in the results folder of the evaluation set, named by the date). Commands, from `gymrats_app/`:
```
flutter test --no-pub --dart-define=PUSHUP_FRAME_KNEE=false test/ai_eval/iter4
flutter test --no-pub --dart-define=PUSHUP_FRAME_KNEE=true test/ai_eval/iter4
```
and, from the repository root, the check of the set against its manifest (no video needed):
```
python tools/diagnose/import_iter4_video_cases.py --verify-only --output gymrats_app/test/ai_eval/cases_iter4
```
Evaluator tests: 13 passed with the rule off and 13 with it on. Next: the recorders or the PM confirm the actual counts and per-rep labels on the record sheets, the labels go into the case files (`--refresh-manifest`), and both modes are run again before the default is decided.

#### 2026-11-18 · code at commit `9841a60` · AI module evaluation, Iteration 4 re-run on main (frozen set unchanged)
Re-run of the frozen set (5.1) on main after PR #74. The 32 cases, 270 labelled reps and the thresholds are unchanged: no commit since the freeze at `dccd84a` touches the cases folder. Command, from `gymrats_app/`: `flutter pub get`, then `flutter test test/ai_eval/ai_eval_test.dart` (1 test passed; report printed and written to `build/ai_eval/report.md`). The PM ran it on 2026-11-18 (Windows, Flutter 3.47.5 / Dart 3.13.4; ML Kit pose detection 0.16.1, `accurate` model, the rep judge's default configuration at the commit). The replay is deterministic, so any machine gives the same numbers.

| Metric | Iteration 3 after the tuning (`269eba7`) | Iteration 4 main (`9841a60`) | Threshold | Result |
|---|---|---|---|---|
| M1 Count accuracy | 79.4 % (50/63) | 79.4 % (50/63) | ≥ 90 % | **fail** |
| M2 Rejection rate | 90.8 % (188/207) | 90.8 % (188/207) | ≥ 90 % | pass |
| M3 Right reason | 59.9 % (124/207) | 59.9 % (124/207) | ≥ 80 % | **fail** |

- **Setting changes since `269eba7`:** the push-up judge pull request S1 (#69, merged 2026-11-16) changed the default judge. The first top hold before counting is 250 ms instead of 300 ms, with 300 ms kept for clearing a knee latch. A span calibration was added, and it never promotes a rep below the configured lockout. Two opt-in models (`PUSHUP_MLP`, `PUSHUP_KNEE_FOREST`) and the person continuity warning (#72, `S2_PERSON_GUARD`) are compile-time flags that are off by default, so this run does not use them. Sangwoo Hahn's notes report the same M1/M2/M3 on the frozen set before and after each S1 change (`docs/testing/iteration-4/Sangwoo-Hahn.md`). This run confirms the numbers on main.
- **Failure analysis:** unchanged from the 2026-11-03 run below. The open items of 5.3 are still open: the set 4 lock-out reason, the `armsStraight` reason of set 8, belly-down reps that are counted, and the normal reps of SWH set 7. Sangwoo Hahn's S1 work also measured the judge on a larger set of recorded videos with labels the agent proposed. Those numbers are not part of this plan (5.1): the labels were not adjudicated by people, and the set was not frozen before the run. They are reported in his notes and the push-up benchmark reports under `docs/iteration-4/`, not here.
- **Pull request #75, then open:** an earlier version (push-up knee endpoint rule, on by default; `b15bb3a`) scored M1 77.8 % (49/63) on the frozen set in its PR body, one more false rejection in JP's set 1 normal recording, with M2 and M3 unchanged. It was revised before the merge; the final version and the final re-run (schedule P20) are the `7680df6` entry above.

#### 2026-11-03 · code at commit `269eba7` · AI module evaluation, re-run after the push-up judge tuning of 2026-11-03 (tuned on the same set)
The four judge changes of that tuning (5.3) were chosen from these same 32 recordings, so this run is **in-sample**; it is reported beside the first run, not instead of it, and a check on new recordings at other phone angles is Iteration 4 work. Full report: in the results folder of the evaluation set (file named by the date and the commit); Hyunwoo's own run before the merge gave the same numbers.

| Metric | First run (`dccd84a`) | After the tuning (`269eba7`) | Threshold | Result |
|---|---|---|---|---|
| M1 Count accuracy | 46.0 % (29/63) | 79.4 % (50/63) | ≥ 90 % | **fail** |
| M2 Rejection rate | 91.3 % (189/207) | 90.8 % (188/207) | ≥ 90 % | pass |
| M3 Right reason | 57.0 % (118/207) | 59.9 % (124/207) | ≥ 80 % | **fail** |

Per person M1: JP 14.3 → 90 %, SWH 20 → 53 %, HS 87.5 → 88 %, HSW 81.8 → 82 %. Per set: set 1 M1 63.3 → 86.7 %, set 7 34.5 → 75.9 %, set 4 M1 0 → 50 % and M3 9.4 → 34.4 %, sets 2, 3 and 5 unchanged (set 2 M3 100 → 94.3 %), set 6 (belly down) unchanged at M2 62.9 %. Cost on the 12 earlier push-up fixtures: 3 cheat reps now count (two head nods, one bow). Still open: belly-down reps (13 of 35 counted, phone angle suspected), the lower-body jitter of SWH set 7, the set 4 and set 8 reasons.

#### 2026-11-03 · code at commit `dccd84a` · AI module evaluation, first run on main (the evaluation set merged)
Re-run on main right after the merge (full report with the per-set and per-case tables in the results folder of the evaluation set). The numbers are identical to the first run below, as the judge code did not change between `e6b16fe` and `dccd84a`, and to Hyunwoo's independent run during the review of the evaluation set.

### First run · 2026-11-03 · before the merge (labels at `08bd2e9`, judge code = main `e6b16fe`)

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

The recordings were used twice: the first 12 sets (10-26 ~ 10-27, the earlier push-up fixtures replayed by the error-case test) drove the judge fix of 10-31 (#22 below) before the set was frozen, and the frozen 32-case set (5.1) measured the result and set the thresholds of the battle game. Changes made from the recordings, in order:

| Date / PR | What the recordings showed | What changed in the app |
|---|---|---|
| 10-31 · #22 (Hyunwoo) | The `base` pose model read a straight plank's hip at 127–139°, so normal reps were rejected as knees down | Pose model `base` → `accurate`; 23–25 fps instead of 27 on the test phone, above the 15 fps requirement |
| 10-31 · #22 | A head nod with the shoulders still up reached the depth line | A bottom now also needs the shoulders at least 0.68 shoulder widths below the top pose (`RepJudgeConfig.minShoulderDrop`); a nod alone is "Go lower" |
| 10-31 · #22 | The "hip angle below 110°" rule fired on normal reps and missed a kneeling bow | That rule removed; new knee rules for a kneeling bow (hips behind the hands, `bowHipHandGap`, `bowTorsoDrop`, `bowHipRise`) and for shins lifted at the top (`maxShinLiftGap`) |
| 10-31 · #22 | Belly-down reps were caught only by the hip height, which a shallow normal rep also hits | `bellyDown` now also needs the torso sagged at least 1.1 (`minBellyTorsoDrop`) |
| 10-31 · #22 | At 100 cm (positions C and D) the setup refused a good plank: the top of a plank read 1.05–1.22 (one rep 1.54) against the 1.0 line | Setup `maxPushUpTorsoDrop` 1.0 → 1.5 in the setup checker, so a far placement can start; 8 cases the judge still gets wrong are kept as known errors in the replay test and listed in the push-up error-case notes (`docs/iteration-3/pushup-error-cases.md`) |
| 10-31 · #20 (Woohyun) | Normal push-ups in the test recordings reached a depth of about 1.4–1.9 shoulder widths (notes in the rep judge configuration) | Excellent needs `maxDepth ≥ 1.6 × passDepth` (push-up 1.76), so only the deepest reps earn 15 points; the first proposal of 1.2 × would have made almost every normal rep Excellent. Good stays 10 |
| 11-01 · #23 (Woohyun) | Elbow angles measured on the recordings: a normal rep that was rejected for depth 90–91°; honest but tired shallow reps 110–126°; the half-rep-with-head-nod cheat 109–135° (team recording `20261027-142000_halfRepHeadNod` 127.8–145.2°); straight arms with a head dip 169–175° | A rep rejected only for depth earns Average +5 when `minElbowAngle ≤ 120°`; the line was raised from 105° after a phone test showed almost no Average at 105°. 120° is a compromise that misses some tired reps (121–126°) and pays some cheats (109–120°) |
| 11-03 · #32 (Hyunwoo) | From 5.2: one tester's normal reps bent the elbows to 68–89° while the head went down only 1.03–1.34 and the shoulders stayed under the 0.68 line; a single frame under the 155° default latched knees on planks that read 160–162°; with the phone at 79–85° normal reps read a bow gap of −0.74 against the −0.6 line; the arm average let one bent arm hide, so short reps counted | Four judge changes in the rep judge, tuned on the same 32 recordings: a bottom is also reached with the elbows at 100° or less and the head 0.8 down (`deepElbowAngle`); the kneel check before the first plank is off (`defaultKneeHip` 155 → 0; the fold from the personal baseline stays); the bow line moves to −0.9 (`bowHipHandGap`); a rep closes only when the less extended arm reaches 172° (`lockoutArmAngle`). Result on the set: M1 46.0 → 79.4 %, M2 91.3 → 90.8 % (still a pass), M3 57.0 → 59.9 %; per person JP 14 → 90 %, SWH 20 → 53 %, HS 88 %, HSW 82 %; set 4 right reason 9 → 34 %. Cost on the earlier 12 fixtures: 3 cheat reps now count (two head nods, one bow). Not addressed: belly-down reps (13 of 35 still counted, phone angle suspected) and the lower-body jitter of SWH set 7 |
| 11-03 · from 5.2 and Woohyun's analysis | At 100 cm the judge fails most (position C M2 79.7 %, D M3 22.2 %; JP's phone at 79–85° outside the standard; hidden knees reported at likelihood 1.0; loose clothes in the floor's colour) | For the heuristic evaluation and the demo, players wear clothes that show the knees and contrast with the floor, and keep the phone within the standard's 50–100 cm and 60–80° |

What the AI testing leaves to Iteration 4 (judge owner Hyunwoo), after the 11-03 tuning: the set 4 lock-out reason (34 % right), the `armsStraight` reason of set 8 (20 %), belly-down reps counted for two recorders (set 6 M2 62.9 %), the remaining normal reps of SWH set 7 (lower-body coordinates jitter), and a check of that tuning on new recordings at other phone angles, since it was fitted on the same 32 cases. The set is frozen; a judge change is measured by re-running `flutter test test/ai_eval` on the new main commit and adding the run to 5.2.

# 6. Acceptance Testing

*Plan required in Iteration 3; results in Iteration 4.*

Plan written in Iteration 3 (PM, 2026-11-01). The six stories below are marked "UAT key story" in [Requirements & Specifications 5](Requirements-and-Specifications#5-functional-requirements) and are **frozen from 2026-11-06**, the end of Iteration 3 (Requirements guideline: once chosen, they cannot be altered afterwards). Results (pass/fail, date, tester, deviations) are reported in Iteration 4 in 6.4.

## 6.1 How the UAT is run
- **Testers:** each story is run by a team member who did not build the feature under test. In the course's in-class UAT (cycle 1 on 2026-11-16, cycle 2 on 2026-11-23) two testers from other teams run the whole sheet and the team members act as instructors and opponents.
- **Build:** release APK built from main at the commit given in the results. The same build is used for every story.
- **Devices:** Samsung Galaxy S22 and Galaxy S23, the phone on the floor as the setup screen asks, indoors with normal room light. Online stories use both phones on the team server.
- **Accounts:** in the in-class UAT each tester signs up a new account in UAT-6 step 1 and keeps it to the end; the online opponent uses a team test account made for the session. No personal accounts.
- **Both exercises:** every story is run twice, once with push-ups and once with squats, and passes only if both runs pass (Requirements Rev.2.3). The procedures below are written for push-ups; the squat run uses the squat setup (standing 2 to 3 m away, whole body in view), squat reps (sit low enough and stand back up) and the squat rejection reasons (e.g., "Sit lower").
- **Pass rule:** a story passes only if every acceptance criterion passes. Each criterion is recorded as pass or fail with a note. A failure gets a GitHub issue linked from the results.
- **Results table (Iteration 4):** story, criterion, pass/fail, test date, tester, build commit, deviation and issue.

## 6.2 UAT stories

| ID | Story | Requirements section | Criteria under test (push-ups and squats) |
|---|---|---|---|
| UAT-1 | Setting up the phone and pose | 5.3 | 1–3 |
| UAT-2 | Counting only fair reps | 5.4 | 1–3 |
| UAT-3 | Battling an online opponent in real time | 5.2, 5.5 | 5.2-1; 5.5-1–4 |
| UAT-4 | Result and feedback | 5.6 | 1–3 |
| UAT-5 | Game points, the health bar and fever time | 5.8 | 2, 4–6 |
| UAT-6 | Understanding the game through the tutorial | 5.11 (revised 2026-11-15) | 1–4 |

Revised 2026-11-04 after the heuristic evaluation (Requirements Rev.2.3): the separate squat story was removed (squats are tested inside every story), fever time was merged into 5.8 with the game points and the health bar, the opponent avatar that copied the player's movement was dropped from 5.5, and the tutorial story (5.11) came in. Not in the UAT, and free to change: 5.1 account, 5.7 match history, the rules pages, the safety warning, the characters (5.12; cycle 1 also ran two character steps), bot difficulty, settings (5.13) and the danger edge (5.8 criterion 3). The in-class sheet runs the stories in the order a new user meets them: UAT-6, the character steps, UAT-1, UAT-3, UAT-5, UAT-2, UAT-4.

## 6.3 Stories, acceptance criteria, and test procedures

### UAT-1. Setting up the phone and pose
**User story:** As a user exercising at home, I want the app to tell me how to place my phone and myself, so that my reps are counted correctly once the battle starts.

**Acceptance criteria**
1. **Phone placement guide.** Given the pose setup screen is open, when the phone lies too flat or my head, shoulders, elbows, and wrists are not all visible, then the app tells me what to fix (for example, to stand the phone up or which body part is not visible) and does not start.
2. **Pose guide.** Given the phone is placed correctly, when the setup screen shows my camera view, then a body silhouette shows where my head, shoulders and hands should be for the chosen exercise, and the hints tell me how to match it.
3. **Ready and start.** Given the phone is placed correctly and I match the pose guide, when I hold a push-up position with straight arms, then the app marks me ready by itself after a countdown, and the battle starts.

**Test procedure**
1. Fresh install of the build; log in with test account A; tap "AI 1v1", push-up.
2. (AC1) Lay the phone almost flat → check the guide message. Stand it up, then step so the left wrist is out of the frame → check the message names the missing part. Check that no countdown starts in either case.
3. (AC2) Place the phone correctly → check that the silhouette is drawn on the camera view; move to one side → check the hint tells you how to get back into the silhouette.
4. (AC3) Match the silhouette and hold a straight-arm push-up position → check that a countdown runs and the battle starts without any tap.
5. Squat run: repeat steps 2–4 with squat chosen; in step 2 the message names the missing feet or asks to step back, in step 3 the silhouette is a standing figure, in step 4 standing still starts the countdown.

### UAT-2. Counting only fair reps
**User story:** As a beginner, I want only correct push-ups or squats to count and to be told right away why a rep did not count, so that the score is fair and I can fix my form during the battle.

**Acceptance criteria**
1. **Valid rep.** Given a battle is running and I start with straight arms, when I lower my body far enough and push back up until my arms are straight, then my count goes up by one.
2. **Rejected rep.** Given a battle is running, when a rep is too shallow or my knees are on the floor, then the rep is not counted and the reason appears on screen at once.
3. **Phone moved.** Given a battle is running, when the phone tilts or shakes, then reps finished during that time are not counted and the app tells me to hold the phone still.

**Test procedure**
1. Start "1v1 vs AI" with test account A and complete setup.
2. (AC1) Do 5 full push-ups at a normal pace → the count shows 5. A second team member counts by eye at the same time.
3. (AC2) In the next battle do 3 half reps (elbows barely bent), then 3 push-ups with the knees on the floor → the count does not change and a reason appears within about a second of each rep. (A half rep may still add Average game points; the count must not change.)
4. (AC3) In the next battle, have the second person tap the phone so it tilts while you do 2 reps → those reps do not count and the "hold the phone still" message appears.
5. Squat run: repeat steps 2–4 with squat chosen; 5 full squats count 5, 3 quarter squats and 3 reps without standing back up are rejected with a reason each, and a tilted phone drops the reps done meanwhile.

### UAT-3. Battling an online opponent in real time
**User story:** As a user, I want to battle a real person online, starting and ending together and seeing each score right away, so that it feels like a real-time match.

**Acceptance criteria** (5.2 criterion 1; 5.5 criteria 1–4)
1. **Match found.** Given two users tap "온라인 1v1" and choose the same exercise at about the same time, when the app pairs them, then both phones show the match-found screen with both nicknames.
2. **Game elements with a live opponent.** Given an online battle is running, when either player's rep is counted or rejected, then the shared health bar, the grade labels, the fever time and the KO rule apply to both players on both phones within a second, with one clock and one score kept by the server, and no camera video is sent.
3. **Both set up before the start.** Given a match has been found, when one player has not finished the pose setup, then the battle does not start and the ready player sees a waiting note; it starts 3 seconds after both are ready.
4. **Short network drop.** Given an online battle is running, when my connection drops, then the app shows that it is reconnecting while the timer keeps running; if I am not back within 10 seconds, I lose by disconnection.
5. **Leaving the battle.** Given an online battle has started, when I press Back and confirm leaving, then I forfeit and the match is recorded as my loss.

**Test procedure**
1. Phone 1 with test account A, phone 2 with test account B, both on Wi-Fi.
2. (AC1) Both tap "온라인 1v1", push-up, within 5 seconds → both show the match-found screen with "A" and "B".
3. (AC3) Complete setup on phone 1 only → phone 1 shows "준비 완료" and waits; complete setup on phone 2 → both count down 3 seconds and start together.
4. (AC2) B does 3 push-ups, then A does one Excellent rep and one knee rep → within a second both phones show the same scores and the same health-bar position, A's label reads Excellent then the rejection reason, and after 20 s both phones show FEVER ×2. (Privacy check: the protocol sends only rep events and scores; confirm in the battle server's log that no image data arrives.)
5. (AC4) In a new match, turn on airplane mode on phone 1 for 5 seconds, then off → phone 1 shows reconnecting and the battle continues. Next match: keep airplane mode on for 15 seconds → phone 1 loses by disconnection.
6. (AC5) In a new match, press Back on phone 1 and confirm → phone 1's history shows a loss; phone 2 shows a win.
7. Squat run: repeat steps 2–6 with squat chosen on both phones; both are matched in the squat queue and the rest behaves the same.

### UAT-4. Result and feedback
**User story:** As a beginner, I want to see who won and what to fix in my form after each battle, so that I improve next time instead of only counting reps.

**Acceptance criteria**
1. **Result.** Given a battle is running, when the round ends (time up, or a KO), then the app stops counting and shows win, loss, or draw with both final scores.
2. **Form feedback.** Given the result of a push-up battle is shown, when I open the form feedback, then I see my counted and rejected reps, my top form issues each with one tip to fix it, and a per-rep record.
3. **Feedback over time.** Given I have played several battles, when I open the feedback statistics from the History tab and choose all records, this month or this week, then I see my average counted reps, a date–reps graph and how often each form issue occurred in that period.

**Test procedure**
1. Run an "AI 1v1" push-up battle with account A to the end of the 30-second round, mixing 4 valid reps and 2 knee reps.
2. (AC1) Check the result screen shows win, loss, or draw and both scores, and that the count no longer changes when you keep moving.
3. (AC2) Open the form feedback → check it shows 4 counted and 2 rejected reps (with the knee reason), at least one form issue with a tip, and one row per rep.
4. (AC3) Play two more battles on another day if possible; open the statistics from the History tab → "all records" lists the three battles in the graph, "this week" and "this month" narrow it to the battles in that period, and the issue counts match the feedback screens.
5. Squat run: repeat steps 1–4 with a squat battle (4 full squats and 2 shallow ones) → the feedback shows the squat issues with tips and the statistics are listed per exercise.

### UAT-5. Game points, the health bar and fever time
**User story:** As a player, I want every rep to move a shared health bar, a big enough lead to end the battle, and a fever time near the end where my score doubles, so that the battle feels like a game and stays exciting until the last second.

**Acceptance criteria** (5.8 criteria 2 and 4–6)
1. **Graded reps and combo.** Given a battle is running, when I complete a counted rep, then it earns Good 10 points, or Excellent 15 when it went 1.6 times deeper than the pass depth, plus a combo bonus of 5 when it comes within 1.5 s of my previous counted rep, and the label appears at once.
2. **KO.** Given a battle is running, when one player gets 100 points ahead, then the battle ends at once with "K.O." and the leader wins; otherwise the higher score wins at time-up, then the higher counted reps, else a draw.
3. **Fever starts.** Given a battle is running, when the fever time begins at 20 s of the 30-second round, then the screen shows "FEVER ×2" in the chip beside the timer until the round ends.
4. **Double score.** Given fever is on, when I complete a counted rep, then it earns twice the points the same rep earns before fever and the health bar moves toward me accordingly; a rejected rep still earns no points.

**Test procedure**
1. Run an "AI 1v1" push-up battle with account A at the 초보 level.
2. (AC1) Do one normal rep, then one deep rep within 1.5 s → the labels read "GOOD" then "+10", and "EXCELLENT" then "+20" with "2 HIT", and the score rises by 10 and 20.
3. (AC3) Watch the timer, which counts down from 0:30 → "FEVER ×2" is not shown before 0:10, appears in the chip beside the timer at 0:10 (20 s into the round) and stays until the round ends.
4. (AC4) During fever do one normal rep and one knee rep → the score rises by 20 for the normal rep and does not change for the knee rep; the health bar moves toward me once.
5. (AC2) In a new battle at the 초보 level, do fast deep reps until 100 points ahead → the battle ends at once with "K.O." and the result shows a win; in another battle, stop early and wait for time-up → the higher score wins, and the result shows "승리" or "패배" with both final scores ("KO 승리" / "KO 패배" after a KO).
6. Squat run: repeat steps 1–5 with squat chosen; a deep squat earns Excellent, fever and the KO behave the same.

### UAT-6. Understanding the game through the tutorial
**User story:** As a new user, I want a short tutorial that shows how a battle works, from getting ready to the report after it, so that I know what to do before my first battle.

**Acceptance criteria** (5.11; revised 2026-11-15, see the revision history)
1. **Opening the tutorial.** Given I have just signed up, or I tap "?" on Home, when the tutorial opens, then its first page shows that GymMouse is a 1:1 battle with push-ups or squats against a person or a bot, and "완료" on the last page takes me to Home.
2. **A battle and getting ready.** Given I go on from the first page, when I read the push-up pages and then the squat pages, then each exercise starts with a 30-second 1:1 battle and how to get ready: for push-ups, fit the body inside the green line; for squats, stand facing the phone with the whole body visible.
3. **Points and rules.** Given I go on to the rules pages of an exercise, when I read them, then they explain with example screens, in the order they happen in a battle, that every rep pushes the health bar, the grades and their points (Excellent, Good, Average for push-ups only, Fail for 0), the combo (+5 for a Good or better within 1.5 s), the fever time (the last 10 s, points ×2) and the KO (a 100-point lead ends the battle).
4. **After the battle.** Given I reach the last page of an exercise, when I read it, then it shows that a report comes after the battle and that the form feedback is opened from it; the squat pages follow the push-up pages with the squat setup and grades.

**Test procedure**
1. Fresh install of the build; sign up with a new test account → the tutorial opens by itself.
2. (AC1) Check the first page names the 1:1 battle with push-ups or squats against a person or a bot.
3. (AC2) Go on → the push-up pages start with the 30-second 1:1 battle and the green-line setup; later the squat pages start with the standing setup, whole body visible.
4. (AC3) Go through the push-up rules pages → the health bar, Excellent / Good / Average / Fail with their points, the combo, the fever time and the KO each have an example screen, in that order; the squat rules pages have the same order without Average.
5. (AC4) On the last push-up page and the last squat page check the report and form feedback page; tap "완료" → Home.
6. (AC1) Tap "?" on Home → the same tutorial opens again.

## 6.4 Results

### Cycle 1 · 2026-11-16 · in class

**Setup.** The in-class UAT of the course (Week 12): two testers from other teams ran the team's UAT sheet, and the team's other members acted as instructors (opponent phone, counting reps by eye, nudging the phone, timing the airplane mode). The sheet has 37 steps in the order a new user meets them: UAT-6 (tutorial, 6) → choosing a character (2, not a UAT key story) → UAT-1 (6) → UAT-3 (7) → UAT-5 (6) → UAT-2 (7) → UAT-4 (3). Each tester signed up a new account in UAT-6 step 1 and used it to the end; the online opponent was a team member on a team test account. Release build of main with the phone-angle display used by UAT-1 steps 2–3 (TODO(hyun-1210): build commit and the two phones used). The sheet snapshot of cycle 1 is part of the Iteration 4 submission.

**Acceptance rate: 73 of 74 steps accepted (98.6 %).** Tester 1: 37/37; tester 2: 36/37. Mean user satisfaction 4.96 of 5 (4 only on UAT-1 steps 4 and 5; every other step 5).

| Story | Steps | Tester 1 | Tester 2 | Result (pass rule of 6.1) |
|---|---|---|---|---|
| UAT-6 Tutorial (5.11) | 6 | 6/6 | 6/6 | Pass |
| Choosing a character (5.12) | 2 | 2/2 | 2/2 | Pass (not a UAT key story) |
| UAT-1 Phone and pose setup (5.3) | 6 | 6/6 | 5/6 | Not passed: step 4 (AC1) rejected by tester 2, severity 4 |
| UAT-3 Online opponent (5.2, 5.5) | 7 | 7/7 | 7/7 | Pass |
| UAT-5 Points, health bar, fever (5.8) | 6 | 6/6 | 6/6 | Pass |
| UAT-2 Only fair reps count (5.4) | 7 | 7/7 | 7/7 | Pass |
| UAT-4 Result and feedback (5.6) | 3 | 3/3 | 3/3 | Pass |

**Failure analysis.** UAT-1 step 4 (left wrist out of the frame, "squat: feet out of the frame"): tester 2 ran it as a squat with the wrist out of view; the squat setup does not need the wrists, so no message named the wrist. The step put the squat variant in brackets inside one row, so the failure comes from the test data, not from the app; the push-up run of the same step passed for tester 1. Cycle 2 splits the step into a push-up row (wrist) and a squat row (feet). The pass rule still counts it as a failed criterion, so UAT-1 is re-run in cycle 2.

**Comments and what we change** (testers' comments and the instructors' notes):

| Where | Comment | Planned change (Iteration 5) |
|---|---|---|
| UAT-1 step 5 | The round starts as soon as the body touches the silhouette for about half a second; the team also saw a start with the body outside it | Hold time before ready, stricter silhouette match |
| UAT-1 step 5 | Close to the phone the hands must be placed narrower than the tester likes | Wider hand tolerance at short distance |
| UAT-1 step 4 | "Hand not visible" and "hand and elbow not visible" switch quickly and are hard to read | Keep one message on screen for a minimum time |
| UAT-1 step 2 | "Stand the phone up more" does not say how far | Show the target angle |
| UAT-4 step 1, team | Squats are played far from the phone, so the feedback text is hard to read; detection was weaker in a crowded room | Larger text, a green or red frame, clearer hip and knee lines; the person-behind work (S2) |
| UAT-6 step 6 | The push-up pages run straight into the squat pages; the tutorial feels a little long | A "skip to squats" step, shorter pages; a clothing note |
| Overall | The label shown when the opponent leaves and the match is canceled is unclear | Clearer wording |

Praised: the characters, the clean design, and the battles being fun even when tiring; one tester called the app ready for release.

### Cycle 2 plan · in class, 2026-11-23

**Sheet.** [UAT Sheet Cycle 2 - Team 4](https://docs.google.com/spreadsheets/d/1x-RXtnCsDLVsYi-UrnAuJU98N_7t15n-AViAkvhFHOU/edit), on the Galaxy S22 and S23. The acceptance criteria of 6.3 are unchanged; only the order and the split of the steps change. The steps follow the user's flow, grouped by what the tester does, and each row names the story it tests:

| Group | What the tester does | Steps | Stories tested |
|---|---|---|---|
| A | The tutorial after sign-up | 3 (A1–A3) | UAT-6 |
| B | An AI push-up battle: setup, reps, points, fever, result and form feedback | 11 (B1–B11) | UAT-1, UAT-2, UAT-5, UAT-4 |
| C | A second AI push-up battle: phone tilt, then a KO | 2 (C1–C2) | UAT-2, UAT-5 |
| D | An AI squat battle: setup, then reps | 4 (D1–D4) | UAT-1, UAT-2 |
| E | Two online battles on two phones: match, both ready, live scores, a short drop, the opponent leaving, a long drop | 7 (E1–E7) | UAT-3 |
| F | The statistics in 기록보관소 (a test account prepared with battles of this week, this month and last month) | 1 (F1) | UAT-4 |
| **All** | | **28 steps, 5 battles, about 40 minutes** | |

* **Cycle 1 failure.** UAT-1 step 4 of cycle 1 is split into a push-up row (B3: the left wrist out of the frame) and a squat row (D1: the feet out of the frame), so each exercise is tested with the body part its setup needs.
* **Setup cue in the expected results.** The rows that check the setup name the short cue and the frame of [Requirements 5.3](Requirements-and-Specifications#53-setting-up-the-phone-and-pose) criterion 5: B1 "폰을 더 / 세워요" with a red frame, B3 "손이 / 안 보여요", B4 a green frame and "그대로 / 멈춰요" with a hold bar, D1 "발목이 / 안 보여요", and D2 the cue and the frame color readable from where the tester stands.
* **Results** are still counted per story with the pass rule of 6.1 (a story passes only if every row that tests it passes), and are reported here after the session.

### Cycle 2 · 2026-11-23

To be completed in Iteration 5 (in class).

# 7. Alpha & Beta Testing

*Required in Iteration 5 (plan, execution and results).*

To be completed in Iteration 5.
