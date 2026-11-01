# AI Collaboration notes: Iteration 3 (2026-10-23 ~ 2026-11-06) – Sangwoo Hahn
Status: draft (iteration open) | Written by: Sangwoo Hahn | Merged by the PM into `AI-Collaboration-Report-Iteration-3.md`
Tools used: Claude Code (Opus 5.5), with the repo's `reviewer` subagent (`.claude/agents/reviewer.md`)

Evidence per step, items a–f of the AI Collaboration Report Guidelines v1.1. Input prompts are in
[Sangwoo-Hahn-Prompt-Log.md](Sangwoo-Hahn-Prompt-Log.md). Answers the user picked in the agent's questions are not
prompts, so they are quoted here from the session export.

## S1 `docs/squat_judge_design` – squat rep judge design (P5), 2026-10-28

### a. Where AI was used
- **The design document:** Claude Code drafted all of `docs/iteration-3/squat-judge-design.md` and the diagram `docs/iteration-3/images/squat-setup-and-depth.svg`, on `docs/squat_judge_design`.
- **Grounding in the code:** before writing, it read `lib/services/pose/rep_judge.dart`, `setup_checker.dart`, `lib/models/rep_event.dart`, and `lib/viewmodels/rep_counter_viewmodel.dart`. It also searched for every `ExerciseType` / `RejectReason` switch and `.values` user, and for every caller that passes `judge:`. The file lists in §6 come from that search.
- **Proposals:** the agent proposed the front view (the OPEN item in `task.md`), the depth measure (hip–knee gap over standing thigh length), the thresholds (pass depth 0.75), and the two squat reject reasons with their Korean texts. All are marked "제안" (proposed) in the doc for the team to confirm in PR review.
- **Review:** the `reviewer` subagent reviewed the doc in three rounds: CHANGES_REQUESTED, then CHANGES_REQUESTED, then APPROVE. A fourth round checked these course notes: CHANGES_REQUESTED (two prompts from the harness-install sessions were filed under S1 in the Prompt Log), then fixed. It compiled stand-ins for the doc's Dart code with `dart analyze` and recomputed the worked examples.
- **Not done by AI:** the user decided who changes 송우현's (W3) files. The agent offered two options, and the user picked "S4 does it instead" over asking W3 (item d). Real squat depth values still need a phone and a person, so the thresholds stay "실측 필요" (needs measurement).

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Sangwoo Hahn, 10-28] "task 수행해"
- [Sangwoo Hahn, 10-28] answer to the agent's question on who changes the W3 files (an answer, not a prompt; from the session export): "S4 does it instead"
- [Sangwoo Hahn, 10-28] "Notes, commit, push"

### c. What AI did well
- **Kept teammates' files compiling:** the search found that W3's `lib/demo/battle_demo.dart` (`_TouchJudge`) and H's `test/demo/rep_judge_demo_test.dart` pass a `RepJudge` or a subclass of it as `judge:`. So §4.1 keeps that parameter and adds `exerciseJudge:`. A plain type change would have broken files the S2 branch may not edit.
- **Checkable examples:** the two worked reps in §5 use round pixel values. The reviewer recomputed every depth in them (0.33, 0.75, 0.94, 0.47, 0.03; 0.29, 0.48, 0.08), and they all matched.

### d. Hallucinations / errors
- **"W3 needs no change" was wrong (reviewer round 1, Major):** the first draft said the result screen hides push-up feedback for squat, so `battle_viewmodel.dart` needs no change. In fact `battle_viewmodel.dart` (L314–326) always builds and saves a push-up `FormReport`, which opens again from home and history. Fix: §6.4 lists the three small changes S4 makes in W3 files (R1–R3) after an approved ownership exception, as the user decided. Cost: two review rounds.
- **No way for W3 to read `passDepth` (round 1, Major):** the interface had `passDepth`, but the judge sits in a private field of `RepCounterViewModel`. Fix: a `passDepth` getter in §4.1.
- **Online grading contradicted the battle rules (round 2, Major):** a fix in round 1 said the server grades online reps per exercise. `battle-rules.md` §7 says the phone grades with `passDepth` and sends `grade`. Fix: the text now follows §7.
- **Region overreach (round 2, Major):** the round 1 fix had S4 edit report creation in `online_battle_screen.dart`, which is outside S4's "pass the exercise" region. It became change R2 in §6.4, which S4 makes after an approved ownership exception.
- **Threshold from nothing (round 1, Minor):** the first draft treated a torso drop of 1.0 as "standing". H's data shows a plank top already at 1.05–1.22. The value was raised to 1.8, and the doc cites those numbers.

### e. Prompt revisions
- None this step. The single prompt "task 수행해" was enough, because `task.md` holds the spec.

### f. Manual fixes and why
- None this step. The user did not edit the doc by hand. No code changed, so there are no markers.
