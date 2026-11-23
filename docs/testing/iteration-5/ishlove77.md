# Testing notes – Iteration 5 – Jinyoung Park (ishlove77, Worker)

Per-push Results for Jinyoung Park's Iteration 5 steps, in the Testing Documentation format. The PM merges these
notes into `docs/testing/Testing-Documentation.md`.

## Results

#### 2026-11-24 · code at commit `6f9ee9c` · step P7 `feat/iter5-google-auth` (PR #93): fixes for the Codex review
Two P1 findings from the automatic Codex review of `81c3fe0` were fixed: the server now fetches Google's keys at most
once per 5 minutes (30 s after a failure, again after 6 hours; malformed answers are 503), and the app ships the public
Google web client id as its default so plain builds have Google sign-in.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Service (app) | flutter_test, fakes | 85% | `google_sign_in_service.dart` 78.9% per file (plugin adapter only, as before); layer for P7 files above target | 11/24 | `flutter test --coverage <P7 test files>` |
| API server | pytest, pytest-django, pytest-cov | 90% | 97% total; `accounts/google_auth.py` 100% | 11/24 | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter analyze` no issues; `flutter test` 3910 passed, 0 failed, 10 skipped (unchanged opt-in checks);
  server `pytest` 157 passed (10 new key-cache tests replace the old key-lookup tests).
- **Shortfalls:** unchanged (the Google plugin adapter, see the entry below).
- **Test cases changed:** `server/tests/test_auth.py` (Google key cache: fetch once, unknown key ids cannot force
  refetches, new key after the interval, retry after a failure, old keys refetched, malformed answers, concurrent
  fetch, key id parsing); `test/services/auth/google_sign_in_service_test.dart` (plain builds use the GymMouse web
  client id).

#### 2026-11-24 · code at commit `35dadd2` · step P7 `feat/iter5-google-auth` (team plan #1): Google sign-in, nickname step, body info
The step adds Google sign-up and login (`POST /auth/google`, ID token checked against Google's keys and
`GOOGLE_CLIENT_IDS`), a nickname step for a new Google account, an optional height and weight step with consent for
every new account (`POST /users/me/body`), and a logout notice that fits accounts without a password. Kakao was built
first and then removed on 2026-11-24 after the PM fixed P7's scope to Google only. Commands from `gymrats_app/` and
`server/` on macOS (Flutter 3.47.5 / Dart 3.13.4, Python 3.12).

| Component | Frameworks | Target | Actual (P7 files) | Date | Command / Report |
|---|---|---|---|---|---|
| ViewModel | flutter_test, fakes | 90% | 99.5% (202/203): auth 97.9%, login 100%, body_info 100%, social_signup 100% | 11/24 | `flutter test --coverage <P7 test files>` |
| Service | flutter_test, MockClient, fakes | 85% | 96.5% (110/114): auth_repository 100%, in_memory_auth_repository 100%, google_sign_in_service 78.9% | 11/24 | same run |
| View | flutter_test (widget) | 75% | 99.6% (277/278): login 98.7%, body_info 100%, social_signup 100%, settings 100% | 11/24 | same run |
| API server | pytest, pytest-django, pytest-cov | 90% | 97% total; accounts/google_auth 100%, serializers 100%, views 99%, models 96% | 11/24 | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter analyze` no issues. `flutter test` 3853 passed, 0 failed, 10 skipped (the existing opt-in live
  server and device checks, unchanged by this step). The P7 test files alone: 164 passed. Server `pytest` 147 passed,
  0 failed.
- **Coverage:** measured on the files this step adds or changes (a full `flutter test --coverage` does not finish on
  this Mac; `coverage_per_file.sh` ran on 11-23 before the Kakao removal and gave the same per-file numbers).
- **Shortfalls:** `lib/services/auth/google_sign_in_service.dart` is 78.9% per file (below the Service 85% target). The
  4 uncovered lines are `PluginGoogleAuthApi`, the thin adapter that calls the real `google_sign_in` plugin, which
  cannot run in a unit test; the service's own logic (cancel, failure codes, missing token, one-time initialize with
  retry) is fully covered through a fake `GoogleAuthApi`. The Service layer as a whole is above target. Plan: covered
  by the manual check on a device.
- **Manual check:** Android emulator (Medium Phone, API 36) against a local Django server on this Mac
  (`10.0.2.2:8000`, outside the repo copy): id and password sign-up shows the body info step and saves it; an existing
  account logs in and sees its records; the login screen shows only the Google button. Google login itself with the
  real client id on a device is pending (OAuth client and test user created 11-24); the PM asked for success, a token
  for another app refused, and existing-account login before merge.

| Test file | Layer | Cases |
|---|---|---|
| `server/tests/test_auth.py` (updated) | Server | Google new account needs a nickname (404, nothing created), create once then log in, password login refused for a Google account, bad nickname, existing account ignores the nickname, tokens refused (audience, issuer, expired, no subject, signature, garbage), unconfigured 503, JWKS key lookup errors, sign-up race, body info with consent, consent and range checks (incl. NaN, Infinity), login required |
| `test/services/auth/google_sign_in_service_test.dart` | Service | ID token, one initialize, no client id, cancel, plugin error codes, no token, retry after failed initialize |
| `test/services/auth/auth_repository_test.dart` (updated) | Service | Google request body with and without nickname, `signup_required`, 401 and 503 mapping, body info request, in-memory accounts and body info |
| `test/viewmodels/auth_viewmodel_test.dart` (updated) | ViewModel | body info step after sign-up and new Google account only, save, skip, expiry |
| `test/viewmodels/login_viewmodel_test.dart` (updated) | ViewModel | Google new account asks for a nickname, existing account logs in, busy state, cancel, each failure message, retry |
| `test/viewmodels/social_signup_viewmodel_test.dart` | ViewModel | trimmed nickname creates the account, nickname rules, failure messages, account made meanwhile, double tap |
| `test/viewmodels/body_info_viewmodel_test.dart` | ViewModel | parsing and ranges, consent required, save, skip, double tap, failures |
| `test/screens/auth_screens_test.dart` (updated) | View | Google button only with the service, nickname route, busy state, failure and retry |
| `test/screens/social_signup_screen_test.dart` | View | nickname form, 가입하기, empty nickname, expired login |
| `test/screens/body_info_screen_test.dart` | View | fields, consent box, 건너뛰기 and one lime 다음, save, errors, small phone |
| `test/screens/settings_screen_test.dart` (updated) | View | logout notice no longer mentions a password |
| `test/auth_flow_test.dart` (updated) | App flow | sign-up → body info → rules → home; new Google account → nickname → body info → rules → home; same Google account later straight home; back out of nickname creates nothing; cancel; session restored after restart |
