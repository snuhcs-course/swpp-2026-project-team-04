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
- **Tests:** all of the test files listed in `docs/testing/iteration-3/g1fted13.md`, W3 entry.
- **Review:** the `reviewer` subagent ran ten rounds: 1–3 logic, 4–6 UI and Django, 7–8 the red edge, 9–10 online and the bot upload. Rounds 1, 2, 4, 5, 7 and 9 asked for changes.
- **Decided by the user:**
  - The numbers stay the v0.1 values in one config, tuned by playing after H2 merges. The user settles the bar's rule details.
  - "젼부 추천대로 해줘": the eight open questions, each answered with the option the agent had marked as recommended: score-lead bar and KO at 100, danger 60+ behind, a new red token for the danger edge (answer 3), the winner order, server-side KO, Django left to its owner (answer 6), help numbers from the config, sketches first. The user later changed answers 3 and 6 (below).
  - Layout A, out of the agent's three sketches.
  - The danger edge: red (answer 3), then amber at the sketch review, then red again after talking with the team. The clock's last 5 s stay amber.
  - Django done in W3 with the user's conditions, instead of asking the owner first. The user tells the owner afterwards.
  - The bot upload's app side after S2 (answer A), then now (answer B), when S2 stopped being a separate PR.
  - Keeping `RepJudgeConfig().bottomDepth` instead of waiting for `counter.passDepth`.
- **Proposed or decided by the agent, and reported to the user:** the color values (`#3DE8FF`, `#FF3B30`: the sketch's defaults, the user named no other); rounding the KO round length up; the temporary local-check patch, not committed; combo and fever in the online words (the reviewer called this the user's call, and the agent decided it).
- **Decided by the agent, and told to the user only on 10-31, after the notes review asked:** the bot's depths 1.4 and 1.9; the words "K.O.로 끝났어요.".
- **Not done by AI:** the phone check of the bot battle (the user); server deployment (the PM).

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 10-30] "젼부 추천대로 해줘"
- [Woohyun Song, 10-30] "Django 두 가지는 상우(S4)에게 묻지 않고 W3에서 처리하고, 끝나면 내가 상우에게 알릴게." and "필요한 줄만 최소로 고쳐. 리팩터링이나 정리는 하지 마." (two lines of one pasted prompt)
- [Woohyun Song, 10-31] "위험 테두리 색은 앰버가 아니라 빨강으로 바꿔 줘." (one line of a pasted prompt)
- [Woohyun Song, 10-31] "상황이 바뀌었어. 상우가 S2를 따로 올리지 않고 S2·S4를 합친 실험용 PR #17(feat/squat_battle)을 올렸고, 진영이형이 #17은 W3가 머지된 뒤에 main을 받아서 머지하겠다고 리뷰에 남겼어." (first lines of a pasted prompt)

### c. What AI did well
- **One scoring code for phone and server:** it kept `player_game_score.dart` free of Flutter so the battle server imports the same class. In review round 10, a temporary probe through a relay (deleted after the round) found preview and server equal over 8 reps with mixed gaps.
- **Order on the wire:** a KO's `match.finished` goes out in a microtask (`battle_server.dart` L427), after the ACK, so both phones read the last score before the end. A test covers it.
- **Stayed inside W3's files:** the KO rep could drop from the pace chart in `feedback_screen.dart`, which W3 does not own. Rounding the KO round length up keeps it in the chart with no edit there.
- **Found a side effect before it happened:** Django's `PUT /matches/feedback/<id>` stores a report even with no match row (`server/matches/views.py` L121). So the local-check patch turns off that upload, and a local battle leaves no orphan row in the team's database.
- **Review probes:** the reviewer cut sockets through a relay against the real server: re-send, offline combo, an unseen KO. All passed, so the online code was tested beyond its unit tests.

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

### e. Prompt revisions
- **Before:** "Django의 ko와 봇 업로드 승패·종료 사유는 상우와 얘기해서 결과를 알려 줄게."
- **After:** the Django prompt in item b, with its conditions: only the needed lines, and stop to ask before touching anyone else's file outside `server/matches` and `server/tests`.
- **Why it worked:** the owner question became a bounded edit with a stop condition. The agent changed five of S4's files by minimal lines, asked before touching the app-side files, and handed back a summary for the owner. One condition was not kept: see "An instruction skipped" in item d.

### f. Manual fixes and why
- None by hand in this step. The user decided (item a), and the agent applied every change, so there is no manual-fix marker.

### Takeaway
- Before saying a check is possible, read the code path it needs and run it.
- Reread your own spec before coding against it.
