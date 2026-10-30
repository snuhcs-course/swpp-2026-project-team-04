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
