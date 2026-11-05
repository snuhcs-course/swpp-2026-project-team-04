# AI Collaboration Report: Iteration 3 (2026-10-23 ~ 2026-11-06)

- **Written by:** Jinyoung Park (PM)
- **Contributors:** Woohyun Song, Hyunwoo Song, Sangwoo Hahn, Jinyoung Park
- **Tools used:** Claude Code (Opus 5.5; Fable 5.1 for the PM), Codex (Sangwoo), Claude Design (Woohyun, internal sketches only), GitHub Actions CI (PR #14)
- **Full input prompts:** [Prompt Log](AI-Collaboration-Report-–-Iteration-3-–-Prompt-Log) (repo: `docs/ai-collaboration/*-Prompt-Log.md`); each member's notes: `docs/ai-collaboration/iteration-3/`

## 1. Where AI Was Used
- **Battle game, rules screen, safety warning, bot levels, score history, Home** (Woohyun, Claude Code): `lib/services/game/`, `help_screen.dart`, `safe_warning_dialog.dart`; PRs #13–#15, #20–#24, #28–#29.
- **Push-up recordings and judge accuracy** (Hyunwoo, Claude Code): the recorder and replay test, the judge rules in `rep_judge.dart` (#22, #32).
- **Squat judge, squat battles, matching per exercise, avatars** (Sangwoo; Claude Code for the design doc, Codex for the code): `squat-judge-design.md`, `squat_rep_judge.dart`; PRs #17–#19, #25–#27.
- **PM work** (Jinyoung, Claude Code): CI (#14), the AI evaluation plan, set and runner (`test/ai_eval/`, #16, #30, #31), trial merges, the redeploy, the HE data, the wiki.
- **Not used, or limited on purpose:** the 32 evaluation recordings and their labels (people, record sheets); every rule and threshold (agents proposed, people chose); merging and the wiki (PM only); phone checks.

## 2. Prompt History (the prompt that worked best per member; all in the Prompt Log)
- [Woohyun, 11-01] "리뷰 결과에 따라 고칠 게 있으면 네 판단으로 고치고 […] PR #23 본문 갱신까지 끝내 줘. 내 결정이 꼭 필요한 일이 생기면 그 단계에서 멈추고 progress.md에 질문을 적어 둬."
- [Hyunwoo, 10-27] "110도 규칙 일단 빼고, 3프레임 연속일때만 키고, 어깨 내려감 0.70 이상 추가하면 좋을 것 같고, 배 내리기는 너가 말한데로 고치면 될 것 같긴한데 배로 안걸러지면 어차피 무릎으로 걸러질 것 같고(이건 확인해봐) […]"
- [Sangwoo, 11-01] "일단 두 가지 작업을 병렬로 진행해줘. 푸쉬업과 똑같은 템플릿으로 스쿼트 온라인 1대1 대결(AI아님) 작업해줘. […] 45도 시점에서 보이도록 해줘."
- [Jinyoung, 10-25] "저번 iter때 branch를 각각 PR올리고 merge 할떄 conflict가 자주 일어났고, PR 순서가 명확하지 않아서 문제가 발생했어. […] 각 사람마다 specific한 harness를 만들어서 zip파일로 줘봐."

## 3. What AI Did Well
- **Replay before every rule change** (Hyunwoo): a per-rep replay split the 34 missed normal reps by cause and took M1 from 46.0 % to 79.4 % with M2 at 90.8 % (#32, `test/ai_eval/results/`).
- **One scoring code for phone and server** (Woohyun): `player_game_score.dart` is Flutter-free, so the battle server imports it (`battle_server.dart` L9, L62); a relay probe found preview and server equal.
- **Read the path before coding** (Woohyun, #23): `_scoreMyNewReps` dropped `minElbowAngle`, so Average could never appear; found before the first edit.
- **Dry merges** (Jinyoung): a chained `merge-tree` of `main` + #25 + #17 found the only conflict in Sangwoo's docs; #17 merged clean (`757a6e2`), about an hour saved.

## 4. Hallucinations / Errors
- **Recording standard from memory** (Hyunwoo): set 8 was written as a straight-arm dip on the toes, which the judge cannot label `armsStraight`; caught while answering the PM. Set 4's "about 140°" was a top for the judge; caught only when bent-arm reps counted, so set 4 lock-outs were misread in the evaluation.
- **CSS assumed in Flutter** (Woohyun): `BlurStyle.inner` as an inset shadow filled the screen with amber; widget tests disable shadows, so only the reviewer's render saw it. Cost: one review round.
- **"W3 needs no change"** (Sangwoo): `battle_viewmodel.dart` always saved a push-up `FormReport` (squat guard now at L437), so squat needed three W3 edits. Caught by the reviewer; two rounds.
- **A label re-serialized** (Jinyoung): the JSON writer re-indented a case file, so one label edit became a 142,749-line diff; caught by `git diff --stat`, redone as +20/−2. Cost: ~3 min.

## 5. Prompt Revisions
- Hyunwoo: "팔 덜펴기는 빠군 기준 적용하면? 배대기는 어떻게 적용해야 고쳐질까?" → "근데 배를 대면 엉덩이나 무릎 관절 값이 유의미하게 이상하게 달라져야하지 않나". Naming the joints turned a search for one line into a per-person comparison, which found the difference at the top of the rep.
- Woohyun: "Go lower(insufficientDepth)로 거절된 rep 중 minElbowAngle이 105° 이하인 것만 +5." → "Average 기준을 105°에서 120°로 바꿔 줘(BattleRules 상수)." A phone check showed Average almost never appearing; one constant kept the change small.
- Jinyoung: "지금꺼 확인해서 반영" → "머지해". "확인" produced only a review; the explicit verb made the tool act.

## 6. Manual Fixes and Why
- No hand edits to app or server code, so no manual-fix marker was added: every change went through an agent after the user's decision; Sangwoo's Codex steps (#17, #25–#27) had no independent review, as his notes say.
- Manual work: recording and labelling the evaluation set, the phone checks, the PM's merges and server steps.

## 7. Takeaway for Iteration 4
- Check a judge change on recordings it was not tuned on before merging it; #32 is in-sample.
- Read the code path a claim needs before stating it; name the file or constant behind every rule.
