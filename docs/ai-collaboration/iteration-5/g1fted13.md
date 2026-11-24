# AI Collaboration notes: Iteration 5 (2026-11-21 ~ 2026-12-04) – Woohyun Song
Status: draft (iteration open) | Written by: Woohyun Song | Merged by the PM into `AI-Collaboration-Report-Iteration-5.md` (P27)
Tools used: Claude Code (Opus 5.5), with the repo's `reviewer` subagent; Claude Design (the user's design canvas); Claude on claude.ai (A2's spec and data)

Evidence per step, items a–f of the AI Collaboration Report Guidelines v1.1. Input prompts are in
[g1fted13-Prompt-Log.md](g1fted13-Prompt-Log.md).

## A2 `codex/iter5-arcade-stages` – Build arcade stage rules (team order #8 before the PM's renumbering), 2026-11-23

### a. Where AI was used
- **Planning the split (local harness, not committed):** the user split P16 (the arcade) into five steps due 11/24 for
  the 11/25 TA meeting; the PM's new harness later named this one A2. Claude Code added the four new steps to the local ownership rules and team plan, then checked
  them in a throwaway clone: commits, `--check-diff` and `--push` on all five stacked branches.
- **The code and tests:** Claude Code wrote all of A2's code and tests in six commits (18 files), plus a merge of `main`:
  - `7cbbab8`: the `BotPace` interface in `lib/models/bot_difficulty.dart` (L1–20). `BotOpponent` now takes it
    (`lib/services/opponent/bot_opponent.dart` L41–43, L109). The tests pin the old rounds in
    `test/services/opponent/bot_opponent_test.dart` (L57–163).
  - `5569621`: `lib/models/arcade_ai_level.dart`, `arcade_stage.dart`, `arcade_floor.dart` and `arcade_catalog.dart`,
    with their four tests.
  - `3bf2515`: `lib/models/arcade_progress.dart`, `lib/services/arcade/arcade_star_judge.dart` and
    `arcade_progress_store.dart`, with their three tests.
  - `6b6b2b4`: the store records a stage itself (`ArcadeProgressStore.recordStage`), after the review (item d).
  - `03edd7f` merges `main` at `ad8a6f7` (#87, push-up grading). `9f14b6f` copies the new
    `BattleRules.kneeAverageEnabled` into the floor rules, and `141c8df` pins the bot rounds of `ad8a6f7`
    (items c and d).
- **Generated, then checked:** the 24 stage constants in `arcade_catalog.dart` were printed from `arcade_data.json` by a
  throwaway Python script. Claude Code did not type them by hand. The catalog test compares every value with a copy of
  the JSON.
- **The hand-off:** the spec (`SPEC.md` v1), `arcade_data.json` and the AI level simulation `tools/ai_level_sim.py`
  were written by Claude on claude.ai, from the mockups on the Claude Design canvas "GymRats 메인 메뉴 시안" (page
  "아케이드 · 들어가기와 흐름").
- **Not done by AI:**
  - The rules and numbers in the hand-off were decided and reviewed by Woohyun Song: the stage layout, the character
    rotation, the AI LV ranges and the star conditions.
  - The user answered the spec's two open questions: stars when two warnings end a hold, and stars when a stage is
    played again.
  - The user decided how the ownership guard treats the stacked branches, and added the three compensating rules.
- **Review:** the `reviewer` subagent returned CHANGES_REQUESTED on the first run (item d). The fixes are in `6b6b2b4`
  and in these notes.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-23] (the harness split, pasted; excerpt) "앞 단계 머지를 기다리지 않고 앞 단계 브랜치에서 갈라져 작업할 거라, 선행 조건 때문에 브랜치 생성이나 커밋이 막히지 않게 해 줘(막는 구조라면 어떻게 할지 먼저 나에게 물어봐)."
- [Woohyun Song, 11-23] (after choosing an option, pasted; excerpt) "after 비움 + 앞 단계 경로 허용으로 가되 세 가지를 더해 줘. 1. 뒷 단계가 앞 단계 파일을 고치지 않게 task.md와 reviewer 지시에 규칙을 넣어. … 3. 이건 하네스 검사를 약하게 하는 예외라 progress.md에 적어 줘."
- [Woohyun Song, 11-23] (the step's start, pasted; excerpt) "고칠 기존 파일은 bot_difficulty.dart와 bot_opponent.dart(시그니처만)뿐이고, 초보·중수·고수 동작은 하나도 바뀌면 안 돼. 같은 시드의 planRound 결과가 바꾸기 전과 같은지 테스트로 확인해."

### c. What AI did well
- **Found that the guard would block the plan, before anything was set up.** The user asked whether prerequisites
  would block branch creation or commits. Claude Code read the guard and found three blocks:
  - `after` blocks edits, commits and pushes until the earlier step merges.
  - A push or `--check-diff` compares the branch with `origin/main`, so a stacked branch fails on the earlier steps'
    files.
  - Branch creation and a clean `git merge` are not blocked, because no `pre-merge-commit` hook exists.
  Claude Code asked the user to choose with three options, as the user had asked. A throwaway clone then confirmed the
  chosen setup: all five stage branches passed, an out-of-scope file stayed blocked, and an earlier-stage edit passed
  the guard but showed in the review diff.
- **Pinned "the bot is unchanged" before touching the bot.** Before editing `bot_opponent.dart`, Claude Code printed
  the rounds that 초보, 중수 and 고수 plan at `25509ee`. The printed 고수 rounds matched the pins already in the test.
  The new tests pin these values, and they pass on the changed code. Changing one constant (`_jitter` 0.15 → 0.16)
  made 7 of the 8 new tests fail.
- **Saw a gap in the stacked-PR rule.** P16-3 and P16 start from A2 and P16-2 merged together, and a GitHub PR has
  only one base. Claude Code chose a base for those PRs and wrote a review command for that case: the intersection of
  the two diffs with `comm -12`. It said in the rules that the PR also shows P16-2's files until both are merged.
- **Checked `main` before the push.** Right before the push, `main` moved to `ad8a6f7`. Claude Code read its diff
  before merging and found two effects on this step. First, #87 changed the bot's rejection reasons, so the pins
  from `25509ee` no longer described `main`. Claude Code printed them again from an export of `ad8a6f7` (outside the
  working tree) and showed that only the reasons differ. Second, `BattleRules` had a new field that the floor
  rules did not copy.
- **Read the existing results instead of re-scoring.** The fight stars use `BattleResult.outcome` and `end`,
  `myInvalidReps`, `GoalProgress.longestCombo` and `GameGradeCounts.ofReps`, as the spec says. Claude Code first
  confirmed in the code that each one exists. No judge or score code changed.

### d. Hallucinations / errors
- **A helper that could wipe the saved progress.** Claude Code added `recordArcadeStage`, which read the store and
  then wrote the result. A store that fails to read reads as the first state (spec 7), so one passing read failure at
  the end of a stage would have written a nearly empty list over the saved progress. The tests did not check this
  case. The reviewer found it on the first run. Fixed in `6b6b2b4`: the store records a stage itself and writes
  nothing when the read fails. The test 'a store that fails to read keeps the saved progress: nothing is written'
  covers it. Cost: one fix commit and three tests.
- **A copy that drops new fields.** `ArcadeFloorRule` builds a floor's `BattleRules` by copying every value of the
  base. When `main` added `kneeAverageEnabled` the same day, the copy left it out: a base with it off would have
  come back with it on. No test failed, because the merged code still compiled and the tests used the default.
  Claude Code saw it in `main`'s diff before the push. Fixed in `9f14b6f`, and the floor test's base now turns the
  switch off, so a value left out fails the test. A new `BattleRules` field still needs the copy updated by hand.
- **An unsupported claim in these notes.** The first draft said the user wrote `SPEC.md` and `arcade_data.json`. The
  reviewer pointed out that the spec speaks of the user in the third person. The claim became a TODO, and the user
  then said who wrote the files and who set the rules (item a).
- **Garbled Korean in the generated constants.** The first run of the catalog script redirected its output in the
  Windows code page, so every Korean label came out garbled. Claude Code saw this when it printed the output, and reran
  the script with `python -X utf8` before using the result. Cost: one rerun.
- **A wrong "outside scope" from the guard.** Claude Code ran `--check-paths` with a path relative to `gymrats_app/`,
  but the guard reads paths from the repo root. Rerun with the root path: ok. Cost: one rerun.
- **A syntax slip:** a comma before `else` in a collection `if` in `arcade_catalog_test.dart`. Claude Code caught it
  when it reread the file, before the first run.
- **A grep pattern that matched nothing:** in the mutation check, `\d` does not work in `grep -E`. Claude Code saw the
  empty output and reran with a plain `tail` to read the result.
- **The harness patch first failed on two files.** `personal.md` and `README.md` use CRLF line endings, and `patch`
  needs `--binary` for them. Claude Code found this by testing the patch on a copy of the zip template, and wrote
  `--binary` into the recovery steps.

### e. Prompt revisions
- Before: "after 비움 + 앞 단계 경로 허용" (the option the user picked).
- After: the same option plus three rules: later steps never edit earlier steps' files; stacked PRs use the previous
  step's branch as base; the weakened check is recorded in `progress.md`.
- Why it worked: the option made the guard pass the earlier steps' files, so it could no longer stop a later step from
  editing them. The added rules moved that check into the task spec and both reviewers' instructions, with a command
  that shows such an edit.

### f. Manual fixes and why
- None in this step: nobody edited A2's code by hand.
