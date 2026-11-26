# Testing notes – Iteration 5 – Jinyoung Park (ishlove77, Worker)

Per-push Results for Jinyoung Park's Iteration 5 steps, in the Testing Documentation format. The PM merges these
notes into `docs/testing/Testing-Documentation.md`.

## Results

#### 2026-11-27 · step P10 `feat/iter5-skill-matching` (PR #102): fix for the Codex review of `6f14022`
- **Finding (P2):** the tie rule compared account ids as strings, so account 10 came before account 2. Fixed in
  `server/lib/skill_matchmaker.dart`: `SkillIndex.compareIds` orders them as numbers (shorter first, then text; the ids
  are integers without leading zeros).
- **Tests:** new `ids compare as numbers: 2 before 10`; the random full-scan test now checks the tie rule with numeric
  ids. Both failed with the string comparison and pass now.
- **Results:** `flutter analyze` no issues; `flutter test` 4938 passed, 0 failed, 10 skipped. Server unchanged
  (293 passed).

#### 2026-11-27 · step P10 `feat/iter5-skill-matching` (PR #102): fix for the Codex review of `22ad600`
- **Finding (P2):** with several accounts at the same estimate just below the player's, `SkillIndex.nearest` took the
  last of them (the largest id), against the documented tie rule (smaller id). Fixed in
  `server/lib/skill_matchmaker.dart`: the lower side now goes to the start of that estimate's block by binary search.
- **Tests:** new `a tie below the skill also goes to the smaller id`; `nearest agrees with a full scan on random data`
  now uses half-step skills (frequent ties) and checks the chosen id against the tie rule. Both failed on `22ad600`
  and pass now.
- **Results:** `flutter analyze` no issues; `flutter test` 4937 passed, 0 failed, 10 skipped. Server unchanged
  (293 passed). Index cost after the fix (three runs, same setup): build 27.0–31.6 ms, 0.50–0.64 µs per lookup.

#### 2026-11-27 · step P10 `feat/iter5-skill-matching` (team plan #6): simulated users and skill-based matchmaking
Real players in the main queue are still paired at once (FIFO). A player whose app sends `accept_virtual` and who
finds no real player within 15 s gets `match.virtual`: a simulated user copying the account whose skill estimate (the
median valid reps of the latest 5 battles per exercise) is closest to theirs, under that account's nickname. The phone
plays it as an AI battle at that pace. The battle server reads the estimates from the new loopback-only
`POST /internal/skills`. Commands from `gymrats_app/` and `server/` on macOS (Flutter 3.47.5 / Dart 3.13.4,
Python 3.12). The commit is the PR head; see the PR for its hash.

| Component | Frameworks | Target | Actual (P10 files) | Date | Command / Report |
|---|---|---|---|---|---|
| Service | flutter_test, fakes, loopback HTTP/WebSocket stand-ins | 85% | bot_matchmaker 100% (13/13), battle_protocol 98.1% (52/53), telemetry_service 88.6% (163/184), online_battle_session 76.2% (400/525, see below) | 11/27 | `coverage_per_file.sh` + `coverage_by_layer.py --files` |
| View | flutter_test (widget) | 75% | online_lobby_screen 95.7% (242/253) | 11/27 | same run |
| All client layers | | | Model 99.4%, ViewModel 98.5%, Service 95.7%, View 97.4%, total 97.2% | 11/27 | `coverage_by_layer.py coverage/lcov.info` |
| API server | pytest, pytest-django, pytest-cov | 90% | 98% total; matches/internal.py 94% | 11/27 | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter analyze` no issues. `flutter test` 4936 passed, 0 failed, 10 skipped (the existing opt-in live server and device checks). Server `pytest` 293 passed, 0 failed
  (15 in `test_skills.py`).
- **Coverage notes:** `online_battle_session.dart` shows 76.2% because its own test file
  (`online_battle_session_test.dart`) hit the per-file runner's 180 s timeout and is not in the numbers; the run also
  left out `ai_eval_test`, two demo tests, `arcade_flow_test`, `online_preparation_test` and
  `social_signup_screen_test` (timeouts, unchanged by P10). The per-file run was taken before the reviewer's round-2
  fixes (malformed `match.virtual`, telemetry line). The new battle server files (`server/lib/skill_matchmaker.dart`,
  `simulated_player.dart`) sit outside the Flutter package and are not reported in lcov; they are covered by 36
  unit tests and 18 server-level tests.
- **Shortfalls:** none against the layer targets.
- **Cost measured for P20** (`skill_matchmaker_test.dart` "measures the build apart from the lookups (P20 setup)",
  `Random(20)`, 10 000 accounts, 10 000 lookups, Apple M4, JIT): build 20.7–32.5 ms, 0.17–0.59 µs per lookup over
  four runs; table in `docs/iteration-5/matchmaking.md`.
- **Manual check:** Android emulator (Medium Phone) against the working-tree Django API and battle server on this Mac
  with a throwaway database (accounts with medians 9, 9, 20 and 4), app endpoints changed only for the run and
  reverted: the online push-up search waited 15 s, then MATCH FOUND showed "테스터 vs 근손실 AI" (the closest
  estimate), the AI battle's pose setup opened, the leave dialog named 근손실, and telemetry stored
  `matching_finished` with `found` for both searches. Not checked: finishing the AI battle (the emulator camera cannot
  pass the pose setup) and two real phones.

| Test file | Layer | Cases |
|---|---|---|
| `server/tests/test_skills.py` | Server | latest five per exercise newest first, accounts with no battle left out, a time tie goes to the newer row, another limit, bad limits refused, only nicknames and reps sent, secret required, closed through the proxy, from another host and without a configured secret, empty list |
| `test/services/online/skill_matchmaker_test.dart` | Service (battle server) | median (odd, even, latest five only, outliers, none), record parsing and malformed records, nearest estimate, never the player themself, ties, nobody to copy, average and default for new players, exercises apart, repeated account, rebuild, nearest equals a full scan on random data, build and lookup cost measured apart |
| `test/services/online/simulated_player_test.dart` | Service (battle server) | copies the closest account by nickname, never the player, new player from the average, RepBot fallback, 1–60 reps, payload without the account id |
| `test/services/online/skill_matching_test.dart` | Service (battle server) | real players paired at once, a real player within the wait taken first, closest account after the wait, assigned once and never paired, joining again, cancel and disconnect get none, older app keeps waiting, friend battles never get one and may not ask, `accept_virtual` type, estimates read at start and refreshed, failed read keeps them, a slow read does not hold up the start, RepBot at the default skill, `HttpResultStore.loadSkills` request, malformed records, error |
| `test/services/online/online_battle_session_test.dart` (updated) | Service | `accept_virtual` only in the main match, `match.virtual` ends the search with the opponent, a malformed one ends it as failed, one after a match is ignored |
| `test/screens/online_lobby_screen_test.dart` (updated) | View | versus screen with the copied nickname tagged AI, AI battle at the copied pace once after the countdown, leaving the versus screen, the search ends as found once (P17), default builder opens the AI battle screen |
| `test/services/matching/bot_matchmaker_test.dart` (updated) | Service | `SimulatedUserPace` range, at least one rep, a planned round makes about that many reps |
| `test/shared/battle_protocol_test.dart` (updated) | Service | 15 s wait, `match.virtual` opponent parsing and malformed payloads |

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (PR #95): fix for the Codex review of `978e092`
One P2 finding was fixed: on the friends page, a 수락 that comes back after another battle (or the exercise sheet) has
opened over the page no longer opens a second lobby; the accepted invite is taken back, so the friend's waiting room
ends at once.

- **Tests:** `flutter analyze` no issues; `flutter test` 4059 passed, 10 skipped; server unchanged (236 passed).
- **Test cases changed:** `test/screens/friends_screen_test.dart` (another battle opened while accepting: no second
  lobby, and the accept is taken back; fails without the fix); `test/viewmodels/friends_viewmodel_test.dart`
  (takeBack cancels an accepted invite, quietly even when it fails and after the page is gone).

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (PR #95): fix for the Codex review of `96e48bc`
One P2 finding was fixed: a banner 수락 whose answer arrives after the app went to the background no longer opens the
waiting room while the app is hidden; the accepted invite is taken back, as when another battle opens meanwhile.

  Only a hidden app (hidden, paused, detached) counts as background: `inactive` (the notification shade, a system
  dialog) keeps the banner and its 수락.
- **Tests:** `flutter analyze` no issues; `flutter test` 4057 passed, 10 skipped; server unchanged (236 passed).
- **Test cases changed:** `test/viewmodels/friends_viewmodel_test.dart` (the app went to the background while
  accepting: nothing opens and the invite is taken back, also after coming back); `test/screens/friends_screen_test.dart`
  (the notification shade (inactive) does not hide it and it keeps reading; "hidden while the app is in the
  background" now checks the alert's state and that reading stops while hidden, because a hidden app draws no frames,
  and the drawn banner after coming back).

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (PR #95): fixes for the Codex review of `888db67`
Three P2 findings were fixed: the one-battle hold now also checks the inviter's other battles; it lasts a whole battle
(2 minutes, since the battle server allows up to 60 s of setup before the 30 s round) and the apps end it as soon as
the waiting room closes after the battle; and an accept that gets no answer (network, timeout, server failure) is
offered again instead of being dropped.

- **Tests:** `flutter analyze` no issues; server `pytest` 236 passed, `accounts/friends_views.py` 100%; the
  two-connection SQLite check (40 rounds) still gives one 200 and one 409 `invite_busy` every round; full
  `flutter test` count in the PR body.
- **Test cases changed:** `server/tests/test_friends.py` (an invite from someone in another battle is busy; the hold
  lasts through a long setup; the battle ending frees the person at once); `test/viewmodels/friends_viewmodel_test.dart`
  (the battle is over: the accepted invite is taken back once; the invite made after the battle was over is taken
  back in any case; finished before any invite takes nothing back; a
  network failure offers the invite again; a refusal is final); `test/screens/online_lobby_screen_test.dart` (paired,
  then the waiting room closes: the accepted invite is taken back).

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (PR #95): one friend battle at a time (PM request)
The last Codex P2 (two invites to one person accepted at once both succeeding) was first left with a reasoned reply;
the PM asked for it to be fixed in this PR. The server now confirms one accept per person: accepting needs no other
invite to that person accepted in the last 35 s (`ACCEPT_HOLD`, one conditional write under a lock on the person;
migration `accounts.0005_friend_invite_accepted_at`). A second accept ends with 409 `invite_busy` and its invite is
cancelled, and a successful accept cancels the person's other open invites, so those inviters' waiting rooms end at
their next 2 s read instead of after 30 s. Leaving the waiting room cancels the accept and frees the person at once.

- **Tests:** `flutter analyze` no issues; server `pytest` 233 passed, `accounts/friends_views.py` 100%, migration 0005
  100%; full `flutter test` count in the commit message and the PR body.
- **Real concurrency on SQLite:** the Django test database has one connection, so a script outside the repo ran the
  real view against a file SQLite database with two threads (two connections) accepting two invites to the same
  person behind a barrier, 40 rounds: every round gave one 200 `accepted`, one 409 `invite_busy`, and exactly one
  accepted invite. Without the retry, the reviewer reproduced the second request failing with "database is locked"
  (HTTP 500); the retry on that lock is covered by `test_an_accept_that_meets_a_database_lock_tries_again_and_is_busy`.
- **Test cases changed:** `server/tests/test_friends.py` (two invites to one person accepted at once: only one counts,
  409 `invite_busy`, no second accepted invite; a second accept from another phone is busy and the other invite is
  cancelled; an invite arriving during a held accept is busy and ends now; leaving frees the person; an old accept no
  longer holds; the accept time is recorded; a database lock is tried again and ends busy; a lock that does not clear
  is an error; an inviter whose invite was just accepted is held too; accepting takes back my own open invite); `test/services/friends/friend_repository_test.dart` (the same rule in
  memory); `test/viewmodels/friends_viewmodel_test.dart` (busy accept message, no newer invite after an accept,
  declined then a newer invite).

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (PR #95): fixes for the sixth Codex review
Two P2 findings from the Codex review of `afae806` were fixed: a friend code must match the shown code exactly, so
extra padding (`헬창#00002`) finds nobody; and a banner 수락 that comes back after another battle (or the friends page)
was opened meanwhile opens nothing and takes the accepted invite back.

- **Tests:** `flutter analyze` no issues; server `pytest` 223 passed, `accounts/friends_views.py` 100%; full
  `flutter test` count in the PR body.
- **Test cases changed:** `server/tests/test_friends.py` (an over-padded tag finds nobody);
  `test/services/friends/friend_repository_test.dart` (the same in memory); `test/viewmodels/friends_viewmodel_test.dart`
  (a battle opened while accepting; hidden and shown again while accepting); `test/screens/friends_screen_test.dart`
  (a battle opened while 수락 is on its way: no friend waiting room over it).

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (PR #95): fixes for the fifth Codex review
Two P2 findings from the Codex review of `72a9faa` were fixed: an invite whose creation returns after the players
were already paired is taken back only if still open (the friend may have accepted it), and a friend code is read
for any nickname sign-up allows, including one with a line break.

- **Tests:** `flutter analyze` no issues; server `pytest` 221 passed, `accounts/friends_views.py` 100%; full
  `flutter test` count in the PR body.
- **Test cases changed:** `test/viewmodels/friends_viewmodel_test.dart` (paired before the invite was made: taken back
  only if still open; the friend accepted it meanwhile: the accept stays; leaving before it was made: plain cancel);
  `server/tests/test_friends.py` (a nickname with a line break can still be added; a pasted code with line breaks
  around it still works);
  `test/services/friends/friend_repository_test.dart` (the same in memory).

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (PR #95): fixes for the fourth Codex review
Two P2 findings from the Codex review of `1f41796` were fixed: the invite banner drops a read that comes back after
a switch of account, so one account's invites never show for another; and the cleanup after two crossed invites met
now asks the server to cancel only an invite that is still open (`{"if_pending": true}` on
`POST /friends/invites/<id>/cancel`), so an invite the friend has just accepted stays accepted.

- **Tests:** `flutter analyze` no issues; server `pytest` 217 passed, `accounts/friends_views.py` 100%; full
  `flutter test` count in the PR body.
- **Test cases changed:** `server/tests/test_friends.py` (cancel if pending leaves an accepted invite, takes back an
  open one, only `true` turns it on, an odd answer body is ignored); `test/services/friends/friend_repository_test.dart` (`if_pending` in the request,
  in-memory refusal); `test/viewmodels/friends_viewmodel_test.dart` (a read after a switch of account is dropped and the new account's read follows at once; the
  pairing cleanup uses `ifPending` and leaves a just-accepted invite).

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (PR #95): fix for the third Codex review
One P2 finding from the Codex review of `851cc40` was fixed: when the account signs out while the invite banner's
수락 is on its way, the late answer no longer opens the waiting room over the signed-out app; the app tries to take the
accepted invite back (without a login the request can fail, and the friend's waiting room then ends within 30 s).

- **Tests:** `flutter analyze` no issues; full `flutter test` count in the PR body; server unchanged (210 passed).
- **Test cases changed:** `test/viewmodels/friends_viewmodel_test.dart` (signed out while accepting: the late answer
  opens nothing and the invite is taken back; signed out and in again while accepting: still dropped; a failed
  accept after a sign-out leaves no error behind);
  `test/screens/friends_screen_test.dart` (signed out while 수락 is on its way: no waiting room opens).

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (PR #95): fixes for the second Codex review
Three P2 findings from the Codex review of `f752b07` were fixed: one open invite per inviter is now kept by the
database (migration `accounts.0004_one_pending_friend_invite`; two invites sent at once from two phones retry, so the
latest is the open one); the 친구와의 대전 row on 게임 시작 re-reads every 5 s while the page is on top, so a request
that comes meanwhile shows its dot; and a friend code needs at least the four tag digits it shows (`헬창#2` finds
nobody).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| API server | pytest, pytest-django, pytest-cov | 90% | 98% total; `accounts/friends_views.py` 100%, migration 0004 100% | 11/24 | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter analyze` no issues; server `pytest` 210 passed; full `flutter test` count in the PR body.
- **Test cases changed:** `server/tests/test_friends.py` (two invites at once leave one open, an invite that keeps
  losing the race gives up with 409, one open invite per inviter in the database, codes with fewer than four digits);
  `test/screens/play_screen_test.dart` (a request that comes while the page is open shows within one refresh, no
  reading while another page is on top, a slow read is not started again on the next tick, no reading while the app
  is in the background); `test/services/friends/friend_repository_test.dart` (short tag refused).

#### 2026-11-24 · step P9 `feat/iter5-friend-battles` (PR #95): fixes for the Codex review
Two P2 findings from the automatic Codex review of `4224bc2` were fixed: every answer to a friend request or a battle
invite is now one conditional write, so of two answers at the same moment (two phones) only one counts; and when two
friends invite each other at once and are paired, each one's still-open invite is taken back, so no stale invite alert
comes after the battle.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| API server | pytest, pytest-django, pytest-cov | 90% | 98% total; `accounts/friends_views.py` 100% | 11/24 | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` |
| ViewModel | flutter_test, fakes | 90% | `friends_viewmodel.dart` unchanged at 100% in the targeted run before this fix; the new `paired()` lines are covered by the four tests below | 11/24 | `flutter test test/viewmodels/friends_viewmodel_test.dart` |

- **Tests:** `flutter analyze` no issues; server `pytest` 204 passed (6 new race tests); the online battle tests
  (`online_battle_integration_test.dart`, `friend_battle_test.dart`) 90 passed on the new battle server, which shows
  the main match without `friend_id` unchanged (PM's request). Full `flutter test`: see the PR body for the head run.
- **Test cases changed:** `server/tests/test_friends.py` (two answers to a request at once, both orders; asking back
  while the request is answered elsewhere; two answers to an invite at once: accept/decline, decline/accept,
  cancel/accept); `test/viewmodels/friends_viewmodel_test.dart` (paired with my invite still open, paired through an
  accepted invite, paired on the invited side, paired just after the friend accepted);
  `test/screens/online_lobby_screen_test.dart` (both invited each other and met: my open invite is taken back).

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
