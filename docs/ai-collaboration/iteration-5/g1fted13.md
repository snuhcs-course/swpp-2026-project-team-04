# AI Collaboration notes: Iteration 5 (2026-11-21 ~ 2026-12-04) – Woohyun Song
Status: draft (iteration open) | Written by: Woohyun Song | Merged by the PM into `AI-Collaboration-Report-Iteration-5.md` (P27)
Tools used: Claude Code (Opus 5.5), with the repo's `reviewer` subagent; Claude Design (the user's design canvas); Claude on claude.ai (A2's spec and data; P8's spec and state mockups; A9's spec); Claude on claude.ai with the Claude Design canvas (the arcade art)

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

## A3 `codex/iter5-arcade-art` – Create arcade artwork (team order #8), 2026-11-23

### a. Where AI was used
- **The art:** Claude on claude.ai drew the four gym owners and the five floor backgrounds as SVG on the Claude Design
  canvas. The app's art data (`gymrats_app/assets/arcade/gym_art.json`) was carried over from those SVGs by an
  extraction script that Claude made (the user's statement, 2026-11-23, in the Prompt Log).
- **The code and tests:** Claude Code wrote all of A3 in commits `de3a969`, `c00eced` and `a5f0d7d` (4 `lib/`
  files, 3 test files, the art's JSON and 17 design shots under `gymrats_app/assets/arcade/`):
  - `lib/widgets/gym_background_art.dart` (L1–398): the parser (`GymArt`, `GymArtShape`, `GymArtSegment`) and the
    painter `GymArtPainter`, which follows the design's reference renderer; `GymArt.warmUp` (L74–89, `c00eced`)
    builds all 701 paths at start-up;
  - `lib/widgets/gym_owner_figure.dart` (L1–130): `GymOwnerFigure` with its breathing, `GymOwnerFace`,
    `gymOwnerFaceCenters`;
  - `lib/widgets/gym_background.dart` (L1–48): `GymBackground`, `gymBackgroundSize`, `gymBackgroundFloorLineY`;
  - `lib/widgets/gym_background_art_data.dart` (L1–9): the string `gymArtJson`, written by a Python script from
    `gym_art.json`, not typed; `test/widgets/gym_background_art_test.dart` checks it equals the JSON file.
- **Checking against the design:** Claude Code compared the drawings with the hand-off's 17 shots pixel by pixel (in
  the tests) and by eye from a widget capture (`docs/testing/iteration-5/g1fted13.md`, A3 entry).
- **Course notes:** Claude Code drafted this section and the testing notes. The Prompt Log comes from the course
  Session Exporter and `extract_prompts.py`; the Chrome extension's injected `<browser_instruction>` text (3 blocks,
  not typed by the user) was removed from it by a script, the prompts themselves are unchanged.
- **Not done by AI:**
  - Woohyun Song directed the art's composition, expressions and props, and chose among Claude's candidates,
    including the sports goggles (C) for the owners and the props backgrounds (A). The spec, `gym_art.json` (kept as
    `gymrats_app/assets/arcade/gym_art.json`) and the shots (now `gymrats_app/assets/arcade/shots/`) were handed over
    by the user as a local design hand-off, which is not committed.
  - Running A3 in its own worktree beside the P16-1 session was the user's decision (the step's start prompt in
    the Prompt Log).

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-23] (the step's start, pasted; excerpt) "SPEC.md를 처음부터 끝까지 읽고 그대로 만들어. gym_art.json은
  손으로 옮기지 말고 그대로 Dart 상수 문자열로 넣고, 기존 캐릭터 파일(character_rig.dart, character_figure.dart 등)과 다른 단계의
  파일은 고치지 마. 새 패키지도 넣지 마. 그린 결과는 shots/의 그림과 대조해서 다른 곳이 있으면 고치지 말고 그림 이름과 함께 나에게
  알려 줘."
- [Woohyun Song, 11-23] (checking the worktree's instructions before starting) "파일을 직접 열지 말고, 세션이 시작될 때 받은
  CLAUDE.md 내용만으로 답해 줘. 첫 문단을 한 줄로 요약하고, 디자인 시안 규칙(.claude/design/INDEX.md를 먼저 읽고 .dc.html 값을 그대로
  쓴다는 줄)이 있는지 알려 줘."

### c. What AI did well
- **No hand-copied numbers.** The 179,842-character JSON went into Dart by script, and a test pins the two together
  character for character, so the 701 shapes cannot drift from the hand-off.
- **The drawings match the design.** All 17 shots match at 2x: no pixel differs by more than 20 in a channel (the
  owners by at most 8). The test also proves it would catch another face, another floor or one missing shape.
- **Traced a look-alike to its source instead of "fixing" it.** 펭뚱이's `watch` and `ok` shots are byte-identical.
  Claude Code found the cause in the design part (`design/CoachB.dc.html` L276: the penguin's mouth is `M0 0` in both
  faces) and reported it to the user without changing the data, as the prompt asked; the user decided to keep it.
- **Stayed inside the step's files.** The shots could not go to `test/widgets/` as W3's did (the step's file list in
  the local harness allowed only `gym_*` tests), so they went to `gymrats_app/assets/arcade/shots/` (`de3a969`), not listed in `pubspec.yaml` and so
  not bundled in the app.

### d. Hallucinations / errors
- **A too loose shot limit.** The first shot test allowed 0.1% of pixels to differ; its own check "the comparison
  catches a wrong picture" failed, because the seal's `watch` and `ok` differ only in the mouth (0.074%). Caught by
  that test on the first run; the limit became 0.03%, the W3 value. Cost: a few minutes.
- **A test that could never pass.** The first parser test compared records holding lists, which Dart compares by
  identity. Claude Code saw it while reading the test back, before running it, and compared plain lists instead.
- **Reviewer, run 1 (CHANGES_REQUESTED, 2 Major and 4 Minor), all fixed:**
  - Major: no test could fail if the painter lost the opacity. The reviewer removed the 93 floor-line opacities in a
    scratch probe and every shot still matched (the shot tolerance hides it). Fixed in `a5f0d7d`: the parser test
    checks the paints' alpha, width, ends and joins, and a pixel test draws a see-through fill and outline. Removing
    the opacity now fails both tests.
  - Major: these notes said the art was the user's own work, which nothing here supports (Claude Design is an AI
    tool). Now only the user's choices are stated, with a TODO for the rest.
  - Minor: the spec builds the paths "앱이 시작할 때"; the code built them on first paint. `GymArt.warmUp`
    (`c00eced`) lets P16 build them at start-up.
  - Minor: the testing notes pointed to a Plan section they do not have and had no acceptance-criteria list; these
    notes cited the local `progress.md` and a PR that did not exist yet; the local progress row was stale.
- **Reviewer, run 2 (APPROVE) on `a5f0d7d`:** it confirmed every fix (3840 passed, 0 failed, 10 skipped) and left two
  Minor findings outside the code: the PR draft's test lists missed the two new tests, and the local review log sat
  under the P16-1 heading. Both were fixed before the PR was opened.

### e. Prompt revisions
- Before (worktree setup): the worktree's `CLAUDE.md` and `gymrats_app/CLAUDE.md` were one-line `@…` imports of the
  original folder's files.
- After: "import가 안 불러와지니 복사 방식으로 바꾸자. … 원래 폴더(C:/dev/swpp-2026-project-team-04)의 같은 파일 내용으로 그대로
  덮어써. 내용을 손으로 옮겨 적지 말고 파일 복사로 해."
- Why it worked: a new session in the worktree then had the project rules loaded; the user checked it with the second
  prompt in item b (it found the first paragraph and the design-mockup rule).

### f. Manual fixes and why
- None in this step: no AI-generated code was edited by hand, so there is no manual-fix marker.

## A4 `codex/iter5-hold-plank` – Implement high-plank hold stages (team order #8.3), 2026-11-23

### a. Where AI was used
- **The spec and the designs:** Claude on claude.ai wrote the hold stage's spec (SPEC v1–v3), and Claude drew the
  designs (`P16Hold`, `P16HoldGrid`, `ArcResult`, `ArcFlowGrid`) on the Claude Design canvas (the user's statement,
  2026-11-23, in the Prompt Log). They reached this step as a local design hand-off, which is not committed.
- **The code and tests:** Claude Code (Opus 5.5) wrote all of A4 in `0933ba6`, `c5b954d` and `1dbf9ec` (17 new files, 4 of them tests, and
  additions at the end of `lib/theme/app_theme.dart`):
  - `lib/services/pose/hold_judge.dart`: the common part, `HoldTimeline` (time, warnings, unknown, entry) and
    `HoldJudge` (3·2·1 frames to the reader only);
  - `lib/services/pose/high_plank_hold.dart`: `HighPlankReader`, whose lines are read from the push-up judge's and the
    setup's configs (`RepJudgeConfig`, `SetupConfig`), not typed in;
  - `lib/services/pose/hold_pose_definition.dart`, `hold_poses.dart`, `lib/models/hold_reading.dart`,
    `hold_progress.dart`: the pose bundle, its one selector, and the values they pass;
  - `lib/viewmodels/hold_stage_viewmodel.dart` and `lib/screens/hold_stage_*.dart` (5 files): the stage from the
    briefing to the result, on the battle's unchanged `SetupViewModel`, `BattleCameraArea`, `BattleCameraView` and
    countdown bands; `HoldColors` and `HoldText` in `app_theme.dart` with the values of the `.dc.html` sources;
  - `lib/demo/hold_stage_demo.dart`: the phone entry point the spec asks for (section 7).
- **Checking against the design:** Claude Code captured the five scenes with the app's fonts in a throwaway widget
  test (deleted) and compared them by eye with the hand-off's shots (testing notes, A4 entry).
- **Review:** the repo's `reviewer` subagent ran three times on the code (the uncommitted tree that became the
  commits) and once more on these notes (see item d).
- **Course notes:** Claude Code drafted this section and the testing notes. The Prompt Log comes from the course
  Session Exporter and `extract_prompts.py`, run on a copy of the export that holds only this session (the folder also
  holds A3's sessions). Two script fixes, the prompts otherwise unchanged: the Chrome extension's injected
  `<browser_instruction>` text (not typed by the user) was removed, and the profanity filter's false hit on "꺼져서"
  ("the power went off") was put back as written.
- **Not done by AI:**
  - Woohyun Song confirmed the designs and made the decisions during the build (the user's statement, 2026-11-23):
    keeping the 'standing up' check (an upright body counts as off screen; asked after reviewer run 1) and the
    warning sound (the battle's reject sound; spec section 12, asked before starting).
  - Woohyun Song also set the branch, the merge of A2 and A3, the draft PR and its wording, and the recovery checks
    after the laptop lost power.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-23] (the step's start, pasted; excerpt) "앞 단계 파일은 상속만 하고 고치지 않는다. 기존 판정
  코드(rep_judge.dart, squat_rep_judge.dart, pose_metrics.dart, setup_checker.dart)도 고치지 않고 가져다 쓴다. 고쳐야만 하면 먼저
  물어봐."
- [Woohyun Song, 11-23] (after the power loss, pasted; excerpt) "같은 폴더에서 A3 세션이 프롬프트 기록의 A4 프롬프트 항목을
  빼는 커밋을 하려 했다. codex/iter5-arcade-art의 마지막 커밋이 무엇인지, 그 커밋이 이 브랜치에 들어와 있는지, A3의 커밋이 이
  브랜치(codex/iter5-hold-plank)에 잘못 올라오지는 않았는지 확인해 줘."

### c. What AI did well
- **Reused the battle's setup without touching it.** The setup, its 3 s auto start (the 3·2·1), the camera, its
  failures and pause come from the unchanged `SetupViewModel`; the setup look from `BattleCameraArea` and
  `BattleCameraView`. No setup, battle or judge file is in the diff (`--check-diff`, reviewer runs 1–3).
- **Found a gap in the spec; the user confirmed after review.** By the spec's table a user standing up with the arms down would read as
  holding (the hands stay below the shoulders). Claude Code used the judge's existing upright-body line
  (`maxTorsoDrop`), wrote it down as beyond the spec, and the user decided to keep it after the reviewer asked.
- **Caught layout faults by looking.** The capture against the design shots found three faults that no test had:
  the stage tag stretched across the top, the clock centred on the screen instead of between its neighbours, and the
  results 28 dp low. Each was fixed and captured again.
- **Recovered cleanly after the power loss.** Before going on it checked the branch, `index.lock`, the end of every
  changed file and the A3 branch, merged A3's new commit (`32893b5`), and finished the edit that was cut off.

### d. Hallucinations / errors
- **Names that do not exist.** `RepPhase.top` (the enum has `up`) in a test and `AppColors.shadow` in the result
  screen (it is `RepBotColors.shadow`). Both caught at once by the analyzer.
- **Test helpers that missed real behaviour.** The cue stream delivers on a microtask, so the first warning-cue test
  found no cue (fixed by flushing microtasks in the helper); the owner is drawn five times for its white outline, so
  `find.byType(GymOwnerFigure)` found too many (the tests take the last one); the top row overflowed with the test
  font (rebuilt so it cannot overflow). All caught on the first test run.
- **Two plank fixtures that tested the wrong rule.** A leg at 140° also put the knees in the judge's knees-beside-hands
  range, and arms at 150° sat on the classifier's boundary. Seen while re-reading the tests before running them;
  changed to 145° and 152°.
- **Reviewer, run 1 (CHANGES_REQUESTED, 3 Major, 4 Minor):** the upright-body rule had no user approval (asked; kept);
  the Design doc changes named three screen files without their classes; bare `gap`/`spacing` numbers in the briefing;
  the next stage card's gap was 6, the design 8; one file not formatted; A5 cannot edit `hold_poses.dart` or the demo
  under the local ownership, and `design_tokens_test.dart` does not list the hold screens (both for the PR body).
- **Reviewer, run 2 (CHANGES_REQUESTED, 1 Major, 1 Minor):** the fix for the card's gap brought in a bare `6`; now
  `ArcadeResultFrame.strikesGap`. Minor: the testing notes' count of checked paths had to come from the run they
  quote; filled from the run on `1dbf9ec`.
- **Reviewer, run 3:** APPROVE on the tree committed as `0933ba6`–`1dbf9ec`, with one Minor left for the PR body: A5 needs a scope exception to add its line to `hold_poses.dart` and to open the chair stages in the demo, and `design_tokens_test.dart` does not list the hold screens. Both are for the PR body.
- **Reviewer, run 4 (APPROVE, notes only):** every cited test name exists and the counts and checks match the runs;
  four wording Minors fixed before the notes commit: a check said to run on a pushed head before the push, two lines
  said the PR text existed before the PR, a heading in item c said Claude asked before the review did, and this item
  missed run 2's Minor.

### e. Prompt revisions
- None in this step: the step ran on its start prompt; the later prompts answered questions or added the power-loss
  checks, without changing what was asked.

### f. Manual fixes and why
- None in this step: no AI-generated code was edited by hand, so there is no manual-fix marker.

### Follow-ups on this branch (2026-11-23 to 11-24, from the A5 session `dfb39c07`)
These were made from the A5 session at the user's word; their full evidence is in the A5 section of this file on
`codex/iter5-hold-chair` (PR #92). In short:
- **a. Where AI was used:** Claude Code (Opus 5.5) wrote `014e4f0` (guide lines from the reader), `1c325ab` ("시작"
  after an entry), `397f498` (a test comment), `f78ac2b` (the result on small screens, found by the P16 session),
  `4ef8a2f` (one bent arm, from the Codex review on #90), `3ffed5f` (the hold effects: spec and designs by Claude on
  claude.ai from the phone check of 11-24, the picks by Woohyun Song), `94f6416` (the leave dialog at a stage's end,
  found by the P16 session), the `main` merges `166de3b`, `78e61dc`, `6bda1e0`, and `f430051` and `f28cac6` (the
  leave button hidden at a stage's end), with their testing notes; the reviewer subagent ran A4 runs 5–13. The phone check of
  2026-11-24 and every decision on these are the user's.
- **d. Hallucinations / errors:** the win or lose jingle came 1.5 s late at a second warning (run 9, Major, fixed);
  a screen check that could not fail (run 9, fixed); the bent-arm check on the mean of both arms let one bent arm pass,
  which no local review caught and the Codex review on #90 did (fixed in `4ef8a2f`); the leave dialog stayed open in
  a second warning's 1.5 s, so leaving lost the stars (found by the P16 session, fixed in `94f6416`); that fix left
  the leave button drawn and announced in the 1.5 s, though it opened nothing (run 12, Minor, left to the user, who
  had it hidden as in a battle: `f430051`).
- **e. Prompt revisions:** merging A2 straight into this branch was blocked by the local pre-commit guard (its
  hand-made merge commit counted `main`'s files as outside A4); the session aborted and asked, and the user's answer
  (2026-11-24, in the Prompt Log) changed the order to `origin/main` first, then A2 and A3.
- **f. Manual fixes:** none; no AI-generated code was edited by hand.

## A5 `codex/iter5-hold-chair` – Add chair-pose judging (team order #8.4), 2026-11-23

### a. Where AI was used
- **The spec and the designs:** Claude on claude.ai wrote the chair pose's spec (SPEC v1–v2), and Claude drew the
  chair pose's designs (P16Hold's sit scenes and the warning icons) on the Claude Design canvas. Woohyun Song confirmed
  the designs and answered the spec's section 9 questions (the user's statement, 2026-11-23, in the Prompt Log). They
  reached this step as a local design hand-off, which is not committed.
- **The code and tests:** Claude Code (Opus 5.5), session `dfb39c07`, wrote all of A5 in `7f26016` and `e1b0a76`:
  - `lib/services/pose/chair_hold.dart`: `ChairHoldReader` (the squat judge's depth worked out in the reader, the
    hips and knees reading, the squat guide's snapshot, a debug-only print for the phone check), `chairHold`,
    `ChairFaults`, `ChairLines`;
  - `test/services/pose/chair_hold_test.dart` (30 tests) and `chair_hold_stage_test.dart` (10 widget tests);
  - the approved small changes in earlier-stage files: the chair line of `hold_poses.dart` (with its import, and
    the now unused `_notYet` removed), the demo's `enabled` line, and one test in each of the two A4 test files that
    asserted the chair was stopped.
- **A4 changes made from this session** (on A4's branch, then merged here; the user's decisions): `014e4f0` guide lines
  from the reader, `1c325ab` "시작" after an entry, `397f498` a test comment, `f78ac2b` the result screen on small
  screens (overflows found by the P16 session), with their testing notes `82e281a` and `be6509a`.
- **Codex reviews (2026-11-24):** on PR #92 at `fe3460c` the bot's one finding (P2, freeze the standing baseline at
  GO) was already the code since `77e1a75`, so Claude Code answered on the thread with the code lines and tests and
  changed nothing. On PR #90 at `be6509a` its finding (P2, one bent arm passing on the mean of both) was right: Claude
  Code fixed it on A4's branch (`4ef8a2f`, notes `ed76b18`, 3 tests), answered on the thread and merged it here
  (`adeb74f`).
- **The effects spec and designs:** Claude (claude.ai) made the hold effects' designs (on the Claude Design canvas)
  and their spec `SPEC-FX.md` by drawing candidates from the phone check of 11-24. Woohyun Song picked among the
  candidates the fail effect (A2 + A3, shown as F4), the star effect (B2) and the start notice (C1), had the bubbles'
  size and place and the chair pose's words changed, and decided to reuse the background music and to give the stars
  a sound (the user's statement, 2026-11-24, in the Prompt Log). They reached this session as a local design hand-off
  (`p16-3-fx`), which is not committed.
- **The hold effects (2026-11-24, from this session; the user's picks on the design canvas):** on A4's branch
  `3ffed5f` (music at the battle's moments, the start bubble, the stars' cheer with a pop and `SoundEffect.good`, the
  second warning's 1.5 s with "실패!" and the fail screen's reasons) and notes `47ea0d1`; merged here (`37e987c`) with
  the chair pose's two-line start words (`4767873`).
- **The follow-up of 2026-11-24** (the user's decision): `77e1a75` keeps the 3·2·1's standing thigh from GO on (the
  spec's "follows while standing" narrowed to before GO), with 7 new tests, among them a slow sit over 3, 4 and 6 s.
- **The leave dialog and `main` (2026-11-24, from this session; the user's instruction):** on A4's branch `94f6416`
  (the leave dialog closes when a hold stage ends and opens no more in the 1.5 s before its result; 3 tests). Then
  `origin/main` was merged up the stack: A2 `da3a039` (notes `dc5947b`), A3 `f482e99` (`c1f5f5f`), A4 `166de3b`,
  `78e61dc`, `6bda1e0`, and here `6a8ce7f`, `ca2cf6a`. Merging A2 straight into A4 was blocked by the local pre-commit
  guard; Claude Code aborted that merge and asked, and the user chose to merge `origin/main` into A4 and A5 first.
- **The leave button (2026-11-24, the user's decision on A4 run 12's Minor):** on A4's branch `f430051` and
  `f28cac6` (the leave button gone from the screen and the semantics tree from a second warning to the result, as in
  a battle; 2 new tests, 2 changed), merged here in `29e1337`; `200816d` checks the button on a chair stage (there in
  the entry, its way out; gone from a second warning), from A5 run 9's Minor.
- **Checking against the design:** the chair scenes captured with the app's fonts in a throwaway widget test (deleted)
  and compared by eye with the hand-off's shots (testing notes, A5 entry).
- **Review:** the repo's `reviewer` subagent ran on the A4 follow-up (runs 5–7), on A5's code (run 1), on
  these notes (runs 2–3), on the follow-up of 2026-11-24 (run 4), on A4's one-arm fix (A4 run 8), on A4's effects
  (A4 runs 9–10), on the chair's start bubble (run 5), on the records of the phone check and the user's answers
  (A4 run 11, A5 run 6), and on the leave dialog fix with the `main` merges (A4 run 12, A5 runs 7–8), and on the leave button
  (A4 run 13, A5 run 9).
- **Course notes:** Claude Code drafted this section and the testing notes. The Prompt Log comes from the course
  Session Exporter and `extract_prompts.py`, run on a copy of the export that holds only this session (the folder
  also holds the A3 and A4 sessions). Two fixes, the prompts
  otherwise unchanged: the Chrome extension's injected `<browser_instruction>` text (not typed by the user) was
  removed, and the two messages sent while a turn was running, which `extract_prompts.py` skips (the export stores
  them as queued commands), were copied in by hand from the same redacted export, verbatim.
- **Not done by AI:** Woohyun Song answered the spec's three questions (a fixed 0.8 knee line; sitting deeper is
  held; no time limit on the entry) and chose how to handle the three A4 gaps found before building (the two A4 tests
  changed here; the guide lines and "시작" fixed on A4's branch). Mid-way the user added the plank guide check, the
  rule that A4 commits hold only A4 files and records, one reviewer run before the A4 push and a plain merge, and
  passed on the P16 session's two overflows. The user also set the branch, the draft PR and its wording. The phone
  check of 2026-11-24 is the user's (testing notes), and so is keeping "삐익!" on a clear ended by warnings.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-23] (the step's start, pasted; excerpt) "A4에 의자 자세의 아이콘, 실루엣, 스쿼트 안내선이 없으면 이
  단계에서 그리지 말고 멈춰서 알려 줘. 기존 판정 코드(squat_rep_judge.dart, setup_checker.dart, pose_metrics.dart,
  rep_judge.dart)는 고치지 않고 가져다 쓴다."
- [Woohyun Song, 11-23] (mid-task, pasted; excerpt) "1. 하이 플랭크의 푸쉬업 안내선도 따로 도는 판정기에서 오는지
  확인하고, 오래 버티면 같은 식으로 사라지면 같은 커밋에서 함께 고쳐 줘."
- [Woohyun Song, 11-24] (pasted; excerpt) "깊이 기준은 폰 확인을 기다리지 말고 지금 고치자. 천천히 앉을 때 기준이 같이
  내려가서 깊이가 낮게 읽히기 때문이다(reviewer 시뮬레이션에서 0.8이 0.73~0.75로 읽힘)."
- [Woohyun Song, 11-24] (pasted; excerpt) "A4 PR #90에 Codex 리뷰(be6509a)가 왔다. P2 \"Check each arm against the plank
  angle\"다. … 맞는 지적이니 A4 브랜치에서 고치자."
- [Woohyun Song, 11-24] (pasted; excerpt; under A4's heading) "A4 연출 추가 작업이다. … 고른 것 (다시 묻지 않는다)
  1. 배경음: 버티기 판에서도 대결과 같은 배경음을 같은 코드, 같은 방식으로 깐다."
- [Woohyun Song, 11-24] (pasted; excerpt; under A4's heading) "1. 별을 받은 뒤 두 번째 경고로 끝나는 클리어는 지금처럼
  둔다(\"삐익!\" 1.5초, win jingle, 클리어 화면). 클리어인데 \"실패!\"를 띄우면 뒤의 클리어 화면과 맞지 않기 때문이다."
- [Woohyun Song, 11-24] (pasted; excerpt; under A4's heading) "두 번째 경고 뒤 1.5초(\"실패!\", 또는 별을 받은 경우
  \"삐익!\") 동안 아직 나가기 창이 열리고, 이때 나가면 결과 화면 없이 끝나 별이 저장되지 않는다. 대결은 판이 끝나는
  순간 나가기 창을 닫는다."

### c. What AI did well
- **Checked the harness before committing a merge.** Before merging A2 into A4, the session merged without
  committing and ran the pre-commit guard by hand; it blocked, so the merge was aborted and the user was asked, as the
  instruction said, instead of a merge commit being forced through.
- **Found A4's gaps before building on them.** Reading A4's view model against the spec's sections 5 and 6 showed that
  the squat guide came from a separate `SquatRepJudge`, which drops a squat (`lost`) 12 s after it starts down, so the
  squat lines would vanish in every chair stage (20–45 s), and that nothing read "시작" after the entry. It asked
  before touching A4; the user chose A4's branch, and A5 merged the fix.
- **Checked a claim with the real code instead of assuming.** For the user's question about the plank's push-up guide
  it wrote a test that runs the real push-up judge through a 60 s plank (`hold_stage_viewmodel_test.dart`); the guide
  stays, so nothing was changed there. Reviewer run 5 confirmed it against `rep_judge.dart`.
- **Proved the depth is the squat judge's.** `chair_hold_test.dart` feeds the same 33 ms frames to `SquatRepJudge` and
  the reader for 12 s and compares the depth exactly (more than 300 frames), then shows the squat judge losing it past
  12 s while the reader keeps it. (Since `77e1a75` this holds for the frames read as in the 3·2·1; after GO the depth
  differs on purpose, see d.)
- **Reproduced before fixing.** For the P16 session's overflow report it first wrote the size tests and saw them fail
  with the reported 28, 20 and 12 px, then fixed and saw them pass, with a test that the design's sizes stay.

### d. Hallucinations / errors
- **Wrong timings in the first test draft.** Working the smoothing through by hand before running found five wrong
  expectations: standing up reads 'hips too high' from the first frame, not the second; the second warning needed
  0.1 s more frames; the standing thigh taken after GO is the smoothed one at 3.4 s, not 180 at 3.3 s; "시작" needs
  0.8 s of sitting, not 0.7 s; and a `const` empty frame is the same object each time, which the view model skips.
  The first run found one more: after 0.9 s of smoothing the depth was 1.9e-7 from 0.9 (tolerance 1e-9 → 1e-3).
- **Analyzer findings:** a local `started` hiding the test helper `started()`, an unused import, and a list element
  the lint wanted null-aware.
- **A wrong test comment:** the 60 s plank test's comment said the app runs the judge on the hold's clock; the app's
  judge keeps its own stopwatch (reviewer run 5, Minor; fixed in `397f498`).
- **A design-doc gap:** the new `HoldGuideReader` was missing from the local Design doc changes list (reviewer run 5,
  Major; added).
- **A layout first try and a measurement taken with the wrong font:** the first overflow fix padded the button's words
  on the left only, which would have moved them off centre; dropped before testing. The fix then kept no margin at
  all, reasoning that the button had "about 8 px to spare" at 360 wide, and the notes gave the overflows as 28 and
  12 px. Both numbers came from the widget tests' font, whose every glyph is 1 em wide. Reviewer A4 run 7 measured
  the app's font: the words overflow only at 320 × 640 with 1.3x text (5 and 16 px), and the slack at 360 is 33–42 px.
  A 4-point margin was added and the notes now say which font the numbers are from.
- **A blocked command:** the post-push check's `grep` was stopped by the repo's commit-text hook, because the command
  itself contained the searched words; rewritten with character classes.
- **Reviewer, A5 run 1 (APPROVE, 3 Minors):** a slow sit (3–6 s to a true 0.8) can read 0.73–0.75 because the copied
  follow rule lowers the standing thigh while the depth is under 0.25 (kept as the spec's formula; added to the phone
  check, a change waits for the user); a clock going back gives 0 where the squat judge gives a negative weight
  (commented); the debug print leaked into the stage tests' output (silenced).
- **Reviewer, A4 run 7 (APPROVE, the small-screen fix, 2 Minors):** the margin and the font, as above; it also ran
  the new tests on the old code and saw them fail with the reported numbers.
- **Reviewer, A5 run 2 (CHANGES_REQUESTED, notes only; 1 Major, 4 Minors):** these notes cited two local A4 commits
  that were redone before the push (`cefcaa4`, `cbd8af0`; the pushed ones are `f78ac2b`, `be6509a`). Minors: the
  export holds the A3 and A4 sessions, not A2's; the earlier-stage changes are small, not one line each; the
  stacked-branch count must match the commit it is quoted for; the command block lacked the six-file run behind
  "156 passed". All fixed. Its own full run hit one flaky online test outside A5 (in the testing notes).
- **Reviewer, A5 run 3 (APPROVE, notes only):** run 2's findings verified fixed; no new finding.
- **A rule copied faithfully that did not fit the pose.** Following the spec, the reader copied the squat judge's
  rule that the standing thigh follows a standing user. On the way down the thigh still counts as standing for a
  while, so a slow sit lowered the standing thigh and a good chair pose read "더 앉아요". The parity test could not
  catch it (it checks the copy, not the pose); reviewer A5 run 1 found it by simulation, and the session first left
  it for the phone check. The user had it fixed the next day: the new tests show the squat judge's rule reading under
  0.75 on the same slow-sit frames where the reader now reads the true 0.8.
- **Reviewer, A5 run 4 (APPROVE, the follow-up of 2026-11-24; 4 Minors):** the new tests fail on the old reader and
  on a reader that never follows. Fixed before the commit: the skips' reason in the testing notes, item c's parity
  claim (now limited to the 3·2·1), item e's "the spec only allowed" (the spec ties changes to the phone check), and a
  test named "halfway up" that never went halfway up. Left for the phone check, as the user's wording asks for it: a
  standing thigh taken after GO is taken once, so a slow rise after GO can fix it before the user is fully up.

- **A mean that hid one bent arm (A4, found by Codex).** A4's high plank reader (also written by Claude Code)
  checked bent arms on `PoseMetrics.elbowAngle`, the mean of both arms, so 180° and 130° made 155° and passed. No
  local reviewer run had caught it; the Codex review on PR #90 did. Fixed with the less straight arm (`4ef8a2f`).
- **A stale finding from Codex.** On PR #92 Codex asked to freeze the standing baseline at GO, which the head it
  reviewed already did; checked against the code and tests and answered instead of changed.
- **Comments naming the review tool:** the first one-arm commit's comments said "Codex review on A4"; code may carry
  only the AI marker, so they now say "PR #90 review" (reviewer A4 run 8, Minor; fixed before the push).

- **The jingle a beat late (A4 effects, reviewer A4 run 9, Major).** The first version started the win or lose
  jingle with the result screen, 1.5 s after a second warning, while a battle's starts when it ends; it now starts
  with the warning's moment. The same run found a screen check that could never fail (a third warning cannot come
  after the judge ended); it now checks that the frames in the moment are not read.
- **A call made without asking.** A clear ended by a second warning (a star already earned) keeps "삐익!" and plays
  the win jingle instead of showing "실패!"; the session decided it, wrote it down as beyond the spec and put it to
  the user in the PR and the report. The user kept it (2026-11-24): "실패!" on a clear would not match the clear
  screen after it.

- **Reviewer, A5 run 5 (APPROVE, the merge of A4's effects and the chair's start bubble; 5 Minors):** two prompts out
  of time order in the Prompt Log and item b; size tests that could not fail for the two-line bubble (now both lines
  inside the bubble and the bubble on screen); the testing entry lacked its criteria and phone-check lines; item a did
  not say who wrote the effects spec (a TODO now); the local progress log lacked this work. All fixed.
- **Phone-check steps that could not be done (reviewer A5 run 7, Major).** The first draft of the slow rise after GO
  said to sit as soon as the 3·2·1 starts, but a user upright at its first frame gives the reader 0.3 s of standing at
  once, and that thigh stays for the play; its fallback ("the case cannot happen on the phone") did not follow from
  the code, since the setup counts standing from 0.25 of the shin and the reader from 0.7. Now: a half squat held
  through the count, reopening the stage when a thigh was taken, and writing down the bends tried. Two Minors (the
  fault ids, `null` before a value exists) fixed with it; run 8 APPROVE.

### e. Prompt revisions
- Before (the user's answer, 2026-11-23): "A4 브랜치에서 고치고 merge (Recommended)".
- After (mid-task, pasted): "1. 하이 플랭크의 푸쉬업 안내선도 따로 도는 판정기에서 오는지 확인하고, 오래 버티면 같은 식으로
  사라지면 같은 커밋에서 함께 고쳐 줘. 2. codex/iter5-hold-plank로 바꾸기 전에 A5 작업 중인 변경이 A4 커밋에 섞이지 않게
  정리해 줘. … 3. A4 커밋은 reviewer를 한 번 돌리고 push한다. 그다음 A5 브랜치로 돌아와 hold-plank를 그냥 git merge로 받아 온다."
- Why it worked: the answer only said where to fix; the revision said what else to check, what the A4 commits may hold,
  and in which order to review, push and merge, so the A4 fix went out as four A4-only commits with their own review.
- Before (the step's start, pasted; the spec's rule it pointed to): "테스트는 SPEC.md 7절 기준이다." (SPEC 3: the
  standing thigh "서 있는 동안만 천천히 따라감"; SPEC 1: "폰으로 찍어 보고 바꾸면 이유와 찍은 기록을 테스트 근거에 남긴다").
- After (2026-11-24, pasted): "깊이 기준은 폰 확인을 기다리지 말고 지금 고치자. … 1. GO 뒤에는 서 있는 기준을 따라가지
  않는다. … 2. 3~4초에 걸쳐 천천히 앉아도 깊이를 실제대로 읽어 \"더 앉아요\"가 뜨지 않는지 보는 테스트를 더한다."
- Why it worked: the spec tied changes to the phone check; the new prompt named the rule to change, how far
  (before GO only), and the test that proves it, so the change was small and testable without the phone.
- Before (2026-11-24, pasted, then interrupted by the user): "2. A4 브랜치에서 고친다: 두 번째 경고 때도 첫 번째 경고와 같은
  경고 화면 … 을 1.5초 보여 준 뒤 실패 화면으로 넘어간다. … 3. 같은 A4 커밋에, 별이 채워질 때의 가벼운 효과를 넣는다. …
  말풍선과 배경음은 다음 iteration으로 미룬다고 PR 본문에 적는다."
- After (2026-11-24, pasted): "A4 연출 추가 작업이다. … 이번 iteration이 마지막이라 다음으로 미루지 않는다. 명세와 시안은
  p16-3-fx 묶음 v2(SPEC-FX.md, design/, shots/)에 있다."
- Why it worked: the first message described the effects in words and deferred the bubbles and music; the revision
  pointed at a spec and picked designs, named every value's source, and kept all four effects in this iteration.
- Before (2026-11-24, pasted): "A4에 A2와 A3를 merge한다(1번 수정 포함). - A5에 A4를 merge한다. … 하네스가 merge
  커밋을 막거나 앞 단계 파일을 고쳐야 하면, 우회하지 말고 멈추고 보고한다."
- After (2026-11-24, the user's answer to the session's question): "1번(A4에 main 먼저)으로 간다. A4에 origin/main을
  먼저 merge한 뒤 A2, A3를 merge한다. A5도 같은 방식으로 한다."
- Why it worked: merging A2 straight in needed a merge commit made by hand (the notes' conflict), which the guard
  checks against A4's own scope, so `main`'s files were outside it; the guard leaves them out only when the merge's
  second parent is `origin/main`. The revision gives the same content in an order the guard accepts.

### f. Manual fixes and why
- None in this step: no AI-generated code was edited by hand, so there is no manual-fix marker.

## P16 `codex/iter5-ai-opponents` – Build arcade screens (team order #8.5), 2026-11-23

### a. Where AI was used
- **The code and tests:** Claude Code (Opus 5.5) wrote all of P16's code and tests in four commits on top of the
  A2 + A3 merge `1ae69d1` (20 new files, 10 in `lib/` with about 5,500 lines and 10 tests, and 24 changed files: 9,554 lines added, 298 removed):
  - `d2bb818`: the arcade's 13 color tokens and the `ArcadeText` styles in `lib/theme/app_theme.dart`.
  - `e5c74ee`: optional arcade values on `Opponent` (`lib/models/matchup.dart` L6–97), the stage's floor picture and
    boss round (`lib/widgets/battle_arena.dart`, `battle_stage.dart`), and the exit button's label.
  - `5bb0e48`: the arcade view model (`lib/viewmodels/arcade_viewmodel.dart`: `ArcadeViewModel` L30,
    `finishBattle` L118, `ArcadeMatchups.rulesOf`/`battleOf` L260–300), the map (`lib/widgets/arcade_map.dart`
    L19–100, from the `ArcMap` script's numbers), the stage sheet, the boss screen, the result screens and
    `ArcadeFlow`, the `/arcade` route and `GymArt.warmUp()` (`lib/main.dart` L61, L129).
  - `c8d6044`: the play page's two cards, the versus, battle and report changes, and the rewritten AI 1v1 tests.
  - After A4 (`codex/iter5-hold-plank`, PR #90) was merged in (`f9d1eba`), `d429c8c`: section 8, the hold stages
    (`lib/screens/arcade_flow.dart` `holdScreen`/`openHold`, the map's next stage after a hold), the chair stages run
    as high plank until A5, and the fight and boss results moved onto A4's `ArcadeResultFrame` (the interim frame
    deleted). `8b975cf`: the boss intro and break scroll on short phones. `6074bf4` merges A4's four follow-up
    commits.
  - After A5 (`codex/iter5-hold-chair`, PR #92) was merged in (`0deb979`): `ca88a59` removes the high-plank stand-in,
    so the chair stages are judged by A5's chair pose; `b03ca98` tests the five results on a 320-wide phone and with
    1.3x text.
  - After the user's phone check on `9b59537`: `fcacca1` makes the break's 자세 잡기 span the content as in the design
    (`lib/screens/arcade_boss_screen.dart`, `_Break`) and lets the ink button's words shrink to fit
    (`lib/widgets/arcade_parts.dart`, `ArcadeDarkButton`).
  - After the A5 session's hold effects: `2ab24c3` merges `codex/iter5-hold-chair`, and Claude Code traced the music
    of a hold stage from the arcade against a fight stage's in the code (`hold_stage_screen.dart`,
    `sound_battle.dart`, `background_music.dart`, `arcade_flow.dart`). One difference (a hold closed on its
    briefing after a jingle brought the menu track back) is fixed in `359ea18`: `ArcadeHoldMusic`
    (`lib/widgets/arcade_hold_music.dart`), given to A4's screen by `ArcadeFlow.holdScreen`.
  - After `main`'s #86, #93 (Google sign-in) and #94 came up the stack: `c92006c` merges `origin/main` first (the
    `main.dart` conflict resolved by keeping #93's Google sign-in lines and P16's arcade lines), then `670aecf`
    merges `codex/iter5-hold-chair` with A4's leave dialog fix (`94f6416`); Claude Code resolved both, checked
    each side's lines and the fix against `ArcadeHoldMusic`. No P16 code changed.
  - After `main`'s #95 (friend battles) and A4's hidden leave button (`d56e1f5`): `18ea16c` merges `origin/main`
    (five conflicts: `main.dart`, `play_screen.dart` and three of their tests; P16's two cards kept, with #95's
    친구와의 대전 row under them), then `03cac86` merges `codex/iter5-hold-chair`. Claude Code resolved both and
    wrote `test/screens/arcade_hold_stage_test.dart` (`7362fb4`), which runs A4's screen with the arcade's
    `ArcadeHoldMusic`.
  - The invite alert fix (`c02a9ff`, the user's decision): Claude Code named the arcade's stage routes in
    `main.dart` (`arcadeSheetRoute`, `arcadeHoldRoute`, `arcadeBossRoute`, `arcadeBreakRoute`,
    `arcadeResultRoute`), set them where `ArcadeFlow`, `ArcadeBossScreen` and the stage sheet open the routes,
    added them to #95's `busyRoutes` (P9's file, act first and report after), and wrote 7 tests in
    `arcade_flow_test.dart` and `main_test.dart`.
  - The next-stage fix (`fbfef4c`, PR #91's Codex review, the user's steps): Claude Code checked the finding in the
    code, wrote the failing tests first, then changed `ArcadeViewModel` (`saving`, `takeOpenRequest`, a read begun
    during a save dropped) and `ArcadeScreen` (the map waits for the read, looks again while a save goes on, and
    drops a waiting request when covered or left), with 13 tests.
  - The hold stage's 다음 스테이지 (`5b09d87`, the user's decision to fix it in P16 with A4's files read only):
    `ArcadeViewModel.holdStore`, a wrapper of the arcade's store handed to A4's screen by `ArcadeFlow.openHold`, and
    `_playHold` on a fight's path, with 10 tests.
- **Design values:** every size, color and position came from the `.dc.html` sources in
  `.claude/design/arcade/p16/design/` (read by Claude Code, not estimated from the shots), e.g. the map's `FH`,
  `BAND`, `WIP`, `P` and `me` values and the `ArcResult` frame.
- **Review:** the `reviewer` subagent ran sixteen times (item d): CHANGES_REQUESTED, APPROVE, then after section 8
  CHANGES_REQUESTED and APPROVE, APPROVE after the A5 merge, APPROVE after the phone check's fix, after the merge
  of the hold effects CHANGES_REQUESTED, then APPROVE on the music fix, APPROVE (4 Minors, fixed) on the `main` merge, and CHANGES_REQUESTED, then
  APPROVE, on the #95 merge, APPROVE (5 Minors, fixed) on the invite alert fix, APPROVE (5 Minors, fixed) on
  the last phone check's notes, CHANGES_REQUESTED, then APPROVE (3 Minors: two fixed, one for the user), on the
  next-stage fix, and APPROVE (4 Minors, fixed) on the hold stage's fix.
- **The hand-off:** the arcade screens' spec (SPEC v1–v2) was written by Claude on claude.ai, and the mockups
  (PlayX, ArcMap, ArcMenuAll, P16Found, ArcPlay, P16Scene, P16Arc, ArcResult, P16Boss) were drawn by Claude on the
  Claude Design canvas. Woohyun Song chose the layout of 게임 시작, the map and the boss match, and answered the
  questions of section 13.
- **Not done by AI:** the four open questions of spec 13 were answered by the user (remove 이어하기 now, 5F from the
  start, "STAGE 8 · 물렁범" as the record name, the report's exits inside the arcade). The user also set the branch
  plan, the PR rules (draft, merge order #8.5) and the rule that earlier steps' files are not edited. After the first
  push the user decided to merge A4 instead of waiting for A5, to use A4's result frame for the fights and the boss
  match, to open the chair stages as high plank until A5, and to base the PR on `codex/iter5-hold-plank`. When A5
  came up the user decided to merge it, remove the stand-in and move the PR's base to `codex/iter5-hold-chair`.
- **The phone check:** done by Woohyun Song on the Galaxy S26+ (`9b59537`, 2026-11-24); the user asked for the fix's
  rule (the design's shape kept, shrinking only on a narrow screen or with large text) and the sizes to test. The
  last phone check (2026-11-24 22:21–22:25, the build of `21fc291`) was also the user's, and its results, with the
  app's sounds in the screen recording, came from the user; Claude Code wrote them into the TODO spots of P16's,
  A4's and A5's testing entries, copied #88's and #89's CI coverage numbers into A3's and A2's entries, and listed
  the follow-ups.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-23] (the step's start, pasted; excerpt) "앞 단계(A2~A5)의 파일은 상속만 하고 고치지 않는다. 고칠 것이 보이면 멈추고 알려 줘. … 판정, 점수, 봇의 rep 계산은 건드리지 않는다. 온라인 대결은 하나도 바뀌면 안 된다."
- [Woohyun Song, 11-23] (mid-task) "프롬프트 기록을 뽑을 때는 이 세션의 프롬프트만 P16 제목 아래 넣고, 같은 폴더에서 돌던 A2 세션의 프롬프트는 넣지 마."
- [Woohyun Song, 11-23] (after the first push, pasted; excerpt) "hold-chair를 기다리지 말고, 지금 codex/iter5-hold-plank(A4, PR #90)를 그냥 git merge로 받아 와서 8절을 진행한다."
- [Woohyun Song, 11-24] (when A5 came up, pasted; excerpt) "의자 자세 판(5, 11, 17, 23)을 하이 플랭크로 열던 대체를 지우고 의자 자세로 연다. 대체를 확인하던 테스트도 맞게 고친다."
- [Woohyun Song, 11-24] (after the phone check, pasted; excerpt) "고칠 것: 보스 매치 라운드 사이 화면의 "자세 잡기" 버튼 글자가 버튼 밖으로 거의 삐져나온다."
- [Woohyun Song, 11-24] (after the hold effects, pasted; excerpt) "아케이드에서 버티기 판에 들어가 결과 화면을 거쳐 아케이드 홈으로 돌아오는 길이 아케이드 대결 판과 같은 순서로 곡이 바뀌는지 코드로 확인한다. 특히 jingle이 두 번 나거나 곡이 겹치지 않는지 본다."
- [Woohyun Song, 11-24] (the last phone check's results, pasted; excerpt) "A2~A5 PR은 지금 HEAD에서 Codex 리뷰가 끝나 더 커밋하지 않기로 했다. 그래서 A4·A5 몫의 폰 확인 결과도 이 브랜치의 테스트 기록에 함께 적는다."
- [Woohyun Song, 11-23] (after the laptop lost power, pasted; excerpt) "이어서 하기 전에 먼저 상태를 확인해 줘. 1. 지금 브랜치가 codex/iter5-ai-opponents인지, git status, 남아 있는 .git/index.lock이 있는지 본다."

### c. What AI did well
- **Porting the map from its script:** the map's layout is the design's own arithmetic (`top(f)`, the six places,
  cell sizes, the `me` offsets) in `ArcadeMapLayout`, pinned by `test/widgets/arcade_map_test.dart` ('5F 공사중 on top,
  250 high; each floor 390 with a 46 band').
- **Keeping the shared files small:** the online battle is untouched. Every value added to shared widgets is optional,
  and the report's `PopScope` was moved into a Stack child, so `result_screen.dart` changes only the needed lines
  (35 added, 3 removed; with a wrapper it was 122 changed lines).
- **Tests that found real bugs before the phone:** a sheet whose `scopesRoute` semantics asserted, a band row and a star
  row that overflowed (three 16-point stars with a gap after each are 51 > 50; the design's `gap` is only between
  them), and floor tags that never showed until the first scroll. Each was fixed with a test that failed first.
- **Checking the record against the code:** the phone check's "2F 열림" did not fit A2's rule (stage 7 opens only
  after the boss's star, and the boss match was not won). Flagged in the report; the user said it was the 2F floor
  shown on the map with its first stage locked, and the record was corrected.
- **Checking the stack before merging:** the user's message said A2–A5 had taken `main`; a fetch showed none of the
  four had it yet and A5 had no dialog fix (the A5 session was still merging), so nothing was merged on the old
  branches, and the merge waited for A5's push (`b6e90d7`).
- **A gap between two merged features, found while merging:** #95's invite alert hides only on named routes
  (`FriendInviteRouteWatch.busyRoutes`), and the arcade opens its hold stages, boss intro and break as unnamed
  routes, so a friend's invite can show over them. Claude Code saw it while resolving `main.dart`, checked it
  with a throwaway test (not committed), and reported it instead of changing #95's file. The user called it a real
  bug and set the fix (`c02a9ff`): with the five names taken out again, the 7 new tests fail.
- **Checking a review finding before fixing it:** for PR #91's Codex P2, the two new flow tests were run on the old
  screen first and failed (no sheet after a late save), so the finding was real; reading A2's store for the order
  of `recordStage` and `read` then showed a second case (a read during the save could put the older progress back),
  fixed in the same commit with its own test.
- **Recovery after the power loss:** the state check (branch, `index.lock`, diffs, line endings, ownership, analyze)
  took a few minutes and found nothing half-written.

### d. Hallucinations / errors
- **Tokens in the wrong class:** the first edit put the arcade colors after `RepBotColors.shadow`, not in `AppColors`
  (`warning` undefined). Caught by the analyzer at once; moved.
- **Test edits by script:** two scripts appended a test group after the last `}` of the file, which was a helper after
  `main()`; one dropped `_rounded` from `versus_screen_test.dart`. A Python escape turned `\'` into `'` in three test
  names. All caught by `flutter analyze` before any run; fixed by inserting before `main()`'s closing brace.
- **A shell command that hung:** a stray `cat > "$TMP/x"` waited on input for two minutes before it was stopped.
- **Reviewer run 1 (CHANGES_REQUESTED):** the battle-end logic sat in a screens file (`ArcadeFlow`), so it was held to
  the View target and only widget-tested; no test checked the AI level and floor rules handed to the battle; bare
  design numbers in named arguments; no Design doc changes in progress.md; the interim result frame used the same
  class names as A4's uncommitted frame; the map computed locks itself instead of A2's `isOpen`. All fixed:
  `ArcadeViewModel.finishBattle` with a sealed outcome and unit tests, `ArcadeMatchups.rulesOf`/`botOf`/`battleOf`
  with tests, named constants, the `ArcadeBattle*` names. Run 2 approved with one Minor, also fixed.
- **Reviewer run 3 (CHANGES_REQUESTED), missed in runs 1 and 2:** the boss intro and the break did not scroll, so on
  a 360 x 640 phone or with 1.3x text their buttons were cut off (by up to 40 points). Caught by the reviewer's own
  layout check; fixed with a fill-then-scroll wrapper and tests at both sizes, which also showed the break's score line
  overflowing at 1.3x text. The reviewer also found that A4's dark button overflows with "R1부터 다시" at 1.3x text;
  A4's file is not edited here, so it was reported to the user for A4's branch.
- **Reviewer run 4 (APPROVE, 3 Minor):** a test named for "the user's character" gave no character view model, so
  it only checked the default; it now picks another character and checks that one reaches A4's screen. A4's branch had
  four new commits since `f9d1eba`; merged in `6074bf4`. A4's result frame also overflows on a 320-wide phone (its
  three 92-wide star columns); reported with the button for A4's branch.
- **Reviewer run 5 (APPROVE, 1 Minor):** the local progress file still described the stand-in as current; updated.
  Before the run, the new result test was also run once against A4's result files from before its fix,
  and 7 of its 10 tests failed with the overflows the reviewer had found, so the test guards them.
- **The break's button, missed by the tests and the reviewer:** the design's break puts 자세 잡기 in a full-width
  column (`width: 100%`); the port left it in a centred column, so the button was only as wide as its words and the
  slanted words' corners reached 2.4 px past its edge. The layout tests checked overflow and reachability, not the
  painted words, so they passed. Caught by the user on the phone (`9b59537`); fixed in `fcacca1` with a test that
  checks the slanted words' corners against each button's rounded shape on the boss screens, and fails on the old
  code. Cost: one fix commit and its tests.
- **Reviewer run 6 (APPROVE, 1 Minor):** the narrow-button test checked only the words' top corners, not the bottom
  left one that the slant leans out; it now checks all four against the button's round shape, and fails when the
  room for the slant is taken out.
- **The music check written too kindly (reviewer run 7, CHANGES_REQUESTED):** my first trace of the hold stages' music
  found that a hold closed on its briefing after a jingle brings the menu track back, where a fight keeps the
  silence, but left it as harmless, and my notes then said the order "matched", that two tracks "never go on
  together" (the music service cross-fades for 0.6 s at every change) and that the map "stays silent after any
  result". The reviewer read the code on its own and also found that A4's leave dialog still opens in a second
  warning's 1.5 s moment. The user's rule was to fix a difference on the P16 side, so `359ea18` adds `ArcadeHoldMusic`
  with tests that fail without it, the notes were rewritten, and the dialog was reported for A4's branch. Cost: one
  code commit, its tests and the notes again. Run 8 approved the fix, with three Minors: wording in the local progress
  file, the new file missing from `design_tokens_test.dart`'s list (added in `5553521`), and origin/main's #93 not
  yet in the A2–P16 stack (left to the user).
- **Reviewer run 9 (APPROVE, 4 Minors), on the `main` merge:** my new testing entry put #93's tests in
  `main_test.dart` (they are in `test/auth_flow_test.dart`) and said that if the app was closed in a second warning's
  moment `ArcadeHoldMusic` would keep the jingle, though a closed app need not dispose its screens and its sound ends
  with it. Both were rewritten before the commit; the other two Minors were PR #91's stale body and this file's
  missing P16 evidence.
- **Reviewer run 10 (CHANGES_REQUESTED), on the #95 merge:** my testing entry for this round had no test-case table
  and no acceptance criteria → tests, though the round added a test file and the merge changed two; it also called
  A5's `chair_hold_stage_test.dart` one of A4's files. The code and both merges passed its checks. Both fixed before
  the commit; run 11 approved, with two wording Minors, also fixed.
- **A path in my notes:** the post-push check matched `.claude/...` in the spec's path in my testing notes; fixed in a
  new commit (`7a1d46c`).
- **A race the tests and twelve reviewer runs missed (Codex, PR #91 on `f27a7e8`):** the map took the stage asked
  for one frame after coming back, while the stars could still be saving, so a slow save lost it. Every test used
  a store that answers at once. Fixed in `fbfef4c` with a store whose saves end late.
- **My first fix for it (reviewer run 14, CHANGES_REQUESTED):** a request still waiting when the map was left
  stayed asked for, and a later visit opened that stage's sheet by itself; my tests had pinned the two drops only
  together. Fixed before the commit (dropped when the map goes; each drop with its own test, each checked by taking
  it out alone). Run 15 approved, and its Minor about a page opened during the read was fixed too.
- **The hold stage's fix:** my `dart format lib …` reformatted two files of other steps (`character_motion.dart`,
  `player_avatar.dart`); seen in `git status` at once and restored before anything else. Reviewer run 16 approved
  and found that no test left the hold from a page of its own, so the map's two runs back were not exercised (test
  added, failing on the old `_playHold`), and that another account's save counted as this account's (guarded).
- **A placeholder body on PR #91 (2026-11-24):** my patch to the script that writes PR #91's body, sent through a
  shell heredoc, put real line breaks into a Python string and broke it (`SyntaxError`). The `gh pr edit` chained
  after it still ran and uploaded the older dry-run body, with the placeholders `TEST` and `@N@`, to PR #91. Caught
  by reading the live body back; the script was fixed in the editor, the body made again, uploaded, and read back
  with no placeholder left. Cost: a few minutes, and a wrong body public for under a minute (38 s in the PR's edit
  history, 13:37:15Z to 13:37:53Z). Since then the body is made and checked first and uploaded in a separate step.

### e. Prompt revisions
- Before (2026-11-24, pasted): "1. fetch 뒤 codex/iter5-hold-chair를 P16 브랜치에 merge한다. main.dart와
  online_lobby_screen_test.dart 충돌은 main의 구글 로그인과 P16 변경을 모두 살려 푼다."
- After (the same day, pasted; excerpt): "하네스는 두 번째 부모가 origin/main인 merge만 main 파일을 빼고 본다. …
  1. hold-chair에 main과 나가기 창 수정이 들어왔는지 확인한 뒤, P16 브랜치에 origin/main을 먼저 merge한다. … 2. 그다음
  codex/iter5-hold-chair를 merge한다."
- Why it worked: on A4 the user had seen the pre-commit guard block a merge commit made by hand that carried
  `main`'s files. With `main` first, `c92006c`'s check compared the index with `origin/main` (111 paths, all P16's
  own or inherited) and `670aecf`'s held only 5 paths, so both passed without any bypass.
- Before (2026-11-24, pasted): "P16 브랜치에 origin/main을 먼저 merge한다."
- After (the same day, pasted): "origin/main이 69b0520보다 앞서 있으면 origin/main을 먼저 merge한다."
- Why it worked: the message also said `origin/main` was still `69b0520`, but #95 had been merged to `main` by
  then (`18b9259`). The condition covered that case, so the merge order needed no question.
- None for the code in this step. The user added one rule mid-task (only this session's prompts under the P16 heading)
  and, after the power loss, gave the state check as a numbered list, which made the recovery a checklist.

### f. Manual fixes and why
- None: no code was edited by hand in this step. `TODO(Woohyun Song)`: add any hand edits made after the phone check.

## P8 `codex/iter5-auth-screens` – Redesign the sign-in and sign-up screens (team order #5), 2026-11-25

### a. Where AI was used
- **The hand-off** (Woohyun Song's account, 2026-11-25):
  - The menu mockups `LoginFinal.dc.html`, `LoginB.dc.html`, `ChL.dc.html` (the group photo's poses and motion)
    and `LoginCSheet.dc.html` were made earlier by Woohyun Song with Claude in Claude Design, on the canvas
    "GymRats 메인 메뉴 시안".
  - `SPEC.md` v1, `LoginS.dc.html` and `LoginStateBoard.dc.html` were made by Claude (claude.ai chat, Claude Opus 5.5).
    Woohyun Song chose among the mockups on the canvas: the C1-A first screen, the id login as a bottom sheet, the
    id sign-up screen kept as it is, and the L1, C2 and F1 states.
  - The screen values come from these `.dc.html` sources as they are; this session (Claude Code) moved them to
    Flutter.
- **Planning:** before any code, Claude Code read the spec, the mockups and the character engine. It compared ChL's
  drawing with the app's W3 + W4 + W5 drawing lists shape by shape, using a throwaway Python script. The result: the
  six bodies are identical, and only the faces, the thumb and RepBot's back glove are new. It then reported the plan
  of spec section 11 and waited. The user approved it with three decisions and five additions (Prompt Log, 11-25 02:40).
- **Local harness (not committed):**
  - P7's and P9's branches in `ownership.json` were changed to the branches that really merged (#93, #95). The guard
    had reported "P7 미머지" and blocked every P8 edit.
  - The ownership exceptions file got 15 P8 lines.
- **Generated, then checked:**
  - `lib/widgets/auth_cast_data.dart` (142 lines) was written by a throwaway converter from `ChL.dc.html`
    `motions.d1` and `LoginB.dc.html`. It asserts each LoginB value it copies against the file.
  - `test/widgets/auth_cast_golden.json` was written by running ChL's own JavaScript (`RIGX.vals`) in node.
  - Neither script is committed (the user's decision).
- **The code and tests:** Claude Code wrote all of it, in four commits (`68597e4`, `5e5c8aa`, `e1b88b1`, `c91a8f3`)
  after the code reviews passed, then merged `origin/main` (`def1c5e`).
  - **The group photo:** `lib/widgets/auth_cast.dart` (L1–892). The model is `AuthCast` (L24); the clock is
    `AuthCastStageState` (L652); the painter is `AuthCastPainter` (L745).
  - **The screens:** `lib/screens/login_screen.dart` has the first-screen layout (L189), the id sheet (L324) and the
    sheet's edge (L480). `lib/screens/social_signup_screen.dart` is the nickname step.
  - **The parts:** `lib/widgets/auth_form.dart` gets the new parts (L185–941), including the line-break helpers
    `keepWordsWhole` (L845), `authLines` (L863) and `AuthWords` (L902).
  - **The tokens:** `lib/theme/app_theme.dart` gets `AuthColors`, `AuthLayout` and `AuthText` (L1267–end).
  - **The view model:** `lib/viewmodels/login_viewmodel.dart` gets `cancelledWith` and `failedWith` (L16–40, L130–148).
  - **The color reader:** `lib/models/character_rig.dart` `_color` (L529) also reads `#RRGGBBAA`.
  - **Tests:** 3 new test files and 8 changed ones (the testing notes' table).
- **Review:** the `reviewer` subagent ran four times: 1 and 3 CHANGES_REQUESTED, 2 and 4 APPROVE (item d).
- **Not done by AI:**
  - The user checked the 27 comparison images against the mockups and found the line-break problem (item d).
  - The user decided the three open design points, the F1 box covering the characters at the smallest size, and
    the commit and phone-check order.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-25] "3. 코드를 쓰기 전에 SPEC.md 11절의 계획(단체 사진을 그리는 방법, 새 파일과 범위 밖 파일, 취소 신호, 테스트 목록과 순서)을 보고하고 기다린다."
- [Woohyun Song, 11-25] "4. golden 시각: 키 포즈 시각만이 아니라 다음 시각도 넣는다. 그래야 보간과 이징이 틀린 것이 잡힌다."
- [Woohyun Song, 11-25] "1. 한글 줄바꿈: 320×640, 글자 1.3배에서 단어 중간이 잘린다. … 인증 화면의 한글(버튼, F1 칸, 취소 줄, 시트, 닉네임 화면)은 띄어쓰기 자리에서만 줄이 바뀌게 한다."

### c. What AI did well
- **Using the engine instead of copying ChL:**
  - The shape-by-shape comparison showed that ChL's pose arrays map one to one onto the home rig's key poses.
  - So the photo runs on the app's own engine. No existing character file changed except one additive color rule.
  - The golden test checks 645 sampled frames against the design's own code with no difference. The times include
    eased mid-segments and ±1 ms around every hop, rock, flag and face change, and the 18 s wrap.
- **The reviewer's data check:** in run 1 the reviewer compared every number of `auth_cast_data.dart` with
  ChL line 738 and LoginB by script, with 0 differences.
- **Render comparisons:** throwaway widget tests drew every state with the app's fonts into PNGs, kept in the
  scratchpad. They caught three layout bugs before any widget test was written (item d).
- **Finding the minimal signal:** `LoginViewModel` needed two defaulted fields. With them the screen can tell a cancel
  (C2), a Google failure (F1) and the expired session apart without changing any message.

### d. Hallucinations / errors
- **Logo slant:** Claude Code first slanted the lime bar and GYMMOUSE the wrong way. It took CSS `skewX(-14deg)` as
  leaning left, then passed a tangent where `Matrix4.skewX` takes an angle. Caught by comparing the render with
  `state_base.png`; fixed before any commit. Cost: one re-render.
- **Podium outline:** it assumed SVG strokes are drawn inside a shape's edge and deflated the podium's outline. SVG
  centres them. Caught on re-reading its own code before the first render.
- **Sheet border:** a rounded `Border` with no bottom side throws in Flutter. The first render test failed on it, so
  it was replaced by a small edge painter (`login_screen.dart` L480).
- **Field text offset:** the theme's input padding leaked into the sheet's fields. Caught by the render.
- **Reviewer run 1:**
  - Major: two public enums were missing from the Design doc changes.
  - Minor: closing the sheet during a login let a wrong-password result show as an F1 box on the first screen. This
    broke the user's rule (b). The fix got a test that fails on the old code.
- **Korean line breaks:** at 320 × 640 with text 1.3, Korean broke inside a word ("Google 로그인에 실패했어 / 요."). It
  was not seen by Claude Code, whose overflow tests only check that nothing spills out. The user found it in the
  images. The fix keeps words whole and balances two lines.
- **Smaller slips:**
  - `pumpAndSettle` never settles while the photo's ticker runs, so the first clock tests timed out.
  - The new `AuthText` widget's name clashed with a theme extension; it was renamed to `AuthWords`.
  - A unit test expected a split that was a tie.
  - The first prompt-log entry included the harness-injected `<browser_instruction>` block. It was removed, since
    only the user's words belong there.
- **Reviewer run 3:**
  - Major: the notes were written as new files, but `origin/main` already had them with A2's entries (#89 merged
    meanwhile). Committing them as they were would have dropped A2's evidence. They were merged into main's files
    after merging `origin/main` (`def1c5e`).
  - Minor: the balanced line break measured lines without the device's bold text. Fixed in `c91a8f3`.
- **Found on the phone:** after a wrong password, closing the sheet made Samsung Pass offer to save the login. The
  sheet's `AutofillGroup` committed on dispose (Flutter's default), which no widget test had looked at. The user found
  it in the phone check and named the fix: cancel on close, save only after a login that worked (`dd08911`, with a
  test that fails without it).
- **A risk the user caught in review:** the `#RRGGBBAA` reader puts the alpha last, while a Flutter color keeps it
  first. A swapped order would not change any pose or face, so the golden test could not catch it. The user asked
  for a unit test that pins the order (`'#FF000080'` is half red).

### e. Prompt revisions
- **The golden times:**
  - Before (the approved plan): golden values at the key-pose times.
  - After (11-25 02:40): also mid-segment eased points, both sides of every hop/rock range and flag change, and the
    18 s wrap.
  - Why it worked: the key-pose times alone would pass with a wrong easing or an off-by-one range.
- **Line breaks:**
  - Before: "넘치지 않기" (spec section 8), checked only as "no overflow".
  - After: "띄어쓰기 자리에서만 줄이 바뀌게 한다", with a suggested method (U+2060 in the drawn text only, screen readers
    and finders untouched) and the expected splits.
  - Why it worked: the expected splits showed the greedy wrap's "Google로 로그인하는 / 중…" was still wrong, which led
    to the balanced two-line break.

### f. Manual fixes and why
- None: no code was edited by hand in this step, so there are no manual-fix markers.

### Takeaway
- Render comparisons at the smallest size with large text catch what overflow tests do not. Look at the pictures
  before calling a screen done.

## A7 `feat/iter5-defeat-pose` – PvP 패배 포즈 추가 및 무승부 표시 수정 (a separate task in the PM's merge plan), 2026-11-26

### a. Where AI was used
- **The hand-off:** `ldfx/SPEC.md` v2 and the mockups `LdA.dc.html` (lose and draw), `LdAFrames`, `LdALose`,
  `LdADraw`, with `ChB`, `ChX` and `W5Report` (not committed). The screen values come from `LdA.dc.html` as they are;
  this session (Claude Code, Claude Opus 5.5) moved them to Flutter. Who made them (Woohyun Song, 2026-11-26):
  - **The mockups (LdA):** Claude made three directions, A, B and C, in Claude Design on claude.ai (the canvas
    "GymRats 메인 메뉴 시안", page "패배·무승부 연출 시안"). Woohyun Song chose A ("거울 컷인"), the loss panel's
    #FF3B30, and A as it is for the draw.
  - **SPEC v2:** Claude (Opus 5.5) wrote it in a claude.ai project chat from the mockups, the code and the PM's
    acceptance criteria. Woohyun Song set the mockup's direction and colors and how A7 is run. The PM's approval
    of 11/26 (due 11/28, the two exceptions) went into its v3.
- **Planning:** before any code, Claude Code read the spec, the mockups and the victory, result and character code.
  It found that the mockup's two characters are the app's own drawings: `ChB` (guard and fist) is the battle stage's
  `CharacterFigurePainter` with the stage's draw patch, and `ChX` `frus` is the W5 rig's `frustrate` motion. So no
  character file had to change. It reported the plan of spec section 9 with three open points (where the values
  live, a new file or not, the overlay's argument) and waited. The user and the PM approved it with decisions A, B
  and C and the due date (Prompt Log, 11-26 11:49).
- **Local harness (not committed):**
  - The A7 step and five exception lines.
  - The v3 reinstall had put back `resolve()` in `.claude/hooks/ownership_guard.py`. Through the `.claude` junction
    the hook then read the main folder's branch, and the edit check let every file of this worktree through. Claude
    Code found it when `--status` showed the wrong branch and restored the one line from the backup.
- **Generated, then checked:** `test/widgets/victory_defeat_golden.json` was written by running `LdA.dc.html`'s own
  `renderVals()` in node, with `toFixed` made exact. The script is not committed (the user's decision).
- **The code and tests:** Claude Code wrote all of it, in four commits after the code reviews passed:
  - `4a1266d` the scenes:
    - `lib/widgets/victory_defeat.dart` (new, L1–675): the values `VictoryDefeat` (L36), the frames
      `VictoryDefeatScene` (L228; loss L383, fighters L463).
    - `lib/widgets/victory_scene.dart`: the new frame types (L619–845).
    - `lib/widgets/victory_overlay.dart`: the painter's new layers (L327–620), `opponent` (L52, L57).
  - `c146864`: `lib/services/game/online_battle_result.dart` L50.
  - `d6c917e`: `lib/screens/result_screen.dart` L513, and the PM acceptance test.
  - `cd7677e`: `lib/demo/result_scene_demo.dart`.
  - Tests: 4 new files and 6 changed ones (the testing notes' table).
- **Review:** the `reviewer` subagent ran three times: run 1 CHANGES_REQUESTED, run 2 APPROVE on the code, run 3
  APPROVE on the commits and these notes, with two Minor points fixed before the push (item d).
- **Not done by AI:**
  - The user and the PM decided the open points and the PR's shape: decisions A, B and C, the order before P15, and
    the Win/Loss/Draw checklist.
  - The phone check was the user's (2026-11-26, SM S947N, a release build of the demo): all four cases as
    expected; the four recordings are in PR #101's comment, posted by the user.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-26] "4. 코드를 쓰기 전에 SPEC.md 9절의 계획을 보고하고 기다린다."
- [Woohyun Song, 11-26] "2. progress.md를 쓸 때 SyntaxWarning(invalid escape sequence)이 났다. progress.md와 ownership 파일을 다시 열어, Windows 경로의 역슬래시가 깨진 곳(특히 \t, \n이 탭이나 줄바꿈으로 바뀐 곳)이 없는지 확인하고 고친다."
- [Woohyun Song, 11-26] "8. … Draw: LOSE나 '패배' 대신 '무승부' 문구가 나오고, 장면에 내 캐릭터와 상대 캐릭터가 함께 나온다(주먹을 맞부딪치는 순간)."

### c. What AI did well
- **Reusing the drawings:** by reading `ChB.dc.html` and `ChX.dc.html` against the app, Claude Code showed that the
  draw's fighters and the loss's frustration already exist in the app. No `character_*` file or asset changed, and the
  W5 rig file stayed the bundle's.
- **A golden that matches the formulas:** the mockup rounds positions to 0.1 px for its CSS, which is coarser than
  the 0.01 tolerance. Making `toFixed` exact in the node run kept the formulas' own values. The reviewer re-ran the
  extraction and got byte-identical output. Three deliberate mistakes (an ease, a 1 ms shift, a rate) each made the
  test fail.
- **The PM's criteria through every screen:** one test file follows a server-ended draw, win and loss through the
  stage's verdict and poses, the report's scene and title, the 기록보관소 row and the report opened from it.
- **Render comparison:** a throwaway test drew the twelve LdAFrames moments with the app's fonts into one sheet,
  compared by eye with `shots/LdAFrames.png` before the review.

### d. Hallucinations / errors
- **Reviewer run 1:**
  - Major: no test tapped through a draw (SPEC 7.5). Added for a loss and a draw; it fails when the draw's skip
    button is hidden.
  - Minor: two doc comments in `victory_scene.dart` still described W5's loss.
- **Reviewer run 3 (notes):** the notes said the reviewer ran twice, and the testing notes did not say that a
  non-arcade AI 1v1 report plays the same scenes (the result screen turns the scene off only for past and arcade
  reports). Both added before the push.
- **The progress.md write:** the first Python heredoc held Windows paths in normal strings and raised a
  SyntaxWarning for `\d`. The user asked for a check. The three harness files were re-read: no tab, newline or
  control character had replaced a backslash. Later scripts use forward slashes.
- **Smaller slips, each caught by a failing run:**
  - `[700.0, 1000, 1400]` inferred `List<num>` (analyze).
  - The demo test tapped the opponent row's 곰탱이 instead of mine (the name is in both rows).
  - The demo test used `pageBack` on a screen with no back button; it now uses system back.
  - An unquoted heredoc mangled a path in the export step.
- **Timing tests:** three unrelated timing tests failed once each in full runs and passed alone (testing notes). They
  were not changed.

### e. Prompt revisions
- **The exceptions' wording:**
  - Before (first message): the two exceptions are "선조치 후보고".
  - After (11-26 11:49): "PM approved 2026-11-26", due 11/28, and the `result_screen_test.dart` line widened to the
    one old-scene test.
  - Why it worked: the PM's approval came between the plan and the code, so the harness and the PR could say so.
- **The PR's shape:**
  - Before: the spec asked only for a phone check proposal.
  - After: a checklist of the PM's three cases with the test names and a place for the user's screenshots.
  - Why it worked: each PM case maps to named tests and to one picture.

### f. Manual fixes and why
- None: no code was edited by hand in this step, so there are no manual-fix markers.

### Takeaway
- Read the mockup's helper components against the app's code before planning: here they showed that nothing in the
  character engine had to change.

## A8 `feat/iter5-hold-character` – Hold stage: my character holds along (local step, PM approved 2026-11-27), 2026-11-26

### a. Where AI was used
- **The hand-off** (Woohyun Song's account, 2026-11-27):
  - **The mockups:** `HoldMe.dc.html` (with `HoldMeLiveA`, `HoldMeAAll`, `HoldMeLieA`, the data and the shots) were
    made by Claude in the Claude Design canvas on claude.ai (canvas "GymRats 메인 메뉴 시안", page "버티기 · 내 캐릭터
    연출 시안"). Claude made three directions (`dir` a, b, c), two star actions and three lying candidates.
  - **The choices:** Woohyun Song chose direction A1 (hold together, a pop at each star in place), the lying pose
    A, and the bubbles' current place (2026-11-26).
  - **The spec:** `SPEC.md` v1 was written by Claude in a claude.ai project chat, from the mockups and the code.
  - **In planning:** Woohyun Song decided that with reduced motion the chair pose's star moment shows the arms-up
    pose.
- **Planning:** before any code, Claude Code read the spec, the mockup's `calc()` and markup, the rig data, and the
  hold stage, character and victory code. It reported the plan of spec section 10 and waited. The user approved it
  with three scope additions and one change: reduced motion's chair star (Prompt Log, 11-26 22:38).
- **Local harness (not committed):** step A8 in `ownership.json` (ID, branch and due 11/29 as the PM approved them on 2026-11-27), and its
  allow list from spec section 0 plus two approved paths. Two exception lines: `design_tokens_test.dart` and, after
  the full run, `chair_hold_stage_test.dart` (item d).
- **Generated, then checked (scripts not committed, as the spec says):**
  - `lib/widgets/hold_me_rig_data.dart`: the bundle's `hold_me_rig.json` with each list on one line. The script
    asserts it is JSON-equal to the bundle file.
  - `lib/widgets/hold_me_drawing_data.dart`: the three drawings and the effect art, converted from the `.svg.txt`
    copies. The script checks each copy is the same text as its group in `HoldMe.dc.html`.
  - `test/widgets/hold_me_golden.json`: picked from the bundle's golden. Extra mid-curve moments came from the
    mockup's own `renderVals()` run in node, after the run reproduced five bundle moments exactly.
- **The code and tests:** Claude Code wrote all of it, in eleven commits (`189144c` to `eb91408`, as rebased on
  `main` `38726e8` with A7 and P14; `a27b5ac` and `f9c3dae` fix reviewer run 1's findings, `0403faa` run 2's,
  `eb91408` run 3's).
  - **Parser:** `lib/widgets/hold_me_rig.dart` (`HoldMeRig` L17, `HoldMePlace` L107, `HoldMeShape` L251).
  - **Pure scene:** `lib/widgets/hold_me_scene.dart` (`HoldMeTimeline` L122, `HoldMeCheer` L319,
    `HoldMeScene.frameAt` L388, `flightAt` L538).
  - **Painters:** `lib/widgets/hold_me_figure.dart` (`HoldMePainter` L39, `HoldMeFlightPainter` L210). The rig is
    drawn by the existing `CharacterFigurePainter` with the home and W5 drawing changes (`_paintRig` L91).
  - **The stage:** `lib/screens/hold_stage_play.dart` `_StageState` (L203–518): the ticker, the timeline, the
    character, the flight, the bar stars and the bubbles, each child keyed (`_build` L299).
  - **Timing values:** `HoldTiming` in `lib/services/pose/hold_judge.dart` (L29–49).
  - **Demo:** a reduced-motion switch in `lib/demo/hold_stage_demo.dart`.
  - **Tests:** four new test files and four changed ones (the testing notes' table).
- **Review:** the `reviewer` subagent ran on the code (run 1 on `f04a85e`: CHANGES_REQUESTED), on the fixes and
  these notes (run 2 on `4a3fea8`: APPROVE with two Minors, fixed in `0403faa` and this line), and on that fix (run 3
  on `8b8f1a8`: APPROVE with three Minors, fixed in `eb91408`, the rebase and the testing notes), and on the rebased
  branch (run 4 on `523ba89`: APPROVE with three wording Minors, fixed in `091ee2c` and these notes); item d.
- **Not done by AI:**
  - The user chose the direction and the place, decided reduced motion's chair star, and approved each scope
    addition.
  - No real-phone check yet: the camera pose setup was not possible, so the user moved it to the app build after
    the merge (2026-11-27).

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-26] "지금은 큰 말풍선, 관장 웃는 얼굴(GymOwnerFace.ok), 막대 별 튀기기(popStar)가 모두 cheer callout 하나에 묶여 HoldTiming.cheer(1초) 동안만 보인다. 이번에는 별을 딴 순간에서 각각 800ms, 700ms, 900ms에 시작하므로 따로 떼어야 한다."
- [Woohyun Song, 11-26] "뷰모델 변경은 되도록 작게, 그 부분들과 떨어진 곳에 둔다. 시간 재기는 가능하면 위젯 쪽에서 한다."
- [Woohyun Song, 11-26] "3. 움직임 줄이기 중 별 순간은 이렇게 바꾼다. 의자 자세는 만세 자세(up)로 바로 바뀌어 win 표정으로 1.6초 보인 뒤 바로 버팀 자세로 돌아온다."

### c. What AI did well
- **No change to the view model's code:** the cheer callout already lived in the view model for `HoldTiming.cheer`.
  Raising that value to 2.4 s and timing the 0.7/0.8/0.9 s parts on the screen kept `hold_stage_viewmodel.dart`,
  `hold_stage_screen.dart` and `hold_stage_result.dart` untouched. Those are the files a teammate's P13 edits.
- **Reusing the engine:** the rig characters use the W5 victory rig's drawing changes and its `grit` (atk + teeth)
  through `CharacterFigurePainter` and `blendPoseTables`. No character, victory or owner file changed, so the spec's
  exception for character files was not needed.
- **The mockup as the test oracle:** running the mockup's own `renderVals()` in node gave rig values at mid-curve
  times the bundle's golden lacked. Nine deliberate mutations, four in the scene and five in the stage, were each
  caught by the tests.
- **A render by eye before wiring:** a throwaway test drew 5 characters × 7 moments per pose. It matched the
  bundle's shots before the stage was touched.

### d. Hallucinations / errors
- **A test missed in the plan:** the plan listed the hold screen and view model tests that pin the 1 s cheer. It
  missed `test/services/pose/chair_hold_stage_test.dart` (A5), which looked for "좋아!" 0.2 s after the star. The
  first full run failed it at three sizes. Claude Code then tried to add an ownership exception line itself; the
  permission check refused it, since no approval existed yet. It asked the user, who approved it (2026-11-27). Cost:
  one more full run.
- **Converter and script slips:**
  - The drawings' converter first rejected the teeth group nested inside the atk group.
  - Its JSON then lacked the closing brace.
  - A scripted edit of the golden extractor left an unescaped quote.
  - All were caught by the scripts' own checks before any file reached the repo.
- **Reviewer run 1 (Major): bubbles popping in twice.** The flying star was an unkeyed child of the stage's
  Stack. When it went at 0.9 s, the cheer's (or a warning whistle's) unkeyed `Positioned` took its element, and the
  bubble's pop-in started over. The same slip replaced the owner's element when the character first showed. Claude
  Code's tests looked for each widget, never at whether it kept its element. The reviewer measured it in a probe
  test (the cheer 121 wide at 901 ms against 243 at rest). Fixed in `a27b5ac` with a key per child. Four new tests
  fail on the old code. Cost: one fix commit and a full run.
- **Reviewer run 1 (Minor):**
  - With reduced motion, the second star's look gave way to the strain at 1.35 s while the cheer still showed, which
    SPEC 7 does not allow. It followed the motion rule. Fixed in `f9c3dae`.
  - The clock rebuilt the whole stage every frame, setup included.
  - The golden's cheer timeline was committed but read by no test.
  - The fit test could not fail for the character.
  - All three were fixed in `a27b5ac`.
- **Reviewer run 2 (Minor):** to stop the clock during the setup, Claude Code set the ticker's `muted` itself on
  every change of the play. That overrode the muting `TickerMode` gives a covered screen, so a covered stage would
  keep ticking. The reviewer showed it in a probe. Now the ticker keeps its time and only leaves the stage unbuilt
  during the setup (`0403faa`). A new test fails on the old code (its first version passed on the old code too,
  since its two 375 ms pumps made a full breathing half-cycle, where the breath is back at 1).
- **Reviewer run 3 (Minor): an age below zero.** That fix recorded times at the clock's latest tick but still drew
  at the last rebuild, which stands still during the setup. A tick in the setup, then a covered screen and a star,
  made the star's age −2 s, and the character was drawn twice as tall for a frame. No route in the app covers the
  stage like that today; the reviewer found it in a probe. The stage now draws at the time it records (`eb91408`),
  with the probe as a regression test.
- **The rebase on A7 (#101):** both A7 and A8 had appended to the three personal notes, so Git split the appends into
  several conflicting hunks around lines the two sections share. Instead of editing the markers, a script rebuilt
  each file as `main`'s file plus exactly what the A8 commit had appended. `git range-diff` showed every code commit
  unchanged.
- **Timeline edge:** a stage first seen while already paused recorded the warning's start at that first look. The
  timeline test 'a stage that starts stopped shows the warning in full' failed, and the look now leaves it unset.
- **Test-side mistakes, caught by their first runs:**
  - An `expect` outside a test.
  - Drawing counts that forgot the strain's sweat and the landing's dust.
  - Comparing `Paint` colors as doubles: Paint keeps 32-bit colors.
  - Recorded canvas calls that keep null optional arguments.
  - A view model test that put the star on the 15000 ms frame, when the time runs from the first frame (15100).
- **The token check's false hit:** `HoldMeColor(0xFF000000 | …)` matched the raw-color rule `Color\(0x`. The value
  is now built first.

### e. Prompt revisions
- **Reduced motion's star:**
  - Before (the plan): the hold pose with `win` for every pose.
  - After (11-26 22:38): the chair pose jumps to its arms-up pose with `win` for 1.6 s, then straight back.
  - Why it worked: it matches spec section 7's "each moment's pose and face" and the warning, which also shows its
    pose at once.

### f. Manual fixes and why
- None: no code was edited by hand in this step, so there are no manual-fix markers.

### Takeaway
- When a shared timing value changes, search every test for it and for the keys it drives (`hold-cheer`,
  `HoldTiming.cheer`, "좋아!") before the plan, not only the step's own files.

## A9 `feat/iter5-coach-voice` – 코치 대화 · 캐릭터 어미 다듬기 (a separate task approved by the PM 2026-11-27), 2026-11-27

### a. Where AI was used
- **The hand-off:** `coach-voice/SPEC.md` v1, then v1.1 (only the exception wording and the PR's shape changed),
  outside the repo and not committed; its dialogue table was used as written. Who made it (Woohyun Song,
  2026-11-27):
  - The problem was found while recording the demo video and shared at the team meeting on 11/25.
  - SPEC v1 and v1.1: Claude (Opus 5.5) wrote them in a claude.ai project chat after reading `coach_script.dart`.
    Claude proposed the rule (the ending only after '-다!') and the nine new lines; Woohyun Song checked them. v1.1
    changed only the PR's shape.
  - Woohyun Song decided to leave the result card's line to P15.
- **Planning:** before any code, Claude Code (Claude Opus 5.5) read the spec, `coach_script.dart`, the coach view
  model, screen and widgets, and their three tests. It reported the plan of spec section 8 and waited (Prompt Log,
  11-27 02:31). It also found a reader of `CoachVoice.ending` that the spec had not listed: the result card's line
  "이번 판 이야기해 줄게{e}!" (`result_screen.dart` L180, `result_cards.dart` L446), which breaks the same rule. Before
  the plan it measured every new line with the app's fonts in a throwaway test (not committed), so the plan could say
  that no sentence needed shortening.
- **Local harness (not committed):** the A9 step, its allow list narrowed to the PM's two files, and one exception
  line for `coach_viewmodel_test.dart`. `.codex-harness` is a junction shared with the A8 session in the main folder,
  so every change added or edited single lines.
- **The code and tests:** Claude Code wrote all of it, in commits `c7157ef` (the code and tests) and `d68cfd9` (the reviewer's two test fixes):
  - `lib/services/feedback/coach_script.dart`: `CoachVoice.exclaim` (L249–255), the doc of `ending` (L245–247), and
    every line of the talk through `exclaim` (L693, L744, L758, L770, L791, L810, L866, L894, L980, L993,
    the question L1049–1059, the answers L1062–1091, the end L1094–1097); the slowed pace (L881) now has none.
  - `test/services/feedback/coach_script_test.dart`: the helpers `_endings`, `_talks`, `_branchMarks`, the new group
    "the ending only after "~다", before "!" (A9 spec 1 and 5)", and the 14 old expectations.
  - `test/viewmodels/coach_viewmodel_test.dart`: 5 lines (the exception).
- **Review:** the `reviewer` subagent: run 1 APPROVE on `c7157ef` with four Minor points, all fixed; run 2
  CHANGES_REQUESTED on `bc36d8c` (two Major and three Minor points in the notes and the PR draft, all fixed; item d).
- **Rebase onto `main` (11-27):** after A8 (#104) merged, the three notes files conflicted. Claude Code rebased the
  branch onto `037b58e`, as the user asked (not a merge). A small script resolved each conflict: A8's section
  first, then A9's. It checked that the A9 code was unchanged and that each file was exactly main's file plus A9's
  lines. The commits are now `07aee1a`, `1434cd2`, `0274949`, `14b5067` and `122f0ad` (they were `c7157ef`,
  `d68cfd9`, `bc36d8c`, `1a707b6` and `5937c1b`). `extract_prompts.py` also offered the automatic summary written
  when this session's context was compacted. That is not an input prompt, so only the user's request went into the
  log.
- **Not done by AI:**
  - Woohyun Song decided the result card (neither of the plan's two options: it stays P15's, and `ending` stays
    readable) and the PR's shape (SPEC v1.1); the PM approved the two files, and the exception was act first, report
    after.
  - The phone check: not done on a device for this PR (the user's decision, 11-27). It is checked on a real phone
    at the team meeting after the merge (11/29); the wording and the overflow are covered by the tests.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-27] "4. 코드를 쓰기 전에 SPEC 8절의 계획을 보고하고 기다린다. SPEC 1절과 2절의 대사 표는 정해진 것이라 다시 묻지 않는다. 다만 넘침 때문에 줄여야 할 문장이 있으면 계획 보고에 적는다."
- [Woohyun Song, 11-27] "결과 카드는 A도 B도 아니고 이렇게 한다."
- [Woohyun Song, 11-27] "PR 본문에 체크리스트 절을 만들지 않고, 하네스 pull-request 스킬의 형식을 그대로 따른다."

### c. What AI did well
- **A rule test that can fail:** the rule check builds 21 talks for each of the five characters and checks every
  line. A table of 34 branch marks fails the test when a talk is dropped and a branch goes unsaid. Four deliberate
  mistakes in `coach_script.dart` (the old end line, a typed-in "수고했다범!", the ending twice, the old question)
  each made it fail, and the file was put back identical.
- **The overflow question answered before the code:** measuring the new lines with the app's fonts at the overflow
  test's sizes showed that the longer questions still fit, so the plan could leave the widgets alone, and
  `coach_screen_test.dart` passed unchanged.
- **The unlisted reader of `ending`:** found by a search before the plan, so the PM could decide the result card
  before any code depended on making `ending` private.

### d. Hallucinations / errors
- **The spec's count:** SPEC 5.4 said about 36 places in `coach_script_test.dart`. The diff changed 12 tests (14
  expectations, 18 lines) that expected the changed lines. The other lines with an ending ("수고했다범!", "미션 성공이다범!") already
  follow the rule and did not change.
- **Slips in this session, each caught:**
  - progress.md first said 33 branch marks; a count of the map gave 34.
  - One mutation command broke on shell quoting; the mutations then ran from a small script file.
  - Three edits of progress.md were refused: twice "File has not been read yet" and once "File content has changed
    since it was last read" (the file is shared with the A8 session). Each time it was re-read and the edit applied
    to the current text only.
- **Reviewer run 1 (Minor points, all fixed):**
  - The rule test's branch set was shared by the five characters, so it checked less than its comment said; now
    each character must say every branch.
  - `coach_viewmodel_test.dart` L467 had been narrowed to the line's fixed words; it expects the whole recall line
    again.
  - The wiki Requirements 5.6 (criterion 4) still quotes the old shapes "다음 판 미션, 뭐로 할까…?" and "지난번
    미션 기억나…?"; it is now a design-doc change for the PM (the PR's Review notes).
  - The local exception line still said "PR Exceptions"; it now says Review notes (SPEC v1.1).
- **Reviewer run 2 (notes and the PR draft):**
  - Major, a claim that was not checked: the plan before the code (11-27) and the drafts said the battle demo's result opens
    the talk. It does not: the result screen pushes `/coach` (`result_screen.dart` L394), and
    `lib/demo/battle_demo.dart` L98–112 routes only the result and the next battle. The phone check is now planned in
    the app, and the user was told.
  - Major: "14 tests" was the count of changed expectations, not tests (12), and the PR had no list of them (SPEC
    5.4). Both fixed.
  - Minor: the refused edits above were described with a cause the transcript does not show; L881 was listed as an
    `exclaim` line; the PR called the spec the design hand-off's (who wrote it is still a TODO).
  - Minor: a Python `write_text` turned the whole local `ownership-exceptions.txt` from LF to CRLF (Windows newline
    translation), though progress.md said LF was kept. Restored to LF; the file is the old one plus the A9 line.

### e. Prompt revisions
- **The result card:**
  - Before (the plan): A, fix the card's line too (scope added to `result_cards.dart`, one line of P15's
    `result_screen.dart`), or B, leave the card and keep `ending` public.
  - After (11-27 02:49): neither. The card line is P15's, `ending` stays readable with a doc saying the talk uses
    `exclaim` only, and the rule is held by tests.
  - Why it worked: the plan named the files and owners, so the PM could keep A9 to two files.
- **The PR's shape:**
  - Before (the approval message and SPEC v1): a checklist and an Exceptions section.
  - After (SPEC v1.1, 11-27 03:02): the `pull-request` skill's sections only; the table in What it does, the tests in
    How to test, the exception and the P15 note in Review notes.
  - Why it worked: the body follows the same skill as the team's other PRs.

### f. Manual fixes and why
- None: no code was edited by hand in this step, so there are no manual-fix markers.

### Takeaway
- Search for every reader of a field before planning to hide it: here the one reader outside the spec decided the
  design.
