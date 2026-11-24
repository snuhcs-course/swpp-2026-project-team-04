# Testing notes – Iteration 5 – Jinyoung Park (ishlove77, Worker)

Per-push Results for Jinyoung Park's Iteration 5 steps, in the Testing Documentation format. The PM merges these
notes into `docs/testing/Testing-Documentation.md`.

## Results

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (team plan #3): friends and friend battles
The step adds friends by friend code (`nickname#tag`, the tag being the account id with at least four digits),
friend requests (`/friends`, `/friends/requests`), friend battle invites open for one minute (`/friends/invites`), a
`friend_id` in the battle server's `queue.join` that pairs only two players who named each other, the 친구와의 대전
page and row on 게임 시작, the friend waiting room in the online lobby, the friend code in 환경설정, and an app-wide
banner for a friend's battle invite. Commands from `gymrats_app/` and `server/` on macOS (Flutter 3.47.5 /
Dart 3.13.4, Python 3.12). The commit is the PR head; see the PR for its hash.

| Component | Frameworks | Target | Actual (P9 files) | Date | Command / Report |
|---|---|---|---|---|---|
| ViewModel | flutter_test, fakes, fake_async | 90% | 100% (194/194): friends_viewmodel | 11/24 | `flutter test --coverage <P9 test files>` |
| Service | flutter_test, MockClient, fakes | 85% | friend_repository 100% (164/164) | 11/24 | same run |
| View | flutter_test (widget) | 75% | friends_screen 98.6% (285/289), play_screen 98.7% (75/76), online_lobby_screen 95.4% (186/195), settings_screen 100% (98/98) | 11/24 | same run |
| API server | pytest, pytest-django, pytest-cov | 90% | 98% total; accounts/friends_views 100%, friends_urls 100%, migration 0003 100%, models 98% | 11/24 | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter analyze` no issues. `flutter test` 4027 passed, 0 failed, 10 skipped (the existing opt-in live
  server and device checks, unchanged by this step). Server `pytest` 198 passed, 0 failed (41 in
  `test_friends.py`).
- **Coverage:** measured on the P9 test files (a full per-file run takes over 10 minutes on this Mac and was stopped
  when the code changed). `online_battle_session.dart` shows 52.8% in this subset because its other paths are covered
  by the existing online tests outside it; P9 added only `friendId`, which is covered. `shared/battle_protocol.dart`
  shows 0% in lcov because the file is loaded twice (by package URI and by the battle server's relative import) and
  the hits are not attributed to the listed path; `isBattleFriendId` is covered by
  `isBattleFriendId takes server player ids only` and the battle server tests.
- **Shortfalls:** none in the P9 files.
- **Manual check:** Android emulator (Medium Phone, API 36) against the working-tree Django API and battle server on
  this Mac (outside the repo copy), with test accounts and a throwaway script outside the repo playing the friend's
  side on the battle server: outgoing request, duplicate request refused, wrong code refused, accept and decline by the
  other side (with the page open and after reopening), incoming request with the dot on 게임 시작 and accept, friend
  battle both ways ending in MATCH FOUND with the friend, leaving before the start cancels it for the friend, and the
  invite banner on home and on 기록보관소 with 거절 and 수락 (수락 opens MATCH FOUND). Not checked: two real phones,
  and the production servers (the friends API and `friend_id` are not deployed; the battle server must be deployed
  before the app).

| Test file | Layer | Cases |
|---|---|---|
| `server/tests/test_friends.py` | Server | friend code (4+ digits), login required, request then accept, duplicate either way, malformed codes, number and nickname both needed, same nicknames told apart, self, decline, accepted not declinable, list order, invite reaches the friend and accept, only friends invited, malformed invites, 1-minute expiry and just inside it, decline and cancel once, either player cancels an accepted invite, a new invite cancels the old, invites private to the two players, no login id or password in the list, only the invited friend accepts, accepting twice accepts once, closed invites not accepted, one request per pair in the database, reverse request race |
| `test/services/online/friend_battle_test.dart` | Service (battle server) | friends who name each other share a room, later join still pairs, never with the main queue, only the named friend, different exercises not paired, friend leaving the queue, leaving before the start cancels, invalid `friend_id` values, joining twice and a second phone make one room, two app sessions meet |
| `test/services/online/online_battle_session_test.dart` (updated) | Service | `friend_id` sent only for a friend battle |
| `test/services/friends/friend_repository_test.dart` | Service | `friendCode`, server overview parsing, unreadable replies, add friend outcomes and refusal codes, request and invite paths, in-memory rules (requests, codes, invites, expiry, accept/decline/cancel) |
| `test/viewmodels/friends_viewmodel_test.dart` | ViewModel | error messages, load and add states, answering requests and invites, wait for an invite (sent, declined, cancelled, expired, accepted but not paired in 30 s, invited side, stop, leave, polling), app-wide alert (signed in only, newest unanswered, accept, ran out, decline, hidden and background, sign-out reset, failed read, double answer, read during an answer, polling) |
| `test/screens/friends_screen_test.dart` | View | my code and copy, add by code, duplicate and wrong code, accept and decline requests, 대결 asks for the exercise, invite accept and decline, ordering, retry, refresh; banner over every page, accept opens the waiting room, decline, ran-out message, hidden on battle routes and the friends page (also under a sheet), replaced routes, background, stops when gone, on the real app's home |
| `test/screens/play_screen_test.dart` (updated) | View | online card goes straight to the exercise, 친구와의 대전 row opens the friends page, dot for a request or an invite, no rule line or play-again row |
| `test/screens/online_lobby_screen_test.dart` (updated) | View | friend waiting room: invite sent, declined, leaving takes it back, invited side, paired stops reading, failed search takes it back, no 다시 매칭, app routes a `FriendBattle` |
| `test/screens/settings_screen_test.dart` (updated) | View | friend code row and copy |
| `test/main_test.dart`, `test/screens/home_screen_test.dart` (updated, exceptions) | App flow / View | expectations of the removed play-again row replaced |

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
