# AI Collaboration Report — Iteration 4: S3

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
