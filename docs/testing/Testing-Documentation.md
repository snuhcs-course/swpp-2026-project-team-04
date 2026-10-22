# Testing Documentation

Source of the wiki page "Testing Documentation" (separate from Design Documentation). Each section has a **Plan** and
**Results**. Plans are commitments: a changed goal keeps the original next to the revision, with the reason in that
iteration's Results. Images live in `docs/images/`.

| Iteration | Newly required | Keep updated |
|---|---|---|
| 2 | Test Responsibility & Schedule; Unit & Integration Testing (plan and first results) | – |
| 3 | AI Module Testing (thresholds and first results); Acceptance Testing (plan) | Unit & Integration |
| 4 | Acceptance Testing (results) | Unit & Integration, AI Module |
| 5 | Alpha & Beta Testing (plan, execution, results) | all of the above |

## 1. Test Responsibility & Schedule (Iteration 2)

### Who
| Component / layer | Owner (writes and maintains its tests) |
|---|---|
| Model (`gymrats_app/lib/models/`) | TODO(team): owner |
| ViewModel (`gymrats_app/lib/viewmodels/`) | TODO(team): owner |
| Service (`gymrats_app/lib/services/`) | TODO(team): owner |
| View (`gymrats_app/lib/screens/`, `lib/widgets/`) | TODO(team): owner |
| API server (`server/`, Django) | Jinyoung Park (match history, feedback storage, P11 saver) |
| Battle server (`server/lib/`, `server/bin/`, Dart) | TODO(team): online-battle owner; P11 additions: Jinyoung Park |

Policy: the author of a feature writes its tests and submits them in the same pull request. A bug fix starts with a
test that fails before the fix.

### When
- Before every pull request and before merging to `main`: `flutter analyze` (no issues), `flutter test` (all pass),
  and the server `pytest` when `server/` changed. These must pass before a PR can be merged.
- Coverage is measured for each PR and at the end of each iteration (Results below).
- TODO(team): CI (GitHub Actions) is not set up; tests run locally before each PR.

## 2. Unit & Integration Testing (Iteration 2)

### Plan

**Frameworks**
| Component | Test framework | Mocking / isolation | Coverage tool |
|---|---|---|---|
| Model, ViewModel, Service (client) | `flutter_test` | hand-written fakes in `gymrats_app/test/support/`, `package:http/testing.dart` `MockClient` | `flutter test --coverage` (lcov) |
| View (screens, widgets) | `flutter_test` widget tests | fake repositories, fake camera / pose estimator | same |
| App flow | widget tests over `GymRatsApp` (`test/*_flow_test.dart`, `test/main_test.dart`) | in-memory repositories | same |
| Battle server (Dart) | `flutter_test` over real loopback sockets (`test/services/online/`) | fake result store, local `HttpServer` | not measured (outside the Flutter package) |
| API server (Django) | `pytest`, `pytest-django` | in-memory SQLite, Django test client | `pytest-cov` |

**Coverage goals by layer (line coverage)**
| Layer | Target | Why |
|---|---|---|
| Model | 90% | plain data and parsing; cheap to test fully |
| ViewModel | 90% | holds the app's logic and state transitions |
| Service | 85% | network and storage error mapping; a few platform calls need a device |
| View | 75% | some widgets wrap platform views (camera preview) that unit tests cannot drive |
| API server | 90% | business rules, auth, and data integrity |

**Scope & exclusions:** `lib/demo/` (manual entry points), `lib/main.dart` wiring (covered by app-flow tests),
generated code, and the device-only parts of `camera_service.dart`, `pose_estimator.dart`, `pose_camera_view.dart`
(their logic is tested through fakes, the device part by manual checks). No test uses the real network, team server,
camera, ML Kit, or secure storage. `test/services/online/public_wss_smoke_test.dart` is a live check against the
team server and is skipped by default.

**Reproducible commands** (Flutter with Dart ^3.13.4, Python 3.12)
```sh
# client
cd gymrats_app
flutter pub get
flutter analyze
flutter test
flutter test --coverage    # one run; if it crashes (flutter_tester segfault), run each test file with
                           # --coverage and merge the lcov files line by line (see Results 2026-10-21)
# per-layer table from coverage/lcov.info: lines under lib/models, lib/viewmodels, lib/services,
# lib/screens + lib/widgets, each counted as hit when any DA line has hits > 0

# server
cd server
python3.12 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats --cov-report=term-missing
```

### Results

#### 2026-10-21 · commit `706694f` · task: match history with feedback (+ online auto ready)
Branch `feat/history_feedback`. Commands as in the Plan; client coverage measured one test file at a time and merged,
because a single `flutter test --coverage` run crashed (flutter_tester segfault) on this machine (Flutter 3.47.5).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 95.8% | 10/21 | per-file `flutter test --coverage`, merged |
| ViewModel | flutter_test, fakes | 90% | 94.4% | 10/21 | same |
| Service | flutter_test, MockClient, fakes | 85% | 91.3% | 10/21 | same |
| View | flutter_test (widget) | 75% | 91.7% | 10/21 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% | 10/21 | `.venv/bin/python -m pytest --cov=...` |
| Battle server (Dart) | flutter_test, loopback sockets | – | not measured | 10/21 | 18 behavior tests in `test/services/online/battle_result_store_test.dart` |

- Tests: `flutter test` 663 passed, 0 failed, 1 skipped (`public_wss_smoke_test`, live team-server check). Server
  `pytest` 74 passed, 0 failed. `flutter analyze`: no issues.
- Left out of the client coverage numbers: none (71 test files; the skipped live check is not run). Total 92.1%. Files no test loads are interfaces or constant-only files (e.g. `lib/services/user/user_repository.dart`, `lib/models/exercise_type.dart`).
- Shortfalls: none against the targets. Gap: the Dart battle server has no line coverage number because it sits
  outside the Flutter package; plan: measure it with `dart test --coverage` once it has its own package.
- Screenshot: TODO(Jinyoung Park): add `docs/images/coverage-2026-10-21.png` of the per-layer table.

Test cases added or changed in this task:
| Layer | File | What it covers |
|---|---|---|
| Server | `server/tests/test_feedback.py` | feedback stored with a bot match, first feedback kept on retry, feedback before/after the match row, another user's feedback 404, invalid and too-large reports, `limit=3`, migration backfill |
| Server | `server/tests/test_results.py` | P11 saver: one row per player per `result_id`, idempotent, forfeit = loss, secret and loopback only, restart voids lost battles, late recover, pre-posted rows overwritten |
| Service | `test/services/online/battle_result_store_test.dart` | battle server stores start/result/void once, restart resume → `match.void`, HTTP store retries, no chunked body |
| Service | `test/services/user/server_user_repository_test.dart` (updated) | upload with feedback, queue keeps feedback, proxy 413, online feedback PUT, list parsing, fetchRecent/fetchFeedback |
| Service | `test/services/feedback/form_summary_test.dart`, `test/services/api/api_client_test.dart` (updated) | summary from findings; proxy error pages classed by status |
| Model | `test/models/feedback_summary_test.dart`, `test/models/match_record_test.dart` (updated) | JSON, row line, stored outcome wins over reps |
| ViewModel | `test/viewmodels/feedback_viewmodel_test.dart`, `home_viewmodel_test.dart` (updated), `battle_viewmodel_test.dart` (updated) | server report, offline phone copy, failures, retry; recent 3 and fallback; report uploaded with the battle |
| View | `test/screens/home_shell_screen_test.dart`, `match_feedback_screen_test.dart`, `home_screen_test.dart`, `history_screen_test.dart`, `online_preparation_test.dart`, `online_lobby_screen_test.dart` (updated), `test/widgets/match_record_card_test.dart` | tabs and back, recent rows, feedback line, stored feedback screen states, online upload and auto ready |

## 3. AI Module Testing (Iteration 3)
To be completed in Iteration 3.

## 4. Acceptance Testing (Iteration 3 plan, Iteration 4 results)
To be completed in Iteration 3.

## 5. Alpha & Beta Testing (Iteration 5)
To be completed in Iteration 5.
