# Matchmaking benchmark and load test (P20)

Owner: ishlove77 · 2026-11-28 · branch `feat/iter5-matching-load` · base `main` `7bc473c` (P10 matchmaking merged)

The task: run a scenario of about 200 concurrent users, with simulated users and skill matching (P10), in a test
environment, and record the build and server settings, the real number of concurrent connections, successes and
failures, the queue-wait distribution and the server errors. 200 is a measurement goal; no pass/fail performance
figure was set in advance, so none is judged here. Raw numbers of every run: `server/benchmarks/matchmaking/results-2026-11-28.json`.

## What was measured

| Part | Tool | What it does |
|---|---|---|
| Load client | `server/benchmarks/matchmaking/load_client.dart` (`load_bot.dart`, `load_run.dart`) | N bots, each a WebSocket client that speaks battle protocol v1 like the app: `clock.sync`; `session.ping` every 5 s; `queue.join` with `accept_virtual: true`; `match.setup` 1–3 s after `match.found` and `match.ready` 1–3 s later; during the round a `pose.frame` every 100 ms (the app's rate, synthetic pose) and 8–25 planned valid reps (+0–2 shallow) as `rep.submit`; after the result a 2–8 s pause, then the next round. It records every round and samples connected / queued / in-match bots each second. |
| Test server | `server/benchmarks/matchmaking/load_server.dart` | The production `BattleServer` class with its defaults (30 s round, 3 s countdown, 10 s simulated-opponent wait, 20 s setup, 50 ms tick, 5-minute skill refresh) on loopback, with development tokens and a synthetic skill table of 1000 accounts (5 battles per exercise, reps around 15) in place of the API server. Nothing is stored (no Django result saver). It samples its event-loop lag every 100 ms and its CPU / resident memory every 5 s. |
| Skill index | `server/benchmarks/matchmaking/skill_index_bench.dart` | P10's `measureSkillIndex`: building the sorted index apart from 10 000 nearest-skill searches, at 100 to 100 000 accounts, median of 5 after a warm-up. |
| Skill read | `server/benchmarks/matchmaking/skills_endpoint_bench.py` | The real `POST /internal/skills` view through Django's test client on an in-memory SQLite database with 100 to 5000 made-up accounts × 20 battles per exercise (P10 review: "the battle server reads every row"). Median of 5 after a warm-up. |

## Build and settings

| Item | Value |
|---|---|
| Machine | S1–S4: Apple M4, 10 cores, 16 GB, macOS 27.2.1. TS1–TS2: the team server (AWS Lightsail, Seoul), 2 vCPU Intel Xeon Platinum 8259CL 2.5 GHz, 1.9 GB RAM, Ubuntu 24.04, next to the live services. **In both, client and server on the same machine over loopback** (no network, no TLS, no nginx). |
| Dart | 3.13.4 (stable). Server and client both AOT-compiled with `dart compile exe` (for the team server cross-compiled on the Mac with `--target-os linux --target-arch x64`), as production builds the battle server (production: Dart 3.13.5, linux-x64, on the team server). The server's mode is in the JSON (`server.compiled`); the client's was added to the client report after these runs, so for them it is a manual note. |
| Battle server | `BattleServer` defaults, as above. `--accounts 1000 --seed 20`. S3 only: `--virtual-after-ms 0`. |
| Authentication | Development tokens `dev:load-NNN:Load NNN` (the API server is not called per connection). |
| Client | `--seed 20`, defaults otherwise (see the table above); the bot ids are `load-001` … |
| Open file limit | `ulimit -n` 1048576 (not a limit here; manual note, not in the JSON). |

## How to reproduce

From the repository root:
```sh
mkdir -p /tmp/p20
dart compile exe server/benchmarks/matchmaking/load_server.dart -o /tmp/p20/load-server
dart compile exe server/benchmarks/matchmaking/load_client.dart -o /tmp/p20/load-client
/tmp/p20/load-server --port 8090 --accounts 1000 --out /tmp/p20/s1-server.json &   # S3: add --virtual-after-ms 0
/tmp/p20/load-client --users 200 --ramp-ms 20000 --rounds 3 --out /tmp/p20/s1-client.json
kill -INT %1                                   # the server writes its report when stopped
# S2: --users 200 --ramp-ms 0 --rounds 1     S4: --users 1000 --ramp-ms 20000 --rounds 1
dart run server/benchmarks/matchmaking/skill_index_bench.dart
cd server && .venv/bin/python benchmarks/matchmaking/skills_endpoint_bench.py
```
For the team server: build both with `--target-os linux --target-arch x64`, copy them to a temporary folder, check that
port 8090 is free (`ss -ltn`), start the server, check that it is running, then start the client in the same SSH
session against `ws://127.0.0.1:8090/ws/v1/battle`, stop the server with
`kill -INT`, copy the JSON back and delete the folder (each step needs the user's OK; see the team server rules).
The client prints the summary lines below and writes the JSON report; timings vary from run to run and machine to
machine, the counts with the same seed and settings should be close but not identical (timers decide who meets whom).

## Scenarios

| ID | Users | Arrivals | Rounds each | Server setting | Why |
|---|---:|---|---:|---|---|
| S1 steady | 200 | one every 100 ms (20 s ramp), then 2–8 s between rounds | 3 | production | the task's scenario |
| S2 burst | 200 | all at once | 1 | production | 200 phones joining in the same second |
| S3 simulated-heavy | 200 | as S1 | 3 | `--virtual-after-ms 0` (not production) | with 200 users online a real opponent is almost always there (S1: 2 of 600 rounds got a simulated one), so this forces the simulated-player path under the same load |
| S4 headroom | 1000 | 20 s ramp | 1 | production | how far beyond 200 the same machine goes |
| TS1, TS2 | 200 | as S1, as S2 | 3, 1 | production | S1 and S2 again on the team server |

## Results (2026-11-28)

| | S1 steady | S2 burst | S3 simulated-heavy | S4 headroom |
|---|---:|---:|---:|---:|
| Bots / connected / connect errors | 200 / 200 / 0 | 200 / 200 / 0 | 200 / 200 / 0 | 1000 / 1000 / 0 |
| Peak connected (1 s samples) | 200 | 200 | 200 | 994 |
| Peak in a match / queued | 198 / 2 | 200 / 2 | 200 / 1 | 994 / 2 |
| Rounds / succeeded / failed | 600 / 600 / 0 | 200 / 200 / 0 | 600 / 600 / 0 | 1000 / 1000 / 0 |
| Ended by KO / time up | 395 / 205 | 128 / 72 | 343 / 257 | 686 / 314 |
| Opponent real / simulated | 598 / 2 | 198 / 2 | 46 / 554 | 1000 / 0 |
| Server `error` messages | 0 | 0 | 0 | 1 (`INVALID_STATE`) |
| Sockets closed by the server | 0 | 0 | 0 | 0 |
| Connect (upgrade) p50 / p99 / max | 1 / 2 / 3 ms | 20 / 35 / 35 ms | 0 / 1 / 2 ms | 0 / 2 / 7 ms |
| Queue wait, all: p50 / p90 / p99 / max | 8 ms / 517 ms / 1.88 s / 10.03 s | 9 / 10 / 11 ms / 10.05 s | 33 / 43 / 50 / 51 ms | 5 / 60 / 122 / 260 ms |
| Queue wait, real opponent: p50 / p99 / max | 2 ms / 1.67 s / 8.35 s | 9 / 11 / 11 ms | 1 / 46 / 46 ms | 5 / 122 / 260 ms |
| `match.found` → `match.start` p50 / p99 / max | 4.47 / 5.80 / 11.70 s | 4.46 / 5.89 / 10.35 s | 9.90 / 12.55 / 12.95 s | 4.43 / 5.77 / 5.92 s |
| `rep.submit` → `rep.accepted` p50 / p99 / max | 0 / 1 / 7 ms | 0 / 1 / 11 ms | 0 / 3 / 6 ms | 1 / 2 / 4 ms |
| Reps sent / acknowledged | 8051 / 8051 | 2753 / 2753 | 8516 / 8516 | 13113 / 13112 |
| Pose frames sent / received from the opponent | 136 637 / 108 875 | 46 287 / 35 920 | 148 166 / 8 469 | 223 210 / 166 656 |
| Server event-loop lag p99 / max | 1 / 8 ms | 1 / 2 ms | 1 / 2 ms | 1 / 2 ms |
| Server CPU, macOS `ps` %cpu (a decaying average, not the 5 s load), mean / max of 5 s samples | 18.4% / 35.3% | 20.7% / 35.7% | 10.4% / 17.8% | 39.5% / 60.5% |
| Server resident memory, max | 44 MB | 57 MB | 81 MB | 82 MB |
| Wall time | 162 s | 48 s | 161 s | 58 s |

Queue-wait histogram (all rounds):

| Bucket | S1 | S2 | S3 | S4 |
|---|---:|---:|---:|---:|
| < 100 ms | 357 | 198 | 600 | 973 |
| 100 ms – 1 s | 223 | 0 | 0 | 27 |
| 1 – 5 s | 16 | 0 | 0 | 0 |
| 5 – 10 s | 2 | 0 | 0 | 0 |
| 10 – 10.5 s | 2 | 2 | 0 | 0 |
| ≥ 10.5 s | 0 | 0 | 0 | 0 |

How to read it:
- Every round that was started finished (600/600, 200/200, 600/600, 1000/1000); no bot failed to connect and the
  server closed no socket. With 200 users online, real players were paired at once (S1 real p50 2 ms); the waits of
  0.1–8 s are bots that joined when no one else of the same exercise was waiting. Only a player still alone after
  10 s got a simulated opponent (the max of "all" is those rounds: the 10 s wait plus up to one 50 ms tick).
- `match.found` → `match.start` is the later of the two players' setup and ready (2–6 s per bot); `match.start` comes
  when both are ready and announces a start 3 s later, so the countdown is not in it. With a simulated opponent it is
  that player's 4–7 s setup and 3–6 s ready (S3 p50 9.90 s), as P10 designed; the S1/S2 maxima (11.70 s, 10.35 s)
  are rounds against a simulated opponent.
- Fewer poses arrive than are sent because the server forwards at most one frame per 100 ms per player, rounds that
  end by KO stop early, and a simulated opponent sends no pose (S3).
- The single `INVALID_STATE` in S4 is a rep the bot sent right as its round ended (KO or time up); the server refused
  it as it should. The KO share (about 2/3) is high because each bot draws its reps independently from 8–25, so many
  pairs differ by more than the KO lead; it only shortens those rounds.

### Team server (TS1, TS2)

The same tools on the team server, 2026-11-28 06:53–06:57 UTC (15:53–15:57 KST). Both binaries were copied to a
temporary folder under `/srv/gymrats` and run in one SSH session; the test server listened on loopback port 8090
only (no port opened, nginx, `.env`, database or running service touched) and the folder was deleted afterwards.
The live battle server had 0 connections before and after; `gymrats-battle` and `gymrats-api` stayed active.
The client shared the 2 vCPUs with the server, so the server's numbers are, if anything, pessimistic.

| | TS1 = S1 on the team server | TS2 = S2 on the team server |
|---|---:|---:|
| Bots / connected / connect errors | 200 / 200 / 0 | 200 / 200 / 0 |
| Peak connected / in a match / queued | 200 / 198 / 3 | 200 / 200 / 2 |
| Rounds / succeeded / failed | 600 / 600 / 0 | 200 / 200 / 0 |
| Ended by KO / time up | 395 / 205 | 128 / 72 |
| Opponent real / simulated | 598 / 2 | 198 / 2 |
| Server `error` messages / sockets closed by the server | 0 / 0 | 0 / 0 |
| Connect p50 / p99 / max | 0 / 3 / 9 ms | 65 / 131 / 132 ms |
| Queue wait, all: p50 / p90 / p99 / max | 4 ms / 516 ms / 1.88 s / 10.03 s | 45 / 49 / 51 ms / 10.02 s |
| Queue wait, real opponent: p50 / p99 / max | 3 ms / 1.61 s / 8.34 s | 45 / 50 / 51 ms |
| `match.found` → `match.start` p50 / p99 / max | 4.46 / 5.80 / 10.95 s | 4.46 / 5.89 / 10.90 s |
| `rep.submit` → `rep.accepted` p50 / p99 / max | 0 / 1 / 6 ms | 0 / 2 / 7 ms |
| Reps sent / acknowledged | 8053 / 8053 | 2750 / 2750 |
| Pose frames sent / received | 136 662 / 132 441 | 46 218 / 43 728 |
| Queue-wait buckets <100 ms / 0.1–1 s / 1–5 s / 5–10 s / 10–10.5 s | 350 / 229 / 17 / 2 / 2 | 198 / 0 / 0 / 0 / 2 |
| Server event-loop lag p99 / max | 0 / 2 ms | 0 / 34 ms (0 samples over 50 ms) |
| Server CPU per 5 s interval, % of one vCPU: mean / max ¹ | 16.6% / 33.5% | 20.5% / 36.7% |
| Client CPU, `ps` lifetime average at the end / highest sample ² | 20.9% / 26.3% | 19.9% / 28.9% |
| Server resident memory, max | 39 MB | 50 MB |
| Wall time | 167 s | 44 s |

¹ Linux `ps -o %cpu` is CPU time over the process's whole life, not the load of the last 5 s. The interval load
is worked back from the server's samples (`usage[].cpu_percent × at_ms`, differenced); the raw `ps` values in the
JSON peak at 22.6% / 25.1%. ² The client's samples have no time stamp, so only the raw `ps` values are given; its
real peak is higher than shown.

Discarded attempts (not results): a first try ran the client on the Mac through one SSH tunnel to the team server.
47 of 200 connections timed out at 10 s, connect p90 was 8.5 s and 136 sockets were closed with 1001, while the test
server itself kept running (its process shows as `dart:load-serve`, which a first `ps -C load-server` check missed).
The tunnel carrying every bot's ~10 pose frames per second is the likely limit, but this was not isolated. A second
try reached that still-running server instead of a fresh one and was discarded as well; the run script used for
TS1/TS2 (not committed) then first checked that port 8090 was free and that the new server was up.

### Skill index (P10 → P20): build apart from search

| Accounts | Build, median (max) | One `nearest` search, median |
|---:|---:|---:|
| 100 | 0.8 ms (1.1) | 0.05 µs |
| 1 000 | 2.2 ms (3.2) | 0.06 µs |
| 10 000 | 14.5 ms (16.9) | 0.07 µs |
| 100 000 | 203 ms (209) | 0.08 µs |

`dart run` (JIT) on the same machine. The search grows like log n; the build like n log n and runs on the battle
server's only isolate at start-up and every 5 minutes, so at 100 000 accounts every other message waits about 0.2 s
once per refresh.

### `POST /internal/skills`

| Accounts | Battle rows | Median (max) | Response |
|---:|---:|---:|---:|
| 100 | 4 000 | 13.3 ms (13.9) | 10 KB |
| 1 000 | 40 000 | 110.6 ms (131.7) | 106 KB |
| 5 000 | 200 000 | 553.0 ms (606.2) | 541 KB |

Python 3.12.15, in-memory SQLite, Django test client (no HTTP, no gunicorn). About 0.11 ms per account, every
5 minutes; the battle server waits for it without blocking (10 s timeout, old estimates kept on failure).

## Findings for the owners (not changed in P20)

1. **Uncaught error in `BattleServer._receive` (battle server owner / PM).** When the server's reply to a request
   fails because the client's socket is already closed, the `catch` block sends an `error` message to the same
   socket, which throws `Bad state: StreamSink is closed` out of the socket listener (`battle_server.dart` 411 via
   `_raw` 341). Reproduced only with the battle server and a bot in the **same process** (a bot that sent
   `queue.cancel` and closed at once; the error reached the zone's handler). It did **not** reproduce across
   processes: 300 WebSocket clients and 50 raw clients writing their frames and the close frame in one TCP write
   left `bin/server.dart` running. `bin/server.dart` has no guarded zone, so if it ever happens in production the
   process may stop (`gymrats-battle.service` has `Restart=on-failure`, 3 s; matches in progress are voided). Suggested fix: guard `_raw` (`try` around
   `socket.add`) — outside P20's paths. The bot now waits up to 1 s for the server's answer before closing, so the load numbers do not depend on it.
2. **Skill refresh at large scale.** Index build 203 ms at 100 000 accounts and `/internal/skills` 553 ms at 5000;
   both far beyond the team's current data, both linear-ish. Nothing to do now.
3. **Not covered by this test:** real phones' network paths (both runs are loopback), TLS/nginx, the API server's
   token check per connection, the Django result saver and telemetry writes during load, friend battles
   (`friend_id`) in the queue, reconnects, and more than 200 users on the team server (S4's 1000 ran only on the Mac).
