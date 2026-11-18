# AI Collaboration Report: Iteration 4 (2026-11-07 ~ 2026-11-20)

- **Status:** draft (iteration open)
- **Written by:** Hyunwoo Song (PM)
- **Contributors:** Woohyun Song, Jinyoung Park, Sangwoo Hahn, Hyunwoo Song
- **Tools used:** Claude Code (Opus 5.5; Jinyoung also Fable 5.1) with the repo's `reviewer` subagent; Claude Design (Woohyun's canvas); Codex and read-only Codex reviewers (Sangwoo); Claude CLI, Opus 5.5 (Sangwoo, silhouette designs); the Codex PR review bot; for the PM, Claude Code (Opus 5.5) with the Google Sheets connector and claude.ai artifacts.
- **Full input prompts:** the members' Prompt Logs and notes in `docs/ai-collaboration/iteration-4/`.

## 1. Where AI Was Used
- **Home lobby, battle stage, characters, report, archive, form feedback, victory scene, setup cues, coach talk** (Woohyun, Claude Code porting his Claude Design canvas): #45, #50, #52, #54, #55, #61–#63, #68, #70, #73, #74, #76, #77; e.g. W1 `57ca64f`…`38c44b1`, 19 `lib/` files.
- **Voice guidance, battle music, cumulative statistics (app and `MatchStatsView`), squat feedback, tutorial** (Jinyoung, Claude Code): `lib/services/audio/`, `server/matches/views.py`; #48, #53, #56, #57, #60, #64.
- **Setup silhouettes, shared squat judge, push-up judge S1, person warning S2, UAT phone angle** (Sangwoo, Codex): `pose_silhouette_guide.dart`, `rep_judge.dart`, `pose_metrics.dart`; #49, #51, #65–#67, #69, #71, #72, #75.
- **PM work** (Hyunwoo, Claude Code; no app code): ownership checks, trial merges and CI reads before each of the 30 merges (#45–#77, all merged by `hyun-1210`), the schedule sheet, the merge-order page, member harness packages, UAT sheets (cycle 2: 28 steps), wiki updates (e.g. `dabda92`, `85c1443`), the TA deck, frozen-set runs (`9841a60`, `7680df6`). Notes: `iteration-4/hyun-1210.md`.
- **Not used:** screen designs (Woohyun), sound picks by ear (Jinyoung and the team), tutorial content and statistics definitions (team chat, Woohyun's data list), phone checks, owner approvals for file exceptions.

## 2. Prompt History (one per member; all in the Prompt Logs)
- [Woohyun Song, 11-13] "(c) 새 앱이 지금 배포된 옛 서버에 새 필드를 보내면 거절당한다. 이걸 어떻게 피할지(예: 서버를 먼저 배포하는 순서, 거절되면 필드 없이 다시 보내기 등) 코드를 쓰기 전에 방법을 제안해."
- [Jinyoung Park, 11-12] "세팅할떄만 voice 놓고 게임도중에는 voice를 빼고 대신 점수에 따라나 실패 할떄 효과음을 넣는 식으로 하자. 때리는 효과음으로 하고, 죽기 직전이면 경고음 효과음을 넣을건데 시안을 몇개 뽑아줘. 브금도 포함해서"
- [Sangwoo Hahn, 11-17] "그럼 S2 기능을 켠 상태에서 실패하는 테스트를 해결하고, 실제 영상으로 검증해서 마무리해줘."
- [Hyunwoo Song, 11-18] "자 지금 pr 어디까지 올라와있고 어디까지 머지돼있으며 업데이트할 문서들이나 시트 등등은 무엇이지?"

## 3. What AI Did Well
- **Tests that fail on the old code** (Woohyun): the agent measured why the suggested `SliverFillRemaining` would still scroll, then wrote `LobbyFillColumn` (`lobby_parts.dart` L127–). Its fit tests failed on the old layout and passed on `38c44b1`. In W4 all 13 planted faults were caught.
- **Evidence before a fix** (Jinyoung): the screen recording showed that the "missing Average sound" came from a rep never graded Average. A `rsync -n --checksum` dry run listed exactly the four J3 server files before the redeploy.
- **Real-data replay** (Sangwoo, #72): in O027 all 256 frames where ML Kit followed the background person were withheld. A Codex visual review, not people, marked those frames.
- **A second AI reviewer:** the Codex PR bot found what our reviewer rounds passed: three findings on #48 (incl. the Android `TTS_SERVICE` query), three P2 gaps on #53 and on #57, and a read race on #52.

## 4. Hallucinations / Errors
- **Cause asserted without evidence** (Jinyoung, 11-14): the agent called the Average hit "lost under the music" and made it the loudest effect. The recording disproved it. Cost: two rebuilds, ~20 min.
- **Race missed by six review runs** (Woohyun, #52): confirming 캐릭터 선택 while the saved character was loading overwrote it with `mouse`. Codex caught it, and `1f7e6f5` fixed it with tests that fail on the old code.
- **Benchmark that did not transfer** (Sangwoo, S1): the knee forest won on presegmented clips, but on the live-counter replay of 32 phone recordings normal recognition fell from 60/63 to 55/63, so the first recommendation was revised. The reviewer also caught a promoted 168.42° lockout (`327a9ff`).
- **Wrong reviewer claim** (Jinyoung, #57): Codex said `ResultState.copyWith` drops the rematch. It has no such parameter, so a test now pins the behavior and no code changed.
- **Sheet writes without a fresh read** (PM, Google Sheets connector): the agent overwrote the team's in-meeting User Story edits (11-11, restored 11-12 from the earlier version) and, after a teammate inserted a row, wrote four PM cells one row off (11-18; caught by re-reading the range).

## 5. Prompt Revisions
- Jinyoung (11-14): "그건 들림 Average를 조금더 키워야 할듯 그리고 세팅시에 tts 소리는 왜 안나옴?" → "효과음중 가장 크면 안되지 그러면 차이가 없자나". Naming the order (Excellent > Good > Average) set the level just under Good.
- Woohyun (11-13): at 03:25 he asked to keep the protocol and map the characters onto existing avatar ids. At 03:28 he resent it, ending with the item 2 request. The proposal came before code and put the options side by side. Option A needed no new field.
- Sangwoo (11-07 ~ 11-12): "더 간단한 실루엣으로 하는게 좋을 것 같아. […]" → "아니 전체 경계선을 만들고 그 경계선 내부만 투명하고 나머지 바깥쪽은 검은색을 반투명하게 깔아서 사람이 자세를 그 내부에 맞추면 되도록 하게 해줘." One clear interior with a dark outside replaced the separate markers.

## 6. Manual Fixes and Why
- No member reports a hand edit of AI-generated code, and no manual-fix marker exists on main (`git grep "manually fixed by"`).
- The members' own work is listed in item 1 under "Not used". The members also state two limits: Sangwoo's video labels came from Codex, and S2 had no two-person phone UAT.
- PM: no code edits. By hand: every merge decision and its timing, the owners' consents for out-of-step files, the in-class UAT.

## 7. Takeaway for Iteration 5
- Measure judge changes on the live-counter replay, not only on clip benchmarks.
- Before review, list slow reads, exit paths and boundary values. These are the gaps Codex found.
- TODO(hyun-1210): confirm with the team.
