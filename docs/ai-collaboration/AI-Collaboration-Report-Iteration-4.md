# AI Collaboration Report: Iteration 4 (2026-11-07 ~ 2026-11-20)

- **Written by:** Hyunwoo Song (PM)
- **Contributors:** Woohyun Song, Jinyoung Park, Sangwoo Hahn, Hyunwoo Song
- **Tools used:** Claude Code (Opus 5.5; Jinyoung also Fable 5.1) with the repo's `reviewer` subagent; Claude Design (Woohyun's canvas); Codex and read-only Codex reviewers (Sangwoo); Claude CLI (Sangwoo, silhouette designs); the Codex PR review bot; for the PM, Claude Code with the Google Sheets connector and claude.ai artifacts
- **Full input prompts:** [Prompt Logs](iteration-4/) (wiki sub-page "Prompt Log"); members' notes: `docs/ai-collaboration/iteration-4/` Sangwoo's log holds the prompts he selected; the review of his full session export is still open (his notes in `docs/ai-collaboration/iteration-4/`).

## 1. Where AI Was Used
- **Lobby, battle stage, characters, report, archive, feedback, victory scene, setup cues** (Woohyun, Claude Code from his Claude Design canvas): #45, #50, #52, #54, #55, #61–#63, #68, #70, #73, #74, #76, #77.
- **Voice, battle music, cumulative statistics, squat feedback, tutorial** (Jinyoung, Claude Code): `lib/services/audio/`, `MatchStatsView` (`server/matches/views.py`); #48, #53, #56, #57, #60, #64.
- **Silhouettes, squat and push-up judges, person warning** (Sangwoo, Codex): `pose_silhouette_guide.dart`, `rep_judge.dart`, `pose_metrics.dart`; #49, #51, #65–#67, #69, #71, #72, #75.
- **PM** (Hyunwoo, Claude Code; no app code): trial merges before the 30 merges (#45–#77), sheets, wiki, frozen-set runs (`9841a60`, `7680df6`).
- **Not used:** screen designs, sound picks, tutorial content, statistics definitions, phone checks, approvals.

## 2. Prompt History
- [Woohyun Song, 11-13] "(c) 새 앱이 지금 배포된 옛 서버에 새 필드를 보내면 거절당한다. 이걸 어떻게 피할지[…] 코드를 쓰기 전에 방법을 제안해."
- [Jinyoung Park, 11-12] "세팅할떄만 voice 놓고 게임도중에는 voice를 빼고 대신 점수에 따라나 실패 할떄 효과음을 넣는 식으로 하자. […] 시안을 몇개 뽑아줘."
- [Sangwoo Hahn, 11-17] "그럼 S2 기능을 켠 상태에서 실패하는 테스트를 해결하고, 실제 영상으로 검증해서 마무리해줘."
- [Hyunwoo Song, 11-18] "자 지금 pr 어디까지 올라와있고 어디까지 머지돼있으며 업데이트할 문서들이나 시트 등등은 무엇이지?"

## 3. What AI Did Well
- **Tests that fail on the old code** (Woohyun): `LobbyFillColumn` (`lobby_parts.dart` L127 at `38c44b1`) came with tests that failed on the old layout; in W4 all 13 planted faults were caught.
- **Evidence before a fix** (Jinyoung): the screen recording showed the "missing Average sound" was a rep never graded Average; an `rsync -n` dry run listed the four files to redeploy.
- **Real-data replay** (Sangwoo, #72): in O027 all 256 frames where ML Kit followed the background person were withheld.
- **Second AI reviewer:** the Codex bot found what our reviewer missed: three findings on #48, three P2 gaps on #53 and on #57, a read race on #52.

## 4. Hallucinations / Errors
- **Cause without evidence** (Jinyoung, 11-14): the agent called the Average hit "lost under the music" and made it the loudest effect; the recording disproved it. Cost: two rebuilds, ~20 min.
- **Race missed by six review runs** (Woohyun, #52): confirming a character while the saved one loaded overwrote it with `mouse`. Codex caught it; fixed in `1f7e6f5`.
- **Benchmark that did not transfer** (Sangwoo, S1): the knee forest won on clips, but the live-counter replay of 32 recordings dropped normal recognition from 60/63 to 55/63; the recommendation was revised.
- **Wrong reviewer claim** (Jinyoung, #57): Codex said `ResultState.copyWith` drops the rematch; no such parameter exists, so only a test was added.
- **Sheet writes without a fresh read** (PM): the agent overwrote the team's meeting edits (11-11, restored 11-12) and wrote four cells one row off (11-18, caught by re-reading).

## 5. Prompt Revisions
- Jinyoung (11-14): "그건 들림 Average를 조금더 키워야 할듯 […]" → "효과음중 가장 크면 안되지 그러면 차이가 없자나". Naming the order (Excellent > Good > Average) set it just under Good.
- Woohyun (11-13): the 03:25 prompt (map characters onto avatar ids) was resent at 03:28 ending with the item 2 request; asking before code surfaced option A, which needed no new field.
- Sangwoo (11-07 ~ 11-12): "더 간단한 실루엣으로 하는게 좋을 것 같아. […]" → "아니 전체 경계선을 만들고 그 경계선 내부만 투명하고 나머지 바깥쪽은 검은색을 반투명하게 깔아서 […]". One clear interior replaced the separate markers.

## 6. Manual Fixes and Why
- No member reports a hand edit of AI-generated code; no manual-fix marker is on main (`git grep "manually fixed by"`).
- By hand: the "Not used" work, merge decisions, the in-class UAT. Limit: Sangwoo's video labels came from Codex, not people.

## 7. Takeaway for Iteration 5
- Measure judge changes on the live-counter replay, not only on clip benchmarks.
- Before review, list slow reads, exit paths and boundary values: the gaps Codex found.
