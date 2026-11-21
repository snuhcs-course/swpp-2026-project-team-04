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

## S4 follow-up — #59 and common squat judging (2026-11-14)
- Tool: Codex. Base: main eb336c3, including J4 #57. Codex reproduced the missing per-frame depth and added regression tests before the fix.
- The user chose to unify production AI/online squats through SquatRepJudge and confirmed owner/PM agreement for the bot factory and its existing test file. The prior demo type had also bypassed phone-movement rejection; using the normal factory removes that production bypass.
- Codex supplied current depth and valid-side hip/knee coordinates, retained the legacy diagnostic judge's API, and verified 4 full + 2 shallow repetitions through real counter wiring, report serialization and the analyzer using fakes.
- Verification: 92 targeted tests passed; Flutter analysis clean. Independent read-only Codex review found no actionable defects and approved this implementation scope. Full-suite results are in the personal testing notes. No physical-phone UAT or broad squat-accuracy result is claimed.
- A coverage command initially referenced a nonexistent squat_error_cases_test.dart; the actual three service suites were rerun successfully. This was an agent command error, not a human manual fix. No human source edits or measured time savings were reported.
- The issue handoff, actual decision replies and commit/push request for this task are recorded verbatim in the prompt log, reviewed for credentials and unrelated personal data before staging. Full-iteration session export and team-wide interaction-history review remain TODO; no assistant transcript or tool output is included.

### S4 #59 current-main integration (2026-11-15)
- On the user's request to handle the open issues, Codex merged current main into the existing #59 branch and verified the combined app suite. An independent reviewer approved the integration against that baseline and identified future conflicts with pending #65; those need resolution and re-verification after #65 is merged. No human source-code edits or real-person testing were reported.

## S4 #59 merge after #65 (2026-11-15)
- Codex merged main `95b6d97`, preserved both personal-note histories and updated the battle test for fresh setup frames and the shared judge. The user requested the conflict resolution and removal of Draft status.
- The four scoped test suites, full Flutter suite and analyzer passed; details are in the personal testing notes. Independent read-only Codex review approved the resolution. No human manual code fix or device UAT was reported.

## S3 UAT phone angle (2026-11-16)
- Codex added an explicitly enabled UAT-only gravity angle chip for the common preparation and bot/online battle setup camera. Ordinary builds do not start the extra display or sensor subscription.
- Independent read-only Codex review found initial overlaps with the setup panel and the battle leave button. Codex moved the display into visible camera/setup space and added geometry and sensor-lifecycle tests; the reviewer approved the corrected implementation. Local test evidence is in the personal testing notes. No human manual source fixes or real-device UAT were reported.

## S1 limited initial-hold change (2026-11-15)
- Codex evaluated isolated push-up timing and pose thresholds, added synthetic 30 Hz tests and shortened the initial hold from 300 to 250 ms. The 172-degree lockout and the belly boundary remain unchanged because experimental relaxations produced an incorrect count or reason regressions.
- An independent read-only Codex review found that the original change also cleared the knee latch early when hips were hidden. Codex added a reproducing test and retained the 300 ms minimum for latch release; the reviewer approved the corrected limited scope. Detailed commands and results are in the personal testing notes. No manual source-code fixes or real-device UAT were reported.
- The user asked for S1 before the next build; the full S1 lockout-margin and recorded-video accuracy goals remain incomplete. These prompts are recorded as visible task inputs, not a complete session export.

## S1 push-up algorithm integration (2026-11-16)
- At the user's request, Codex prepared an isolated snapshot of the S1 work from the other project chat for the existing PR, leaving that chat's worktree untouched. The default pose-geometry changes, opt-in MLP/knee experiments and contact diagnostic retain their separate modes; the research reports describe their measured tradeoffs.
- The earlier video validation used sampled proposed labels rather than independently adjudicated ground truth; physical exercise accuracy and multi-person tracking are not established. The user previously reported the experimental knee classifier performed worse on their phone. See the testing notes and the individual benchmark reports for exact runs and limitations.

- A read-only Codex reviewer reproduced an insufficient-lockout promotion in the S1 snapshot. Codex added a test and corrected promotion to respect the configured lockout; the reviewer confirmed that correction and identified the separate custom-injected tilt-monitor limitation, which is disclosed for review. No physical-user test or manual human source edit was reported for this integration. Final test evidence and the failed coverage collection are in the testing notes.

## S1 follow-up — mobile pose comparison and knee forest (2026-11-16)

- Codex compared ML Kit Accurate/Base and RTMPose-s/m using fixed source-group splits, then exported the selected depth-four forest into the local opt-in push-up judge. The comparison used 2,706 presegmented normal/knee intervals labelled by earlier Codex visual review. The testing notes and pushup-mobile-pose-comparison.md retain exact counts, provenance and limitations.
- The user stopped the Sapiens2-5B investigation to prioritize low-latency phone execution, requested installation, and selected the new comparison build after the agent disclosed worse results on 32 recorded-phone sequences. The input prompts below document these decisions.
- Codex automated same-frame inference, grouped evaluation, Python/Dart parity and Android installation. All 2,706 exported classifier decisions matched. Time savings were not measured.
- Independent read-only Codex review found a microsecond truncation error in live attempt boundaries and a shared Android metadata label that incorrectly described ML Kit preprocessing. Codex corrected both. Native replay exposed weaker live-counter results despite the favorable presegmented benchmark. The report retains this contrary evidence.
- The first recommendation based on clip-level scores required revision after live-counter replay. The user chose a comparison build with the known regression and requested a phone trial.
- Human manual source-code edits were not reported. Codex performed the implementation and fixes. The user authorized publication in the existing S1 PR. The selected prompt record is incomplete as a full iteration-wide session export.

### PR integration and review readiness, 2026-11-16

The user requested updating the existing S1 and S2 PRs and releasing their Draft status. Codex committed the five-phase forest work as 89403cb and merged the current remote S1 branch into it as c940d09. The resulting tree includes main fe1aad1 and the remote 327a9ff lockout correction. Conflict resolution preserved both personal-note histories and the new forest tests. An independent read-only Codex reviewer checked the resolved source and found no actionable implementation defects. The default counter's lockout guard and the opt-in model decision path are described separately in the comparison report.

The local staged-file guard was corrected to compare a merge result with main when the incoming branch already contains that main revision. Its path ownership map was preserved. This local harness change is excluded from the commit. Verified test results are recorded in the personal testing notes. Model accuracy limitations and pending real-person validation remain explicitly documented for reviewers.

## S2 experimental continuity warning, 2026-11-16
- At the user's request, Codex prepared S2 separately before S1 merged; the user confirmed owner/PM agreement for the affected battle and counter files. ML Kit poses do not provide person identity, so the default-off continuity warning is explicitly a prototype rather than a completed identity guarantee.
- Independent read-only Codex review identified retry, stream-stall, setup transition, geometry validation, and stale online-publication risks. Codex corrected these cases and added regressions. The physical two-person scenario and the threshold need independent labels and device UAT. No human manual code fix was reported. User prompts in the personal log are limited to this visible task and consent; the complete iteration transcript remains TODO.

### S2 review-ready publication, 2026-11-16

- The user requested completion of the existing S1/S2 pull requests and removal of Draft status. Codex verified S2's current main ancestry, reran analysis and seven focused suites, and refreshed the English PR description and personal evidence. The exact request is recorded in the prompt log.
- Serial coverage collection succeeded after the earlier VM-service failure. All 258 selected tests passed, and each changed file exceeded its layer target. The personal testing notes contain the counts and reproducible command.
- Independent read-only Codex review found no actionable defects in the current opt-in prototype. Its review covered confirmation freshness, lifecycle/retry behavior, setup handoff and withheld online pose publication. Physical identity-retention efficacy and full-suite validation with the feature globally enabled remain open.
- This publication pass changed documentation. Human manual source edits and measured time savings were not reported. The full-iteration transcript and team-wide interaction-history review remain pending.

### S2 integration after S1 PR #69, 2026-11-16

Codex integrated main `d188240` after the PM merged S1, preserving both branches' personal notes and prompt history. Source files merged automatically. Independent read-only review checked the S1 forest-history interaction with S2 abandonment and reset, and found no actionable integration defect. The resolved tree passed application analysis, 3,329 ordinary-build tests with 10 existing skips, and 258 focused tests with changed-file coverage above target.

An initial analysis command ran from the repository root and reported package-import errors in standalone diagnostic scripts. Codex corrected the working directory to `gymrats_app` and reran analysis successfully. Human manual source changes were not reported. The opt-in prototype's physical identity-retention limitations remain documented.

### S2 enabled-build failures and real-video replay (2026-11-17, PR #72)

Sangwoo asked Codex to reproduce the failures with `S2_PERSON_GUARD` enabled and verify what happens when someone moves behind the player. The current baseline had 14 failures. The earlier figure of 47 came from an older scoped run. Sangwoo confirmed owner or PM approval for the sound test’s camera input change. Codex supplied continuous camera frames in the affected tests and preserved the original sound assertions. No human manual source edit was reported. The dated inputs appear in the [prompt log](Sangwoo-Hahn-Prompt-Log.md).

Codex replayed native Android ML Kit landmarks from nine videos through the app’s repetition counter. In O027 a separate Codex visual review identified 256 frames where ML Kit selected the background person. The guard withheld all 256 and suppressed seven invalid judgments. In the multi-person squat clip the counter accepted the same three repetitions at the same timestamps in both configurations. The fixture and observations are documented in the [video findings](../../iteration-4/person-behind-findings.md).

A single-person control exposed an error in the original guard. A one-frame collapse in estimated shoulder width kept the game paused until confirmation. Codex added a regression test and changed the guard to withhold that frame while preserving the last reliable pose. The blurred control O033 still triggers a pause. Phone testing with two people and independent human labels remain outstanding. Both full app configurations passed 3,342 tests with ten existing skips each. A separate Codex reviewer checked the implementation and evidence. The [testing record](../../testing/iteration-4/Sangwoo-Hahn.md) includes the coverage collection retries and results.


### Per-frame knee observations and endpoint sequence (2026-11-18)

The user requested three knee states for each pose frame and then specified a completed-repetition sequence with touching before and after the push-up. Codex ported the previously fitted 48-feature, 32-tree single-frame model, added observable/occluded gates and temporal preparation evidence, and connected the reading to every RepJudge snapshot. The rule captures stable touching preparation before descent, allows occluded middle frames and requires a touching result on the actual closing frame. The preparation uses three samples spanning100ms with at most500ms age. The return uses one current result to preserve repetition timing. Reset and S2 abandonment clear sequence state.

The initial phone build included the observer with its veto disabled. The user clarified the desired sequence and explicitly requested enabling rejection. Three endpoint regressions reproduced false vetoes in the earlier any-touch evidence, and Codex replaced that latch with endpoint matching. An independent read-only Codex review approved the sequence. The S2+frame-knee combined trial passed434 scoped tests and was installed as an ARM64 release with both options enabled. Visible home startup and installed/local APK identity were verified. No human manual source edits were reported. These actions are linked in the [testing notes](../../testing/iteration-4/Sangwoo-Hahn.md) and [prompt log](Sangwoo-Hahn-Prompt-Log.md).

The user subsequently authorized immediate non-draft publication and confirmed all agreements. The follow-up starts from main e0bcae2 after S1#69 and S2#72 merged. It enables the endpoint veto by default with an explicit false opt-out. The model uses earlier weak clip-derived labels. Published per-frame evaluation includes unavailable frames and misses, and no completed-repetition generalization rate is claimed. The [model and sequence note](../../iteration-4/pushup-frame-knee.md) preserves the measured limits. Physical knee-contact accuracy remains a phone trial.


### PR #75 retained knee mode and evaluation (2026-11-18)

The user clarified that one or two lifted observations should retain confirmed touching. Codex changed confirmation to three consecutive distinct frames in either direction, removed the100msminimum, and retained the confirmed mode through occlusion. Three confirmed lifted frames prevent old touching from returning after occlusion. Raw snapshot readings remain per-frame observations. Reset, abandonment, image changes and missing camera delivery clear the mode. The closing repetition uses the confirmed mode, including an occluded closing frame. The user authorized updating PR75 and committing/pushing.

Three new regressions failed against the previous implementation and passed after the change. Additional boundary and interruption tests passed. A separate read-only Codex reviewer approved the retained-mode contract and measurement formulas. Main9841a60 and the unchanged frozen set/scorer were replayed independently. Enabled M1 falls from50/63 to49/63, while M2=188/207 and M3=124/207 remain unchanged. Disabled mode matches main. Historical incorrect acceptances decrease3to1, explicit rejections increase56to58, and historical normal acceptance remains28/35. These reused in-sample results and the extra normal rejection are disclosed for review. No human manual source changes were reported. The [testing record](../../testing/iteration-4/Sangwoo-Hahn.md) and [input log](Sangwoo-Hahn-Prompt-Log.md) contain the evidence.


### Unified knee policy and supplemental coordinate evaluation, 2026-11-18

Following the user's full knee-judge audit request, Codex unified the primary,
short-cycle, calibration, span and optional MLP knee decisions around one
completed-attempt evidence predicate. The twelve-joint confidence gate,
frontal bent-arm abstention and bilateral gray-band corroboration were developed
using the inspected Hyunwoo clips. The existing forest weights were preserved.
An independent read-only Codex reviewer approved that implementation and its
single-participant development evidence. No human manual source fix was reported.

The user subsequently authorized publication on existing PR #75 and forwarded
the PM's coordinate-only evaluation requirements. The user explicitly selected
Hyunwoo8 + Sangwoo8, overriding the participant names in the forwarded draft.
Codex reused native push-up/Sangwoo observations and extracted the four remaining
Hyunwoo squat clips on a dedicated local Android emulator. The public addition
contains16 coordinate JSONs/5,325 frames, source hashes, capture metadata and
blank per-person record sheets. No MP4, JPEG or raw camera frame is published.
The frozen cases and scorer are unchanged. New tests replay the actual RepJudge
or SquatRepJudge and preserve the original M1/M2/M3 alignment semantics.

The user confirmed that chair use itself is permitted when squat depth and full
standing are satisfied. Both chair cases therefore use range_only. Actual
counts/per-rep labels remain pending recorder/PM confirmation; filename intent,
prior visual cycle estimates and app predictions do not become ground truth.
New-set metrics are N/A until that confirmation. The knee rule default is false
because a new-set benefit is not established. Fixed-set OFF scores are
50/63 M1,188/207 M2,124/207 M3; unified ON scores are51/63,181/207,131/207.
The M2 regression is disclosed and not offset by a fabricated new-set score.

The initial full run with the former default ON reproduced seven pinned legacy
snapshot failures. The PM's conservative-default instruction restores OFF;
those assertions and labels were not weakened. Two initial new parser-test
failures came from over-narrow inferred types in synthetic mutable maps and
were corrected without changing production outcomes. Both new evaluation
configurations then passed13 tests. Final analysis/full-suite/publication
checks are recorded in the personal testing note. No server deployment or
new phone installation is part of this publication. Complete-iteration input
export and human per-rep annotation remain TODO(Sangwoo/recorders/PM).


Installed Session Exporter help confirms Codex support. Its local dry-run for
2026-11-18 in this chat's supplied worktree returned no eligible sessions.
The safe fallback is the reviewed selected visible user inputs in the personal
prompt log; no empty export or complete-transcript review is claimed.


After main0a17580 was merged, analysis and all3,751 default-build tests passed
with10 existing skips. Additional S2+unified-ON checks yielded164 passes and one
new main goal-camera-retry test failure. Codex independently reproduced that
single failure in untouched main0a17580 with S2 enabled. It is disclosed as an
inherited optional-configuration test failure; unrelated mission assertions
were preserved. The independent read-only reviewer approved the final code,
data and ON/OFF report consistency before publication.


### Combined MLP and both knee layers — 2026-11-21/22

1. **Use:** Codex implemented an additive knee-policy switch, replayed the unchanged recorded poses, grouped the requested four categories and wired the user-selected policy into the common battle factory. Models and weights were not retrained; no camera data was sent to an external service.
2. **Inputs:** The three selected original user requests are in the personal prompt log. They first prohibited publication, then explicitly authorized a PR and merge after clean checks. This selected record does not claim a complete iteration export.
3. **Useful output:** The event-by-event check preserves all479 proposal counts/timestamps and prior rejections, allowing only25 accepted-to-knee rejections. The combined table distinguishes category recall, misses and unmatched accepted events.
4. **Errors and corrections:** The earlier replacement mode removed old protections; the additive mode preserves them. A regression failed before the fix. A separate production-factory regression exposed that the comparison option was not yet active in normal battles; Codex added explicit battle wiring. A shell test command initially split a multiword filter into an extra filename; the correctly invoked221-test run passed. No model/tool timing savings were measured.
5. **Prompt revision:** The user changed the requested experiment from replacing the knee specialist to retaining both layers, and then explicitly chose publication after the results showed both benefits and costs. The additive comparison improves knee recall76/79 to78/79 but reduces normal recall69/73 to65/73.
6. **Manual fixes:** No human source-code edits were reported. Codex made the code and test corrections; an independent read-only Codex reviewer inspected the actual changes and comparison artifacts. Publication-wide results and CI are recorded in the testing notes.

No original video or raw image is included. Recent labels remain provisional protocol/visual references. Frozen targets are not claimed achieved. The selected policy is a user-approved trade-off, not a claim of unseen-person or live-phone accuracy.

The installed Session Exporter supports Codex. Dry runs for2026-11-21 through2026-11-22 returned zero eligible sessions for both the active worktree and this chat's supplied worktree. The latter reported ambiguous working-directory moves and session metadata exclusions. No ZIP or complete transcript review is claimed. The reviewed fallback is the three verbatim visible user inputs for this task.

Publication-wide validation finished: full analysis clean,3768 tests passed with10 existing skips,236 scoped tests passed, and all three four-test configuration-override runs passed. The selected production-factory replay exactly matches all44 prior case outputs. The first full run's3 S2 legacy-golden failures are retained in the local evidence; original7/13/empty assertions remain on the old judge, and five production-policy scenarios now verify pause, wrong-person suppression and confirmation/resumption. The O033 pre-pause accepted candidate is disclosed in the evaluation note.

## S3 follow-up — 2026-11-22 battle setup alignment

- **Context and tools.** Codex continued the common setup change into the live AI and online modes. Sangwoo set the exercise-specific requirements and confirmed Song Woohyun's approval for the battle camera and setup changes.
- **Inputs.** The prompt log records the two selected visible user inputs for this follow-up. Codex inspected the setup checker, crop layout, live controllers, and original tests before connecting the shared matcher.
- **Implementation and supervision.** Codex used the painted outline and the stable setup clipping area to gate the existing bout flow, moved online readiness completion to a fresh sample, and used the detector-failure event only for setup. Existing server scheduling and exercise rep judges retain their contracts.
- **Review and correction.** An independent Codex reviewer identified cropped-off landmarks, single detector failures, and the cue during online withdrawal as edge cases. Codex corrected those cases and added regression coverage. The reviewer returned APPROVE after checking the updated paths and ownership.
- **Human contribution.** Human participation in this follow-up consisted of scope selection, publication authorization, and confirmation of the file owner's agreement. Codex authored the code and test revisions.
- **Verification.** The personal testing note records the Flutter checks and open device UAT scenarios.
