# AI Collaboration Report: Iteration 3 (2026-10-23 ~ 2026-11-06)

- **Written by:** Jinyoung Park (PM)
- **Contributors:** Woohyun Song, Hyunwoo Song, Sangwoo Hahn, Jinyoung Park
- **Tools used:** Claude Code (Opus 5.5; Fable 5.1 for the PM), Codex (Sangwoo), Claude Design (Woohyun, internal sketches only), GitHub Actions CI (PR #14)
- **Full input prompts:** wiki sub-page [AI Collaboration Report – Iteration 3 – Prompt Log](AI-Collaboration-Report-–-Iteration-3-–-Prompt-Log) (in the repo: `docs/ai-collaboration/AI-Collaboration-Report-Iteration-3-Prompt-Log.md` and `iteration-3/*-Prompt-Log.md`); each member's notes: `docs/ai-collaboration/iteration-3/`

## 1. Where AI Was Used
- **Battle game, rules screen, safety warning, bot levels, score history, Home** (Woohyun, Claude Code): `lib/services/game/`, `help_screen.dart`, `safe_warning_dialog.dart`, `bot_difficulty.dart`, migration `0003_match_scores`; PRs #13, #15, #20, #21, #23, #24, #28, #29.
- **Push-up recordings and judge accuracy** (Hyunwoo, Claude Code): the recorder and replay test (`rep_judge_demo.dart`, `pushup_error_cases_test.dart`), the judge rules in `rep_judge.dart` (#22) and the tuning after the evaluation (#32).
- **Squat judge, squat battles, matching per exercise, avatars, opponent view** (Sangwoo; Claude Code for the design doc, Codex for the code): `docs/iteration-3/squat-judge-design.md`, `lib/services/pose/squat_rep_judge.dart`, `services/matching/`; PRs #17–#19, #25–#27.
- **PM work** (Jinyoung, Claude Code): the CI workflow (#14), the AI evaluation plan, set and runner (`test/ai_eval/`, #16, #30, #31), dry and trial merges of every PR, the redeploy, the HE data, the wiki pages.
- **Not used, or limited on purpose:** the 32 evaluation recordings and their labels (people, record sheets); every rule and threshold (agents proposed, users chose); approving, merging and the wiki (PM only); phone checks.

## 2. Prompt History (one per member; all in the Prompt Log)
- [Woohyun, 10-30] "젼부 추천대로 해줘"
- [Hyunwoo, 11-02] "근데 배를 대면 엉덩이나 무릎 관절 값이 유의미하게 이상하게 달라져야하지 않나"
- [Sangwoo, 10-28] "task 수행해"
- [Jinyoung, 11-03] "그거 걍 너가 보고 확인해봐 아마 세트마다 label이 똑같을 거임"

## 3. What AI Did Well
- **Replay before every rule change** (Hyunwoo): a per-rep replay split the 34 missed normal reps by cause and took M1 from 46.0 % to 79.4 % with M2 at 90.8 % (#32, `test/ai_eval/results/2026-11-03_main-269eba7_after-pr32.md`).
- **One scoring code for phone and server** (Woohyun): `player_game_score.dart` is Flutter-free, so the battle server imports it; a relay probe found preview and server equal (`server/lib/battle_server.dart` L9, L62); a KO's end is sent after the last score's ACK (L427).
- **Read the path before coding** (Woohyun, #23): `_scoreMyNewReps` dropped `minElbowAngle`, so Average could never appear; found before the first edit and raised as one question.
- **Dry merges** (Jinyoung): a chained `merge-tree` of `main` + #25 + #17 showed the only conflict was in Sangwoo's docs; #17 merged clean (`757a6e2`), about an hour saved.
- **Reviewer subagent:** before #15 it reproduced a logout read as "back" with a probe test (`safe_warning_dialog.dart`).

## 4. Hallucinations / Errors
- **Recording standard from memory** (Hyunwoo): set 8 was written as a straight-arm dip on the toes, which the judge cannot label `armsStraight`; caught while answering the PM, changed before recording. Set 4's "about 140°" is a top for the judge; caught only when the user saw bent-arm reps counted. Cost: set 4 lock-outs read as other reasons in the evaluation.
- **A check claimed without reading the code** (Woohyun): "online can be checked with a local battle server", but the address is a constant and the lobby refuses loopback. Caught when the user asked for the commands; cost: a temporary patch for the check.
- **CSS assumed in Flutter** (Woohyun): `BlurStyle.inner` as an inset shadow filled the screen with amber; widget tests disable shadows, so only the reviewer's render saw it.
- **"W3 needs no change"** (Sangwoo): `battle_viewmodel.dart` always saved a push-up `FormReport` (the squat guard is now at L437), so squat needed three W3 edits. Caught by the reviewer; two rounds.
- **A label re-serialized** (Jinyoung): the JSON writer re-indented a whole case file, so one label edit became a 142,749-line diff; caught by `git diff --stat`, redone as +20/−2. Cost: ~3 min.

## 5. Prompt Revisions
- Hyunwoo: "팔 덜펴기는 빠군 기준 적용하면? 배대기는 어떻게 적용해야 고쳐질까?" → "근데 배를 대면 엉덩이나 무릎 관절 값이 유의미하게 이상하게 달라져야하지 않나". Naming the joints turned a search for one line into a per-person comparison, which found the difference at the top of the rep.
- Woohyun: "Go lower(insufficientDepth)로 거절된 rep 중 minElbowAngle이 105° 이하인 것만 +5." → "Average 기준을 105°에서 120°로 바꿔 줘(BattleRules 상수)." A phone check showed Average almost never appearing; one constant made the change small.
- Jinyoung: "지금꺼 확인해서 반영" → "머지해". "확인" produced only a review; the explicit verb made the tool act.

## 6. Manual Fixes and Why
- No hand edits to app or server code this iteration, so no manual-fix marker was added: every change went through an agent after the user's decision. The Claude Code steps had the reviewer subagent; Sangwoo's Codex steps (#17, #25–#27) had no independent review, as his notes say.
- The manual work was recording and labelling the evaluation set, the phone checks, and the PM's merges and server steps, run with the agent step by step.

## 7. Takeaway for Iteration 4
- Check a judge change on recordings it was not tuned on before merging it; #32 is in-sample.
- Read the code path a claim needs before stating it, and name the clock, file or constant behind every rule.
