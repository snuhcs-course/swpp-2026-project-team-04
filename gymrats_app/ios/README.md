# iOS build (not in the team plan; Android stays the target)

Added on `feat/ios_build` (2026-11-19, PM agreed) so the app can be installed on an iPhone for testing.
Checked on an iPhone with iOS 26 (setup, camera, pose detection).

## What iOS needs that Android does not

- `Runner/AppDelegate.swift`: the iOS side of the `gymrats/device` (beep, keep screen on, files folder) and `gymrats/gravity` (gravity + gyro, sent in Android's units and axes) channels that `MainActivity.kt` answers on Android.
- `lib/services/pose/camera_service.dart`: BGRA frames on iOS, a fixed quarter turn, and `iosFramesMirrored` for the front camera.
- `lib/services/pose/pose_estimator.dart`: the iOS ML Kit plugin ignores the rotation, so iOS frames are turned upright (and the front camera un-mirrored) before detection.
- `lib/widgets/pose_camera_view.dart`: the iOS preview arrives lying down and is turned upright.
- `Runner/Info.plist`: display name GymMouse, camera usage text, portrait only. `Podfile` / project: iOS 15.5 minimum (ML Kit), `PERMISSION_CAMERA=1` for permission_handler.

## Build and install (Mac only)

1. Xcode that supports the iPhone's iOS (iOS 26 needs Xcode 26 or later), `xcodebuild -downloadPlatform iOS`, `brew install cocoapods`.
2. Xcode > Settings > Accounts: add an Apple ID. In `Runner.xcworkspace` > Runner > Signing & Capabilities pick your team and, with a free Apple ID, a bundle ID of your own (the repo keeps `com.gymrats.gymratsApp` and no team).
3. Pair the iPhone (cable, or Wi-Fi: `xcrun devicectl manage pair --device <id>`), turn on Developer Mode.
4. `flutter run --release -d <iPhone>` from `gymrats_app/`. On the phone, trust the developer profile once (Settings > General > VPN & Device Management).

A free Apple ID's install expires after 7 days. Other people without a Mac need TestFlight (paid Apple Developer account).
