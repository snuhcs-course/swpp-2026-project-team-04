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

## 2. Prompt History
[Jinyoung Park, 11-23] "task 수행해. 근데 회원가입할때 구글이랑 카카오톡 둘다 지원하게 해주고, 회원가입시 … 이런식으로 키, 몸무게 추가 정보도 받게 해줘."
[Jinyoung Park, 11-24] "카카오도, google가입도 닉네임은 필요함"
[Jinyoung Park, 11-24] "그러면 카카오 빼자 ui에서도"
[Jinyoung Park, 11-24] "문구만 바꾸고, 서버 재배포함?"
Full list: `ishlove77-Prompt-Log.md`.

## 3. Problems and How They Were Caught
- The reviewer subagent returned CHANGES_REQUESTED three times on P7 (logged in the progress file's Review log):
  the server accepted `NaN` for height and weight (DRF `FloatField` passes min/max) and stored it before a 500 — fixed
  with a finite check and NaN/Infinity tests; the design-doc note named `google-auth` though the code used PyJWT; the
  nickname step re-showed the rules for an account made meanwhile (fixed to use the `created` flag); and a nickname
  suggestion the server sent but the app could not read (dropped).
- Claude ran `dart format` over whole folders twice and `flutter pub add` changed `analysis_options.yaml`, touching
  files outside P7; the ownership guard flagged them and they were restored before committing.
- A first Google Cloud form lost its input when typing reached the console's keyboard shortcuts; Claude noticed the
  page had changed, checked that nothing was saved, and redid the step field by field.

## 4. Revisions and Decisions
- Kakao: built (user, 11-23) → PM excluded it from Iteration 5 (11-24) → removed from UI and code (user, 11-24).
- Google nickname: first taken from the Google profile (fallback "GymRat") → the user asked for a chosen nickname, so
  the server answers `signup_required` and creates nothing until the nickname step.
- Body info endpoint is `POST /users/me/body` because the app's `ApiClient` has no PATCH (kept out of P7's scope).

## 5. Manual Fixes
None observed this step: every code change was made by Claude Code and checked by the user.

## 6. Reflection
TODO(Jinyoung Park): what worked and what to change, at the end of the iteration.
