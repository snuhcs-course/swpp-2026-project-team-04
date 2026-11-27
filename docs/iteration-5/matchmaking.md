# Matchmaking with simulated users (P10)

Owner: ishlove77 · 2026-11-27 · branch `feat/iter5-skill-matching`

## Rules

| Situation | What happens |
|---|---|
| Another real player is waiting for the same exercise in the main queue | Paired at once, first come first served, whatever the skill (unchanged FIFO). |
| No real player within **10 s** (`battleVirtualWait`; 15 s until the user's change of 2026-11-27) | The battle server opens a match with a **simulated player** that copies the account whose skill estimate is closest to the player's own, under that account's nickname (no AI label: PM approval relayed by the user, 2026-11-27). The phone gets an ordinary `match.found`. |
| The simulated match | Played by the battle server as a real match (user decision 2026-11-27: no difference from a real opponent). The simulated player opens its setup 4–7 s after the match is found and is ready 3–6 s later; the setup time (20 s), the countdown, fever, combos, KO, forfeit and the result follow the same code as a real match. During the round it makes its planned reps as `rep.updated`. No poses are sent: the online battle screen does not draw the opponent's pose. |
| Result | `match.finished` as for a real match. The P11 saver gets the simulated player marked `simulated: true` and stores a row only for the real player (an online battle, `is_online: true`, opponent = the nickname); the copied account's history never gets one. 기록보관소, the report and 다시 대결 behave as after any online battle. |
| Friend battle (`friend_id`) | Never gets a simulated player. |
| App that does not send `accept_virtual: true` (older app) | Keeps waiting as before. |

### The simulated player's reps
`SimulatedPlayer.planReps`: round(estimate) valid reps give or take one (1–60), plus 0–2 too shallow
(`insufficient_depth`), spread over the round from 1.5 s to 1.2 s before the end with a little jitter; about 15% of the
valid reps are excellent, the rest good. Its id is `sim-` and 12 hex characters, never an account id.

## Skill estimate

- Per exercise (`push_up`, `squat`): the **median of the latest 5 battles that count**, of any kind (AI, arcade,
  online), newest first.
- What counts (decided 2026-11-27):

  | Battle | Value |
  |---|---|
  | Played to time (`time_up`) | its valid reps (`my_reps`) |
  | KO lasting 10 s or more, length known | its valid reps scaled to 30 s: `reps × 30 s ÷ length` (20 s and 12 reps → 18) |
  | KO under 10 s, or of unknown length | left out (the opponent hardly played; scaling would overstate the pace) |
  | Forfeit, disconnect | left out |

  A KO's length is the battle server's start-to-end for an online battle, and only otherwise the phone's form report
  (`roundMs`, the time played rounded up to the second, so a 9.5 s KO reads as 10 s there). PM review of `71fcdc3`.
- Fewer than 5 that count: the median of those there are. None: the average estimate of all accounts with one, or
  9 reps when nobody has one (`SkillIndex.defaultSkill`).
- The player's own estimate is taken the same way.
- The simulated player plays about `round(estimate)` valid reps of the copied account. With nobody else to copy it is
  `RepBot` at the player's own estimate.

## Data flow

1. Django `POST /internal/skills` (loopback only, `X-Results-Secret`, like the other `/internal/` calls) returns
   `{"players": [{"player_id", "display_name", "recent": {"push_up": [...], "squat": [...]}}]}`: the nickname and the
   values of the latest `limit` (default 5, at most 10) battles that count per exercise, newest first (a scaled KO
   value may have a fraction). Nothing else leaves.
2. The battle server reads it at start-up and every 5 minutes (`skillRefreshMs`), and builds a `SkillIndex`: one list
   per exercise sorted by estimate. A failed read keeps the previous index.
3. On assignment: `estimateOf(player)` is a hash lookup; `nearest(exercise, skill, excludeId: player)` is a binary
   search plus one step each way.

## Protocol additions (v1, backward compatible)

- `queue.join` payload: optional `accept_virtual: bool`. `true` together with `friend_id` is `INVALID_PAYLOAD`.
- No new server message: a simulated match is announced and played with the existing ones.
- Internal (battle server → API server): `POST /internal/skills`; in `POST /internal/results` a player may carry
  `"simulated": true` with a `sim-` id, and is then not stored.
- Deploy order: Django (route and saver) → battle server → app. An older battle server refuses `accept_virtual`, and
  an older Django refuses a result with a simulated player.

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

- The copied account's nickname is shown without a label, and the simulated player is indistinguishable from a person
  (PM approval relayed by the user, 2026-11-27).
- The protocol doc (`docs/iteration-2-protocol.md`) needs `accept_virtual` and the simulated player in results.
- Telemetry (P17/P24): `battle_finished` of a simulated match is `kind: main`; its `scores` carry the `sim-` id, which marks
  it. A match cancelled before the start has no scores and cannot be told apart.
- P20: measure the `/internal/skills` read and simulated matches under load, apart from the index numbers above. The
  read is one query: countable battles are chosen in the database and cut to the latest `limit` per account and
  exercise by a window function (PM and Codex review of `71fcdc3`), so it does not load the whole history.
