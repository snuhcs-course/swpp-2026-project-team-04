# GymRats app

Flutter Android client integrating avatar battles, 30-second rounds, form feedback, and phone placement. `lib/main.dart` launches **login → home → online or AI matching → versus → pose setup → battle → result → form feedback**.

The primary home button queues for an authenticated online opponent; the lower button uses local RepBot. Avatar selection is in the profile screen and saved per account on this device. Completed rounds have on-device form reports. Online rounds use the server's clock and require the integrated server deployment for the new 30-second default and rejection reasons. See the [repository README](../README.md) and [online protocol](../docs/iteration-2-protocol.md) for details.

## Run the integrated app

From this directory, with Flutter and the Android toolchain configured:

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

Use an Android phone running API 24 or newer, enable USB debugging, and grant camera access. The Flutter SDK must include Dart 3.13.4 or a compatible 3.x version. The main app starts in portrait orientation.

## Standalone development demos

These optional entry points isolate individual features; they are not required to run the integrated app:

```sh
flutter run -t lib/demo/pose_setup_demo.dart -d <device-id>
flutter run -t lib/demo/rep_judge_demo.dart -d <device-id>
flutter run -t lib/demo/battle_demo.dart -d <device-id>
```

For pose setup, face the camera with your head, both shoulders, elbows, and wrists visible, and hold the top of a push-up with straight arms. Hold that pose for 1.5 seconds, then remain ready during the three-second automatic countdown. Knees and hips are not required; when the hips are visible, an upright body does not become ready.

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
