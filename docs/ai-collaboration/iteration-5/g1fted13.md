# AI Collaboration notes: Iteration 5 (2026-11-21 ~ 2026-12-04) – Woohyun Song
Status: draft (iteration open) | Written by: Woohyun Song | Merged by the PM into `AI-Collaboration-Report-Iteration-5.md` (P27)
Tools used: Claude Code (Opus 5.5), with the repo's `reviewer` subagent; Claude Design (the user's design canvas); Claude on claude.ai (A2's spec and data); Claude on claude.ai with the Claude Design canvas (the arcade art)

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
- **The follow-up of 2026-11-24** (the user's decision): `77e1a75` keeps the 3·2·1's standing thigh from GO on (the
  spec's "follows while standing" narrowed to before GO), with 7 new tests, among them a slow sit over 3, 4 and 6 s.
- **Checking against the design:** the chair scenes captured with the app's fonts in a throwaway widget test (deleted)
  and compared by eye with the hand-off's shots (testing notes, A5 entry).
- **Review:** the repo's `reviewer` subagent ran on the A4 follow-up (runs 5–7), on A5's code (run 1), on
  these notes (runs 2–3) and on the follow-up of 2026-11-24 (run 4).
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
  check is the user's.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-23] (the step's start, pasted; excerpt) "A4에 의자 자세의 아이콘, 실루엣, 스쿼트 안내선이 없으면 이
  단계에서 그리지 말고 멈춰서 알려 줘. 기존 판정 코드(squat_rep_judge.dart, setup_checker.dart, pose_metrics.dart,
  rep_judge.dart)는 고치지 않고 가져다 쓴다."
- [Woohyun Song, 11-23] (mid-task, pasted; excerpt) "1. 하이 플랭크의 푸쉬업 안내선도 따로 도는 판정기에서 오는지
  확인하고, 오래 버티면 같은 식으로 사라지면 같은 커밋에서 함께 고쳐 줘."
- [Woohyun Song, 11-24] (pasted; excerpt) "깊이 기준은 폰 확인을 기다리지 말고 지금 고치자. 천천히 앉을 때 기준이 같이
  내려가서 깊이가 낮게 읽히기 때문이다(reviewer 시뮬레이션에서 0.8이 0.73~0.75로 읽힘)."

### c. What AI did well
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
- **Design values:** every size, color and position came from the `.dc.html` sources in
  `.claude/design/arcade/p16/design/` (read by Claude Code, not estimated from the shots), e.g. the map's `FH`,
  `BAND`, `WIP`, `P` and `me` values and the `ArcResult` frame.
- **Review:** the `reviewer` subagent ran six times (item d): CHANGES_REQUESTED, APPROVE, then after section 8
  CHANGES_REQUESTED and APPROVE, APPROVE after the A5 merge, and once more after the phone check's fix.
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
  rule (the design's shape kept, shrinking only on a narrow screen or with large text) and the sizes to test.

### b. Prompt history (representative; the input prompts are in the Prompt Log)
- [Woohyun Song, 11-23] (the step's start, pasted; excerpt) "앞 단계(A2~A5)의 파일은 상속만 하고 고치지 않는다. 고칠 것이 보이면 멈추고 알려 줘. … 판정, 점수, 봇의 rep 계산은 건드리지 않는다. 온라인 대결은 하나도 바뀌면 안 된다."
- [Woohyun Song, 11-23] (mid-task) "프롬프트 기록을 뽑을 때는 이 세션의 프롬프트만 P16 제목 아래 넣고, 같은 폴더에서 돌던 A2 세션의 프롬프트는 넣지 마."
- [Woohyun Song, 11-23] (after the first push, pasted; excerpt) "hold-chair를 기다리지 말고, 지금 codex/iter5-hold-plank(A4, PR #90)를 그냥 git merge로 받아 와서 8절을 진행한다."
- [Woohyun Song, 11-24] (when A5 came up, pasted; excerpt) "의자 자세 판(5, 11, 17, 23)을 하이 플랭크로 열던 대체를 지우고 의자 자세로 연다. 대체를 확인하던 테스트도 맞게 고친다."
- [Woohyun Song, 11-24] (after the phone check, pasted; excerpt) "고칠 것: 보스 매치 라운드 사이 화면의 "자세 잡기" 버튼 글자가 버튼 밖으로 거의 삐져나온다."
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
- **A path in my notes:** the post-push check matched `.claude/...` in the spec's path in my testing notes; fixed in a
  new commit (`7a1d46c`).

### e. Prompt revisions
- None for the code in this step. The user added one rule mid-task (only this session's prompts under the P16 heading)
  and, after the power loss, gave the state check as a numbered list, which made the recovery a checklist.

### f. Manual fixes and why
- None: no code was edited by hand in this step. `TODO(Woohyun Song)`: add any hand edits made after the phone check.
