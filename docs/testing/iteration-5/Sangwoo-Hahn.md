# Iteration 5 testing · Sangwoo-Hahn

## 2026-11-23 · UAT push-up scoring

Base commit `25509ee`. Tested in Flutter on Windows, including two clients connected to the local Dart battle server. The focused run passed 548 tests.

```
flutter test --no-pub test/services/pose/rep_judge_test.dart test/services/opponent/bot_opponent_test.dart test/widgets/help_rules_test.dart test/services/online/online_battle_integration_test.dart test/services/pose/pose_metrics_test.dart test/widgets/battle_fx_motion_test.dart test/services/game
```

The regressions cover a completed knee push-up in fever, an opponent receiving the same five points, the elbow-angle window of a shallow attempt, knee contact on a shallow cycle and clearing an earlier rejection on Good. This run did not include physical-device play or a production deployment.

### 2026-11-24 · Knee push-up scoring follow-up

Updated scoring and tutorial expectations. Exercised the shared score path and the two-client battle-server integration in fever. A zero-point knee rep now counts as an opponent miss. Device play was not exercised.
