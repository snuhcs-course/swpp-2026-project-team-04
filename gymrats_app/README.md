# GymRats app (Flutter, Android)

Flutter client for GymRats, a real-time 1v1 bodyweight exercise battle app.

**Current state (`feat/pose_setup`):** only the pre-match **pose setup** step is implemented.
Plain `flutter run` starts `lib/main.dart`, which is still a placeholder that shows only the text "GymRats".
To try pose setup, run the **demo entry point** described below.

## Prerequisites
- Flutter SDK with Dart 3.13.4 or newer (`flutter --version`).
- Android SDK (install Android Studio). Check with `flutter doctor`.
- An Android phone (Android 6.0 / API 23 or newer) with **Developer options > USB debugging** on, connected by a USB data cable. Accept the "Allow USB debugging?" prompt on the phone.
  No phone? See [Run on the emulator](#run-on-the-emulator-no-phone).

## Run the pose setup demo
```
git clone https://github.com/snuhcs-course/swpp-2026-project-team-04.git
cd swpp-2026-project-team-04
git checkout feat/pose_setup
cd gymrats_app
flutter pub get
flutter devices                                    # copy your phone's device id
flutter run -t lib/demo/pose_setup_demo.dart -d <device-id>
```
The `-t lib/demo/pose_setup_demo.dart` part is required. Without it you only see the "GymRats" placeholder.
The first build takes a few minutes. No server or login is needed.

## What you should see
1. **Choose an exercise:** tap **Push-up** (the only exercise for now).
2. Allow the camera permission.
3. The camera preview opens with **green dots** on body parts that are detected well and **red dots** on the rest.
4. Put the phone on the floor about 1 m in front of where your head will be, screen facing you, and get into push-up position **facing the camera**. Head, both shoulders, elbows, and hands must be in view.
5. The message at the bottom tells you what to fix:

| Message | Meaning |
|---|---|
| No one detected. Step into the camera view. | No person found |
| Move back a little. / Move closer to the camera. | Body too large / too small in the frame |
| Face the camera. | Body or head is turned sideways or away |
| Hands not visible. (or other parts) | Required body parts are out of frame |
| Hold still... | Pose is valid; hold it for 1.5 s |
| Ready! Starting in 3... | Ready. Stay still for 3 s and setup finishes by itself |

6. After the countdown, **"Setup complete: Push-up"** appears. You do not need to touch the phone; the **Start** button is only a shortcut.

Other behavior to check:
- Rotating the phone to landscape works; the preview and dots stay upright.
- Leaving the pose for more than 0.5 s cancels Ready and the countdown.
- The top-left button goes back, the top-right button switches between the front and back camera.

## Debug values
The demo prints the checker values to the log (nothing is drawn as text over the camera): reason, fps, hold timer, auto start countdown, orientation, and thresholds.
They appear in the `flutter run` terminal, or with:
```
adb logcat -s flutter | grep pose_setup
```
Example:
```
pose_setup | reason=ready fps=24 ready=true hold=1.5s/1.5s autoStart=2.0s/3.0s device=portraitUp sensor=270 frameRotation=270 screen=portrait
```

## Run on the emulator (no phone)
An Android emulator can use your laptop webcam as its camera (pose detection is slower there, about 10 fps).
```
~/Library/Android/sdk/emulator/emulator -list-avds             # pick an AVD name
~/Library/Android/sdk/emulator/emulator -webcam-list           # find your webcam, e.g. webcam0
~/Library/Android/sdk/emulator/emulator -avd <avd-name> -camera-front webcam0 &
flutter run -t lib/demo/pose_setup_demo.dart -d emulator-5554
```
Paths are for macOS; on Windows the SDK is usually under `%LOCALAPPDATA%\Android\Sdk`.

## Tests
```
flutter analyze
flutter test
```

## Code layout
```
lib/
  main.dart                          app entry (placeholder home for now)
  demo/pose_setup_demo.dart          standalone pose setup demo
  models/                            pose_frame, exercise_type
  services/pose/                     camera_service, pose_estimator (ML Kit), setup_checker (pure Dart rules)
  viewmodels/setup_viewmodel.dart    setup state, auto start countdown
  screens/setup_screen.dart          camera preview, landmark dots, status message
test/                                unit and widget tests for all of the above
```
The architecture follows the team wiki [Design Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Design-Documentation).
