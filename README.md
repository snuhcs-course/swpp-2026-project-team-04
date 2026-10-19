# GymRats

GymRats is a Flutter Android app for camera-based exercise battles. This integration combines online avatar battles, authentication/history, 30-second rounds, phone-placement checks, and on-device form feedback. The video below is the historical Iteration 1 demo.

The main app requires a signed-in account. Online battles require two different accounts and the team API/WSS server. The lower AI battle button uses local RepBot; the primary button starts online matching. Choose one of four avatars from the profile button.

The integrated server defaults to 30-second rounds and accepts the expanded form/phone-motion rejection reasons. Deploy this server version before testing those rules online; the client follows the duration actually supplied by the server. Source integration and local APK builds do not deploy the server.

## Demo video

[Watch or download the Iteration 1 demo](demo-videos/iteration-1-demo-video.mp4)

This is a low-resolution copy of the original demo recording.

## Implemented features

- **Home:** authenticated user profile, avatar selection, best record, latest match, and saved form feedback.
- **Matching and versus:** FIFO online matching with real opponent information, or simulated matching with RepBot. Online pose setup starts after matching.
- **Online avatars:** bundled rigged avatars follow the opponent's joint coordinates. No camera video or audio is sent.
- **Pose setup:** camera preview, landmark overlay, framing and visibility checks, and an automatic countdown after holding a valid pose.
- **Rep judging:** Google ML Kit pose detection and a Dart state machine using head depth, arm extension, shoulder tilt, and timing. Counted reps and rejection reasons appear on screen.
- **Battle:** a 30-second timer, both scores, an animated opponent mannequin, live feedback, and an Android beep for each counted rep.
- **Results:** win/loss/draw, final scores, valid/rejected rep counts, and the proportion of judged reps that counted. Users can return home or match again.
- **Session records:** completed AI matches use the authenticated history repository. Online scores/results are server-authoritative; this branch does not add online result persistence to the history API. Leaving early does not create a completed form report.

## Getting started

### Prerequisites

- Flutter SDK with Dart **3.13.4 or a compatible 3.x version**, as required by `gymrats_app/pubspec.yaml`.
- Android Studio / Android SDK and a configured Android toolchain. The Android project targets Java 17.
- An Android phone with **Android 7.0 / API 24 or newer**, a camera, and USB debugging enabled. Accept the USB debugging authorization prompt.

A physical Android phone is recommended for exercise testing. The main app runs in portrait orientation.

### Run the integrated demo

```sh
git clone https://github.com/snuhcs-course/swpp-2026-project-team-04.git
# Check out the integration branch after it has been published, or use the existing local integration checkout.
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

1. Sign in. For the AI walkthrough, tap the lower **AI와 1v1 대결** button to search for RepBot. The primary **온라인 1v1 대결** button instead queues for a real player.
2. Continue from the versus screen to pose setup and allow camera access.
3. Secure the phone on the floor in front of you, screen facing you. Face the camera in a push-up position and adjust the distance until your head, both shoulders, elbows, and wrists are detected.
4. Hold a valid setup pose for about 1.5 seconds, then remain ready during the three-second automatic countdown.
5. Perform push-ups during the 30-second battle. Start with extended arms, lower your body, and return to the top. Counted reps increase your score; rejected attempts show feedback.
6. At time-up, check the result and statistics. Return home to see the updated latest match and best record, or start another match.

## Current limitations

- **AI practice is simulated:** `BotMatchmaker` selects RepBot and `BotOpponent` generates local rep events. Online mode instead exchanges avatar pose coordinates through WSS.
- **Local-only preferences and coaching:** avatar selection is saved per account on this device; form reports are device-local files, not cross-device records. Online battle history persistence remains separate backend work.
- **Push-ups only:** additional exercises are not implemented.
- **Limited front-view judging:** setup requires the upper body with straight arms, a phone propped at 60° or steeper and sitting still, and refuses an upright body when the hips are visible. During the round, a lean or a shake of the phone drops that rep. Knee push-ups are rejected from a personal hip angle taken at a straight-arm top, or from a default angle when that top never appears. A cat pose (hips folded, arms never bent, head at the bottom) is told to bend the arms. Belly and wall push-ups are rejected only when the hips are seen. From the front those parts are often hidden, and then the rep is judged on head depth alone. A push-up that reaches depth and locks out still counts when the descent was fast. An attempt that returns to the top in under a tenth of a second is dropped as tracking noise, with no count and no message. The thresholds are not yet tuned on devices. Unusual camera placement and unrelated movements may produce incorrect counts.
- **Device-dependent detection and sound:** counting depends on lighting, framing, and landmark confidence. Rep beeps use Android media volume and may be quiet on some devices.
- **Form feedback stays on the phone:** each finished battle's measurements are saved as a file on the device (newest 20), and the feedback screen computes its rule findings from them. The rules cover rejected reps, left-right balance while the head is down, a loss of depth late in the round, descents that reached the bottom too quickly, elbows flared out past the shoulders, hands planted much wider than the shoulders, and the head dropping ahead of shoulders that themselves moved. A small extra from the floor camera, an elbow tucked across the chest, or a merely wide grip stays quiet. A rule with too little data stays quiet. None of those last three change the count. Each fault shows a prepared side-view example, about 2.5 seconds, that loops until it is tapped. Knees are on the floor only in the knee example. Nothing is uploaded, and reinstalling the app deletes the saved reports.

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
  lib/screens/              Home, matching, versus, setup, battle, result, feedback
  lib/viewmodels/           Screen state and battle/counting coordination
  lib/services/pose/        Camera, ML Kit estimator, setup checker, rep judge
  lib/services/feedback/    Form reports and the rules that read them
  lib/services/device/      Beeps, screen-on, and phone placement
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
