# AI Collaboration notes: Iteration 3 (2026-10-23 ~ 2026-11-06) – Woohyun Song
Status: draft (iteration open) | Written by: Woohyun Song | Merged by the PM into `AI-Collaboration-Report-Iteration-3.md`
Tools used: Claude Code (Opus 5.5), with the repo's `reviewer` subagent (`.claude/agents/reviewer.md`)

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
