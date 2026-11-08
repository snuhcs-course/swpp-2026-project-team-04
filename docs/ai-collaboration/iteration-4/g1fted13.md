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
- **Replies in the wrong language:** the standing rule is to reply in Korean. Still, the agent's replies switched to English three times, after long turns or a resumed session. Each time the user had to ask again: "한국어로 바꿔서 다시 처음부터 응답해" (11-06 22:01), "답변이 왜 갑자기 영어로 바뀌었어? 한국어로 다시 답변해" (11-08 03:43), "응답을 한국어로 해" (11-08 18:13). Cost: a re-sent answer each time; no code impact.
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
