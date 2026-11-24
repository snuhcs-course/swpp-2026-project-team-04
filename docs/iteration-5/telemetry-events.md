# Telemetry events (P17, as implemented)

This page is the event dictionary from 박진영's P6 plan, as the app and the servers implement it. Where the code
differs from the P6 table, the difference is marked **Changed** and the reason is given. The P6 document should take
the same changes.

## Where events go

| From | Endpoint | Auth | Stored |
|---|---|---|---|
| App (six events) | `POST /api/telemetry/events`, body `{"events": [...]}`, 1–100 events | The user's login (Bearer). The server adds the account; the app never sends it. | Django `telemetry.TelemetryEvent`, in the SQLite file `/srv/gymrats/data/gymrats.db` |
| Battle server (`battle_finished`) | `POST /api/internal/telemetry/battle` (loopback only; nginx does not forward `/api/internal/`) | The P11 `X-Results-Secret`, loopback only, no `X-Forwarded-For` | Same table |

- **App response:** `{"stored": n, "duplicates": n, "rejected": [indexes]}`.
  - A rejected event (unknown event, unknown field, wrong value) is dropped, not retried.
  - A malformed batch (no list, an empty list, more than 100 events) is refused whole with 422.
- **Deduplication:**
  - `event_id` is unique, so a resent event is stored once.
  - `match_id` is unique for `battle_finished`, so one battle is one row, even if a report is retried.
- **Never in a payload:** camera frames or images, joint coordinates, tokens, passwords, e-mail. The server enforces
  this, because every event accepts only the fields in the tables below.
- **Retention:** not implemented yet. It will be decided at the 11/25 P3 TA meeting (P6 draft: 30 days after 12/4).

## Common fields

Every event carries `event`, `event_id` (UUID v4) and `ts` (UTC, ISO 8601).

The six app events also carry:
- `session_id` (UUID, new each app run);
- `app_version` (`--dart-define=GYMRATS_VERSION`, default `1.0.0+1`);
- `attempt_id` (UUID; it joins a start to its end).

## App events

| Event | When (code) | Fields | Values |
|---|---|---|---|
| `tutorial_started` | The onboarding tutorial opens (`HelpScreen.initState`), shown once before the first home after sign-up on this phone. **Changed:** the help opened again later ('?', 규칙 보기) is not recorded, so the counts are the onboarding's | `pages_total` | integer |
| `tutorial_finished` | 완료 on the last page → `completed`. 건너뛰기, back, or the screen closing any other way → `skipped` | `result`, `duration_ms`, `last_page` (1-based) | `completed` · `skipped` |
| `setup_started` | The pose setup starts. Bot battle: when its camera opens (`BattleScreen`). Online: `OnlineBattleScreen` opening after `match.found` | `exercise`, `mode` | `push_up` · `squat` / `bot` · `main` · `friend` |
| `setup_finished` | Bot: the round begins → `ready`; leaving before it → `cancelled`. Online: the server sets the start → `ready`; `setup_timeout` or `ready_timeout` → `timeout`; any other end before the start (own exit, opponent left, connection lost) → `cancelled` | `result`, `duration_ms`, `limit_ms`, `last_reason` | `ready` · `timeout` · `cancelled`; `limit_ms` 10000 online, null for the bot; `last_reason`: a SetupReason below, or null |
| `matching_started` | The queue takes the join (`queue.joined`, the first one for each search; a reconnect does not start another) | `exercise`, `kind` | `push_up` · `squat` / `main` · `friend` |
| `matching_finished` | Opponent found → `found`. The user stops the search (cancel, back, closing the lobby, 다시 신청), or the friend declines or takes the invite back → `cancelled`. The friend does not accept in time, or accepted but never paired → `timeout`. The search fails (connection, server error, login expired, invite not sent) → `error` | `result`, `wait_ms` | `found` · `cancelled` · `timeout` · `error` |

**SetupReason values:** `no_person`, `too_close`, `too_far`, `not_facing_forward`, `missing_parts`, `not_in_push_up`,
`not_standing`, `phone_too_flat`, `phone_shaky`.

**Changed:**
- **Where the setup events come from.** The bot setup runs inside `BattleScreen`, not `SetupScreen`; `SetupScreen`
  is not reached in the app.
- **`limit_ms` may be null.** It is null for the bot, which has no time limit.
- **`last_reason` may be null.** It is null when the checker never asked for anything. A pose that is ready but
  outside the silhouette keeps the previous reason.
- **`timeout` for matching only applies to friend battles.** The main queue has no time limit, on the app or the
  server.

## Battle server event

| Event | When | Fields | Values |
|---|---|---|---|
| `battle_finished` | The match ends, recorded by the battle server once, where it decides the end (`_finish`, `_cancel`, `_void`) | `match_id`, `end_reason`, `status`, `duration_ms` (from `match.found` to the end), `exercise`, `kind`, `scores` | see below |

- **`status`:** `finished` · `cancelled` · `void`.
- **`scores`:** one entry per player, `[{player_id, game_score, valid_reps}]`. It is empty when the battle never
  started.
- **`end_reason`:** the battle server's own codes.

| `end_reason` | `status` | P6 value |
|---|---|---|
| `time_up`, `ko` | finished | `completed` |
| `forfeit` (a player left after the start) | finished | `user_exit` / `opponent_exit` |
| `disconnect_timeout` | finished | `disconnect_timeout` |
| `user_exit` (left before the start) | cancelled | `user_exit` |
| `setup_timeout` | cancelled | `setup_timeout` |
| `ready_timeout` | cancelled | `ready_timeout` |
| `disconnected_before_start` | cancelled | (not in P6) |
| `both_disconnected` | void | `both_disconnected` / `void` |

**Changed:**
- **The server's codes are kept as they are.** P6 says "use the codes the app and the battle server already use", so
  P6's summary values are not mapped. One server record per match cannot say whose exit it was, which
  `user_exit`/`opponent_exit` would need.
- **`status`, `exercise` and `kind` were added,** so cancelled and void battles can be counted apart and
  friend battles split from the main queue.
- **A battle still running when the battle server stops is not recorded.** The next start voids it in storage
  (P11 `recover`).

## Sending from the app

- **Batching:** events wait on the phone in `telemetry_pending.json` in the app's files folder. They go in batches of
  up to 100, 3 s after being recorded.
- **Waiting:**
  - With no connection, or on 404 (server not deployed yet), 408, 429 or 5xx, they wait and are retried every 30 s.
  - Logged out, or on 401, they wait for the next login.
  - At most 200 are kept; the oldest go first.
- **Accounts:** each event belongs to the account signed in when it was recorded, and goes only with that account's
  login. An event recorded while signed out goes with the next login. Another account on the same phone never sends
  someone else's events.
- **Login is never touched:** the sender does not use `ApiClient`'s requests, so a rejected token never logs the
  user out.
- **Next app run:** events the last run could not send are read before anything is written, then sent first.

## Counting (P6 rules)

```
python manage.py telemetry_summary [--since 2026-12-02T00:00:00+09:00]
```

It prints JSON with these parts:
- **tutorial, setup and matching:** the starts as the denominator, the count of each end result, and `unobserved`
  for starts with no end (the app closed mid-way). It also gives mean and median times per result, and ends whose
  start never arrived, which are counted apart.
- **battle:** the number of battles, and the count and times per `end_reason`.
