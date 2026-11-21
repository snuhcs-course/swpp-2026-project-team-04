# Combined MLP and knee policy — 2026-11-22

The user selected **MLP + existing knee specialist + latest frame-knee evidence** for publication. This changes the production battle policy, not the recorded labels or model weights. Both bot and online push-up battles use `judgeFor` -> `RepJudge.forBattle`; squats keep `SquatRepJudge`.

## Runtime configuration

`RepJudge.forBattle` defaults to `PUSHUP_MLP=true`, `PUSHUP_FRAME_KNEE=true`, `PUSHUP_RETAIN_LEGACY_KNEE=true` and `PUSHUP_KNEE_FOREST=false`. Explicit build definitions still override these settings. The unnamed `RepJudge` constructor retains historical replay defaults so frozen tests do not silently change configuration.

The additive mode retains the old MLP knee veto and its original geometric fallback. Completed-attempt frame evidence can only change an accepted repetition to `kneesDown`; it never accepts a previously rejected event or changes an existing rejection reason. The latest observer still returns touching/lifted/occluded each frame and confirms state changes with three consecutive frames. Reset, abandonment and interrupted streams clear its evidence.

## Same-input development comparison (2026-11-21)

Frozen32 plus Hyunwoo/Sangwoo8: **40 recordings, 310 reference repetitions**. Only the recent Jinyoung recordings are excluded. The original fine-label DP alignment is preserved before grouping; missing predictions are errors. Other groups all rejection reasons except kneesDown and insufficientDepth, so it is not exact individual-reason accuracy. Extra accepted events have no matched reference and are shown separately.

| Configuration | Normal (73) | Knees down (79) | Insufficient depth (36) | Other (122) | Extra accepted |
|---|---:|---:|---:|---:|---:|
| Iteration3 |56/73 (76.7%)|68/79 (86.1%)|35/36 (97.2%)|38/122 (31.1%)|0|
| Iteration4 historical default |56/73 (76.7%)|68/79 (86.1%)|35/36 (97.2%)|38/122 (31.1%)|0|
| MLP + old knee specialist |69/73 (94.5%)|76/79 (96.2%)|2/36 (5.6%)|7/122 (5.7%)|26|
| MLP + latest knee, replacing old |65/73 (89.0%)|60/79 (75.9%)|5/36 (13.9%)|27/122 (22.1%)|33|
| **MLP + old and latest knee** |**65/73 (89.0%)**|**78/79 (98.7%)**|**2/36 (5.6%)**|**7/122 (5.7%)**|**22**|

Compared with old MLP, the additive option correctly classifies two more knee repetitions but rejects four additional normal repetitions. Binary invalid-not-counted recall is157/237 (66.2%), versus151/237 (63.7%) with the old MLP; this metric includes missing events. The former Iteration4 rule has210/237 (88.6%). The user chose the additive trade-off after seeing these results. This does not establish that the selected policy meets the frozen90%/90%/80% M1/M2/M3 targets.

Across all44 replayed recordings (including recent Jinyoung for this invariant only), all479 event counts and timestamps are unchanged. The only25 changes are accepted -> kneesDown. Every old rejection reason is preserved. MLP+old and replacement control replays match their saved results exactly. All32 frozen JSONs and the two recent source/label artifacts retain their original SHA256 hashes.

## Reproduction and limitations

The public frozen set is `gymrats_app/test/ai_eval/cases`. The historical MLP and frame models were already fitted/inspected against related data; these are reused development recordings, not a new holdout. Recent labels come from the recorder protocol plus a visual count audit, not independent human confirmation of physical knee/floor contact. Public cases_iter4 labels remain pending and are not replaced by these provisional references. Depth/other reasons are rule fallbacks, not a trained four-class MLP.

The local recorded-frame runner and full artifacts are in `C:/SWPP/iter4/pushup-judge-comparison-20261121` and the publication rerun in `C:/SWPP/iter4/pushup-mlp-pr-20261122`. No original videos or raw images are published. Phone latency, live camera scheduling, setup/person tracking and physical-contact ground truth are outside this replay evaluation.

From `gymrats_app`, run the source regressions and production configuration checks:

```sh
flutter test --no-pub --coverage test/services/pose/rep_judge_test.dart test/services/pose/pose_metrics_test.dart test/services/pose/push_up_judge_adapter_test.dart
flutter test --no-pub --dart-define=PUSHUP_MLP=false --dart-define=PUSHUP_FRAME_KNEE=false --dart-define=PUSHUP_RETAIN_LEGACY_KNEE=false test/services/pose/push_up_judge_adapter_test.dart
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --dart-define=PUSHUP_MLP=true --dart-define=PUSHUP_FRAME_KNEE=true --dart-define=PUSHUP_RETAIN_LEGACY_KNEE=true test/ai_eval/ai_eval_test.dart
```

The last command evaluates the selected policy on the frozen set. A plain `test/ai_eval` invocation retains historical low-level defaults; it must not be presented as the production MLP policy's score. `AI_EVAL_STRICT=true` enforces the original accuracy thresholds, which this policy does not meet.

## Background-person regression coverage

Historical S2 video tests retain their original7/13/empty event assertions with an explicitly injected legacy judge. Separate production-policy replays exercise the real battle factory: no paused frame may publish a pose or repetition, unchanged-user clips preserve all baseline events, and the wrong-person stream is suppressed until explicit confirmation. Confirmation/resumption is also tested with the selected policy.

On the blurred O033 control, the selected MLP completes one candidate at2867ms before tracking pauses. This is a known pre-pause model false positive; the test does not call it a correct repetition or claim that the guard prevents all false candidates. No person-guard runtime behavior is changed by this PR.

Publication verification is recorded in [Sangwoo's testing notes](../testing/iteration-4/Sangwoo-Hahn.md). No server protocol or dependency changes are required.
