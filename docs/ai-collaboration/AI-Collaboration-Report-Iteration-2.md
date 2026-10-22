# AI Collaboration Report: Iteration 2 (TODO(team): start date ~ end date)
Status: draft (iteration open). Updated after each task; condensed to one page when the iteration closes.
Written by: Jinyoung Park | Contributors: Jinyoung Park, TODO(team): other members
Tools used: Claude Code (Opus 5.5)

## 1. Where AI Was Used
- Match history with feedback, server side: `server/matches/` (models, migration 0002, `views.py`, `internal.py`),
  `server/tests/test_feedback.py`, `server/tests/test_results.py`, commit `98e3c3b`: Claude Code.
- P11 result storage in the battle server: `server/lib/result_store.dart`, P11 calls in `server/lib/battle_server.dart`,
  `server/bin/server.dart`, commit `98e3c3b`: Claude Code.
- App: feedback upload, 홈 | 기록 tabs, history rows, stored feedback screen (`gymrats_app/lib/screens/home_shell_screen.dart`,
  `match_feedback_screen.dart`, `viewmodels/feedback_viewmodel.dart`, `services/user/server_user_repository.dart`) and
  their tests, commit `98e3c3b`: Claude Code.
- Online auto ready after 3 s: `gymrats_app/lib/screens/online_battle_screen.dart`, commit `706694f`: Claude Code.
- Deploy to the team server (Django migrate, battle-server release, nginx): commands prepared by Claude Code; the
  production steps were run by the user.
- Not used: TODO(team): tasks done without AI this iteration.

## 2. Prompt History
[Jinyoung Park, 10-21] "Start the new GymRats task. … Follow the progress.md checklist in order, starting with phase 1
(server: P11 saver + feedback storage)." (task brief, pasted)
[Jinyoung Park, 10-21] "계속 그냥 쭉쭉 ㄱㄱ"
[Jinyoung Park, 10-21] "그리고 마지막으로 지금은 start 버튼 눌러야 시작이 되는데 자세가 잡힌 상태에서는 저절로 3초뒤에 start가 되게
수정을 해주고, 3초 안에 자세가 무너지면 다시 준비 할 수 있도록 ㄱㄱ"
[Jinyoung Park, 10-21] "android studio로 한번 해보자"
(Full input prompt log: `AI-Collaboration-Report-Iteration-2-Prompt-Log.md`, wiki sub-page
"AI Collaboration Report – Iteration 2 – Prompt Log")
TODO(team): each member's prompts for their tasks.

## 3. What AI Did Well
- End-to-end check before deploying: running the Dart result store against a local Django server found that Dart's
  `HttpClient` sent a chunked body that Django read as empty (422); fixed with Content-Length and a regression test
  (`test/services/online/battle_result_store_test.dart`, "no chunked" assertion). Unit tests on each side had passed.
- Review loop: the reviewer subagent found a race where an app could pre-post a row under a `result_id` and make the
  P11 saver roll back (Critical), and a late restart recovery voiding live battles (Major); both fixed with tests
  (`test_app_cannot_pre_post_an_online_result`, `test_late_recover_spares_battles_the_new_process_started`).
- Emulator walkthrough with a screen recording of home, the 기록 tab, the stored feedback screen, offline error, retry.

## 4. Hallucinations / Errors
- Wrong expected value in a test: assumed `ended_at_ms` 1792022460000 was 2026-10-18 03:21 UTC; it is 2026-10-15
  00:01 UTC (`server/tests/test_results.py`). Caught by the failing test. Cost: ~2 min.
- `dart format test` reformatted twelve teammate test files unrelated to the task. Caught in `git diff --stat`;
  reverted before review. Cost: ~5 min.
- Widget test timing: used `pumpAndSettle`, which moved the fake clock past the 3 s auto-ready window
  (`test/screens/online_preparation_test.dart`). Caught by the failing assertion; replaced with short pumps.
- Reported a phone-based test was ready while the phone was locked; the screenshot showed only the lock screen.
- The first exported Prompt Log (`0e7f450`) kept a computer host name and a server login from a pasted terminal output;
  the privacy grep only looked for email and paths. Caught by a wider grep before the PR; redaction terms added.
- TODO(team): other members' cases.

## 5. Prompt Revisions
- Before: "지금 연결 해놨는데 한번 test 해봐" (phone connected; the agent could not get past the lock screen)
- After: "android studio로 한번 해보자"
- Why it worked: the emulator has no lock screen and accepts adb input and screenshots, so the agent could drive and
  record the whole flow itself.
- TODO(team): other members' revisions.

## 6. Manual Fixes and Why
- No hand edits to code in this task.
- Two production deploy steps (Django migrate + restart; battle-server switch + nginx reload) were run by the user,
  because the agent's permission classifier blocked production deploys; the agent supplied the exact commands and
  verified the result read-only.
- TODO(team): other members' manual fixes (mark them in code as `AI-generated; manually fixed by <name>, <date>`).

## 7. Takeaway for Iteration 3
- Run a small end-to-end check across the client/server boundary before deploying; the per-side unit tests missed a
  transport bug.
- TODO(team): agree on one takeaway at the iteration close.
