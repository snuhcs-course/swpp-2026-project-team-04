# Knee-support classifier study

## Request and selected method

On 2026-11-16 the user reported that the installed binary MLP worked well apart from knee-supported push-ups. The requested objective was to reject those movements while preserving as many normal push-ups as possible. This study continues from the local `fix/pushup_game_speed` worktree based on `d866b45`.

The selected research candidate combines the existing binary MLP with a second, small knee classifier. Both consume the same 466 features from the preceding 1.6-second pose window. These features contain 13 joints, 18 relative 2D spans, six temporal bins, motion ranges and visibility. The knee classifier has 32 and 16 hidden ReLU units and a sigmoid output. Its threshold is `0.9204565286636353`.

At each existing motion proposal, a score above that threshold gives `kneesDown`. Otherwise the existing binary verdict is retained. Proposal times are preserved. The overlay only removes accepted events, so it cannot recover normal attempts for which the counter produced no event. The live phone-motion rejection belongs after this classifier, as in the current app architecture.

The candidate, its portable inference tool and model-selection evidence are saved locally. This document reports recorded-data experiments. The installed app's human workout test belongs to the earlier binary-MLP trial.

## Selection procedure

The normal-preservation budget was chosen for this experiment. Additional rejection of previously accepted normal events was limited to 2% in each validation domain. Candidates were ranked by the average reduction of existing false knee acceptances in the web and native domains.

- Compared 42 geometric rules and small-tree configurations, including temporal summaries of knee angles and wrist, hip and ankle gaps.
- Compared 12 web-only specialist configurations using logistic regression, trees and a small MLP.
- Compared 396 combinations of the base threshold and web specialist threshold. Lowering the base threshold introduced additional native normal losses and other-fault acceptances.
- Compared 19 native-assisted logistic, tree and MLP configurations. The selected MLP weights native training examples by 20, alongside class balancing.

Web specialist selection uses five source-group folds. Native selection leaves one device group out at a time. Device groups are S23-Ultra, S947N, SM-S901N, s26-fe and an older unknown device group. Device separation does not establish participant separation.

The fitting pool contains 1,609 matched web normal windows and 385 matched web knee windows from development sources. Native supplementation uses 208 proposal windows from 16 pure-posture recordings, comprising 74 normal-posture windows and 134 knee-posture windows. Mixed-posture recordings supply no training labels because their individual repetition times are unavailable.

The base MLP was already fitted on all web development data. Therefore the incremental web-development figures condition on a previously fitted base model. They are descriptive model-selection results. The specialist's validation samples are excluded from its own fold's fitting and scaling.

## Reused web test

The existing held-out groups were excluded from the new fitting and threshold selection. This same test set was inspected in earlier studies. Labels are the existing automatic visual-review proposals and have not received independent human adjudication.

| Measure | Installed binary MLP | Selected knee overlay |
|---|---:|---:|
| Normal attempts accepted | 299/378, 79.1% | 299/378, 79.1% |
| Knee attempts explicitly rejected | 74/105, 70.5% | 76/105, 72.4% |
| Knee attempts incorrectly accepted | 14 | 12 |
| Knee attempts with no event | 17 | 17 |
| All abnormal attempts explicitly rejected | 271/470, 57.7% | 273/470, 58.1% |
| Extra accepted proposals | 50 | 50 |

Forty normal attempts still have no detected event. Rejection reasons remain a secondary objective. Six normal attempts receive a knee explanation under the overlay, but all six were already rejected by the binary model.

## Native device-group cross-validation

The following counts concern detected proposal windows in recordings labelled with one posture throughout. They include extra proposals. They are not repetition-level accuracy percentages.

| Measure | Existing binary MLP | Out-of-fold knee overlay |
|---|---:|---:|
| Accepted events in pure normal recordings | 49 | 49 |
| Incorrectly accepted events in pure knee recordings | 65 | 37 |
| Rejected events among 134 knee proposal windows | 69 | 97 |

This removes 28 of 65 incorrect knee acceptances, a 43.1% reduction, while retaining the 49 previously accepted normal events in these recordings. The threshold was selected on these cross-validation predictions, so these figures are model-selection estimates. Web development retains 1,463 of 1,490 previously accepted normal windows, losing 27 or 1.81%.

The final refitted model sees all of these native training examples. Replaying the pure recordings after refitting retains 49 normal events and reduces the 65 incorrect knee acceptances to zero. That result is training-set resubstitution. It does not measure generalization. Across all 36 labelled native recordings, the final refit loses one formerly accepted normal entry under the existing sequence-edit alignment, from 62 to 61 of 72. The mixed recordings share devices with the fitting pool.

Native repetition-level summaries are sensitive to label-dependent sequence alignment. An extra rejected event can align to a labelled knee rep while an extra accepted event is left unmatched. For this reason, raw false accepted event counts are retained in the primary comparison above.

## Reproduction and artifacts

The external experiment root is `C:/SWPP/iter4/pushup-nine-benchmark/knee-focus`.

- `rules/results.json` contains the geometric comparisons.
- `model/results.json` and `model/combined-results.json` contain the web-only comparisons.
- `native/results.json` contains the native-assisted logistic comparison.
- `native-extended/results.json` contains the selected method and validation operating points.
- `native-extended/native-knee-model.npz` contains the portable selected model.
- `native-extended/native-knee-model.joblib` contains the fitted training implementation.
- `native-extended/export-parity.json` and `cli-verification.json` contain inference verification.
- `native-extended/phone-resubstitution.json` explicitly identifies the native fitting-data replay.

Selected NPZ SHA-256 is `542d8651d1a8d4aadc58bcd0b8cf05634e9f69112f6d9a61c580905fb80e69c5`.

```powershell
python tools/diagnose/train_pushup_knee_specialist.py C:/SWPP/iter4/pushup-nine-benchmark C:/SWPP/iter4/pushup-nine-benchmark/knee-focus/model
python tools/diagnose/train_pushup_knee_specialist.py C:/SWPP/iter4/pushup-nine-benchmark C:/SWPP/iter4/pushup-nine-benchmark/knee-focus/model --combined
python tools/diagnose/train_pushup_knee_native.py C:/SWPP/iter4/pushup-nine-benchmark C:/SWPP/iter4/pushup-nine-benchmark/knee-focus/native-extended --extended
python -m unittest discover -s tools/diagnose -p 'test_*.py' -v
```

Portable inference takes the base NPZ, selected knee NPZ, source pose JSONL, causal proposal JSONL and a new output path, in that order.

```powershell
python tools/diagnose/infer_pushup_knee.py BASE_MODEL.npz KNEE_MODEL.npz REPLAY.jsonl PROPOSALS.jsonl NEW_OUTPUT.jsonl
```

## Verification and remaining error

All 13 diagnostic tests passed, including five new knee-study tests. Exported logistic, neural and tree implementations match their training predictors. For the selected model, probabilities and decisions match exactly on 4,449 cached windows. The complete inference CLI replayed 294 held-out streams and 858 proposals, reproducing the full held-out confusion matrix exactly. Independent read-only review approved the research implementation and identified the validation qualifications recorded above.

The residual 37 native cross-validation false acceptances and 12 web knee false acceptances remain substantive errors. The selected model is a useful improvement candidate. New-person, newly recorded phone-workout performance is unmeasured. Camera occlusion and imperfect existing posture labels still limit the available evidence.

## App integration and phone installation

On 2026-11-16 the user authorized applying the selected specialist and installing the local build. `PushupKneeModel` now embeds the selected parameters in the pose metric service. `RepJudge` evaluates both models from one `featuresForProposal` result. A knee veto gives the existing `kneesDown` feedback reason while preserving event timing and available depth/angle metadata. Both AI and online battles consume this path through the existing adapter when built with `PUSHUP_MLP=true`.

The original scaler and dense-layer arithmetic are shared by the two networks. All 69,412 knee parameter bytes match the selected NPZ. On 4,449 cached windows, Dart's maximum knee-probability difference is 0.000000749 and there are zero threshold-decision differences. Complete app replay agrees with Python on all 858 held-out events and 456 labelled native events.

Four new regression tests cover fixed exported probabilities, a shared proposal window, five formerly accepted recorded knee events receiving knee rejection, and four recorded normal acceptances surviving. These recorded examples include fitting data and establish wiring behavior. Flutter analysis is clean. The full test suite passed 3,141 tests with 10 existing skips. Sequential scoped coverage passed 133 tests and measured 96.20% for pose metrics, 96.12% for the judge and 92.31% for the adapter. The initial concurrent coverage attempt failed because the VM coverage service disappeared. The sequential retry completed successfully. Independent read-only review approved the implementation.

An ARM64 debug APK built with `--dart-define=PUSHUP_MLP=true` was installed over GymRats on the connected Galaxy S22, and Android records its update at 2026-11-16 13:28:49. Installed and local APK SHA-256 both equal `e847a7e7a2a33340a30b0d5b75b74625ff74eb7d7953d16b52d17adbe7139ecd`. The home-to-AI-push-up flow reached the camera pose-setup screen. Runtime logging confirms the binary MLP 64/32 plus knee MLP 32/16. Human workout accuracy after this installation is unmeasured.

Verification logs, coverage, replay outputs, activation log and setup screenshot are under `C:/SWPP/iter4/pushup-nine-benchmark/knee-device`.
