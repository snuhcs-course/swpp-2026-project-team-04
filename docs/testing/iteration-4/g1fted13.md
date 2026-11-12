# Testing notes – Iteration 4 – Woohyun Song

Per-push Results for my Iteration 4 steps, in the Testing Documentation format. The PM merges them into
`docs/testing/Testing-Documentation.md`.

## Results

#### 2026-11-08 · code at commit `38c44b1` · step W1 `feat/home_lobby` (P5 home redesigned as a game lobby, team order #2)
This step turns home into a game lobby and moves the light design theme in:
- **Home:** '?', the profile chip, the GYMRATS title, RepBot doing push-ups, and three menu rows (게임 시작, 기록보관소, 환경설정). Home fits the phone screen: RepBot takes the height left, from 0.6 to 1.2 times its design size, and the page scrolls only when RepBot at 0.6 still does not fit.
- **New pages:** 게임 시작 (online and AI battle cards, play again), AI 1v1 (exercise, level, 대결 시작) and 환경설정 (nickname, 아바타, rules, sound switches, logout).
- **Theme:** the light theme with palette B, and the design fonts.
- **Sound switches:** kept across app restarts (`SettingsStore`).
- **Removed:** the bottom tab bar and the bot level sheet.

The branch sits on `main` at `998a6fd`. I ran the commands from the Plan in `gymrats_app/` on Windows, on `38c44b1`,
without coverage. Coverage comes from the PR's CI comment, "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.4% (266/273) | 11/08 | CI comment "Tests and coverage (GitHub Actions)" on PR #45, commit `f3f6b9f`, [run 42480145654](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/42480145654) |
| ViewModel | flutter_test, fakes | 90% | 96.3% (986/1024) | 11/08 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 94.3% (2249/2384) | 11/08 | same CI comment |
| View | flutter_test (widget) | 75% | 92.4% (4484/4854) | 11/08 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (101 passed; `server/` unchanged) | 11/08 | CI `pytest --cov=accounts --cov=matches --cov=gymrats` on `f3f6b9f` |

- **Tests:** `flutter test` 1490 passed, 0 failed, 10 skipped. `flutter analyze` found no issues. The skipped tests were already skipped on `main`, and W1 does not touch them:
  - `test/services/online/public_wss_smoke_test.dart`: a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`.
  - 9 recordings in `test/services/pose/pushup_error_cases_test.dart`: known push-up judge errors, each with its reason in `knownErrors`.
- **Count change:** `main` at `998a6fd` had 1476 passing tests. W1 deletes `test/widgets/bot_difficulty_sheet_test.dart` with its widget (the AI 1v1 page replaces the sheet), rewrites the home tests, and adds the files marked "(new)" below.
- **Other checks:** `ownership_guard.py --check-diff` ok (48 files, all W1's or approved exceptions). Server `pytest` was not run because `server/` did not change.
- **Checks after merging `origin/main`:** `git fetch origin && git merge origin/main` said "Already up to date": `main` is still `998a6fd`, which the branch already contains, so the code is still `38c44b1`. I reran the checks anyway on 2026-11-08: `flutter analyze` found no issues, and `flutter test` had 1490 passed, 0 failed and 10 skipped (the same tests). `ownership_guard.py --check-diff` is ok (48 files).
- **Coverage:** from the CI comment "Tests and coverage (GitHub Actions)" on PR #45, commit `f3f6b9f` (2026-11-08 21:31 KST; app and server jobs both succeeded; run link above). App total 93.5% (8196/8763), Other 92.5% (211/228).
  - CI also ran `flutter analyze` (no issues) and `flutter test` (1490 passed, 10 skipped, 0 failed). This matches the local run. `f3f6b9f` changes only the notes on top of `38c44b1`.
  - Left out of the coverage numbers by CI's 240 s per-file limit: `test/screens/result_screen_test.dart`, which is not a W1 file. Its tests still ran in `flutter test`.
- **Shortfalls:** none. Every layer and the server meet their targets.
- **Manual check (2026-11-08, the user, on a Galaxy S26+ with Android 17 and One UI 9.0, the same phone as in my earlier test notes):** the user checked these on a build of this branch and reported no problems ("폰 확인 끝났어. 문제없어.").
  - Home does not scroll or stretch when swiped.
  - All three menu rows show above the navigation bar.
  - RepBot keeps its shape and its push-ups.
  - The profile chip and the menu rows keep their size.
  - At the largest system font size the page scrolls with no overflow stripes, and every row can be reached and tapped.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/lobby_rep_bot_test.dart` (new) | the 17 bar ends and the head equal the design prototype's output at s = 0, 0.5, 1; one rep is 2000 ms and starts 600 ms in, s = (1 − cos(2π·t/2000)) / 2 every 50 ms; keeps doing push-ups, holds the top pose with reduced motion, stops and restarts when it changes; repaints on its own layer; the paint order (floor, glow, outline, body) |
| View | `test/widgets/lobby_parts_test.dart` (new) | `LobbySkew`; `LobbyPage` (an `Expanded` child takes the room left, scrolls when too tall, the backdrop goes behind); `LobbyPage.fill` (the fill takes the height left, the system bars are left out, scrolls only when the fill at its least does not fit, no scroll room with fractional sizes); `LobbyFillColumn` (fill between the others, keeps its least height, a shrinking `FittedBox` gives its room to the fill, taps land where drawn, relayout on a new least height or more children, dry layout equals layout, intrinsic size counts the fill at its least); `LobbyBackdrop`, `LobbyWatermark`, `LobbySquareButton` (44 pt look, 48 pt tap area, name), `LobbyTag`, `LobbyPageHeader`, `LobbyArrowChip` |
| View | `test/widgets/lobby_menu_item_test.dart` (new) | every entry looks the same (gray tag, ink title, gray chevron), the lines and spacing, the whole row is the tap area, screen readers hear a button, titles shrink on a narrow screen at a large text size |
| View | `test/screens/home_screen_test.dart` (updated) | home shows rules, nickname, title, RepBot and the menu; loading, failed load with retry, network failure message; '?' opens the rules (UAT-6); 게임 시작, 기록보관소 and 환경설정 open their pages; the profile chip opens settings; logout moved to settings; home reloads on return; the amber note for unsent battles; the chip ends at the right margin, a 12-letter nickname shows whole, a long one ends in an ellipsis; sound switches keep their value; **fits the screen:** 360×780 and 393×852 with and without system bars have no scroll, RepBot shrinks on a short screen and grows to at most 1.2× on a tall one, the chip and menu rows stay the same size, a tab bar under home is left out of the room, 320×640 at 1.3× text scrolls with RepBot at its least and every menu row can be scrolled to and tapped, 6 sizes (320×568 … 412×915) × 3 text scales (1.0/1.3/2.0), 18 cases, show no overflow and scroll only with RepBot at its least; every button is 48 dp and named |
| View | `test/screens/play_screen_test.dart` (new) | both battle cards, the latest setup and the rules; the online card asks for the exercise and opens the lobby, closing the sheet stays; the AI card opens the AI 1v1 page; play again with a bot or online; nothing to play again before the first battle; 규칙 보기; back; fits phone sizes; button sizes and names |
| View | `test/screens/ai_setup_screen_test.dart` (new) | exercises, levels and the start button; the designed defaults (push-ups, 중수); 기록 없음 for a new user; choosing an exercise and a level; 대결 시작 searches for the chosen bot; level bars, ink tag, lime check chip; screen reader labels; fits phone sizes |
| View | `test/screens/settings_screen_test.dart` (new) | nickname, rules, sound switches and logout; no editing and no safety switch in this step; 아바타 opens `/profile`; switches show and change the view model, one at a time, and keep their value on reopen; another screen sees the change; 게임 규칙 다시 보기; logout asks first; back; screen reader switch rows; fits phone sizes |
| View | `test/widgets/battle_mode_card_test.dart`, `match_record_card_test.dart`, `accent_button_test.dart`, `grid_background_test.dart` (updated) | the new `BattleModeCard` look and API; palette B colors and the `AccentButton` ink edge |
| View | `test/screens/home_shell_screen_test.dart` (updated) | home opens with the logout action and no tab bar; home can be replaced for tests |
| ViewModel | `test/viewmodels/home_viewmodel_test.dart` (updated) | load, failure and retry, a failed reload keeps the profile, one fetch while loading, dispose guards, no recent list; the latest setup to play again (bot level, the pre-level bot, online); the AI 1v1 choice kept across reloads |
| ViewModel | `test/viewmodels/settings_viewmodel_test.dart` (new) | designed defaults (sound effects on, voice guidance off); each switch changes alone and notifies; after dispose nothing changes; each switch is saved, a never-saved switch keeps its default, a switch turned while loading keeps the user's value, a failed read keeps the defaults |
| Service | `test/services/user/settings_store_test.dart` (new) | `SecureSettingsStore` over a fake secure storage: nothing saved reads as null, each switch has its own key, any value but true/false reads as never saved |
| Design | `test/theme/app_theme_test.dart` (updated) | light theme design colors; fonts and fallbacks; the lobby text styles; palette B: colors only fill, ink text at 4.5:1 on every surface and fill, white text and a lime icon on ink, gray lines at 3:1; `AppHighlight`; Material defaults (spinners, buttons, cursor, radio, switch, fields) in ink |
| Design | `test/design_tokens_test.dart` (updated) | the new screens and widgets added to the checked list; the deleted `bot_difficulty_sheet.dart` removed (PM OK) |
| App flow | `test/main_test.dart` (updated) | 게임 시작 → matching → versus and cancel; the AI 1v1 page → a squat bot at the chosen level; back one page at a time; online takes the exercise; '?' opens the rules; the result's battle on home; sound switches survive a restart |
| App flow | `test/auth_flow_test.dart`, `test/demo/auth_history_demo_test.dart`, `test/screens/feedback_screen_test.dart`, `online_lobby_screen_test.dart`, `profile_screen_test.dart` (updated, approved exceptions) | only the paths from home: logout through 환경설정, history through 기록보관소, the avatar page through 아바타, reduced motion so RepBot holds still |

### Acceptance criteria → tests
- Given I log in, then home shows both battle modes with the exercise choice and starts the same flows as before. The user changed home's layout on 2026-11-06: the modes are one tap away, on 게임 시작.
  - Tests: `"게임 시작 opens the play page on home's profile"`, `'shows both battles, the latest setup and the rules'`, `'the online card asks for the exercise, then opens the lobby'`, `'the AI 1v1 page leads to a squat bot at the level chosen'`, `'start leads through matching to versus; cancelling goes home'`.
- Given I tap '?', then the rules/help open as before. Tests: `"'?' opens the rules; back returns home (UAT-6)"`, `"'?' on home opens the rules over home; back returns home"`.
- Home fits the phone screen (user spec, 2026-11-08). Tests: `'a $label phone shows it all without scrolling'`, `'320×640 at 1.3× text scrolls, with RepBot at its least, and every menu row can be scrolled to and tapped'`, `'$label: no overflow, no scroll while RepBot can shrink'`.

#### 2026-11-11 · code at commit `cd88ab2` · step W1 `feat/home_lobby`, follow-up to the Codex review of PR #45 (team order #2)
The Codex review of PR #45 (on `78351da`, 2026-11-10) left three comments. This push fixes two of them on the same branch, in two rounds: the first fix, then changes after my review of it.
- **Result screen (Codex P1), commits `5909acd` and `cd88ab2`.** WIN and LOSE were lime and pink text on the light ground, about 1.03:1 and 2.58:1. Now:
  - the verdict word is ink on a slanted band, lime for a win and pink for a loss;
  - the scores and the 자세 피드백 보기 label are ink;
  - round 2: the 무효 count is ink too (it was amber text on a white card, about 1.8:1);
  - DRAW, the layout and the wording are unchanged.
  - `result_screen.dart` is W6's file. It was changed under a one-off exception: text readability only.
- **환경설정 nickname (Codex P2), commits `15e0dcd` and `df2ff07`.** A 12-letter nickname at a large text size overflowed its row. It is now one line that ends in "…" only when it does not fit.
  - Round 1 capped it at 40% of the screen width. That cut a 12-letter Hangul name even at the normal text size on a 360-dp phone.
  - Round 2: the nickname sits on its title's line and takes all the width the title leaves. The gray line under the title now runs under both. At 1.0× on a 360-dp phone the line and a 12-letter name do not fit side by side.
- **Not fixed here (Codex P2, issue #47).** "최근 설정으로 다시 하기" guesses bot or online from the opponent's name. A fix needs the mode in the match record, which is in J3's files, so there is no code change.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `cd88ab2`, without coverage. The coverage is from the PR's CI comment on the pushed head `57343fe` (the code of `cd88ab2` plus these notes), [run 42903634050](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/42903634050); app and server jobs succeeded.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 97.4% (266/273) | 11/11 | CI comment "Tests and coverage (GitHub Actions)" on PR #45, `57343fe`, [run 42903634050](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/42903634050) |
| ViewModel | flutter_test, fakes | 90% | 96.3% (986/1024) | 11/11 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 94.3% (2249/2384) | 11/11 | same CI comment |
| View | flutter_test (widget) | 75% | 92.3% (4488/4860) | 11/11 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (CI: 101 passed; `server/` unchanged) | 11/11 | same CI comment |

- **Tests:** `flutter test` had 1500 passed, 0 failed and 10 skipped. `flutter analyze` found no issues.
  - The 10 skipped tests are the same ones as on 11-08.
  - The count grew from 1490 by the 10 new tests below (9 in round 1, 1 in round 2). No test was removed.
- **Tests before the fix:** in both rounds I wrote the new and changed tests first and ran them on the code before the fix.
  - Round 1, on `78351da`: 10 failed.
    - In `result_screen_test.dart`, 8 failed: the three updated ink checks, WIN and LOSE on a band, and "no lime or pink text" (its name then) for a win, a loss and a draw. The draw screen fails too, through its lime and pink scores and the feedback button's lime label.
    - In `settings_screen_test.dart`, 2 failed: the 12-letter nickname at 1.3× (no ellipsis) and at 2× ("A RenderFlex overflowed by 114 pixels on the right"), the overflow Codex described.
  - Round 2, on `1bb8544` (round 1 committed): 7 failed.
    - In `settings_screen_test.dart`, 3 failed: the new 12-letter name at 1.0× on a 360-wide phone (cut by the 40% cap), and the 1.3× and 2× tests through their new check that the name takes all the room its title leaves.
    - In `result_screen_test.dart`, 4 failed: the win test's 무효 count (amber), and "no text in lime, pink or amber" (its name then; now "a palette B fill color") for a win, a loss and a draw.
  - The DRAW test and the short-nickname test passed on the old code as well. They guard what must not change.
- **Other checks:** `dart format --set-exit-if-changed` passes on the four changed files, and `ownership_guard.py --check-diff` is ok. Server `pytest` was not run because `server/` did not change.
- **Coverage:** from the CI comment on `57343fe` ([run 42903634050](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/42903634050)): Model 97.4%, ViewModel 96.3%, Service 94.3%, View 92.3%; total 93.5% (8200/8769), other 92.5% (211/228); server 96%. CI's `flutter test` had 1500 passed, 10 skipped, 0 failed, the same as on this PC.
  - Left out of the coverage numbers: `test/screens/result_screen_test.dart`, which hit CI's 240 s limit per file (as on 11-08). Its tests still ran and passed in `flutter test`. So the result screen's changed lines are not in the View number.
- **Shortfalls:** none; every target is met.
- **Manual check:** not checked on a phone for this push. The agent rendered the round-2 code with the app's fonts to images for a look by eye: the result screen (393×852; WIN, LOSE, DRAW) and 환경설정 (360×780 at 1.0×, 1.3× and 2.0× text). With the real fonts a 12-letter name is whole at 1.0× and ends in "…" at 1.3× and 2.0×. The images are not committed. To check on a phone: the nickname row with a long name, and the result screen's 무효 count.

### Test cases added or changed in this follow-up
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/result_screen_test.dart` (updated; W6's file, exception) | WIN and LOSE are ink on a slanted lime or pink band, 4.5:1 or more; DRAW stays ink with its glow and no band, 4.5:1 or more on the ground; a win, a loss and a draw paint no text in a palette B fill color (lime, pink, amber, cyan, red), the feedback button and 무효 included; the scores and the 무효 count are ink |
| View | `test/screens/settings_screen_test.dart` (updated) | a 12-letter nickname shows whole at 1.0× on a 360-wide phone, right of its title and flush with the row's end, the gray line under it; at 1.3× and 2× it is one line ending in "…" that takes all the room its title leaves, inside the screen, and a screen reader gets the whole name; a short nickname shows whole at the right of its row |

### Acceptance criteria → tests (this follow-up)
- The verdict word is 4.5:1 or more (user spec 2026-11-11, Codex P1). Tests: `'$word is ink on a slanted band, 4.5:1 or more'` (WIN, LOSE), `'DRAW stays ink on the screen ground, with no band'`.
- Lime, pink and amber text become ink, button text and the 무효 count included (user spec 2026-11-11 and its later answer). Tests: `'a ${outcome.name} paints no text in a palette B fill color, the feedback button and 무효 included'` (win, lose, draw), `'a win: WIN, the margin, both players, and my stats'`.
- The nickname takes the row's free width and ends in "…" only past it: whole at 1.0× on a 360-dp phone, one line with "…" and no overflow at 1.3× and 2× (Codex P2, user's later answer). Tests: `'a 12-letter nickname shows whole on a 360-wide phone at the normal text size'`, `'a 12-letter nickname at ${scale}x text is one line that ends in …, beside its title'`, `'a short nickname shows whole, at the right of its row'`, `'fits $label without overflow, scrolling if it must'`.
- UAT-4 AC1 (win, loss or draw with both scores) still holds. Tests: `'a win: WIN, the margin, both players, and my stats'`, `'$mine:$theirs is a $word'`.

#### 2026-11-13 · code at commit `6a8efba` · step W2 `feat/battle_screen_revamp` (P8 battle screen revamp, team order #5)
This step replaces the bot and online battle screens with one fighting stage, as designed (the user's Claude Design candidate A, spec v2.2), and redraws the matching screens in palette B:
- **The stage** (upper half): the HUD (names, clock and lead chip, scores, valid rep counts, time bar), two fighters, a meeting point that moves with the score share, and the effects of every rule: grade word then "+N", combo "N HIT", FEVER ×2, the danger edge, the reject sign with a pictogram, K.O., TIME! and the verdict, then 결과 보기.
- **The camera area** (lower half): the camera uncropped, a one-line hint, the ready button, the setup bar, the reconnect band, the leave button.
- **The setup runs on the battle screen** for both battles.
  - Bot (team question 9, option A): pose check, 3·2·1, GO!.
  - Online: the same layout.
  - #49's push-up silhouette lies over the camera. The strips a cropping camera would not show are dimmed in its shade.
- **Online:** the server's scores, the opponent's zero-point reps as a miss, reconnecting, and the result to `/result`.
- **Matching:** the radar, MATCH FOUND and the safety dialog in palette B. The safety picture is now drawn from the design's SVG; the old white-line PNG vanished on the light box.
- **Settings:** the '매 경기 안전 안내' switch. On: the notice shows every match. Off: only until it was seen once. The setting is kept across restarts.
- **Setup words in Korean**, the same sentences as the voice guidance. One or two missing parts are named; three or more say "몸 전체가 화면에 보이게 해 주세요.". The ready button reads "시작" (bot) and "준비" / "준비 취소" (online).
- **Sound hooks for J2:** `onCue` and `onSetup` on both battle screens and on the online lobby.

The branch contains `origin/main` `6e87a0f` and #49 `origin/feat/pose_silhouette_guide` `3efe402`. On 2026-11-13 `git fetch` found nothing new on either, and merging both said "Already up to date".

I ran the commands from the Plan in `gymrats_app/` on Windows, on `6a8efba`, without coverage. Coverage comes from the PR's CI comment "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | not measured on this Windows PC (coverage collection hangs); TODO(Woohyun Song): fill from the PR's CI coverage comment | 11/13 | CI comment "Tests and coverage (GitHub Actions)" on the W2 PR |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the CI comment | 11/13 | same |
| Service | flutter_test, MockClient, fakes | 85% | TODO(Woohyun Song): from the CI comment | 11/13 | same |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the CI comment | 11/13 | same |
| API server | pytest, pytest-django, pytest-cov | 90% | not run here; `server/` unchanged | 11/13 | CI `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` had 2113 passed, 0 failed and 10 skipped. `flutter analyze` found no issues.
  - The 10 skipped tests are the same as on 11-08, and W2 does not touch them:
    - `test/services/online/public_wss_smoke_test.dart`: a live server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`;
    - 9 known push-up judge errors in `test/services/pose/pushup_error_cases_test.dart`, each with its reason.
  - W2 adds 17 test files, two of them data files: the design's golden samples and the reviewed drawings. It changes 28 and deletes 3.
  - The deleted ones are the tests of `game_health_bar.dart`, `game_fever_chip.dart` and `game_danger_edge.dart`, which the stage replaces. The PM approved removing them.
- **The design check:** `test/widgets/battle_fx_motion_test.dart` compares the stage's effect math with the design prototype's own samples.
  - `test/widgets/battle_fx_golden.json` holds spec v2.2's 18 scenarios with 248 samples: positions, rotations, sizes and opacities of the fighters, bands, star, sign and HUD. A changed design number fails it.
  - The drawings (5 fighter poses, 10 pictograms) are pinned call by call in `test/widgets/battle_art_drawings.json`.
- **Tests checked against wrong code:** in every step I planted single-number and single-line changes ("mutants") in the new code and reran its tests. The reviewer subagent planted more in its runs. A mutant that survived got a test. The counts per step are in my AI notes, item c.
- **Other checks:**
  - `ownership_guard.py --check-diff` flags only the 6 files #49 brought: `setup_screen.dart`, `pose_silhouette_guide.dart` and its test, and 한상우's three notes. This is expected until #49 is merged into `main`.
  - Every other file outside W2's list is covered by an approved exception line.
  - Server `pytest` was not run, because `server/` did not change.
- **Coverage:** TODO(Woohyun Song): fill from the PR's CI comment (commit, run link, per-layer numbers, any test file left out by CI's time limit).
- **Shortfalls:** TODO(Woohyun Song): after the CI comment.
- **Screen readers:** widget tests check the words of the stage and the camera area through the semantics tree: the labels, the live-region announcements and the safety picture's label. TalkBack on a real phone was **not** checked.
- **Manual check (2026-11-13, the user, on a phone):** the user's words: "폰 확인을 마쳤고 대결은 문제 없어." The follow-ups below show that the setup, the matching radar and the match-found screen were seen on the phone. The phone check lists are in the PR.
  - TODO(Woohyun Song): the phone model(s) and Android version.
  - TODO(Woohyun Song): whether the online battle was run on two phones, and so whether UAT-3 AC2's "within a second" was seen.
  - TODO(Woohyun Song): whether the stage demo and the safety picture drawn since `3688547` were checked (the 11-12 look at the dialog was at the old PNG).
  - Left for later changes:
    - a larger camera during the setup;
    - radar blips that blink as the sweep passes;
    - the match-found screen's colors and "VS".
  - Found for S3 (not W2): in the push-up setup the pose can turn ready before the body lines up with the silhouette.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/battle_fx_motion_test.dart` (new) + `battle_fx_golden.json` | the stage's effect math against the design prototype's 248 samples in 18 scenarios: the meeting point's follow, the lunge, hit-stop, shake and zoom, the star, twinkle and puff, the reject sign, the bands' size rule (`bandBox`) and places, combo marks, fever and danger, the K.O. flight, TIME! and the verdict, the countdown and GO!, 결과 보기; the grade word then "+N"; a late result of another kind; reduced motion; cues given once each |
| View | `test/widgets/battle_stage_model_test.dart` (new) | the stage's inputs: events, endings, the reject sign's short labels and pictograms per reason |
| View | `test/widgets/battle_art_path_test.dart`, `battle_fighter_test.dart`, `battle_reject_sign_test.dart`, `battle_banner_test.dart`, `battle_stage_hud_test.dart` (new) + `battle_art_drawings.json`, `battle_test_support.dart` | the design's path data read as drawn; 5 poses and 10 pictograms pinned call by call; the bands (ink text on slanted, ink-edged fills); the HUD's names, clock, chip, scores, counts and time bar, with pixel probes and the app's real fonts |
| View | `test/widgets/battle_stage_test.dart`, `battle_arena_test.dart` (new) | one frame of the stage; the arena's layout on several phones; one clock; the danger edge; the sign over the line; cues for sound; announcements for screen readers; 결과 보기 |
| View | `test/widgets/battle_camera_area_test.dart` (new) | the camera area's buttons, hint, setup bar, reconnect band and combo marks; it follows the system text size (1.3× and 2× fit); every setup hint and online line fits its two lines at 1.3× on a 360-wide phone beside "시작", "준비" and "준비 취소" |
| View | `test/widgets/battle_camera_view_test.dart` (new) | the camera in its own shape; the chest and squat lines; the silhouette over the part a cropping camera shows; the strips around it dimmed in its shade with no lighter seam (pixel test); the strips take no taps |
| View | `test/widgets/battle_stage_events_test.dart`, `battle_online_events_test.dart` (new) | the bot's and the online state turned into stage events and state, deciding nothing; the opponent's miss online; snapshots replay nothing |
| View | `test/screens/battle_screen_test.dart` (updated) | the bot battle on the stage, from the setup: band, tags, hint, 시작, camera switch; the silhouette; 3·2·1 and GO!; the round, fever, TIME! and the verdict, K.O., 결과 보기; back; the app paused; camera failure and retry; **UAT-1 AC1–AC3 and step 5 through the battle screen, with the setup's real times**; `onCue` and `onSetup` |
| View | `test/screens/online_preparation_test.dart` (updated) | the online battle on the stage, from the setup: ready and auto ready, 준비 / 준비 취소, the countdown, the silhouette, the server's scores, the opponent's miss, fever, reconnecting, the endings and `/result`, the ended page; `onCue`; `onSetup` with the time to the server's start |
| View | `test/screens/matching_screen_test.dart`, `versus_screen_test.dart`, `online_lobby_screen_test.dart` (updated) | the radar (still with reduce motion, one picture for screen readers); MATCH FOUND; the safety switch (every match, once seen, kept); the lobby passing the sound hooks on; the lobby's plain page in palette B |
| View | `test/widgets/safe_warning_dialog_test.dart` (updated) | the picture drawn from the SVG: numbers, order, colors and widths, the drops' curves, pixels, 3:1 contrast, one scale on a 360-wide phone (232 × 150) |
| View | `test/widgets/exit_dialog_test.dart`, `exit_game_button_test.dart`, `player_avatar_test.dart`, `battle_live_indicators_test.dart`, `game_panel_fonts_test.dart` (updated) | the leave dialog, the leave button and the avatar in palette B; the tests of the removed widgets taken out |
| View | `test/screens/settings_screen_test.dart`, `home_screen_test.dart` (updated) | the '매 경기 안전 안내' row first in 게임, read as one switch; the 효과음 switch found by its title |
| View | `test/screens/result_screen_test.dart` (updated, exception) | online, 다시 매칭 opens the lobby; a win because the opponent left, and a loss because my connection dropped, are said so |
| ViewModel | `test/viewmodels/battle_viewmodel_test.dart` (updated) | the setup phase; the count to the start; 시작 starts at once; the round's own clock; the `BattleViewModel.bot` / `botCounter` wiring |
| ViewModel | `test/viewmodels/settings_viewmodel_test.dart` (updated) | the safety notice: on and not seen at first; the rule table; the switch and the seen mark saved; kept across a restart; the user's value wins while loading; failed reads and saves; dispose |
| ViewModel | `test/viewmodels/setup_viewmodel_test.dart` (updated, exception) | the Korean setup words; "준비 완료! N초 뒤 시작해요." |
| Service | `test/services/game/online_battle_result_test.dart` (new) | the result of an online battle the server finished, incl. who left |
| Service | `test/services/online/online_battle_integration_test.dart` (updated, exception) | the session's count of the opponent's zero-point reps |
| Service | `test/services/pose/setup_checker_test.dart` (updated, exception) | the Korean words, the same lines as the voice; parts named with 이/가; three or more parts give the whole-body line |
| Service | `test/services/user/settings_store_test.dart` (updated, exception) | the safety switch and its seen mark under their own keys, kept for a new store |
| Model | `test/models/battle_result_test.dart` (updated) | `BattleResult.departure` |
| Design | `test/theme/app_theme_test.dart`, `test/design_tokens_test.dart` (updated) | the stage's text styles and tokens, `setupGuideScrim`; the new widget files added to the token check, the three removed ones taken out (PM OK) |
| App flow | `test/main_test.dart`, `test/demo/battle_demo_test.dart`, `pose_setup_demo_test.dart`, `test/screens/setup_screen_test.dart`, `match_setup_screen_test.dart` (updated; some exceptions) | the stage demo; the setup words; one test renamed for what it checks |

### Acceptance criteria → tests
- Given a bot or online battle, then every UAT-5 rule still shows in the new layout (grade labels, combo, FEVER ×2, K.O.). Tests:
  - `'my counted rep: GOOD, then +10, the score and my valid rep on the stage, the chest lines on the camera'`
  - `'fever turns the stage cyan 20 s into the round, counted from GO!, not from the camera'`
  - `'a KO plays the ring-out to 결과 보기, which opens the result in place'`
  - `'two counted reps within the combo window: the second earns the bonus and "2 HIT" shows over the camera (UAT-5 combo)'` (through the bot battle screen)
  - `'a combo shows "2 HIT" over the camera, 14 under the line on the left, and under the reconnect band while it is up'` (the arena)
  - `'$name: every sample matches within the design tolerance'` (18 design scenarios)
- Given an online battle, then both phones show the same health bar and scores within a second (UAT-3 AC2). The stage shows the server's numbers, bar included; "within a second on both phones" is a two-phone manual check (open TODO above). Test: `"the stage shows the server's scores, valid reps and bar, and the camera its chest lines"`.
- UAT-1 runs through the battle screen's setup (현우's condition). Tests:
  - `'AC1, step 2 (push-up): a phone lying almost flat, then the left wrist out of the picture: the hint says what to fix, and nothing counts down'`
  - the `'AC2, step 3 (push-up): …'` and `'AC3, step 4 (push-up): …'` tests
  - `'step 5 (squat): missing feet and standing too close are named, …'`
- The safety switch: on, every match; off, until seen once; kept across restarts. Tests:
  - `'on, as designed: every match shows it, seen or not; 확인 counts as seen'`
  - `'off: it shows until it is seen once, then a match goes straight to the setup button'`
  - `'off and seen in an earlier run: no warning, the setup at once'`
