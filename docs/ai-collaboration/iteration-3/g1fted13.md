# AI Collaboration notes: Iteration 3 (2026-10-23 ~ 2026-11-06) – Woohyun Song
Status: draft (iteration open) | Written by: Woohyun Song | Merged by the PM into `AI-Collaboration-Report-Iteration-3.md`
Tools used: Claude Code (Opus 5.5), with the repo's `reviewer` subagent (`.claude/agents/reviewer.md`); Claude Design (a private Design canvas, internal sketches only)

Evidence per step, items a–f of the AI Collaboration Report Guidelines v1.1. Input prompts are in
[g1fted13-Prompt-Log.md](g1fted13-Prompt-Log.md). Answers the user typed into the agent's questions are not prompts,
so they are quoted here from the session export.

## W1 `docs/battle_rules` – battle game rules design (P4), 2026-10-25 ~ 2026-10-26

### a. Where AI was used
- **The design document:** Claude Code drafted all of `docs/iteration-3/battle-rules.md` (L1–274), commit `73ef92c` on `docs/battle_rules`.
- **Who proposed the numbers:** the agent proposed them as options with recommended defaults: base and fever time, points per label, combo, KO and danger thresholds. The user chose among them, wrote their own answer on the winner rule (written scoring criteria required), raised Excellent from 1.2× to 1.6×, and accepted the two details the agent added: a rejected rep breaks the combo, and about 20% of the bot's reps are Excellent.
- **Grounding the rules in the code:** Claude Code read the current battle code to back the document's claims; one claim was still wrong (item d). Sources included `lib/models/battle_rules.dart` (30 s round), `lib/services/pose/rep_judge.dart` (`bottomDepth` 1.1), `lib/services/opponent/bot_opponent.dart` (`planRound` timing), and `server/lib/battle_server.dart` (`_finish` picks the winner by valid reps). It also read the server's match models and serializers (no `ko` reason, no outcome on bot uploads) and `docs/iteration-2-protocol.md` §5, §7, §8.
- **Arithmetic:** Claude Code worked out the scoring formula (L77–95), the bot estimate table (L120–134), and the two worked examples (L152–204).
- **Review:** the `reviewer` subagent reviewed the document in three rounds: CHANGES_REQUESTED, then APPROVE, then APPROVE after the threshold change. It recomputed the examples with a script. A fourth round checked these course notes: CHANGES_REQUESTED, then APPROVE after the fixes.
- **Bringing in `main` (10-26):** after the PM's CI workflow (#14) was merged, Claude Code merged `origin/main` into the branch (`1e07378`, no conflicts) and re-ran `flutter analyze` and `flutter test`. It also switched the testing notes' coverage cells to the CI comment on #13, following the user's new coverage rule. When the CI run on `fb8e67c` finished, it drafted the text that puts those numbers into the testing notes and the PR #13 "How to test". It applied the text after the user approved it.
- **Not done by AI:**
  - The final choice of every rule was the user's: base 20 s + fever 10 s, game score decides the winner, KO at a 100-point lead, no "opponent mistake → double", Excellent at 1.6×. The team confirms the numbers at the 10-28 check-in.
  - Measuring real `maxDepth` values on a phone needs a person and a device. The document marks it as "실측 필요" (needs measurement, L63) for the 10-28 check-in.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 10-25] "task 수행해"
- [Woohyun Song, 10-25] answer to the agent's question on the winner rule, typed in place of the offered options (an answer, not a prompt, so it is not in the Prompt Log; from the session export): "게임 점수로 승자를 정하되, 점수 산정 기준을 같이 세워야 해."
- [Woohyun Song, 10-25] "1. 1번의 의미가 잘 이해가 안 가. 2. 좋아. 3. Excellent 기준을 1.2배에서 1.6배로 높이자."

### c. What AI did well
- **Ownership-safe KO:** it found that a bot-battle KO needs no change to the S2-owned `rep_counter_viewmodel.dart`, because `finish()` already ends with `RoundEnd.timeUp`. It wrote this into the doc (L108–113), so W3 stays inside its own files.
- **Cross-team dependencies:** it found the changes a game-score winner needs outside W3 and named their owners: `server/matches/` (no `ko` reason, bot uploads carry no outcome), `server_user_repository.dart`, and `match_record.dart`. They are listed in the doc (L226–247) for the PM before the check-in.
- **Code facts:** the draft checked in the code, not assumed, that `rep.submit` has no depth field, and built the `grade` proposal on that.
- **Review caught what the draft missed:** the reviewer subagent found that the server rejects unknown `rep.submit` fields (`fields()` in `battle_protocol.dart`). A new app sending `grade` to the old server would have every rep refused, and the draft covered only old app → new server. This led to the rollout rule at L222.

### d. Hallucinations / errors
- **Wrong time base (reviewer round 1, Major):**
  - The first draft measured fever and combo with `RepEvent.at`, as if it were time into the round.
  - In the code it is the rep judge's stopwatch, started when `RepCounterViewModel` is built (`rep_counter_viewmodel.dart` L129–131). In online battles it also counts setup and countdown, so every rep could have scored as fever.
  - Fix: round elapsed time (`RepRecord.at` / `elapsed_ms`) is now defined in the doc (L35–39).
  - Cost: one review round.
- **Wrong arithmetic (reviewer round 1, Major):** the "8 reps" row of the bot estimate table did not follow the doc's own assumption. It gave user 100 and bot +50, where the right values are 110 and +40, and the danger claim was wrong too. Fix: the table was recomputed with the spread written out (L120–134).
- **Threshold proposed without checking the data (reviewer round 1, Minor):**
  - The agent proposed Excellent at 1.2 × `passDepth` (1.32) without checking the code comment that full push-ups measured 1.4–1.9 (`rep_judge.dart` L13–14). At that threshold almost every rep would have been Excellent.
  - After the reviewer cited the data, the user raised the threshold to 1.6 × (1.76).
- **Over-strong claim (reviewer round 2, Minor):** the doc said that across app versions "the bar and the winner stay the same". That held only for the winner. Fix: `match.found` now carries `ko_lead` (L215, L223).
- **Caught by the agent before review:** an example used `rep_seq` 14 where valid + rejected reps made 12, and the doc said a KO happens "at the end of fever" where the computed time is 24.3 s. Both were fixed in the first draft.

### e. Prompt revisions
- **No prompt was rewritten** in this step. The closest case is the winner-rule question above.
  - Before (agent's option): "게임 점수(바 위치)"
  - After (user's own answer): "게임 점수로 승자를 정하되, 점수 산정 기준을 같이 세워야 해."
  - Why it worked: the answer made the scoring criteria a required part of the document, so §3 defines every point rule (labels, combo, fever, formula table) instead of only naming the winner rule.
- **Clarifying question:** "1번의 의미가 잘 이해가 안 가" (the time-base note) got a plainer explanation with a concrete case, a table of the two clocks.

### f. Manual fixes and why
- None by hand in this step. The user changed one number by instruction (Excellent 1.2× → 1.6×), and the agent applied it, including the example depth values (L161–170, L185). No code changed, so there is no manual-fix marker.

### Takeaway
- Before proposing a threshold, check the numbers already recorded in the code (comments, test data).
- Name the clock behind every time rule.

## W4 `feat/safe_warning` – safety warning when a match is found (P12), 2026-10-26 ~ 2026-10-30

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
  - After a phone check the user asked to drop "×100". The agent put two revisions on the canvas (A2, A3); the user picked A3, and the agent changed the script and redid the PNGs and the screen reader label (`50b8a18`).
- **Tests:** `test/widgets/safe_warning_dialog_test.dart` (new), plus updates to `test/screens/versus_screen_test.dart`, `test/screens/online_lobby_screen_test.dart` and `test/design_tokens_test.dart`.
- **Review:** the `reviewer` subagent ran two rounds on the code: CHANGES_REQUESTED, then APPROVE. Later rounds checked these notes and the pictogram change.
- **Decided by the user:**
  - the warning's content and layout (a pictogram of a push-up done too hard, the message below);
  - sketches as internal-only material;
  - an image file (PNG), instead of the agent's recommended "draw it in code"; the PM agreed to the `pubspec.yaml` line and the asset path;
  - sketch A, out of the agent's three;
  - after the phone check, removing "×100", and A3 out of the agent's two revisions;
  - the online 5 s auto-close, picked from the agent's options, where it was marked recommended.
- **Proposed or decided by the agent, and reported to the user:**
  - back on the warning asks whether to leave, and staying shows it again;
  - the warning waits while the lobby's cancel dialog is open;
  - the title, message and the line under the button, taken from sketch A. The line was kept without a separate question; task.md records it.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 10-26] "일단은 내부 스케치로 쓰기로 결정하자. 그리고 W4를 시작하자. '안전 경고'는 매칭이 잡힌 후 게임이 시작하기 전에 유저에게 무리하여 플레이할 경우 신체에 무리가 될 수 있으니 몸상태에 유의하여 게임하라는 알림이야. 픽토그램 같은 이미지로 푸쉬업을 무리해서 하다가 다치는 이미지를 넣고 하단에 안전 메시지를 넣으면 돼." (line breaks shown as spaces)
- [Woohyun Song, 10-26] "1. PM이 동의했어. 2. PNG로 가자. 3. 너가 Claude Design 캔버스에 시안 3가지를 만들어줘." (line breaks shown as spaces)
- [Woohyun Song, 10-26] "A로 가자."
- [Woohyun Song, 10-29] "폰으로 보니까 그림이 마음에 안 들어. 픽토그램에서 x100 써있는 부분을 없애는 편이 나아보여. 이거는 claude design으로 수정안을 다시 띄워줘."
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
- **Picture detail that did not work on a phone:** the agent added "×100" and the repetition lines to sketch A by itself; the user's brief did not ask for them. Sketch A had been picked on the canvas and passed the tests, so only the user's phone check caught it: the user disliked the picture and named "×100". The agent offered two revisions, and the user picked A3, which also drops the lines. Cost: one more round of sketches and PNGs.

### e. Prompt revisions
- **Before:** "일단은 내부 스케치로 쓰기로 결정하자. 그리고 W4를 시작하자." (interrupted by the user)
- **After:** the same lines plus the warning's content and the pictogram-above, message-below layout (quoted in item b).
- **Why it worked:** the added description became the brief for the three sketches and fixed the copy's intent before any code. The agent then only had to ask how the warning closes online and how the image is made.

### f. Manual fixes and why
- None by hand in this step. The user made the main decisions (item a), and the agent applied every change. No code was edited by a person, so there is no manual-fix marker.

### Takeaway
- Two sessions should not share one working tree; use a separate `git worktree` per step.
- A dialog's "closed by the user" and "removed by the app" need different answers.

## W2 `feat/help_screen` – battle rules screen and '?' on home (P10), 2026-10-27 ~ 2026-10-31

### a. Where AI was used
- **The screen (commit `ec36e9d`):** Claude Code wrote `gymrats_app/lib/screens/help_screen.dart` (L1–240), `gymrats_app/lib/widgets/help_pictures.dart` (L1–266) and `gymrats_app/lib/widgets/help_rules.dart` (L1–123), with their tests and the three `design_tokens_test.dart` paths.
- **The routing (commit `0d4828c`):** `gymrats_app/lib/services/user/rules_seen_store.dart` (L1–44), `gymrats_app/lib/viewmodels/help_viewmodel.dart` (L1–94), `gymrats_app/lib/viewmodels/signup_viewmodel.dart` (L83, L92, L139), and `gymrats_app/lib/main.dart` (the gate at L175–187, the `/help` route at L212–215), with their tests.
- **The '?' button (commit `d0f056b`):** `gymrats_app/lib/screens/home_screen.dart` L234–240, seven added lines and no other change in that file, with tests in `home_screen_test.dart`, `main_test.dart` and `auth_flow_test.dart`. Merging `origin/main` first (`d9c9c80`, no conflict) was also done by the agent, at the user's request.
- **Sketches:** Claude Design, three directions on a private canvas: A the card list already in code, B one screen, C three swipe pages. Internal only, as for W4. The agent also wrote the title options.
- **Review:** the `reviewer` subagent reviewed the code in four rounds: CHANGES_REQUESTED, then APPROVE, then APPROVE after the rebuild as C, then APPROVE for the '?' and the merge. A later round checked these notes (`progress.md` Review log).
- **Decided by the user:**
  - the flag per account, the option the agent marked recommended and the default the user's own prompt had named;
  - design sketches for this screen too (item e);
  - layout C, asking for several copy options and rejecting "바를 끝까지 밀어요", then the three titles out of the agent's options;
  - no push on 10-29, only local commits;
  - on 10-31, the merge, removing the `home_screen.dart` exception, the PR's first line and reviewer, and "아직" in the Manual check.
- **Proposed or decided by the agent, and reported to the user:**
  - a sign-up saves "not seen", 시작하기 saves "seen", and no saved flag counts as seen. The behavior was written into the question the user answered, and the agent reported the result afterwards;
  - 건너뛰기 on pages 1–2, part of sketch C;
  - the page bodies and rule rows, kept from the sketch. The user asked for several copy options; the agent offered them for the titles only and said so on 10-27;
  - the danger row's copy without a color (item c). The reviewer suggested the final wording.
- **Decided by the agent, and told to the user only at the notes review on 10-31:**
  - back on the first-login rules closes the app like any root screen. It was recorded in `progress.md` on 10-27, but no chat message said so;
  - the '?' icon (`Icons.help_outline_rounded`), its tooltip "게임 규칙", and its place left of the profile button.
- **Not done by AI:** the phone check. It is still open.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 10-27] "W2 feat/help_screen 시작해. W1(#13), W4(#15)는 PR 열려 있고 PM 리뷰 대기 중이야. […] home_screen.dart는 feat/squat_judge 머지 전까지 잠겨 있으니 건드리지 말고, '?' 버튼은 progress.md에 대기로 남겨." (shortened; full text in the log)
- [Woohyun Song, 10-27] "Help Screen도 Claude Design을 통해 디자인 시안 뽑고 나한테 검토받아"
- [Woohyun Song, 10-27] answer to the agent's question on the sketches (an answer, not a prompt, so it is not in the Prompt Log; from the session export): "C로 가되, 멘트 후보를 여러 개 뽑아서 가보자. '바를 끝까지 밀어요'는 특히 좀 별로야"
- [Woohyun Song, 10-29] "매칭이 잡히고 pose setup까지 완료해야 규칙 창이 뜨는 건가?"
- [Woohyun Song, 10-31] "W2(feat/help_screen)로 돌아가자. […] 2) '?' 버튼과 그 테스트를 넣어 줘. S2가 고친 home_screen.dart의 다른 줄은 건드리지 말고 꼭 필요한 줄만 바꿔." (shortened; full text in the log)

### c. What AI did well
- **Sign-up never flashes home:** `HelpViewModel.signedUp` (`help_viewmodel.dart` L61–69) switches to the rules before its first await, so the screen does not depend on how fast secure storage writes. A read that ends later is ignored. The reviewer asked for an app-level test of this in round 1, and "with slow phone storage, sign-up never shows home before the rules" now checks every frame.
- **A clear answer to a device question:** when the user asked on 10-29 whether the rules wait for the pose setup, the agent separated the rules screen (W2, sign-up and '?') from the safety warning (W4, match found). It also said the checked-out branch was W4, which has no rules code.
- **Design conflict brought up early (reviewer round 3):** the rules page said the screen flashes red, while wiki 2.5.2 has no red. The agent took the color out of the copy and told the user. The user settled the color in W3.
- **The reviewer's mutation run (round 4) found a real gap:** of 19 mutations, 2 survived, both making the `/help` route write the flag. Nothing in the tests pinned that '?' saves nothing. The code was correct, and two tests now pin it.
- **The lock checked, not assumed:** to see whether the `home_screen.dart` exception was still needed, the agent removed the line and then read the guard's `lock_state`, which was empty. The reviewer confirmed the check can fail: at `0d4828c`, before the merge, it reports the lock as closed.

### d. Hallucinations / errors
- **Font change on the score tags (reviewer round 1, Major):** the tags changed the font family, and wiki 2.5.1 allows only color and weight. Fixed on the same day. Cost: one review round.
- **Other round 1 findings (Minor):** a pill where tags take `AppRadius.small`, a 12 px icon gap where wiki 2.5.5 says 8, copy that said 푸시업 though squat comes later, and a comment that hid how `SignupScreen`'s own default skips the rules. All fixed.
- **Round 3 findings on the rebuilt screen (Minor):** spacing off the 2.5.5 table (20 and 12 where 16 and 8 belong), Korean tags on a style meant for the number font, no test of the icon colors, and an unbounded loop in a test helper. All fixed.
- **Flaky test set aside too quickly:** in round 1 a full run failed once in `battle_result_store_test.dart`, the forfeit test, with the two players' outcomes swapped. The agent and the reviewer recorded it as outside W2, because it passed alone 3 of 3 and in the later full runs. In W3's round 9 another test in that file failed once, by the checklist a Critical, and its message was not captured. The likely cause, not a proven one, is in the helper both tests use: both players joining at once. The fix (`d0ed8aa`) is on W3's branch, so this branch still has the old helper.
- **Replies back in English:** the user asked for Korean on 10-27, and the agent went back to English in later replies, so the user had to raise it again. It was then saved as a memory rule. Cost: two prompts.
- **A test weaker than its name (caught by the agent before review, 10-31):** the first long-name test's assertion passed at half a button's height, with a comment that did not match it. It now checks for at least twice the font size.
- **Hidden keys would have dropped prompts (caught by the agent before commit, 10-31):** the first plan hid W3's prompts in this Prompt Log, under the existing rule for prompts of another step. Three of them are not on W3's branch yet, so W3's next export would have skipped them. The W2 log now holds no W3 keys. The same rule had already hidden six W2 prompts during W4, and they moved back into W2's entries.
- **Scratch probe faults (reviewer, round 4):** a first name-length probe did not change the name shown, because `InMemoryUserRepository` ignores the nickname, and one probe run hung. The reviewer reported both. The results come from a second probe, and the agent stopped the hung run. No effect on the branch.

### e. Prompt revisions
- **Before:** the 10-27 start prompt (item b) listed the files and rules but no design step. The agent built a card list, which passed review round 2.
- **After:** "Help Screen도 Claude Design을 통해 디자인 시안 뽑고 나한테 검토받아"
- **Why it worked:** the user saw three directions before settling on one, and chose a different layout from the one in the code. Cost: the card list was replaced, and round 3 reviewed the screen again. In W3 the agent offered sketches first as its recommended option, and the user accepted it.
- **Before:** "한국어로 다시 적어."
- **After:** "지금 이 세션에서 계속 응답이 영어로 오는 문제가 있어."
- **Why it worked:** the first prompt fixed one reply. The second named the repeating problem, so the agent saved a rule that also covers later sessions.

### f. Manual fixes and why
- None by hand in this step. The user's decisions are listed in item a, and the agent applied every change. No code was edited by a person, so there is no manual-fix marker.

### Takeaway
- Ask for design sketches before the first build of a screen, not after its review.
- Hide a prompt's key only when that prompt is already logged somewhere: a hidden key stops every later export.
- Write "reported to the user" only for what a chat message said; a line in `progress.md` is not a report.

## W3 `feat/fever_score` – game layer: bar, judgments, fever, danger, KO (P8), 2026-10-30 ~ 2026-10-31

### a. Where AI was used
- **Rules and game layer:** Claude Code wrote `gymrats_app/lib/models/battle_rules.dart` (`BattleRules` L15–104), `game_score.dart`, `lib/services/game/battle_game.dart` and `player_game_score.dart` (`b9adb50`).
- **Bot battle:** `battle_viewmodel.dart`, `battle_result.dart` (`30a5450`); the bot's depths in `bot_opponent.dart` (L61–67, L113–117, `562f706`).
- **Battle server:** scoring, the grade check (`_grade`, L470) and the KO end (L427) in `server/lib/battle_server.dart` (`facac22`); the protocol section (`2b84d5f`).
- **Screens:** the health bar, fever chip and danger edge widgets, the panel and result screens (`8507790`, `3cfc477`, `32f38dc`, `532cfdc`). Claude Design: three internal sketches on a private canvas.
- **Online on the phone (`fb9fc34`):** `online_battle_session.dart` (`rules` L95, `_myPreview` L106, `_readRules` L412, `submitRep` L519) and `online_battle_screen.dart` (`_clockColor` L275, `_lastRepWords` L282, the danger edge L667).
- **Other people's files, under the user's exceptions, only the lines needed:** Django `server/matches/` and `server/tests/` (`d98d219`); `server_user_repository.dart` and `match_record.dart` (`80f7e43`).
- **After W2 merged (10-31):**
  - The merge `2e373ca`: four conflict files, both sides kept, by a script.
  - The judge's pass depth (`ded29b8`): `battle_viewmodel.dart` L223–224, `online_battle_session.dart` L521, `online_battle_screen.dart` L163.
  - The demo's reasons (`b2defe6`, `battle_demo.dart` L248).
  - `help_rules.dart` reading `BattleRules` (`439a9d0`), and the red icon (`db63c80`, `help_pictures.dart` L254).
  - The home hint (`65dfe2b`, `home_screen.dart` L178).
- **Tests:** all of the test files listed in `docs/testing/iteration-3/g1fted13.md`, W3 entries.
- **Review:** the `reviewer` subagent ran eleven code rounds: 1–3 logic, 4–6 UI and Django, 7–8 the red edge, 9–10 online and the bot upload, 14 the merge and the changes after W2. Rounds 1, 2, 4, 5, 7 and 9 asked for changes; round 14 was APPROVE with 5 Minor.
- **Decided by the user:**
  - The numbers stay the v0.1 values in one config, tuned by playing after H2 merges. The user settles the bar's rule details.
  - "젼부 추천대로 해줘": the eight open questions, each answered with the option the agent had marked as recommended: score-lead bar and KO at 100, danger 60+ behind, a new red token for the danger edge (answer 3), the winner order, server-side KO, Django left to its owner (answer 6), help numbers from the config, sketches first. The user later changed answers 3 and 6 (below).
  - Layout A, out of the agent's three sketches.
  - The danger edge: red (answer 3), then amber at the sketch review, then red again after talking with the team. The clock's last 5 s stay amber.
  - Django done in W3 with the user's conditions, instead of asking the owner first. The user tells the owner afterwards.
  - The bot upload's app side after S2 (answer A), then now (answer B), when S2 stopped being a separate PR.
  - Keeping `RepJudgeConfig().bottomDepth` instead of waiting for `counter.passDepth`, until W2 merged.
  - After W2 merged: the merge with both sides kept, the pass depth swap, the help numbers and the red icon. W3 fixing the home hint in the rules screen's words. The exception for that line, and, when the agent asked, for `home_screen_test.dart` and `help_rules_test.dart`.
- **Proposed or decided by the agent, and reported to the user:** the color values (`#3DE8FF`, `#FF3B30`: the sketch's defaults, the user named no other); rounding the KO round length up; the temporary local-check patch, not committed; combo and fever in the online words (the reviewer called this the user's call, and the agent decided it).
- **Decided by the agent, and told to the user only on 10-31, after the notes review asked:** the bot's depths 1.4 and 1.9; the words "K.O.로 끝났어요.".
- **Decided by the agent after W2 merged, and told to the user only on 10-31, after the notes review asked:** the hint's exact words; `submitRep`'s optional `passDepth` with a push-up fallback. An earlier progress note named them, but the export cannot show that it reached the screen.
- **Not done by AI:** the phone check of the bot battle (the user); server deployment (the PM).

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 10-30] "젼부 추천대로 해줘"
- [Woohyun Song, 10-30] "Django 두 가지는 상우(S4)에게 묻지 않고 W3에서 처리하고, 끝나면 내가 상우에게 알릴게." and "필요한 줄만 최소로 고쳐. 리팩터링이나 정리는 하지 마." (two lines of one pasted prompt)
- [Woohyun Song, 10-31] "위험 테두리 색은 앰버가 아니라 빨강으로 바꿔 줘." (one line of a pasted prompt)
- [Woohyun Song, 10-31] "상황이 바뀌었어. 상우가 S2를 따로 올리지 않고 S2·S4를 합친 실험용 PR #17(feat/squat_battle)을 올렸고, 진영이형이 #17은 W3가 머지된 뒤에 main을 받아서 머지하겠다고 리뷰에 남겼어." (first lines of a pasted prompt)
- [Woohyun Song, 10-31] "홈 버튼 힌트 \"30초 안에 더 많이 하면 승리\"가 W3의 점수 승리 규칙과 어긋나. W3가 규칙을 바꾸는 PR이니 이 문구도 W3에서 고쳐 줘." (one item of a pasted prompt)
- [Woohyun Song, 10-31] "지금 PR 들어간 거 conflict 생긴 거 같은데 그것도 확인해봐"

### c. What AI did well
- **One scoring code for phone and server:** it kept `player_game_score.dart` free of Flutter so the battle server imports the same class. In review round 10, a temporary probe through a relay (deleted after the round) found preview and server equal over 8 reps with mixed gaps.
- **Order on the wire:** a KO's `match.finished` goes out in a microtask (`battle_server.dart` L427), after the ACK, so both phones read the last score before the end. A test covers it.
- **Stayed inside W3's files:** the KO rep could drop from the pace chart in `feedback_screen.dart`, which W3 does not own. Rounding the KO round length up keeps it in the chart with no edit there.
- **Found a side effect before it happened:** Django's `PUT /matches/feedback/<id>` stores a report even with no match row (`server/matches/views.py` L121). So the local-check patch turns off that upload, and a local battle leaves no orphan row in the team's database.
- **Review probes:** the reviewer cut sockets through a relay against the real server: re-send, offline combo, an unseen KO. All passed, so the online code was tested beyond its unit tests.
- **The merge checked, not trusted:** after the four conflicts were resolved, a script compared every line of both sides with the result, and none was missing. In round 14, `git show --remerge-diff` showed hand changes only in those four files.
- **A side effect found and measured before it ships:** the pass depth swap makes every valid bot rep Excellent in a squat battle. The agent worked this out from the numbers and wrote it in `progress.md` before round 14, and the reviewer measured it over 1000 seeded rounds (19.8% to 100%). W3 builds cannot reach it, so it goes in the PR's note for #17, with the numbers.

### d. Hallucinations / errors
- **A claim made without reading the code:** the agent told the user online could be checked "with a local battle server". The user asked for the commands, and only then did the agent read the code. The app's address is a constant, the lobby does not allow a loopback `ws://`, Django login for the battle server takes only a loopback URL, and `server/bin/server.dart` crashes on Windows at `ProcessSignal.sigterm.watch()`. Reading the code found the address and the loopback rule; a trial run found the crash. The agent first noted the correction in `progress.md`; the notes review found no chat message that said it plainly, so the agent told the user on 10-31. Cost: a temporary patch for the check.
- **Own spec missed (reviewer round 9, Major):** `battle-rules.md` L219, written by the agent in W1, says the phone shows the label and +N at once from a local sum. The first online version waited for the ACK and showed the previous rep's score until then.
- **Clock kept counting after a KO (round 9, Major):** the result screen showed a live countdown beside "승리", turning cyan and amber. Fixed: the clock stops at `ended_at_ms`.
- **Assumed CSS behavior (round 5, Major):** `BoxShadow(blurStyle: BlurStyle.inner)` was used as an inset shadow. It filled the whole screen with amber. Widget tests disable shadows, so they passed; the reviewer's real render caught it. Fixed with four gradients and a pixel test.
- **KO numbers (rounds 1 and 2, Major):** a KO reported the full 30 s as the round length, giving a false pace. The first fix then dropped the KO rep from the pace chart.
- **Too big for real fonts (round 4, Major):** the score at 92 px and a speaker icon cut text at 360 wide. The test font had hidden it. A real-font test was added.
- **Tests that could not fail, caught by the agent:** a "reconnect" test only checked a replaced socket; a re-sent-ack test could not see a bug. Both were rewritten with a scripted server. A 5 s round was also waited on with a 5 s limit.
- **Flaky test (round 9):** one failure in four full runs in `battle_result_store_test.dart`. Likely two players joining at once on two sockets; the message was not captured. It is older than W3.
- **Reviewer guessed wrong too:** round 9 guessed the valid-reps row as the overflow at text scale 2.0, without identifying it. Round 10 found the real one, the health bar's label line.
- **Prompt Log extraction:** `extract_prompts.py` took a session summary and browser notices as prompts and missed two prompts typed while the agent was working. The agent corrected the entries by script against the export, and the notes review compared them with it.
- **An instruction skipped:** in the Django prompt the user asked to see the list of files before any edit. The agent said it would pull the list, then edited the files with no list shown (10-30). The notes review caught it in the export, and the agent told the user on 10-31. The same request on 10-31 was followed: list first, then edits.
- **An approval stretched (10-31):** the user approved the hint line in `home_screen.dart`. The agent also tried to add `home_screen_test.dart` and `help_rules_test.dart` to `.claude/ownership-exceptions.txt`, planning to mention them in its final report. The edit's note already said "reported to the user", before any report. The permission check refused the edit, with the reason `[Self-Modification]` and no file named; that the two files caused it is the agent's reading. The agent did not work around it: it recorded only the approved line, then asked the user to approve the two files, in a question that did not mention the refused edit. The user approved both. The agent told the user about the refusal on 10-31, after the notes review asked. Cost: one question.
- **A merge side effect missed (round 14, Minor):** the battle demo walks `RejectReason.values`, so S2's squat reasons reached the push-up demo. No conflict marked it, and the agent had not looked. Fixed in `b2defe6`, with a test that fails on the old code.
- **A test run that did not run:** the first full `flutter test` after the merge printed only `Test directory "test" not found`, and the tool reported exit code 0. An earlier command had left the shell in the repo root, where there is no `test` folder. The 0 was the exit code of the `tail | cut` at the end of the line; flutter itself exits 1 (reproduced in review). Reading the output caught it, and a rerun with an explicit `cd` into `gymrats_app/` and `pwd` printed ran the tests. When the notes review named this cause, the agent first remembered a `cd` in that command; the session record showed there was none.
- **Own command hung:** one command began with a stray `cat > /dev/null`, which waited for input until the 300 s limit. The agent stopped it. Cost: about five minutes.
- **Stale text (round 14, Minor):** a comment in `help_rules.dart` still said the danger color was open, and three `progress.md` records were old or incomplete. All fixed.
- **Note claims ahead of the evidence (round 15, 4 Major):** these notes first said "reported to the user" for progress notes the export cannot show on screen; said the agent told the user the two files had not been its call, when its question did not mention the refused edit; said the rerun was from the same folder and the cause was not found, when the session showed the cause; and said the squat table was already in the PR. The reviewer checked them against the session export and the live session. All fixed before the push.

### e. Prompt revisions
- **Before:** "Django의 ko와 봇 업로드 승패·종료 사유는 상우와 얘기해서 결과를 알려 줄게."
- **After:** the Django prompt in item b, with its conditions: only the needed lines, and stop to ask before touching anyone else's file outside `server/matches` and `server/tests`.
- **Why it worked:** the owner question became a bounded edit with a stop condition. The agent changed five of S4's files by minimal lines, asked before touching the app-side files, and handed back a summary for the owner. One condition was not kept: see "An instruction skipped" in item d.

### f. Manual fixes and why
- None by hand in this step. The user decided (item a), and the agent applied every change, so there is no manual-fix marker.

### Takeaway
- Before saying a check is possible, read the code path it needs and run it.
- Reread your own spec before coding against it.
- An approval covers what it names: ask before adding a file it only implies.
- Read a run's output, not only its exit code.

## W3b `feat/average_score` – Average +5, three score grades (team order #6b), 2026-11-01

### a. Where AI was used
- **Rules and game layer (`2421242`):** Claude Code wrote `BattleRules.averagePoints`, `averageMaxElbowAngle`, `isAverage` (`battle_rules.dart` L19–20, L87), `PlayerGameScore.addAverage`, `addRep` (`player_game_score.dart` L45, L67), and the new `lib/services/game/rep_grade.dart`.
- **Bot battle screens (`2421242`):** the Average banner (`battle_score_panel.dart` L323, L432), the result's grade line (`result_screen.dart` L438–L500). `battle_viewmodel.dart` L307 is the one approved line.
- **Online (`3fd242d`):** `online_battle_session.dart` (`_readRules` L422, `_repScore` L433, `submitRep` L548–L566), `online_battle_screen.dart` (`_lastRepWords` L284, `_gradeWords` L309), `server/lib/battle_server.dart` (`_grade` L469, `average_points` L507, L522), the protocol section.
- **Bot depths (`867312e`):** `bot_opponent.dart` L68, L96–L99, L136. **Help (`c8d42c5`):** the fourth tile and the shrink in `help_pictures.dart`. **Rules doc (`28e6ba8`):** `battle-rules.md` 3.6.
- **The line moved to 120° after the user's phone check (`5c47a3e`):** Claude Code changed `BattleRules`, the rules page's sentence (`help_rules.dart`), `battle-rules.md` 3.6, the protocol's number, and eight test files.
- **Tests:** all the test files listed in `docs/testing/iteration-3/g1fted13.md`, W3b entry; a later check in `d5e9c54`.
- **Review:** the `reviewer` subagent ran code rounds 17 and 18, CHANGES_REQUESTED then APPROVE with 3 Minor, and notes rounds 19 to 21, which asked for changes twice (item d). Round 19 also rechecked those 3 Minor fixes in code. For the 120° change the user asked for the new parallel review, four lenses in one message (round 22): spec asked for changes, tests, design and hygiene approved, and only spec reran, on the fix diff (round 23). The notes and the PR draft then went to the hygiene lens alone.
- **Decided by the user (with the PM, as the user reported):** the three grades and their points; the 105° line and its evidence; Go lower only; fever, combo and valid-rep behavior; the bot's rejected reps staying 0; the `passDepth` design for the bot, with #17 passing it; the condition not to touch the judge and the #17 files; the PR's first line and reviewer. When the agent asked: the one line in `battle_viewmodel.dart`, and adding `battle_score_panel.dart`.
- **Decided by the agent, without asking the user:** the `average_points` handshake; the banner's two lines at a fixed 60 height; the result's one-line card and the online text line; counting grades from the phone's records and accepting the gap; `judgeFor(exercise)` for the result's pass depth; the help sentence; putting Average in section 3.6 to keep the numbers; leaving the view model's stale comment. A squat never earns Average: this follows from the user's Go lower rule. Before the first push, the session record held no chat message listing these; only the move to section 3.6 had a chat line (item d). The first push's closing message listed them all (transcript 18:18:44Z, UTC, a text block).
- **After the phone check, decided by the user:** the line at 120° and its evidence; not fixing the large-text problems here; Good's strictness as a team item only; the parallel review. **Decided by the agent:** stating the number on the rules page, as its reading of "도움말 설명 ... 같이 고쳐 줘". **Then, under the user's "네 판단으로 고치고":** the design lens's wording for it; narrowing the user's stated reason about dropping the head in `battle-rules.md`; naming the recording's 2 extra nods (both in item d).
- **Not done by AI:** the phone checks of W2, W3 and W3b (the user). Telling the PM about the view model's line (the user). Server deployment (the PM).

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-01] "Average 기준을 105°에서 120°로 바꿔 줘(BattleRules 상수). 근거: 내 녹화에서 정직하지만 지쳐서 얕아진 rep이 110~126°, 팀 녹화의 꼼수 3개는 127.8~145.2°. 점수는 팔꿈치만 보니 고개 숙이기는 점수에 영향 없음." (one item of a pasted prompt)
- [Woohyun Song, 11-01] "S4(#17)가 고치는 battle_viewmodel.dart, rep_counter_viewmodel.dart, pose_avatar_toggle_view.dart는 건드리지 마. 거절된 rep도 BattleGame._add로 들어오니 점수 계층에서 처리해. 세 파일 중 하나라도 필요해 보이면 고치기 전에 멈추고 물어봐." (one item of a pasted prompt)
- [Woohyun Song, 11-01] answers to the agent's two questions (answers, not prompts, so not in the Prompt Log; from the session export): "한 줄 추가 (Recommended)" and "목록에 추가 (Recommended)".

### c. What AI did well
- **Followed the value instead of the prompt's premise:** the prompt was right that rejected reps reach `BattleGame._add`, but `_scoreMyNewReps` rebuilt each `RepEvent` without `minElbowAngle`, so a bot battle could never have given Average. The agent found this by reading the path before coding, stopped as the prompt asked, and asked with a merge preview against #17 at `d8ad424` (the same 2 conflict regions, no new one). Removing the line fails `battle_viewmodel_test.dart` and four `battle_screen_test.dart` tests.
- **Old server checked in the code:** the W3 server's `_grade` refuses a rejected rep with a grade, so a simple new field would have broken new apps on a W3 server. The agent added `average_points` as a handshake, and the reviewer confirmed the mix against the real `0465943` session and server in both directions.
- **Exact default:** `passDepth / 1.1` is exactly 1 at the default, so push-up depths keep their exact values. In round 19 the reviewer compared bot plans over 500 seeds at 30, 45 and 60 s with `origin/main` by `cmp`: byte-identical.
- **Stale score handled before review:** `myLastScore` stays on the last scoring rep, so a later rejected rep could have shown `+5 AVERAGE`. The banner and the online line check the rep itself, with tests, and the reviewer's mutations of those guards failed.
- **A check beyond the brief:** replaying the team's recorded sets showed the recording's 3 Go lower head nods, at 127.8–145.2°, earning 0. It cannot confirm the 90–91° side, and the testing notes say so.
- **The trade-off written down:** moving to 120° makes the user's older range for head nods (109–135°) overlap the new range for tired reps (110–126°). The agent wrote that into `battle-rules.md` 3.6 and the PR instead of listing only the two ranges that separate.

### d. Hallucinations / errors
- **A regression at large text (reviewer round 17, Major):** the fourth tile made `_ScoreTile` too narrow, so "Excellent" broke mid-word at text scale 1.3 on 360 wide. The agent's real-font test ran only at 1.0. The fix shrank the labels; round 18 then found the numbers break the same way at 2.0 ("+1/0"), which round 17 had also not measured.
- **A named test not written (round 17, Major):** `task.md` asked for real fonts on the result widgets, in the agent's own wording, and the agent added none. Added.
- **Tests that claimed more than they asserted (rounds 17 and 18, Minor):** "keeps the reason and the points whole" was only `find.text`; after the rewrite a reason cut to 40 wide still passed. "Stays the size of the others" had no size check. Mutants proved both, and the checks were added.
- **Banner taller than the others (round 17, Minor):** the two-line banner overflowed by 7 px at 360x780 at text scale 1.5. It is now a fixed height that shrinks.
- **Doc renumbering (caught by the agent):** Average first went in as section 3.3, which moved 3.5 to 3.6 and broke a test name's reference. A grep caught it, and Average moved to 3.6.
- **Test mistakes (caught by the test runs):** a test opened the screen twice; a line check compared tops of cells that shrink by different amounts, and failed at scale 2.0 with nothing wrong on screen.
- **A blocked command:** one command staged code and also called `.claude/hooks/ownership_guard.py`, so `guard_git.py` read it as staging harness files. No harness file was being staged; the agent split the command and did not touch the hook.
- **A note claim with no record behind it (rounds 19 and 20, Major):** these notes first said the agent's decisions were "told to the user in chat on 11-01", and the agent told the reviewer the same. The agent believed it had told the user. The only record is a block stored as `thinking` (transcript 17:37:02Z, UTC), addressed to the user and naming the categories and the squat point; no assistant text block holds it. So nothing shows it reached the user, and the notes no longer claim it. The agent's first correction then said the record held nothing at all: its own check had required words that block does not contain, and round 20 found the block. This is the same class of finding as rounds 11, 12 and 15. Cost: two review rounds.
- **A reason from the prompt written down as fact (round 22, Major):** the prompt said "고개 숙이기는 점수에 영향 없음", and the agent put that into `battle-rules.md`, `task.md`, `progress.md` and the body of commit `a5889ef` (never pushed, amended into `5c47a3e`) without checking it. The spec lens found it too wide: among reps closed as Go lower, Average reads only the angle, but depth is the nose's (`rep_judge.dart` `_depth`), so dropping the head can close a rep as Go lower or valid. Fixed before the push: the doc says the narrower thing, the number stays the user's. In the first W3b prompt the agent had checked the premise; this time it did not.
- **"Team recording, 3 cheats" taken at face value (round 22, Minor):** the three are the Go lower reps of one recording. Its other two nods, at 112.5° and 129.8°, are rejected as `kneesDown` by a known error. The earlier replay printed only Go lower reps, so it had hidden them. The doc now names them.
- **A test check that compared two broken things (round 19, Minor):** the points check compared "+10" with "+15", so when both broke to two lines it still passed. It now compares both with "+5".

### e. Prompt revisions
- **Before:** "Go lower(insufficientDepth)로 거절된 rep 중 minElbowAngle이 105° 이하인 것만 +5."
- **After:** "Average 기준을 105°에서 120°로 바꿔 줘(BattleRules 상수)." (item b)
- **Why it worked:** the first number came from recordings, and playing it on a phone showed Average almost never appearing, which the tests could not show. The number lived in one place, so the change stayed small.
- **What did the work in the first prompt:** its stop condition. "세 파일 중 하나라도 필요해 보이면 고치기 전에 멈추고 물어봐" turned the wrong premise into one question instead of an edit or a workaround.

### f. Manual fixes and why
- None by hand in this step. The user decided (item a), and the agent applied every change, so there is no manual-fix marker.

### Takeaway
- Follow a value from where it is made to where it is read before trusting that it arrives.
- A test named for a limit must run at that limit; mutate it to see that it can fail.
- A reason in a prompt is a claim too: check it against the code before writing it down as fact.

## W5 `feat/bot_difficulty` – the bot's difficulty, 초보, 중수, 고수 (team order #12), 2026-11-01 to 11-02

### a. Where AI was used
- **Levels and bot (`1207c85`):** Claude Code wrote `lib/models/bot_difficulty.dart` (all numbers), `Opponent.at`, `BotMatchRequest`, `Matchup.rematch` (`matchup.dart` L20, L31, L58), `BotOpponent.difficulty`, `forMatchup` and the plan's counts and combo chance (`bot_opponent.dart` L30, L77, L110–L117), and `battle_screen.dart`'s one line.
- **Picker (`661614f`, `ffbcb91`):** `lib/widgets/bot_difficulty_sheet.dart`, the painter included; `_startMatching` and the reload guard (`home_screen.dart` L71, L83); the level through `matching_viewmodel.dart`, `matching_screen.dart`, `main.dart`, `result_screen.dart`.
- **Leave dialog (`706e5a2`, `a2f6c64`, `8ba3723`, `34b49ad`):** `gameMessage`, `_lineWidth`, `_withParticle` (`exit_dialog.dart` L55, L65, L85), and one line of `online_battle_screen.dart` L331. **Rules doc (`674228b`):** `battle-rules.md` 4.5. **Match card (`a7cfbde`):** the name's line and the exercise's, `match_record_card.dart` L45–L60. **Connection to #17 (`19b62ed`, `12042d8`):** the conflict's resolution (`battle_screen.dart` L77), `forMatchup`'s required depth (`bot_opponent.dart` L30), `_startMatching(exercise)` and both buttons (`home_screen.dart` L83, L229, L234).
- **Sketches:** three rounds on a private Design canvas, internal only: A, B, C; then C1, C2, C3; then D1, D2, D3, which were the agent's readings of the user's instructions.
- **Tests:** the files listed in `docs/testing/iteration-3/g1fted13.md`, W5 entry; `0700310`, `f50d660`, `a2f6c64`, `1fb8dfe`, `8ba3723` and `34b49ad` after the reviews, `a7cfbde` with the card, after the phone check, and `19b62ed` and `12042d8` with the connection.
- **Review:** four lenses in one message on the code of `674228b`, reviewed before that commit's message was rewrapped. spec and design approved with Minor findings. tests asked for changes (a criterion's result leg had no test), and hygiene asked for changes (#23 had merged, item d). The fixes and the notes then went to those two lenses: tests approved, and hygiene asked for changes again (item d); on that fix, hygiene approved (round 28). The user's new rule for the leave dialog then went to all four lenses, on the fix diff (round 29): spec, tests and design approved, and hygiene asked for changes (item d), which round 30 rechecked. The long name's line went to the same four, on its fix (round 31): spec, tests and hygiene approved with Minor findings, and design asked for changes (item d). Its fix went to design, which approved (round 32). The match card went to the same four, uncommitted, before the user's recheck (round 33): spec approved with no findings; design, tests and hygiene with Minor findings. The notes and the PR draft went to hygiene (round 34), which asked for changes (item d) and approved the fix (round 35). The merge and the squat button went to the same four (round 36): all approved, each with Minor findings. The notes and the PR draft went to hygiene (round 37), which asked for changes (item d) and approved the fix (round 38).
- **Decided by the user:** the step's scope, branch and order; the numbers; layout C with level-specific pictures, then the minimal style and D3; the name "AI 봇 · 초보"; the same three levels for the squat bot; and the approval of every file beyond the first list, including 다시 매칭 keeping the level and the 와/과 fix, both proposed in the agent's question. That question named the fix only as 초보과의 to 초보와의. **Then, told what it reached:** the fix applying to online names; the rule for names that are not Hangul ("Mike 님과의", "상대와의" for no name); one line in `online_battle_screen.dart` and one in each of two test files; the bot's pass depth following `counter.passDepth` at #17's merge; telling 상우 himself after the PR opens; keeping the section 11 bullet and D3. **After the PR opened:** 진영 as reviewer; a long name on its own line, in the user's words, with a generous limit; no icon on a sideways screen, from the options the agent gave; the commits staying local until tonight's push. **After the phone check:** the match card's layout, from the three the agent gave; the four files outside W5's list, which they had said to ask about first. **After #17 merged:** the merge of `e975cba`, the bot's line and `forMatchup`'s required depth in their words, the squat button through the sheet, the check of the online squat button, one note in the ownership file, the push after their phone check, and leaving the squat judge's depth to #17's owners.
- **Proposed by the agent, chosen by the user:** one more number for 중수's combos (`comboChance` 0.08), from its measurement.
- **Decided by the agent, without asking the user:** the sheet's title and the cards' words as sketched; "초보 AI 상대를 찾는 중"; keeping `Matchmaker.findOpponent`'s signature (its fake is in PM-only `fakes.dart`) by putting the level on the found bot; `BotMatchRequest`; the 30 s basis, which changes a 60 s round's most mistakes from 3 to 4; the combo gap of 0.8 of the window; the pink steps in D3 (70, 85, 100%; outer lines 70%); leaving `versus_screen.dart` and `opponent_window.dart` as they are; the reload guard; a bullet in `battle-rules.md` section 11; at first, letting the 와/과 fix cover online names, which the prompt's "온라인은 건드리지 않음" did not allow for (item d). The first closing message listed them (transcript, the message after round 28). After that: a test of the online line in `online_preparation_test.dart`, under the prompt's "관련 테스트"; and leaving the wrap in the leave dialog as it was, which the user then asked to fix. For that fix: reading a line's width from each letter's measured width rather than counting letters, and a room of 240, so 7 Hangul syllables take three lines though they would just fit. The closing message of 08:44:59Z UTC listed the online test, the wrap and an empty reviewer field; the user then chose 진영. For the card: up to three lines for a name, and no line limit on the exercise's line. The report before the recheck showed each name's lines and the time wrapping from text scale 1.1, but named neither limit; the closing message of 18:40:02Z UTC does. For the connection: the merge commit holding the resolution, what it needs to compile, and the test pinning the resolved line; `openSheetWith`, and a missed tap failing in `home_screen_test.dart`; a test through the real `BattleGame`; leaving the no-save test out, as its file is outside W5's list. The closing message before the phone check named the false pass, the commit split and the no-save gap, not the `BattleGame` test.
- **Not done by AI:** the phone checks (the user, 2026-11-02). The card's two lines: PM OK (11-02), as the user reports. Reporting the squat judge's depth to 진영 and 상우: the user. Telling 상우 about the files on S4's list that W5 edits, listed in the PR's notes and the closing message of 08:44:59Z UTC: the user.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-01] "지금 봇이 고수에 가까워서, 지금 값을 고수로 두고 중수와 초보를 만든다." (one line of a pasted prompt)
- [Woohyun Song, 11-01] answer to the agent's question (an answer, not a prompt, so not in the Prompt Log; from the session export): "C1~C3 다 별로야. 기존 C와 같은 미니멀한 디자인에서 별과 같은 아이콘을 통해서 난이도를 나타내. 픽토그램이나 C같은 미니멀한 스타일을 선호하는 거야. 단지 난이도에 따라 그림이 달랐으면 좋겠는 거고. 내가 참고하라고 한 overwatch reference도 다시 한 번 참고해"
- [Woohyun Song, 11-02] "기록 탭과 홈의 최근 경기 카드에서 상대 이름이 "푸쉬업 · vs AI 봇 · ..."로 잘려서 난이도가 안 보여. 결과 화면에서는 다 보여. 폭 360에서도 레벨까지 보이게 고쳐 줘." (one part of a pasted message)
- [Woohyun Song, 11-02] "봇은 BotOpponent.forMatchup(widget.matchup, passDepth: counter.passDepth)로 정리하고, forMatchup의 passDepth를 필수로 바꿔." (one part of a pasted message)

### c. What AI did well
- **Measured a word in the prompt:** "가끔" for 중수's combos looked like it would follow from the pace. A probe with the real scoring showed 5.5% of rounds, against 62% for 고수, so the agent asked with the numbers and the option of one more setting. Reviewer round 26 reproduced 5.3% with its own simulation.
- **Followed the name to where it reads badly:** "AI 봇 · 초보" reaches `ExitDialog.game`, whose fixed 과 would read "초보과의". The agent found this while reading the path, and asked for the file with the reason, before any edit. The same reading found `battle_screen.dart` (it builds the bot) and 다시 매칭, neither on the first list.
- **Pinned the old behavior before changing it:** the agent printed the old bot's plans first, so "고수 is today's bot" is a test. Round 26 confirmed it over 50,000 seeds against the old source.
- **Its tests found two real problems:** `excludeSemantics` had removed the card's tap for a screen reader, and closing the sheet reloaded home through `didPopNext`. For the second, the agent fixed the code, not the pinned `fetchCount`.
- **A check that can fail:** 14 mutations of the changed code after the reviews named the ones that might survive, 6 on the final rule, 7 on the long name's line, 4 on the sideways icon and the widths, and 5 on the match card, each failing its test file.
- **Measured a limit before using it:** the design lens suggested three lines from 8 characters. "AI 봇 · 초보" has 9, so that would have changed every bot's dialog, which the user had said to keep, while 7 W's overflow below it. The agent measured the font first, used widths, and tested 182 names at 360 wide with the real fonts.
- **Searched before applying a new rule:** the user's rule was "exit_dialog.dart 안에서만 처리하고". A search for the sentence found a second copy in `online_battle_screen.dart`, so the rule alone would have shown "Mike 님과의" and then "Mike과의" in one online match, and two tests outside W5's files that pin the old words. The agent asked, with both cases, before editing.
- **Found a crash before the merge:** a read-only dry merge at `3801f7d` showed that #17's squat button merged with no conflict and would crash at `main.dart`'s cast, which `flutter analyze` does not see. The plan went to the user with the fix before any file changed, and the mutation of that button now fails three tests.
- **Traced the whole squat path (round 36, spec):** the lens read from the button to 다시 매칭 and found what the phone then showed: a user's squat reps have no depth, so they can never read Excellent. The agent checked it in the code first and told the user what to watch for, and the user confirmed it on the phone.
- **Stopped at the file the user named:** the user said to ask first if the fix left W5's files. The agent measured with a probe outside the repo (room 141.3, line 160), listed the four files and the three layouts with those numbers, and edited nothing until the answer.

### d. Hallucinations / errors
- **Sketches the user rejected (user):** the first request asked for the same cute RepBot growing stronger and gave props, faces and badges as examples. The agent drew those literally. "C1~C3 다 별로야" (item b): the user wanted C's minimal pictogram. Cost: one sketch round.
- **A reference not opened, then not reachable:** the user's link was only for an idea, so the agent drew C1–C3 without opening it. Asked to look again, it got a Cloudflare challenge (403) from both WebFetch and curl, and the Chrome tools were disconnected. It did not try to get past the challenge, and search found no description of the icons. D1–D3 rest on the user's words, and the agent told the user so with the sketches.
- **A stale premise (round 26, hygiene, Major):** #23 merged at 14:48 KST, during this session, and the agent never fetched again. `task.md` and `progress.md` still said it was not merged, and the checks ran against the old guard result. The merge changed no file, so nothing was lost, but "#23이 머지되면 origin/main을 merge해" was the user's own instruction.
- **A criterion with no test (round 26, tests, Major):** nothing checked the level's name on the result screen; the code was right.
- **A test that could not fail (round 26, tests, Minor):** "leaving home while the sheet is open" pumped an empty widget, so the awaited sheet never returned. Rewritten with a home removed under the sheet; removing `!mounted` now fails it.
- **A meaningless test, caught by the agent:** one test, named for 중수 needing its combo chance, asserted almost nothing and said so in its own comment. Deleted before its first run.
- **Weak checks (round 26, tests, Minor):** 초보's 0% Excellent had a 4% tolerance; the combo rule was only statistical, and three mutations would have survived; a pixel test read alpha only; a source-line test claimed behavior in its name.
- **An approval read too widely (round 27, hygiene, Major):** these notes first called the online 와/과 change approved. The question named only the bot's 초보과의, and no message before it mentioned online names, while the prompt fenced online off. The agent's own commit message, written after the answer, says the fix covers online names such as 철수, and it still did not ask. The fix stayed, since the Korean is right and the change was unpushed. The closing message told the user, who kept it for online names and set a rule for names that are not Hangul.
- **A claim about online that was not complete:** the notes and the closing message called the leave dialog the only online change, and said the fix covers online names. `online_battle_screen.dart` had its own copy with a fixed 과, so that screen would have kept "철수과의". The agent had grepped for `ExitDialog.game`, not for the sentence, and round 26's spec lens, which read the same callers, did not see it either. Found by the search above.
- **A marker moved by accident (round 29, Major):** the new online tests went between an existing marker and its test, so the pushed code would have said 진영 reviewed tests written today, and the old test would have lost its marker. Moved. The file's own diff should have shown it.
- **A criterion left out of the PR draft (round 29, Major):** the draft mapped seven of `task.md`'s eight criteria; the missing one was online, the one teammates would look for first.
- **A file's owner half told (round 29, Minor):** the question to the user called `online_battle_screen.dart` W3's and W3b's file. It is also on S4's list, by region, outside this line. The closing message of 08:44:59Z UTC corrected it.
- **A fix that hid a button (round 31, design, Major):** the user asked for three lines and for no overflow at 640x360, and the agent's tests passed. The render showed the leave button below the fold on a sideways screen, with nothing to show it could scroll. The tests scrolled to it first, so they could not see it. The agent asked with the options, and the user chose to leave out the icon when sideways. A new test checks both answers with no scrolling, under a status bar.
- **Widths taken from a wrong style at first, caught by the agent:** the first probe measured 14 with no spacing, an unresolved style, not the dialog's 16 and 0.5. It printed the style's null size, and the agent scaled the numbers to the real one. Round 31's lenses measured the font on their own, and found one group slightly short: lowercase 9.7 against 9.78. Fixed.
- **A test that passed while the phone showed the bug (the user's phone check):** "shows whole in the history card" passed, and the notes and the PR counted it for the criterion, while the phone cut the name. It put the card straight in a Scaffold, with 181 of room against the phone's 141, as the screens have 20 side margins. Replaced by a group on the real history tab and home: 36 of its tests fail on the old card, all from the cut. Cost: one phone round.
- **Previews that did not match (found by the agent after the answer):** the question drew home's card with no date, though home passes `showDate: true`, and 12 W's on three lines, though the render showed two. The agent told the user before the recheck. The layout the user chose did not change.
- **A claim ahead of the facts (round 34, hygiene, Major):** these notes first said that the card's two limits were named in the report before the recheck. That report showed each name's lines and named neither limit, so the user had not been told what the line claimed. Corrected above, and the closing message names them.
- **A sentence gone stale (round 34, hygiene, Major):** the PR draft's list of what #17 edits came from `d8ad424` and still held at `3801f7d`. The agent had read `5f81140`, which also edits `main.dart` and `online_battle_screen.dart`, and had not gone back to the draft. Rewritten from the file-by-file overlap, with the conflict rechecked in a dry merge.
- **A test that passed with its tap missed (found at the merge, by the agent):** #17 made home longer, so `closing the difficulty sheet does not load home again` tapped outside the screen, the sheet never opened, and the test passed. The agent saw the warnings in the run's output, after one neighboring test failed. Tests now check that the sheet opened, and a missed tap fails.
- **Findings credited to the phone (round 37, hygiene, Major):** the draft and the testing note said a squat battle's no-save was found on the phone, had the user reporting all three findings, and called an older line #17's. The user had reported only Excellent, and the rest came from reading the code. "The phone check covered the battle" also read as covering two untested lines. Both now say which is which.
- **A filter that hid those warnings (round 36, tests, Minor):** the output saved for the review kept only the last lines, so a reader could not see missed taps. The last full run on this code, before its commit, keeps all of it and counts none; the run on `ae8f010` kept the tail, and `main_test.dart` and `home_screen_test.dart` show none.
- **Spacing off the table (round 26, design, Minor):** the sheet kept the sketch's 8, 20 and 32, where wiki 2.5.5 gives 12 and 24.
- **The doc's source not recorded (round 26, spec, Minor):** `battle-rules.md` 4.5 says the real `planRound`, and the temporary test that ran it was in no record, which named only the earlier scratch copy. Recorded now.
- **Sketch drawn from memory:** the sketches' robot path was the agent's recollection of the app's icon, and the design canvas's rules say not to render it, so it was not compared. D3 uses C's simpler robot instead, and the shipped picture is drawn in code.

### e. Prompt revisions
- **Before** (an answer to the agent's question, from the session export): "지금의 귀여운 RepBot 디자인(얼굴, 몸 형태, 색감)은 세 레벨 모두 그대로 유지하고 ... 표정, 소품, 몸집, 배지 같은 요소로 차이를 줘."
- **After:** "기존 C와 같은 미니멀한 디자인에서 별과 같은 아이콘을 통해서 난이도를 나타내." (item b)
- **Why it worked:** the first listed elements, and the agent drew each one. The second named the style to keep and one icon to use, which left little to guess, and the user chose from the next three.

### f. Manual fixes and why
- None by hand in this step. The user decided (item a), and the agent applied every change, so there is no manual-fix marker.

### Takeaway
- Fetch again before trusting what a branch's state was at the start of a long session.
- Measure a vague word in a spec before building to it.
- A test that passes on an empty widget proves nothing: mutate the line it claims to guard.
- A width test belongs on the real screen: a widget alone has room the phone does not.
- A tap followed by a negative check proves nothing until the test knows the tap landed.

## W6 `feat/score_history` – game points in the records, and the squat guide text (team order #13), 2026-11-02

### a. Where AI was used
- **Server (`b36a3e0`):** Claude Code wrote `Match.my_score`, `opponent_score` and migration `0003_match_scores`, the serializers (`serializers.py` L12, L61, L91), `internal.py` L180, L196, and `bests` in `/users/me` (`accounts/views.py` L77).
- **Online (`8a3fed1`):** one line of `battle_server.dart`, and the Iteration 3 section of `docs/iteration-2-protocol.md`.
- **App (`e704c3a`):** `MatchRecord`'s scores, `PersonalBest`, `UserProfile.bestOf` (`user_profile.dart` L5, L51), both repositories, the card's numbers (`match_record_card.dart` L132), `_BestRecord` (`home_screen.dart` L403).
- **Guide text (`acf8a49`):** `_GuideCard` by exercise (`matching_screen.dart` L484).
- **Squat bot battles and the dash (`0644fe0`, `46ee9b3`, `69cef1e`):** one line of `battle_viewmodel.dart`, `PersonalBest.isEmpty` in `bestOf` (`user_profile.dart`), and a test of the squat upload. **Outcome pins (`784bc00`):** after the user's question.
- **Sketches:** plans A and B and the squat pictogram on a private Design canvas, internal only. They are for the next PR, `feat/home_layout`.
- **Tests:** the files listed in `docs/testing/iteration-3/g1fted13.md`, W6 entry.
- **Review:** four lenses in one message on the uncommitted code (round 39): design and hygiene approved with Minor findings; spec and tests asked for changes (item d). The fixes went to those two (round 40): both approved, with Minor findings, all fixed. The squat save and the dash went to the same two (round 41): both approved with Minor findings, and the missing squat upload test was added. The commits, these notes and the PR draft went to hygiene (round 42), which asked for changes (item d); its fixes and the phone result went back to it (round 43), which approved with Minor findings, all fixed.
- **Decided by the user:** the scope and the order; home plan B, from the sketches; two PRs; "3회 : 5회" for old records; the squat text as the agent proposed it, to be checked on the phone; starting from W5's head before its merge, then merging `main`; the `accounts` files and `battle_server.dart`, on 진영's OK as the user reports it; the protocol doc and two test files, in answer to the agent's question, and the lobby's test in another; keeping the files the agent had added to the step's list (below); the date taking two lines, and the 12 letter name wrapping; the feedback line staying one line; pinning the largest scores in a test; saving squat bot battles and keeping 2~3 m, on 상우's answers, as the user reports them; "—" for a user who has not played.
- **Decided by the agent, without asking the user:** adding the display, guide, doc and test files to the step's list, beyond the user's words (item d), and saying so in its next message; the personal best's order, in which a first low score replaces a reps best; keeping `best_reps`; the deploy order; widening that "—" to a battle with no points and no reps; nullable fields, both scores or neither on POST (a 422); `MAX_SCORE` 100000, generous because the app drops a refused upload; `bests`' shape, with points and reps possibly from different battles; a server with no `bests` reading as push-up reps; `internal.py` storing points only when both players have them, since a refusal would lose the result; a best of 0 points reading as reps, so one such battle does not turn "32회" into "0점"; 2000 as the largest score tested, from the judge's limit; the guide's four lines, the words unchanged; two test lines pinning the game's outcome, after the user asked only to check it and note the result; the commit split; rewrapping the unpushed commit messages; the next branch's name. The closing message lists them.
- **Not done by AI:** asking 진영 for the `accounts` files and `battle_server.dart`, and getting 상우's two answers: the user, with 진영. The phone check (round 1), and spotting the cards in item d: the user. The redeploy: the PM.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-02] "할 일: Django Match에 점수 필드와 마이그레이션, 앱의 저장·불러오기, 홈 카드·기록 탭·개인 최고를 점수로 표시, 온라인 결과 저장에도 점수 포함. 점수가 없는 예전 기록은 횟수로 표시. 개인 최고는 종목별(푸쉬업, 스쿼트)로." (one part of a pasted message)
- [Woohyun Song, 11-02] "W5(#24)는 30bccb9에서 CI가 녹색이고 진영이형 merge만 남았어. 시간을 아끼려고, merge를 기다리지 말고 지금 feat/bot_difficulty(30bccb9)에서 feat/score_history를 만들어 시작해 줘." (one part of a pasted message)
- [Woohyun Song, 11-02] "하나 확인해 줘: 데모 카드 중 90 : 100과 164 : 206이 "승"으로 나와(내 점수가 더 낮은데 승). 임시 패치가 점수만 넣고 승패는 예전 횟수 기준으로 남아서 그런 건지, 아니면 실제 기록에서도 점수와 승패가 어긋날 수 있는지 확인해 줘." (one part of a pasted message)
- [Woohyun Song, 11-02] answer to the agent's question (an answer, not a prompt, so not in the Prompt Log; from the session export): "그대로 두자. 대신 하나만 확인해 줘. 이번 판에서 나올 수 있는 가장 큰 점수(예: 양쪽 다 세 자리 최댓값, KO 판 포함)를 넣어도 점수 숫자 자체와 "vs 상대 이름" 줄은 폭 360에서 안 잘리는지 테스트로 고정해 줘."

### c. What AI did well
- **Read the path before planning:** the prompt named Django and the app. Reading the code first showed that the battle server left `game_score` out of what it posts to Django, and that the best is in `server/accounts/`, outside the permission given. Both went to the user before any file changed, and the user got 진영's OK for both.
- **Corrected the prompt's place for the sentence:** the prompt put "머리 앞 약 1m" after a match is found. A search showed it only on the search screen, shared by bot and online, so one card fixes both.
- **Looked at the render, not only the tests:** the guide's tests passed, and a real-font picture showed it breaking inside "두세요" and "머리부터". Measuring gave the last line 229.3 of 230, so the agent set four lines by hand instead of three.

### d. Hallucinations / errors
- **A list wider than the user's words:** the user said to put only "server/matches/와 기록 저장 파일" on the step's list. The agent also added the display, the guide text, the rules doc and their tests, because the task needed them, and told the user in its next message. The user kept them, but the agent had decided first.
- **A list edit with no approval (the guard, then the permission check):** the guard blocked the first edit of `bot_difficulty_sheet_test.dart`, and adding that file and a new font test file to the list, with no approval, was refused. It was not worked around: the new tests went into files already on the list, and the user was then asked about the one file still needed.
- **A temporary patch that read wrong (the user's phone check):** the agent's sample scores for the demo had no stored outcome, so the cards "90 : 100" and "164 : 206" read 승. The user asked whether real records could do the same. The agent traced both paths: no, as a real battle always stores the game's outcome, and it pinned that in two tests. The patch was never committed.
- **Credit and promises that were not so (round 42, hygiene, Major):** these notes first listed every file beyond the first list as the user's decision, and said the prompts were followed as written. The PR draft said a first low score replaces reps "as the task says", though that order is the agent's, and said the user tells 상우 about his files, which the user did not say in this step. All corrected before the push.
- **A file's owner half told (round 39, hygiene, Minor):** the question to the user called all three files the user's own. `docs/iteration-2-protocol.md` is also on S4's list whole. The closing message corrects it.
- **A criterion half tested (round 39, spec and tests, Major):** the guide's criterion names bot and online, and only bot had a test. Hard-coding the lobby to push-up passed everything. The code was right, and a new test now fails on that mutation.
- **A width test that left out a line (round 39, tests, Major):** the real-font group's rows read "피드백 없음", so no test saw the feedback line narrowed by the points. Testing every title found `바닥 푸시업 아님 12회` cut, which went to the user, who accepted it.
- **A test measuring one number twice (round 40, spec and tests, Minor):** with equal scores, `.first` found my number both times, so the opponent's, nearest the edge, was never measured.
- **A test whose first half checked nothing (round 40, spec and tests, Minor):** "the scores survive a refused report and a retry" cleared the requests before reading the body sent without the report.
- **A spec number from memory, caught by the agent:** `task.md` said one score alone is a 400. This server answers bad bodies with 422, which the agent saw while writing the test.
- **A clock read wrongly, caught by the agent:** `TZ=Asia/Seoul date` printed UTC labelled KST on this PC. The agent compared it with the last commit's time before telling the user the hour.
- **Records behind the code (rounds 39 and 40, Minor):** rows above a table's separator, a file cited for two results it did not hold, and `task.md` and `progress.md` lagging behind the 0 point rule.

### e. Prompt revisions
- None in this step: no prompt was rewritten. Later messages brought new decisions, as in item a.

### f. Manual fixes and why
- None by hand in this step. The user decided (item a), and the agent applied every change, so there is no manual-fix marker.

### Takeaway
- Read a change's whole path before planning it: the file that drops the value may be outside the permission asked for.
- A criterion that names two cases needs a test for each, even when they share a widget.
- A width test must have every line a real row has.

## W6b `feat/home_layout` – home leads with the two battle modes (team order #13b), 2026-11-02 to 11-03

### a. Where AI was used
- **The sheet (`8185c70`):** Claude Code wrote `showExerciseSheet`, `ExerciseSheet`, `ExercisePictogram` and the squat's drawing (`exercise_sheet.dart`).
- **The cards and home (`57e845e`):** `BattleModeCard`, `BattleModePicture`, `_RepBotPainter` (`battle_mode_card.dart`); `_startOnline`, `_startBot`, the `_inSheet` guard and the new layout (`home_screen.dart` L51, L89-L116).
- **The rules doc (`ceb51c0`):** one line, the home card's name (`battle-rules.md` section 4.5).
- **Sketches:** board B1 and the Picto board on a private Design canvas, internal only, made during W6.
- **Tests:** the files listed in `docs/testing/iteration-3/g1fted13.md`, W6b entry.
- **Review:** four lenses in one message on the uncommitted code (round 44): spec and hygiene approved; design and tests asked for changes (item d). The fixes went to those two (round 45): both approved, with Minor findings, all fixed. These notes and the PR draft went to hygiene (round 46), which asked for changes (item d); its fixes went back to it (round 47), which approved with Minor findings, all fixed. The phone result and the merge went to it last (round 48), which approved with one Minor finding, fixed.
- **Decided by the user:** plan B on board B1, not B′, from the agent's sketches; two PRs, with this one second; Requirements 5.7 criterion 1 and the screens table's Home row on the "PM 확인" list; starting this step right after W6's PR; registering the step, and keeping the files the agent had added to its list (below); moving the sheet's best in points to the phone check after the redeploy; the review request to 진영. Home and the squat button's parts of 상우's files are on 진영's OK, as the user reports it.
- **Decided by the agent, without asking the user:** adding home, the new widgets, their tests and the tap's lines in two test files to the step's list, beyond the user's words, and saying so in its next message, without naming those tests, where it called the tap's lines one line each, though they are 3 lines and 1 line changed to 3; branching from `d04b8c1`, since #28 was not merged, so this PR could not go up until it was; leaving "depends on feat/score_history" out of the PR, against `task.md`'s first words, as nothing is left to depend on once #28 has merged (`task.md` updated); `titleLarge` for the sheet's number and "VS", larger than on the board, as the wiki allows only color and weight to change; card padding 16, not the board's 12; sections 24 apart and titles 8 above their content, including the "최근 경기" title's gap that this step would not otherwise touch; RepBot's own painter, in full pink on the figure's floor, instead of W5's picture at 0.7 from a file not on this step's list; "…" on home's section note at a very large text size; 100000 as the largest best in the overflow test, from the server's limit; accepting that the sheet reads the best once when it opens; keeping `.last` in the two test files outside this step's own, to keep those diffs small; the longer "PM 확인" list; the commit split.
- **Not done by AI:** the phone check (round 1, items 1 to 9 pass as the user reports): the user. The wiki edits, the merge and the redeploy: the PM.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-02] "1. 홈은 B로 갈게." (one part of a pasted message)
- [Woohyun Song, 11-02] "2. 홈은 B안으로 확정. 요구사항 5.7 기준 1과 화면 표의 홈 행은 W6b PR의 PM 확인 항목으로 두자." (one part of a pasted message)
- [Woohyun Song, 11-02] "3. 홈 개편(B안)과 스쿼트 매칭 안내 문구도 W6에 넣으래. 홈과 스쿼트 버튼 쪽 상우 파일은 PM이 허용했어." (one part of a pasted message)
- [Woohyun Song, 11-02] "확인되면 임시 데모 패치를 되돌리고, 말한 순서대로 push와 PR까지 진행해 줘. 그다음 바로 W6b(홈 B안)를 시작하자." (one part of a pasted message)
- [Woohyun Song, 11-03] "W6b 폰 확인 결과야(작업 폴더 빌드, Galaxy S947N): 1~9번 모두 됨. 10번(데모 앱에서 시트의 개인 최고 "N점")은 재배포 뒤 2차 확인 때 실서버로 보기로 했어. 노트에는 그렇게 적어 줘." (one part of a message)

### c. What AI did well
- **Did not delete what looked unneeded:** the tests lens asked whether removing the strut fails a test, and the agent's fix list said to keep it only if a mutation showed it was needed. Removing it failed no test. Before deleting it, the agent swept 128 sizes: 38 overflowed without it and 0 with it. The strut stayed, and 24 of those cases became a test that fails without it.
- **Kept a guard working over two sheets:** home reloads when a page closes above it, and a sheet is a page. `_inSheet` stays set from the first sheet through the second, and the tests pin both directions: no reload on closing, a reload after a later page.

### d. Hallucinations / errors
- **Credit that was not so, again (round 46, hygiene, Major):** item a credited the user with registering the step and left out that the agent had widened its list, the error round 42 found in W6. Item c credited the review with the agent's own rule. Notes and the PR draft said home had two start buttons, where it had four. The AI notes called two test files other people's, which the ownership data does not say. All corrected before the push.
- **A sketch followed past the wiki (round 44, design, Major):** the sheet's number and "VS" changed `fontFamily` on a title style, which wiki 2.5.1 rule 3 does not allow, and the cards had padding 12, not 2.5.7's 16. Both came from the agent's own board. Fixed, so both numbers are larger than on the board.
- **A criterion half tested on the real app (round 44, tests, Major):** the task's real routes test covered AI only, so a broken online route would have passed `main_test`. Fixed, for both exercises.
- **A guard with nothing pinning its release (round 44, tests, Major):** no test failed if `_inSheet` was never reset, which would leave home stale after every later battle. The new tests fail on both mutations.
- **A short list for the PM (round 44, design, Major):** the list named 5.7 and the screens table but not 5.2's old labels, 2.5.7's and 2.5.2's lines, or the README's other rows. Round 45 added one more README row.
- **A comment that was not so (round 44, design, Minor):** the code said RepBot stands on the figure's floor, using a picture that did not, and drew it at W5's 0.7. It got its own painter and a test of the floor.
- **A wrong reason recorded (round 45, tests, Minor):** `progress.md` said a descendant finder needed an import outside the permitted lines. `BottomSheet` comes from `material.dart`, already imported. The reason was corrected, and `.last` stays because the checks after it would fail if it hit the wrong text.
- **Pins that let a wrong shape through (round 45, tests, Minor):** the squat's ankle and toe swapped, and RepBot's body floating, passed. Each has a pin now, and each mutation now fails.
- **A tap that missed, caught by a test setting:** the card test tapped the picture's center, which is empty. `hitTestWarningShouldBeFatal` failed it rather than letting it pass with nothing done.
- **An overflow by 2.8 px, caught by a real-font test:** at text scale 2 the best's line measured short, because its number is bigger than the words around it. That is why the strut went in.

### e. Prompt revisions
- None in this step: no prompt was rewritten.

### f. Manual fixes and why
- None by hand in this step. The user decided (item a), and the agent applied every change, so there is no manual-fix marker.

### Takeaway
- A sketch is not the design system: check its sizes and styles against the wiki before coding them.
- When a mutation of a line passes, find out what the line is for before deleting it or adding a test.
- A guard needs a test of what it stops and of what it lets through again.
