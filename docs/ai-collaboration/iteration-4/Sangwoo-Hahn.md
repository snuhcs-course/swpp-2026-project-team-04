# AI Collaboration Report — Iteration 4: S3

## Issue #47: replay stored match mode (2026-11-15)
- Codex added the `isOnline` mode check to `BattleSetup.of` and regression cases for bot-like online nicknames, stored bot levels, unknown bot names and old records. The first targeted test run reproduced the two defects; the fixed tests and full suite passed. The user confirmed owner/PM agreement for the two home files and explicitly allowed a separate branch restricted to those source/test files. Personal course notes remain the normal exception.
- Independent read-only Codex review approved the change and noted that a deployed server or legacy record without the mode retains the name-based ambiguity. No real-server check, human source-code edit or time-saving estimate was reported.

Author: Sangwoo Hahn. Status: draft; team-wide interaction review remains pending.

## 1. Where AI was used
- Codex implemented and verified the push-up setup framing guide and screen integration.
- At the user's explicit request, Claude CLI (Opus 5.5, one resumed session) supplied successive silhouette designs. Codex applied the selected outline and checked the Flutter build and tests.
- No AI-based changes were made to the pose checker or server for this prototype.

## 2. Prompt History
See [selected user prompts](Sangwoo-Hahn-Prompt-Log.md). This is not a complete session export; a complete, reviewed export is still TODO.

## 3. What AI Did Well
- Iterative design produced a symmetric, rounded front-view outline in `gymrats_app/lib/widgets/pose_silhouette_guide.dart` and adapted the layout after the user described the desired camera placement.
- The agent used existing fake-camera tests and the phone debug build to check integration. Time saved was not measured.

## 4. Hallucinations / Errors
- The initial design depicted a side view, but the existing push-up setup expects a front view. The user corrected it and the design was revised.
- A generated Dart design needed a numeric type correction and a later landscape layout overlapped the exit button; compilation and widget tests exposed these errors. Effort was not measured.
- Independent review identified a remaining mismatch: the `cover` preview can crop landmarks while the existing checker uses the full frame. It is not fixed in this draft.

## 5. Prompt Revisions
- The user clarified that the camera faces the user and later asked for one transparent interior with a dark exterior, rather than separate position markers.
- After seeing the phone screen, the user asked for an outline following the photographed body, then for symmetry, smoothing, and a slightly lower position.

## 6. Manual Fixes and Why
- No human manual source-code fixes were reported. Codex made the compilation and layout corrections; these must not be attributed to a human.

## 7. Takeaway
- Validate the visible camera region against the detector input and confirm the guide on multiple real devices before calling the feature complete.

## S3 follow-up — alignment and auto-start (2026-11-13)
- Codex added a weighted distance check for the head, shoulders and hands in `gymrats_app/lib/models/setup_silhouette_alignment.dart`, considering the preview crop and mirror; the ViewModel gates the offline push-up countdown on this and existing pose checks. No ML model was trained for this change.
- The user requested a three-second wait and then suggested comparing the sum of joint distances to the silhouette; Codex implemented the selected approach with individual limits for the head and hands. The configured limits are provisional.
- Codex ran the scoped tests and built a release app for the connected phone; the user reported completing a test. Specific manual-test outcomes and time savings were not provided. No human manual source-code fixes were reported.
- Independent review and full interaction-history export remain TODO. Online battle uses a separate setup flow and is not included.

- A full-suite run exposed diagnostic demo tests depending on manual setup. Codex preserved the existing diagnostic behavior and reran those suites; no human source edit was claimed.

## S3 follow-up — squat silhouette (2026-11-15)
- Codex adapted the standalone recorder's standing guide and landmark-region matcher to the common setup, bot battle and online preparation paths. The user confirmed owner/PM agreement for the battle files and their associated tests. No new pose model was trained.
- An independent read-only Codex review found stale-frame reuse after bot detector errors, stale online readiness across reconnects, and a missing design token. Codex fixed these and added regression tests. The follow-up review approved the changes. Human manual source edits and time savings were not reported.
- The recorded input for this PR is in the prompt log. Earlier standalone-recorder work is summarized in the local progress record; its complete conversation export has not been reviewed for publication.
- The alignment regions are provisional; real-person calibration and real-phone auto-start validation were not performed. Clasping the hands is shown as guidance but is not checked.

## S3 follow-up — main merge (2026-11-15)
- Codex merged the current main into the squat silhouette branch, resolved the theme token conflict by preserving both owners' values, and reran the analyzer and full app tests. The local staged-file guard was corrected to compare a main merge's result with its incoming main parent; it still checks every change the branch introduces relative to main, including conflict resolutions. It is a local harness change and is not committed.
- The user had earlier confirmed owner/PM agreement for the battle integration. A direct confirmation from Woohyun in the PR is not evidenced by the review records available at this point.

## S1 limited initial-hold change (2026-11-15)
- Codex evaluated isolated push-up timing and pose thresholds, added synthetic 30 Hz tests and shortened the initial hold from 300 to 250 ms. The 172-degree lockout and the belly boundary remain unchanged because experimental relaxations produced an incorrect count or reason regressions.
- An independent read-only Codex review found that the original change also cleared the knee latch early when hips were hidden. Codex added a reproducing test and retained the 300 ms minimum for latch release; the reviewer approved the corrected limited scope. Detailed commands and results are in the personal testing notes. No manual source-code fixes or real-device UAT were reported.
- The user asked for S1 before the next build; the full S1 lockout-margin and recorded-video accuracy goals remain incomplete. These prompts are recorded as visible task inputs, not a complete session export.
