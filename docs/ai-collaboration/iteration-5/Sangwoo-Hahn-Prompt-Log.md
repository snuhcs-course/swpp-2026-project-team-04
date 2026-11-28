# Iteration 5 prompt log · Sangwoo-Hahn

## 2026-11-23 · UAT push-up scoring

- 지금 푸쉬업 기각되면 +5 Average 뜨던게 없어진 문제 왜 발생했는지 알려줘.
- 그럼 이 문제를 해결하기 위한 방법 제시해줘.
- 깊이에 따라 다르게 점수를 주면 좋겠어. 무릎은 +5로 고정하는건 어때?
- 지금 Good에서도 화면에 기각 사유가 나와?
- 그럼 이 형태로 알고리즘 수정해서 PR 올리고 머지까지 해줘.
- 어.

### 2026-11-24

무릎대고 푸쉬업하면 +5점 주던거 +0점으로 바꿔줘. PR 머지까지 진행해줘.

### 2026-11-24 · P9 follow-up
그럼 지금 문제 해결해서 브랜치 수정 및 커밋과 푸쉬할 수 있어?

코덱스 리뷰 및 머지 요청 원문: codex 리뷰 후 머지까지 해줘

### 2026-11-27 · P10 protocol handoff (excerpt)
넘기는 일: docs/iteration-2-protocol.md에 새 메시지를 추가해 줘. 내 범위 밖 파일이야.

### 2026-11-27 · Revised P10 protocol handoff
docs/iteration-2-protocol.md에 accept_virtual과 결과의 simulated 선수 추가 부탁해.

### 2026-11-27 · P10 protocol merge check
P10 머지됐으니까 후속 프로토콜 문서 PR #103도 확인하고 문제없으면 Sangwoo-Hahn으로 머지해줘.

### 2026-11-28 · P11 weekly rankings follow-up
P11에서 내 후속으로 남긴 Match.played_at 인덱스 추가, 디자인 토큰 검사에 랭킹 화면 등록, 랭킹 라우트 테스트 추가까지 한 PR로 처리하고 Codex 리뷰랑 CI 통과하면 머지해줘.

### 2026-11-28 · P20 battle socket follow-up
P20에서 내 후속으로 남긴 대전 서버의 닫힌 소켓 예외도 지금 고쳐줘. 한 명의 연결이 끊겨도 다른 경기는 계속되는지 테스트하고, PR 올려서 Codex 리뷰랑 CI 통과하면 머지해줘.

### 2026-11-28 · P18 pose evaluation
그럼 이제 내가 맡은 P18 푸시업·스쿼트 판정 테스트 진행해줘. 최신 main 기준으로 기대 판정이랑 실제 횟수·점수·기각 사유를 비교해서 기록하고, PR 올려서 Codex 리뷰랑 CI 통과하면 머지해줘.

### 2026-11-28 · A1 follow-up · knee feedback in battle

그럼 무릎 대고 한 푸시업은 점수랑 횟수 안 올라가고, +0 AVERAGE 대신 ‘무릎을 바닥에서 떼요’만 뜨게 고쳐줘. 실제 대전 화면까지 테스트하고 PR 올려서 Codex 리뷰랑 CI 통과하면 머지해줘.

추가로 더 해야하는데 아직 안되어 있는 것들 있어?

- “MISS로는 떠야해.”
- “+0이랑.”
- “튜토리얼 화면은 바뀔 필요 없어.”
