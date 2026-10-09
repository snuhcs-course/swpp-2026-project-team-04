# GymRats

GymRats is a Flutter Android app for camera-based exercise battles. The `iteration-1-demo` branch implements a **60-second push-up battle against RepBot, a simulated opponent**.

This is a local prototype, not an online multiplayer release. No account, backend server, or second phone is required.

## Demo video

[Watch or download the Iteration 1 demo](Demo_Video.mp4)

This is a low-resolution copy of the original demo recording.

## Implemented features

- **Home:** push-up selection, a sample user profile, best record, and latest match.
- **Matching and versus:** simulated matching with RepBot, opponent information, and battle rules.
- **Pose setup:** camera preview, landmark overlay, framing and visibility checks, and an automatic countdown after holding a valid pose.
- **Rep judging:** Google ML Kit pose detection and a Dart state machine using head depth, arm extension, shoulder tilt, and timing. Counted reps and rejection reasons appear on screen.
- **Battle:** a 60-second timer, both scores, an animated opponent mannequin, live feedback, and an Android beep for each counted rep.
- **Results:** win/loss/draw, final scores, valid/rejected rep counts, and the proportion of judged reps that counted. Users can return home or match again.
- **Session records:** completed matches update the best record and latest match in memory. Leaving early does not save a result.

## Getting started

### Prerequisites

- Flutter SDK with Dart **3.13.4 or a compatible 3.x version**, as required by `gymrats_app/pubspec.yaml`.
- Android Studio / Android SDK and a configured Android toolchain. The Android project targets Java 17.
- An Android phone with **Android 6.0 / API 23 or newer**, a camera, and USB debugging enabled. Accept the USB debugging authorization prompt.

A physical Android phone is recommended for exercise testing. The main app runs in portrait orientation.

### Run the integrated demo

```sh
git clone --branch iteration-1-demo --single-branch https://github.com/snuhcs-course/swpp-2026-project-team-04.git
cd swpp-2026-project-team-04/gymrats_app
flutter doctor
flutter pub get
flutter devices
flutter run -d <device-id>
```

Replace `<device-id>` with the Android device ID shown by `flutter devices`. Grant camera access when prompted. **Plain `flutter run` launches the integrated app through `lib/main.dart`; no standalone demo entry point is required.**

To build a debug APK locally:

```sh
flutter build apk --debug
```

The APK is generated at `gymrats_app/build/app/outputs/flutter-apk/app-debug.apk` relative to the repository root.

## Demo walkthrough

1. On the home screen, tap **AI와 1v1 대결** to search for RepBot.
2. Continue from the versus screen to pose setup and allow camera access.
3. Secure the phone on the floor in front of you, screen facing you. Face the camera in a push-up position and adjust the distance until your head, both shoulders, elbows, and wrists are detected.
4. Hold a valid setup pose for about 1.5 seconds, then remain ready during the three-second automatic countdown.
5. Perform push-ups during the 60-second battle. Start with extended arms, lower your body, and return to the top. Counted reps increase your score; rejected attempts show feedback.
6. At time-up, check the result and statistics. Return home to see the updated latest match and best record, or start another match.

## Current limitations

- **No real PvP or network synchronization:** `BotMatchmaker` selects RepBot and `BotOpponent` generates local rep events. The opponent is not a remote camera feed or a trained exercise model.
- **No login, database, or persistent history:** `InMemoryUserRepository` starts with sample profile/record data. Changes are lost when the app process restarts.
- **Push-ups only:** additional exercises are not implemented.
- **Limited front-view judging:** setup checks visible upper-body landmarks, not full-body form. Knees and hips are not required, so the judge cannot reliably distinguish knee push-ups or assess torso sagging. Unusual camera placement and unrelated movements may produce incorrect counts.
- **Device-dependent detection and sound:** counting depends on lighting, framing, and landmark confidence. Rep beeps use Android media volume and may be quiet on some devices.
- **No post-match coaching or rep timeline:** these are separate from the current live rejection feedback and result statistics.

## Checks and tests

From `gymrats_app/`:

```sh
flutter analyze
flutter test
```

The test suite covers pose/setup rules, rep judging, bot behavior, repositories, view models, widgets, and navigation. Automated tests do not replace a physical-device camera check.

## Repository layout

```text
gymrats_app/
  lib/main.dart             Integrated app entry point and navigation
  lib/screens/              Home, matching, versus, setup, battle, result
  lib/viewmodels/           Screen state and battle/counting coordination
  lib/services/pose/        Camera, ML Kit estimator, setup checker, rep judge
  lib/services/matching/    Matchmaker interface and local bot matching
  lib/services/opponent/    Opponent interface and simulated rep events
  lib/services/user/        Repository interface and in-memory records
  lib/models/               Battle, match, pose, and rep data
  lib/demo/                 Standalone development entry points
  test/                     Unit and widget tests
```

## Documentation

- [Project Wiki](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki)
- [Design Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Design-Documentation)
- [App development notes and standalone demos](gymrats_app/README.md)
