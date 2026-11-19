# GymMouse

GymMouse is an Android app that turns push-ups and squats into a 30-second, real-time 1v1 battle game. The phone stands on the floor in front of you, and its camera counts your reps with an on-device pose model, so video never leaves the phone. Home is a game lobby where your character works out. You pick one of five characters (GYM마우스, 그루, 곰탱이, 펭뚱이, 물렁범), then battle the AI rival RepBot at one of three levels or another player online, in push-ups or squats. The battle plays on a fighting stage: every rep is graded **Good**, **Excellent** or **Average** and pushes the health bar, quick reps build a combo, the last 10 seconds are a **fever** that doubles the points, and a 100-point lead ends the round by **K.O.** After the battle, a game report compares it with your earlier battles, your character talks you through the round and gives you a mission for the next one, and the archive (기록보관소) shows your statistics over time.

## Demo video

[Watch or download the Iteration 4 demo (3 min 15 s, 334 × 720 portrait)](demo-videos/iteration-4-demo-video.mp4)

Recorded on 2026-11-18 on the release build of `main` at `7680df6` (the app code on `main` is unchanged since): an AI push-up battle against RepBot, then an online squat battle against another player.

| Time (approx.) | What you see |
|---|---|
| 0:00 | Log in and sign up |
| 0:16 | The tutorial pages (Good +10, Excellent +15) |
| 0:32 | Choosing a character |
| 0:40 | **게임 시작** → **AI 1v1** → push-up, level **중수** (intermediate) |
| 0:48 | Pose setup with the large two-line cue ("정면을 / 봐요") and the silhouette |
| 0:56 | The push-up battle against RepBot: health bar, **GOOD**, combo, **FEVER ×2** |
| 1:28 | The game report (a 130 : 135 loss) and the character's talk card |
| 1:36 | The character's talk |
| 1:52 | **게임 시작** with the mission sticker → **온라인 1v1** → squat |
| 2:00 | Match found, versus another player |
| 2:08 | Squat setup cues ("머리·무릎이 / 안 보여요", then "그대로 / 멈춰요" in a green frame) |
| 2:24 | The online squat battle (+20 in fever, combos) |
| 2:48 | **K.O.** win |
| 2:56 | The character offers the next missions |
| 3:12 | 기록보관소 (the archive) |

Earlier demos: [Iteration 3 (2 min 1 s)](demo-videos/iteration-3-demo-video.mp4), [Iteration 2 (1 min 47 s)](demo-videos/iteration-2-demo-video.mp4), [Iteration 1](demo-videos/iteration-1-demo-video.mp4).

## What Iteration 4 adds

| Feature | What you can do | PR |
|---|---|---|
| **Game lobby and Home** | Home is a game lobby in a new light theme, with four menu rows: **게임 시작** (online or AI battle, or play again with the latest setup), **캐릭터**, **기록보관소** and **환경설정** (nickname, sound switches, the tutorial, logout). The AI 1v1 page picks the exercise and the level (**초보 · 중수 · 고수**) in one place. Your chosen character does its exercise in the middle of Home; tap it to change character. | #45, #55 |
| **Battle on a fighting stage** | Bot and online battles play on one stage: two fighters meet at a point that moves with the score, with names, clock, scores and valid reps above. Each rule shows as an effect: GOOD / EXCELLENT / AVERAGE then "+N", "N HIT" combos, FEVER ×2, a red danger edge, a reject sign for a rep that earned nothing, K.O. and TIME!. New radar and MATCH FOUND screens show both characters face to face. After a win, your character celebrates in a victory scene on the report (KO 승리, 판정승, 기권승); after a loss or a draw it slumps. The game rules and points are unchanged. | #50, #54, #68 |
| **Characters** | Six drawn characters replace the 3D avatars: you choose one of five on the 캐릭터 선택 screen (GYM마우스, 그루, 곰탱이, 펭뚱이, 물렁범), and RepBot is the AI rival. The choice is saved per account and fights on the stage; online, the opponent sees your character. | #52 |
| **Sound** | Music for the menu, the setup and the battle (faster in fever), win and lose jingles, hit sounds by grade, a buzz for a rep that earned nothing, an alarm while you are 60 points behind and a gong at a K.O. **효과음** in 환경설정 turns music and effects on or off. A voice-guidance service with Korean lines (the phone's text-to-speech) was added too, but after the phone check the setup and the battle speak no lines. | #48, #53 |
| **Pose setup** | A body silhouette on the camera for push-ups and squats; the battle starts by itself once your pose fits it for 3 s (online, you become ready by yourself), so there is no ready button. Setup cues are two short lines in large type (e.g. "한 걸음 / 뒤로", "그대로 / 멈춰요") on a board above the camera, sized to be read from about 2.5 m, with a green or red frame around the camera. The joint dots are gone from the camera view. | #49, #51, #65, #70, #73, #77 |
| **Tutorial** | The rules pages become a 22-page tutorial (a game page, 11 push-up pages, 10 squat pages): setup, grades, combo, fever, K.O. and the report, with pictures. It opens after sign-up and from **?** on Home. | #60, #64 |
| **Game report and form feedback** | The result screen is a game report: the verdict, both scores, a new personal best, and your score against your recent battles. Squat battles now keep a form report too (shallow squats, not standing up, depth lost late in the round), and the form feedback screen shows depth, joint-angle and pace charts for both exercises. | #57, #62, #63 |
| **기록보관소 statistics** | The archive shows the last 7 days (reps, battles, streak), your score growth per exercise and the latest battles; any battle reopens its report. 기간별 통계 shows the average counted reps, a date–reps graph and your form issues for this week, this month or all time, per exercise. | #56, #61 |
| **Character talk and missions** | After a battle with a form report, your character talks you through it, one line at a time (your reps against recent battles, your pace, your biggest form problem and its fix, a piece of praise), then offers two goals for the next battle. The chosen goal becomes a **mission**: a "미션!" sticker on the exercise, a mission card at match found, a progress chip and "미션 성공!" in the battle, and a check in the next talk. The lines are built by rules from the battle's numbers, not by a language model. | #74, #76 |
| **Judges and AI evaluation** | AI and online squat battles use the same shared squat judge, and AI squat reports keep their depth over time. The push-up judge gets the calibration, short-cycle and joint-span work, plus a unified knee rule behind the build flag `PUSHUP_FRAME_KNEE` (off by default). A supplemental Iteration 4 evaluation set (16 recordings, 80 labelled reps, push-ups and squats) was added and scored. On the frozen 32-case set the default build keeps M1 79.4 %, M2 90.8 %, M3 59.9 % (targets 90 / 90 / 80 %). | #66, #69, #75, #78 |
| **Person check** | When someone walks behind you and the pose model starts following them, the game pauses scoring until you confirm your pose again. Off by default (`--dart-define=S2_PERSON_GUARD=true` turns it on). | #72 |
| **UAT build phone angle** | Builds made with `--dart-define=UAT_PHONE_ANGLE=true` show the phone's angle during setup, so testers can prop it at 60°. | #71 |
| **Fixes** | "Play again" on a past online battle reopens online matching even when the opponent's name looks like a bot. | #67 |

Still from Iterations 1 to 3: accounts, the online lobby and per-exercise matching, ML Kit rep counting, the battle game rules (health bar, grades, combo, fever, K.O.), the three bot levels, the safety reminder, and push-up form feedback.

### Next: Iteration 5

The team collected candidates at the 2026-11-18 meeting; the scope and owners are decided at the 2026-11-21 meeting.

- Sign-in with Kakao and Google, and a redrawn sign-up screen
- Friends and trophy-based matching, with a matching-latency and server load test
- Sharing the feedback, and a calendar-style record of your battles
- A daily single mode or quests
- A shorter tutorial
- A stricter silhouette check in the setup
- Push-up judge: fewer missed normal reps; squats: a reject reason for pushing off with the hands
- Trying an iOS build, and a release on One Store
- UAT cycle 2 on 2026-11-23, and the alpha test in class

## How it works

![System architecture](https://raw.githubusercontent.com/wiki/snuhcs-course/swpp-2026-project-team-04/images/architecture/system-architecture.png)

- **On the phone:** the camera, Google ML Kit pose detection (33 landmarks) and our rep judges (push-up and squat) run on the phone, together with the gravity sensor and gyroscope checks and the setup silhouette check. The phone grades each rep, keeps the score in a bot battle, builds the form report, writes the character's talk, and plays the music and sounds.
- **Battle server** (Dart, WebSocket at `/ws/v1/battle`): one queue per exercise, pairs players, passes each player's character id on to the opponent, syncs the start, relays rep events and pose keypoints (at most 10 frames per second) between the two phones, keeps the clock, the grades and the score, decides fever and K.O., and posts the result with both players' points to the REST API. Since the 3D avatars were removed, the stage draws the opponent's character from the server's reps and scores; the relayed keypoints are drawn only by a debug-only test screen. The message contract is [docs/iteration-2-protocol.md](docs/iteration-2-protocol.md) and the game rules are [docs/iteration-3/battle-rules.md](docs/iteration-3/battle-rules.md).
- **REST API** (Django REST Framework at `/api/`, SQLite): accounts with JWT log-in, profile with per-exercise bests, match history with points and saved form reports, and the statistics for the archive (`/matches/stats`).
- Both go through nginx with an IP-address HTTPS certificate on one Lightsail instance. Camera frames, images and audio never leave the phone.

The full design is in the [Design Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Design-Documentation).

## Technology stack

| Part | Stack |
|---|---|
| Android app | Flutter (Dart `^3.13.4`), MVVM with Provider · `camera` · `google_mlkit_pose_detection` · `just_audio` for the music and sounds · `flutter_tts` for the voice guidance · `fl_chart` · `http` · `flutter_secure_storage` · `permission_handler` |
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
| Server | Nothing to set up: the app uses the team server at `https://52.78.38.225`. It runs the server code of `main` (REST API and battle server redeployed on 2026-11-14; the server code has not changed since). To run the API yourself, see [server/README.md](server/README.md). |

## Run the demo

### 1. Get the code

```sh
git clone https://github.com/snuhcs-course/swpp-2026-project-team-04.git
cd swpp-2026-project-team-04
```

The demo was recorded on `main` at `7680df6`; the app code on `main` has not changed since.

### 2. Install the app

```sh
cd gymrats_app
flutter pub get
flutter devices
flutter run -d <device-id>
```

Grant camera access when asked. For an APK instead, run `flutter build apk --release`; it is written to `gymrats_app/build/app/outputs/flutter-apk/app-release.apk`. A ready-built APK from the in-class UAT (a release build that also shows the phone angle during setup) is at [gymmouse-uat.apk](https://github.com/snuhcs-course/swpp-2026-project-team-04/releases/download/uat-build/gymmouse-uat.apk); open it on the phone and allow installing from that source. The file is replaced when the team publishes a newer UAT build.

### 3. Try the flows

1. **Sign up.** Tap **처음이신가요? 회원가입**. The ID is 4 to 20 lowercase letters, digits or `_`, the nickname 1 to 12 characters, and the password 8 to 64 characters. The tutorial opens once after sign-up; **?** on Home shows it again.
2. **Pick a character.** On Home, tap **캐릭터** (or the character itself) and choose one of the five.
3. **Place the phone.** For push-ups, stand it on the floor in front of where your head will be, screen facing you, propped at 60° or steeper. For squats, stand 2 to 3 m away so your whole body is in the frame. Do not touch the phone during the round.
4. **Battle RepBot (one phone).** Tap **게임 시작** → **AI 1v1**, pick **푸쉬업** or **스쿼트** and **초보**, **중수** or **고수**, then **대결 시작**. After the versus screen and the safety reminder, fit your body into the silhouette and follow the cue board; once your pose holds, the stage counts 3, 2, 1 and the round starts by itself. Watch the health bar, the grades, the combo, **FEVER ×2** in the last 10 s, and a K.O. if one player pulls 100 points ahead.
5. **Battle a person (two phones).** On both phones, tap **게임 시작** → **온라인 1v1** and pick the same exercise. After matching, both players set up the same way; each becomes ready by holding the pose, and the server starts the round when both are ready. The opponent appears as their character.
6. **Read the report and talk to your character.** The game report shows the verdict, both scores and your recent battles. Tap **이야기 듣기** for the character's talk and pick a mission for the next battle, or **자세 기록 표로 보기** for the form feedback charts. **다시 대결** starts the same kind of battle; **홈으로** returns to Home.
7. **See your records.** **기록보관소** on Home shows the last 7 days, your score growth and the latest battles; tap a battle to reopen its report, or **기간별 통계** for the statistics by period.

## Tests and checks

| Part | From | Command | Last result (`main` at `7680df6`, 2026-11-18; CI, except the AI module test run by the PM) |
|---|---|---|---|
| App | `gymrats_app/` | `flutter analyze` and `flutter test` | no issues; 3758 passed, 10 skipped |
| AI module test | `gymrats_app/` | `flutter test test/ai_eval` (report in `build/ai_eval/report.md`) | Frozen 32-case set, default build: M1 79.4 %, M2 90.8 %, M3 59.9 % (thresholds 90 / 90 / 80 %). Supplemental Iteration 4 set (16 cases): 56.7 / 84.0 / 44.0 % with the knee rule off, 70.0 / 90.0 / 50.0 % with it on |
| REST API | `server/` | `.venv/bin/python -m pytest --cov=accounts --cov=matches --cov=gymrats` | 114 passed, 96 % coverage |
| Battle server | `gymrats_app/` | `flutter test test/services/online/` (part of the app run) | included above |
| Coverage by layer | CI | GitHub Actions on each pull request (`Flutter coverage` shards, `Django API`) | Model 99.4 %, ViewModel 98.1 %, Service 95.5 %, View 98.0 % (targets 90 / 90 / 85 / 75 %); details in the [Testing Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Testing-Documentation) |

Setup, commands, the AI module test on the recorded sets, the acceptance tests (UAT cycle 1: 73 of 74 steps accepted) and the full results are in the [Testing Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Testing-Documentation). Automated tests do not replace a check on a real phone.

## Known limitations

- The push-up judge misses the targets of the AI module test (count accuracy 79 % against 90 % on the frozen set, 57 % on the new Iteration 4 set with the default build). The knee rule that raises it on the new set lowers the rejection rate on the frozen set, so it stays off until Iteration 5 decides.
- The setup can start before the body really matches the silhouette (found in UAT cycle 1).
- The person check (`S2_PERSON_GUARD`) is off by default: on a blurred video it raised a false warning that paused the counting. With it off, a person standing behind you can be tracked instead of you.
- The Excellent depth (1.6 × the pass depth) and the three bot levels are still the first values; testers found the AI battle too easy.
- The phone judges its own reps, and the server trusts that judgment.
- Judging from the front: when the hips are out of view, belly and wall push-ups cannot be told apart, and the rep is judged on head depth alone.
- If the server cannot be reached, unsent matches wait in memory and are lost if the app is closed.

## Repository

| Folder | Contents |
|---|---|
| `gymrats_app/` | The Flutter app (`lib/`), its tests (`test/`) and the recorded push-up and squat sets for the AI module test (`test/ai_eval/`) |
| `server/` | The Django REST API, the Dart battle server (`lib/`, `bin/`), their tests and the deployment files (`deploy/`) |
| `docs/` | The battle protocol, the Iteration 3 game rules and squat design, the Iteration 4 judge, sound and person-check notes, the testing notes and the AI collaboration notes |
| `tools/` | The per-layer coverage scripts, the CI test report and the pose and judge diagnostics |
| `demo-videos/` | Demo videos for each iteration |

Branches: `main` holds the integrated code. Each task is a branch from `main` that comes back through a pull request, checked by CI, reviewed first by an AI agent and then by the PM, who merges it in the order of the team plan. `iteration-N-demo` holds the code shown in the demos of Iterations 1 to 3.

## Documents

- [Requirements and Specifications](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Requirements-and-Specifications)
- [Design Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Design-Documentation)
- [Testing Documentation](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Testing-Documentation)
- [AI Collaboration Report – Iteration 4](docs/ai-collaboration/AI-Collaboration-Report-Iteration-4.md)
- [Meeting Logs](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Meeting-Logs)

## Team

SWPP 2026 Team 4: Hyunwoo Song (PM in Iteration 4: merge order and merges, the AI module re-runs and the Iteration 4 set's labels, the course documents, publishing the demo video), Woohyun Song (game lobby, fighting stage, characters, game report, archive screens, form feedback screen, victory scene, readable setup cues, character talk and missions), Jinyoung Park (voice guidance, battle music and sounds, archive statistics, squat form feedback, tutorial), Sangwoo Hahn (setup silhouettes and auto start, the shared squat judge, push-up judge, person check, UAT phone angle, the Iteration 4 evaluation set).
