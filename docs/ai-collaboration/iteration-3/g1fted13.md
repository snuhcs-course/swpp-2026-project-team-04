# AI Collaboration notes: Iteration 3 (2026-10-23 ~ 2026-11-06) – Woohyun Song
Status: draft (iteration open) | Written by: Woohyun Song | Merged by the PM into `AI-Collaboration-Report-Iteration-3.md`
Tools used: Claude Code (Opus 5.5), with the repo's `reviewer` subagent (`.claude/agents/reviewer.md`); Claude Design (a private Design canvas, internal sketches only)

Evidence per step, items a–f of the AI Collaboration Report Guidelines v1.1. Input prompts are in
[g1fted13-Prompt-Log.md](g1fted13-Prompt-Log.md). Answers the user typed into the agent's questions are not prompts,
so they are quoted here from the session export.

## W4 `feat/safe_warning` – safety warning when a match is found (P12), 2026-10-26 ~ 2026-10-27

### a. Where AI was used
- **The dialog:** Claude Code wrote `gymrats_app/lib/widgets/safe_warning_dialog.dart` (L1–207, commit `3db59cb`): `SafeWarningDialog` (L17), its picture box `_Picture` (L158), `safeWarningRoute` (L186) and `showSafeWarning` (L203).
- **The hook-up (commit `1fd3ef5`):**
  - `gymrats_app/lib/screens/versus_screen.dart`: the warning opens when the screen is on top (`didChangeDependencies`, L65), the warning loop `_warn` (L81), closing it with the screen (`dispose`, L107), and `_askToLeave` now returns bool (L151).
  - `gymrats_app/lib/screens/online_lobby_screen.dart`: the 5 s online auto-close (L60).
  - `pubspec.yaml`: one line, with the PM's agreement.
- **The pictogram:**
  - Claude Design: three internal sketches (A/B/C) on a private Design canvas; the user picked A.
  - Claude Code then wrote a Pillow script, kept outside the repo, that draws sketch A's shapes and exports `gymrats_app/assets/images/safe_warning.png` at 1x/2x/3x (`3db59cb`).
  - The art is drawn for this app: no third-party image, no new package.
- **Tests:** `test/widgets/safe_warning_dialog_test.dart` (new), plus updates to `test/screens/versus_screen_test.dart`, `test/screens/online_lobby_screen_test.dart` and `test/design_tokens_test.dart`.
- **Review:** the `reviewer` subagent ran two rounds on the code: CHANGES_REQUESTED, then APPROVE.
- **Decided by the user:**
  - the warning's content and layout (a pictogram of a push-up done too hard, the message below);
  - sketches as internal-only material;
  - an image file (PNG), instead of the agent's recommended "draw it in code"; the PM agreed to the `pubspec.yaml` line and the asset path;
  - sketch A, out of the agent's three;
  - the online 5 s auto-close, picked from the agent's options, where it was marked recommended.
- **Proposed or decided by the agent, and reported to the user:**
  - back on the warning asks whether to leave, and staying shows it again;
  - the warning waits while the lobby's cancel dialog is open;
  - the title, message and the line under the button, taken from sketch A. The line was kept without a separate question; task.md records it.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 10-26] "일단은 내부 스케치로 쓰기로 결정하자. 그리고 W4를 시작하자. '안전 경고'는 매칭이 잡힌 후 게임이 시작하기 전에 유저에게 무리하여 플레이할 경우 신체에 무리가 될 수 있으니 몸상태에 유의하여 게임하라는 알림이야. 픽토그램 같은 이미지로 푸쉬업을 무리해서 하다가 다치는 이미지를 넣고 하단에 안전 메시지를 넣으면 돼." (line breaks shown as spaces)
- [Woohyun Song, 10-26] "1. PM이 동의했어. 2. PNG로 가자. 3. 너가 Claude Design 캔버스에 시안 3가지를 만들어줘." (line breaks shown as spaces)
- [Woohyun Song, 10-26] "A로 가자."
- [Woohyun Song, 10-26] answer to the agent's two questions, sent as a new message after the question turn was interrupted (an answer, not a prompt, so it is not in the Prompt Log; from the session export): "5초 뒤 자동 닫힘 (Recommended)" for how the online warning closes, and "이미지 파일(PNG/SVG)" for the pictogram.

### c. What AI did well
- **Used the server's limit to set the countdown:** it found the server's 60 s ready limit (`server/lib/battle_server.dart`, `readyTimeoutMs`) before proposing how the online warning closes. The user chose the proposed 5 s auto-close, and a test now compares the two values.
- **Stayed inside W4's files:** the first version blocked back while the warning was open, which broke `test/main_test.dart` (W2's file). Instead of editing that file, the agent changed the behavior: back on the warning asks whether to leave, as back on the screen does. The test passes unchanged.
- **Found an edge case in an existing test:** reading `online_lobby_screen_test.dart` showed that a match can be found while the lobby's "매칭을 취소할까요?" dialog is open. The warning would have covered that dialog, so it now waits until the versus screen is on top.
- **No uncommitted work lost:** another session stashed the W4 work while switching to the W1 branch. The agent checked the stash's contents, stopped, waited for that session to go idle (an idle notice, not polling), and restored the work without conflicts.

### d. Hallucinations / errors
- **Back swallowed:** the first version ignored back on the warning (`PopScope(canPop: false)`), which broke the app's "back asks whether to leave" flow. Caught by the full `flutter test` run (`main_test.dart` failed).
- **Warning shown twice:** after the user left from the warning, a second warning opened over home. The screen stays mounted during its pop animation, and the loop checked `mounted`. Caught by `main_test.dart` ("Too many elements"). Fixed: `_askToLeave` returns whether the user left.
- **Logout read as back (reviewer round 1, Major):**
  - The reviewer reproduced it with a probe test. When the app itself removes every screen (logout, session expiry), the warning ended up with no answer, the code read that as back, and "게임에서 나갈까요?" opened over the login screen.
  - Fix: three answers (true, false, null), and only an explicit back asks. A regression test was added.
- **Other reviewer findings (Minor):**
  - A warning was left over the lobby when an online match was cancelled. Fixed: the screen removes the warning's route on dispose.
  - An assertion (`session.phase`) could not fail. Replaced with a comparison against the server's real default.
  - The line under the button was not in the copy recorded from the user. It is sketch A's line, so it was kept, and task.md now records it.
- **Faulty tests caught by running them:**
  - A landscape check measured the full-screen `Dialog` widget instead of the card.
  - A `pubspec.yaml` check assumed LF line endings; this Windows checkout has CRLF.
  - The Prompt Log builder's regex dropped the last prompt. Caught by re-running `extract_prompts.py`.
- **Invalid result noticed:** one "passing" `main_test.dart` run happened after the other session had switched the working tree to the W1 branch, so it tested W1 code. The reflog showed this. The run was discarded and repeated after the restore.
- **Unrelated reformatting:** `dart format` re-wrapped existing tests. It was reverted so the diff holds only W4 changes.

### e. Prompt revisions
- **Before:** "일단은 내부 스케치로 쓰기로 결정하자. 그리고 W4를 시작하자." (interrupted by the user)
- **After:** the same lines plus the warning's content and the pictogram-above, message-below layout (quoted in item b).
- **Why it worked:** the added description became the brief for the three sketches and fixed the copy's intent before any code. The agent then only had to ask how the warning closes online and how the image is made.

### f. Manual fixes and why
- None by hand in this step. The user made the main decisions (item a), and the agent applied every change. No code was edited by a person, so there is no manual-fix marker.

### Takeaway
- Two sessions should not share one working tree; use a separate `git worktree` per step.
- A dialog's "closed by the user" and "removed by the app" need different answers.
