# Binary MLP phone trial

The user requested a local GymRats build using the broader motion proposals and the already trained binary MLP on 2026-11-16. This enables the model evaluated in `pushup-span-benchmark.md` for an actual phone trial.

## Build and behavior

`flutter build apk --debug --target-platform android-arm64 --dart-define=PUSHUP_MLP=true --no-pub` selects the experimental path. Both AI and online push-up battles construct the same judge through the existing adapter. The default value of the build flag is false for comparison builds. The squat implementation uses its existing judge.

The classifier has 466 screen-coordinate features, two hidden layers of 64 and 32 ReLU units, and one sigmoid output. It consumes up to 1.6 seconds of preceding pose frames after the previous proposal. A probability greater than 0.5 accepts the repetition. The proposal finder combines the earlier head/short-cycle judge, a 0.06 arm-span cycle and 0.095 elbow/height turns, with 800 ms between proposals. The whole computation runs locally.

The frozen model has no phone-angle input because the training videos had no recorded IMU. Its proposal path reproduces the image-only projection used in the experiment. The battle counter still applies the separate live phone-movement rejection after this judge. App preparation and sensor subscriptions use their existing flow.

The MLP predicts normal or invalid only. Invalid repetitions keep a simultaneous existing rejection reason when one is available. Otherwise the current heuristic fault or generic insufficient-depth explanation is used. This explanation is not a learned nine-way class. Existing game grades still use measured depth from coincident primary events. Additional accepted proposals without measured depth receive the game's Good grade. Existing shallow-repetition Average scoring remains in force.

The experimental event index increases only when this path publishes a verdict. A new round resets it. A camera interruption discards an unfinished motion while retaining the index.

## Verification

The embedded parameters reproduce the numeric arrays from `span-wide-mlp/binary-model.npz`, whose SHA-256 is `ef3c99bc3cf8087788658ee528b7142fdcc41f9c89ea54ec64a073765b7b022c`. All 466 features matched exactly on 858 held-out proposal windows. Maximum normal-probability difference was 0.000000739 relative to the exported Python model, and no binary decision differed.

Proposal times matched across 1,170 development recordings with 3,383 proposals, 294 held-out recordings with 858 proposals, and 44 native phone recordings with 518 proposals. Replaying the complete experimental app judge on the held-out recordings produced exactly the same 858 timestamps and binary labels as the original saved model.

Focused tests cover model features, positive and negative model outputs, empty landmarks, stable poses, partial-cycle abandonment, sequence indices, reset, proposal cooldown, prior-frame feature boundaries and matching legacy-primary priority.

## Known model errors

On the earlier web-video test the broader binary MLP accepted 299/378 normal reps and explicitly rejected 271/470 faults. It also produced 50 extra accepted proposals. On the existing per-rep-labelled phone controls it newly accepted 70 previously rejected critical faults and produced 62 extra accepted proposals. The user requested this trial after receiving those results. The model is the same frozen experiment, and on-phone workout accuracy has not been established by build or replay verification.

## Installation result

The experimental APK was installed on the connected Galaxy S22 (SM-S901N) on 2026-11-16, and Android successfully launched GymRats. The on-device package hash matched the locally built APK. The phone was locked, so live screen interaction and a human exercise trial remain unverified.

Final Flutter analysis passed. The full suite passed 3,137 tests with 10 existing skips, and the scoped pose coverage run passed 129 tests. New experimental tests also passed with PUSHUP_MLP=true.

After the user unlocked the phone, the visible home-to-AI-push-up flow reached the live pose-setup screen. The runtime log confirmed the binary MLP 64/32 path. The camera, outline guide and placement prompt were inspected on the phone. The app remains at pose setup. Human exercise accuracy remains unmeasured.
