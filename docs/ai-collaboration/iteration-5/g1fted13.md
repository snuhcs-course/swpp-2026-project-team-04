# AI Collaboration notes: Iteration 5 (2026-11-21 ~ 2026-12-04) – Woohyun Song
Status: draft (iteration open) | Written by: Woohyun Song | Merged by the PM into `AI-Collaboration-Report-Iteration-5.md` (P27)
Tools used: Claude Code (Opus 5.5), with the repo's `reviewer` subagent; Claude on claude.ai with the Claude Design canvas (the arcade art)

Evidence per step, items a–f of the AI Collaboration Report Guidelines v1.1. Input prompts are in
[g1fted13-Prompt-Log.md](g1fted13-Prompt-Log.md).

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
