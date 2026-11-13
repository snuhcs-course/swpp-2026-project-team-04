# AI Collaboration notes: Iteration 4 (2026-11-07 ~ 2026-11-20) – Woohyun Song
Status: draft (iteration open) | Written by: Woohyun Song | Merged by the PM into `AI-Collaboration-Report-Iteration-4.md`
Tools used: Claude Code (Opus 5.5), with the repo's `reviewer` subagent (`.claude/agents/reviewer.md`); Claude Design (the user's design canvas)

Evidence per step, items a–f of the AI Collaboration Report Guidelines v1.1. Input prompts are in
[g1fted13-Prompt-Log.md](g1fted13-Prompt-Log.md). W1 began on 2026-11-06, when the PM handed out the Iteration 4
team plan, one day before the iteration's official start. Its prompts from that day are included.

## W1 `feat/home_lobby` – home redesigned as a game lobby (P5, team order #2), 2026-11-06 ~ 2026-11-08

### a. Where AI was used
- **The code and tests:** Claude Code wrote all of W1's code and tests in eight local commits on `feat/home_lobby` (`57ca64f` … `38c44b1`; 19 `lib/` files, +2839 / −873 lines). The main files:
  - `lib/widgets/lobby_rep_bot.dart` (L1–431), RepBot doing push-ups;
  - `lib/widgets/lobby_parts.dart` (L1–484), the shared lobby parts, incl. `LobbyPage.fill` (L45) and `LobbyFillColumn` (L127–) in `38c44b1`;
  - `lib/widgets/lobby_menu_item.dart`;
  - `lib/screens/home_screen.dart` (existed before; W1 changed +248 / −288 lines);
  - three new pages: `play_screen.dart`, `ai_setup_screen.dart`, `settings_screen.dart`;
  - `lib/viewmodels/settings_viewmodel.dart` and `lib/services/user/settings_store.dart`, the sound switches kept across restarts;
  - the light theme, palette B and fonts in `lib/theme/app_theme.dart` (existed before; W1 changed +317 / −31 lines, incl. `RepBotColors` L85–, `LobbyText` L138– and `AppHighlight` L256–).
- **The layout came from the user's design.** The four pages (main candidate 1, 게임 시작, AI 1v1, 환경설정) and the RepBot prototype are from the user's Claude Design canvas, exported into the local harness folder. Claude Code ported them to Flutter. For RepBot it compared every bar end and the head with the strings the prototype's own `renderVals()` prints at s = 0, 0.5 and 1 (`test/widgets/lobby_rep_bot_test.dart`, group 'the pose matches the design').
- **Review:** the `reviewer` subagent reviewed W1 seven times.
  - Runs 1 and 3 returned CHANGES_REQUESTED with Major findings (item d).
  - Runs 2, 4, 5, 6 and 7 returned APPROVE, and every Minor finding was fixed.
  - It reran the full suite itself in every run from 2 to 7.
- **Course notes:** Claude Code drafted these notes, the testing notes (`docs/testing/iteration-4/g1fted13.md`) and the requirement-wording memo for the PM (5.2 AC1/AC2/AC6, 5.9 AC1, UAT-4 AC3).
- **Not done by AI:**
  - Every design choice was the user's: the lobby layout, the light theme and fonts (team kickoff 2026-11-07), palette B "형광펜", the uniform menu rows, hiding the bot rep ranges on the AI 1v1 page, and the RepBot size range 0.6–1.2×.
  - The ownership exceptions for files outside W1 were agreed by the PM and 박진영 in the team chat and passed on by the user.
  - The phone check was done by the user on 2026-11-08.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-06] (the step's start, pasted; excerpt) "task 수행해. 로비 레이아웃은 내가 Claude Design에서 이미 정했으니 선택지를 새로 만들지 말고 .claude/design/INDEX.md를 먼저 읽어. … 가운데 RepBot은 정지 그림이 아니라 푸쉬업을 계속하는 애니메이션이어야 해. INDEX.md의 \"Lobby motion\" 절대로 RepBot.dc.html의 수치를 그대로 옮겨서 lobby_* 위젯의 CustomPainter로 만들어. 눈대중으로 다시 그리지 마."
- [Woohyun Song, 11-08] (palette B, pasted; excerpt) "색배합은 .claude/design/ColorPalettes.dc.html의 \"B · 형광펜 (라임 + 잉크)\"로 정했어. 규칙은 이거야. 1. 라임 #C6FF3D, 분홍 #FF4F81, 주황 #FFB547, 청록 #3DE8FF, 빨강 #FF3B30은 지금 값 그대로 두고, 칸(배경·버튼·막대·띠·칩)에만 써. 2. 글씨는 전부 잉크 #141A26이고, … 밝은 색을 글씨 색으로 쓰지 않아."
- [Woohyun Song, 11-08] (the fit fix, pasted; excerpt) "남거나 모자란 높이는 RepBot 애니메이션 영역 하나가 흡수해요. 화면이 작으면 RepBot이 비율을 유지한 채 작아지고, 화면이 크면 커지되 지금 시안 크기의 1.2배를 넘지 않게 최대 크기를 둬요. … 구현 힌트 (더 나은 방법이 있으면 그걸로 해도 돼요)"
- [Woohyun Song, 11-08] (after the phone check, pasted; excerpt) "머지 충돌이 나거나 테스트가 하나라도 실패하면 push하지 말고 멈춰서 알려 줘. 그리고 앞으로 새 테스트를 예전 코드에 돌려 볼 때는 git checkout으로 파일을 되돌리지 말고, 커밋하지 않은 변경이 있으면 git stash를 쓰거나 별도 worktree에서 해 줘."

### c. What AI did well
- **Found why home scrolled, and why the hint would not fix it (`38c44b1`).**
  - The cause: RepBot's slot reported its full 264 pt to `IntrinsicHeight`. Home was 24 pt taller than a bare 360×780 screen, and 96 pt with a 24 pt status bar and a 48 pt navigation bar.
  - Why the hint fails: the user's hint, `SliverFillRemaining(hasScrollBody: false)`, also sizes by intrinsic height, and `RenderFittedBox` reports its child's unshrunk height. At 320×640 with 1.3× text the old slot asked for 418 pt for a 231 pt RepBot, so that layout would scroll while RepBot could still shrink. This breaks the spec's "scroll only at the least size".
  - The fix: Claude Code measured this before choosing a design, then wrote `LobbyFillColumn` (`lobby_parts.dart` L127–), which lays the other children out to measure them.
  - The result: 360×780 and 393×852 have 0 scroll with and without system bars; 320×640 at 1.3× text scrolls 70 pt instead of 332.
- **Tests that fail on the old code.** The new fit tests were run against the old layout. The tests that cover the bug failed there: 360×780 and 320×640, shrink and grow, the tab bar, the chip and rows, and some size-matrix cases. The cases on screens that already fit, such as 393×852, passed. All of them passed on the new layout. The reviewer's fractional-height finding got its own test, 'a page that fits has no scroll room, even with fractions'. It fails on the first formula (1.137e-13 pt of scroll room) and passes on the fix.
- **Kept to the ownership rules under pressure.** The new home broke 15 tests in 5 files outside W1: one is 박진영's J4 file, two belong to my own later steps W2/W3, and two have no owner.
  - Claude Code listed them by file and owner, stopped, and asked for exceptions instead of editing them.
  - After the PM's OK it changed only each test's path from home.
  - It found a bug in `help_pictures.dart` (J5's file: health-bar fills drawn 0 px tall) while rendering the palette preview, and only reported it.
- **A contract a teammate can use.** It wrote the W1 → J2 contract for the sound switches in `task.md`: where `SettingsViewModel` lives, how to read and change it, and how tests provide it. The user approved it on 2026-11-06.

### d. Hallucinations / errors
- **Review run 1 (11-06), 4 Major findings:**
  - The views changed text styles inline, against UI Design System 2.5. Fixed with the `LobbyText` styles in `app_theme.dart`.
  - The sound switches reset whenever 환경설정 reopened, so J2 could not read them. Fixed by moving `SettingsViewModel` to the app level in `main.dart`.
  - The profile chip did not sit flush right, and long names were cut early.
  - The "Design doc changes" rows for the new files were missing.
  - Caught by the reviewer, not by tests. Cost: one fix round (about 10 minutes: findings at 21:41, fixes sent to run 2 at 21:50, APPROVE at 21:56), plus new tests for each case.
- **Review run 3 (11-08), 2 Major findings, after the switch to the light theme:**
  - Material defaults were still lime on the light screens: spinners, text buttons, the cursor and radios, which cannot be read on a light ground.
  - The contrast table missed the result screen's WIN/LOSE and scores (UAT-4 AC1).
  - Fixed with ink theme parts and tests, and the table rows were added.
- **Review run 7 (11-08), Minor:** the first `LobbyFillColumn` formula added the fill's height back to the others. With fractional heights this could leave about 1e-13 pt of scroll room, so the page would stretch on a swipe although it fits. Fixed by computing the column's height first and giving the fill the rest (test above).
- **A tooling slip (11-08):** to run the new tests against the old layout, the agent ran `git checkout` on the test file. That also threw away its own uncommitted test edits.
  - It re-applied them from the conversation the same minute and reran the suite, so nothing was lost in the commit.
  - The user then made a rule, written into `progress.md`: use `git stash` or a separate worktree for this, never `git checkout`.
- **Replies in the wrong language:** the standing rule is to reply in Korean. Still, the agent's replies switched to English four times, after long turns, a resumed session, or English-heavy work such as reviewer reports and the PR body. Each time the user had to ask again: "한국어로 바꿔서 다시 처음부터 응답해" (11-06 22:01), "답변이 왜 갑자기 영어로 바뀌었어? 한국어로 다시 답변해" (11-08 03:43), "응답을 한국어로 해" (11-08 18:13), "영어로 답변 그만하고 한국어로 답변해" (11-08 21:31, after the PR report). Cost: a re-sent answer each time; no code impact.
- **Process slip:** the repo's `testing` skill should be loaded before writing tests. In the fit fix it was loaded only after the tests were written. The tests were then checked against it, and nothing had to change.

### e. Prompt revisions
- **The palette B text rule (11-08):**
  - Before (04:43): "2. 글씨는 전부 잉크 #141A26이고, 보조 글씨는 지금의 textSecondary/textMuted를 써. 색 칸 위 글씨도 잉크야. 밝은 색을 글씨 색으로 쓰지 않아."
  - After (15:49): "규칙을 내가 너무 넓게 썼어. \"밝은 색을 글씨로 쓰지 않는다\"는 밝은 배경 위의 글씨 얘기야. 잉크처럼 어두운 칸 위의 흰 글씨나 라임 아이콘은 대비가 충분하니 괜찮아."
  - Why it worked: the agent had applied the first rule literally, also to the one dark button, and so moved the AI 1v1 대결 시작 button away from its design. Narrowing the rule to "text on a light ground" let it restore the button as designed (ink fill, white `onInk` text, lime arrow). It also wrote the exception into `task.md`, the wiki color table and the team message, so the rule now reads the same everywhere.
- **The coverage rule (11-06):**
  - Before (18:58): "테스트 노트의 커버리지 칸에는 \"not measured on this Windows PC (coverage collection hangs); TODO(…): measure on macOS\"라고 적어."
  - After (19:20): "커버리지 규칙은 내가 준 문구 말고 Iteration 3 마지막에 쓰던 규칙(\"PR의 CI 코멘트에서 가져온다\")으로 되돌려줘. 원래 내용은 .claude/archive/iteration-3/progress.md(없으면 .claude-backup 안의 progress.md)를 기준으로 해."
  - Why it worked: the first prompt retyped an older wording from memory. The second named the file that holds the final rule, so the agent copied that rule instead of the retyped one. These notes use it: coverage comes from the PR's CI comment.
- **The fit fix (11-08):** the spec gave a hint but allowed a better method ("더 나은 방법이 있으면 그걸로 해도 돼요"), with numbers to test. This let the agent measure the hint and reject it with evidence instead of following it (item c).

### f. Manual fixes and why
- None in W1's code. No AI-generated line in W1 was edited by hand, so W1 has no manual-fix markers.
- The user's corrections came as prompts. Examples: after checking palette B, the user had the 대결 시작 button put back to the design (ink fill, white `onInk` text, lime arrow) and kept `AccentButton`'s ink edge.
- The user's own work in W1 was the design itself (Claude Design canvas), the decisions in item a, and the phone check.

### Takeaway
- A precise spec with numbers (sizes to test, the 0.6–1.2 range, "scroll only at the least size") let the agent test the hint and reject it with measurements instead of guessing.
- For the next steps: keep asking for tests that fail on the old code first, and run that check with `git stash` or a worktree.

## W1 follow-up – the Codex review of PR #45, 2026-11-11

### a. Where AI was used
- **Code review:** the team's Codex GitHub review reviewed PR #45 at `78351da` on 2026-11-10 and left three comments:
  - P1: WIN/LOSE cannot be read on the light background (`app_theme.dart` L37);
  - P2: the replay setup guesses the mode from the opponent's name (`home_viewmodel.dart` L37); 송현우 filed issue #47 from it;
  - P2: a long nickname overflows the settings row (`settings_screen.dart` L60).
- **Fixes and tests:** Claude Code (Opus 5.5) wrote both fixes and their tests, in two rounds (line numbers as of `cd88ab2`):
  - `5909acd`: `lib/screens/result_screen.dart` (`_Verdict` L186–, `_Score` L335–, `_FeedbackButton` L585) and `test/screens/result_screen_test.dart` (group 'readable on the light ground (palette B)' L220–);
  - `15e0dcd`: `lib/screens/settings_screen.dart` (`_Nickname`, a 40% screen-width cap; replaced in round 2) and `test/screens/settings_screen_test.dart` (group 'the nickname row' L265–);
  - round 2, after the user's answers: `df2ff07`: `settings_screen.dart` (`_Row.value` L163–, L209–) and the 1.0× test (L279–); `cd88ab2`: `result_screen.dart` (`_StatCard` L510–, the 무효 count ink) and `result_screen_test.dart` (L171–, L267–).
  - It read the comments and the issue through the GitHub REST API, because `gh` is not installed on this PC.
- **Review:** the `reviewer` subagent, run 9: APPROVE with 4 Minor findings; run 10 (round 2): APPROVE with 4 Minor findings, and its follow-up on these notes: APPROVE with 3 Minor wording points (item d).
- **Not done by AI:** the scope was the user's decision: text color only, a lime/pink band behind the verdict, no code for #47 (J3's files), and the one-off exception for W6's `result_screen.dart`. In round 2 the user chose the nickname's width rule and added the amber 무효 count; the pink robot icon and the avatar rings stay for W6.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-11] (pasted; excerpt) "바꾸는 범위는 글자 색뿐이야. 승패 단어와 라임·분홍으로 칠해진 글자(버튼 글자 포함)를 잉크로 바꾸고, 승패 단어 뒤에 이기면 라임, 지면 분홍 기울인 띠를 깔아. 화면 구성, 문구, 레이아웃은 W6에서 새로 그리니 바꾸지 마. 승패 글자가 4.5:1 이상인지 테스트로 확인해."
- [Woohyun Song, 11-11] (pasted; excerpt) "2. 결과 화면: 무효 횟수의 주황 글자도 글자 가독성 문제라 이번에 잉크로 바꿔(이미 받은 예외 범위 안). 상대 분홍 로봇 아이콘과 라임·분홍 아바타 테두리는 W6에서 고칠 거라 그대로 둬."

### c. What AI did well
- **Codex found two real bugs that W1's checks had let through.**
  - The result screen: review run 3 (11-08) had flagged the same WIN/LOSE contrast. W1 only listed it for the file's owner, so PR #45 would have shipped a result screen whose outcome cannot be read after every match.
  - The nickname: W1's settings tests used only the 2-letter name '우현'. Home's chip had a 12-letter test; settings had none.
- **Tests first, which reproduced the reported bug.** The new tests failed on `78351da` before the fix: 10 failures, including Codex's overflow ("A RenderFlex overflowed by 114 pixels on the right" at 2× text). In round 2, 7 changed or new tests failed on `1bb8544` before the change, among them the 1.0× case the first fix had missed. The tests check the contrast itself (WCAG ratio of the text color on its band), not only color names. Another test walks every text on the screen for lime or pink, so it also caught the feedback button's lime label.
- **The open question was raised, not hidden.** The round-1 cap passed every test the prompt asked for. The reviewer subagent (run 9) flagged that it cut a 12-letter name at 1.0× on a 360-dp phone; the agent measured it (8 letters + "…") and asked the user instead of shipping it. That question led to round 2.
- **A check with the real fonts.** The tests use the test font, where each Hangul letter is 1 em wide. A temporary render with the app's fonts (not committed) showed the 1.0× name whole and the 1.3×/2× names cut, so the tests do not pass only because of the test font.

### d. Hallucinations / errors
- **W1's tests missed the longest nickname on one screen** (see item c). The 11-08 checks did not test the longest valid input on every screen that shows a nickname.
- **The first nickname fix met the prompt but not the need.** The prompt named 1.3× and 2× text only. The agent capped the name at 40% of the screen width, so a 12-letter name showed 8 letters and "…" even at the normal size. Cost: one more round (a new layout, 1 new test, 2 stricter tests, reviewer run 10).
- **#47 is a limit W1 shipped knowingly.** Review run 1 (11-06) flagged that the replay setup reads a bot only from the opponent's name. W1 kept it as a documented name-only limit with a test, since the match record has no mode. Codex's P2 hit the same limit. It now goes through issue #47 to J3, whose files hold the record.
- **Review run 9, 4 Minor findings:**
  - The fix removed the verdict's glow for DRAW too, outside the "lime/pink text" scope. DRAW's glow was put back, with a test.
  - A test comment said a screen reader reads the whole name, but the test only checked the widget's text. Fixed. The first fix then failed twice: the exact semantics label matched nothing, because the row merges its texts, and the semantics handle was disposed too late. Two quick reruns.
  - Two scope questions for the user: palette B leftovers (pink icon, lime/pink rings, amber count), and a 12-letter Korean name is cut even at 1.0× on a 360-dp phone.
- **Review run 10, 4 Minor findings, all addressed:** three fixed: stale `progress.md` lines (still the 40% cap, 무효 "left for W6"), a test name that listed fewer colors than it checked ("lime, pink or amber" while it also bans cyan and red), and the `_Row` class comment, which did not mention the new value. The fourth went to W6 as a note: `AppColors.warning`'s comment still names the 무효 count as an amber fill. `app_theme.dart` is shared by W1, W2, W3 and W6, and it was not edited now because W2 has uncommitted changes to it.
- **Run 10 follow-up (these notes), 3 Minor wording points, all fixed:** the file owner above; item c credited the agent with spotting the 1.0× cut, which the reviewer raised first (run 9); a test was cited by its later name.
- **Tooling:** the temporary render check failed to load twice (run from outside the package, then missing imports). It is a scratch file, never committed.

### e. Prompt revisions
- Before: "환경설정 닉네임 줄: settings_screen.dart에서 닉네임이 한 줄 줄임표(…)로 처리되게 하고, 12자 닉네임에 글자 크기 1.3배와 2배를 넣은 위젯 테스트를 추가해."
- After: "닉네임: 화면 폭 40% 고정 말고, 줄의 남은 폭을 다 쓰고 그래도 넘칠 때만 "…"로 줄여 줘. 360dp 폰 기본 글자 크기에서 12자 한글 닉네임이 잘리지 않는 테스트와, 2배 글자에서 넘치지 않는 기존 테스트를 둘 다 통과시켜."
- Why it worked: the first prompt set only the upper bound (no overflow at large text), so a cap that cut early still passed. The second named the width rule and the normal-size case on the narrowest phone, so a test fixes both ends.

### f. Manual fixes and why
- None. No AI-generated line was edited by hand, so there are no markers.

### Takeaway
- Test the longest valid input at the largest text size on every screen that shows it, not only on the screen the feature started on.
- When a fix is tested only at the extreme, also test that the normal case is unchanged.

## W2 `feat/battle_screen_revamp` – battle screen revamp (P8, team order #5), 2026-11-09 ~ 2026-11-13

### a. Where AI was used
- **The code and tests:** Claude Code wrote all of W2's code and tests, in 24 local commits on `feat/battle_screen_revamp`, from `199e606` (11-11) to `6a8efba` (11-13).
  - Size at `6a8efba` (without #49's files): 40 `lib/` files changed (14 new, 6 deleted), +7390 / −2094 lines. The test side is +33594 lines, most of them the two data files below.
  - The main new files:
    - `lib/widgets/battle_fx_motion.dart` (L1–1462): the stage's effect math, a port of the design prototype's script;
    - `battle_stage.dart`: one frame of the stage;
    - `battle_arena.dart`: the stage and the camera, one clock, cues and announcements;
    - `battle_camera_area.dart` and `battle_camera_view.dart`: the lower half;
    - `battle_fighter.dart`, `battle_reject_sign.dart`, `battle_banner.dart`, `battle_stage_hud.dart`: the drawings;
    - `battle_stage_events.dart` and `battle_online_events.dart`: the bot's and the online state turned into stage events;
    - `lib/services/game/online_battle_result.dart`: the result of an online battle.
  - Rewritten: `lib/screens/battle_screen.dart` (L1–399) and `online_battle_screen.dart` (L1–606), both on the stage from the setup on; `battle_viewmodel.dart` (the setup phase, the round's own clock).
  - Restyled: `matching_screen.dart`, `versus_screen.dart` and `safe_warning_dialog.dart`. The safety picture is now `SafeWarningPicturePainter`, drawn from the design's SVG.
  - Changed under approved exceptions: `settings_store.dart`, `settings_viewmodel.dart` and `settings_screen.dart` for the safety switch, and `setup_checker.dart` for the setup words in Korean.
- **The design came from the user.** The stage is candidate A "링아웃 무대", spec v2.2, from the user's Claude Design canvas: `W2-FX-SPEC.md`, the prototype `FxA.dc.html`, and the drawings `FxFighter`/`FxIcon`. Claude Code ported it number by number.
  - It checked the port against the prototype's own samples: `test/widgets/battle_fx_golden.json`, 18 scenarios with 248 samples, compared in `battle_fx_motion_test.dart`.
  - It pinned every drawing call by call in `test/widgets/battle_art_drawings.json`.
- **Review:** the `reviewer` subagent reviewed W2 in 20 numbered runs (11–30 in `progress.md` "Review log"); six of them (11, 12, 13, 16, 17, 18) had a re-review, so about 26 verdicts in all.
  - Ten of these returned CHANGES_REQUESTED (item d).
  - Each step was committed only after an APPROVE.
  - In most runs the reviewer also planted its own mutants and reran the suite.
- **Course notes:** Claude Code drafted these notes and the testing notes.
- **Not done by AI:**
  - Every design choice was the user's: the candidate, every spec answer (e.g. "the scope is not cut", grade words during the battle, text size rules), the ready words "시작"/"준비", the safety switch's rule, and "three or more missing parts read the whole-body line".
  - The team agreements were made by people. The bot setup moved to the battle screen (question 9) with 한상우's agreement and 현우's approval. #49's widget was reused with 한상우's agreement. The exceptions were approved by PM 송현우, or done first and reported (listed in the PR).
  - The phone checks were done by the user, last on 11-13 on a Galaxy S26+ ("폰 확인을 마쳤고 대결은 문제 없어."): real bot battles and the new safety picture. The online battle on two phones and the stage demo were not checked (the testing notes' manual check).

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-11 20:42] (the restart on the settled design, pasted; excerpt) "새 세션이야. W2(feat/battle_screen_revamp, 대결 화면 개편)를 이어서 할 거야. 대결 화면 디자인은 Claude Design에서 시안 A \"링아웃 무대\"로 확정했고, 원본은 .claude/design/w2-fx/ 에 있어(v2)."
- [Woohyun Song, 11-12 11:05] (question 9, pasted; excerpt) "- 9번(progress.md의 Q9): 봇 대결도 대결 화면이 대결 전 단계부터 맡는다. 같은 무대·카메라 배치에서 자세 세팅 → 3·2·1 → GO!까지 진행하고, 봇 흐름은 setup_screen을 거치지 않는다. 상우가 동의했다."
- [Woohyun Song, 11-12 14:57] (the third session, pasted; excerpt) "2. 실루엣 위아래에 어두워지지 않는 띠(S22에서 약 37px)가 남지 않게, 그 띠도 #49 실루엣 바깥과 같은 어둡기로 덮어. 상우 파일은 고치지 말고 W2 쪽에서 해."
- [Woohyun Song, 11-12 17:27] (after a phone look, pasted; excerpt) "폰에서 보니 안전 안내 창의 그림(사람 모양)이 밝은 배경에 묻혀서 거의 안 보여. 지금 그림이 예전 어두운 테마용 PNG(assets/images/safe_warning.png, 흰 선)라서 그래. PR 전에 W2에서 고치자."

### c. What AI did well
- **A port that can be checked.** The effect math is pure Dart beside the widgets, compared with the prototype's own samples. Design v2.1 and v2.2 arrived in the middle of the step, and each change landed as a list of number differences the golden check confirmed. No number was tuned by eye.
- **Planted errors ("mutants") in every step.** Before each commit the agent changed single numbers or lines in its new code and reran the tests, and the reviewer planted its own. Where a mutant survived, a test was added:
  - step 6: 33 of 34 killed (23 of the agent's own and 11 of the reviewer's); the one left is on a line that step did not change (the avatar ring width);
  - step 4: the reviewer's 51 mutants in run 20, 36 killed and 6 equivalent; the rest became tests;
  - the third session's 가: 1 of 8 survived (the silhouette while the camera was not running) and got a test;
  - 나: 5 of 5 killed with no new test;
  - 다: 2 of 9 survived; one fix to the test store killed both (item d);
  - the user's answers 2–4: 11 of 11 killed.
- **Pixel tests that found visual bugs before the phone did:**
  - (1) **The dimmed strips:** a plain fill next to #49's silhouette left a lighter line (0.69 against 0.55). The agent measured why: #49's painter both clips and fills its box anti-aliased, so its edge pixel gets the coverage squared. It drew the strips in the guide's own layer with `BlendMode.src`, 1 pt into the box, short of the outline; the white line ends 2 pt away (measured).
  - (2) **A hint cut at large text:** a test lays every setup hint at 1.3× on a 360-wide phone. It found that the online reconnect hint, a pre-W2 line, was cut beside "준비 취소".
- **A clock bug found by a test (step 4):** right after GO!, the counter still showed its old time for one frame, so the view model read 26 s instead of 30. The fix and its test are in `battle_viewmodel.dart` (`_endRoundOnTime` and the watchdog).
- **Ownership kept:** in the second session the agent stopped before `settings_store.dart` (not W2's) and listed the exact lines it would change. The user's answer came with the exception scheme.

### d. Hallucinations / errors
- **Review findings (10 CHANGES_REQUESTED runs), for example:**
  - Run 11 (the effect math): the golden check could not see a tag present on one side only, a countdown could not be cancelled, and rules the samples do not reach had no test.
  - Run 12 (the drawings): 30 of 49 planted mutants survived. Every drawing was then pinned call by call.
  - Run 13 (the stage): at rest the opponent was drawn over the user's fighter. The design draws the user on top, and the agent's own comparison with the shot had missed it. The stage clock also restarted, so an ending replayed. 20 of 104 mutants survived.
  - Run 17 (online): two old behaviours were dropped without a reason.
  - Run 19 (the bot setup): a demo test that could fail by chance, and the app's wiring untested.
  - Run 28 (the safety picture): on a 360-dp phone the dialog gives the picture 232 × 150. The painter scaled each axis on its own, so the head became an ellipse. A test at 412 wide could not see it.
  - Cost: one fix round each, from about ten minutes to an hour.
  - The final review of the whole diff (run 30, 11-13) returned APPROVE with 3 Minor findings: two comments were out of date (one named the removed TIME UP overlay, the other the "setup screens"); no screen-level test showed the combo mark (a test was added through the bot battle screen); and the PR's first line had to name #49 (the order #49 → W2 is newer than `team-plan.md`).
- **A wrong theory (11-12):** the agent first expected `BlendMode.plus` to remove the lighter seam, assuming the two coverages add. The pixel test still read 0.66. The cause was #49's double anti-aliasing (item c). Cost: one extra try.
- **Claims about tests that were too strong (11-12):**
  - A note said a pixel test catches the squeezed head. It does, but only by one anti-aliased pixel; the scale tests are what catch it (run 29).
  - A test store read its values after the wait. The test 'the switch turned or the notice seen while loading keep the user's' therefore always passed, until a mutant showed it.
- **Replies in the wrong language again:** on 11-12 the agent wrote a whole long report in English, and the user asked again: "그리고 응답을 한국어로 하도록 해." Cost: none in the code. The memory note on this was made stricter.
- **Tooling:**
  - Shell heredocs failed several times on this Windows PC.
  - A script written through the shell lost its Korean text encoding.
  - A probe test was blocked once by the ownership guard (wrong file name).
  - Each was redone with the file tools. No impact on the code.

### e. Prompt revisions
- **Missing body parts:**
  - Before (11-12 14:57): "missingParts: 안 보이는 부위를 이름으로 말해야 해(UAT-1 AC1, 절차 2·5단계). … 여러 개면 \"손, 발목이 화면에 안 보여요.\"처럼 마지막 부위에 맞춰 이/가를 붙여."
  - After (11-12 16:31, after the report): "3. 안 보이는 부위가 3곳 이상이면 부위를 나열하지 말고 \"몸 전체가 화면에 보이게 해 주세요.\"(J1 음성과 같은 문장)로 말하게 해. 1~2곳이면 지금처럼 이름으로 말해. … 1.3배 글자 크기와 폭 360에서 잘리지 않는지 테스트로 확인해."
  - Why it worked: the first prompt said how to list the parts but not how much room the hint has. The reviewer measured the five-part squat line cut at 1.3×. The second prompt set a limit and asked for a fit test, which also caught a second cut line.
- **Files outside the step:**
  - Before (11-12 11:57): "저장 때문에 화면·뷰모델 말고 다른 파일(예: settings_store.dart)을 고쳐야 하면 멈추고 어느 줄인지 알려 줘."
  - After (11-12 14:57): "예외 처리 방식: 아래 가·나·다에서 남의 파일을 고쳐야 하면 먼저 처리하고, 현우·상우에게는 내가 나중에 보고한다."
  - Why it worked: the stop rule made the agent name the exact lines, so the user could approve a clear scope at once. Each exception line now records its reason and who is told.

### f. Manual fixes and why
- None. No AI-generated line in W2 was edited by hand, so W2 has no manual-fix markers.
- The user's corrections came as prompts and phone checks. Examples: the ready words, the three-parts rule, and the safety picture after the phone check.

### Takeaway
- Comparing a port with the design's own samples, and planting errors in the new code, caught more than reading the code did.
- Test each picture at the narrowest real phone width (360 dp), not only at 412.

## W3 `feat/characters` – characters replace the avatars (P14, team order #11), 2026-11-13 ~ 2026-11-14

### a. Where AI was used
- **The code and tests:** Claude Code wrote all of W3's code and tests. They are five local commits on `feat/characters`, all on 11-13, from `7b190db` (09:11) to `dded304` (11:26). On 11-14 it merged `origin/main` into the branch as `47afaff`.
  - Size: 30 `lib/` files changed (8 new, 6 deleted), +2842 / −2062 lines. 68 test files and fixtures, +3406 / −1085. `assets/avatar/` (16 MB) was removed.
  - The new files:
    - `lib/models/character_rig.dart` (L1–542): the rig model and its parser;
    - `character_rig_data.dart` (L1–800): the rig as Dart data;
    - `character_idle_motion.dart` (L1–101): the idle motions;
    - `lib/widgets/character_figure.dart` (L1–353): one painter for all six characters, `CharacterIdleFigure` and `BattleCharacters`;
    - `lib/screens/character_select_screen.dart` (L1–374), `lib/services/user/character_store.dart` (L1–60), `lib/viewmodels/character_viewmodel.dart` (L1–80) and `character_select_viewmodel.dart` (L1–72).
  - Changed:
    - W2's stage: `BattleFxCast` in `battle_fx_motion.dart`, `battle_stage.dart`, `battle_arena.dart`;
    - the online side: `online_battle_session.dart`, `lib/shared/battle_protocol.dart`, `server/lib/battle_server.dart` and `docs/iteration-2-protocol.md`;
    - `main.dart`, and the 게임 시작 and 환경설정 rows.
- **The design came from the user.** The user's Claude Design canvas gave `W3-CHARACTER-SPEC.md` v1.1, the rig `w3_rig.json` (`w3-rig-2`), `render_ref.py`, `hit_contact.json`, `idle_golden.json`, the shots and `ChSelectB.dc.html`.
  - Claude Code ported the rig.
  - It checked the painter against 36 of the 60 design shots, pixel by pixel, and the idle motions against `idle_golden.json`.
- **A report before any code:** as the user asked, the agent first listed the files and their owners. It proposed how a new app gets past the old deployed server, and wrote the deploy order, what to keep of the old avatar, and the build steps. Then it waited for the user's answers.
- **Review:** the `reviewer` subagent reviewed each step (runs 1–5 in `progress.md` "Review log"). Runs 1, 3, 4 and 5 had a re-review or re-check. Three runs returned CHANGES_REQUESTED first (item d). Each step was committed only after an APPROVE. After the merge, a sixth run reviewed the whole diff and returned APPROVE with five Minor findings (item d).
- **Course notes:** Claude Code drafted these notes, the testing notes and the PR body.
- **The Codex review of PR #52** left one P2 comment, a real race (item d). Claude Code reproduced it with tests, fixed it in `1f7e6f5` after the user chose the approach, and replied to the comment.
- **Not done by AI:**
  - The characters and the selection screen were designed by the user.
  - The fix of the Codex finding: the user chose "home waits" from the two options the agent gave.
  - Every decision was the user's:
    - reuse `avatar_id` (Option A);
    - storage per account;
    - only the settings row renamed;
    - the radar and VS circles kept;
    - `fakes.dart` untouched;
    - RepBot the same at every AI level;
    - no server deploy.
  - The messages to 현우, 박진영 and 한상우 are drafts; the user sends them.
  - The phone check was the user's (the testing notes' manual check): picking a character, and the chosen character (물렁범) idling, hit and knocked out in a bot battle.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-13 03:25] (the first start, stopped seconds after it was sent; excerpt) "온라인 상대의 캐릭터(명세 8절·12절을 바꿈): 서버와 프로토콜은 고치지 않는다. 온라인 세션이 지금 주고받는 avatar_id(서버가 battleAvatarIds 목록으로 검사함)를 그대로 쓰고, 고를 수 있는 캐릭터 다섯(mouse, kangaroo, bear, penguin, seal)을 그 목록에 이미 있는 id 다섯에 짝지어 보내고 받는다."
- [Woohyun Song, 11-13 03:28] (the restart in a new session, pasted; excerpt) "(c) 새 앱이 지금 배포된 옛 서버에 새 필드를 보내면 거절당한다. 이걸 어떻게 피할지(예: 서버를 먼저 배포하는 순서, 거절되면 필드 없이 다시 보내기 등) 코드를 쓰기 전에 방법을 제안해."
- [Woohyun Song, 11-13 08:36] (the answers to the report; excerpt) "1. 프로토콜: A안(avatar_id 재사용). 서버는 avatar_id를 선택 항목으로 바꾸고, 값은 모양만 검사(소문자·숫자·밑줄 1~32자)해서 해석 없이 그대로 전달한다."
- [Woohyun Song, 11-14 00:08] (the finish, pasted; excerpt) "2. git fetch origin 후 git merge origin/main (rebase 금지). 충돌은 W3 파일 안에서만 풀고, 다른 사람 파일에서 나면 멈추고 알려줘."
- [Woohyun Song, 11-14 02:01] (the Codex comment on #52, pasted; excerpt) "대결을 시작할 때 캐릭터를 잡는 곳도 읽기가 끝난 값을 쓰게 한다. 기존 결정(\"느린 읽기가 사용자가 직접 고른 선택을 되돌리지 않는다\")은 그대로 지켜. 더 단순하고 안전한 방법이 있으면 고치기 전에 알려줘."

### c. What AI did well
- **A port checked against the design's own data:**
  - A test keeps the rig equal to the design's JSON (`assets/characters/w3_rig.json`).
  - The painter matches 36 shots pixel by pixel: at most 0.03% of the pixels may differ. On 11-13 all 60 design shots measured 0.018% or less.
  - The idle motions match `idle_golden.json`, and every attack ends where `hit_contact.json` measured.
  - The stage took the characters through new inputs whose defaults are W2's. So W2's 248-sample golden check passed unchanged.
- **Mixed versions worked out before the code:**
  - The report before any code proposed how a new app gets past the old, deployed server. The user chose Option A, with a one-time `avatar_01` resend.
  - The tests run the Dart battle server in the test process. They cover an old app on the new server, and a new app on the old server: one resend, kept on reconnect, and a second refusal fails the search.
  - The reviewer checked both cases again in run 4.
- **Checked before deleting:** before removing the 3D avatar files, the agent ran `git fetch` and checked every remote branch and the open PRs (#49, #50) for uses. #49 passes camera parameters only, so `PoseAvatarToggleView` became camera-only without a change to 한상우's files.
- **Ownership kept:** files outside W3's list were changed only under exception lines with their reason, as the user's answer 6 said. `--check-diff` passes (235 files).
- **The old avatar page checked on request (11-14):** the user asked whether 환경설정 → 프로필 still showed "내 아바타" (preview, the SOMA list, search, the 운동복 filter). The agent found that `profile_screen.dart` and its test were deleted in `83c00ce`, and the 3D assets and viewers in `dded304`. No route or row leads to the old page any more. The SOMA names are left only as data in `avatar_model.dart`, kept for the PM's cleanup.

### d. Hallucinations / errors
- **Review findings (3 CHANGES_REQUESTED runs):**
  - Run 1 (the rig and painter):
    - `assets/characters/ATTRIBUTION.txt` pointed to a licence file in the repo that does not exist.
    - The Design doc rows were missing.
    - An empty move threw a `StateError`, and missing shape geometry silently became 0.
    - The figure stretched in a box of another shape.
  - Run 3 (the selection screen):
    - During a slow save, a second tap on 이 캐릭터로 하기 (or back) also closed the page under the selection screen. The reviewer reproduced it.
    - Gaps, paddings and corners were numbers outside the design tokens.
    - The re-review found that the back-during-save test let the page finish closing first, so it could not catch the guard.
  - Run 5 (the cleanup):
    - The agent's own pre-check had missed that 한상우's `tools/diagnose/Verify-AndroidPluginRegistration.ps1` (on `main`) requires `WebViewFlutterPlugin`. So removing `webview_flutter` would break it. The package was restored.
    - A fresh `pub get` had also bumped a transitive package, so the lock file was restored from HEAD.
    - The protocol doc said 25 avatars; there were 28.
  - Cost: one fix round each.
- **The final review (run 6, 11-14)** returned APPROVE with 5 Minor findings:
  - The PR body draft said old apps send `avatar_01`–`avatar_28`. In fact the ids are `avatar_01`–`avatar_25` plus three `soma_*` ids, as the protocol doc says.
  - Two comments were unclear or out of date: `ATTRIBUTION.txt` said "this file" for `w3_rig.json`, and `avatar_model.dart` said only the ids were left.
  - The selection screen's name band keeps the mockup's 14 at its top without a recorded deviation.
  - Old avatar words remain in files outside W3's list.
  - A harness line still said "Merge order: #10".
  - All of them were fixed or recorded, with no change in behavior.
- **A race that the agent and six review runs missed, found by the Codex review of PR #52 (P2, `character_select_viewmodel.dart`, 11-14):**
  - The claim: home can open as soon as the rules check ends, while the account's character is still being read. 캐릭터 선택 then starts on the stand-in `mouse`. Confirming it calls `choose`, which voids the pending read and saves `mouse` over the saved choice. A battle started then captures `mouse` too.
  - Reproduced: the agent first wrote tests with a store whose read waits. All three failed on the old code: the saved `seal` became `mouse` (view-model and app level), and a bot battle built during the read got `mouse`. Review run 3 had tested a slow *save* on this screen, but no test had a slow *read*.
  - The fix (`1f7e6f5`): before fixing, the agent proposed a simpler way than the one in the prompt, and the user chose it. Home waits until the character is read, behind the rules check's spinner (`CharacterViewModel.loading` / `isReadyFor` in `main.dart`). A read that fails counts as the default, so the wait always ends. The selection screen keeps a second guard: no confirm before the read ends, and the preview follows the read unless a cell was picked. The rule of 11-13 "a slow read does not undo a choice made meanwhile" still holds.
  - Tests: 15 new ones (3 app tests, 1 screen test, 5 + 6 view-model tests). Two existing tests counted the load's notifications and were adjusted to the new contract, with their intent kept.
  - Review run 7 returned APPROVE with 4 Minor findings: the decision and a design-doc row were not recorded; no app test covered the rules screen before home; the notes and PR body still had the old numbers; three near-identical test fakes. The first three were fixed: a test for the rules path was added, and it also fails on the old code. The fakes stay, because the shared fake file is the PM's.
  - The agent replied to the Codex comment on GitHub with the problem, the fix, the commit and the tests, then resolved the thread.
  - Cost: one fix round. The comment came at 01:00 KST and the fix was committed at 02:41; that span includes the time before the user passed the comment on.
- **Tooling slips:**
  - In run 2 the agent reverted a reviewer mutant with `git checkout`. That also dropped the step's own uncommitted arena changes. They were restored at once from the copy taken just before.
  - In step 5, one `sed` edit of the comment in `android/app/build.gradle.kts` (not W3's file) was reverted at once. The reviewer checked it is identical to HEAD.
  - No impact on the code.

### e. Prompt revisions
- **The online opponent's character:**
  - Before (11-13 03:25): keep the server and the protocol as they are, and map the five characters onto five avatar ids already in the server's list.
  - After (11-13 03:28, in a new session): add the field to the server and the protocol ourselves, keep old and new apps and servers working ((a)–(c)), and propose the way past the old server before any code.
  - Then (11-13 08:36, after the agent's report): Option A. Reuse `avatar_id`, check only its shape, and resend once with `avatar_01`.
  - Why it was revised (the user, 11-14): right after sending the first prompt, the user changed course. W3 would do the server-side handling itself, then report to the PM and the server file's owner afterwards. So the user corrected the instruction and sent it again at 03:28. Carrying the character id in the existing `avatar_id` field was settled at 08:36, after the agent's report.
  - Why it worked: asking for a proposal before code put the choices side by side in the report. The chosen option needs no new field. Old apps already draw an unknown `avatar_id` as their default, so the per-recipient messages of (b) were no longer needed.

### f. Manual fixes and why
- None. No AI-generated line in W3 was edited by hand, and the diff has no manual-fix marker.
- The user's corrections came as prompts and answers: the protocol option and the files kept for the PM. The 08:36 rule (do not delete what a teammate uses) kept `webview_flutter` once run 5 found 한상우's script.

### Takeaway
- When a change crosses versions (old and new apps and servers), ask for a proposal before any code. The answer then picks the option with the fewest moving parts.
- Before deleting a package, check the scripts and tools too, not only the Dart code.
- Test the moment between login and the first read of saved data. A stand-in default shown then can be saved over the real value.

## W2b `feat/battle_screen_polish` – polish of the battle and matching screens (A2, team order #7), 2026-11-13 ~ 2026-11-14

### a. Where AI was used
- **The code and tests:** Claude Code wrote all of W2b's code and tests, in six commits on `feat/battle_screen_polish`: `0b8f610` (3-B, the pose setup), `c421b42` (2-A3, MATCH FOUND), `4c555ec` (1-A, the radar blips) on 11-13, and `374b72c` (old avatar words), `82772e5` (the end screen) and `ae44bbb` (MATCH FOUND with the W3 characters) on 11-14. It also resolved the merge of `main` with #51 and #52 (`13d0b4d`).
  - 3-B: the setup's layout and its move in `lib/widgets/battle_fx_motion.dart` (`BattleFxFrame.battleLayout`, `setupLook`, the ready chips), the screen's geometry as a pure function (`BattleArenaLayout` in `battle_arena.dart`), the camera picture's size and the silhouette's place (`BattleCameraLayout`, `BattleCameraView.pictureSize`, `coverShare` in `battle_camera_view.dart`), and the large band and button in `battle_camera_area.dart`.
  - 1-A: `RadarBlips` in `lib/screens/matching_screen.dart`, a pure function of the sweep.
  - 2-A3: the board in `lib/screens/versus_screen.dart`. It was built with W2's stand-in in one slot (`_VersusCharacter`). Once W3 was in `main`, that slot draws the W3 characters (`ae44bbb`), and the online lobby passes the session's two characters.
  - The end screen: `BattleFxFrame.endLayout`, `BattleArenaLayout.lineTop(progress, end:)`, and 결과 보기 moved into its own widget, `lib/widgets/battle_result_button.dart`.
- **The design came from the user:** `W2B-SPEC.md` and `w2b_golden.json` from the user's design canvas. Claude Code ported them and checked the port against the design's own samples (`test/widgets/battle_w2b_golden.json`).
- **The end screen's options:** the spec had none. Claude Code drew three options with the app's real fonts and the real stage widgets (a temporary render test, not committed). The user chose one, and only that one was built.
- **A teammate's PR:** Claude Code compared 한상우's #51 with 3-B's silhouette and reported the result to the user (item c). It did not edit his files.
- **Review:** the `reviewer` subagent reviewed W2b in four runs: run 1 (3-B), run 2 (1-A and 2-A3), run 3 (the end screen and this push's notes) and run 4 (the merge of `main` and the character swap). Run 3 returned CHANGES_REQUESTED twice (item d); every run ended with APPROVE.
- **Course notes:** Claude Code drafted these notes and the testing notes.
- **Not done by AI:**
  - The scope and every choice were the user's: the spec section 11 answers, the four open choices of 3-B kept as built, the words' margin (70 + 76 × scale) and leaving the "VS" disc's overlap on small phones, the end screen in this step, option A, the character swap as its own commit, and a Draft PR first.
  - The phone checks were the user's (Galaxy S26+): 3-B, the radar dots and MATCH FOUND (with the stand-in) had no problems. The end screen and MATCH FOUND with the W3 characters are not checked on the phone yet.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-13 12:27] (the start, pasted; excerpt) "기준: .claude/design/gymrats-w2b-reference/W2B-SPEC.md. 이번 범위는 3-B만이야. 자세 세팅 중에는 카메라가 화면의 약 80%를 쓰고, 카운트다운이 시작되면 50:50으로 바뀌는 것."
- [Woohyun Song, 11-13 21:47] (the scope widened, pasted; excerpt) "3. 2-A3의 캐릭터는 W3(feat/characters) 코드가 이 브랜치에 없어서 지금은 쓸 수 없어. … 캐릭터가 들어갈 자리는 위젯 하나로 모아서, 나중에 W3에서 그 위젯만 W3 캐릭터로 바꾸면 되게 해. W3 파일은 고치지도 가져오지도 마."
- [Woohyun Song, 11-14 03:02] (the finish with the end screen, pasted; excerpt) "먼저 코드는 고치지 말고 2~3개 안을 실제 글꼴로 그린 그림으로 .claude/design/out/w2b-end/에 만들어 보여 줘."
- [Woohyun Song, 11-14 03:21] "일단 A로 가자"
- [Woohyun Song, 11-14 04:00] (an answer in the agent's question dialog, so not in the Prompt Log; excerpt) "교체는 지금 이 브랜치에서 별도 커밋으로 해(내 캐릭터는 저장된 선택, 봇은 RepBot, 온라인은 서버 id, 대기 동작에서 상대는 230ms 늦게). 그다음 PR은 Draft로 바로 열고, …"

### c. What AI did well
- **A port checked against the design's samples.** 3-B matches the design's 39 `setupTransition` samples and 1-A its `radar` samples, every 50 ms over two turns. In W2's own samples only one field changed (the end screen's cover behind 결과 보기), and the reason is in the notes.
- **Options drawn before code.** For the end screen, the agent rendered three options with the app's fonts and the real stage, at the KO and time-up endings and the middle of the move. The user's prompt came at 11-14 03:02, and the choice at 03:21 in one line, "일단 A로 가자". Only that option was coded.
- **A spec conflict found and asked, not guessed (2-A3):** the spec puts the words "146 × scale" from the character's side, but a character shrunk around its feet then overlaps them, which the spec's own section 9 forbids. The agent measured it (overlap below a scale of 0.92; on the S22 at text 1.3 the scale is about 0.79) and asked. The user chose 70 + 76 × scale.
- **A teammate's PR read against this one:** 한상우's #51 shares no file with W2b. The agent found that its alignment check sits in `SetupViewModel`, which only the `/setup` screen uses, while the real bot and online setups use `SetupChecker` directly. So #51 does not reach the battle's setup yet. Its crop math equals `coverShare`, so a later hookup should pass the battle layout's camera box.
- **The review caught a moved `main` before the push:** checking this push's notes, the reviewer ran `git fetch` and found #51 and #52 (W3) merged into `main`. The notes and the PR draft were for a head that could not be pushed. The branch merged `main` first (three conflicts, all in W2b's files), and MATCH FOUND got the W3 characters at once.
- **The full suite caught a regression in a demo:** after the end screen, the stage demo's effect buttons, which sit where the camera is, vanished at every ending. The full suite found it, not the phone. The demo now starts over through 결과 보기.

### d. Hallucinations / errors
- **Review findings (runs 1 and 2: no Critical or Major, 5 Minor each, all fixed; run 3: 1 Major, 3 Minor):**
  - Run 1 (3-B): a disconnected opponent's "연결 끊김" tag floated over the empty ground during the setup; with reduced motion the layout jumped one frame (16 ms) after the phase changed; one assertion about the fading bar could not fail.
  - Run 2 (1-A, 2-A3): the blips' glow colors and the pills' paddings had no test (planted changes passed); the "AI" pill's lift was a raw number in the screen.
  - Run 3 (the end screen): **1 Major.** When the screen reports a knockout before its blow (a supported order), the line started down at the report. It then went back up when the blow landed, so the camera came back for a moment. The agent's own tests had covered a knockout by its blow, but not one reported first. The fix came test first: the start never moves later. Run 3 also had 3 Minor findings. In fever the cyan wash fills the whole screen; the options had been drawn without fever. It was kept, and a render was made (`.claude/design/out/w2b-end/_built.png`, not committed). The render was named to the user in the question they answered at 04:12, and the end screen is on the phone-check list. Moving 결과 보기's tests had lost a small-phone size. One note said the button's place was "as before" when it was 1.5 points higher; it is now placed exactly as before.
  - Run 3's check of the notes: **CHANGES_REQUESTED.** They described a head that could not be pushed, because `main` had moved (item c). One sentence stated as done something not yet done (the render "shown" to the user), and two time estimates could not be checked. The notes were redone after the merge.
  - Run 4 (the merge and the swap): APPROVE with 3 Minor findings, all fixed: a stale class doc, and design-doc rows and a task line still naming the stand-in.
- **Two W3 tests broken by the merge:** W3's screen tests looked for the characters while setting up, where 3-B draws no fighter. They now check after the countdown.
- **A demo broken by the end screen (11-14):** the first version of the end screen made the stage demo's buttons disappear with the camera, and one demo test failed in the full suite (2186 passed, 1 failed). Cost: one test and one doc comment.
- **Tooling:** a Python edit of a test file failed to find its text (Windows line endings and an escaped quote), and was redone with the file tools. No impact on the code.

### e. Prompt revisions
- **The end screen in or out:**
  - Before (11-14 02:59): "PM이 W6~W8을 먼저 끝내라고 해서, 대결이 끝난 뒤 화면(무대를 화면 전체로)은 이번 W2b에서 빼고 시간이 남으면 나중에 따로 할 거야."
  - After (11-14 03:02, re-sent): "대결이 끝난 뒤 화면까지 이번 W2b에 넣는다." with a new step: "먼저 코드는 고치지 말고 2~3개 안을 실제 글꼴로 그린 그림으로 .claude/design/out/w2b-end/에 만들어 보여 줘. … 시간이 빠듯하니 안은 간단히 보여 주고, 내가 고르면 바로 만들어."
  - Why it worked: the second prompt kept the end screen small enough for the deadline. Pictures first, then one option, so no time went into code for options that were not chosen. It also gave the rules up front (no change to judging or the result conditions, one pure progress value, reduced motion, which golden fields may change and where to write why).

- **A dialog answer written for an older state:**
  - Before (11-14 04:00, the question dialog): "…본문에 \"대결이 끝난 뒤 화면을 이어서 올림\"이라고 적어. 끝 화면 안을 보여 주고 내가 고르면 같은 브랜치에 이어서 커밋하고 …"
  - After (11-14 04:12): the agent pointed out that option A was already built and committed, and asked again. The user chose "A 그대로 포함".
  - Why it worked: asking kept a PR line that was no longer true out of the PR.

### f. Manual fixes and why
- None. No AI-generated line in W2b was edited by hand, so W2b has no manual-fix markers.
- The user's corrections came as prompts and phone checks: the spec answers, the words' margin, the end screen's option.

### Takeaway
- When the spec leaves a screen open, draw two or three options with the real widgets before writing code; the choice then takes one line.
- Run the full suite before review: a demo that shares the screen's layout can break in ways the widget's own tests do not see.
