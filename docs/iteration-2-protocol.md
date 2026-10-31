# GymRats Iteration 2 통신 프로토콜

상태: v0.1 계약 기반 구현 / 공유 서버 HTTPS·WSS 배포 완료 / 작성일: 2026-10-15 / 갱신일: 2026-10-17

P7~P10의 서버 매칭, Flutter 연결, 상대 자세 동기화, 결과 및 연결 종료 처리를 정의한다. 2026-10-17 공유 서버 `52.78.38.225`의 `/srv/gymrats/battle`에 FIFO 배틀 API를 별도 서비스로 배포하고, 공인 IP 인증서와 nginx를 통해 `wss://52.78.38.225/ws/v1/battle`을 공개했다. 내부 프로세스는 `127.0.0.1:8080`에만 바인딩한다. 현재 구현 범위와 남은 연동은 문서 끝의 실행 안내를 따른다.

## 1. 확정 범위와 확인할 정책

사용자가 확정한 범위:

- 카메라 사진·영상·음성은 전송하지 않는다. 자세 데이터는 관절 식별자, 좌표와 인식값만 전송한다.
- 상대의 실제 관절 좌표로 상대 아바타를 움직인다. 반복 횟수만으로 정해진 애니메이션을 재생하는 방식이 아니다.
- 프로토타입 아바타는 아래 확정된 4종을 제공한다. 설정 화면에서 선택하고, 상대에게 선택된 아바타 종류를 전달한다.
- 자세 외에 매칭·점수·인증·경기 제어 메시지는 별도로 주고받는다.

이 문서에서 제안하는 정책:

| 항목 | 초안 |
|---|---|
| 경기 길이 | AI 대결과 동일한 30초 (서버가 최종 시간 관리) |
| 시작 | 두 사용자 준비 후 서버가 3초 뒤의 공통 시작 시각 지정 |
| 준비 제한 | 매칭 후 60초 이내 준비하지 않으면 경기 취소 |
| 자세 전송 | 최대 10 FPS, 관절 33개 이하 |
| 일시적 통신 끊김 | 10초 재접속 유예, 경기 시간은 계속 진행 |
| 직접 나가기 | 경기 전 취소, 경기 중 기권패 |
| 양쪽 연결 상실·서버 재시작 | 무효, 자동 승자 지정 금지 |
| 아바타 변경 | 경기 밖에서만 적용, 현재 매칭의 아바타는 고정 |

제안값은 구현 전에 PM에게 공유한다. P5·P6 담당자와 인증 토큰 검증 방법을, P11 담당자와 결과 저장 계약을 맞춰야 한다.

## 2. 연결과 인증

- 운영 전송: HTTPS 및 WSS. 개발 서버 IP는 `52.78.38.225`이며 도메인·인증서·최종 접속 URL은 미정이다. IP만으로 안전한 TLS 연결이 이미 구성됐다고 가정하지 않는다.
- 제안 WebSocket 경로: `/ws/v1/battle`.
- Flutter는 연결 시 `Authorization: Bearer <access_token>` 헤더를 보낸다. URL 쿼리에 토큰을 넣지 않는다.
- 인증 구현은 P5·P6 소유다. 사용자 ID는 검증된 토큰에서 서버가 결정하며 클라이언트가 보낸 ID를 신뢰하지 않는다.
- 소켓이 열리기 전 인증 실패는 HTTP 401/403으로 처리한다. 클라이언트는 세션 갱신 또는 로그인을 수행하고 재접속한다.
- 토큰 만료·로그아웃 시 소켓을 종료하고 재인증한다. 연결 중 토큰 갱신 메시지는 v1에 두지 않는다.
- 소켓 연결은 매칭 대기부터 결과 수신까지 유지한다. 클라이언트는 하나의 세션 서비스가 연결을 소유하도록 하며 화면 이동마다 새 연결을 만들지 않는다.
- 서버 비밀값은 `/srv/gymrats/.env`에만 두고 로그·Git에 남기지 않는다. 관절 프레임도 기본적으로 로그나 DB에 저장하지 않는다.

## 3. 공통 형식

모든 메시지는 UTF-8 JSON object다. 필드명은 `snake_case`, `v`는 정수 `1`이다. 숫자는 유한값이어야 하며 NaN·Infinity는 허용하지 않는다.

```json
{
  "v": 1,
  "type": "match.ready",
  "request_id": "client-generated-unique-id",
  "match_id": "server-generated-match-id",
  "payload": {}
}
```

| 필드 | 규칙 |
|---|---|
| `type` | 아래에 정의된 이벤트명 |
| `request_id` | 클라이언트 제어 요청에 필수. 서버 응답·오류가 같은 값을 돌려줌 |
| `match_id` | 매칭 성립 이후 메시지에 필수 |
| `payload` | 이벤트별 데이터 object |
| `server_time_ms` | 서버 메시지에 포함하는 Unix epoch 밀리초 |

`pose.frame`에는 `request_id` 없이 `frame_seq`를 사용한다. 서버는 중계 메시지에 검증된 `player_id`를 직접 추가한다. 미지의 버전·이벤트·잘못된 필드는 명시적 오류로 거절한다. 메시지 크기는 최대 16 KiB, 자세는 초당 10개, 일반 제어 요청은 초당 10개를 제안한다. 과도한 자세 프레임은 폐기하고 반복적 위반은 연결을 종료한다.

제어 요청은 동일한 `request_id`와 동일한 내용으로 재시도하면 같은 처리 결과를 반환한다. 같은 ID에 다른 내용을 보내면 `REQUEST_ID_REUSED`다. 상태를 바꾸는 요청의 ID는 최소 해당 매칭 종료까지 보관한다.

## 4. 아바타 목록과 설정

기존 4종의 식별자는 유지하며, 2026-10-19에 전체 목록을 25종으로 확장했다. 서버와 앱은 같은 허용 목록을 사용한다. 모든 모델은 로컬 GLB와 썸네일로 포함하고, 기존 ML Kit 관절 좌표로 구동한다.

| avatar_id | 설정 표시 이름 | 원본 | 라이선스 기록 |
|---|---|---|---|
| `avatar_01` | 우주비행사 | [Rigged Low Poly Astronaut](https://mrlentereng.itch.io/rigged-low-poly-astronaut) | 제작자 페이지 CC0. 원 제작자 ThunderWare Games, 리깅 MrLentereng |
| `avatar_02` | 로봇 | [Corebreaker Robot](https://donitz.itch.io/corebreaker-robot-model) | 제작자 Donitz, CC0 |
| `avatar_03` | 마네킹 | [GDQuest Mannequiny](https://github.com/gdquest-demos/godot-3d-mannequin) | 저장소 기준 아트 CC BY 4.0, 코드 MIT. 사용 파일별 LICENSE 확인 및 출처 표시 |
| `avatar_04` | 휴머노이드 | [XCVG Rigged Humanoid](https://opengameart.org/content/rigged-and-animated-humanoid) | 제작자 XCVG, CC0 |

추가 목록: `avatar_05`~`08`은 Kenney Protagonists, `09`~`12`는 Retro, `13`~`16`은 Survivors의 저작자 제공 스킨이다. `17`~`21`은 KayKit Adventurers(기사·바바리안·메이지·로그·후드 로그), `22`~`25`는 KayKit Skeletons(메이지·미니언·로그·워리어)다. 추가 리소스는 CC0이며 원본 URL·라이선스·변환 사항은 `gymrats_app/assets/avatar/ATTRIBUTION.txt` 및 팩별 LICENSE에 기록한다. Kenney 12종은 공통 리그/메시에 서로 다른 원본 스킨을 적용한 외형이다.

프로필에서 썸네일·3D 미리보기·검색·분류 필터로 선택하며, ID는 계정별 기기 저장소에 유지된다. 새 ID를 온라인에서 사용하려면 서버의 이 허용 목록도 배포해야 한다. 알 수 없는 ID나 원격 모델 URL은 계속 거절한다.

리소스를 도입할 때 배포본의 라이선스와 원본 URL을 함께 보관한다. Mannequiny는 앱의 크레딧 화면과 저장소의 제3자 리소스 고지에 `GDQuest and contributors (https://www.gdquest.com/)`, 원본 링크, CC BY 4.0 링크 및 변경 사항을 표시한다. 코드를 가져올 경우 MIT 고지도 보존한다. CC0 모델도 추적을 위해 제작자·출처를 기록한다.

- 네 종류는 서로 다른 원본 뼈대를 가진다. 각 모델에 별도 뼈대 매핑·기준 자세·회전 보정을 두어 같은 33개 관절 입력을 공통 내부 리그로 변환한다. 원본 뼈대가 동일하다고 가정하지 않는다.
- 이미지·모델 파일은 앱에 포함한다. 네트워크로 임의의 모델 URL이나 리소스 파일을 교환하지 않는다.
- 기본값은 `avatar_01`. 알 수 없는 ID를 수신한 앱은 기본 아바타로 표시한다. 서버는 허용 목록 밖의 선택 요청을 거절한다.
- 설정 화면에서 목록 미리보기, 선택 표시, 저장을 제공한다. 로컬 저장으로 앱 재시작 후에도 선택을 유지한다. 계정 간·기기 간 저장은 사용자 프로필 담당자와 별도 연동한다.

클라이언트는 매칭 참가 때 현재 선택을 보낸다.

```json
{
  "v": 1,
  "type": "queue.join",
  "request_id": "join-001",
  "payload": {"exercise": "push_up", "avatar_id": "avatar_02"}
}
```

서버는 참가 시 선택을 매칭 정보에 복사하고 `match.found` 및 재접속 스냅샷에서 양쪽에 전달한다. 매 프레임에 아바타 ID를 반복 전송하지 않는다. 매칭 후 설정을 바꿔도 다음 매칭부터 적용한다.

## 5. 경기 상태와 이벤트

경기 상태는 `preparing → scheduled → playing → finished`다. 시작 전 취소는 `cancelled`, 정상 결과를 결정할 수 없는 중단은 `void`다. `finished`, `cancelled`, `void`는 최종 상태이며 늦게 도착한 데이터로 변경하지 않는다.

| 방향 | 이벤트 | 주요 payload 및 동작 |
|---|---|---|
| 서버→앱 | `session.welcome` | `player_id`, `connection_id`, `heartbeat_interval_ms: 5000`, `heartbeat_timeout_ms: 15000` |
| 앱→서버 | `queue.join` | `exercise`, `avatar_id`. v1은 `push_up`만 지원. 서버가 참가 요청을 수락한 순서(FIFO)대로 두 명씩 매칭 |
| 서버→앱 | `queue.joined` | `queue_id`. 대기열 참가 확인, 상대를 찾을 때까지 유지. 취소·접속 종료 시 대기열에서 제거하며 재참가는 맨 뒤에 추가 |
| 앱→서버 | `queue.cancel` | `queue_id` |
| 서버→앱 | `queue.cancelled` | `queue_id`. 실제 대기열에서 제거 완료 |
| 서버→앱 | `match.found` | `players`, `duration_ms: 30000`, `ready_deadline_ms` |
| 앱→서버 | `match.ready` | `ready: true/false`. 카메라·시작 자세가 준비됐는지 알림 |
| 서버→앱 | `match.ready_state` | `ready_player_ids` |
| 서버→앱 | `match.start` | `start_at_ms`, `end_at_ms`. 서버가 두 사용자 모두 준비된 경우 한 번 발행 |
| 앱→서버 | `rep.submit` | 아래 반복 판정 데이터 |
| 서버→앱 | `rep.accepted` | `rep_seq`, 서버가 수락한 본인 누적 점수 |
| 서버→앱 | `rep.updated` | 상대 `player_id`, `rep_seq`, 판정, 누적 점수 |
| 앱↔서버 | `pose.frame` | 아래 관절 데이터. 서버는 상대에게만 중계 |
| 앱→서버 | `match.leave` | `reason: user_exit` |
| 서버→앱 | `match.connection_state` | `player_id`, `state: disconnected/reconnected`, `reconnect_deadline_ms` (끊김 시) |
| 서버→앱 | `match.cancelled` | `reason: user_exit/ready_timeout/disconnected_before_start`, `ended_at_ms` |
| 서버→앱 | `match.finished` | 최종 점수·승자·종료 사유 |
| 서버→앱 | `match.void` | `reason: both_disconnected/server_restarted/server_error`, `ended_at_ms`. 승패·점수 반영 없음 |
| 앱→서버 | `match.resume` | 재인증된 연결에서 이전 `match_id` 재참가 요청 |
| 서버→앱 | `match.snapshot` | 현재 상태·참가자·아바타·점수·시각·마지막 수락 `rep_seq`·연결 상태 |

`players`는 정확히 두 명의 `{player_id, display_name, avatar_id}` 배열이다. 사용자명은 인증 프로필에서 가져온다. 한 사용자는 대기열 또는 활성 매칭 하나에만 속한다. 자기 자신과의 매칭, 같은 사용자의 중복 참가를 막는다.

준비 중 한 명이 나가면 상대도 취소 안내 후 홈으로 돌아간다. `match.start` 이후 준비 취소·카메라 오류가 나면 시작을 몰래 미루지 않고 해당 사용자의 `match.leave` 또는 연결 종료 정책으로 처리한다. 시작 전 상대가 나간 경우 서버가 `cancelled`로 확정할 수 있다.

### 시각 동기화

앱은 연결 후 `clock.sync`를 3회 보내며 payload에 `client_sent_ms`를 넣는다. 서버는 `clock.synced`로 같은 값과 `server_received_ms`, `server_sent_ms`를 돌려준다. 앱은 응답 수신 시각을 기록하고 왕복 지연이 가장 작은 표본으로 서버 시각 오프셋을 추정한다. 연결 복구 때도 다시 측정한다.

앱은 서버 시각 추정치로 카운트다운을 표시하되 최종 판정은 서버가 한다. 타이머 진행은 단조 시계에 기준점을 고정해 기기 벽시계 변경의 영향을 막는다. 기본 종료 시각은 `start_at_ms + 30000`이고, 앱이 백그라운드에 가거나 연결이 끊겨도 멈추지 않는다. 서버의 경기 제한 시간 측정에도 단조 시계를 사용한다. 앱은 이전 60초 서버의 응답도 해석할 수 있지만, 30초 규칙과 새 거절 사유를 실제 적용하려면 이 통합본의 서버 배포가 필요하다.

## 6. 관절 데이터

현행 `PoseFrame`의 회전 보정된 정방향 이미지 좌표를 사용한다. 송신 전에 미리보기용 좌우 반전을 적용하지 않는다. 왼쪽·오른쪽은 항상 사용자의 신체 기준이다.

- `x = keypoint.x / imageWidth`, `y = keypoint.y / imageHeight`.
- 원점은 정방향 이미지 좌측 상단, 오른쪽이 +x, 아래쪽이 +y.
- `z = keypoint.z / imageWidth`: 추정기가 준 상대 깊이 값의 정규화다. 미터 단위가 아니며 서로 다른 사람의 절대 깊이를 비교하지 않는다.
- `likelihood`는 기존 추정기의 인식값이며 `[0,1]`이다.
- `aspect_ratio = imageWidth / imageHeight`로 가로·세로 비율을 전달해 아바타 표시가 늘어나지 않도록 한다.
- x/y는 화면 밖 관절일 경우 0~1을 벗어날 수 있다. 서버는 유한값과 합리적인 범위 `[-2,3]`를 검사하고, 수신 앱은 화면 밖·낮은 인식값의 관절을 숨긴다. z는 유한값 및 `[-10,10]`, aspect_ratio는 `(0,10]`을 제안한다.

```json
{
  "v": 1,
  "type": "pose.frame",
  "match_id": "match-001",
  "payload": {
    "frame_seq": 42,
    "elapsed_ms": 12500,
    "aspect_ratio": 0.4615,
    "has_person": true,
    "joints": [[0, 0.51, 0.23, -0.04, 0.98], [11, 0.66, 0.39, 0.01, 0.95], [12, 0.34, 0.40, 0.00, 0.96]]
  }
}
```

`joints`의 각 배열은 `[joint_id, x, y, z, likelihood]`이며 길이가 정확히 5다. 예시는 3개만 보인 부분 프레임이다. 최대 33개, ID 중복 금지, 인식되지 않은 관절은 생략한다. 사람을 찾지 못하면 `has_person: false`, `joints: []`로 보낸다.

관절 ID는 저장소 `BodyLandmark`의 다음 순서를 v1 계약으로 고정한다. 구현 enum의 순서가 바뀌어도 네트워크 ID를 바꾸면 안 된다.

```text
0 nose                 1 leftEyeInner       2 leftEye
3 leftEyeOuter         4 rightEyeInner      5 rightEye
6 rightEyeOuter        7 leftEar            8 rightEar
9 leftMouth           10 rightMouth        11 leftShoulder
12 rightShoulder      13 leftElbow         14 rightElbow
15 leftWrist          16 rightWrist         17 leftPinky
18 rightPinky         19 leftIndex          20 rightIndex
21 leftThumb          22 rightThumb         23 leftHip
24 rightHip           25 leftKnee           26 rightKnee
27 leftAnkle          28 rightAnkle         29 leftHeel
30 rightHeel          31 leftFootIndex      32 rightFootIndex
```

`frame_seq`는 경기·사용자별로 1부터 증가하고 재접속 후에도 이어진다. 서버는 이전 번호 이하의 프레임을 폐기한다. 경기 중에만 중계하며 프레임별 ACK·재전송은 없다. 송수신 큐가 밀리면 최신 프레임만 남겨 지연이 계속 누적되지 않도록 한다.

수신 앱은 좌표를 아바타의 공통 리그에 매핑하고 보간해 표시한다. 인식값 0.5 미만 관절은 숨기는 안을 제안한다. 마지막 프레임 수신 후 500ms까지 자세를 유지하고 이후 중립/신호 지연 표시로 전환한다. 렌더링은 화면 종횡비를 보존하며 필요 시 표시 단계에서만 좌우를 반전한다. 자세 중단만으로 통신 기권을 판정하지 않는다.

## 7. 반복 판정과 점수

```json
{
  "v": 1,
  "type": "rep.submit",
  "request_id": "rep-001",
  "match_id": "match-001",
  "payload": {"rep_seq": 1, "elapsed_ms": 4200, "valid": true, "reason": null}
}
```

- `rep_seq`는 경기·사용자별 1부터 시작하며 정상/거절 판정을 모두 포함해 1씩 증가한다.
- 서버가 기대하는 다음 번호만 수락한다. 중복 번호는 저장된 수락 결과를 재전송하며 점수를 다시 올리지 않는다. 같은 번호에 다른 내용은 `REP_CONFLICT`로 거절한다.
- 중간 번호가 빠지면 `REP_OUT_OF_ORDER`와 `expected_rep_seq`를 반환한다. 앱은 미확인 이벤트를 순서대로 재전송한다.
- `valid: false`이면 `reason`은 `insufficient_depth`, `incomplete_extension`, `shoulders_not_level`, `too_fast`, `knees_down`, `arms_straight`, `belly_down`, `not_floor_push_up`, `phone_moved` 중 하나다. `too_fast`는 이전 클라이언트 호환용이며, 현재 판정기는 빠른 하강을 거절 대신 사후 피드백으로 처리한다. 정상 판정은 `reason: null`이다.
- 서버가 수락할 때 valid/invalid 누적 수를 계산한다. 클라이언트의 임의 누적 점수는 받지 않는다.
- 서버의 현재 경기 시간이 `[start, end)` 안에 있고, `elapsed_ms`가 `[0,duration_ms)` (기본 `[0,30000)`)이며 이전 수락 이벤트보다 작지 않을 때만 새 이벤트를 수락한다. 종료 후 도착한 새 이벤트는 점수에 반영하지 않는다. 네트워크로 늦게 도착한 마지막 판정이 제외될 수 있는 프로토타입 정책이다.
- 이미 수락한 반복은 종료 후 중복 전송돼도 원래 ACK를 돌려줄 수 있으나 최종 결과를 바꾸지 않는다.
- 서버는 점수 집계와 이벤트 순서를 관리한다. 단말의 자세 판정을 신뢰하는 v1은 변조 클라이언트까지 막는 서버 측 부정행위 검증을 제공하지 않는다.

`rep.updated`에는 서버가 추가한 `player_id`, `rep_seq`, `valid`, `reason`, `valid_reps`, `invalid_reps`가 들어간다. 상대 표시 점수는 서버 누적값으로 덮어써 재전송에 따른 중복 가산을 막는다. 상대 아바타의 움직임 자체는 `pose.frame`을 사용한다.

## 8. 결과와 연결 끊김

```json
{
  "v": 1,
  "type": "match.finished",
  "match_id": "match-001",
  "server_time_ms": 1792022460000,
  "payload": {
    "result_id": "result-001",
    "reason": "time_up",
    "winner_id": "user-a",
    "ended_at_ms": 1792022460000,
    "players": [
      {"player_id": "user-a", "avatar_id": "avatar_02", "valid_reps": 12, "invalid_reps": 2, "outcome": "win"},
      {"player_id": "user-b", "avatar_id": "avatar_01", "valid_reps": 10, "invalid_reps": 1, "outcome": "loss"}
    ]
  }
}
```

위 시각·ID는 형식 예시다. `reason`은 `time_up`, `forfeit`, `disconnect_timeout`이다. 기권은 점수와 무관하게 기권자가 패배한다. 동점은 양쪽 `draw`, `winner_id: null`이다. 정확도는 `valid_reps / (valid_reps + invalid_reps)`로 표시하고 판정이 0개면 값 없음으로 표시한다.

앱은 로컬 타이머가 끝나면 판정 전송을 멈추고 서버 결과를 기다린다. 결과를 기다리는 중 연결이 끊기면 승패를 임의 계산하지 않고 재접속 후 스냅샷으로 복구한다. `result_id` 기준으로 저장·결과 화면 전환을 중복 수행하지 않는다.

### 연결 유지와 복구

- 앱은 5초마다 `session.ping`을 보내고 서버는 `session.pong`으로 응답한다. `request_id`로 대응시킨다.
- 15초 동안 heartbeat가 없거나 소켓이 닫히면 서버가 끊김을 확정하고 상대에게 알린다. 10초 유예는 끊김 감지 시점부터 계산한다. 최대 감지 지연이 추가될 수 있다.
- 경기 전에는 끊김 감지 시 매칭을 취소한다. 경기 중에는 일시적 끊김 유예를 적용한다.
- 앱은 1초, 2초, 이후 최대 3초 간격으로 재접속을 시도하되 로그인 실패는 무한 재시도하지 않는다.
- `match.resume`는 인증된 본인의 경기만 가능하다. 서버는 새 연결을 유일한 활성 연결로 정하고 오래된 연결의 쓰기를 차단한다.
- `match.snapshot`은 `status`, `players`, `ready_player_ids`, 준비/시작/종료 시각(해당할 때), 점수, 각 사용자 마지막 수락 `rep_seq`, 연결 상태, 최종 결과(있을 때)를 포함한다. 모든 선택적 필드는 상태에 따라 null 가능하다.
- 미확인 반복은 같은 번호로 재전송하되 종료 전 수락 규칙을 따른다. 오래된 자세 프레임은 재전송하지 않는다.
- 한 명만 유예 만료하면 연결 종료 패배다. 양쪽 모두 끊겨 있는 경우 어느 한쪽의 유예 만료 또는 경기 종료가 먼저 발생하면 무효로 확정한다.
- 시간 종료 시 한 명만 끊겨 있고 유예 중이면 결과 확정을 유예 만료까지 보류한다. 복구하면 종료 시점까지 서버가 수락한 점수로 정상 결과, 미복구면 연결 종료 패배다. 종료 후 새 반복은 받지 않는다.
- 서버 재시작 전 활성 경기는 결과 저장 계층에서 무효로 복구한다. 복구 저장이 없는 초기 단계에는 `MATCH_NOT_FOUND`를 명시해 앱이 경기 종료/결과 확인 불가를 표시하게 한다. 이를 정상 경기 결과로 저장하지 않는다.

결과는 복구를 위해 서버 메모리에 최소 10분 보관하는 안을 제안한다. P11의 DB 저장이 연결되면 그 이후 재조회는 DB가 맡는다. 서버는 최종 결과를 한 번 확정하고 `result_id` 기반으로 P11 저장기를 호출한다. 원본 관절 프레임·영상은 결과 저장에 포함하지 않는다.

## 9. 오류

```json
{"v":1,"type":"error","request_id":"rep-001","match_id":"match-001","payload":{"code":"REP_OUT_OF_ORDER","message":"Expected next rep sequence","retryable":true,"expected_rep_seq":3}}
```

필수 오류 코드는 `UNSUPPORTED_VERSION`, `UNKNOWN_TYPE`, `INVALID_PAYLOAD`, `UNAUTHENTICATED`, `FORBIDDEN`, `INVALID_AVATAR`, `ALREADY_QUEUED`, `ALREADY_IN_MATCH`, `QUEUE_NOT_FOUND`, `MATCH_NOT_FOUND`, `INVALID_STATE`, `REQUEST_ID_REUSED`, `REP_CONFLICT`, `REP_OUT_OF_ORDER`, `RATE_LIMITED`, `SERVER_ERROR`다.

상태가 맞지 않는 요청은 `INVALID_STATE`와 현재 상태를 반환한다. 취소 요청과 매칭 성립이 경합하면 클라이언트는 `match.found`의 경기 ID로 `match.leave`를 보낸다. 오류 메시지에 토큰·서버 내부 경로·스택 추적을 넣지 않는다.

## 10. 구현 경계와 완료 기준

| 작업 | 구현 범위 | 확인할 시나리오 |
|---|---|---|
| P7 | 서버 연결·대기열·경기 상태·준비·공통 시작 | 두 사용자만 매칭, 중복 참가 방지, 취소 경합, 준비 시간 초과 |
| P8 | Flutter 연결 서비스·직렬화·서버 시각·온라인 Matchmaker | 화면 이동에도 같은 연결 유지, 인증 실패, 재접속·스냅샷 |
| P9 | rep 수락·중계, 좌표 정규화·중계·리깅 | 4종 아바타 각각 움직임 확인, 회전·반전·종횡비·누락 관절, 중복/역순 이벤트 |
| P10 | 서버 결과·기권·통신 이탈·결과 화면 | 동점, 정상 종료, 한쪽/양쪽 끊김, 종료 직전 복구, 최종 결과 중복 방지 |
| 추가 UI 연계 | 설정의 아바타 선택·로컬 저장·4종 리소스 | 재시작 후 선택 유지, 다음 매칭에 적용, 알 수 없는 ID 대체 |

아바타 선택 UI·리소스 제작 담당과 일정표 반영 여부는 PM이 정한다. P7~P10 외 작업을 자동으로 다른 팀원에게 배정하지 않는다.

실제 휴대폰 두 대를 서로 다른 네트워크에서 연결해 매칭부터 결과까지 검증한다. 기존 봇 모드와 테스트는 유지하고 온라인 모드는 별도 구성으로 주입한다. 현재 `Matchmaker.findOpponent()` 및 `OpponentSource`만 교체해서 끝내지 않고 경기 ID, 세션 상태, 서버 타이머, 송신 경로를 함께 확장한다. 배포 시 Android 인터넷 권한, TLS URL 구성, 역방향 프록시의 WebSocket 전달과 서버 재시작 방식을 확인한다.

## 관련 소스

### 로컬 1차 구현 및 실행

- 홈의 **온라인 1v1 · 아바타 대결**은 기존 AI 모드와 별도 경로다.
- 시작은 `feat/auth_history`에서 가져온 정상 로그인·회원가입 화면이다. 로그인한 AuthRepository의 동일 JWT·계정을 온라인 배틀에서 재사용한다. 비밀번호는 저장하지 않으며, 기존 로그인 세션은 Android Keystore 기반 SecureTokenStore에 암호화해 저장한다. 온라인 로비에는 추가 로그인·토큰 입력·테스트 계정 생성 UI가 없다.
- 일반 앱 주소는 `lib/config/server_config.dart`의 `https://52.78.38.225/api` 및 `wss://52.78.38.225/ws/v1/battle`로 고정한다. 주소 입력란·dart-define 주소 변경은 없고, Android는 평문 통신을 허용하지 않는다. 단위 테스트만 생성자 주입으로 로컬 서버를 사용한다.
- 한 연결을 로비부터 결과까지 유지한다. 양쪽 기존 자세 확인 기준을 만족하고 준비 완료를 누르면 서버 공통 시각으로 카운트다운한다.
- **상단은 상대 아바타 전용 영역**, 하단은 본인 카메라/아바타 전환 영역이다. 상대 영상·음성·이미지·임의 모델 URL을 받거나 전송하는 경로는 없다.
- 좌표는 최대 10 FPS, 최대 33개, 16 KiB 제한으로 검증·중계한다. 아바타 종류는 매칭 명단에서 전달한다. 500ms 이상 새로운 자세가 없으면 상대 자세를 비우고 대기 상태로 표시한다.
- 서버 점수 수락·중복 방지, 서버 결과, 준비 시간 초과, 기권, 재접속 스냅샷, 한쪽 끊김 유예, 양쪽 끊김 무효를 로컬 테스트했다. 서버 타이머는 백그라운드에서도 연장되지 않는다.
- 원격 아바타는 앞서 만든 위치 이동·팔꿈치 강조 렌더러를 재사용한다. 전면 카메라 반전은 송신 좌표에 적용하지 않고, 상대는 신체 좌우 기준으로 표시한다.

서버는 Dart SDK 외 추가 패키지 없이 저장소 루트에서 실행한다. 아래 개발 인증은 **실제 로그인 인증이 아니며 루프백 전용**이다.

```powershell
$env:BATTLE_DEV_AUTH = '1'
dart server/bin/server.dart
```

기본 리슨 주소는 `127.0.0.1:8080`, WebSocket 경로는 `/ws/v1/battle`이다. 인증 어댑터가 없으면 기본 거부한다. 로컬 인증은 서버·Dart 소켓 단위 테스트에서만 사용하며, 실제 Android 앱은 아래의 고정 공개 서버로 접속한다.

```powershell
cd gymrats_app
flutter run
```

순수 Dart 테스트는 생성자에 명시적으로 허용한 루프백 `ws://`만 사용할 수 있다. 일반 앱에는 개발 인증이나 토큰 편집 경로를 제공하지 않는다. 인터넷/LAN의 평문 ws 접속과 인증서 우회는 허용하지 않는다.

공개 접속은 검증된 TLS 도메인의 `wss://<domain>/ws/v1/battle`을 설정해야 한다. 배포 서비스는 `BATTLE_AUTH_URL=http://127.0.0.1:8000/users/me`로 기존 Django API에 JWT 검증을 위임하고, 반환된 계정 ID·닉네임을 사용한다. 잘못된 토큰·API 오류·리디렉션은 거부한다. CLI 인증 어댑터는 이 API 방식, `BATTLE_AUTH_FILE` 임시 trusted-token 방식, 루프백 개발 방식 중 하나만 선택한다. 실제 비밀은 기존 규칙대로 `/srv/gymrats/.env`에만 둔다.

### 공유 서버 배포 현황 (2026-10-17)

- 서비스: `gymrats-battle.service`, 부팅 시 시작 및 오류 시 재시작. 기존 `gymrats-api`·nginx·DB는 변경하지 않았다.
- 경로: `/srv/gymrats/battle/current` → 타임스탬프 릴리스. 실행 파일은 Dart 3.13.5로 서버에서 빌드했다.
- 내부 리슨: `127.0.0.1:8080`. 외부 접속: `wss://52.78.38.225/ws/v1/battle`, 상태 `https://52.78.38.225/battle-health`. 기존에 허용된 443 포트만 사용한다.
- 검증: 기존 계정의 짧은 수명 JWT를 메모리에서만 사용해 인증·잘못된 토큰 거부·FIFO 명단 순서·동시 시작·기권 종료를 확인했다. 계정 생성·경기 DB 기록·토큰 출력은 하지 않았다.
- 일반 Android 앱은 공개 WSS에 직접 접속하므로 SSH 터널·adb reverse가 필요 없다. 서버 내부 루프백은 운영 진단·Dart 단위 테스트 용도다.
- nginx HTTPS 설정과 공인 IP 인증서 발급 완료. Certbot 5.8.0, `shortlived` 프로파일, HTTP-01 webroot 검증을 사용한다. 인증서·계정 키는 서버의 `/srv/gymrats/battle/tls/config`에만 저장하고 root 전용 권한을 적용했다.
- `gymrats-cert-renew.timer`가 6시간 간격으로 갱신을 검사하고 갱신 시 nginx를 reload한다. 실제 인증서 검증과 갱신 dry-run을 통과했다. 인증서 검증 우회는 하지 않는다.
- 공개 WSS에서 두 개의 별도 TEST 계정으로 실제 HTTPS 로그인·FIFO 매칭·아바타 종류·자세 중계·점수·종료 결과를 검증했다. 새 테스트 계정은 DB에 남지만 경기 기록은 저장하지 않는다. 토큰·비밀번호는 로그·소스·APK에 넣지 않는다.

### 휴대폰 1대 + 에뮬레이터 테스트

- 휴대폰용 빌드: `flutter build apk --debug`. 정상 로그인·회원가입 후 홈의 온라인 배틀에서 아바타 선택 → **온라인 상대 찾기**를 누른다. 실제 카메라의 자세 확인 후 준비 완료를 누른다.
- 에뮬레이터용 빌드: `flutter build apk --debug --dart-define=BATTLE_SYNTHETIC_OPPONENT=true`. 똑같은 정상 로그인 화면에서 휴대폰과 다른 계정으로 로그인하고 온라인 배틀에 참가한다. 계정 자동 생성·자동 로그인은 하지 않는다.
- 에뮬레이터 상단에는 휴대폰에서 받은 실제 자세 아바타가, 하단에는 합성 자세가 나타난다. 가상 상대는 준비 완료 및 3초당 1회 합성 판정을 보낸다. 화면에 TEST 표시하며 실제 운동이나 AI 검출 결과로 간주하지 않는다.
- 가상 모드는 명시적 dart-define을 켠 디버그 빌드에서만 동작한다. 일반·release 빌드에서는 가상 모드가 비활성이다. USB/SSH 터널 없이 공개 HTTPS/WSS로 통신한다. 같은 계정을 두 기기에 쓰면 서버는 기존 연결을 종료해 자기 자신과의 매칭을 막는다.

아직 완료하지 않은 범위:

- 온라인 경기의 P11 DB 결과 저장·과거 경기 조회 연결, 강제 종료/프로세스 재시작 후 경기 복구. 기존 AI 경기 기록 기능은 유지하지만 온라인 결과는 아직 배틀 서버 메모리에서 최대 10분 유지한다. 앱 재시작 시 기존 로그인 저장소에서 로그인 세션을 복원한다.
- 아바타 선택의 재시작 후 영구 저장. 현재 선택은 온라인 로비/해당 매칭에 한정한다.
- 서로 다른 외부 네트워크의 휴대폰 두 대로 종단 검증. 휴대폰 한 대와 합성 상대 에뮬레이터 간 연동은 사용자가 확인했다. 실제 휴대폰 두 대의 정상 종료·이탈·재접속 시나리오는 별도 최종 검증이 필요하다.
- 운영 규모의 인증/접속 수/프록시 제한 및 느린 수신자 압력 테스트. 현재 일반 제어 요청 제한은 초당 15개이며, 초안 제안치 10개와 다르다.
- 카메라/검출 오류 시 자동 기권 정책. 현재는 서버 시간이 계속 가고 자세/판정이 중단되며, 사용자가 나가면 기권 처리한다. 오류만으로 승패를 임의 결정하지 않는다.

핵심 구현 파일:

- `server/lib/battle_server.dart`, `server/bin/server.dart`
- `gymrats_app/lib/shared/battle_protocol.dart`
- `gymrats_app/lib/services/online/online_battle_session.dart`, `pose_wire.dart`
- `gymrats_app/lib/screens/online_lobby_screen.dart`, `online_battle_screen.dart`
- `gymrats_app/lib/widgets/opponent_avatar_panel.dart`

회귀 테스트:

```powershell
cd gymrats_app
flutter test test/services/online/online_battle_integration_test.dart test/widgets/opponent_avatar_panel_test.dart
```

공유 서버에는 배포했지만 이 문서를 GitHub Wiki 등 공유 문서에 자동 게시하지는 않았다. 온라인 결과의 DB 저장은 아직 구현하지 않았다.

- [현재 앱 진입점](../gymrats_app/lib/main.dart)
- [매칭 인터페이스](../gymrats_app/lib/services/matching/matchmaker.dart)
- [상대 인터페이스](../gymrats_app/lib/services/opponent/opponent_source.dart)
- [관절과 프레임 모델](../gymrats_app/lib/models/pose_frame.dart)
- [반복 판정 모델](../gymrats_app/lib/models/rep_event.dart)
- [설계 Wiki](https://github.com/snuhcs-course/swpp-2026-project-team-04/wiki/Design-Documentation)

## Iteration 3 changes

게임 규칙(점수, 콤보, 피버, 체력 바, KO)의 근거는 [배틀 규칙 문서](iteration-3/battle-rules.md) 7장이다. 숫자는 `gymrats_app/lib/models/battle_rules.dart` 한 파일에 있고, 서버도 같은 코드(`gymrats_app/lib/services/game/player_game_score.dart`)로 계산한다. 이 절은 위 5, 7, 8장에 다음을 더한다.

| 메시지 | 추가 필드 | 뜻 |
|---|---|---|
| `match.found`, `match.snapshot` | `fever_start_ms`, `ko_lead`, `average_points` | 피버 시작 시각, KO 점수 차, Average rep의 점수. 앱은 체력 바를 `ko_lead`로 그린다. `average_points`가 없는 서버에는 `"average"`를 보내지 않는다 |
| `rep.submit` | `grade`: `"average"`, `"good"`, `"excellent"` 또는 없음 | rep의 등급. 깊이와 팔꿈치 각도는 폰이 판단한다. 유효 rep에는 `good`이나 `excellent`이고, 없으면 `good`으로 본다. `average`는 `valid: false`이고 `reason: "insufficient_depth"`일 때만 허용하며, 그 밖의 거절 rep에는 값을 보내지 않는다. 어긋난 조합이나 모르는 값은 `INVALID_PAYLOAD` |
| `rep.accepted`, `rep.updated` | `combo`, `points`, `game_score` | 연속 콤보 수(거절 rep과 Average rep 뒤 0), 이 rep의 점수, 그 선수의 누적 게임 점수. 폰은 `valid_reps`처럼 서버 누적값으로 덮어쓴다. `rep.updated`에는 보낸 쪽의 `grade`도 그대로 실린다 |
| `match.finished`의 `players[]`, `match.snapshot`의 `scores` | `game_score` | 최종 또는 현재 게임 점수 |

- **종료 사유 `ko`:** `rep.submit`을 수락한 직후 점수 차가 `ko_lead` 이상이면 서버는 `rep.accepted`와 `rep.updated`를 보낸 다음 `match.finished`(`reason: "ko"`)로 경기를 끝낸다. 그 뒤의 새 `rep.submit`은 종료 후 이벤트이므로 `INVALID_STATE`다.
- **Average rep:** `valid: false`이므로 `invalid_reps`에 들어가고 `valid_reps`에는 들어가지 않는다. 서버는 같은 코드(`PlayerGameScore.addRep`)로 `average_points`를 더하고, 피버 때 배수를 적용하며, 콤보 보너스 없이 콤보를 끊는다. KO 판정은 다른 rep와 같다. 기준(거절 사유 `insufficient_depth`, `minElbowAngle` 120° 이하)은 폰이 판단하고 각도는 보내지 않는다. 서버가 폰의 판정을 믿는 것은 `valid`, `grade`와 같다.
- **옛 앱, 옛 서버와 섞일 때:** 옛 앱은 거절 rep에 `grade`를 보내지 않으므로 그 rep는 지금처럼 0점이다. 옛 앱은 `rep.updated`의 `grade: "average"`로 +N을 띄우지 않지만 `game_score`를 그대로 쓰므로 점수와 바는 같다. 새 앱은 `match.found`와 `match.snapshot`에 `average_points`가 있을 때만 `"average"`를 보낸다. W3 서버는 거절 rep에 `grade`가 있으면 `INVALID_PAYLOAD`를 주기 때문이다. W3 서버에 붙으면 Average는 꺼지고 그 rep는 0점이다.
- **승자:** `time_up`과 `ko`는 게임 점수가 높은 쪽 → 유효 횟수가 많은 쪽 → 무승부(`winner_id: null`) 순서로 정한다. `forfeit`와 `disconnect_timeout`은 지금처럼 나간 쪽이 패배한다.
- **저장:** 결과 저장(`BattleResultStore.finished`)에는 게임 점수를 넣지 않는다(배틀 규칙 문서 10장 9번). `reason`에 `ko`가 올 수 있다.
- **배포 순서:** Django → 배틀 서버 → 앱. Django가 먼저인 이유는, Django `REASONS`에 `ko`가 들어가기 전에 배틀 서버를 배포하면 KO 경기의 저장이 거절되기 때문이다(마이그레이션은 없다). 옛 서버는 모르는 필드를 거절하므로, 앱은 `match.found`에 `fever_start_ms`가 있을 때만 `grade`를 보내고 게임 화면을 켠다.
- **빌드:** 배틀 서버가 `gymrats_app/lib/models/battle_rules.dart`, `game_score.dart`, `gymrats_app/lib/services/game/player_game_score.dart`를 새로 import한다. 배포용 `source.tar`에 이 세 파일이 있어야 컴파일된다.
