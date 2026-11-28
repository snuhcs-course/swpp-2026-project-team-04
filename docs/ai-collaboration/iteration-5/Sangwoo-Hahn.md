# Iteration 5 AI collaboration · Sangwoo-Hahn

## 2026-11-23 · UAT push-up scoring

- Goal. Apply the PM-approved depth and knee scoring rules and clear stale rejection feedback.
- Tool. Codex traced a UAT scoring discrepancy through the pose judge, game rules, client preview and WebSocket server.
- Implementation. Codex changed attempt measurements, depth grading, fixed knee scoring, capability negotiation, feedback and tutorial copy.
- Review. An independent Codex review identified shallow knee-contact precedence and outdated tutorial guidance. Codex revised both. The final review verdict is recorded on the PR.
- Verification. Local Flutter regressions include authoritative server scoring in fever and client feedback. See the personal testing record.
- Human input. The PM selected the scoring policy and confirmed agreement for shared-file changes. No manual source edits were reported.

### 2026-11-24 · Knee push-up scoring follow-up

Codex updated the shared knee-rep points rule, tutorial copy and regression tests. The PM specified zero points. No manual code edits were reported.

### P9 review follow-up · 2026-11-24
Codex implemented and tested bounded transaction retries for SQLite contention in the friend request endpoint at the PM's request. No manual edits reported.

Independent Codex review identified a remaining SQLite lock-upgrade race and malformed request handling. Codex updated the implementation and regression tests before re-review.

### 2026-11-27 · P10 protocol handoff
Codex compared the wire contract in PR #102 with the PM handoff and documented the optional flag and the virtual assignment. Inspecting the validator clarified that a valid friend request can explicitly set the flag to false. No manual edits were reported.

### 2026-11-27 · Revised P10 protocol handoff
Codex traced the server-managed match and updated the protocol handoff in #103 against #102 at `71fcdc3`. The flag belongs to the internal result payload. The client follows the standard online match flow.

### 2026-11-27 · P10 protocol merge check
Codex reconciled the protocol with merged P10. The real client supplies its avatar ID, while the battle server selects the simulated player's character.

### 2026-11-28 · P11 weekly rankings follow-up
Codex implemented the three PM follow-ups from #108. An independent read-only Codex reviewer checked the four implementation and test files against `375a9b7`, verified migration reversibility and returned APPROVE with no findings. No human code edits were reported.

### 2026-11-28 · P20 battle socket follow-up
Codex implemented the shared WebSocket send guard and two regression tests for the P20 follow-up. The first test run exposed an incorrect assertion on the final result payload. Codex corrected it to check players and reran the three affected suites. An independent read-only Codex reviewer checked the two changed code and test files against 5e607fb and returned APPROVE with no findings. No human code edits were reported.

### 2026-11-28 · P18 pose evaluation
Codex implemented the landmark replay, applied the published battle scoring rules and compared the results against existing human labels. The report distinguishes measured verdicts and points from the reference score ranges and records the model/data limitations. The team’s recordings and confirmed labels supplied the reference. No new human code edits were reported.

### 2026-11-28 · A1 follow-up · knee feedback in battle

Codex traced the zero-point Average to the shared grader and verified the correction through the online battle screen, server integration and recorded pose replays. The PM specified the exact Korean cue and unlocked the Android test device. Independent Codex review caught stale demo expectations, readability at distance and an order-dependent assertion in the two-client test. Codex applied the fixes. No manual code edits were reported.

The PM clarified the final screen copy to show MISS and +0 alongside the knee correction. Codex revised the player banner, screen regression and motion expectations.
