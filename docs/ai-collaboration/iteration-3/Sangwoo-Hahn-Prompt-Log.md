# AI Collaboration Report – Iteration 3 – Prompt Log – Sangwoo Hahn
Input prompts only, quoted verbatim (no agent responses), from the course Session Exporter.

## 2026-10-27 ~ 10-28 · Sangwoo Hahn · tooling setup (no branch)
<!-- 33a91a02 2026-10-27T14:25:20.977Z -->
[Sangwoo Hahn, 10-27 23:25] "이 git 작업공간에 \"C:\SWPP\iter3\gymrats-iter3-harness-sangwoo\" 설치해줘"

<!-- 4c875119 2026-10-28T12:12:34.267Z -->
[Sangwoo Hahn, 10-28 21:12] ".claude/guide.md 읽어"

## 2026-10-28 · Sangwoo Hahn · docs/squat_judge_design
<!-- ff7b3bf2 2026-10-28T12:14:56.241Z -->
[Sangwoo Hahn, 10-28 21:14] "task 수행해"

<!-- ff7b3bf2 2026-10-28T12:48:08.840Z -->
[Sangwoo Hahn, 10-28 21:48] "Notes, commit, push"

## S3 — SOMA sportswear (2026-11-02; prompts visible in this session)
- “SOMA가 운동복 등의 옷을 입은 자연스러운 아바타가 되도록 (여러 옵션 중 선택 가능하게 해줘) Goal을 잡고 github에서 관련 여러 자료를 찾아보면서 작업해줘.”
- “이건 그냥 색칠한 몸이잖아. 옷으로 보이게끔 다시 작업해줘.”
- “서로 겹치지 않게 좀 더 잘 적용해줘.”
- “매우 이상한 자세로 나와.”
- “좋아. 이제 SOMA에 옷입힌 아바타만 남기고 아바타 전부 지워줘.”
- “프로필의 아바타 선택 부분도 적용해줘.”
- “안돼. 배틀 부분에서도 바뀐 아바타가 뜨도록 수정해줘.”
- “좋아. 이제 이대로 PR 올려줘.”

## 2026-11-01 · Sangwoo Hahn · feat/squat_battle

Representative prompts visible in this conversation; a full session export has not been completed.

[Sangwoo Hahn] "일단 두 가지 작업을 병렬로 진행해줘. 푸쉬업과 똑같은 템플릿으로 스쿼트 온라인 1대1 대결(AI아님) 작업해줘.
또한, 카메라에 인식된 내 모습이 게임 모드에 따라 푸쉬업/스쿼트 자세임을 가정하고, 이와 비슷하도록 보정하여 45도 시점에서 보이도록 해줘."

[Sangwoo Hahn] "스쿼트 온라인도 데모가 아니라 지금 온라인 푸쉬업 1대1 대결과 같은 템플릿으로 제작해줘."

[Sangwoo Hahn] "버튼 위치를 푸쉬업 1대1 바로 아래로 해주고, 푸쉬업도 푸쉬업 이름을 붙여줘."
## S3b — Opponent avatar view (2026-11-02; prompt visible in this session)
- “엥 그럼 S3b까지 전부 PR 올려줘.”

## S4 follow-up — Squat demo depth (2026-11-02; visible prompts)
- “스쿼트 AI 대결에서 사람 rep은 Excellent가 안 나와. 폰에서 최대한 깊게 해도 Good만 나왔어. squat_demo_judge.dart가 rep을 보낼 때 깊이를 안 넣어서 그래. 봇은 중수 10%, 고수 20%가 Excellent라서 같은 횟수면 봇이 점수로 앞서. 사람 쪽 기준을 맞추는 게 맞아 보여서, (가) 상우가 SquatDemoJudge rep에 깊이를 넣는 걸 제안해. 급하면 (나) 내가 스쿼트 봇의 Excellent를 0%로 끄는 임시 방법도 있어(W5 파일만 수정). 어느 쪽으로 할지 정해 줘.”
- “그럼 나(한상우)가 작업 시작하면 될 듯해.”
- “커밋과 푸쉬해줘. PR도 수정해야해?”
