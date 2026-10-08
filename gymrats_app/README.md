# GymRats app

Flutter Android client for the Iteration 1 demo. `lib/main.dart` launches the integrated flow: **home → simulated matching → versus → pose setup → 60-second battle → result**.

The opponent is local RepBot. Profile and match records are in memory; online PvP, authentication, and persistent storage are not implemented on this branch. See the [repository README](../README.md) for features, prerequisites, the walkthrough, and limitations.

## Run the integrated app

From this directory, with Flutter and the Android toolchain configured:

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

Use an Android phone running API 23 or newer, enable USB debugging, and grant camera access. The Flutter SDK must include Dart 3.13.4 or a compatible 3.x version. The main app is locked to portrait orientation.

## Standalone development demos

These optional entry points isolate individual features; they are not required to run the integrated app:

```sh
flutter run -t lib/demo/pose_setup_demo.dart -d <device-id>
flutter run -t lib/demo/rep_judge_demo.dart -d <device-id>
flutter run -t lib/demo/battle_demo.dart -d <device-id>
```

For pose setup, face the camera with your head, both shoulders, elbows, and wrists visible. Hold a valid pose for 1.5 seconds, then remain ready during the three-second automatic countdown. Knees and hips are not required by the current front-view setup checker.

The battle demo uses a simulated camera and touch input: tap for a counted rep and long-press for a rejected rep. Use the integrated app or rep judge demo to test actual camera-based counting.

## Diagnostics

Setup diagnostics appear in the `flutter run` terminal with the `pose_setup` prefix. Android Flutter logs are also available with:

```sh
adb logcat -s flutter
```

Check camera permission, lighting, framing, and landmark visibility if detection fails. Rep beeps use Android media volume.

## Tests

```sh
flutter analyze
flutter test
```

Tests cover pose/setup rules, rep judging, bot behavior, in-memory records, view models, widgets, and navigation. Use a physical phone to verify camera behavior and exercise counting.
