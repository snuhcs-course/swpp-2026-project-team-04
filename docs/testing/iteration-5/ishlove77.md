# Testing notes – Iteration 5 – Jinyoung Park (ishlove77, Worker)

Per-push Results for Jinyoung Park's Iteration 5 steps, in the Testing Documentation format. The PM merges these
notes into `docs/testing/Testing-Documentation.md`.

## Results

#### 2026-11-28 · step P21 `feat/iter5-failover` (PR #114): fix for the Codex review of `a724bf4`
Fix at commit `a05099e`.
- **Finding (P1):** the `migrate` command added in the previous round had no working directory and no environment,
  so Django would stop on the missing secrets. Step 3 now runs it as `jinyoung` from `/srv/gymrats/backend` with
  `/srv/gymrats/.env` loaded in that shell only, after the write check; it also checks `DATABASE_URL` (without it
  Django falls back to an empty database) and that the service users are in `gymrats`. Reviewer subagent: APPROVE
  (3 Minor applied). Documentation only; no code or test change.
- **Results:** unchanged (server `pytest` 372 passed, 98%).

#### 2026-11-28 · step P21 `feat/iter5-failover` (PR #114): fix for the Codex review of `17dbf12`
Fix at commit `ed5f1be`.
- **Finding (P1):** a restored database not writable by the API user (`jinyoung`) would pass `/health`, which does
  not touch the database, and fail later on writes. The procedure (5, steps 3–4) now gives the owner and modes read
  from production (`/srv/gymrats/data` 2775, `gymrats.db` 644, both `jinyoung:gymrats`), checks them with
  `sudo -u jinyoung test -w`, runs `migrate` as `jinyoung`, and logs in and reads history on the machine before the
  IP moves. Reviewer subagent: APPROVE (2 Minor applied). Documentation only; no code or test change.
- **Results:** unchanged (server `pytest` 372 passed, 98%).

#### 2026-11-28 · step P21 `feat/iter5-failover` (PR #114): fixes for the Codex review of `fab012b`
Fix at commit `25139d3`.
- **Findings (P1 ×2):** (1) a replacement from a snapshot older than the last deploy kept the old code, so `migrate`
  saw only the old migrations; (2) a fresh replacement had no IP certificate, so HTTPS and WSS could not work. The
  procedure (`docs/iteration-5/server-failover.md` 5, steps 2–5, finding 6) now brings the API and battle server to
  the production release before `migrate` and start, lists the base setup of a fresh instance, checks ports 80 and
  443, and issues (fresh) or renews (snapshot; the certificates last about 6 days) the certificate after the IP is
  attached. The reviewer subagent first asked for the fresh-instance nginx setup and the snapshot certificate
  renewal, then approved. Documentation only; no code or test change.
- **Results:** unchanged (server `pytest` 372 passed, 98%).

#### 2026-11-28 · step P21 `feat/iter5-failover` (PR #114): fix for the Codex review of `e4b3411`
Fix at commit `f00735e` (line wrap in the next commit).
- **Finding (P1):** the failover procedure restored the backup on a replacement booted from a snapshot without
  stopping the services first; both start at boot, so the battle server's one-time recovery would run against the
  snapshot's database and a newer backup could bring back `active` battles that are never voided. The procedure
  (`docs/iteration-5/server-failover.md` 5, steps 2–3, and finding 5) now stops both services right after boot and
  restores only with them stopped, and stops them again after any reboot before the start. Documentation only; no code or test change.
- **Results:** unchanged from the entry below (server `pytest` 372 passed, 98%).

#### 2026-11-28 · step P21 `feat/iter5-failover` (team plan #15): restart, backup restore and failover rehearsal
Code at commits `63b5dde` (tests) and `0d2266a` (rehearsal record, `docs/iteration-5/server-failover.md`). Server only;
no app change. Commands from `server/` on macOS (Python 3.12).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| API server | pytest, pytest-django, pytest-cov | 90% | 98% total (1055 statements, 20 missed) | 11/28 | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** server `pytest` 372 passed, 0 failed (5 new in `tests/test_failover.py`, `transaction=True` so SQLite's
  backup API sees committed rows). No app change, so `flutter test` was not rerun.
- **Check that the tests depend on the restore:** with `restore()` turned into a no-op, 4 of the 5 tests fail (the
  integrity test does not restore).
- **Rehearsal (not automated; details in `docs/iteration-5/server-failover.md`):** production API restart healthy
  again through nginx in 0.77 s and battle server in 0.17 s (5 min target); a frozen API in a separate environment detected and
  restarted in 2 min 20 s (3 min target; worst case about 3 min 16 s with a 65 s check period); backup restore with
  `migrate` to both services healthy in 2.15 s, restored data time 05:29:15 UTC; history, sign-up and login,
  matching, result saving and the void of a battle cut by a crash checked on it. Static IP failover not run (Lightsail
  console is admin-only).
- **Shortfalls:** none in coverage. The 30 min failover target is not verified (above).

| Test file | Layer | Cases |
|---|---|---|
| `server/tests/test_failover.py` | Server | a backup of the live database passes the integrity check; a restore brings back the backup and drops what came after; after a restore an existing account logs in with its old password and reads its history; a new account signs up and a result is saved; a battle running at the backup comes back active and the restart voids it with no history rows |

#### 2026-11-28 · step P20 `feat/iter5-matching-load` (PR #111): fixes for the Codex review of `bd2e5f3`
Code at commit `d691e47`.
- **Findings:** (1) the test server's skill table had no records for the bots, so every bot used the average estimate
  and every simulated opponent copied the same account; (2) the bots waited 10 s for an upgrade, the app 8 s. The
  bots are now in the table under the ids the run gives them (`--bots`), the report counts the accounts the simulated
  opponents copied, and the connect timeout defaults to 8 s.
- **Tests:** `bot ids are the same in the run and in the skill table`, `each bot in the table has its own estimate,
  not the average`, `simulated opponents copy accounts near each bot's own estimate` (with no bots in the table it
  finds 1 account and fails), and the default timeout in `defaults are the documented 200-user scenario`.
- **Rerun:** S3 on the Mac with the bots in the table: 600/600 battles, 0 server errors, 556 simulated opponents
  copying 24 accounts. The other runs had at most 2 simulated battles and were not rerun (see the results document).
- **Results:** `flutter analyze` no issues; tool tests 29 passed, 0 failed. No app or Python change.

#### 2026-11-28 · step P20 `feat/iter5-matching-load` (PR #111): fixes for the Codex review of `0ea34e2`
Code at commit `2ef4630`.
- **Findings:** (P1) an upgrade finishing after the connect timeout stayed open on the server, uncounted; (P2) a bot
  stopped before or while connecting could still open a socket and keep it; (P2) the load client ignored unknown
  options, so a typo ran the defaults. The late socket is now closed, a stopped bot closes what opened and counts as
  connect error `stopped`, and unknown options are refused. Reported results are unaffected (every reported run had
  0 connect errors and no stop).
- **Tests:** `an unknown option is refused, not run with the defaults`, `an upgrade that finishes after the connect
  timeout is closed`, `a bot stopped while connecting closes the socket and counts no connection`, `a bot whose turn
  comes after the stop time never connects`; all four fail on `0ea34e2` and pass now.
- **Results:** `flutter analyze` no issues; tool tests 26 passed, 0 failed. No app or Python change (last full runs:
  `flutter test` 5406 passed, 10 skipped; `pytest` 367 passed; bench 6 passed).

#### 2026-11-28 · step P20 `feat/iter5-matching-load` (team plan #12): matchmaking benchmark and load test
Load test tools in `server/benchmarks/matchmaking/` and the results in `docs/iteration-5/matchmaking-load.md` (raw
numbers: `results-2026-11-28.json`). No app or server code changed. Commands from `gymrats_app/` and `server/` on
macOS (Flutter 3.47.5 / Dart 3.13.4, Python 3.12.15) on code commit `db5948c` (base `main` `7bc473c`).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model / ViewModel / Service / View | flutter_test | 90 / 90 / 85 / 75% | not affected (no app change) | 11/28 | – |
| API server | pytest, pytest-django, pytest-cov | 90% | not affected (no change in `accounts`, `matches`, `gymrats`); the bench script `skills_endpoint_bench.py` 99% | 11/28 | `.venv/bin/python -m pytest benchmarks/matchmaking --cov=benchmarks/matchmaking` |
| Load test tools (Dart, `server/benchmarks/matchmaking/`) | flutter_test, the real `BattleServer` on loopback, a scripted WebSocket server | – | not measured | 11/28 | `flutter test ../server/benchmarks/matchmaking/matchmaking_load_test.dart` |

- **Tests:** `flutter analyze` no issues. `flutter test` 5406 passed, 0 failed, 10 skipped (the existing opt-in live
  server and device checks). The tool tests are outside `gymrats_app/test`, so plain `flutter test` and CI do not
  run them: `flutter test ../server/benchmarks/matchmaking/matchmaking_load_test.dart` 22 passed (4 runs, stable).
  Server `pytest` 367 passed, 0 failed; `pytest benchmarks/matchmaking` 6 passed (outside `testpaths`, run by path).
- **Coverage notes:** the Dart tool files are outside the app package, so `flutter test --coverage` writes no lcov
  for them (`--coverage-package` matches package names only), the same as `server/lib/battle_server.dart`. They are
  covered by behavior: every outcome the report counts (finished, timeout while queued and in a match, stopped,
  void on server stop, closed by the server, refused token), the clock offset, the error tally, the statistics and
  the arguments. `dart analyze` on the test file reports only the unresolved `package:flutter_test` (no pubspec in
  that folder).
- **Fail-first checks:** `every server error is counted, one without a code as unknown, …` and `reps follow the
  server clock from clock.sync` failed on the code before the reviewer's fixes and pass now.
- **Load test results (measured, no target set in advance):** 200 users × 3 battles on the Mac and on the team
  server: 600/600 battles finished, 0 server errors, 0 sockets closed by the server; real-opponent wait p50 2–3 ms,
  p99 1.6–1.7 s. 200 at once and 1000 users: all battles finished. Full tables in the results document.
- **Shortfalls:** none against a target. Two team-server attempts were discarded (an SSH tunnel limit, then a run
  against a server left from that attempt); both are described in the results document.

| Test file | Layer | Cases |
|---|---|---|
| `server/benchmarks/matchmaking/matchmaking_load_test.dart` | Tool (load test) | nearest-rank percentiles, single value, empty sample, range errors, histogram edges and labels, summary, tallies; default and parsed arguments, bad arguments; synthetic skills; index bench row; real and simulated pairing, poses to the opponent, rounds in order, refused token, timeout while queued, timeout in a match, stop, server stop; clock offset and error tally against a scripted server |
| `server/benchmarks/matchmaking/test_skills_endpoint_bench.py` | Tool (server bench) | fill sizes, refill replaces, timing reports every account, one row per size, a database on disk refused before deleting, the environment forced to the in-memory database |

#### 2026-11-28 · step P11 `feat/iter5-weekly-rankings` (PR #108): fix for the Codex review of `76fa05c`
Code at commit `00cc5f6`.
- **Finding (P2):** a read asked just before Monday 00:00 KST and answered after it kept last week, with no timer
  left. The view model now remembers when it asked; if the week ended while the read was on, it reads once more. An
  old week asked for after its end (the phone's clock ahead) is kept, so it never loops.
- **Tests:** `a read that crosses the end of the week reads the new one` (fails without the fix), `an old week again
  after that is kept, read only twice`.
- **Results:** `flutter analyze` no issues; `flutter test` 5336 passed, 0 failed, 10 skipped. No server change.

#### 2026-11-28 · step P11 `feat/iter5-weekly-rankings` (PR #108): fix for the Codex review of `31dc5ce`
Code at commit `cb4107b`.
- **Finding (P2):** a kept ranking was shown for good when the screen stayed open past Monday 00:00 KST. The view
  model now drops kept rankings whose week has ended when a tab is chosen, reads the shown one again at the week's
  end (a timer, not set when the week is already over by the phone's clock) and when the app comes back to the
  front. The view model takes the clock, so the tests no longer depend on today's date.
- **Tests:** view model `coming back after it reads the shown ranking again`, `a tab kept from the old week is read
  again when chosen`, `the open screen reads again at the end of the week`, `a week already over by the phone's clock
  is not read on and on`, `a timer that fires early by the clock waits again`, `a kept tab shown again still reads
  at the end of the week`, `dispose stops the end-of-week read`; screen `back from the background in a new week, it
  reads again`. Each new test failed with its part of the fix taken out.
- **Results:** `flutter analyze` no issues; `flutter test` 5334 passed, 0 failed, 10 skipped; weekly_rankings_viewmodel
  100%, weekly_rankings_screen 100%. No server change (367 passed).

#### 2026-11-28 · step P11 `feat/iter5-weekly-rankings` (PR #108): fixes for the Codex review of `ae1e9c7`
Code at commits `a7d6135` (legacy kind) and `d4bc830` (database ranking).
- **Finding 1 (P2, unknown kind counted as main):** a result without `kind` (an older battle server) and every row
  stored before migration 0004 were `main`, so a friend battle could score. They are now `legacy` and never score.
  Tests: `test_a_result_without_a_kind_is_kept_as_legacy`, `test_a_battle_of_unknown_kind_does_not_count` (the
  rankings test helper now sends `kind: main` by default).
- **Finding 2 (P2, every row loaded in Python):** the database now picks the scoring rows, sums the points, ranks
  with a window function and returns the top 50 only; my own row's rank is a count. Test:
  `test_the_global_ranking_reads_a_fixed_number_of_queries` (at most 5 queries) and
  `test_a_battle_of_an_id_that_holds_mine_does_not_count` (fails if the id is matched without its quotes). The seeded demo data gives the same
  answer as before. Not done: an index on `Match.played_at` (outside P11's approved paths; PM follow-up).
- **Results:** server `pytest` 367 passed, 0 failed, 98% (`matches/rankings.py` 100%). No app change.

#### 2026-11-28 · step P11 `feat/iter5-weekly-rankings` (PR #108): rankings split by exercise, no stretch past the end
Code at commits `8395855` (server), `5ae5975` (app tabs), `148669d` (stretch fix).
- **Change (user decision, PM approval relayed):** push-ups and squats are ranked apart. The endpoint takes
  `exercise=push_up|squat` (default `push_up`, unknown value 422) and answers with `exercise`. The screen has the
  전체/친구 tabs and under them a 푸쉬업/스쿼트 row; it opens on 전체 · 푸쉬업, and each choice keeps the other.
- **Tests:** server `test_push_ups_and_squats_rank_apart`, `test_friends_rank_each_exercise_apart`,
  `test_without_an_exercise_the_ranking_is_push_ups`, `test_an_unknown_exercise_is_refused`; repository `asks for the
  friends scope of squats by name`, `a reply of an exercise it does not know is a server error`; view model
  `choosing squats reads them in the shown scope and keeps push-ups`, `choosing the shown exercise does nothing`;
  screen `the exercise tabs sit under the scope tabs, push-ups first`, `squats show their own ranking in each scope`.
- **Stretch fix:** the user saw the rows stretch on Android when pulling the list past its end (Android 12 stretch
  overscroll). The list now turns overscroll off; `pulling past the end does not stretch the rows` failed before the
  fix (it found a `StretchingOverscrollIndicator`) and passes now.
- **Results:** `flutter analyze` no issues; `flutter test` 5326 passed, 0 failed, 10 skipped. Server `pytest` 364
  passed, 0 failed, 98% (`matches/rankings.py` 100%). Changed files (reviewer's run over the changed tests):
  rankings_repository 100%, weekly_rankings_viewmodel 100%, weekly_rankings_screen 100%.
- **Manual check:** Android emulator, the rankings screen with answers this branch's Django code computed (push-up
  and squat battles seeded): push-ups unchanged (36, 19, …); squats apart (근손실 20 first; 데모 1+1+3 = 5 tied with
  단짝 at 2); the friends tab of squats shows squat points only; pulling past the end of the list no longer stretches
  the rows.

#### 2026-11-28 · step P11 `feat/iter5-weekly-rankings` (team plan #13): weekly global and friends rankings
`GET /api/matches/rankings/weekly?scope=global|friends` sums this week's points (Monday 00:00 KST) from main online
battles stored by the battle server: KO win 10, win 5, draw 3, loss 1, own forfeit or disconnect 0, void 0. Friend
battles are told apart by the new `OnlineBattle.kind`. The online exercise sheet gets a 주간 랭킹 row that opens a
rankings screen with 전체 and 친구 tabs. Commands from `gymrats_app/` and `server/` on macOS (Flutter 3.47.5 /
Dart 3.13.4, Python 3.12) on code commit `5b00ab3` (P11 merged with `origin/main` `32d2106`).

| Component | Frameworks | Target | Actual (P11 files) | Date | Command / Report |
|---|---|---|---|---|---|
| Service | flutter_test, http MockClient | 85% | rankings_repository 100% | 11/28 | `flutter test --coverage <P11 test files>` + `coverage_by_layer.py --files` |
| ViewModel | flutter_test, fakes | 90% | weekly_rankings_viewmodel 100% | 11/28 | same run |
| View | flutter_test (widget) | 75% | weekly_rankings_screen 100%, play_screen 100%, exercise_sheet 97.7% | 11/28 | same run |
| API server | pytest, pytest-django, pytest-cov | 90% | 98% total; matches/rankings.py 100% | 11/28 | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter analyze` no issues. `flutter test` 5320 passed, 0 failed, 10 skipped (the existing opt-in live
  server and device checks). Server `pytest` 360 passed, 0 failed (18 in `test_weekly_rankings.py`, 3 new kind cases
  in `test_results.py`).
- **Coverage notes:** the full per-file run (`coverage_per_file.sh`, 248 files) was too slow on this Mac and was
  stopped after 169 files; coverage was measured over the six P11 test files instead (122 tests). Layer totals for the
  whole app are in the P10 entry below and P11 only adds files at or above the targets. The battle server's
  `kind` field (`server/lib/battle_server.dart`) is outside lcov and covered by `a friend battle is stored as kind
  friend` and the main-battle body check in `battle_result_store_test.dart`.
- **Shortfalls:** none against the targets. `lib/main.dart` wiring of the route is not tested (excluded from
  coverage; `main_test.dart` is outside P11's paths).
- **Manual check:** Android emulator (Medium Phone) with a scratchpad entry point: `GymRatsApp` with
  `ServerRankingsRepository` over a `MockClient` serving answers that this branch's Django code computed on an
  in-memory database from 20 battles posted to `/internal/results`. Totals matched a hand count (10+5+3+1+0 = 19 and
  five more players), the friend battle and last week's battle were left out, ties shared a rank, scrolling kept the
  header fixed, the friends tab showed a 0-point friend, and back returned to the sheet. Not checked: production
  servers, real battles.

| Test file | Layer | Cases |
|---|---|---|
| `server/tests/test_weekly_rankings.py` | Server | points per outcome and end reason, week bounds, sums, leaving, this week only, resent result once, app-saved rows, simulated opponent, friend battle, void and unfinished, a battle I was not in, shared ranks, top 50 with my row apart, friends with 0 points, deleted friend, unknown scope 422, login 401 |
| `server/tests/test_results.py` (updated) | Server | kind kept, no kind is main, unknown kind 422 |
| `test/services/rankings/rankings_repository_test.dart` | Service | request path, scope and token, parsing, no row of mine, unreadable reply, error status, value equality, point constants, in-memory fake |
| `test/viewmodels/weekly_rankings_viewmodel_test.dart` | ViewModel | starts on global, no double read, tab switch with cache, slow scope under its own tab, errors and retry, dispose guard |
| `test/screens/weekly_rankings_screen_test.dart` | View | spinner, list with dates and no rules line, ties, my row fill, friends tab, my row under the list, empty week, only me in friends, error and retry, semantics, 50 rows at text scale 1.6 on 320×640, only rows scroll, short list height, KST week label |
| `test/widgets/exercise_sheet_test.dart` (updated) | View | no title line, the line when given, rankings row only with a target, its place and podium, semantics, small phone |
| `test/screens/play_screen_test.dart` (updated) | View | no "온라인 1v1 · 30초", the rankings row opens the rankings and back returns to the sheet |
| `test/services/online/battle_result_store_test.dart` (updated) | Service (battle server) | `kind` main and friend in the stored body |

#### 2026-11-27 · step P10 `feat/iter5-skill-matching` (PR #102): the simulated player's character
- **Change:** the simulated player no longer always shows the default character. It shows the character the copied
  account last joined with (kept in the battle server's memory), or else a selectable one at random, never RepBot.
- **Tests:** new in `test/services/online/skill_matching_test.dart`: `the simulated player shows a character a person
  may pick`, `it shows the character the copied account last joined with`, `a character no person may pick is not
  copied`.
- **Results:** `flutter analyze` no issues; `flutter test test/services/online/ test/shared/` 215 passed, 1 skipped
  (the opt-in public wss check); `dart compile kernel bin/server.dart` builds. No Django or app change (server 310
  passed, client full run 5033 passed stand).

#### 2026-11-27 · step P10 `feat/iter5-skill-matching` (PR #102): fixes for the PM's review of `71fcdc3`
- **P2 1 (KO length):** a real 9.5 s online KO of 7 reps was left out until the phone's report (time played rounded up
  to 10 s) arrived, and then counted as 21. `SkillsView` now takes a KO's length from the battle server's start and end
  when there is one, and from the phone's report only otherwise.
- **P2 2 (query, also Codex inline 4712457652):** `/internal/skills` loaded every countable row into Python. Countable
  battles are now chosen in the database and cut to the latest `limit` per account and exercise by a window function,
  in one query.
- **Tests (server):** new `test_skills_leaves_out_a_short_online_ko_before_and_after_its_report`,
  `test_skills_prefers_the_battle_servers_length_to_the_phones`,
  `test_skills_reads_only_the_latest_battles_that_count_in_one_query`; all three failed on `71fcdc3`.
- **Results:** server `pytest` 310 passed, 0 failed, 98% (`matches/internal.py` 95%). No Dart or app change, so the
  client numbers of the entry below stand (5033 passed, 10 skipped).

#### 2026-11-27 · step P10 `feat/iter5-skill-matching` (PR #102): the simulated opponent played by the battle server
After the PM's review of `1a164d6` and the user's decisions (10 s wait, KO battles scaled to 30 s, no difference from
a real user), the battle server now plays the simulated opponent as a player of a real match, and the result saver
stores a row for the real player only. The app's own simulated path (match.virtual, AI battle, setup timer) is gone;
the app keeps `accept_virtual`. Commands from `gymrats_app/` and `server/` on macOS (Flutter 3.47.5 / Dart 3.13.4,
Python 3.12); commit = the PR head.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.4% | 11/27 | `coverage_per_file.sh` + `coverage_by_layer.py` |
| ViewModel | flutter_test, fakes | 90% | 98.5% | 11/27 | same run |
| Service | flutter_test, fakes, loopback stand-ins | 85% | 97.6% (online_battle_session 92.4%, battle_protocol 97.9%) | 11/27 | same run |
| View | flutter_test (widget) | 75% | 97.7% | 11/27 | same run |
| API server | pytest, pytest-django, pytest-cov | 90% | 98% (matches/internal.py 95%, matches/serializers.py 100%) | 11/27 | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter analyze` no issues. `flutter test` 4933 passed, 0 failed, 10 skipped (the existing opt-in live
  server and device checks). Server `pytest` 306 passed, 0 failed (22 in `test_skills.py`, 6 new in
  `test_results.py`).
- **Coverage notes:** the per-file runner left out `online_preparation_test`, `social_signup_screen_test`,
  `online_battle_session_test` and `simulated_player_test` (180 s timeouts; they pass in the plain run). The battle
  server files (`server/lib/*.dart`) are outside the Flutter package and not in lcov; they are covered by 25
  server-level tests (`skill_matching_test.dart`), 36 unit tests (`skill_matchmaker_test.dart`,
  `simulated_player_test.dart`) and the existing battle server suites.
- **Shortfalls:** none against the targets.
- **Manual check:** Android emulator (Medium Phone) and Galaxy S23 Ultra over USB, against this branch's Django API
  and battle server run locally with a throwaway database (app endpoints changed only for the run and reverted).
  Emulator, push-up: estimate 9 → MATCH FOUND "테스터 vs 근손실" (no AI tag) after 10 s; the online setup screen with
  "남은 시간" and "상대 · 준비 완료"; after 20 s the online "경기 취소" screen with 다시 매칭; estimate raised to 21 →
  헬창, lowered to 3 → 초보쥐 (database edited between, battle server restarted to reload). Galaxy, squat (played by
  the user): a full battle against the simulated player ended in a KO win, stored as the player's online battle only
  (no row for the copied account). Not checked: two real phones in one match, the production servers.

| Test file | Layer | Cases |
|---|---|---|
| `test/services/online/skill_matching_test.dart` (rewritten) | Service (battle server) | real players paired at once, real player within the wait first, simulated match found with the closest account, it opens setup and gets ready, a full battle ends as a real one with the simulated player marked in the stored result, setup timeout, forfeit, KO by it and by the player (no rep after a KO), reconnect and resume, each player's own match, cancel, disconnect, older app, friend battles, `accept_virtual` checks, an app `OnlineBattleSession` playing it to the end, estimate reads, `loadSkills` |
| `test/services/online/simulated_player_test.dart` (updated) | Service (battle server) | closest account, never the player, average for a new player, RepBot fallback, 1–60 reps, rep plan (count, order, payloads, excellent share, short rounds), sim ids |
| `server/tests/test_results.py` (updated) | Server | a simulated opponent keeps no record (only the player's online row, nickname as opponent), malformed or unmarked simulated players refused, two simulated players refused |
| `server/tests/test_skills.py` (updated) | Server | KO scaled to 30 s, online KO length, KO under 10 s and of unknown length left out, left battles left out, five filled from battles that count, unusable report length, bad limit 422 |
| `test/services/online/online_battle_session_test.dart` (updated) | Service | `accept_virtual` in the main match only |
| `test/shared/battle_protocol_test.dart` (updated) | Service | 10 s wait |

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
