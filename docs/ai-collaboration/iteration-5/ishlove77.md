# AI collaboration notes: Iteration 5, Jinyoung Park (ishlove77)
Status: draft (iteration open)
Written by: Jinyoung Park
Tools used: Claude Code (Opus 5.5)

These notes cover Jinyoung Park's Iteration 5 steps, items a–f per the guideline; the PM merges them into the one-page
team report. Prompt log: `ishlove77-Prompt-Log.md` (filled by the course Session Exporter before every push).

## 1. Where AI Was Used
### P7 `feat/iter5-google-auth` (team plan #1, Google sign-in and sign-up, 2026-11-23 ~ 11-24)
- Server: `server/accounts/google_auth.py` (whole file: ID token check with Google's keys), the Google login view,
  nickname rule and body info view in `server/accounts/views.py`, `serializers.py`, `models.py`, migration
  `0002_social_login_and_body_info.py`, routes, settings and `.env.example` placeholders, and the new tests in
  `server/tests/test_auth.py`: Claude Code (commit `385ea0b`).
- App: `lib/services/auth/google_sign_in_service.dart`, the Google parts of `auth_repository.dart` and
  `in_memory_auth_repository.dart`, `lib/viewmodels/body_info_viewmodel.dart`, `social_signup_viewmodel.dart`, the
  Google and body info parts of `auth_viewmodel.dart` and `login_viewmodel.dart`, `lib/screens/body_info_screen.dart`,
  `social_signup_screen.dart`, the Google button in `login_screen.dart`, the routes in `main.dart`, and every P7 test
  under `gymrats_app/test`: Claude Code (commit `8db6d45`). The logout notice in `settings_screen.dart`: Claude Code
  (commit `35dadd2`).
- Kakao login (app service, SDK, Android redirect, server check and `/auth/kakao`) was built by Claude Code on 11-23 at
  the user's request and removed on 11-24 after the PM fixed P7 to Google only; it is not in the commits.
- Local test setup outside the repo (`~/gymmouse-localtest/run_local.sh`: the working-tree Django server on the Mac and
  an app copy pointed at it) and an iOS build of the working tree on the user's phone: Claude Code.
- Google Cloud setup (project, OAuth consent screen, Android and web clients, test user) through Claude in Chrome on the
  user's own account; the user signed in, approved the account choice with the PM, and agreed to the data policy.
- Not used: the body info screen layout (the PM's chat sketch), Kakao's inclusion and removal, Google only, local test
  before merge and deploy after merge (the PM's decisions), the nickname step for Google accounts and the logout
  wording (the user's requests).

### P9 `feat/iter5-friend-battles` (team plan #3, friends and friend battles, 2026-11-24)
- Server: `server/accounts/friends_views.py` and `friends_urls.py` (whole files: friend codes, requests, battle
  invites), the `FriendRequest` and `FriendBattleInvite` models in `server/accounts/models.py`, migration
  `0003_friends.py`, the `/friends` route in `server/gymrats/urls.py`, and `server/tests/test_friends.py`: Claude Code.
- Battle server: the optional `friend_id` in `queue.join` and the pairing rule in `server/lib/battle_server.dart`,
  `isBattleFriendId` in `lib/shared/battle_protocol.dart`, `friendId` in `online_battle_session.dart`, and
  `test/services/online/friend_battle_test.dart`: Claude Code.
- App: `lib/services/friends/friend_repository.dart`, `lib/viewmodels/friends_viewmodel.dart`,
  `lib/screens/friends_screen.dart` (whole files, including the app-wide invite banner), the 친구와의 대전 row in
  `play_screen.dart`, the friend waiting room in `online_lobby_screen.dart`, the friend code row in
  `settings_screen.dart`, the routes, provider and banner wiring in `main.dart`, and the P9 tests: Claude Code.
- Manual checks on the Android emulator against local servers, with a throwaway Dart script outside the repo playing
  the friend's side on the battle server: Claude Code (adb taps and screenshots), watched and partly tapped by the user.
- Not used: friend code format, the 1-minute invite, the entry order (PM decisions), the 친구와의 대전 row replacing
  the play-again row, removing the rule line, and the app-wide banner with 거절 · 수락 (the user's decisions on the
  emulator).

### P10 `feat/iter5-skill-matching` (team plan #6, simulated users and skill-based matchmaking, 2026-11-27)
- Battle server: `server/lib/skill_matchmaker.dart` and `server/lib/simulated_player.dart` (whole files: median of the
  latest 5 battles, sorted index with binary search, cost measurement, the simulated opponent), the 15 s assignment,
  `accept_virtual`, `match.virtual` and the estimate refresh in `server/lib/battle_server.dart`, `loadSkills` in
  `server/lib/result_store.dart`: Claude Code.
- Server: `SkillsView` (`POST /internal/skills`) in `server/matches/internal.py`, its route, and
  `server/tests/test_skills.py`: Claude Code.
- App: `battleVirtualWait`/`battleVirtualOpponent` in `lib/shared/battle_protocol.dart`, `OnlinePhase.virtualAssigned`
  and `VirtualOpponent` in `online_battle_session.dart`, `SimulatedUserPace` in `bot_matchmaker.dart`, the simulated
  opponent's versus screen and AI battle in `online_lobby_screen.dart`, the one-line `found` case in
  `telemetry_service.dart`, every P10 test, and `docs/iteration-5/matchmaking.md`: Claude Code.
- Manual check on the Android emulator against local Django and battle servers with a throwaway database: Claude Code
  (adb taps and screenshots).
- Not used: the estimate rule (median of the latest 5), real players first with no skill limit, the 15 s wait, and
  showing the copied account's nickname (the user's decisions); the scope exceptions (PM approval).

## 2. Prompt History
[Jinyoung Park, 11-23] "task 수행해. 근데 회원가입할때 구글이랑 카카오톡 둘다 지원하게 해주고, 회원가입시 … 이런식으로 키, 몸무게 추가 정보도 받게 해줘."
[Jinyoung Park, 11-24] "카카오도, google가입도 닉네임은 필요함"
[Jinyoung Park, 11-24] "그러면 카카오 빼자 ui에서도"
[Jinyoung Park, 11-24] "문구만 바꾸고, 서버 재배포함?"
[Jinyoung Park, 11-24] "friend추가하는 기능은 닉네임으로 추가?"
[Jinyoung Park, 11-24] "최근 설정으로 다시 하기 대신에 친구와의 대전으로 이름 바꿔서 저기 배치해주고 30초, 점수 높은쪽 승리 이거는 뺴자"
[Jinyoung Park, 11-24] "상대방이 대전 걸면 위의 친구가 대전을 신청했어요 이런식으로 뜨게 하면 안된 ㅏ"
[Jinyoung Park, 11-27] "유져의 실력 추정치는 최근 5개의 경긱 각가을 평균을 구하고 그것의 median으로 해서 평가를 좀 해줘. 그리고 그 user의 닉네임이 배틀시에 떠야함. …"
[Jinyoung Park, 11-27] "일단 바로 실제 유저 있으면 매칭 시켜 그다음에 없을때 가상 유저만 실력 비슷한 유저로(즉, 실제 유저는 바로 바로 매칭시켜()"
[Jinyoung Park, 11-27] "실제 유저 대기 시간 15초"
Full list: `ishlove77-Prompt-Log.md`.

## 3. Problems and How They Were Caught
- P10: the first design could not see bot battles at all (the battle server only knows online results), so the
  estimates needed a Django endpoint outside P10's files; Claude stopped and asked, and the PM approved the exception.
- P10: the reviewer subagent returned CHANGES_REQUESTED: a search ending with a simulated opponent never finished its
  P17 telemetry attempt (Claude had left it as a TODO with `_matching = null`), and the design-doc changes were missing.
  Claude's own lobby test for that case checked the key `name` instead of `event`, so it passed while checking nothing;
  rewritten to assert one `found`. Telemetry fixed after a second PM-approved one-line exception.
- P10: the Codex review of `22ad600` found that `SkillIndex.nearest` broke its own documented tie rule on the lower
  side (largest id instead of smallest). Claude's random full-scan test compared only distances, so it missed this;
  the test now checks the chosen id and uses half-step skills to force ties.
- P10: the next Codex review (`6f14022`) found the same tie rule still wrong for multi-digit ids (`"10"` sorts before
  `"2"` as text); Claude's tests used ids that hid it. Ids now compare as numbers, with a test using 2, 10 and 100.
- P10: the lobby disposed the online session inside its own listener call (assertion "dispose() called during
  notifyListeners()"), caught by the first widget-test run; the release now runs in a microtask.
- P10: the first lobby tests used `pumpAndSettle`, which ran the 5 s warning and the 3 s countdown and left the versus
  screen before the check; found with a debug print and replaced by explicit pumps.

- The reviewer subagent returned CHANGES_REQUESTED three times on P7 (logged in the progress file's Review log):
  the server accepted `NaN` for height and weight (DRF `FloatField` passes min/max) and stored it before a 500 — fixed
  with a finite check and NaN/Infinity tests; the design-doc note named `google-auth` though the code used PyJWT; the
  nickname step re-showed the rules for an account made meanwhile (fixed to use the `created` flag); and a nickname
  suggestion the server sent but the app could not read (dropped).
- Claude ran `dart format` over whole folders twice and `flutter pub add` changed `analysis_options.yaml`, touching
  files outside P7; the ownership guard flagged them and they were restored before committing.
- A first Google Cloud form lost its input when typing reached the console's keyboard shortcuts; Claude noticed the
  page had changed, checked that nothing was saved, and redid the step field by field.

- P9: the reviewer subagent approved twice with Minor findings, fixed in the same step: opposite friend requests
  sent at the same moment could create two rows (now one unique constraint on the unordered pair, with a race test); a
  failed search left the invite open so the friend waited for nothing (the lobby now takes it back); lime filled
  buttons in list rows (outlined now). Out of P9's scope and handed to the PM: the token test list and the protocol doc.
- P9: Claude first planned to add `friendId` to the lobby's session factory type, which broke tests outside P9
  (`test/main_test.dart`); caught by `flutter analyze`, changed to a field set before `connect`.
- P9: Claude added an ownership exception for a moved test file without asking; the harness's permission check blocked
  it, and the user approved it explicitly before it was recorded.
- P9: Claude again formatted whole folders (`dart format lib test`), touching six files outside P9 twice; seen in
  `git status` and restored both times.
- P9: during the emulator check Claude reported three unexplained actions (a decline, an accept followed by a cancel,
  an exit dialog) as possible app bugs; they were the user tapping the emulator at the same time. Claude asked before
  changing code, and set up touch display and a hardware input log to tell the two apart.

- P9: the automatic Codex review of PR #95 found two P2 issues neither the reviewer subagent nor the emulator check
  had caught: two answers to the same friend request at once could both succeed and delete the new friendship (the
  code read, then wrote; `select_for_update` does nothing on the SQLite production database), and two friends who
  invited each other at once were paired but left both invites open, so a stale alert could start another lobby
  after the battle. Fixed with conditional writes and by taking back an open invite on pairing, with race tests.

- P9: the second Codex review (`f752b07`) found three more P2 issues: two invites sent at once from two phones could
  both stay open; the dot on the 친구와의 대전 row never refreshed while 게임 시작 stayed open; and a short tag such
  as `헬창#2` still found `헬창#0002`, against the PM's four-digit rule. Claude had applied the four-digit rule only
  to how the code is shown, not to how it is parsed. Fixed with a database constraint and retry, a 5 s refresh, and a
  four-digit parse, each with tests.

- P9: the third Codex review (`851cc40`) found that a 수락 still in flight when the account signs out opened the
  waiting room over the signed-out app. Fixed by dropping answers that come back after a sign-in change, with tests.

- P9: the fourth Codex review (`1f41796`) found a read that could show one account's invites to the next account,
  and that the pairing cleanup from the first round could still cancel an invite the friend had just accepted. The
  reviewer subagent had flagged that second case as unlikely and Claude kept it with a test; Codex showed it could end
  the friend's waiting room, so the cleanup now lets the server decide (`if_pending`).

- P9: the fifth Codex review (`72a9faa`) found a second path to the same cancel-after-accept problem (an invite
  created after the pairing) and that a nickname with a line break, allowed at sign-up, made a friend code that could
  not be read back. Each round of fixes so far opened a narrower case nearby; the friend-battle cleanup now always
  lets the server decide.

- P9: the sixth Codex review (`afae806`) found over-padded tags still resolving (the four-digit fix of round two
  checked only the minimum) and a late 수락 opening a friend lobby over another battle. Both fixed with tests.

- P9: the seventh Codex finding (two invites to one person accepted at once) was first answered as "won't fix" under
  the user's new rule to fix only what users can realistically hit; the PM then asked for it in this PR with a server
  regression test. Fixed with a per-person accept hold.

- P9: the Codex review after the PM-requested fix (`888db67`) found the hold still had gaps (the inviter's other
  battle; a hold shorter than a slow setup) and that a network error on 수락 lost the banner for good. The 35 s hold
  was Claude's choice, sized to the app's pairing timeout rather than the battle server's limits; it is now 2 minutes
  and released by the app when the battle ends.

## 4. Revisions and Decisions
- P10 matchmaking: task.md asked for the smallest expected skill gap among real players with a P5 tolerance → the user
  chose real players at once (FIFO) and skill only for the simulated opponent after 15 s, estimated as the median of the
  latest 5 battles.
- P10 data source: battle-server-only estimates (online results only, lost on restart) → Django `/internal/skills`
  read at start and every 5 minutes (user chose option A, PM approved).
- P10 simulated battle: played on the phone as an AI battle, because the P11 saver writes a row for both players of
  an online battle and would put the battle in the copied account's history.

- Kakao: built (user, 11-23) → PM excluded it from Iteration 5 (11-24) → removed from UI and code (user, 11-24).
- Google nickname: first taken from the Google profile (fallback "GymRat") → the user asked for a chosen nickname, so
  the server answers `signup_required` and creates nothing until the nickname step.
- Body info endpoint is `POST /users/me/body` because the app's `ApiClient` has no PATCH (kept out of P7's scope).
- P9 friend search: nickname only (nicknames repeat) → `nickname#tag` friend code with the account id as the tag
  (user, then PM: at least 4 digits).
- P9 entry: online card → 메인 매치 / 친구와 1v1 sheet (PM) → also a top-right friends button (user) → button removed,
  the 친구와의 대전 row replaces 최근 설정으로 다시 하기, the online card is the main match again, the sheet removed
  (user, after seeing it on the emulator; the PM is told).
- P9 one battle at a time: Codex finding left with a reasoned reply (user: fix only what is needed) → the PM asked to
  fix it in this PR (one confirmed accept per person, 409 `invite_busy`, the unmatched inviter's room ends at once).
- P9 invites: a friend left waiting after an accepted invite → either player may cancel an accepted invite, both
  waiting rooms read it every 2 s, and an accepted invite not paired within 30 s ends the wait.

## 5. Manual Fixes
None observed in P7, P9 or P10: every code change was made by Claude Code and checked by the user.

## 6. Reflection
TODO(Jinyoung Park): what worked and what to change, at the end of the iteration.
