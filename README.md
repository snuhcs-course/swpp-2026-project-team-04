# GymRats

GymRats is an Android app that turns push-ups into a 30-second, real-time 1v1 battle. The phone stands on the floor in front of you, and its camera counts your reps with an on-device pose model, so video never leaves the phone. You are matched with another player online, or play against the AI rival RepBot, and you see your opponent as a 3D avatar that copies their real movement. After each battle, a form report tells you what to fix.

This branch, `iteration-2-demo`, holds the code shown in the **Iteration 2 demo** (pull requests #6 to #11 merged). The app talks to the team server, which is already running, so you only need to install the app.

## Demo video

[Watch or download the Iteration 2 demo (1 min 47 s)](demo-videos/iteration-2-demo-video.mp4)

Recorded on two phones playing each other online:

| Time (approx.) | What you see |
|---|---|
| 0:00 | Sign-up |
| 0:12 | Choosing an avatar in Profile |
| 0:18 | Home → **온라인 1v1 대결** (online 1v1 battle) |
| 0:24 | Matching on both phones |
| 0:30 | Pose setup: framing hints until "Ready! Press Start." |
| 0:54 | The battle: your camera and score below, the opponent's avatar above |
| 1:24 | Result (win / loss) |
| 1:30 | Form feedback with side-view examples and a depth chart |
| 1:42 | The per-rep record |

The Iteration 1 demo (AI battle only) is in [demo-videos/iteration-1-demo-video.mp4](demo-videos/iteration-1-demo-video.mp4).

## What Iteration 2 adds

| Feature | What you can do | PR |
|---|---|---|
| **Accounts** | Sign up with a nickname, ID and password, stay logged in, and log out. | #6 |
| **Online 1v1 battle** | Match with the next player waiting on the server (first come, first served). Both scores update live, and the server decides the result. Leaving after the start is a forfeit, and not reconnecting within 10 s is a loss. | #8 |
| **Opponent avatars** | Pick one of 25 3D avatars in Profile (search, category filter, preview). During a battle the opponent appears as their avatar, moved by their joint coordinates; no camera video or audio is sent. | #8 |
| **30-second rounds** | Every battle, online or against RepBot, lasts 30 s. | #7 |
| **Fair rep judging** | Setup checks the phone is propped at 60° or steeper and still. During the round a lean or a shake of the phone drops that rep, and knee, belly, wall and "cat" push-ups are rejected with a reason on screen. | #7, #10 |
| **Form feedback** | After a battle: rejected reps by reason, left–right imbalance, loss of depth late in the round, fast descents, flared elbows, wide hands and the head dropping first, each with a side-view example and a fix, plus depth and elbow-angle charts and a per-rep record. | #7 |
| **History** | Home shows your best record and 3 latest battles; the **기록** (history) tab lists all of them. Tapping a battle reopens its form feedback, which is stored on the server. | #6, #9 |
| **Team server** | Django REST API and a Dart battle server on AWS Lightsail (Seoul), reached over HTTPS and WSS only. | #6, #8 |

Still from Iteration 1: the AI battle against RepBot, camera pose setup, ML Kit rep counting, and the result screen.

### Next: Iteration 3

- Measure push-up counting accuracy on real recordings (AI module testing)
- Clearer feedback, so a beginner knows exactly what to fix
- A tier system and tier-based matching
- A second exercise, such as squats

## How it works

![System architecture in Iteration 2](https://raw.githubusercontent.com/wiki/snuhcs-course/swpp-2026-project-team-04/images/architecture/system-architecture.png)

- **On the phone:** the camera, Google ML Kit pose detection (33 landmarks) and our rep judge run on the phone, together with the gravity sensor and gyroscope checks. The phone also builds the form report.
- **Battle server** (Dart, WebSocket at `/ws/v1/battle`): pairs players, syncs the start, relays rep events and pose keypoints (at most 10 frames per second) between the two phones, keeps the clock and score, and decides the result. The message contract is [docs/iteration-2-protocol.md](docs/iteration-2-protocol.md).
- **REST API** (Django REST Framework at `/api/`, SQLite): accounts with JWT log-in, profile, match history and saved form reports.
- Both go through nginx with an IP-address HTTPS certificate on one Lightsail instance. Camera frames, images and audio never leave the phone.

The full design is in the [Design Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Design-Documentation).

## Technology stack

| Part | Stack |
|---|---|
| Android app | Flutter (Dart `^3.13.4`), MVVM with Provider · `camera` · `google_mlkit_pose_detection` · `webview_flutter` with bundled three.js for the 3D avatars · `fl_chart` · `http` · `flutter_secure_storage` · `permission_handler` |
| Battle server | Dart (`dart:io` WebSocket), run by systemd |
| REST API | Python 3.12 · Django 5.2.7 · Django REST Framework 3.16.1 · SimpleJWT 5.5.1 · bcrypt · gunicorn · SQLite |
| Hosting | AWS Lightsail (Seoul) · nginx · Let's Encrypt IP certificate, renewed by a systemd timer |
| Tests | `flutter_test` and `fake_async` · pytest, pytest-django and pytest-cov |

## Development environment

| Part | Requirements |
|---|---|
| App | Flutter SDK with Dart 3.13.4 or a compatible 3.x (we used Flutter 3.47.5), Android Studio with the Android SDK, Java 17 |
| Phone | Android 7.0 (API 24) or newer with a front camera and USB debugging on. A real phone is needed for exercise; the app runs in portrait. |
| Online battle | Two phones, each signed in with a different account, and an internet connection |
| Server | Nothing to set up: the app uses the team server at `https://52.78.38.225`. To run the API yourself, see [server/README.md](server/README.md). |

## Run the demo

### 1. Get the code

```sh
git clone https://github.com/snuhcs-course/swpp-2026-project-team-04.git
cd swpp-2026-project-team-04
git checkout iteration-2-demo
```

### 2. Install the app

```sh
cd gymrats_app
flutter pub get
flutter devices
flutter run -d <device-id>
```

Grant camera access when asked. For an APK instead, run `flutter build apk --debug`; it is written to `gymrats_app/build/app/outputs/flutter-apk/app-debug.apk`.

### 3. Try the flows

1. **Sign up.** Tap **처음이신가요? 회원가입**. The ID is 4 to 20 lowercase letters, digits or `_`, the nickname 1 to 12 characters, and the password 8 to 64 characters.
2. **Place the phone.** Stand it on the floor in front of where your head will be, screen facing you, propped at 60° or steeper, and do not touch it during the round.
3. **Battle RepBot (one phone).** On Home, tap **AI와 1v1 대결**, then **자세 세팅 시작**. Get into the top of a push-up until head, shoulders, elbows and wrists are found. After "Ready! Press Start." the round starts by itself in 3 s, or tap **Start**. Do push-ups for 30 s.
4. **Battle a person (two phones).** On both phones, tap **온라인 1v1 대결**. After matching, both players set up the same way, and the battle starts when both are ready.
5. **See the result and feedback.** Tap **자세 피드백 보기** on the result screen, then **홈으로**. Home shows the new battle, and the **기록** tab lists every battle; tap one to open its feedback again.

## Tests and checks

| Part | From | Command | Last result |
|---|---|---|---|
| App | `gymrats_app/` | `flutter analyze` and `flutter test` | 675 passed, 1 skipped (10/23) |
| REST API | `server/` | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` | 76 passed, 96% line coverage |
| App coverage by layer | `gymrats_app/` | `flutter test --coverage`, then `python3 ../tools/coverage_by_layer.py coverage/lcov.info` | Model 95.8%, ViewModel 94.4%, Service 91.3%, View 91.7% (10/21) |

Setup, commands and the full results are in the [Testing Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Testing-Documentation). Automated tests do not replace a check on a real phone.

## Known limitations

- Push-ups only.
- The phone judges its own reps, and the server trusts that judgment.
- Judging from the front: when the hips are out of view, belly and wall push-ups cannot be told apart, and the rep is judged on head depth alone. The thresholds are not yet tuned across many phones.
- If the server cannot be reached, unsent matches wait in memory and are lost if the app is closed.
- During matching or setup, a busy phone can miss its "still connected" signal; enough misses make the server cancel the match. A fix is planned.

## Repository

| Folder | Contents |
|---|---|
| `gymrats_app/` | The Flutter app (`lib/`) and its tests (`test/`) |
| `server/` | The Django REST API, the Dart battle server (`lib/`, `bin/`), their tests and the deployment files (`deploy/`) |
| `docs/` | The battle protocol, the testing notes and the AI collaboration notes |
| `tools/` | The per-layer coverage script, Android diagnostics and the avatar preview |
| `demo-videos/` | Demo videos for each iteration |

Branches: `main` holds the integrated code. Each task is a branch from `main` that comes back through a pull request, reviewed first by an AI agent and then approved and merged by the PM. `iteration-N-demo` holds the code shown in that iteration's demo.

## Documents

- [Requirements and Specifications](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Requirements-and-Specifications)
- [Design Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Design-Documentation)
- [Testing Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Testing-Documentation)
- [AI Collaboration Report – Iteration 2](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/AI-Collaboration-Report-%E2%80%93-Iteration-2)
- [Meeting Logs](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Meeting-Logs)

## Team

SWPP 2026 Team 4: Woohyun Song (PM in Iteration 2: design, documents, reviews), Jinyoung Park (accounts, REST API, history and saved feedback), Hyunwoo Song (rep judging, phone placement, form feedback), Sangwoo Hahn (matching, battle server, online battle, avatars, HTTPS).
