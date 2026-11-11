# GymMouse

GymMouse is an Android app that turns push-ups and squats into a 30-second, real-time 1v1 battle. The phone stands on the floor in front of you, and its camera counts your reps with an on-device pose model, so video never leaves the phone. You are matched with another player online, or play against the AI rival RepBot at a level you choose, and you see your opponent as a 3D avatar that copies their real movement. Every rep is graded and scored, a fever time doubles the points, and a big enough lead ends the round by KO. After each push-up battle, a form report tells you what to fix.

This branch, `iteration-3-demo`, holds the code shown in the **Iteration 3 demo** (pull requests #13 to #37 merged, `main` at `6fbc533`). The team server runs the server code of this commit (unchanged since `e6b16fe`, deployed 2026-11-03), so you only need to install the app.

## Demo video

[Watch or download the Iteration 3 demo (2 min 1 s, 720p)](demo-videos/iteration-3-demo-video.mp4)

Recorded on 2026-11-04: a push-up battle against RepBot on one phone, then an online squat battle on two phones.

| Time (approx.) | What you see |
|---|---|
| 0:00 | Sign-up, then the rules pages (how points, combo and fever work) |
| 0:12 | Home → **AI 1v1** → push-up → bot level **초보** (beginner) |
| 0:16 | Matching with RepBot, the versus screen and the safety reminder |
| 0:22 | Pose setup, then the push-up battle: health bar, **Good / Excellent +N**, combo, **FEVER ×2** |
| 0:58 | **TIME UP**, 100 : 80, win |
| 1:03 | Form feedback with side-view examples, then the result screen |
| 1:12 | Home → **온라인 1v1** → squat on two phones: match found, versus screen |
| 1:20 | Squat pose setup on both phones ("Hold still…") |
| 1:25 | The online squat battle: your camera below, the opponent's SOMA avatar above |
| 1:58 | Result on both phones: 승리 (win) 490 : 470 and 패배 (loss) |

Earlier demos: [Iteration 2 (1 min 47 s)](demo-videos/iteration-2-demo-video.mp4), [Iteration 1](demo-videos/iteration-1-demo-video.mp4).

## What Iteration 3 adds

| Feature | What you can do | PR |
|---|---|---|
| **Battle game** | Every battle is a tug of war on a health bar that starts at 50:50. A counted rep is **Good +10** or **Excellent +15** (deep enough), a rep rejected for depth but with the elbows at 120° or less is **Average +5**, and a rep within 1.5 s of the previous one adds a **combo +5**. From 20 s to the end every point counts **×2 (fever)**. Falling 60 points behind flashes the edge of the screen red, and a 100-point gap ends the round at once by **KO**. At time-up the higher score wins, then the higher rep count, else a draw. Same rules against RepBot and online; online, the server keeps the clock and the score. | #20, #23 |
| **Bot difficulty** | Before an AI battle, choose **초보 · 중수 · 고수** (beginner, intermediate, expert). "다시 매칭" on the result screen keeps the level. | #24 |
| **Squats** | A second exercise with its own rep judge (hip and knee depth, with Excellent for a deep squat), against RepBot or online. Players are matched per exercise, and the setup screen tells you to stand 2 to 3 m from the phone. | #19, #17, #27 |
| **Push-up judge accuracy** | The judge was re-tuned on recorded push-up sets (knee, belly, half-rep and wall cases), and 32 labelled recordings from the four of us form the frozen AI module test set with its replay runner. The first run on it (count accuracy 46 %, rejection 91 %, right reason 57 %) led to four more judge rules; on the same set they bring count accuracy to 79 % (rejection 91 %, right reason 60 %). | #22, #16, #30, #31, #32 |
| **SOMA avatars** | Three sportswear avatars (navy training, coral active, sage studio) in Profile. The opponent's avatar is shown from a 45° side view on a push-up rig, so depth is visible. | #25, #26 |
| **Rules and safety** | The game rules open as pages right after sign-up and from **?** on Home. A safety reminder appears when a match is found. | #21, #15 |
| **Score history** | The recent-battle card on Home, the **기록** (history) tab and the personal best now show game points, with the reps beside them. Squat battles against RepBot are saved too. | #28 |
| **Home** | Home leads with two cards, **온라인 1v1** and **AI 1v1**. Tapping one asks for the exercise (push-up or squat, each with your personal best), then goes to the online lobby or to the difficulty sheet. | #29 |
| **CI** | Every pull request runs the app and server tests with coverage. | #14 |

Still from Iterations 1 and 2: accounts, the online lobby and matching, camera pose setup, ML Kit rep counting, the result screen, form feedback for push-ups, and history with saved feedback.

### Next: Iteration 4

- Form feedback for squats
- Tuning the Excellent depth and the bot levels from the heuristic evaluation and user tests
- UI fixes from the heuristic evaluation: bigger cues on the setup and battle screens for a phone 50–100 cm away, a body silhouette on the camera view, shorter rules with a form tutorial, one header style and standard dialog buttons

## How it works

![System architecture](https://raw.githubusercontent.com/wiki/snuhcs-course/swpp-2026-project-team-04/images/architecture/system-architecture.png)

- **On the phone:** the camera, Google ML Kit pose detection (33 landmarks) and our rep judges (push-up and squat) run on the phone, together with the gravity sensor and gyroscope checks. The phone grades each rep, keeps the score in a bot battle, and builds the form report.
- **Battle server** (Dart, WebSocket at `/ws/v1/battle`): one queue per exercise, pairs players, syncs the start, relays rep events and pose keypoints (at most 10 frames per second) between the two phones, keeps the clock, the grades and the score, decides fever and KO, and posts the result with both players' points to the REST API. The message contract is [docs/iteration-2-protocol.md](docs/iteration-2-protocol.md) and the game rules are [docs/iteration-3/battle-rules.md](docs/iteration-3/battle-rules.md).
- **REST API** (Django REST Framework at `/api/`, SQLite): accounts with JWT log-in, profile with per-exercise bests, match history with points and saved form reports.
- Both go through nginx with an IP-address HTTPS certificate on one Lightsail instance. Camera frames, images and audio never leave the phone.

The full design is in the [Design Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Design-Documentation).

## Technology stack

| Part | Stack |
|---|---|
| Android app | Flutter (Dart `^3.13.4`), MVVM with Provider · `camera` · `google_mlkit_pose_detection` · `webview_flutter` with bundled three.js for the 3D avatars · `fl_chart` · `http` · `flutter_secure_storage` · `permission_handler` |
| Battle server | Dart (`dart:io` WebSocket), run by systemd |
| REST API | Python 3.12 · Django 5.2.7 · Django REST Framework 3.16.1 · SimpleJWT 5.5.1 · bcrypt · gunicorn · SQLite |
| Hosting | AWS Lightsail (Seoul) · nginx · Let's Encrypt IP certificate, renewed by a systemd timer |
| Tests | `flutter_test` and `fake_async` · pytest, pytest-django and pytest-cov · GitHub Actions on every pull request |

## Development environment

| Part | Requirements |
|---|---|
| App | Flutter SDK with Dart 3.13.4 or a compatible 3.x (we used Flutter 3.47.5), Android Studio with the Android SDK, Java 17 |
| Phone | Android 7.0 (API 24) or newer with a front camera and USB debugging on. A real phone is needed for exercise; the app runs in portrait. Tested on Samsung Galaxy S22, S23 and S25. |
| Online battle | Two phones, each signed in with a different account, and an internet connection |
| Server | Nothing to set up: the app uses the team server at `https://52.78.38.225`, deployed from this commit on 2026-11-03. To run the API yourself, see [server/README.md](server/README.md). |

## Run the demo

### 1. Get the code

```sh
git clone https://github.com/snuhcs-course/swpp-2026-project-team-04.git
cd swpp-2026-project-team-04
git checkout iteration-3-demo
```

### 2. Install the app

```sh
cd gymrats_app
flutter pub get
flutter devices
flutter run -d <device-id>
```

Grant camera access when asked. For an APK instead, run `flutter build apk --release`; it is written to `gymrats_app/build/app/outputs/flutter-apk/app-release.apk`. The heuristic-evaluation APK was built this way from the app code of this commit.

### 3. Try the flows

1. **Sign up.** Tap **처음이신가요? 회원가입**. The ID is 4 to 20 lowercase letters, digits or `_`, the nickname 1 to 12 characters, and the password 8 to 64 characters. The rules pages open once after sign-up; **?** on Home shows them again.
2. **Place the phone.** For push-ups, stand it on the floor in front of where your head will be, screen facing you, propped at 60° or steeper. For squats, stand 2 to 3 m away so your whole body is in the frame. Do not touch the phone during the round.
3. **Battle RepBot (one phone).** On Home, tap the **AI 1v1** card, pick **푸쉬업** or **스쿼트**, then **초보**, **중수** or **고수**. After the safety reminder and the pose setup ("Ready! Press Start."), the round starts by itself in 3 s. Watch the health bar, the **Good / Excellent / Average +N** labels, the combo, **FEVER ×2** at 20 s, and a KO if you pull 100 points ahead (or fall behind).
4. **Battle a person (two phones).** On both phones, tap the **온라인 1v1** card and pick the same exercise. After matching, both players set up the same way, and the battle starts when both are ready. The opponent appears as their avatar from a 45° view.
5. **See the result and feedback.** The result screen shows both scores and the reason (time-up or KO). For a push-up battle, tap **자세 피드백 보기** for the form report. **홈으로** returns to Home, where the recent-battle card shows the points; the **기록** tab lists every battle, and tapping one reopens its feedback.
6. **Change your avatar.** In Profile, pick one of the three SOMA outfits.

## Tests and checks

| Part | From | Command | Last result (2026-11-03, `6fbc533`, app code unchanged since `f03a460`) |
|---|---|---|---|
| App | `gymrats_app/` | `flutter analyze` and `flutter test` | no issues; 1476 passed, 10 skipped |
| AI module test | `gymrats_app/` | `flutter test test/ai_eval` (report in `build/ai_eval/report.md`) | M1 79.4 %, M2 90.8 %, M3 59.9 % on the frozen 32-case set (thresholds 90 / 90 / 80 %; tuned on the same set, see the Testing Documentation 5) |
| REST API | `server/` | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` | 101 passed |
| Battle server | `gymrats_app/` | `flutter test test/services/online/` (part of the app run) | included above |
| Coverage by layer | CI | GitHub Actions on each pull request (`Flutter coverage` shards, `Django API`) | per-layer table in the [Testing Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Testing-Documentation) |

Setup, commands, the AI module test on the recorded push-up sets, and the full results are in the [Testing Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Testing-Documentation). Automated tests do not replace a check on a real phone.

## Known limitations

- Form feedback exists for push-ups only; a squat battle has no feedback screen.
- The Excellent depth (1.6 × the pass depth) and the three bot levels are first values, to be tuned after the heuristic evaluation.
- The push-up judge misses the targets of the AI module test (count accuracy 79 % against 90 %); belly-down reps and some far placements are still misjudged, and the latest rules were tuned on the same recordings they are measured on.
- The phone judges its own reps, and the server trusts that judgment.
- Judging from the front: when the hips are out of view, belly and wall push-ups cannot be told apart, and the rep is judged on head depth alone.
- The exercise sheet reads your personal best when it opens, so right after a battle it can show the previous best until it is opened again.
- If the server cannot be reached, unsent matches wait in memory and are lost if the app is closed.
- Apps built before this iteration cannot read squat records from the server; install this build.

## Repository

| Folder | Contents |
|---|---|
| `gymrats_app/` | The Flutter app (`lib/`), its tests (`test/`) and the recorded push-up sets for the AI module test (`test/ai_eval/`) |
| `server/` | The Django REST API, the Dart battle server (`lib/`, `bin/`), their tests and the deployment files (`deploy/`) |
| `docs/` | The battle protocol, the Iteration 3 game rules and squat design, the testing notes and the AI collaboration notes |
| `tools/` | The per-layer coverage script, Android diagnostics and the avatar preview |
| `demo-videos/` | Demo videos for each iteration |

Branches: `main` holds the integrated code. Each task is a branch from `main` that comes back through a pull request, checked by CI, reviewed first by an AI agent and then by the PM, who merges it in the order of the team plan. `iteration-N-demo` holds the code shown in that iteration's demo.

## Documents

- [Requirements and Specifications](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Requirements-and-Specifications)
- [Design Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Design-Documentation)
- [Testing Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Testing-Documentation)
- [AI Collaboration Report – Iteration 3](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/AI-Collaboration-Report-%E2%80%93-Iteration-3)
- [Meeting Logs](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Meeting-Logs)

## Team

SWPP 2026 Team 4: Jinyoung Park (PM in Iteration 3: merge order and reviews, AI module evaluation, server deployment, heuristic evaluation, documents), Woohyun Song (battle game, rules screen, safety reminder, bot difficulty, score history, Home), Hyunwoo Song (push-up recordings and judge accuracy), Sangwoo Hahn (squat judge and squat battles, per-exercise matchmaking, SOMA avatars, opponent view).
