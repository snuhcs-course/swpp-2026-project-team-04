# Iteration 5 testing · Sangwoo-Hahn

## 2026-11-23 · UAT push-up scoring

Base commit `25509ee`. Tested in Flutter on Windows, including two clients connected to the local Dart battle server. The focused run passed 548 tests.

```
flutter test --no-pub test/services/pose/rep_judge_test.dart test/services/opponent/bot_opponent_test.dart test/widgets/help_rules_test.dart test/services/online/online_battle_integration_test.dart test/services/pose/pose_metrics_test.dart test/widgets/battle_fx_motion_test.dart test/services/game
```

The regressions cover a completed knee push-up in fever, an opponent receiving the same five points, the elbow-angle window of a shallow attempt, knee contact on a shallow cycle and clearing an earlier rejection on Good. This run did not include physical-device play or a production deployment.

### 2026-11-24 · Knee push-up scoring follow-up

Updated scoring and tutorial expectations. Exercised the shared score path and the two-client battle-server integration in fever. A zero-point knee rep now counts as an opponent miss. Device play was not exercised.

### P9 reciprocal friend requests · 2026-11-24
Server pytest: 239 passed. accounts/friends_views.py: 184/184 statements. Two concurrent API clients start with an empty pair and end with one accepted friendship visible to both. Tested retry exhaustion and unrelated database errors.

Independent re-review reproduced simultaneous 503 responses. The updated endpoint writes first and resolves a pair uniqueness conflict within the transaction. Full server suite: 245 passed; friends_views.py 187/187 statements. Added malformed JSON regressions.

### 2026-11-27 · P10 protocol handoff
Validated the documented virtual-assignment JSON example and field names, target range, wait and friend-queue flag rules against PR #102 at `1a164d6`. No runtime code changed in the documentation branch.

### 2026-11-27 · Revised P10 protocol handoff
Compared the revised queue and result contract against #102 at `71fcdc3`, including friend validation, queue/setup clocks, the WebSocket versus internal result payloads, and pre-start telemetry. Checked the documented simulated-player JSON against the serializer fields. Documentation only.

### 2026-11-27 · P10 protocol merge check
Checked the protocol against the P10 merge commit `5d7bc6e`. Parsed the simulated result example, checked its fields against OnlinePlayerSerializer and compared the queue/setup timers, avatar selection and fallback name with the battle server. All checks passed.

### 2026-11-28 · P11 weekly rankings follow-up
The Flutter design-token and app-routing suites passed (118 tests). The new route test opened weekly rankings through the online exercise sheet, observed a global push-up request on the injected repository, and returned to the sheet with system back. The Django suite passed (367 tests), and `makemigrations --check --dry-run` found no model drift. On an in-memory SQLite database with 4,000 match rows, the global weekly ranking query used `match_played_at_idx` for the date range and returned the same five ranked rows before and after migration. An independent reviewer also applied, reversed and reapplied the migration with an existing match.
