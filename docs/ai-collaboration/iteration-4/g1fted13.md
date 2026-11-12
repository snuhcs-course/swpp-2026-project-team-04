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
  - The phone checks were done by the user, last on 11-13 ("폰 확인을 마쳤고 대결은 문제 없어."; which parts were checked on the phone: see the testing notes' TODOs).

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
