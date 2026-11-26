# Matchmaking with simulated users (P10)

Owner: ishlove77 · 2026-11-27 · branch `feat/iter5-skill-matching`

## Rules

| Situation | What happens |
|---|---|
| Another real player is waiting for the same exercise in the main queue | Paired at once, first come first served, whatever the skill (unchanged FIFO). |
| No real player within **15 s** (`battleVirtualWait`) | The battle server sends `match.virtual`: a simulated user that copies the account whose skill estimate is closest to the player's own, shown under that account's nickname. |
| Friend battle (`friend_id`) | Never gets a simulated user. |
| App that does not send `accept_virtual: true` (older app) | Keeps waiting as before. |

The simulated battle runs on the phone as an AI battle (`BotOpponent` at `SimulatedUserPace`). Its result is saved with
`POST /matches` by the player's app only, so the copied account's history never gets a row. (The P11 saver stores a
row for both players of an online battle, which is why the server does not play the simulated user itself.)

## Skill estimate

- Per exercise (`push_up`, `squat`): the **median of the valid reps (`my_reps`) of the latest 5 battles** of any kind
  (AI, arcade, online).
- Fewer than 5 battles: the median of those there are. No battle: the average estimate of all accounts with one, or
  9 reps when nobody has one (`SkillIndex.defaultSkill`).
- The player's own estimate is taken the same way.
- The simulated user plays `round(estimate)` valid reps, give or take one, clamped to 1–60. With nobody else to copy it
  is `RepBot` at the player's own estimate.

## Data flow

1. Django `POST /internal/skills` (loopback only, `X-Results-Secret`, like the other `/internal/` calls) returns
   `{"players": [{"player_id", "display_name", "recent": {"push_up": [...], "squat": [...]}}]}`: the nickname and the
   latest `limit` (default 5, at most 10) valid reps per exercise, newest first. Nothing else leaves.
2. The battle server reads it at start-up and every 5 minutes (`skillRefreshMs`), and builds a `SkillIndex`: one list
   per exercise sorted by estimate. A failed read keeps the previous index.
3. On assignment: `estimateOf(player)` is a hash lookup; `nearest(exercise, skill, excludeId: player)` is a binary
   search plus one step each way.

## Protocol additions (v1, backward compatible)

- `queue.join` payload: optional `accept_virtual: bool`. `true` together with `friend_id` is `INVALID_PAYLOAD`.
- Server → client `match.virtual` (no `match_id`):
  `{"exercise": "push_up", "opponent": {"display_name": "근손실", "expected_reps": 7}}`. The player leaves the queue;
  a real player joining later is not paired with them. The copied account's id is never sent.
- Deploy order: Django (new route) → battle server → app. An older battle server refuses `accept_virtual`.

## Cost: building the index vs. searching it

Measured by `measureSkillIndex` in `server/lib/skill_matchmaker.dart`, through the test below.

```sh
cd gymrats_app
flutter test test/services/online/skill_matchmaker_test.dart --plain-name "measures the build"
```

Setup for P20 to reproduce: `Random(20)`, 10 000 accounts with 5 push-up battles of 0–39 valid reps each, 1 000 query
skills in 0–45, 10 000 lookups (queries taken in turn), no player excluded.

| Run (2026-11-27, Apple M4, Flutter 3.47.5, `flutter test` JIT) | Build (sort, 10 000 accounts) | 10 000 lookups | Per lookup |
|---|---:|---:|---:|
| 1 | 20.7 ms | 1.7 ms | 0.17 µs |
| 2 | 32.5 ms | 4.4 ms | 0.44 µs |
| 3 | 26.1 ms | 4.4 ms | 0.44 µs |
| 4 | 29.0 ms | 5.9 ms | 0.59 µs |
| 5 (after the tie fix, PR #102 review) | 31.6 ms | 6.4 ms | 0.64 µs |
| 6 (after the tie fix) | 27.0 ms | 5.1 ms | 0.51 µs |
| 7 (after the tie fix) | 27.1 ms | 5.0 ms | 0.50 µs |

Building is O(n log n) and happens off the request path, every 5 minutes; a lookup is O(log n) and happens once per
simulated assignment. P20 should measure the Django query (`/internal/skills`, a window function over `Match`) and the
end-to-end assignment under concurrent players separately from these numbers.

## Open points (PM)

- The copied account's real nickname is shown. Screens still tag a bot opponent "AI", so the player is not told they
  face a person.
- P17 telemetry: a search that ends with a simulated user is not recorded as found yet (needs a change in
  `MatchingTelemetry`, outside P10's files).
