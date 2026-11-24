# Testing notes – Iteration 5 – Woohyun Song

Per-push Results for my Iteration 5 steps, in the Testing Documentation format. The PM merges them into
`docs/testing/Testing-Documentation.md` (P26).

## Results

#### 2026-11-23 · code at commit `141c8df` · step A2 `codex/iter5-arcade-stages` (Build arcade stage rules; team order #8 before the PM's renumbering)
The arcade (P16 before the PM's renumbering) is split into five steps. A2 is the arcade's values and rules, with no
screen:
- **Data:** the 4 floors, 24 stages and 16 AI levels of the design hand-off `arcade_data.json` (version arcade-1), as
  Dart constants (`ArcadeCatalog`, `ArcadeAiLevel`).
- **Bot:** `BotOpponent` takes a `BotPace`, which `BotDifficulty` and `ArcadeAiLevel` implement. 초보, 중수 and 고수 play
  exactly as before.
- **Rules:** each floor's rule as `BattleRules`; the stars of a fight, a boss match and a hold (`ArcadeStarJudge`).
- **Progress:** the most stars per stage (`ArcadeProgress`), kept per account in secure storage
  (`ArcadeProgressStore`).

The branch starts at `origin/main` `25509ee`. Before the push, `main` moved to `ad8a6f7` (#87, push-up grading), and
I merged it in (`03edd7f`). I ran the commands from the Plan in `gymrats_app/` on Windows, on `141c8df`, without
coverage. Coverage comes from the PR's CI comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | CI comment "Tests and coverage (GitHub Actions)" |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the PR's CI comment (no ViewModel changed) | 11/23 | same CI comment |
| Service | flutter_test, fakes | 85% | TODO(Woohyun Song): from the PR's CI comment | 11/23 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment (no View changed) | 11/23 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 11/23 | – |

- **Tests:** `flutter test` 3908 passed, 0 failed, 10 skipped. `flutter analyze` found no issues. The skipped tests
  were already skipped on `main`, and A2 does not touch them:
  - `test/services/online/public_wss_smoke_test.dart`: a live team-server check that runs only with
    `RUN_PUBLIC_BATTLE_SMOKE`.
  - 9 recordings in `test/services/pose/pushup_error_cases_test.dart`: known push-up judge errors, each with its
    reason in `knownErrors`.
- **Count change:** A2 adds 124 tests: 115 in the seven new arcade test files and 9 in the two bot test files.
  The other 4 new tests came with `main`'s #87. Before the merge, the branch had 3904 passed on `6b6b2b4`.
- **One failed run, not from this step:** the first full run on `6b6b2b4` had one failure in
  `test/services/online/online_battle_integration_test.dart`, 'server deduplicates verdicts, rejects conflicts,
  relays only pose whitelist' (L922: `valid_reps` 0, expected 1). A2 does not touch online battles. That run was
  slow (`flutter analyze` took 150 s instead of 75 s, with another test run on this PC). The file then passed 3 times
  out of 3 on its own (59 tests each), and the next full run on `6b6b2b4` passed (3904). It also passed in the earlier
  full run on `3bf2515` (3901 passed) and in the run on `141c8df` above.
- **The bot is unchanged (spec 3):** before editing `bot_opponent.dart`, I printed `planRound` with the code at
  `25509ee` for 초보, 중수 and 고수: the rounds of seeds 1 and 7, and for seeds 0 to 499 the counts of reps, valid
  reps and deep reps, the sum of their end times and the rejected reps by reason. The printed 고수 rounds equal the ones
  already pinned in the test from `8fc6cb3`. The new tests pin these values, and they pass on the changed code. As a
  check that the pins catch a change, I set the bot's `_jitter` from 0.15 to 0.16 for one run: 7 of the 8 new tests
  failed. The 8th checks only the valid reps of an arcade level, so it does not depend on `_jitter`. Then I set it
  back.
- **The pins after the merge:** #87 maps the bot's simulated `kneesDown` misses to `insufficientDepth`, so `main`'s
  bot is no longer the one pinned at `25509ee`. I printed the same values again from an export of `ad8a6f7` (outside
  the working tree). Only the rejection reasons differ: 초보 seed 1's `kneesDown` rep is now `insufficientDepth`, and
  the `kneesDown` count of seeds 0 to 499 moved to `insufficientDepth` (초보 125 + 107 = 232, 중수 55 + 53 = 108,
  고수 42 + 57 = 99). The times, counts and depths are the same. The pins now hold the `ad8a6f7` values (`141c8df`),
  and they pass on the merged code.
- **A field the merge added:** #87 also added `BattleRules.kneeAverageEnabled`, which a floor's rules did not copy
  from their base. Fixed in `9f14b6f`. The floor test's base now turns it off, and without the copy 'fever sets its
  start, and keeps the base's other values' fails.
- **The data test catches a changed value:** for one run I changed stage 7's label '무효 2회 이하'. The test
  'the 24 stages, every field and star' failed at stage 7. Then I set it back.
- **The JSON copy:** the step's ownership covers only `test/models/arcade_*_test.dart`, so the copy of
  `arcade_data.json` is a raw string in `test/models/arcade_catalog_test.dart` instead of a fixture file. Only the line
  breaks differ from the hand-off file (checked with Python `json.loads(copy) == json.load(file)`).
- **Other checks:** `ownership_guard.py --check-diff` ok (21 files: 18 code and test files, 3 notes), run with the local harness of the time. On 2026-11-23 I also
  matched the 21 files with the A2 paths of the PM's new harness: none is outside them. Server `pytest` was not run because
  `server/` did not change.
- **Coverage:** TODO(Woohyun Song): copy the numbers, commit and run link from the PR's CI comment "Tests and coverage
  (GitHub Actions)".
- **Shortfalls:** none known before CI reports coverage.
- **Manual check:** none. A2 has no screen. The arcade screens (P16) use these values.
- **Notes-only push (2026-11-23):** the PM's new harness names this step A2, "Build arcade stage rules"; these
  notes, the AI notes and the PR now use that name. The code is unchanged at `141c8df`, so the results above
  stand. The tests were not rerun for this push.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/arcade_catalog_test.dart` (new) | every floor, stage, star and AI level equals the JSON copy; the version and 5F; the characters are the character rig's, with the same names; the JSON's default score rules are `battleRules`; 초보 = LV 1, 중수 counts like LV 4 (combo chance 0.08 vs 0.10), 고수 has no level; six stages per floor in the order push-up, squat, plank, push-up, chair, boss; six characters fight twice each, never twice on a floor, never on their own floor, never in two fights in a row; AI LV 1 to 16 through the fight and boss stages; holds and bosses meet the floor owner; boss rounds push-up then squat; the stars of each kind; the star numbers get harder each floor; 4F's 무효 0회; lookups and range errors |
| Model | `test/models/arcade_ai_level_test.dart` (new) | 16 levels in order; `of(1..16)`, range errors at 0, -1 and 17; LV 1 has every number of 초보 and plans exactly its rounds (100 seeds); one more valid rep at both ends per level; LV 16 counts 20 to 22 in 30 s; every level stays inside its valid and rejected counts (200 seeds each); a bot takes a level |
| Model | `test/models/arcade_floor_test.dart` (new) | 1F is `battleRules`; 2F fever from 15 s; 3F combo bonus 10; 4F excellent 30; every other value (all 12) stays the default; the times multiply the base's own value; fever keeps the base's other values, incl. `kneeAverageEnabled` off |
| Model | `test/models/arcade_stage_test.dart` (new) | `HoldPose` plank and chair with their labels; `ExerciseType` is still push-up and squat; stage kinds; a hold's star times and end time; `ArcadeStars` count, cleared, lit, equality |
| Model | `test/models/arcade_progress_test.dart` (new) | the first state; a stage opens after a star in the one before; the stage to play; a floor cleared only by its boss; 5F after stage 24; all 24 cleared; star total up to 72; playing again never lowers a stage's stars; range errors; 24 counts from 0 to 3; equality; the saved form `{"v":1,"best":[...]}` and 13 broken values |
| Service | `test/services/arcade/arcade_star_judge_test.dart` (new) | fight: loss, win only, condition, KO only, all three, the boundaries n and n ± 1 of 무효 (incl. 0회), 콤보 and Excellent, a wrong second star throws; boss: R1 lost, R2 lost, both won, the excellent sum at its boundary, KO in one round only, both KO, all three; hold: each star second's boundary, ended by two warnings (17 s clears, 9 s fails), each stage's own seconds; a round from a `BattleResult`: win, KO win, loss by KO, draw, rejected reps, longest combo, excellent reps, 3F and 4F rules, no form |
| Service | `test/services/arcade/arcade_progress_store_test.dart` (new) | secure storage: writes and reads under `gymrats.arcade.<account>`, accounts apart, nothing saved, 7 broken values, a failing read; memory store; `recordStage` writes once per stage and keeps the most stars, writes nothing when the storage read fails (the saved progress stays), replaces a broken value |
| Service | `test/services/opponent/bot_opponent_test.dart` (updated) | 초보 and 중수 seeds 1 and 7 plan exactly the rounds printed at `ad8a6f7` (main before this step); seeds 0 to 499 of all three levels plan the same reps; the bot and `planRound` take an arcade level |
| Model | `test/models/bot_difficulty_test.dart` (updated) | every level is a `BotPace` and reads the same through it |

### Acceptance criteria → tests
- Data equals `arcade_data.json` (spec 9) → 'the four floors: name, owner and rule', 'the 24 stages, every field and
  star', 'the 16 AI levels', 'the characters are the rig's, with the same names'
- Stage rules → 'every floor plays push-up, squat, plank, push-up, chair, boss', 'the six characters each fight twice
  in the twelve fights', 'no character fights twice on a floor, nor on its own floor', 'no character fights in two
  fights in a row', 'the AI goes up one level per fight and boss stage, 1 to 16', 'the floor's owner judges its holds
  and plays its boss match'
- AI levels → 'LV 1 has every number of 초보', 'a level outside 1 to 16 throws', 'LV 1 plans exactly the rounds of
  초보', 'LV <n> stays inside its valid and rejected counts' (16 tests)
- 초보·중수·고수 unchanged (user's condition) → '초보 seed 1 plans exactly the same round' and the three other
  seed pins, '초보: seeds 0 to 499 plan the same reps' and the same for 중수 and 고수, the existing 고수 'seed 1 / seed 7
  plans exactly the same round'
- Floor rules → '1F plays by the default rules', '2F: fever from 15 s, the rest as by default', '3F: combo bonus 10,
  twice the default, the rest as by default', '4F: excellent 30, twice the default, the rest as by default'
- Fight and boss stars → 'a loss lights no star, whatever else happened', 'a KO win without the condition lights the
  first and third', '무효 n회 이하: n and fewer meet it, n + 1 does not', '콤보 n 이상: n and more meet it, n - 1 does
  not', 'losing R2 lights no star', 'the excellent reps of both rounds count together, from n', 'a KO in one round
  only is no third star'
- Hold stars and decision 11.1 → 'each star lights at its seconds, not a moment before', 'ended by two warnings: the
  time held so far counts (spec 11.1)'
- Progress and decision 11.2 → 'a stage opens once the one before it has a star', 'the stage to play is the first one
  with no star', 'a floor is cleared by a star in its boss match', '5F shows once the 4F boss match has a star',
  'playing again keeps the most stars of the stage (spec 11.2)', 'all 24 cleared: no stage left, every floor and 5F'
- Storage (spec 7) → 'accounts keep their own progress', 'a broken value, another version, another length or a count
  outside 0 to 3 is the first state', 'a store that fails to read is the first state', 'a store that fails to read
  keeps the saved progress: nothing is written'

#### 2026-11-24 · merge `da3a039` of `origin/main` `69b0520` · step A2: `main` merged in before the draft ends
At the user's word (2026-11-24; the prompt is logged on A4's branch, `codex/iter5-hold-plank`), `origin/main` (#86 setup timeout, #93 Google
sign-in, #94 zero points for knee push-ups) was merged into this branch first, before the steps stacked on it. No
conflict: no file changed on `main` since `ad8a6f7` is one of A2's. A2's code is unchanged at `141c8df`.

Commands, in `gymrats_app/` on Windows, without coverage (this PC's rule): `flutter pub get` (#93 added a package),
`flutter analyze`, `flutter test`.

- **Tests:** `flutter analyze` found no issues. `flutter test` 4034 passed, 0 failed, 10 skipped (2026-11-24, on
  `da3a039`; the same 10 skips as above). The bot pins pass on the merged code.
- **Other checks:** `ownership_guard.py --check-diff` OK (21 paths against `origin/main`, as before). Server `pytest`
  was not run: `server/` is `main`'s, unchanged by A2, and `main`'s own checks cover it.
- **Coverage:** TODO(Woohyun Song): copy the PR's CI comment for this head.

#### 2026-11-25 · code at commit `c91a8f3`, `origin/main` merged in `def1c5e` · step P8 `codex/iter5-auth-screens` (Redesign the sign-in and sign-up screens, team order #5)
P8 redesigns the login screen and the first sign-up (nickname) step on top of P7's Google sign-in (#93). It follows
the design hand-off's spec `p8/SPEC.md` v1 (2026-11-25, not committed) and its `.dc.html` sources:
- **First screen (LoginB look d1):** the GYMMOUSE logo, the group photo of the six characters on a three-step
  podium, "Google로 시작하기" and the "아이디로 로그인" link.
- **States (LoginS):** L1 is a spinner in the Google button with the button and the link greyed. C2 is a grey line
  "로그인을 취소했어요". F1 is an error box over the button, with the button saying "Google로 다시 시도". An expired
  session shows in the same box, with the button left as "Google로 시작하기" (the user's decision).
- **Id sheet:** the app's id and password with `LoginViewModel`'s checks and messages, the lime 로그인 button, and
  the link to the id sign-up screen (unchanged).
- **Nickname step:** a count that stops at 12/12, input cut at 12 after a Korean letter is finished, the help or
  error line, an F1 box, and the lime 시작하기 button.
- **Group photo:** the six 18 s loops of `ChL.dc.html` (`motions.d1`) are converted number for number into the app's
  character engine (the home rig's form). The faces, the thumb and RepBot's back glove that the app lacked are added
  as a draw patch. The photo's clock stops while it is covered or the app is in the background. With the device's
  animations off it draws the design's still moment.
- **View model:** `LoginState` gets two fields with defaults, `cancelledWith` and `failedWith`, so the screen can
  tell a cancel and a Google failure apart. Messages and behavior are unchanged.
- **Line breaks:** the login screens' Korean breaks only at spaces (word joiners in the drawn text only). When the
  words need two lines, the break is balanced ("Google로 / 로그인하는 중…").

The branch starts at `origin/main` `18b9259`; the code is four commits, `68597e4`, `5e5c8aa`, `e1b88b1` and
`c91a8f3`. Before the push, `main` had moved to `9757854` (#96 telemetry, #89 A2), and I merged it in (`def1c5e`; it
touches none of P8's code, only these notes). I ran these in `gymrats_app/` on Windows on `def1c5e`, without coverage
(this PC's rule):

```sh
flutter pub get
flutter analyze
flutter test
flutter test test/widgets/auth_cast_test.dart test/widgets/auth_form_test.dart test/screens/login_screen_test.dart test/screens/auth_screens_test.dart test/screens/social_signup_screen_test.dart test/viewmodels/login_viewmodel_test.dart test/models/character_rig_test.dart test/theme/app_theme_test.dart test/design_tokens_test.dart test/auth_flow_test.dart test/demo/auth_history_demo_test.dart
```

No server, Google account, camera or secure storage is needed:
- **Auth fakes:** `ScriptedAuthRepository`, `InMemoryAuthRepository` and `FakeSocialSignIn` from
  `test/support/auth_fakes.dart`. The nickname test adds a subclass that holds the account's creation.
- **Golden values:** `test/widgets/auth_cast_golden.json` holds values from the design's own JavaScript.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | TODO(Woohyun Song): from the PR's CI comment (`character_rig.dart` only) | 11/25 | CI comment "Tests and coverage (GitHub Actions)" on the P8 PR |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the PR's CI comment (`login_viewmodel.dart`) | 11/25 | same CI comment |
| Service | flutter_test, fakes | 85% | not changed by P8 | 11/25 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the PR's CI comment | 11/25 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not changed by P8 | 11/25 | same CI comment |

- **Tests:** `flutter test` passed 4340, failed 0 and skipped 10 (2026-11-25, `def1c5e`), and `flutter analyze`
  found no issues. Before the merge, the code's tree passed 4134/0/10. The 10 skipped tests are the ones already skipped on `main` (a live server smoke
  test and 9 known push-up judge errors), untouched.
- **The step's files:** the eleven files in the second command passed 267 tests:
  - new: auth_cast 22, auth_form 19, login_screen 15
  - changed: auth_screens 18, social_signup_screen 13, login_viewmodel 17, character_rig 34, app_theme + design_tokens 108
  - flows: auth_flow + auth_history_demo 21
- **Ownership:** `ownership_guard.py --check-staged` was OK on each commit, and `--check-diff` on `def1c5e` was OK
  (P8 · 20 paths against `origin/main`).
- **Against the design (group photo):** the first screen was drawn at 0 s to 7 s in a throwaway test (not committed)
  and compared by eye with `shots/cast_timeline_0-7s.png` and `shots/state_base.png`. The poses, faces, the thumb,
  the sparks, the seal's heart, the places and the podium match.
- **Against the design (states):** each state was captured with the app's fonts at 360 × 780 and at 320 × 640 with
  text 1.3 and compared with the `shots/state_*.png` files. Base, L1, C2, F1, the id sheet and its error, and the
  nickname step's base, empty error and busy match. The user checked all 27 images (2026-11-25).
- **Fixed after the user's check:** at 320 × 640 with text 1.3, "Google로 로그인하는 중…" and "Google 로그인에
  실패했어요." broke inside a word. They now break as "Google로 / 로그인하는 중…" and "Google 로그인에 / 실패했어요."
- **Not covered by a test:** with the device's bold text on, `AuthWords` measures its lines in bold, as they are
  drawn (reviewer run 3). The test font's bold and regular letters are equally wide, so a test could not fail.
- **Known differences, kept by the user's decision (2026-11-25):**
  - The nickname field has no placeholder.
  - The id sheet is about 16 px taller than LoginS: the close button and the sign-up link keep the app's 48 px tap
    area.
  - The links' underline sits at Flutter's default distance, not CSS's 3 px.
  - At 320 × 640 with text 1.3 the F1 box covers the lower part of the bottom row's characters. Nothing overflows.
- **Out-of-step files, act first and report after (the user's decision, 2026-11-25):**
  - `lib/models/character_rig.dart`: a rig color may be `#RRGGBBAA`, for ChL's half-clear blush.
  - `test/auth_flow_test.dart` (P7) and `test/demo/auth_history_demo_test.dart`: they now open the id sheet first
    and use the new words; the flows and their expectations are the same.
- **Coverage:** TODO(Woohyun Song): copy the P8 PR's CI comment (commit, run link, per-layer numbers, P8's files).
- **Phone check, done 2026-11-25** by the user (Galaxy S26+, a release build of the pushed branch, the cable out, two
  screen recordings of 31 s and 59 s; the user's message is in the Prompt Log):
  - **First screen:** the logo right under the status bar, the group photo, the Google button and the link sit as
    in the design. The characters move and change faces, and go on moving after a return from the recent apps.
  - **L1:** while Google's account picker was up, the turning ring, "Google로 로그인하는 중…" and the greyed button
    and link were as designed.
  - **C2:** closing the account picker showed "로그인을 취소했어요" over the button; a new tap cleared it.
  - **Id sheet:**
    - It opened from the link, three times, and the characters behind it kept moving.
    - With the keyboard up, the fields, the 로그인 button and the sign-up link stayed visible.
    - A wrong password showed the busy button (pale lime, spinner), then "아이디 또는 비밀번호가 맞지 않아요.";
      typing again cleared it.
    - "처음이신가요? 회원가입" opened the id sign-up screen, and back returned to the sheet.
    - The right password went home.
  - **Not seen on the phone:**
    - F1 and the nickname step: the build is signed with a debug key whose SHA-1 is not yet registered in the team's
      Google Cloud (asked of 박진영). Picking an account made the plugin report a cancel, so C2 showed. To check
      again after the registration; until then the widget tests above cover them.
    - The one-a-second start and the 18 s loop: not caught in the recordings; left to `auth_cast_test`.
  - **Fixed after the phone check (`dd08911`):** after a wrong password, closing the sheet made Samsung Pass offer
    to save the login. The sheet's autofill group committed when it closed. It now cancels on close, and the screen
    asks to save only after a login that worked (`TextInput.finishAutofillContext()`). New test in
    `auth_screens_test.dart`: 'the password manager is asked to save only after a login that worked, never when the
    sheet closes'. It fails without the fix ([true] instead of [false]). `flutter analyze` on the two files found no
    issues, and auth_screens, login_screen, auth_flow and auth_history_demo passed 55 tests (the user's call: no
    reviewer run for this fix).

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/auth_cast_test.dart` (new) | **Data:** the six places, scales, flips, teams and clocks of LoginB; the podium, the planes, the shadows; every loop is 18 s and holds each pose 6 s; every face and flag a loop uses has shapes; malformed data rejected.<br>**Golden:** each of the six matches ChL's own `RIGX.vals` at every sampled time (pose numbers, expression, hop and rock, flags and what they show, sparks and hearts).<br>**Timing:** one more character changes pose each second from 1 s to 6 s; animations off draws LoginB's `ft` moment.<br>**Stage:** one picture with the cast label; the clock starts at 0 and runs, never ticks with animations off, stops in the background and under an opaque screen and goes on after, not under a sheet; the band's scale. |
| View | `test/widgets/auth_form_test.dart` (new) | **Text:** `keepWordsWhole` (joiners only inside words, nothing lost, a decomposed letter kept whole); with joiners a narrow line breaks at a space where the plain sentence breaks inside a word; `authLines` (fits, balanced two lines, three lines or one word left to wrap); `AuthWords` finds and reads as written; `splitFirstSentence`.<br>**Parts:** the error box (bold first sentence, grey rest, amber mark, announced); the cancel line and field error announced; the Google button (G, busy spinner, grey words, no taps); the lime button (arrow, busy pale with spinner, no taps); the spinner turns and stands still with animations off; links (underlined, lighter when off, 48 high); round buttons (48 tap area); input fields (named, 17 text, spaced dots); every glyph draws. |
| View | `test/screens/login_screen_test.dart` (new) | **First screen:** logo, line, photo, Google and the link in order; no fields, no sign-up link; Google signs in; no Google service shows only the link; tap sizes.<br>**States:** L1 (spinner, words, no taps on the button or link); C2 (line over the button, announced, gone on a new tap or when the sheet opens); F1 (box over the button, bold and grey sentences, "Google로 다시 시도", gone on a new tap); each failure's words; the expired box with "Google로 시작하기".<br>**Sizes:** 360 × 780 and 320 × 640 with text 1.3, every state and the sheet with errors fit, a note never reaching the lowest row's feet; at the design's size the box covers the bottom step and the photo keeps its size. |
| View | `test/screens/auth_screens_test.dart` (updated) | **Id sheet:** opens from the link; X, back and outside close it and keep the text; field errors under the fields; the wrong-credentials line over the button; a network failure; busy; closed while logging in, a wrong password shows nowhere; the sign-up link; a login closes the sheet as the app does; the keyboard; the password manager saves only after a login that worked (`dd08911`).<br>**Google:** a new Google account opens the nickname step; (a) after a Google failure the sheet has no error; (b) a wrong password then closing leaves nothing; (c) the expired box goes when the sheet opens and closes.<br>**Unchanged:** the id sign-up screen's tests. |
| View | `test/screens/social_signup_screen_test.dart` (updated) | **Layout:** back, 회원가입, the photo, the nickname with count and help, the lime 시작하기, and only the design's words; back creates nothing.<br>**Input:** the count follows and stops at 12, a 13th letter is not taken; the cut waits for composition.<br>**States:** 시작하기 creates the account; the empty error replaces the help line; busy (pale, spinner, "계정을 만드는 중…", one request); a server failure's F1 box; the expired provider login.<br>**Sizes:** 360 × 780 and 320 × 640 with text 1.3, and the keyboard up. |
| ViewModel | `test/viewmodels/login_viewmodel_test.dart` (updated) | cancel told apart until the next try; the id form clears the cancel note; every Google failure sets `failedWith`; wrong credentials and the expired session do not |
| Model | `test/models/character_rig_test.dart` (updated) | `#RRGGBB` opaque, `#RRGGBBAA` with its alpha last (`#FF000080` is half red), other lengths rejected |
| Design | `test/theme/app_theme_test.dart`, `test/design_tokens_test.dart` (updated) | the Auth colors and text styles; the new screen and widget files use only tokens |
| App flow | `test/auth_flow_test.dart`, `test/demo/auth_history_demo_test.dart` (updated) | the same flows through the id sheet and the new words |

### Acceptance criteria → tests (the P8 spec, section 9; the local task.md left the step's criteria to the spec)
- 9-1 First screen → login_screen_test: 'the logo and its line, the group photo, Google and the id link; no fields and
  no sign-up link', 'Google로 시작하기 signs in with Google'
- 9-2 States → login_screen_test: 'L1: …', 'C2: backing out shows the grey line, …', 'C2: opening the id sheet clears
  it', 'F1: the box over the button, …', 'an expired session shows in the box, …'
- 9-3 First sign-up → auth_screens_test 'a new provider account opens the nickname step'; social_signup_screen_test
  'an empty nickname: …', 'while it creates the account: …', 'a server failure shows the F1 box over the button',
  'the count follows the text and stops at 12; a 13th letter is not taken'
- 9-4 Id sheet → auth_screens_test: 'the link opens it: …', 'X, back and a tap outside each close it, …', 'a wrong id
  or password shows one line over the button, …', 'the sign-up link opens the id sign-up screen', 'a login closes the
  sheet with the screen, as the app does', '(a) …', '(b) …', '(c) …'
- 9-5 Group photo → auth_cast_test: 'each second from 1 s to 6 s, exactly one more changes pose', 'animations off:
  never ticks', 'stops while another screen covers it, then goes on', 'stops while the app is in the background, then
  goes on', and the six golden tests
- 9-6 Overflow → login_screen_test and social_signup_screen_test: the '… text 1.3: …' tests at both sizes
- 9-7 Existing screens → the full `flutter test` above (home, battle and victory character tests unchanged and
  passing; the id sign-up screen's tests unchanged); character_rig_test's color test
