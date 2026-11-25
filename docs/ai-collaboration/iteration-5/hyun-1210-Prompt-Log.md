# AI Collaboration Report – Iteration 5 – Prompt Log
Input prompts only, quoted verbatim (no agent responses), from the course Session Exporter.

## 2026-11-23 · Hyunwoo Song · codex/iter5-setup-timeout
<!-- 9a315516 2026-11-22T13:40:29.606Z -->
[Hyunwoo Song, 11-22 22:40] "d:\Users\[REDACTED:username]\Downloads\gymrats-iter5-harness-[REDACTED:custom_term].zip 이번 iter 내가 맡은 작업 뭔지 설명해봐"

<!-- 9a315516 2026-11-22T13:48:36.515Z -->
[Hyunwoo Song, 11-22 22:48] "진행하자"

<!-- 9a315516 2026-11-22T14:41:43.404Z -->
[Hyunwoo Song, 11-22 23:41] "https://claude.ai/artifact/Pe5GgEvrv9brdQ1M5LRF6U?sk=<redacted> 이거 artifact너가 읽을 수 있나?"

<!-- 9a315516 2026-11-22T14:42:53.059Z -->
[Hyunwoo Song, 11-22 23:42] "https://claude.ai/artifact/LGAA4nWpkL7qDwR9nJeVbR"

<!-- 9a315516 2026-11-22T14:59:25.004Z -->
[Hyunwoo Song, 11-22 23:59] "현우님, P12 인수 기준에 취소 후 재매칭이 있으니 PM으로서 예외 승인합니다. online_lobby_screen.dart의 _openBattle 안에서 세팅 시간 초과 후 ‘다시 매칭’을 누르면 로비에서 새 검색을 시작하도록 연결하는 범위예요.

진영님도 이 범위로 수정해도 괜찮으실까요? 동의 주시면 현우님은 하네스 예외 목록과 progress.md에 승인 범위를 남기고 진행해 주세요. PR에는 ‘다시 매칭’을 눌렀을 때 검색이 한 번만 시작되는지, 일반 경기 종료 때는 기존처럼 홈으로 돌아가는지 확인한 결과도 부탁드려요. 동의한데 그냥 진행하고 앞으로 이런거 선조치 후보고 하면될듯"

<!-- 9a315516 2026-11-22T16:27:24.659Z -->
(Removed: an automatic context summary that the exporter read as a prompt; not typed by a person.)

<!-- 9a315516 2026-11-23T00:32:25.025Z -->
[Hyunwoo Song, 11-23 09:32] "pr만 올리면 나머지 다 진행되는거 아닌가 서버 배포만하면"

<!-- 9a315516 2026-11-23T04:01:22.685Z -->
[Hyunwoo Song, 11-23 13:01] "진행해"

## 2026-11-23 · Hyunwoo Song · codex/iter5-setup-timeout
<!-- 9a315516 2026-11-23T04:08:32.755Z -->
[Hyunwoo Song, 11-23 13:08] "폰은 연결해놨으니까 테스트 하면 돼 애뮬레이터 할떄. 그리고 텔레멘트리랑 지금 나머지 남은 작업들은 어떻게 해야하는 걸로 이해하고 있어?"

<!-- 9a315516 2026-11-23T04:14:10.082Z -->
[Hyunwoo Song, 11-23 13:14] "현우님, 서버에 <redacted> 계정 만들고 보내 주신 키 등록했습니다. ssh <redacted> 로 들어가시면 됩니다. 진영이형·상우 계정처럼 sudo(비밀번호 없이), docker, gymrats 그룹이 들어가 있습니다. 등록된 키 지문은 SHA256:<redacted> 입니다.
참고로 배틀 서버 파일은 <redacted> 계정 소유라서, 배틀 서버를 배포하실 때는 sudo -u <redacted> 로 설치 스크립트를 돌려야 권한 오류가 안 납니다.
@[REDACTED:custom_term] 라는데. 아니야 내가 배포 해도 될듯 근데 리뷰에서 코드 바뀌고 진행하면 될듯 지금 pr은 올렸어? pr올리고 머지 직전의 코드 상태에서 배포하고 나서 테스트하면되나?"

<!-- 9a315516 2026-11-23T04:15:48.257Z -->
[Hyunwoo Song, 11-23 13:15] "이벤트 정의를 진영이형한테 넘긴다는게 뭔소리지 기록보관소랑 리포트 진입은 저렇게 단순한 느낌은 아니고 지금 기록보관소 ui자체가 뭔가 난해하고 복잡하다? 좀 더 사용자입장에서 한눈에 확 와닿고 편리하게 조작하게 재구성할 필요가 있다와 캐릭터 멘트 이후 상세 리포트로 가는게 뭔가 좀더 유저 프렌들리하게 자연스럽게 넘어가는 느낌을 원한데"

<!-- 9a315516 2026-11-23T04:20:10.485Z -->
[Hyunwoo Song, 11-23 13:20] "그럼 p6오기전에 못하네. 텔레멘트리는. 다른 것들부터 해야하는 방식으로? 그럼 너가 인지하고 있는 작업순서가 지금 어떻게 되지? 그리고 p13이나 p15는 바로 고치지말고 시안을 artifact로 후보 나눠서 보여줘"

<!-- 9a315516 2026-11-23T05:22:40.177Z -->
[Hyunwoo Song, 11-23 14:22] "진행해"

<!-- 9a315516 2026-11-23T05:34:14.312Z -->
[Hyunwoo Song, 11-23 14:34] "codex는 pr 올리면 알아서 리뷰해주게 깃허브에 돼 있어 확인해봐 그리고 리포트 시안은 바로 시작해"

<!-- 9a315516 2026-11-23T05:52:26.160Z -->
[Hyunwoo Song, 11-23 14:52] "일단 코드 서버 배포해서 10초 그거 되는지 확인하자"

<!-- 9a315516 2026-11-23T06:01:55.905Z -->
[Hyunwoo Song, 11-23 15:01] "너가 진행해서 폰과 연결된 노트북 애뮬레이터로 테스트해봐"

<!-- 9a315516 2026-11-23T06:19:47.362Z -->
[Hyunwoo Song, 11-23 15:19] "[Image #4] [Image #5] 이레퍼런스들 참조해서 디자인 수정해봐"

<!-- 9a315516 2026-11-23T06:24:51.028Z -->
[Hyunwoo Song, 11-23 15:24] "앞에 해놓은 것도 아까우니까 일단 버리지말고 남겨놔 비교용으로 쓰게"

<!-- 9a315516 2026-11-23T08:05:43.227Z -->
[Hyunwoo Song, 11-23 17:05] "폰은 연결해놨고 애뮬레이터는 너가 띄우거나 만들어도되고 디자인 시안은 D-2가 좀 마음에 든다네 이걸 좀 다듬거나 업그레이드 하면 될 것 같은데?"

<!-- 9a315516 2026-11-23T08:51:24.901Z -->
[Hyunwoo Song, 11-23 17:51] "다 끝나면 빌드는 하지말고 어느 사항들이 수정됐는지 그리고 디자인 어떻게 구성했는지 시안만 보여줘(그 시간 재는거 같이)"

<!-- 9a315516 2026-11-23T09:03:27.331Z -->
[Hyunwoo Song, 11-23 18:03] "그리고 나서 끝나면 디자인 시안 d-2로 좀 다듬거나 업그레이드 해보는건가"

<!-- 9a315516 2026-11-23T09:05:28.322Z -->
[Hyunwoo Song, 11-23 18:05] "남은 시간: 10초 이렇게 표시는 해줘야겠다 방금 봤는데 (그냥 숫자말고)"

## 2026-11-24 · Hyunwoo Song · feat/iter5-game-report
<!-- 9a315516 2026-11-23T15:23:45.104Z -->
[Hyunwoo Song, 11-24 00:23] "codex리뷰 아직 없으면 없는대로 일단 냅두자 머지는 가능한 상태지? pm한테 뭐라고 보낼까? 그리고 D-2+ 시안이 뒤집어져있기도 하고  일단내용 구성 자체는 D-2가 좋아서 이 구성은 따르돼 디자인 스타일 특히 자세 분석 쪽 디자인 구성은 D-2+가 좀더 좋았던 것 같아 이거 반영해서 D-2에서 다시 좀 깔끔하게 하나 안 만들어볼래?"

<!-- 9a315516 2026-11-23T15:36:23.834Z -->
[Hyunwoo Song, 11-24 00:36] "<span style=\"font-size: 12px; color: #4A5366; line-height: 1.5\">10초 구간별 인정 횟수로 정해요. 초반에 몰리면 초반 집중형, 고르면 꾸준형, 후반에 늘면 후반 강세형.</span><div style=\"margin: 4px 20px 14px; padding: 10px 12px; background: #F3F5F9; border-radius: 10px; font-size: 12px; color: #4A5366; line-height: 1.5\">작은 숫자는 최근 5경기 평균과의 차이예요. 칼로리와 무게는 체중 65 kg으로 가정한 추정값이에요. 줄을 누르면 계산 근거가 보여요.</div> 얘네는 빼도 될 것 같아\"d:\Users\[REDACTED:username]\Downloads\gymrats-iter5-harness-[REDACTED:custom_term] (1).zip\"  그리고 하네스 업데이트 됐대"

<!-- 9a315516 2026-11-23T15:38:46.482Z -->
[Hyunwoo Song, 11-24 00:38] "체중과 키를 받기로 했고 없으면 디폴트 값 65로 생각하면 될 것 같아(앞에 진영이형이 회원가입할떄 하기로 했는데 기다릴까? 아님 올거 생각해서 가정하고 작업할까?) 자세 점수 가중치는 기존 코드들을 보고 너가 잘 판단하면 될 것 같고 

<pasted_content id=\"0817\">
<div style=\"padding: 0 20px; display: flex; flex-direction: column; gap: 10px\">
    <div style=\"background: #FFFFFF; border-radius: 22px; padding: 16px; display: grid; grid-template-columns: 48px minmax(0, 1fr); gap: 12px; align-items: start\">
      <div style=\"width: 48px; height: 48px; border-radius: 14px; background: #C6FF3D; display: flex; align-items: center; justify-content: center; font-size: 10px; font-weight: 700\">캐릭터</div>
      <div>
        <div style=\"font-size: 13px; font-weight: 700; color: #4A5366\">코치 한마디</div>
        <div style=\"font-size: 15px; margin-top: 4px; line-height: 1.55\">깊이는 끝까지 좋았어요. 다음 대결은 마지막 10초에 6회를 목표로 해 봐요.</div>
      </div>
    </div>
    <a href=\"#\" style=\"height: 52px; border-radius: 16px; background: #FFFFFF; color: #141A26; font-size: 15px; font-weight: 700; display: flex; align-items: center; justify-content: center; gap: 6px; text-decoration: none\">자세 분석 자세히 보기
      <svg width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.4\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M9 6l6 6-6 6\"></path></svg>
    </a>
  </div>
</pasted_content id=\"0817\">

 마지막 꺼 이거도 위에것들 처럼 여백 안남기고 박스로 채워지는게 더 자연스러울 것 같은데"

<!-- 9a315516 2026-11-23T15:41:10.301Z -->
[Hyunwoo Song, 11-24 00:41] "<pasted_content id=\"0817\">
<div style=\"padding: 2px 20px 0; display: flex; flex-direction: column; gap: 12px\">
    <div style=\"height: 48px; background: #FFFFFF; border-radius: 24px; display: flex; align-items: center; justify-content: space-between; padding: 0 6px\">
      <button aria-label=\"이전 경기\" style=\"width: 40px; height: 40px; border: 0; background: transparent; color: #141A26; display: flex; align-items: center; justify-content: center; padding: 0\">
        <svg width=\"18\" height=\"18\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M15 18l-6-6 6-6\"></path></svg>
      </button>
      <span style=\"font-family: Oxanium, sans-serif; font-weight: 600; font-size: 16px\">26.11.23(월) 14:30</span>
      <button aria-label=\"다음 경기\" style=\"width: 40px; height: 40px; border: 0; background: transparent; color: #C9CED8; display: flex; align-items: center; justify-content: center; padding: 0\">
        <svg width=\"18\" height=\"18\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M9 6l6 6-6 6\"></path></svg>
      </button>
    </div>

    <div style=\"background: #FFFFFF; border-radius: 22px; padding: 18px 20px; display: flex; align-items: center; justify-content: space-between\">
      <div style=\"display: flex; flex-direction: column; gap: 6px\">
        <div style=\"display: flex; align-items: center; gap: 10px\">
          <span style=\"font-size: 17px; font-weight: 700\">자세 점수</span>
          <span style=\"font-family: Oxanium, sans-serif; font-weight: 700; font-size: 13px; padding: 3px 8px; border-radius: 8px; background: #F6FFE6; color: #1E7A3C\">+6</span>
        </div>
        <span style=\"font-size: 12px; color: #4A5366\">푸쉬업 · vs RepBot 고수 · 30초</span>
      </div>
      <div style=\"display: flex; align-items: baseline; gap: 4px\">
        <span style=\"font-family: Oxanium, sans-serif; font-weight: 800; font-size: 52px; line-height: 1\">82</span>
        <span style=\"font-size: 16px; font-weight: 700; color: #4A5366\">점</span>
      </div>
    </div>
  </div>
</pasted_content id=\"0817\">

 이러면 맨 위에도?"

<!-- 9a315516 2026-11-23T15:41:46.916Z -->
[Hyunwoo Song, 11-24 00:41] "그리고 맨위에 요약, 상세, 변화도 다 없애도 될 것 같아"

<!-- 9a315516 2026-11-23T15:43:39.568Z -->
[Hyunwoo Song, 11-24 00:43] "이제 진행해도 될 것 같은데? 자세 분석 자세히 보기 들어가면 어떤거 보여주려고 생각중이야?"

<!-- 9a315516 2026-11-23T15:46:25.921Z -->
[Hyunwoo Song, 11-24 00:46] "[Image #8] 이 막대기가 좀 부자연스러운데 평균 이하 평균 평균이상의 위치나 중간 눈금이나 뭔가 자연스럽게 수정해줄 수 있나 P13은 같이 준비하면 좋긴할듯"

<!-- 9a315516 2026-11-23T15:59:51.390Z -->
[Hyunwoo Song, 11-24 00:59] "이렇게 해보세요는 빼고 <div style=\"font-size: 13px; color: #4A5366; line-height: 1.5\">주황 점이 무효 횟수예요. 마지막 10초에 덜 내려간 횟수가 몰렸어요.</div> 이것도 이어서하는게 아니라 깊이나 팔꿈치에서 줄바꿈해서 두 문장으로 하는게 나은 것 같아 p13은 usb 연결해놨으니까 진행해보고"

<!-- 9a315516 2026-11-23T16:08:24.093Z -->
[Hyunwoo Song, 11-24 01:08] "[Image #9] 이 정보들도 C 탭의 성장에 그 기간 동안의 합 같은걸로 있으면 좋지 않을까? 난 C 탭이 좀 마음에드네"

<!-- 9a315516 2026-11-23T16:10:20.594Z -->
[Hyunwoo Song, 11-24 01:10] "<pasted_content id=\"0817\">
PR #86은 머지 보류입니다. 현재 HEAD fc151fe에서 GitHub 검사 7개가 모두 통과했고 충돌도 없습니다. 다만 독립 Codex 리뷰에서 사용자가 화면에 표시된 시간보다 먼저 탈락하는 문제를 확인해 CHANGES REQUESTED를 남겼습니다. PR 리뷰 댓글

매칭 후 55초에 두 번째 카메라가 열리면 두 휴대폰에는 세팅 시간 10초가 표시됩니다. 그런데 서버의 기존 60초 타이머가 먼저 만료돼 5초가 남은 상태에서 경기를 취소합니다. 양쪽 카메라가 열린 뒤에는 서버가 공지한 새 마감을 적용하고, 그 마감 직전에는 준비가 성공하며 마감 시에는 setup_timeout이 한 번만 발생하는지 회귀 테스트를 요청했습니다.

online_preparation_test.dart의 예외는 실제 diff를 확인해 기대 문구 두 줄에 한해 승인했습니다. 프로토콜 문서 수정안도 작성해 PR에 올렸습니다. 별도 문서 브랜치의 원격 생성은 GitHub 권한 오류로, 로컬 커밋은 해당 w
</pasted_content id=\"0817\">

 라는데? 코덱스 리뷰 있던 거 아니야?로컬 커밋은 해당 worktree의 훅 파일 누락으로 막혀 아직 main에는 반영되지 않았습니다. 리뷰해결하고 머지 요청하래"

<!-- 9a315516 2026-11-23T16:17:17.263Z -->
[Hyunwoo Song, 11-24 01:17] "머지뒤에 배포하자"

<!-- 9a315516 2026-11-23T16:18:12.721Z -->
[Hyunwoo Song, 11-24 01:18] "그리고 기록보관소를 운동일지라는 이름으로 바꾸고 성장을 전체로 바꾼다음에 전체랑 경기를 순서 바꾸는거 어떄?"

<!-- 9a315516 2026-11-23T16:52:56.713Z -->
[Hyunwoo Song, 11-24 01:52] "새 HEAD e75c7ec이고 main(ad8a6f7)도 merge해 뒀어요. 그리고 이거 메인에 머지했다는건 뭔소리지 여기에 대한 설명은? 그리고 기기 확인은 나중에 하자 내가 그 다른 사람이랑 코드 받아서 하고 알려줄게"

<!-- 9a315516 2026-11-23T16:55:57.862Z -->
[Hyunwoo Song, 11-24 01:55] "AI=>아케이드
나머지는 괜찮은 듯? 이라고 하는게 이게 AI 대전 없애고 그자리에 아케이드 모드 만든데 그러면 완전히 새 게임이라 기록도 좀 달라질것 같은데 그 pr 머지되고 우리 만드는게 낫지않나?"

<!-- 9a315516 2026-11-23T16:59:14.361Z -->
[Hyunwoo Song, 11-24 01:59] "p14는 그러면 어차피 그것도 아케이드 구현되고 해야하네"

<!-- 9a315516 2026-11-23T17:16:39.037Z -->
(Removed: an automatic context summary that the exporter read as a prompt; not typed by a person.)

[Hyunwoo Song, 11-24 02:21] "일단 pr만 올려놓고 머지 나중에 하라할까"

<!-- 9a315516 2026-11-24T06:02:46.551Z -->
[Hyunwoo Song, 11-24 15:02] "draft pr 올리면 돼 그러면 남은 작업들과 남은 작업들이 기다리고 있는 앞의 작업들이 뭐지? 표로 보여줘봐"

<!-- 9a315516 2026-11-24T06:35:22.839Z -->
[Hyunwoo Song, 11-24 15:35] "위키는 수정 해줬대 그 진영이형한테 물을 거는 그 데이터베이스 어디에 저장됐냐 아닌가? 그거 우리가 코드로 읽어오면 되지 않나? 리포트 진입도 시안 만들어야하나? 아니면 나중에 하는게 낫나"

<!-- 9a315516 2026-11-24T06:57:55.061Z -->
[Hyunwoo Song, 11-24 15:57] "1번은 우리가 진행하자"

<!-- 9a315516 2026-11-24T07:13:56.923Z -->
[Hyunwoo Song, 11-24 16:13] "지금 배포해도 상관없잖아"

<!-- 9a315516 2026-11-24T10:50:58.545Z -->
[Hyunwoo Song, 11-24 19:50] "pr 머지된것들 있는지 확인 ㄱ"

## 2026-11-24 · Hyunwoo Song · feat/iter5-telemetry
<!-- 9a315516 2026-11-23T17:21:10.403Z -->
[Hyunwoo Song, 11-24 22:08] "<pasted_content id=\"0817\">
@한상우  @송현우 
P6 텔레메트리·서버 복구 계획 초안 올렸어: ⧉ <artifact link redacted>

- 현우 (P17): 이벤트 사전 7개 정리해 뒀어. 튜토리얼, 자세 세팅, 매칭은 시작·끝 한 쌍씩이고 경기 종료(battle_finished)는 하나야. 사유 값은 앱과 대전 서버가 이미 쓰는 코드(setup_timeout, user_exit, SetupReason 등)를 그대로 썼어. 영상·관절 좌표·인증정보는 빼고, 같은 match_id 종료는 한 건으로 세. 구현하면서 이름이나 필드를 바꾸면 문서 표도 같이 고쳐 줘.
- 상우:
  - 알파는 헬스 체크와 재시작(목표 5분), 베타는 백업 복원과 수동 전환으로 나눴어. 전환은 고정 IP를 새 인스턴스로 옮기는 방식이라 앱은 다시 배포 안 해도 돼.
  - 지금은 자동 백업이 없고 배포 전 수동 백업만 있어. 매일 백업과 서버 밖 사본을 둘지, Lightsail 스냅샷이나 임시 인스턴스 비용을 쓸지는 네가 정해 줘.
  - 헬스 체크·백업 timer를 서버에 설치하는 것도 네 승인 받고 할게.
- 내일 P3 TA 미팅에서 확인할 것: RTO 30분, RPO 24시간, 보관 30일은 내 초안 값이야. 수집 지표와 보관 범위도 같이 물어볼게. 확인할 항목은 문서 맨 아래 \"미정 사항\" 표에 있어.

문서에서 바로 고치거나 댓글 달아 줘.
</pasted_content id=\"0817\">


<pasted_content id=\"0817\">
진영님, 알파는 장애 감지와 재시작, 베타는 백업 복원과 고정 IP 전환까지 검증하는 범위로 준비해 주세요. TA 미팅 전에는 세 가지만 보완하면 좋겠습니다.

텔레메트리(P17·송현우) — 이벤트는 제안한 7개로 충분합니다. 튜토리얼·자세 세팅·매칭은 시작 횟수를 분모로 두고 완료·취소·타임아웃을 구분해 주세요. 앱이 중간에 [profanity removed] 종료 이벤트가 없는 시도는 ‘종료 미관측’으로 따로 세면 됩니다. battle_finished는 두 기기가 같은 경기를 보고해도 match_id당 한 건이어야 합니다. 영상·관절 좌표·인증정보를 텔레메트리에서 제외한다는 기준도 유지해 주세요.

백업·복구(P6·박진영) — RPO 24시간을 목표로 한다면 배포 전 수동 백업만으로는 충족하기 어렵습니다. 매일 자동 백업하고 서버 밖에 사본 하나를 두는 안을 베타 기본안으로 제안합니다. 복원 시험은 별도 환경에서 하고, 로그인·기존 경기 기록 조회까지 성공한 시각을 남겨 주세요. 알파의 5분은 현재 서버에서 API 재시작 후 정상 응답까지, 베타의 30분은 장애 감지부터 대체 서버에서 앱 요청이 성공할 때까지로 구분해 주세요. 베타에서는 기존 앱으로 고정 IP에 재접속해 API와 대전 연결을 모두 확인하면 됩니다.

11월 25일 TA 미팅 — ① 이벤트 7개로 온보딩·매칭 이탈을 평가하기에 충분한지, ② 수동 전환과 실측 결과가 베타 failover 검증으로 충분한지, ③ RTO 30분·RPO 24시간이 적절한지, ④ 30일 보관이 원시 이벤트·집계 지표·DB 백업 중 어디에 필요한지 확인해 주세요. 헬스 체크·백업 타이머의 실행 주기와 실패 알림 대상, 스냅샷·임시 인스턴스의 예상 비용을 적어 주시면 운영 서버 적용 여부를 결정할게요.
</pasted_content id=\"0817\">

 라는데?"

<!-- 9a315516 2026-11-24T13:08:57.549Z -->
[Hyunwoo Song, 11-24 22:08] "읽어도 돼"

<!-- 9a315516 2026-11-24T13:11:47.508Z -->
[Hyunwoo Song, 11-24 22:11] "<pasted_content id=\"0817\">
GymRats P6 텔레메트리·서버 복구 계획
2026년 11월 24일 · @Someone · 상태: 초안 (PM 한상우 확인 전)
범위와 목표
P6는 두 가지를 정한다: P17이 그대로 구현할 텔레메트리 이벤트 사전과, P21이 리허설할 서버 복구 대응안. 복구는 단계별로 나눈다.
단계
대응
쓰는 곳
알파 (12/2~)
헬스 체크, 장애 감지, 프로세스 재시작
P21 재시작 리허설, P24 알파
베타 (P21 이후)
DB 백업·복원, 별도 환경으로 수동 전환
P21 복원·전환 리허설, P24 베타
수집할 지표와 보관 범위, 복구 목표 시간(RTO)과 허용 데이터 손실(RPO)은 이 문서의 초안 값을 11/25 P3 TA 미팅에서 확인한 뒤 확정한다. 확정 전 값은 모두 \"초안\"으로 표시한다.
텔레메트리 이벤트 사전
이벤트는 7개로 충분하다(PM 11/24). 튜토리얼·자세 세팅·매칭은 시작·끝 한 쌍이고 attempt_id로 이어 붙인다. 경기 종료는 대전 서버가 한 번 기록한다. 사유 값은 앱·대전 서버가 이미 쓰는 코드를 그대로 쓴다.
공통 필드 (모든 이벤트): event, event_id(UUID, 중복 제거용), ts(UTC ISO 8601), session_id(앱 실행마다 새 난수), app_version. 시작·끝 쌍에는 attempt_id(시도마다 새 UUID)를 더한다. 로그인 후 서버가 계정 id를 붙인다(앱은 보내지 않음).
이벤트
시점
추가 필드 (단위)
값
tutorial_started
튜토리얼 첫 페이지 표시
attempt_id, pages_total
정수
tutorial_finished
마지막 페이지 통과 또는 건너뛰기
attempt_id, result, duration_ms (ms), last_page
completed · skipped
setup_started
자세 세팅 화면 진입
attempt_id, exercise, mode
push_up · squat / bot · main · friend
setup_finished
준비 완료·시간 초과·나가기
attempt_id, result, duration_ms (ms), limit_ms (ms), last_reason
ready · timeout · cancelled / SetupReason: no_person, too_close, too_far, not_facing_forward, missing_parts, not_in_push_up, not_standing, phone_too_flat, phone_shaky
matching_started
온라인 대기열 참가(queue.join)
attempt_id, exercise, kind
main · friend
matching_finished
상대 찾음·취소·시간 초과·오류
attempt_id, result, wait_ms (ms)
found · cancelled · timeout · error
battle_finished
경기 종료 또는 취소, 대전 서버가 기록
match_id, end_reason, duration_ms (ms), 두 선수의 점수
completed · user_exit · opponent_exit · setup_timeout · ready_timeout · disconnect_timeout · both_disconnected · void
집계 규칙 (PM 11/24)
• 튜토리얼·자세 세팅·매칭은 *_started 횟수가 분모다. 끝 이벤트의 result로 완료·취소(건너뛰기)·타임아웃을 나눠 센다.
• 같은 attempt_id의 끝 이벤트가 없는 시도(앱이 중간에 꺼짐)는 종료 미관측으로 따로 센다. 분모 = 완료 + 취소 + 타임아웃 (+ 오류) + 종료 미관측.
• battle_finished는 match_id당 한 건이다. 두 기기가 같은 경기를 보내지 않도록 대전 서버가 판정 시점에 한 번만 기록하고, 저장 쪽에서도 match_id를 유일 키로 둔다.
이름과 값은 P17(송현우)이 구현하며 바꾸면 이 표를 함께 고친다. limit_ms는 지금 시험값 10초(10000)이다.
수집 원칙
페이로드에는 위 표의 필드만 담고, 카메라 영상·이미지·관절 좌표·인증 정보(토큰, 비밀번호, 이메일)는 넣지 않는다. 팀 개인정보 규칙(영상은 기기 밖으로 나가지 않음)과 P17 인수 기준을 그대로 따른다.
• 중복 종료: 같은 match_id의 battle_finished는 한 건으로 센다. 앱이 재시도로 여러 번 보내도 서버가 event_id와 match_id로 걸러낸다.
• 전송: 앱이 이벤트를 모아 로그인된 상태로 Django API에 보낸다. 실패하면 기기에 잠시 쌓아 두었다가 다음 전송 때 함께 보낸다(최대 개수는 P17에서 정함).
• 저장 위치: 지금 쓰는 SQLite(/srv/gymrats/data/gymrats.db)에 이벤트 테이블을 둔다. 별도 서비스는 두지 않는다(2 GB 서버 하나).
• 보관 기간 (초안): 알파·베타 분석이 끝나는 12/4 이후 30일. 기간과 범위는 P3에서 TA와 확인한다.
알파 대응: 헬스 체크와 재시작
알파는 장애 감지와 재시작까지 검증한다. 목표 5분(초안)은 현재 서버에서 API를 재시작한 순간부터 /api/health가 다시 정상 응답할 때까지다. 두 서비스 모두 비정상 종료 시 3초 뒤 자동 재시작하고 부팅 때 켜지므로, 빠진 것은 \"답이 없는\" 상태의 감지다.
대상
현재 구성 (11/24 확인)
헬스 체크
Django API gymrats-api
gunicorn 2 workers, 127.0.0.1:8000, Restart=on-failure 3 s
GET /api/health → {\"status\":\"ok\"}
대전 서버 gymrats-battle
Dart, 127.0.0.1:8080, 메모리 상한 256 MB, Restart=on-failure 3 s
GET :8080/health → {\"status\":\"ok\",\"protocol\":1}
nginx
80·443, /api/ → 8000, /ws/v1/battle → 8080
밖에서 /api/health 200, wss 토큰 없이 401
TLS 인증서
짧은 수명 IP 인증서, gymrats-cert-renew.timer로 갱신
만료일 확인
감지 (초안)
감지
주기
실패 판정
실패 시 동작
알림 대상
헬스 체크 timer (서버 안, systemd)
1분
API /health, 대전 :8080/health 3번 연속 실패
그 서비스만 재시작, /srv/gymrats/logs에 기록
기록 + 아래 경보
Lightsail 경보 (서버 밖)
5분
상태 확인 실패 또는 CPU 과부하
사람이 확인
한상우, 박진영 (콘솔 연락처 이메일)
알파 세션 중 수동 확인
세션 동안 수시
Mac에서 /api/health 실패
재시작 절차 시작
팀 채팅
서버 전체가 멈추면 서버 안의 timer도 멈추므로, 그 경우는 Lightsail 경보와 수동 확인으로 잡는다. 주기와 판정 횟수는 초안이다.
재시작 절차 (수동)
1.  어느 쪽이 죽었는지 두 /health로 확인한다.
2.  journalctl -u <서비스> -n 50으로 원인을 남긴다.
3.  그 서비스만 sudo systemctl restart <서비스>. 다른 팀원 서비스는 건드리지 않는다.
4.  두 /health와 밖의 /api/health를 다시 확인한다.
5.  감지 시각·복구 시각·원인을 팀 채팅과 progress에 남긴다.
대전 서버 재시작은 진행 중인 경기를 끊는다. 배포로 인한 재시작은 알파 세션 사이에만 한다.
베타 대응: 백업 복원과 수동 전환
베타는 백업 복원과 고정 IP 전환까지 검증한다. 목표 30분(RTO 초안)은 장애를 감지한 순간부터 대체 서버에서 앱 요청이 성공할 때까지다. 허용 데이터 손실은 최대 24시간이다(RPO 초안). 지금의 배포 직전 수동 백업(/srv/gymrats/data/backups, 6개)만으로는 24시간을 지킬 수 없어, 매일 자동 백업 + 서버 밖 사본 하나를 베타 기본안으로 한다(PM 11/24).
백업 (초안)
무엇
언제
어디
보관
실패 알림
SQLite DB (지금 약 8 MB), SQLite 온라인 백업 API, 백업 timer
매일 04:00 KST + 배포 직전
/srv/gymrats/data/backups
7일치
실패·무결성 오류를 /srv/gymrats/logs에 남기고 다음 헬스 체크에서 한상우·박진영에게
서버 밖 사본: Lightsail 자동 스냅샷 (인스턴스 디스크 전체, 위 DB 백업 포함)
매일, DB 백업 뒤 시각
인스턴스와 따로 보관되는 Lightsail 스냅샷
최근 7개
Lightsail 콘솔 알림 (한상우·박진영)
베타 직전 수동 스냅샷
베타 빌드 배포 직전 1회
같음
베타 종료까지
—
.env는 백업에 넣지 않는다. 비밀 값은 복원 때 담당자가 다시 넣는다.
수동 전환 절차 (초안)
1.  장애를 확인하고 팀 채팅에 전환을 알린다(서버 정지·플랜 변경은 사전 공지 규칙).
2.  마지막 스냅샷으로 새 Lightsail 인스턴스를 만든다(또는 새 인스턴스에 코드를 배포하고 DB 백업을 복원).
3.  .env를 다시 넣고, DB 무결성(pragma integrity_check)과 migrate --check를 확인한다.
4.  gymrats-api, gymrats-battle, nginx를 켜고 새 인스턴스의 임시 IP로 헬스 체크한다.
5.  고정 IP [REDACTED:custom_term]를 새 인스턴스로 옮긴다. 앱의 주소는 그대로라 앱을 다시 배포하지 않는다. IP 인증서는 새로 받거나 tls를 옮긴다.
6.  밖에서 기존 기록 조회·신규 로그인·매칭·결과 저장을 확인하고, 복원된 데이터 시각을 남긴다.
베타 검증은 기존 앱으로 고정 IP에 다시 접속해 API와 대전 연결(wss)을 모두 확인한다. 복원 시험은 운영 서버가 아닌 별도 환경에서 하고, 로그인과 기존 경기 기록 조회가 성공한 시각을 남긴다.
예상 비용 (AWS 공식 요금, 2026-11-24 기준, 서울 리전에서는 달라질 수 있음)
항목
단가
우리 경우 (추정)
Lightsail 스냅샷
$0.05 / GB-월, 두 번째부터는 바뀐 부분만
쓰는 디스크 약 4.5 GB → 첫 스냅샷 약 $0.23/월, 7개 보관해도 월 $1 안팎
임시 인스턴스 (Linux 2 GB, 공인 IPv4)
$12 / 월 상한, 시간 단위 과금
리허설 3시간 약 $0.05, 끝나면 삭제
DB 백업 (서버 안)
추가 비용 없음 (디스크 60 GB 중 4.5 GB 사용)
8 MB × 7일
출처: Lightsail 요금, 인스턴스 번들, 과금 FAQ. 켜기 전 PM이 운영 서버 적용 여부를 정한다.
P21 리허설 체크리스트
P21(박진영, 12/2)은 운영 서버가 아닌 테스트 환경에서 아래를 실행하고, 측정값을 베타 전에 PM에게 넘긴다. 합격 기준은 위 초안 목표를 따르고, P3 뒤 확정값으로 바꾼다.
리허설
환경
측정
합격 기준 (초안)
API 재시작
현재 서버, 알파 세션 사이
재시작 순간 → /api/health 정상 응답
5분 안
대전 서버 재시작
현재 서버, 알파 세션 사이
재시작 → :8080/health, 끊긴 경기 처리
5분 안, 끊긴 경기가 기록을 깨지 않음
답 없는 프로세스 감지
테스트 환경
멈춤 → 헬스 체크 timer 재시작
3분 안 (1분 × 3회)
DB 백업 복원
별도 환경
복원 소요 시간, 복원된 데이터 시각, 로그인·기존 경기 기록 조회 성공 시각
무결성 ok, 마지막 백업 시각까지 있음
고정 IP 수동 전환
임시 인스턴스
장애 감지 → 기존 앱의 API·대전 요청 성공
30분 안
전환 뒤 확인:
[ ] 기존 계정의 기록 조회
[ ] 신규 로그인 (Google)
[ ] 메인 매칭과 친구 대전 짝짓기
[ ] 경기 결과 저장
운영 서버에서는 강제 종료를 하지 않는다. 테스트 환경(임시 인스턴스 또는 로컬)은 P21 시작 전에 PM과 정한다.
미정 사항
11/25 P3 TA 미팅에서 확인할 것 (박진영, 한상우)
1.  이벤트 7개로 온보딩·매칭 이탈을 평가하기에 충분한가
2.  수동 전환과 실측 결과가 베타 failover 검증으로 충분한가
3.  RTO 30분·RPO 24시간이 적절한가
4.  30일 보관이 원시 이벤트·집계 지표·DB 백업 중 어디에 필요한가
그 밖의 미정 사항
언제
담당
이벤트 이름·필드 확정, 이벤트 API 모양
P17 착수 전
송현우
헬스 체크·백업 timer, Lightsail 자동 스냅샷·경보를 운영 서버에 적용할지
위 비용·주기 보고
한상우 결정, 박진영 설치
P21 테스트 환경 (임시 인스턴스)
P21 시작 전
박진영, 한상우
</pasted_content id=\"0817\">"

<!-- 9a315516 2026-11-24T13:20:55.633Z -->
[Hyunwoo Song, 11-24 22:20] "저거 pr14 먼저 못끝내니까 17먼저 해서 pr올리고 머지하는게 낫지 않나? telementry가 하려는게 그냥 이벤트들 애널리틱스로 모으는거지? 어디에 어떻게 너을지는 정해졌고?"

<!-- 9a315516 2026-11-24T13:28:16.123Z -->
[Hyunwoo Song, 11-24 22:28] "진행해"

## 2026-11-25 · Hyunwoo Song · feat/iter5-telemetry

<!-- 9a315516 2026-11-24T15:08:14.322Z -->
[Hyunwoo Song, 11-25 00:08] "코덱스 리뷰 확인해 지금 이미 pr 열린거 아니야? 아직 pr 못해?"

<!-- 9a315516 2026-11-24T15:12:36.276Z -->
[Hyunwoo Song, 11-25 00:12] "그렇게 진행해"

## 2026-11-25 · Hyunwoo Song · feat/iter5-auto-setup
<!-- 9a315516 2026-11-24T13:08:10.048Z -->
[Hyunwoo Song, 11-24 22:08] "<pasted_content id=\"0817\">
@한상우  @송현우 
P6 텔레메트리·서버 복구 계획 초안 올렸어: ⧉ https://claude.ai/artifact/WWLaDyg8K12U8i38jB5pYm

- 현우 (P17): 이벤트 사전 7개 정리해 뒀어. 튜토리얼, 자세 세팅, 매칭은 시작·끝 한 쌍씩이고 경기 종료(battle_finished)는 하나야. 사유 값은 앱과 대전 서버가 이미 쓰는 코드(setup_timeout, user_exit, SetupReason 등)를 그대로 썼어. 영상·관절 좌표·인증정보는 빼고, 같은 match_id 종료는 한 건으로 세. 구현하면서 이름이나 필드를 바꾸면 문서 표도 같이 고쳐 줘.
- 상우:
  - 알파는 헬스 체크와 재시작(목표 5분), 베타는 백업 복원과 수동 전환으로 나눴어. 전환은 고정 IP를 새 인스턴스로 옮기는 방식이라 앱은 다시 배포 안 해도 돼.
  - 지금은 자동 백업이 없고 배포 전 수동 백업만 있어. 매일 백업과 서버 밖 사본을 둘지, Lightsail 스냅샷이나 임시 인스턴스 비용을 쓸지는 네가 정해 줘.
  - 헬스 체크·백업 timer를 서버에 설치하는 것도 네 승인 받고 할게.
- 내일 P3 TA 미팅에서 확인할 것: RTO 30분, RPO 24시간, 보관 30일은 내 초안 값이야. 수집 지표와 보관 범위도 같이 물어볼게. 확인할 항목은 문서 맨 아래 \"미정 사항\" 표에 있어.

문서에서 바로 고치거나 댓글 달아 줘.
</pasted_content id=\"0817\">


<pasted_content id=\"0817\">
진영님, 알파는 장애 감지와 재시작, 베타는 백업 복원과 고정 IP 전환까지 검증하는 범위로 준비해 주세요. TA 미팅 전에는 세 가지만 보완하면 좋겠습니다.

텔레메트리(P17·송현우) — 이벤트는 제안한 7개로 충분합니다. 튜토리얼·자세 세팅·매칭은 시작 횟수를 분모로 두고 완료·취소·타임아웃을 구분해 주세요. 앱이 중간에 [profanity removed] 종료 이벤트가 없는 시도는 ‘종료 미관측’으로 따로 세면 됩니다. battle_finished는 두 기기가 같은 경기를 보고해도 match_id당 한 건이어야 합니다. 영상·관절 좌표·인증정보를 텔레메트리에서 제외한다는 기준도 유지해 주세요.

백업·복구(P6·박진영) — RPO 24시간을 목표로 한다면 배포 전 수동 백업만으로는 충족하기 어렵습니다. 매일 자동 백업하고 서버 밖에 사본 하나를 두는 안을 베타 기본안으로 제안합니다. 복원 시험은 별도 환경에서 하고, 로그인·기존 경기 기록 조회까지 성공한 시각을 남겨 주세요. 알파의 5분은 현재 서버에서 API 재시작 후 정상 응답까지, 베타의 30분은 장애 감지부터 대체 서버에서 앱 요청이 성공할 때까지로 구분해 주세요. 베타에서는 기존 앱으로 고정 IP에 재접속해 API와 대전 연결을 모두 확인하면 됩니다.

11월 25일 TA 미팅 — ① 이벤트 7개로 온보딩·매칭 이탈을 평가하기에 충분한지, ② 수동 전환과 실측 결과가 베타 failover 검증으로 충분한지, ③ RTO 30분·RPO 24시간이 적절한지, ④ 30일 보관이 원시 이벤트·집계 지표·DB 백업 중 어디에 필요한지 확인해 주세요. 헬스 체크·백업 타이머의 실행 주기와 실패 알림 대상, 스냅샷·임시 인스턴스의 예상 비용을 적어 주시면 운영 서버 적용 여부를 결정할게요.
</pasted_content id=\"0817\">

 라는데?"

<!-- 9a315516 2026-11-24T15:50:40.821Z -->
[Hyunwoo Song, 11-25 00:50] "확인해봐"

<!-- 9a315516 2026-11-25T02:50:28.339Z -->
[Hyunwoo Song, 11-25 11:50] "@송현우 현우님, P17 PR #96을 main에 머지했습니다. 머지 커밋은 9af9717입니다.

이제 main 기준으로 DB 백업 → Django 마이그레이션 → 대전 서버 재배포 순서로 진행해 주세요. 배포가 끝나면 서버 헬스 체크와 텔레메트리 이벤트 수집을 확인하고, 배포한 커밋과 확인 결과를 공유해 주세요. 이거 하라는데 그러면폰에다운도 받아야하나?"

<!-- 9a315516 2026-11-25T02:53:50.208Z -->
[Hyunwoo Song, 11-25 11:53] "폰 연결했어 체크하는 김에 저번에 올린 pr도 같이 체크하자 그리고 아마 다른 pr(우리가 기다리고 있던)도 올라왔을텐데 확인하고 이어서 하면 되지 않나?"

<!-- 9a315516 2026-11-25T03:30:39.420Z -->
[Hyunwoo Song, 11-25 12:30] "너가 해야할거 다해"

<!-- 9a315516 2026-11-25T03:47:38.311Z -->
[Hyunwoo Song, 11-25 12:47] "<pasted_content id=\"0817\">
[송현우] [오후 12:39] 생각해보니까
[송현우] [오후 12:39] 매칭 잡히면 자세세팅 시작
[송현우] [오후 12:39] 이거 누르는 것도 빼고 그냥
[송현우] [오후 12:39] 매칭 잡히면 3초 정도 있다가 바로 자세세팅 시작되게 해야겠네
</pasted_content id=\"0817\">

 이렇게 바꾸는 건 어때? 추가 의견인데. 뭔말인지 이해했나?"

<!-- 9a315516 2026-11-25T03:59:06.973Z -->
[Hyunwoo Song, 11-25 12:59] "<pasted_content id=\"0817\">
현우님, 좋아요! 이 작업은 현우님이 맡아주세요. #91이 머지된 뒤 최신 `main`에서 시작해 주시면 돼요.

온라인 대전(메인 매치·친구 대전)에서 매칭이 잡히면 VS 화면에 **‘3초 후 자세 세팅을 시작해요’**와 `3 → 2 → 1`을 보여주고, 버튼 없이 자동으로 넘어가는 걸로 해요. 카운트다운 중 상대가 나가면 기존 취소 흐름으로 돌아가고, 세팅 화면이 두 번 열리지 않는지도 테스트 부탁드려요.

두 기기에서 VS 화면이 뜨는 시각이나 카메라가 열리는 시각은 조금 다를 수 있으니, 3초는 전환 안내용으로만 쓰면 좋겠어요. **세팅 제한 10초는 지금처럼 양쪽 카메라가 열린 뒤 서버가 정한 마감 시각을 기준으로** 유지해 주세요. 먼저 이 흐름으로 적용하고, 이후 `setup_timeout` 비율을 보고 시간 조정 여부를 같이 정해요.
</pasted_content id=\"0817\">

 작업 진행하면 될듯"

<!-- 9a315516 2026-11-25T04:30:51.660Z -->
[Hyunwoo Song, 11-25 13:30] "근데 어차피 아케이드에 카운트 다운 안넣을거니까 상관없지 않나?"

<!-- 9a315516 2026-11-25T04:36:39.115Z -->
[Hyunwoo Song, 11-25 13:36] "[Image #3] 그리고 자바 이거 너꺼야? 꺼도 돼?"

<!-- 9a315516 2026-11-25T05:09:56.974Z -->
[Hyunwoo Song, 11-25 14:09] "\"d:\Users\[REDACTED:username]\Downloads\gymrats-iter5-harness-[REDACTED:custom_term] (3).zip\" 진행"

<!-- 9a315516 2026-11-25T05:28:47.674Z -->
[Hyunwoo Song, 11-25 14:28] "화면 낭독 원래 있던건가? 우리가 추가로 넣은거 아니지?"

<!-- 9a315516 2026-11-25T05:29:18.495Z -->
[Hyunwoo Song, 11-25 14:29] "남겨둬 그러면"

<!-- 9a315516 2026-11-25T07:50:36.574Z -->
[Hyunwoo Song, 11-25 16:50] "머지된 pr 확인해봐"

<!-- 9a315516 2026-11-25T07:53:44.200Z -->
[Hyunwoo Song, 11-25 16:53] "그러면 진행하면 될 것 같은데"
