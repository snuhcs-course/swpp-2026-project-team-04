# AI Collaboration Report: Iteration 3 (2026-10-23 ~ 2026-11-06)
Status: draft (iteration open)
Written by: Jinyoung Park (PM) | Contributors: Woohyun Song, Hyunwoo Song, Sangwoo Hahn
Tools used: Claude Code (Fable 5.1, Opus 5.5), GitHub Actions CI (PR #14)

This page covers the PM's work. Each member's own notes for their tasks are in `docs/ai-collaboration/iteration-3/<github-id>.md` with a `-Prompt-Log.md` beside it; the team review of every member's exported sessions is done at the close of the iteration.

## 1. Where AI Was Used
- PM review and merge of the team-plan PRs #17, #20–#29: Claude Code read each diff, ran dry merges (`git merge-tree`) and trial merges in a scratchpad worktree with `flutter analyze`, `flutter test` and `pytest`, then merged with a merge commit and posted the PM comment (e.g. #28 comment 6576313391, #29 comment 6582061544).
- Team merge-status page (claude.ai artifact "Iteration 3 merge 순서") and the PM plans in `~/Downloads/gymrats-iter3-*.md`: drafted and updated by Claude Code after every merge.
- Testing Documentation Rev.2.0 (wiki commit `6b716c6`, 11-01): UAT plan (§6, six stories) and the AI module test plan, drafted by Claude Code from the course guideline and the Requirements page.
- AI module test: branch `test/ai_eval_cases` — the PM's eight recordings (`929418a`), the per-rep labels of the HS/SWH sets (`08bd2e9`), and the replay runner `gymrats_app/test/ai_eval/eval_cases.dart`, `eval_cases_test.dart`, `ai_eval_test.dart` with the README sections "The set as recorded" and "Running" (11-03): Claude Code wrote them from the frozen plan (`eval_plan.dart`, `eval_scorer.dart`, PR #16) and the existing replay loader.
- Server redeploy of 2026-11-03 from `main` `e6b16fe` (Django `migrate` 0003, battle server release `20261102T174257Z-main-e6b16fe`): commands prepared and run by Claude Code step by step with the user's OK.
- Heuristic-evaluation data: the seven `hr01`–`hr07` accounts and 28 dummy battles were created through the public API by a one-off script Claude Code wrote (kept outside the repo).
- `README.md` on this branch (`iteration-3-demo`), this report and the Testing Documentation results entry: Claude Code.
- Not used: recording the 32 push-up evaluation sets (people on real phones, labels by the recorder), the heuristic evaluation itself (evaluators in class), and the teammates' feature code (their own reports).

## 2. Prompt History
[Jinyoung Park, 11-02] "우현꺼 PR을 젤 뒤로 미뤄서 상우꺼 부터 먼저 PR처리"
[Jinyoung Park, 11-02] "CI 끝났으면 #17 머지해"
[Jinyoung Park, 11-02] "지금꺼 확인해서 반영"
[Jinyoung Park, 11-03] "pr 올린거 확인하고 merge좀"
[Jinyoung Park, 11-03] "그리고 HE계정 여러개랑 더미 데이터 넣는것도 잊지 말고"
(Full log: [AI-Collaboration-Report-Iteration-3-Prompt-Log.md](AI-Collaboration-Report-Iteration-3-Prompt-Log.md), wiki sub-page "AI Collaboration Report – Iteration 3 – Prompt Log")

## 3. What AI Did Well
- Merge order with conflicts: before #17 (`feat/squat_battle`) was merged, a chained dry merge of `main` + #25 + #17 showed that the only conflict was in two of 상우's own docs files; the PM merged `origin/main` into his branch (`59b354e`) after asking him, and #17 went in clean (`757a6e2`). About an hour of conflict hunting saved per PR.
- Each merge was checked on the real head: for #29 a clean worktree at `66e9849` ran `flutter analyze` and 1456 tests (CI's coverage shard had hung), so the merge did not wait for CI.
- The redeploy took five minutes (17:43–17:47 UTC) with a DB and code backup first, the migration, a release folder with `previous-release.txt` for rollback, and the read-only `deploy/smoke-battle.py` (5 PASS) afterwards.
- The reviewer subagent's four minor findings on the runner (position parsed from any first character, a second replay for the error column, a silent fallback without `perRep`, two README wording slips) were fixed before the commit; the error column was re-derived from the frozen scorer's alignment and stayed identical for all 32 cases.
- The evaluation runner (loader, scoring, per-set and per-case tables, 27 tests) was written and run in one sitting on the existing `replay()` and scorer; the first run gave M1 46 %, M2 91 %, M3 57 % with a per-case table that shows where the judge fails (set 4 lock-out never recognized, set 8 reason wrong, two people's normal reps rejected).
- HE data in one run: 7 accounts and 28 battles with points, outcomes, KO and form reports through `POST /api/matches`, so Home, the history tab and the feedback screen are not empty for the evaluators.

## 4. Hallucinations / Errors
- The merge-status page first said 우현 had uploaded 0 AI-evaluation recordings and mixed up the `SWH`/`HSW` folders (11-01). Caught by the user reading the page; fixed the same day and recorded in memory. Cost: ~10 min and one wrong notice to the team.
- Claude assumed the battle server could be compiled on the server with `sudo -u sangwoo` using 상우's Dart SDK; it failed twice (`Exists failed, path = '/home/jinyoung/bin/'`). Caught by the command output; the binary was cross-compiled on the Mac instead (`--target-os=linux --target-arch=x64`), as for the 10-21 release. Cost: ~5 min.
- A page-edit script asserted on a sentence that an earlier edit had already changed (11-02). Caught by the assertion; re-run with the actual text. Cost: ~2 min.
- Writing the final label into Hyunwoo's set 4 file, Claude re-serialized the whole JSON with an indent, turning a 2-line change into a 142,749-line diff (11-03). Caught by `git diff --stat` right after; the file was restored and only the `label` block replaced (+20/−2). Cost: ~3 min.

## 5. Prompt Revisions
- Before: "지금꺼 확인해서 반영" (11-02, PR #28). After: "머지해". Why it worked: the first prompt only asked to check and reflect, so the merge was held; the explicit verb was what the tool needed to act.
- Before: "내가 main merge 하면 안되는겨?" After: "ㄱㄱ" (11-02, #17). Why it worked: the question settled who merges `main` into a teammate's branch (the PM, after asking him); the short go then ran the agreed step.

## 6. Manual Fixes and Why
- None in code: the PM task produced reviews, documents, fixtures and server steps, not app code, so no "manually fixed" marker was added this iteration.
- TODO(Woohyun Song, Hyunwoo Song, Sangwoo Hahn): manual fixes of AI-generated code in your tasks, with the marker and the line, in your own notes.

## 7. Takeaway for Iteration 4
- Ask for an explicit merge or deploy verb in the prompt instead of "확인" when the action is wanted; it saves a round trip.
- Keep the merge-status page as the single team notice and have each member confirm their own row before it is shared.
