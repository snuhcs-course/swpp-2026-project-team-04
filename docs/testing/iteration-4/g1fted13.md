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
This step replaces the bot and online battle screens with one fighting stage, as designed (candidate A from the user's design canvas, spec v2.2), and redraws the matching screens in palette B:
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
| Model | flutter_test | 90% | 97.4% (266/273) | 11/13 | CI comment "Tests and coverage (GitHub Actions)" on PR #50, commit `7f12f3e`, [run 43260166309](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43260166309) |
| ViewModel | flutter_test, fakes | 90% | 96.6% (1096/1135) | 11/13 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 94.9% (2447/2578) | 11/13 | same CI comment |
| View | flutter_test (widget) | 75% | 94.1% (5924/6295) | 11/13 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (101 passed; `server/` unchanged) | 11/13 | CI `pytest --cov=accounts --cov=matches --cov=gymrats` on `7f12f3e` |

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
- **Coverage:** from the CI comment on PR #50 ([comment](https://github.com/snuhcs-course/swpp-2026-project-team-04/pull/50#issuecomment-6829754908)), commit `7f12f3e` (2026-11-13 01:41 KST; the app and server jobs both succeeded; [run 43260166309](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43260166309)). `7f12f3e` changes only these notes on top of `6a8efba`.
  - App total 94.6% (9972/10537); Other 93.4% (239/256).
  - CI also ran `flutter analyze` (no issues) and `flutter test` (2113 passed, 10 skipped, 0 failed), the same as on this PC.
  - The drawings fixture (`battle_art_drawings.json`) was recorded on Windows. It passes on CI's Linux too.
  - Left out of the coverage numbers by CI's 240 s limit per file: `test/screens/result_screen_test.dart`, as on 11-08 and 11-11. Its tests still ran and passed in `flutter test`. So the two places W2 changed in `result_screen.dart` (under its exception) are not in the View number.
- **Shortfalls:** none; every layer and the server meet their targets.
- **Screen readers:** widget tests check the words of the stage and the camera area through the semantics tree: the labels, the live-region announcements and the safety picture's label. TalkBack on a real phone was **not** checked.
- **Manual check (2026-11-13, the user, on a Galaxy S26+ (SM-S947N) with One UI 9.0 and Android 17):** "폰 확인을 마쳤고 대결은 문제 없어."
  - Seen on the phone:
    - real bot battles, push-ups and squats, with the effects they produce, including the setup;
    - the matching radar and the match-found screen;
    - the safety picture drawn since `3688547`.
  - The online battle on two phones: not checked; to be checked with a teammate's phone before the UAT. The same holds for UAT-3 AC2's "within a second".
  - The stage demo was not run.
  - The effects only an online battle shows were not seen on a phone: the reconnect band, the opponent's lost connection, the opponent leaving, and a loss by my lost connection.
    - All four are checked by widget tests (`online_preparation_test.dart`, `battle_arena_test.dart`, `battle_fx_motion_test.dart`).
    - Three are also in the design comparison (`battle_fx_golden.json`: `combo_while_reconnecting`, `opponent_disconnected`, `opponent_left`).
    - The loss by my lost connection is the mirror of `opponent_left` and is checked by widget tests only, e.g. 'my connection lost too long: I vanish and lose'.
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
- Given an online battle, then both phones show the same health bar and scores within a second (UAT-3 AC2). The stage shows the server's numbers, bar included; "within a second on both phones" is a two-phone manual check: not checked; to be checked with a teammate's phone before the UAT. Test: `"the stage shows the server's scores, valid reps and bar, and the camera its chest lines"`.
- UAT-1 runs through the battle screen's setup (현우's condition). Tests:
  - `'AC1, step 2 (push-up): a phone lying almost flat, then the left wrist out of the picture: the hint says what to fix, and nothing counts down'`
  - the `'AC2, step 3 (push-up): …'` and `'AC3, step 4 (push-up): …'` tests
  - `'step 5 (squat): missing feet and standing too close are named, …'`
- The safety switch: on, every match; off, until seen once; kept across restarts. Tests:
  - `'on, as designed: every match shows it, seen or not; 확인 counts as seen'`
  - `'off: it shows until it is seen once, then a match goes straight to the setup button'`
  - `'off and seen in an earlier run: no warning, the setup at once'`

#### 2026-11-14 · code at commit `47afaff` · step W3 `feat/characters` (P14 characters replace the avatars, with a selection screen, team order #11)
This step replaces the old avatars with six drawn characters. The design is the user's (spec v1.1 from the design canvas; rig data `w3-rig-2`).
- **The characters:** one data file (`assets/characters/w3_rig.json`) and one painter (`CharacterFigure`) draw all six in five poses (idle, attack, hit, K.O., win).
  - Five can be picked: GYM마우스 (`mouse`, the default), 그루 (`kangaroo`), 곰탱이 (`bear`), 펭뚱이 (`penguin`) and 물렁범 (`seal`). RepBot (`bot`) is the bot's.
  - Each character has its own idle motion: a hop, a rock or a stretch.
- **The stage:** the bot and online battles draw the two characters instead of W2's stand-in fighter.
  - The opponent idles 230 ms after me, the hit star sits where the blows land, and each character draws its own flash.
  - Without characters the stage keeps W2's values, so W2's `battle_fx_golden.json` passes unchanged.
- **캐릭터 선택:** a screen after the design `ChSelectB`. It opens from 게임 시작's new 캐릭터 row and from 환경설정's 캐릭터 row (was 아바타).
  - The choice is saved per account in the phone's secure storage.
  - Nothing saved, an unknown id, RepBot or an old avatar id all read as the mouse.
- **Online:** the app sends its character id in the protocol's existing `avatar_id` field.
  - The battle server takes the field as optional, checks only its shape (1 to 32 lowercase letters, digits or `_`) and passes it on.
  - An older server that refuses the character with `INVALID_AVATAR` gets one more `queue.join` with `avatar_01`.
  - An opponent's id that is not one of the five draws the mouse.
- **The old 3D avatars are gone:** the profile screen with its avatar list in `83c00ce`; the 3D models, the viewers, the opponent mannequin and `tools/avatar-preview/` in `dded304`. `PoseAvatarToggleView` now shows the camera only.

The branch was made from W2's head `38ea06d` before #50 was merged. On 2026-11-14 I merged `origin/main` `1ed57ca` (#49 and #50) into it as `47afaff`. There was no conflict, and `main` brought no file change: `git diff 38ea06d 1ed57ca` is empty.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `47afaff`, without coverage. Coverage comes from the PR's CI comment "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.2% (470/474) | 11/14 | CI comment "Tests and coverage (GitHub Actions)" on PR #52, commit `a55507b`, [run 43457588271](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43457588271) |
| ViewModel | flutter_test, fakes | 90% | 96.7% (1151/1190) | 11/14 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 95.3% (2259/2370) | 11/14 | same CI comment |
| View | flutter_test (widget) | 75% | 96.1% (5898/6139) | 11/14 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (101 passed; the Django code is unchanged, only the Dart battle server changed) | 11/14 | CI `pytest --cov=accounts --cov=matches --cov=gymrats` on `a55507b` |

- **Tests:** `flutter test` had 2263 passed, 0 failed and 10 skipped. `flutter analyze` found no issues.
  - The 10 skipped tests are the same as in W2:
    - `test/services/online/public_wss_smoke_test.dart`: a live server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`. W3 builds its sessions with character ids. It expects the opponent's character to be the mouse until the W3 battle server is deployed.
    - 9 known push-up judge errors in `test/services/pose/pushup_error_cases_test.dart`, each with its reason.
  - `main` before W3 had 2113 passed, so W3 adds 150 tests in all.
  - W3 adds 7 test files and two fixtures, changes 20 test files and deletes 4.
    - The fixtures are the design's idle samples (`test/models/character_idle_golden.json`) and 36 of the design's 60 shots (`test/widgets/character_shots/`).
    - The deleted files tested removed code: the profile screen, the avatar pose payload, the opponent avatar panel and the opponent mannequin.
- **The design check:**
  - `character_idle_motion_test.dart` compares every character's idle motion, and W2's breathing, with the design's own samples.
  - `character_figure_test.dart` paints each of the 36 shots and compares it pixel by pixel with the design's PNG. At most 0.03% of the pixels may differ (smoothed edges). One test shows that the comparison catches a wrong picture: the other team's colors, or one missing eye shine.
  - `character_rig_test.dart` checks the rig against `assets/characters/w3_rig.json` and the spec: the box, the order, the names, the five poses, where every attack ends (`hit_contact.json`), the hit star (48 px over, 58 px up) and the 230 ms. It also checks that a malformed rig is refused.
- **Tests checked against wrong code:** the reviewer planted mutants in runs 1 and 2. In the painter, 13 of 14 were caught; the one left changes no pixel. In the stage wiring, 15 of 16 were caught, and the one left got a test. The two tests of run 3's double-tap fix fail on the old code.
- **Other checks:**
  - `ownership_guard.py --check-diff` is ok: 235 changed files. Each is W3's or is under an approved exception line; the exceptions are listed in the PR.
  - The Dart battle server changed (`server/lib/battle_server.dart`). Its tests run in `flutter test` (`test/services/online/online_battle_integration_test.dart`). The Django server did not change, so `pytest` was not run on this PC.
- **Coverage:** from the CI comment on PR #52 ([comment](https://github.com/snuhcs-course/swpp-2026-project-team-04/pull/52#issuecomment-6858206591)), commit `a55507b` (2026-11-14 01:02 KST; the app and server jobs both succeeded; [run 43457588271](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43457588271)). `a55507b` changes only these notes on top of `c057a58`, and `c057a58` only two comments on top of `47afaff`.
  - App total 96.1% (10033/10445); Other 93.8% (255/272).
  - CI also ran `flutter analyze` (no issues) and `flutter test` (2263 passed, 10 skipped, 0 failed), the same as on this PC.
  - The pixel comparison with the 36 design shots, run on Windows so far, passes on CI's Linux too.
  - Left out of the coverage numbers by CI's 240 s limit per file: `test/screens/settings_screen_test.dart`. Its tests still ran and passed in `flutter test`. So W3's change to `settings_screen.dart` (the 캐릭터 row, under its exception) is not in the View number.
- **Shortfalls:** none; every layer and the server meet their targets.
- **Screen readers:** widget tests check that each cell of 캐릭터 선택 says its name and animal and whether it is picked. TalkBack on a real phone was **not** checked.
- **Manual check (the user, reported 2026-11-14, on a Galaxy S26+ (SM-S947N) with One UI 9.0 and Android 17):** the user found nothing to fix in W3's code.
  - Seen on the phone:
    - picking a character with 게임 시작's 캐릭터 row;
    - a bot battle with the chosen character (물렁범): its idle, hit and K.O. motions.
  - Not in the reported check: the online battle on two phones, which shows the opponent's character and also needs the W3 battle server deployed; 환경설정's 캐릭터 row; a second account; the stage demo's character buttons; reduced motion; TalkBack.
  - Left for later steps (the user's plan): the character on the main menu (W4) and the screen after the battle (W2b). MATCH FOUND still draws W2's stand-in in `_VersusCharacter` (`versus_screen.dart`, on W2b); it gets the W3 character once W2b and W3 are both in `main`.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/character_rig_test.dart` (new) | the rig equals `assets/characters/w3_rig.json`; `w3-rig-2`'s 140 × 160 box; six characters in order, with the names of 11-13; five poses with fourteen values each; the shapes per character; expressions only in their poses; the design colors, no character lime or pink; outlines; the default mouse and RepBot; every other choice reads as the mouse; the stage values (where attacks end, the hit star, 230 ms, each idle motion); a malformed rig is refused and says where |
| Model | `test/models/character_idle_motion_test.dart` (new) + `character_idle_golden.json` | each character's idle motion and W2's breathing against the design's samples; a hop never goes below the floor; stepped and smooth rocks; a stretch; a period of 0 turns its part off |
| Model | `test/models/avatar_catalog_test.dart` (updated) | the kept avatar ids only (the asset getters are gone) |
| View | `test/widgets/character_figure_test.dart` (new) + `character_shots/` (36 PNG) | the painter against 36 design shots, pixel by pixel, and a check that the comparison catches a wrong picture; size, pose and team; an unknown id draws the mouse; the idle figure (its motion, still with reduced motion); `BattleCharacters`; the theme colors are the rig's; even scaling in a box of another shape; every pose in both teams, with and without the flash |
| View | `test/screens/character_select_screen_test.dart` (new) | the account's character large with its name and line; a tap changes only the preview; 이 캐릭터로 하기 saves and goes back; during a slow save a second tap or back goes back only once; back saves nothing; the layout and type of ChSelectB; each cell read with its name and animal; the picked cell; 360 × 640 and a large text size |
| ViewModel | `test/viewmodels/character_viewmodel_test.dart` (new) | the app-wide character: the mouse before login, the account's saved one after it, another account, logout, choosing saves for the signed-in account, RepBot not choosable, a failed save, a slow read does not undo a choice |
| ViewModel | `test/viewmodels/character_select_viewmodel_test.dart` (new) | the five in order, each said as its animal and a few words; picking changes only the preview; confirming saves; a second confirm while saving does nothing |
| Service | `test/services/user/character_store_test.dart` (new) | per account in secure storage; nothing saved, unknown, RepBot or an old avatar id read as the mouse; an unreadable value; a failed write reaches the caller; the in-memory store |
| Service | `test/services/online/online_battle_integration_test.dart` (updated) | `avatar_id` carries the character: the server checks only the shape, passes the id on in `match.found`, the snapshot and the result, and leaves it out for a player who sent none; RepBot, an old avatar id or nothing reads as the mouse; an older server: one resend with `avatar_01`, also after a reconnect, and a second refusal fails the search; every character a person may pick reaches the opponent |
| Service | `test/services/game/online_battle_result_test.dart`, `test/services/online/battle_result_store_test.dart`, `public_wss_smoke_test.dart` (updated, exceptions) | sessions and players built with a character id instead of `AvatarModel` |
| View | `test/widgets/battle_fx_motion_test.dart`, `battle_stage_test.dart`, `battle_arena_test.dart` (updated, exceptions) | without characters, W2's breathing and star; with them, each side's idle (hop, rock, stretch), the opponent 230 ms later, only the idle pose moves, the danger sway, reduced motion, the star at (xm ± 48, 288); the characters in their poses and team colors, the hit one flashing on its own; the fever aura |
| View | `test/screens/battle_screen_test.dart`, `online_preparation_test.dart`, `online_lobby_screen_test.dart` (updated) | my character against RepBot; the mouse when none is given; online, mine and the one the opponent sent; the lobby matches with my character |
| View | `test/screens/play_screen_test.dart`, `settings_screen_test.dart`, `home_screen_test.dart` (updated, exceptions) | 게임 시작's 캐릭터 row shows my character, opens 캐릭터 선택 and follows a new choice; 환경설정's 캐릭터 opens the selection; the app-wide view model in the test apps |
| View | `test/widgets/pose_avatar_toggle_view_test.dart` (updated), `battle_live_indicators_test.dart`, `battle_online_events_test.dart` (updated, exceptions) | the camera-only view: no avatar button, the pose and both height gauges on the given frame; one gauge test rewritten for it; the online events with character ids |
| App flow | `test/main_test.dart`, `test/demo/battle_demo_test.dart` (updated; the demo under an exception) | the account's saved character on 게임 시작; a pick is saved and goes into the next bot battle; logout puts the mouse back; the online route sends the account's character; the stage demo's character buttons |
| Design | `test/design_tokens_test.dart` (updated) | `character_select_screen.dart` and `character_figure.dart` in the token check |

### Acceptance criteria → tests
- Given I open character selection and pick one, then it is saved for my account. Tests:
  - `'이 캐릭터로 하기 saves the pick for the account and goes back'`
  - `'choosing saves for the signed-in account and shows at once'`
  - `'keeps the choices per account while the app runs'`
  - `'another account starts from the mouse, then shows its own'`
- …and shown in battle. Tests:
  - `'a pick on 캐릭터 선택 is saved for the account, shows on 게임 시작 and goes into the next bot battle'`
  - `'the stage shows my character against RepBot'`
- …and shown to my online opponent. Tests:
  - `'every character a person may pick matches and appears on the opponent client'`
  - `'a character id is passed on to the opponent as it came, in match.found, the snapshot and the result'`
  - `'the stage draws my character and the one the opponent sent'`
  - `'the online route sends the character of the account'`
  - On real phones this needs the W3 battle server deployed; it was not checked on two phones.

#### 2026-11-14 · code at commit `1f7e6f5` · step W3 `feat/characters`, follow-up to the Codex review of PR #52 (team order #11)
The Codex review of PR #52 left one comment (P2, `lib/viewmodels/character_select_viewmodel.dart`). This push fixes it on the same branch.
- **The problem:** home could open as soon as the rules check ended, while the account's character was still being read.
  - 캐릭터 선택 then started on the stand-in `mouse`, and 이 캐릭터로 하기 saved `mouse` over the saved choice.
  - A battle opened then got `mouse` too.
- **The fix (`1f7e6f5`).** The user chose between two options the agent gave:
  - Home waits until the account's character is read, behind the same spinner as the rules check. A read that fails counts as the default, so the wait always ends.
  - 캐릭터 선택 keeps a second guard. Before the read ends, the button shows "저장된 캐릭터를 불러오는 중…" and takes no taps. When the read ends, the preview takes the saved character, unless a cell was picked meanwhile.
  - A choice made during the read still wins over the read (the rule of 11-13).
  - Only W3 files changed: `main.dart`, `character_viewmodel.dart`, `character_select_viewmodel.dart`, `character_select_screen.dart` and their tests.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `1f7e6f5`, without coverage. The coverage comes from the PR's CI comment on `1f7e6f5`, [run 43475382323](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43475382323).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.2% (470/474) | 11/14 | CI comment "Tests and coverage (GitHub Actions)" on PR #52, commit `1f7e6f5`, [run 43475382323](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43475382323) |
| ViewModel | flutter_test, fakes | 90% | 96.8% (1165/1204) | 11/14 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 95.3% (2259/2370) | 11/14 | same CI comment |
| View | flutter_test (widget) | 75% | 96.1% (5902/6143) | 11/14 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (101 passed; `server/` unchanged) | 11/14 | same CI comment |

- **Tests:** `flutter test` had 2278 passed, 0 failed and 10 skipped. `flutter analyze` found no issues.
  - The 10 skipped tests are the same as before.
  - The count grew from 2263 by the 15 new tests below. No test was removed.
  - Two existing tests in `character_viewmodel_test.dart` counted the notifications of a load. A load now notifies twice, as the read starts and as it ends. Their intent is kept:
    - 'a login reads the account's saved character' expects 2, with that reason;
    - 'RepBot or an unknown id cannot be chosen' starts its count after the load.
- **Tests before the fix:** the agent wrote the reproduction first and ran it on the code before the fix (`15434a6`). All three tests failed:
  - in `character_select_viewmodel_test.dart`, 'confirming saves nothing over the saved character': the saved `seal` became `mouse`;
  - in `main_test.dart`, the first two app tests: the same overwrite through 캐릭터 선택, and a bot battle built during the read got `mouse`.
  - After the user chose the fix, the app tests were rewritten for "home waits". On a copy of the old code, with the one line that reads the new `loading` dropped, all three final app tests fail. The new screen test fails there too.
  - The view-model tests use the new API (`loading`, `isReadyFor`, `ready`), so they do not compile on the old code.
- **Other checks:** `dart format` leaves the 8 changed files unchanged, and `ownership_guard.py --check-diff` is ok (238 files). Server `pytest` was not run on this PC, because `server/` did not change.
- **Coverage:** from the CI comment on `1f7e6f5` (2026-11-14 02:49 KST; the app and server jobs both succeeded).
  - App total 96.1% (10052/10464); Other 93.8% (256/273).
  - CI's `flutter analyze` and `flutter test` (2278 passed, 10 skipped, 0 failed) match this PC.
  - Still left out of the numbers by CI's 240 s limit: `test/screens/settings_screen_test.dart`; its tests passed.
- **Shortfalls:** none; every layer and the server meet their targets.
- **Review:** the reviewer subagent returned APPROVE (run 7) with 4 Minor findings. Three were fixed, among them the test 'a new account reads the rules meanwhile; after 시작하기 home still waits for the read'. It also fails on the old code. The fourth was kept: three near-identical slow-read fakes stay private, because the shared `test/support/fakes.dart` is the PM's.
- **Manual check:** not checked on a phone for this push.

### Test cases added or changed in this follow-up
| Layer | File | What it covers |
|---|---|---|
| App flow | `test/main_test.dart` (updated) | group 'while the saved character is still being read': home waits for the read, then 캐릭터 선택 and a bot battle start on the saved character and a pick keeps it; a new account reads the rules meanwhile and home still waits after 시작하기; a read that fails opens home with the mouse |
| View | `test/screens/character_select_screen_test.dart` (updated) | opened during the read: the hint, no taps, nothing saved; then the preview takes the saved character and the button saves |
| ViewModel | `test/viewmodels/character_select_viewmodel_test.dart` (updated) | during the read: confirming saves nothing over the saved character; not ready until the read ends; the preview takes the saved character if nothing was picked; a cell picked meanwhile stays and can then be saved; a read after the screen is gone changes nothing on it |
| ViewModel | `test/viewmodels/character_viewmodel_test.dart` (updated) | group 'loading': not loading before a login; loading from a login until the read ends, said both times; a choice during the read ends it and wins; a logout ends it; another account's loading is not ended by the first one's late read; a read that fails reads as the mouse and ends it; two tests count the load's two notifications |

### Acceptance criteria → tests (this follow-up)
- Given I picked a character, then it stays saved for my account, even when the app reads it slowly after a login. Tests:
  - `'home waits for it, so 캐릭터 선택 and a bot battle start on the saved character and a pick does not overwrite it'`
  - `'confirming saves nothing over the saved character'`
  - `'opened while the saved character is still read, 이 캐릭터로 하기 says so and cannot be pressed; then the preview takes the saved one and the button saves'`
- …and it is the one shown in battle. Tests:
  - the same first test (the bot battle gets `seal`)
  - `'a new account reads the rules meanwhile; after 시작하기 home still waits for the read'`
- A choice made during the read still wins (the rule of 11-13). Tests: `'a choice made while reading ends the loading and wins'`, `'a slow read does not undo a choice made meanwhile'`.

#### 2026-11-14 · code at commit `ae44bbb` · step W2b `feat/battle_screen_polish` (A2 polish of the battle and matching screens, team order #7)
This step polishes W2's screens, following the W2b design spec (`W2B-SPEC.md`, from the user's design canvas) and the user's follow-ups after W2's phone check:
- **3-B, the pose setup:** while setting up, the camera takes about 80% of the screen. The stage shows only its HUD, with a status band and two ready chips. The hint is a large one-line band and the ready button is large. When the countdown starts, the line comes down to W2's half-and-half layout in 350 ms and the fighters pop up. Going back to the setup reverses it. #49's silhouette keeps its place on the camera picture (option 가), so it grows with the picture.
- **1-A, the radar blips:** the three blips are red laser-pointer dots that light up as the sweep passes. The online lobby uses the same radar.
- **2-A3, MATCH FOUND:** a board with a lime cell (me) over a pink one (the opponent), each player on a white pedestal, and a "VS" disc. Since W3 (#52) is in `main`, the players are the W3 characters: my saved choice, RepBot for a bot, and online the character the server passed on, each with its own idle motion (the opponent's 230 ms later, as on the stage) and read as a picture with its name. (Built first with W2's stand-in fighter, then swapped in `ae44bbb`.)
- **The end screen (option A, the user's choice of three drawn options):** once the result is known, the line goes down to the bottom of the screen in 450 ms and the camera area disappears. The stage stays where it is, its ground fills the screen, and 결과 보기 stays in the middle of the lower half, now without the gray cover. An online time-up keeps the camera and the leave button until the server's result comes. With reduced motion the end look comes at once.
- **Old avatar words:** one comment in `battle_viewmodel.dart` and two test names still named the old mannequin.

Judging, scores, timing, the conditions for the result screen, the server and the protocol do not change.

The branch started on 2026-11-13 from W2's head `38ea06d`. On 2026-11-14 it merged `origin/main` twice:
- `1ed57ca` (#49, #50) as `46c394e`, with no conflict;
- `23879ca` (#51, #52) as `13d0b4d`, with conflicts in three W2b files: `battle_arena.dart`, `battle_fx_motion.dart` and `battle_arena_test.dart`. W3's idle motion and W2b's setup layout were both kept. Two W3 screen tests looked for the characters while setting up, where 3-B draws no fighter; they now check after the countdown.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `ae44bbb`, without coverage. Coverage comes from the PR's CI comment "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.2% (510/514) | 11/14 | CI comment "Tests and coverage (GitHub Actions)" on PR #54, commit `4cd89bc`, [run 43492170043](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43492170043) |
| ViewModel | flutter_test, fakes | 90% | 96.8% (1179/1218) | 11/14 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 95.3% (2259/2370) | 11/14 | same CI comment |
| View | flutter_test (widget) | 75% | 96.3% (6235/6475) | 11/14 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (101 passed; `server/` unchanged) | 11/14 | CI `pytest --cov=accounts --cov=matches --cov=gymrats` on `4cd89bc` |

- **Tests:** `flutter test` had 2362 passed, 0 failed and 10 skipped. `flutter analyze` found no issues.
  - The 10 skipped tests are the same as before, and W2b does not touch them: the live server check in `test/services/online/public_wss_smoke_test.dart` (runs only with `RUN_PUBLIC_BATTLE_SMOKE`) and 9 known push-up judge errors in `test/services/pose/pushup_error_cases_test.dart`, each with its reason.
  - W2b adds 1 test file and 1 data file, and changes 15 test files and 1 data file (the table below).
- **The design checks:**
  - `test/widgets/battle_w2b_golden.json` is the design's `w2b_golden.json`, byte for byte. 3-B is checked against its 39 `setupTransition` samples (the line, the camera box, the picture, what fades and pops) and 1-A against its `radar` samples.
  - `test/widgets/battle_fx_golden.json` (W2's samples) changed in one field only: the 17 `resultButton.scrim` values were removed, because option A leaves no camera to cover behind 결과 보기. The check of that field left `battle_fx_motion_test.dart`. Every other W2 sample is unchanged and still passes.
  - The end screen has no design samples: its progress is one pure function (`BattleFxFrame.endLayout`, `BattleArenaLayout.lineTop(progress, end:)`), tested at its start, middle and end for a knockout, a time-up decided at once or later, a player leaving, an end during the setup, and reduced motion.
- **Other checks:**
  - `ownership_guard.py --check-diff`: ok on `ae44bbb`: 32 changed files, all owned by W2b (with #50 in `main`, W2's and #49's files have left the diff).
  - Server `pytest` was not run, because `server/` did not change.
- **Coverage:** from the CI comment on PR #54 ([comment](https://github.com/snuhcs-course/swpp-2026-project-team-04/pull/54#issuecomment-6862902439)), commit `4cd89bc` (2026-11-14 04:32 KST; the app and server jobs both succeeded; [run 43492170043](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43492170043)). `4cd89bc` changes only these notes on top of `ae44bbb`.
  - App total 96.2% (10448/10859); Other 94.0% (265/282).
  - CI also ran `flutter analyze` (no issues) and `flutter test` (2362 passed, 10 skipped, 0 failed), the same as on this PC.
  - Left out of the coverage numbers by CI's 240 s limit per file: `test/screens/settings_screen_test.dart` (not a W2b file), as for W3. Its tests still ran and passed in `flutter test`.
- **Shortfalls:** none; every layer and the server meet their targets.
- **Screen readers:** widget tests check the words through the semantics tree: the large setup hint read whole, MATCH FOUND's "나, (name)" and "상대, (name), AI" and each character as a picture with its name, the radar as one picture, and 결과 보기 as a button. TalkBack on a real phone was **not** checked.
- **Manual check (the user, on the Galaxy S26+ (SM-S947N) with One UI 9.0 and Android 17 from W2's record):**
  - 3-B: the push-up setup passed with the body matched to the larger silhouette, and at the countdown the screen went to the 50 : 50 layout. No problems.
  - 1-A: the radar's red dots. No problems.
  - 2-A3: MATCH FOUND, first with W2's stand-in fighter. No problems.
  - A second check after the merge with W3 (2026-11-14), all with no problems:
    - MATCH FOUND with the W3 characters: my character and RepBot on their pedestals, with the white edge, the size and the idle motion;
    - the end screen after a KO: the line goes down, the stage fills the screen, and 결과 보기 is in the same place;
    - the end screen after a time-up: the fever wash filling the whole screen is fine too;
    - the setup: the camera at 80% and the switch at the countdown.
  - An online battle on two phones was not reported in this step.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/battle_fx_motion_test.dart` (updated) + `battle_w2b_golden.json` (new) + `battle_fx_golden.json` (updated) | the setup's layout and its move against the design's 39 samples; reduced motion; going back during the move or the pop; the status band fading with its words; the ready chips; the line going down after the battle: when it starts for each ending, 450 ms eased, an online time-up waiting for the server, reduced motion, the ending and the button's moment unchanged |
| View | `test/widgets/battle_arena_test.dart` (updated) | the setup's line, camera box and picture on two phones; the countdown's move; going back; a screen opening on the round; after the battle: the line and the camera going down, the ground filling the screen, the stage in place, 결과 보기 in the lower half with no cover, the online wait, reduced motion, an end during the setup |
| View | `test/widgets/battle_camera_area_test.dart` (updated) | the setup's large band, bar, camera switch and ready button; their fade at the countdown (no taps, not read); every setup line on one line at 1.3× and 2×; 결과 보기's tests moved out |
| View | `test/widgets/battle_result_button_test.dart` (new) | 결과 보기: lime with an ink edge, words and arrow, read as a button, opens the result, comes up as the effect says, fits at 1.3× and 2× on 360 and 320 wide |
| View | `test/widgets/battle_camera_view_test.dart` (updated) | the picture fills the setup's box and fits whole in the battle's; the silhouette keeps its place on the picture (option 가) and its shape |
| View | `test/widgets/battle_stage_test.dart`, `battle_banner_test.dart` (updated) | no fighters or tags while setting up; the ready chips; the valid counts fading in; the Korean bands |
| View | `test/screens/battle_screen_test.dart`, `online_preparation_test.dart` (updated) | the bot and online setups in the new layout, with the silhouette's place; W3's two character tests now look for the characters after the countdown (none while setting up) |
| View | `test/screens/matching_screen_test.dart`, `online_lobby_screen_test.dart` (updated) | the blips against the design's `radar` samples, every 50 ms over two turns; their look; still with reduced motion; a stopped radar keeps its blips; the same radar in the online lobby; the lobby gives MATCH FOUND the session's two characters |
| View | `test/screens/versus_screen_test.dart` (updated) | the board, cells, pedestals, white edges, words and pills; long names cut and read whole; online without the AI pill; the low-cell scale; the W3 characters: my saved choice against RepBot, the lobby's two online, the default for an unknown person, each read as a picture with its name; their idle motions against W3's (the opponent 230 ms later), the white copies moving with them, under the safety warning, still with reduced motion |
| View | `test/demo/battle_demo_test.dart` (updated) | the stage demo after an ending: its buttons go with the camera, and 결과 보기 starts over |
| ViewModel | `test/viewmodels/battle_viewmodel_test.dart` (updated) | two test names: "swings the opponent" instead of the old mannequin |
| Design | `test/theme/app_theme_test.dart`, `test/design_tokens_test.dart` (updated) | the setup's and the board's text styles; the new widget file in the token check |

### Acceptance criteria → tests
- 3-B: during the setup the camera takes about 80% of the screen; at the countdown the line comes down in 350 ms and the fighters pop up; going back reverses it; reduced motion jumps. Tests:
  - `"every sample matches: the line's progress, what fades, the fighters and the number"` (the design's 39 samples)
  - `'setting up, the camera takes the screen from 156 down, over the stage, the picture fills it, and no fighter is drawn'`
  - `'the countdown brings the line down in 350 ms, then the fighters pop up, as the design times it'`
  - `'back to the setup during the countdown, the fighters fade out and the line goes back up'`
  - `"with reduced motion the countdown jumps to the battle's layout, and back"`
- 1-A: the blips light up as the sweep passes, as the design's samples say. Tests: `'every 50 ms over two turns: the sweep and the three blips'`, `'a radar stopped when the search ends keeps its blips as they were, fading or lit'`
- 2-A3: the board, the players and their words; reduced motion; the W3 characters. Tests:
  - `'the board (W2b 2-A3): a lime cell over a pink one, an ink line between, a white VS disc over its middle, in one ink-edged box that takes the height between the header and the rules'`
  - `'beside each character: "나" or "상대" on a white pill over the name in Do Hyeon 28, and "AI" on a pill for a bot; …'` (the name goes on about the sides and the cell's middle)
  - `'with reduced motion they stand still in the idle pose and nothing keeps the screen redrawing'`
  - `"the user's saved character stands against RepBot; online, the characters the lobby gives, the opponent's as the server sent it; each is read as a picture with its name"`
  - `"they move by their own idle motions from the moment the board shows, the opponent's running 230 ms later, as on the stage; the pedestals and the words stay"`
- The end screen: the camera goes once the result is known, the stage fills the screen, 결과 보기 stays in place; the ending and the way to the result do not change. Tests:
  - `'a knockout: once the blow lands the line goes down in 450 ms, the camera with it, the ground fills the screen and the stage stays; 결과 보기 comes up in the middle of the lower half, with no dimming'`
  - `'online, a time-up waiting for the server keeps the camera and the way out until the result comes, then the line goes down'`
  - `'with reduced motion the camera is gone at once'`
  - `"the ending itself, the button's moment and the setup layout do not change with it"`
  - unchanged and passing: `'a KO plays the ring-out to 결과 보기, which opens the result in place'` (the bot battle screen)

#### 2026-11-14 · code at commit `80b00d7` · step W4 `feat/home_character` (P17 the chosen character on home, team order #14)
This step puts the account's character on home and tidies home around it, in three parts (all on 2026-11-14):
- **Part 1 (the user's list, before the design package):**
  - Home's menu has four rows: 01 / PLAY 게임 시작, 02 / CHARACTER 캐릭터 (new; opens 캐릭터 선택), 03 / ARCHIVE 기록보관소, 04 / SETTINGS 환경설정.
  - 게임 시작 loses its 캐릭터 row; 환경설정 keeps its own.
  - The logo reads GYMMOUSE (the app's new name).
  - On 캐릭터 선택 the line under the name band moved under the floor (the user's choice of three drawn options), because 그루's ears covered it, found on the phone. The band's name keeps the design's size at any text size, and the line grows up to 1.5×.
- **Home fit (after the phone check: home still scrolled):** `origin/main` (W2b #54, J2 #53) merged as `7be4abb` with no conflict. Home then follows the design's 76 px menu layout: the logo 40, the menu titles 44, rows of 75 (the design's gaps in token steps). The logo and the titles keep their size at any text size. Nothing scrolls at the default text size on 360 × 780 (three-button or gesture bar) or 412 × 915, the unsaved-battles note included.
- **Part 2 (the W4 design package `W4-HOME-SPEC.md`, numbers from `w4_home_rig.json`):**
  - In RepBot's place the character does its exercise again and again: GYM마우스 and 그루 push-ups, 곰탱이 the one-two punch, 펭뚱이 and 물렁범 squats. No stand, no name band.
  - The whole room is one button to 캐릭터 선택, read as "캐릭터 바꾸기, 지금 캐릭터 (name)". With reduced motion it shows one rest picture.
  - Its clock stops while a page covers home or the app is in the background, and the motion starts from 0 when home shows again or the character changes.
  - `CharacterFigurePainter` takes a pose table, expression tags, draw patches and motion flags from outside, so W5 can add its own patches. The stage's pose-name drawing is unchanged except for 그루's inner tail fur, now on the stage and 캐릭터 선택 too (the user's answer to the spec's question 10.1).
  - A small room shrinks the character rather than scrolling the menu (question 10.2).
  - RepBot's widget and its test are deleted. The login page's logo reads GYMMOUSE too.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `80b00d7`, without coverage. The coverage comes from the PR's CI comment on the pushed head `53ea881` (the code of `80b00d7` plus these notes), [run 43573595867](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43573595867).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.2% (510/514) | 11/14 | CI comment "Tests and coverage (GitHub Actions)" on PR #55, commit `53ea881`, [run 43573595867](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43573595867) |
| ViewModel | flutter_test, fakes | 90% | 96.8% (1189/1228) | 11/14 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 92.6% (2414/2606) | 11/14 | same CI comment |
| View | flutter_test (widget) | 75% | 96.4% (6761/7012) | 11/14 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (101 passed; `server/` unchanged) | 11/14 | same CI comment |

- **Tests:** `flutter test` had 2606 passed, 0 failed and 10 skipped. `flutter analyze` found no issues.
  - The 10 skipped tests are the same as before, and W4 does not touch them: the live server check in `test/services/online/public_wss_smoke_test.dart` (runs only with `RUN_PUBLIC_BATTLE_SMOKE`) and 9 known push-up judge errors in `test/services/pose/pushup_error_cases_test.dart`, each with its reason.
  - W4 adds 3 test files and 2 data sets, changes 10 test files and deletes `test/widgets/lobby_rep_bot_test.dart` with the widget it tested (the table below).
- **The design checks:**
  - `test/widgets/character_motion_golden.json` is the design's `golden` (the rest of `w4_home_rig.json` is the app's `character_motion_data.dart`; the two together equal the bundle's file). Every pose value, expression and whole-picture move of its 54 samples and 5 rest pictures is matched within its tolerance 0.01; the samples include times past one rep and parts that run late.
  - `test/widgets/character_home_shots/` holds the design's five home shots (three-button bar, reduced motion) cut to the character's room. The app's rest picture is compared pixel by pixel both ways. The shots put the feet on a whole point (GYM마우스 at 180 for 179.52), so the test moves its render by that rounding; the app keeps the spec's exact place, which the placement tests check.
  - The W3 shot tests (`test/widgets/character_shots/`) compare the painter without patches and still pass; a new test checks that 그루's fur is the only change on the stage, in its color, in every pose (knocked out, the body hides the whole tail).
- **Mutation checks (by me, files restored byte for byte):** 13 deliberate faults (in 15 runs) were all caught: the easing formula, a part's delay ignored, the floor 16 → 15, effects drawn, flags ignored, the insert position, no restart on a new character or when shown again, no fur on the stage, a wrong screen-reader name, reduced motion ignored, RepBot's id not mapped to the mouse, and a least height brought back for the room.
- **Other checks:**
  - `ownership_guard.py --check-diff`: ok on `80b00d7`: 36 changed files, all owned by W4 or under the user's one-off exceptions (W1 / W3 files of the user, `app_theme.dart`'s home styles, the login page and its test).
  - Server `pytest` was not run, because `server/` did not change.
- **Coverage:** from the CI comment on PR #55 ([comment](https://github.com/snuhcs-course/swpp-2026-project-team-04/pull/55#issuecomment-6874331984)), commit `53ea881` (2026-11-14 17:09 KST; the app and server jobs both succeeded; [run 43573595867](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43573595867)). `53ea881` changes only these notes on top of `80b00d7`, and it is the head PR #55 was merged with.
  - App total 95.7% (11144/11647); Other 94.1% (270/287).
  - CI also ran `flutter analyze` (no issues) and `flutter test` (2606 passed, 10 skipped, 0 failed), the same as on this PC.
  - Left out of the coverage numbers by CI's 240 s limit per file: `test/screens/settings_screen_test.dart` and `test/services/audio/background_music_test.dart`. Their tests still ran and passed in `flutter test`. So W4's one-line change to `settings_screen.dart` (the tag '03 / SETTINGS' → '04 / SETTINGS', under its exception) is not in the View number.
- **Shortfalls:** none in coverage; every layer and the server meet their targets.
- **Screen readers:** widget tests check the character button's name and role, that the drawing itself is not read, the '?' button's 게임 규칙, and the 캐릭터 row's name without the character. TalkBack on a real phone was **not** checked.
- **Manual check (the user, 2026-11-14, on a Galaxy S26+ (SM-S947N) with One UI 9.0 and Android 17, the same phone as W2's):** the ears on 캐릭터 선택 were found during W2b's phone check; after part 1, home still scrolled (also on the S26+), which led to the home fit. The final build (part 2, with W2b and J2 from the merge) passed with no problems.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/character_motion_test.dart` (new) + `character_motion_golden.json` (new) | the home rig's data (five characters, 17 pose keys alike in steps, timetables naming real key poses, malformed rigs rejected); the 54 golden samples and 5 rest pictures within 0.01; the easings, segments, loop wrap, late parts, expressions, hop / rock / landing; expression tags incl. W5's per-character form; the placement rule at 360 × 780 with both bars, a lower and a narrower room, no room |
| View | `test/widgets/character_draw_patch_test.dart` (new) | every drawPatch of the five aimed at exactly one W3 shape; added shapes right after it; the flags (back glove, paddle fins) and the belly key; the five stage effects marked and not drawn (pixel-equal to the shapes removed), still drawn by pose name; W5-style patches (a fixed move written alone, a later patch at the same shape first); malformed patches; shape equality |
| View | `test/widgets/lobby_character_test.dart` (new) + `character_home_shots/` (new) | the whole room one button with the spec's name, for every character, RepBot's and unknown ids as the mouse; its own clock and repaint boundary; reduced motion; restart from 0 on a new character, when shown again, and for a character chosen while covered; no frames when covered or in the background; the placement in any room; the design's home shots |
| View | `test/widgets/character_figure_test.dart` (updated) | the painter's motion inputs (a table without a pose name, tags as the name, repaint on change); 그루's tail fur from `CharacterFigure` only, the only change in every stage pose |
| View | `test/screens/home_screen_test.dart` (updated) | four menu rows and their taps; GYMMOUSE; the character between the title and the menu, the account's choice and a new choice from 0, the default without a character above home, its motion and its rest picture, its tap and its screen-reader names; the fit (shrinks, at most 1.6×, only its room changes, a tab bar, 320 × 568 at 2× scrolls with no room left, a size × text sweep); with the app's fonts: no scroll on five phones with and without the note, the design's layout numbers, each character's placement on 360 × 780 with both bars, 1.3× / 1.5× text |
| View | `test/widgets/lobby_menu_item_test.dart`, `lobby_parts_test.dart` (updated) | the 75 high row (line, tag, title, chevron box), the title's fixed size at larger text, the page's 8 / 8 padding |
| View | `test/screens/character_select_screen_test.dart` (updated) | the line under the floor; no picture of the five overlaps the name band or its line at any extreme of their idle motion, at 1.0 / 1.3 / 2.0× text; the band's name at 30 and the line up to 1.5× at 2× text |
| View | `test/screens/play_screen_test.dart`, `settings_screen_test.dart`, `auth_screens_test.dart` (updated) | 게임 시작 without the 캐릭터 row; 환경설정's tag 04 / SETTINGS; the login page's GYMMOUSE |
| App flow | `test/main_test.dart` (updated) | GYMMOUSE on home; 캐릭터 선택 opened from home's 캐릭터 row, the saved character on its preview and a pick kept |
| Design | `test/design_tokens_test.dart` (updated) | the four new widget files in the token check; the deleted `lobby_rep_bot.dart` line removed with its file |

### Acceptance criteria → tests
- I chose a character, then home shows it; after I change it, home shows the new one. Tests: `"the account's character stands there, and a new choice shows at once, from the start of its motion"`, `'a character chosen while a page covers home starts from 0 when home shows again (환경설정 -> 캐릭터 -> back)'`
- Its poses, expression and whole-picture move match the design within 0.01. Tests: `'$id at ${t.toInt()} ms: pose, expression and whole move'` (54 samples), `'$id still: the rest picture with less motion'`
- Every drawPatch target is found and the five stage effects are not drawn. Tests: `'$id: every patch is aimed at exactly one W3 shape'`, `'each effect rule finds its W3 shapes, and only W3 ones'`, `'$id with $tags draws as if the effect shapes were not there'`
- On 360 × 780 with a three-button and a gesture bar, each character's scale and feet are the design's. Tests: `'360×780 with the $bar bar: $id at the scale and feet of its placement'`, `'on 360×780 with the $bar bar every character stands at its placement'`
- Tapping the character opens 캐릭터 선택, with the spec's name; reduced motion does not move. Tests: `'tapping the character opens 캐릭터 선택; back returns home (W4 spec 6)'`, `'the whole room is one button that opens 캐릭터 선택, named for the character (W4 spec 6)'`, `'with less motion it shows the rest picture and stays still'`
- Home fits without scrolling (part 1's tests, kept). Tests: `'a $label phone shows it all without scrolling'` (five phones, with and without the note)
- Part 1: four menu rows, 캐릭터 opens 캐릭터 선택, 게임 시작 has no 캐릭터 row, the logo reads GYMMOUSE, no character covers the band or its line. Tests: `'the menu: 게임 시작, 캐릭터, 기록보관소, 환경설정, all alike'`, `'캐릭터 opens 캐릭터 선택; back returns home'`, `"no 캐릭터 row: the character is picked from home's menu"`, `'for all five, at every extreme of their idle motion (rig …'`

#### 2026-11-15 · code at commit `13afb2f` · step W6 `feat/ui_report_rules` (the result report in palette B, team order #13)
This step redraws the result screen as the game report of the design (BResult, headline option A of BResultHeads). It was built on 2026-11-13 and 2026-11-14 against a list of values, and connected to 박진영's result view model (J4 #57) on 2026-11-15:
- **The report:** the verdict on a marker band (KO 승리 / 승리 lime, KO 패배 / 패배 pink, 무승부 gray), the sub line (exercise, "vs RepBot <level>" or the nickname, the seconds), a reason line when the headline does not say it ("점수 같음 · 횟수로 승리/패배", "상대가 나갔어요", "연결이 끊겼어요"; no seconds when a player left), both scores with swatches and the user's reps, then the cards, and 홈으로 / 다시 대결. Accuracy and the grade counts left the screen (the design has neither).
- **The cards, from J4's `ResultState`:** the personal best when this battle beat the best before it ("185점 → 240점 · 55점 올랐어요"), the latest battles (up to 8 bars, this one last, the mean of up to 5 battles before it as a dashed line, the same exercise, bot and online mixed), and the next tip (the first issue's fix and what it was, push-ups and squats), with 자세 피드백 전체 보기 when the battle has a form report.
- **Empty and waiting states (my defaults, the design has none):** the first battle shows neither the best nor the latest battles (the user's rule of 2026-11-13: a card without values is left out); while the earlier battles load, one quiet card "이전 기록을 불러오는 중…" stands in their place (no 0, no empty chart); if they cannot be loaded, the comparison is left out and the rest stays. A battle without a game score (an old server) leaves out the latest battles too.
- **Rules pages:** built here on 2026-11-13, then moved to 박진영's tutorial at the team meeting of 2026-11-15. Their files are back to `main`'s version on this branch, and the rules tests I had added (`test/widgets/help_pictures_test.dart`) left with them.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `13afb2f`, without coverage. The coverage comes from the PR's CI comment on the pushed head `bbba0c2` (the code of `13afb2f` plus these notes), [run 43640991023](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43640991023).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.3% (545/549) | 11/15 | CI comment "Tests and coverage (GitHub Actions)" on PR #62, commit `bbba0c2`, [run 43640991023](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43640991023) |
| ViewModel | flutter_test, fakes | 90% | 97.4% (1430/1468; W6 changes no view model) | 11/15 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 93.1% (2559/2750; W6 changes no service) | 11/15 | same CI comment |
| View | flutter_test (widget) | 75% | 96.5% (6935/7188) | 11/15 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (114 passed; `server/` unchanged) | 11/15 | same CI comment |

- **Tests:** `flutter test` had 2797 passed, 0 failed and 10 skipped. `flutter analyze` found no issues.
  - The 10 skipped tests are the same as before, and W6 does not touch them: the live server check in `test/services/online/public_wss_smoke_test.dart` (runs only with `RUN_PUBLIC_BATTLE_SMOKE`) and 9 known push-up judge errors in `test/services/pose/pushup_error_cases_test.dart`, each with its reason.
  - The review run measured the three result test files alone with `--coverage` (not the layer numbers): `result_screen.dart` 100%, `result_report.dart` 99.4%, `result_cards.dart` 99.3% (the two lines left are painters' `shouldRepaint`).
- **Mutation checks (by me, 2026-11-14, before the J4 wiring; files restored byte for byte):** 9 deliberate faults in the reason line and the report were all caught.
- **Other checks:**
  - `ownership_guard.py --check-diff`: ok on `13afb2f`: 13 changed files, all owned by W6 or under the user's one-off W6 exceptions of 2026-11-13 (the old result words in `main_test.dart`, `battle_demo_test.dart`, `feedback_screen_test.dart`, the grade-count group of `game_panel_fonts_test.dart`, one comment in `battle_demo.dart`).
  - Server `pytest` was not run, because `server/` did not change.
- **Coverage:** from the CI comment on PR #62 ([comment](https://github.com/snuhcs-course/swpp-2026-project-team-04/pull/62#issuecomment-6884336253)), commit `bbba0c2` (2026-11-15 06:17 KST; the app and server jobs both succeeded; [run 43640991023](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43640991023)). `bbba0c2` changes only these notes on top of `13afb2f`.
  - App total 95.6% (11711/12251); Other 81.8% (242/296).
  - CI also ran `flutter analyze` (no issues) and `flutter test` (2797 passed, 10 skipped, 0 failed), the same as on this PC.
  - Left out of the coverage numbers by CI's 240 s limit per file: `test/screens/settings_screen_test.dart` and `test/services/audio/background_music_test.dart` (neither is a W6 file). Their tests still ran and passed in `flutter test`. The three result test files are in the numbers.
- **Shortfalls:** none in coverage; every layer and the server meet their targets. J4 gives the best before and the average, not the gain and the difference: the screen subtracts them (noted for 박진영 after the cutoff).
- **Screen readers:** widget tests check what the headline, the sub line (with its reason), the scores and the chart are read as. TalkBack on a real phone was **not** checked.
- **Manual check:** at the team meeting of 2026-11-15 the result screen was checked in an online battle (before the J4 wiring) with no problem. This build (with the J4 wiring) has **not** been checked on a phone yet. It will be checked once, on a `main` build after the W5–W8 PRs are all merged: a new best, the latest battles, a squat tip and the loading line.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/result_screen_test.dart` (rewritten) | the mapping from J4's `ResultState` (outcome, KO from the end, a player leaving without seconds, a past battle's name, the new best and its gain, not beaten or matched, the latest battles and the difference, the first battle without them, no game score, loading, failed, the tip's headline / detail and no code, feedback); where the earlier battles come from (the app's repository when it keeps the list, else a source that fails); on the screen: time-up win / loss / draw for push-ups and squats with both scores, KO win / loss, equal scores decided by reps, the opponent leaving and the lost connection, the comparison as in the design, the first battle, the placeholder while loading and the cards in its place, a failed load, the push-up and squat tips, nothing to fix, the buttons (home, back, system back, 다시 대결 for a bot and online, one leaving button, the feedback and back), leaving while loading |
| View | `test/widgets/result_report_test.dart` (new) | the headline's words, bands, slant and one line at larger text; the sub line (bot levels, a long nickname cut at 1.0 / 2×); the reason line and the seat at the right end; the score row (swatches, baseline, reps under the scores at 2×, rejected reps unknown); the header; the cards' order, gaps and the placeholder while loading; the buttons; no text in a fill color; a 360 × 780 and a short phone, 320 × 640 at 1.3 / 2× |
| View | `test/widgets/result_cards_test.dart` (new) | the best card's words and colors; the latest-battles chart (bars from the right, this one in ink, the dashed average and its label above or below, the chip above / equal / below, dates, the screen-reader label); the tip card with and without a reason or the link; the placeholder (one muted line, no number, no chart) |
| App flow | `test/main_test.dart`, `test/demo/battle_demo_test.dart`, `test/screens/feedback_screen_test.dart` (updated) | the result's new words only ('승리', 다시 대결, 자세 피드백 전체 보기) |
| View | `test/widgets/game_panel_fonts_test.dart` (updated) | the group of the result's grade counts deleted (they left the screen) |
| Design | `test/design_tokens_test.dart` (updated) | `result_screen.dart`, `result_cards.dart`, `result_report.dart` in the token check |

### Acceptance criteria → tests
- UAT-4 AC1: the result shows win, loss or draw with both scores, for push-ups and squats. Tests: `'a time-up ${squat ? 'squat' : 'push-up'} ${outcome.name}: "$headline", both scores, the seconds'` (6 cases), `'a KO ${outcome.name}: "$headline" and the time it took'`, `'${outcome.name}${byKo ? ' by KO' : ''}: "$word" in ink on …'`
- An online battle a player left says why and shows no seconds. Tests: `'an online battle that ended by ${departure.name}: $headline, and why, without the seconds'`, `'a battle a player left, without its length: no seconds'`
- The first battle does not look like a new best. Tests: `'the first battle: no new best and no comparison, the rest of the report as usual'`, `'no best card when the best was not beaten, or there was none (the first battle)'`
- While loading, a placeholder, not 0 or an empty chart; a failed load leaves the comparison out. Tests: `'while they load: the placeholder, no 0 and no chart; then the cards in its place'`, `'a failed load: the comparison is left out, the rest of the report stays'`
- The next tip shows for push-ups and squats. Tests: `"a push-up battle: its first issue's fix and what it was"`, `'a squat battle has its squat tip'`

#### 2026-11-15 · code at commit `a2724d0` · step W7 `feat/ui_archive` (archive and statistics screens in the B palette, UAT-4 AC3, team order #17)
This step redraws 기록보관소 and adds the 기간별 통계 screen. Both parts go up in one PR. The screens only draw what J3's view models give (`HistoryViewModel`, `FeedbackStatsViewModel`); J3's data code is unchanged.
- **Part 1, the archive (2026-11-14, from the BArchive mockup):**
  - The header has the back button, "03 / ARCHIVE", a faint "LOG" and the slanted title 기록보관소.
  - The "최근 7일" card shows the week's reps and battles, the streak chip (hidden at 0) and 7 bars, today's in ink.
  - The "점수 성장" card has 푸쉬업 / 스쿼트 tabs, the score line, the rise chip and an empty line when the exercise has no score yet.
  - Below them come the newest 3 battles and "전체 보기", which opens every battle on the same view model with the old paging footer. A row shows the result, time, opponent, score, the "↑N" chip when the battle raised the best, and "상대 나감".
  - Without a summary the cards hide; a failed summary shows 다시 시도 in their place.
- **Part 2, the statistics (2026-11-14, from the W7-STATS mockup and its `w7_golden.json`):**
  - Period tabs 전체 / 이번 달 / 이번 주 (this week first) and exercise chips 푸쉬업 / 스쿼트 / 둘 다 (both first). Tabs and chips change the numbers at once, without loading again.
  - The summary card shows the range, the average counted reps per battle, battles and total reps, and the date–reps graph:
    - this week: by day;
    - this month: the month's days, the days to come dashed;
    - all records: by day up to 14 days, else by week with a note.
  - The form-issue card lists the rejected reps by reason and the form-report issues by how many battles had them. "나머지 N개 더 보기" opens a group of more than five rows.
  - Loading, failed and empty states.
  - The archive gets a lime "기간별 통계" pill at the right of its header (only when the account can give statistics). The 7-day card is named "최근 7일 · M/D ~ 오늘", and a day without battles is a thin 3-high line.
- **Merge:** `origin/main` with J4 (#57) merged as `a2724d0`. No conflict, and no W7 file changed by the merge. J4's new squat titles in `form_analyzer.dart` keep the six titles the statistics screen repeats; the test that reads them from that file still passes.
- **Second merge (2026-11-15):** `origin/main` with W6 (#62) and J5's tutorial follow-up (#64) merged as `837cb7c`.
  - Conflicts only in `lib/theme/app_theme.dart` and in these three note files. W6 and W7 had both added `AppColors.inactive` (#A9B0BE): one token is kept, with one comment for both uses (W6's bars of the earlier battles, W7's dashed days to come). The notes keep both sides, W6 first.
  - No W7 screen, widget or test file changed. `design_tokens_test.dart` and `auth_flow_test.dart` merged without a conflict (both sides kept).
  - Checks on `837cb7c`: `flutter analyze` found no issues; `flutter test` had 2999 passed, 0 failed and 10 skipped (the same 10 as below); `ownership_guard.py --check-diff` ok (28 changed files); the reviewer subagent checked the resolution (APPROVE).
  - Coverage on the new head: not measured on this Windows PC (coverage collection hangs); TODO(Woohyun Song): fill from the PR's CI coverage comment.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `a2724d0`, without coverage. The coverage comes from the PR's CI comment on the pushed head `a3c6680` (the code of `a2724d0` plus these notes), [run 43618528652](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43618528652).

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | 99.3% (545/549) | 11/15 | CI comment "Tests and coverage (GitHub Actions)" on PR #61, commit `a3c6680`, [run 43618528652](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43618528652) |
| ViewModel | flutter_test, fakes | 90% | 97.4% (1430/1468) | 11/15 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | 93.1% (2559/2750) | 11/15 | same CI comment |
| View | flutter_test (widget) | 75% | 97.0% (7980/8231) | 11/15 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | 96% (114 passed; `server/` unchanged) | 11/15 | same CI comment |

- **Tests:** `flutter test` had 2891 passed, 0 failed and 10 skipped. `flutter analyze` found no issues.
  - The 10 skipped tests are the same as before, and W7 does not touch them: the live server check in `test/services/online/public_wss_smoke_test.dart` (runs only with `RUN_PUBLIC_BATTLE_SMOKE`) and 9 known push-up judge errors in `test/services/pose/pushup_error_cases_test.dart`, each with its reason.
  - W7 adds 8 test files and 2 test data files, rewrites `test/screens/history_screen_test.dart`, and changes 3 more test files (the table below). Its 12 test files have 280 tests, all passing.
- **The design checks:**
  - `test/widgets/feedback_stats_golden.json` is a copy of the mockup's `w7_golden.json` (tests cannot read the design folder). The graph's slots and the screen's words are pure functions. All 11 golden cases match on the first run: the summary, every slot's label, reps, look and bar height, the empty notice, and the issue rows' names, counts and bar widths.
  - Part 1's growth chart uses the mockup's own math (padding, headroom, dot limit), checked point by point.
  - Renders with the app's fonts at 360 × 780 were compared with the mockup's shots by eye. The differences are the missing 24 px status bar in the test and the title's font (the app's page title, the user's choice).
- **Mutation checks (by me, files restored byte for byte):** 32 deliberate faults were all caught.
  - Part 1 (14): the streak chip at 0, today's bar color, the rise chip at 0, the gain not passed, the failed-summary branch, the number of recent rows, 전체 보기 without older pages, the KO word, an unknown online flag, the chart's headroom, and 4 in the time / opponent line.
  - Part 2 (18):
    - the graph: by day or by week, the 14-day cut, a day to come's bar height and dashes, the zero bar's color, the month labels near today, the week labels every other slot;
    - the words and cards: the form-record base, unknown issue codes skipped, the 4% bar floor, the more button, the average's dash;
    - the screen: the more rows reset on a new period, the loading skeleton's period, the tab order, the tabs' selected state, the pill without a statistics source, the archive's zero-day color.
  - The 2 that first survived (the 4% floor, the more button with one hidden row) led to two edge tests.
- **Other checks:**
  - `ownership_guard.py --check-diff`: ok on `a2724d0`, 25 changed files. All are W7's own files or under the user's one-off exceptions: the theme's new colors and text styles, one line in `test/auth_flow_test.dart` ('경기 기록' → '기록보관소'), and one deleted group in `test/widgets/match_record_card_test.dart` (it showed `MatchRecordCard` on the old history list, which no screen uses now).
  - Server `pytest` was not run, because `server/` did not change.
- **Coverage:** from the CI comment on PR #61 ([comment](https://github.com/snuhcs-course/swpp-2026-project-team-04/pull/61#issuecomment-6881251918)), commit `a3c6680` (2026-11-15 02:12 KST; the app and server jobs both succeeded; [run 43618528652](https://github.com/snuhcs-course/swpp-2026-project-team-04/actions/runs/43618528652)). `a3c6680` changes only these notes on top of `a2724d0`.
  - App total 96.0% (12770/13308); Other 82.6% (256/310).
  - CI also ran `flutter analyze` (no issues) and `flutter test` (2891 passed, 10 skipped, 0 failed), the same as on this PC.
  - Left out of the coverage numbers by CI's 240 s limit per file: `test/screens/settings_screen_test.dart` and `test/services/audio/background_music_test.dart` (neither is a W7 file). Their tests still ran and passed in `flutter test`.
- **Known limitation (user, 2026-11-14):** battles stored before the issue codes were saved have a form record but no `issues`. They count in '자세 기록 있는 N판' without adding issue counts; battles after the server redeploy are exact. Left as is.
- **Shortfalls:** none in coverage; every layer and the server meet their targets. A row without form feedback still does nothing when tapped (a past battle's report from the archive comes after J4's data, in a later step).
- **Screen readers:**
  - Widget tests check the spoken lines: the tabs and chips with their selected state, the summary as one line, the graph as one sentence with the dates spelled out, and each issue row as one line.
  - They also check the live regions of the loading, failed and empty states, the 다시 시도 button, the expanded state of 더 보기, and the pill's name.
  - TalkBack on a real phone was **not** checked.
- **Manual check (2026-11-15, the user, on the Galaxy S26+ (SM-S947N) with One UI 9.0 and Android 17 from my earlier notes):** all passed. The user checked:
  - 기록보관소: the two cards and the newest 3 battles, the name "최근 7일 · M/D ~ 오늘" and today's bar, and the thin line on a day without battles;
  - 점수 성장: the 푸쉬업 / 스쿼트 tabs and the empty-state line;
  - 전체 보기: loading more battles and going back;
  - the 기간별 통계 pill opening 이번 주 · 둘 다, and switching the tabs and chips;
  - 이번 달's dashed days to come, and 전체's slots by day and by week;
  - 자세 문제's 더 보기 and 접기;
  - after two or more battles in the order of UAT-4 step 3, the statistics match each battle's report;
  - large text and a long online nickname.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/archive_chart_test.dart` (new) | the growth chart's layout from the mockup's math (padding, headroom, dots up to 12 points), the week's bar heights incl. the 3-high line for a day without battles, the exercise icons and the pill's icon |
| View | `test/widgets/archive_cards_test.dart` (new) | the 7-day card (totals, streak chip hidden at 0, bars, 오늘 in ink, the "최근 7일 · M/D ~ 오늘" name), the growth card (tabs, rise chip, caption, first-played date, empty line), the retry card |
| View | `test/widgets/archive_match_row_test.dart` (new, real fonts) | the result line (KO, 승 / 패 / 무), time (오늘, 어제, date), online opponent, score, the gain chip, 상대 나감; one line when it fits, else the opponent under the time with no dangling dot, at larger text |
| View | `test/screens/history_screen_test.dart` (rewritten) | the header, the pill (place, look, opens 이번 주 · 둘 다, hidden without a source, a narrow phone at 1.3× text), both cards, the newest 3 battles, gain chips, the tabs, the summary missing / loading / failed, the empty and failed states, 전체 보기 and its paging, rows opening feedback, fit at 360 × 780, no overflow at larger text |
| View | `test/widgets/feedback_stats_slots_test.dart` (new) + `feedback_stats_golden.json`, `feedback_stats_golden.dart` (new) | the 11 golden cases × summary, chart, empty notice and issue rows; the slot edge cases (over 26 weeks still by week, a 28-day February, one slot, the least bar), the loading skeletons, the calendar helpers; the spoken summary and graph sentences, the row labels, the six form-report titles read from `form_analyzer.dart` |
| View | `test/widgets/feedback_stats_chart_test.dart` (new) | bars by look (value, today, zero, dashed future, skeleton), values and labels, the spoken sentence, a notice taller than the graph makes room, repaint rules |
| View | `test/widgets/feedback_stats_filters_test.dart` (new) | the period tabs and exercise chips: order, names, selection, taps, 44 touch areas, screen-reader groups and selected state |
| View | `test/widgets/feedback_stats_cards_test.dart` (new) | the summary card's numbers and their place, the empty notice over or under the plot, the issue card's groups, bar widths (4% floor, 100% cap), "나머지 N개 더 보기" / 접기 and its expanded state, the loading and failed cards |
| View | `test/screens/feedback_stats_screen_test.dart` (new) | the W7-STATS section 10 list: opening on 이번 주 · 둘 다 with the mockup's numbers, switching without loading again, loading (a tab picked meanwhile, reduced motion), failed (the reasons, 다시 시도), empty (this week, this month, all, no form records), more rows closing on a new period or exercise, graph slots by day / week, the spoken lines, the first screen at 360 × 780, no overflow at larger text in every state |
| App flow | `test/auth_flow_test.dart` (updated) | one check: the archive's title is now 기록보관소 |
| View | `test/widgets/match_record_card_test.dart` (updated) | the group that showed `MatchRecordCard` on the old history list removed (no screen uses it now) |
| Design | `test/design_tokens_test.dart` (updated) | the 9 new screen and widget files in the token check |

### Acceptance criteria → tests
- UAT-4 AC3: from the archive the statistics open on this week and both exercises. Tests: `'it opens the statistics on this week and both exercises'`, `"this week and both exercises are picked, with the mockup's week_both numbers"`
- All records, this month and this week narrow the battles; push-ups and squats are listed apart. Tests: `'tabs and chips switch the values without loading again'`, `'summary: range, average, battles, reps, with a form record'` (11 golden cases)
- The average counted reps, a date–reps graph and how often each form issue occurred. Tests: `'chart: kind, slots, gap, and per slot the label, reps, future, now, value, bar height and look'`, `'form issues: base, blank line, and both groups in order with names, counts and bar widths'`, `'every record: by week over 14 days, with the note'`, `'every record: by day up to 14 days, no note'`
- Loading, failed and empty states. Tests: `'gray boxes and 불러오는 중; a tab picked meanwhile stays picked once loaded'`, `'the reason, 다시 시도 and the note; the tabs stay, and 다시 시도 loads again'`, `"this week without battles: the notice over the plot, the dashes, and the form card's one line"`, `'every record without battles: the notice under the numbers, no graph'`
- The archive (part 1): the last 7 days, the growth and the newest battles, and 다시 시도 when the summary fails. Tests: `'the last 7 days, the growth and the newest three battles'`, `'the gain chip only on the battles that raised the best'`, `'the 스쿼트 tab switches the graph to squats'`, `"a failed summary: 다시 시도 in the cards' place, the list stays, and the retry brings the cards"`
- Readable at larger text on a 360-wide phone. Tests: `'no overflow at ${scale}x text on a 360 wide phone, in every state'`, `'on a narrow phone with large text the tag is cut, the pill stays whole'`

## W8 form-feedback records

#### 2026-11-15 · code at commit `8204458` · step W8 `feat/ui_form_feedback` part 1 (the form feedback screen in palette B, team order #18; issues #58 and #59)
- **What changed:**
  - The form feedback screen is redrawn from the palette B mockup (BFeedback): ink text on white panels, color only in the badges, swatches, reject squares and bars.
  - It draws what `FeedbackViewModel` gives (`state.form`) and computes no verdict itself. Before, the chart sentences judged the report again with the push-up rules, so a squat that lost 0.15 of its depth read 후반 깊이 감소 on the card and 깊이는 끝까지 유지됐어요 under the chart (#58).
  - Squats: 앉은 깊이 (서 있을 때 허벅지 길이 기준) and a new 엉덩이 각도 chart (the shoulder–hip–knee angle the app already saves) in place of 머리 하강 깊이 and the elbows; no elbow column. The arm sentence appears only when the analyzer judged the arms.
  - An AI squat saves no depth over time (#59, the judge is S4's): a short note takes the depth chart's place and still gives the verdict.
  - A round cut short by a KO is read in its own slices ("2.8초").
  - The fault examples keep their shape at any width, a thin ink figure with the faulty part in amber.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `8204458`, without coverage: collecting coverage over the full suite hangs on this PC (a run over a few test files works). The layer numbers come from the PR's CI comment "Tests and coverage (GitHub Actions)".

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | not measured on this Windows PC (full-suite coverage collection hangs); TODO(Woohyun Song): fill from the PR's CI coverage comment | 11/15 | CI comment "Tests and coverage (GitHub Actions)" on the PR |
| ViewModel | flutter_test, fakes | 90% | same TODO | 11/15 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | same TODO | 11/15 | same CI comment |
| View | flutter_test (widget) | 75% | same TODO for the layer (the reviewer's coverage run of only the 5 W8 test files, on the tree committed as `8204458`: the W8 files 649 / 654 lines, 99.2%) | 11/15 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | `server/` unchanged; TODO(Woohyun Song): fill from the CI comment | 11/15 | CI `pytest --cov=accounts --cov=matches --cov=gymrats` |

- **Tests:** `flutter test` had 2807 passed, 0 failed and 10 skipped. `flutter analyze` found no issues.
  - The 10 skipped tests are the same as before, and W8 does not touch them: the live server check in `test/services/online/public_wss_smoke_test.dart` (runs only with `RUN_PUBLIC_BATTLE_SMOKE`) and 9 known push-up judge errors in `test/services/pose/pushup_error_cases_test.dart`, each with its reason.
  - W8 adds 4 test files (3 test files and 1 file of report builders) and changes 3 (the table below): 85 tests in the W8 files, plus the token check.
- **The design check:** the mockup was rendered in headless Chrome with the app's own font files and compared side by side with the screen rendered by a temporary widget test with the same fonts and the mockup's numbers (the push-up page, a squat, an AI squat without depth, a 17 s KO round, 1.3× text). They match apart from the token roundings; the renders are local only.
- **Mutation checks (by me, files restored):** the depth chart with a clip again (the end square cut, 261 < 266), the angle charts' floor fixed at 60, and the right inset at 0 were each caught by a test.
- **Other checks:**
  - `ownership_guard.py --check-diff`: ok on `8204458`: 13 changed files, all owned by W8 or under the user's one-off `app_theme.dart` exception (a `FeedbackText` extension appended at the end).
  - The middle commit `06f2160` (the fault examples) was checked alone in a temporary worktree: `flutter analyze` clean, the 59 tests of the affected files pass.
  - Server `pytest` was not run, because `server/` did not change.
- **Shortfalls:** layer coverage is a TODO until the CI comment. The tutorial screens (W8 part 2, UAT-6) wait for J5 `feat/tutorial`.
- **Screen readers:** widget tests check that each chart is one picture with its name (머리 하강 깊이 그래프, 앉은 깊이 그래프, 엉덩이 각도 그래프, 팔꿈치 각도 그래프), the section titles as headers, and each badge's kind (고칠 점, 잘한 점, 참고). TalkBack on a real phone was **not** checked.
- **Manual check:** TODO(Woohyun Song): the phone check (a push-up and a squat battle against the AI, then 자세 피드백 전체 보기 and a battle from 기록보관소), the phone model and the Android version.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/feedback_screen_test.dart` (updated: imports and one group at the end) | UAT-4 AC2 for push-ups and squats (4 counted, 2 rejected, the issue with its tip, a row per rep); #58: the squat with 0.95, 0.95, 0.80, 0.80 says the late loss on the card and under the chart, the same depths in a push-up stay kept, a push-up that lost 0.3 says so; too few reps: no verdict; squat titles, no elbow chart, sentence or column, the 엉덩이 각도 chart and its camera note; the push-up's elbow chart, legend and column; the arm sentence follows the analyzer (even, left, right, none when it cannot tell); the screen words the values it is given, never its own; opened with only a report it shows the view model's findings and follows a new report; a 17 s KO round; #59 with and without a verdict; nothing judged and nothing seen; palette B (no text in a fill color); push-up and squat at 1.3× / 2× on 360 × 780 with no overflow and the reason not cut |
| View | `test/screens/match_feedback_screen_test.dart` (updated: +1) | the loaded report and the view model's feedback reach the screen as they are |
| View | `test/widgets/feedback_charts_test.dart` (new) | the seconds' wording; the depth chart's span, scale (push-up and squat), dashed rep marks, amber squares only for rejected reps, a KO round, gaps, axis numbers not scaled; the elbow lines (solid ink, dashed gray); the hip line; the angle charts' floor under 60; the room on the right with the end square drawn whole and not clipped; the pace bars (lime, ink edge, none for an empty slice, at least 2, slice labels); the reject square's paint; the legend |
| View | `test/widgets/feedback_parts_test.dart` (new) | the panel, the section title (header, the unit on the right or under the title), the stat (swatch only when given, the number shrinks on one line), the swatch, the three badges (colors, marks, screen-reader kinds, the mark not scaled), the finding card (ink title and numbers, quieter fix, the example only with a demo), the chart panel (one picture, the sentence, the legend), the note, the rep table (columns, swatches, ink verdicts, dashes for missing values, no elbow column for squats, fixed column widths and the whole reason wrapped at 2×, a gap before the right columns) |
| View | `test/widgets/feedback_fault_clip_test.dart` (new) | every example in ink, amber only at fault, no pink; drawn to scale and standing on the bottom; the floor line; the amber part inside its ink edge and the line widths (6 and 9); the head at fault; the wall of the standing push-up; tap to pause and play |
| View | `test/widgets/feedback_test_reports.dart` (new) | report builders for these tests (not a test file) |
| Design | `test/design_tokens_test.dart` (updated) | `feedback_screen.dart`, `feedback_charts.dart`, `feedback_parts.dart` and `form_fault_clip.dart` in the token check |

### Acceptance criteria → tests
- UAT-4 AC2 (push-up and squat): counted and rejected reps, the top issues each with one fix, a per-rep record. Tests: `'UAT-4 AC2 (${exercise.name}): 4 counted and 2 rejected reps, the issue with its tip, and one row per rep'` (push-up and squat)
- Requirements 5.6: depth and joint-angle charts and reps over time, for both exercises. Tests: `'a push-up keeps 머리 하강 깊이, the elbow chart, its legend and the elbow column'`, `'a squat shows its hip angle as its joint-angle chart, without a verdict'`, `'a round cut short by a KO is read in its own slices'`
- #58: the chart sentences agree with the cards. Tests: `'#58: a squat that lost 0.15 says so on the card and under the chart'`, `'#58: the same depths in a push-up stay within its 0.25 line, on the card and under the chart'`, `'a push-up that lost 0.3 says so on the card and under the chart, as before'`, `'the screen words the values it is given, never its own'`
- #58: no sentence judges the arms when the analyzer did not; squat titles. Tests: `'a squat is titled 앉은 깊이 and has no elbow chart, arm sentence or elbow column'`, `'when the analyzer cannot tell the arms apart, the sentence does not judge them'`, `'the arm sentence follows the analyzer: even, left or right bent more, as the cards say'`
- #59: the chart's place does not break without depth over time. Tests: `'#59: an AI squat without depth over time says where the depths are and still gives the verdict'`, `'#59 with too few reps to judge: only where the depths are'`
- Large text does not overflow or cut the reason. Tests: `'${exercise.name} at ${scale}x text on a 360 x 780 phone: nothing overflows down to the last rep'` (push-up and squat, 1.3× and 2×), `'with large text the number columns keep their widths and the whole reason wraps; nothing overflows'`
- Palette B. Tests: `'palette B: every word is ink; color only fills badges, swatches, squares and bars'`, `'every example is ink on a light floor, amber only at fault, and nothing pink'`

#### 2026-11-15 · code at commit `be2c0a2` · step W8 `feat/ui_form_feedback`, follow-up to the Codex review of PR #63 (team order #18)
- **What changed:** the review's P2 comment ("Filter post-round samples before scaling"). A camera frame handled just after the round ended was not drawn, but it still set the depth chart's scale, and when only that frame had a depth the screen showed an empty chart instead of the note. Now whether a chart has data and how far its scale reaches come from the samples inside the round, the same ones the line draws, for the depth, elbow and hip charts (`hasData` takes the slice length).
- **Tests:** `flutter test` had 2811 passed, 0 failed and 10 skipped (the same 10 as before); `flutter analyze` found no issues. The W8 files now have 89 tests (+4 new, 3 rewritten), plus the token check. Coverage: TODO(Woohyun Song): from the CI comment on the PR's new head (the reviewer's coverage run on this PC did not finish while the full suite ran beside it).
- **Mutation check (by me, file restored):** with every sample counted as within the round, 6 of the new and rewritten tests fail.
- **Other checks:** the reviewer returned APPROVE (one Minor: the line repeated the in-round rule; it now uses the same helper). `ownership_guard.py --check-diff`: ok. Server `pytest` was not run, because `server/` did not change.
- **Manual check:** none for this change (a frame after the round is hard to produce on purpose); it is covered by the tests below.

### Test cases added or changed in this follow-up
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/feedback_charts_test.dart` (updated) | the three `hasData` checks count only the round (30 s counts, 30.1 s does not, a 12 s KO round drops 13 s); a sample after the round neither stretches the depth scale (push-up up and down, squat) nor is drawn; a depth only after the round draws nothing; a deep bend after the round leaves the angle floor at 60 |
| View | `test/screens/feedback_screen_test.dart` (updated: +1 in the W8 group) | an AI squat whose only depth is a frame at 30.2 s gives the note and the verdict, not an empty chart |
| View | `test/widgets/feedback_test_reports.dart` (updated) | `extraSamples` for samples after the round |

### Acceptance criteria → tests (this follow-up)
- A sample after the round does not change the chart. Tests: `'a sample after the round does not stretch the scale'`, `'a depth only after the round draws nothing'`, `'hasData: a depth at any moment of the round, not after it'`, `"a deep bend after the round does not lower the chart's floor"`
- With depth only after the round, the note shows. Tests: `'a depth seen only after the round ends gives the note, not an empty chart (Codex review of #63)'`

#### 2026-11-15 · code at commit `71b780e` · step W5 `feat/victory_animation` (P18 the victory animation after the battle, team order #15)
This step adds the victory scene after a battle (the user's design package `W5-VICTORY-SPEC.md`, numbers from `w5_victory_rig.json`, test values from `victory_golden.json`). It was built in three parts:
- **Part 1 (2026-11-14, `2403055`): the scene as `victory_*` widgets, apart from the report.**
  - A win is a 2.1 s cut-in: a lime panel with stripes, 22 confetti, the band "KO 승리" / "판정승" / "기권승" (KO, time, the opponent left), my character's own celebration, a blend into its end pose, and a shrink onto its seat on a lime stand.
  - A loss or a draw is one frustration on a white stand (760 ms; 물렁범 820 ms), then it stops.
  - A tap jumps to the end look. Reduced motion, or "do not play" (a past report), shows only the end look. It plays once.
- **Part 2 (2026-11-15, `3ef678f`): the scene on the result screen.**
  - W6's report keeps a 144 × 148 seat at the right end of the headline's rows: its bottom is the score row's top, and it ends 4 into the margin (x 200–344 on a 360 phone, as in the spec). The headline, the sub line and the reason line keep left of it. When the sub line's words cannot fit beside it (2× text with seconds), the seat gets a row of its own above the headline.
  - When the report opens after a battle, the scene plays over it once and ends on the seat. The end look then stays in the report, so it scrolls with the page.
  - If the page moves while the scene plays (insets, text size, screen size, a screen reader's scroll), the scene follows the seat.
- **Step 5 (2026-11-15, `167207c`, `71b780e`, after W7 #61 was merged): a battle in 기록보관소 opens its report** (team decision 2026-11-08), not the form feedback.
  - The report comes from 박진영's record view model (J4) and shows only the end look, with no animation. Its 자세 피드백 전체 보기 opens the feedback when the battle has one.
  - 다시 대결 on a past report starts the same kind of battle from home: a bot at the level its saved name gives (else 고수), or the online lobby.
- **Merges of `main` (no rebase):** `49571d4` (W4 #55, J3 #56), `8ae9784` (J4 #57, J5 #60, W6 #62, J5 #64; only `design_tokens_test.dart` conflicted, both sides kept), `1ef6874` (W7 #61), `bfb4345` (W8 #63, S3 #65, the home replay fix #67); the last two had no conflict.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `71b780e`, without coverage. The coverage will come from the PR's CI comment.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | TODO(Woohyun Song): from the PR's CI comment | 11/15 | CI comment "Tests and coverage (GitHub Actions)" on the W5 PR (commit and run link to add) |
| ViewModel | flutter_test, fakes | 90% | TODO(Woohyun Song): from the CI comment (W5 changes no view model) | 11/15 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | TODO(Woohyun Song): from the CI comment (W5 changes no service) | 11/15 | same CI comment |
| View | flutter_test (widget) | 75% | TODO(Woohyun Song): from the CI comment | 11/15 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | TODO(Woohyun Song): from the CI comment (`server/` unchanged) | 11/15 | same CI comment |

- **Tests:** `flutter test` had 3213 passed, 0 failed and 10 skipped on `71b780e`. `flutter analyze` found no issues. Part 1 alone (`2403055`): 2675 passed, 10 skipped, 0 failed.
  - The 10 skipped tests are the same as before, and W5 does not touch them: the live server check in `test/services/online/public_wss_smoke_test.dart` (runs only with `RUN_PUBLIC_BATTLE_SMOKE`) and 9 known push-up judge errors in `test/services/pose/pushup_error_cases_test.dart`, each with its reason.
  - The review runs measured the changed files alone with `--coverage` (not the layer numbers), on part 2's tree: `result_screen.dart` 100% (117/117), `result_report.dart` 99.6% (the line left is W6's painter `shouldRepaint`), `victory_overlay.dart` 100%, `victory_scene.dart` 99.2%.
- **The design checks:** `test/widgets/victory_golden.json` is the bundle's golden file. Every pose sample (each character's poses, expression and whole-picture move, with the end blends 0.3 / 0.6 / 1, times past one loop, and the stills) matches within its tolerance 0.01. So does every scene sample (panel, band, stand, the character's feet / scale / opacity / motion time / end blend and its pose, the confetti where given). Every W4 and W5 drawPatch finds its shape, and the five stage effects are not drawn, for 5 characters × every key pose. With the app's fonts, renders of the result screen were compared with the design's stills by eye (local renders, not committed).
- **Mutation checks (by me, files restored byte for byte):** all caught.
  - Part 1: a restart after the end; reduced motion ignored.
  - Part 2: each of the four re-measure triggers (insets, text size, screen size, scroll). A fifth one (a view-model listener) survived, because loading changes only the cards below the seat, so that code was removed.
  - Step 5: a past report playing the scene; a past bot battle's 다시 대결 going to the online lobby; the past battle's "has a score" flag forced true and forced false (forced false survived at first, so a test was added); 다시 대결 starting from home for every battle, or for none.
- **Other checks:**
  - `ownership_guard.py --check-diff`: ok on `71b780e`, 19 changed files. They are W5's files plus the user's one-off W5 exceptions of 2026-11-15: `widgets/result_report.dart` (W6's file; the seat only), `screens/history_screen.dart` (W7's; the link to the report only), and in `test/screens/history_screen_test.dart` and `feedback_screen_test.dart` only the three tests that expected a row to open the feedback.
  - Server `pytest` was not run, because `server/` did not change.
- **Coverage:** TODO(Woohyun Song): fill the table, the app total and the files CI leaves out from the W5 PR's CI comment (commit, run link).
- **Shortfalls:** none known; the coverage numbers are still to come.
- **Screen readers:** widget tests check the skip button's name ("승리 연출 건너뛰기" / "연출 건너뛰기"), that it goes once the scene ends, and that the seat's picture is not read. TalkBack on a real phone was **not** checked.
- **Manual check:** not done on a phone yet. It will be checked once, on a `main` build after all the PRs are merged: a KO / time / opponent-left win, a loss and a draw, reduced motion, larger text, and a battle opened from 기록보관소.

### Test cases added or changed in this step
| Layer | File | What it covers |
|---|---|---|
| View | `test/widgets/victory_motion_test.dart` (new) | the rig's data (the bundle's file, five characters, key poses alike in steps, timetables and ends that exist, one landing per motion, the expression map, RepBot / unknown ids as the default, malformed data rejected); every pose golden sample within 0.01 (end blends 0.3 / 0.6 / 1, wrapped times, stills); the end blend and the end expression from 0.5; blending tables; every W4 and W5 patch finds its shape, W5's before W4's paddle; every key pose painted; the stage effects marked and not drawn; the teeth, the grin and the tongue |
| View | `test/widgets/victory_scene_test.dart` (new; updated in part 2) | the scene golden (5 × 17 KO times, 7 loss times, both stills; a draw is a loss's scene); the end times; the band by result; the layers' times; the seat, the stand and the panel's last box near the seat; every motion inside the seat; the colors are the palette's; another screen size; the confetti leaving the screen; the result kinds; `VictoryResult.decide` |
| View | `test/widgets/victory_overlay_test.dart` (new; updated in part 2) | on a test backdrop: a win plays and ends at 2100 ms, a loss at 760 / 820 ms; the band's words; pixels of the panel, band, stand and seat; a tap skips and the button under it works after; the screen-reader skip; reduced motion (from the start and turned on while playing); `play: false`; plays once; play turned off; RepBot / unknown ids; the painter at every golden time on 360 × 780, 412 × 915 and 0 × 0; `onEnd` once when played out or skipped, never when it does not play or is stopped from outside |
| View | `test/widgets/victory_seat_test.dart` (new) | with the app's fonts: the seat at x 200–344 on the score row (the design's place, a status bar lower), on a wider phone; the headline, sub line and reason line keep left of it for seven kinds of line at 1.0 / 1.3 / 1.5× text; a long nickname cut before it, the seconds whole; at 2× text the seat's own row (a line without seconds still fits beside it); the switch at the sub line's least width (±0.5); the least width itself; no seat, no cell; `VictorySeat`'s end look for each result (stand at +44 / +129, feet at +86 / +132), with no button, no frames and no taps |
| View | `test/widgets/victory_test_support.dart`, `victory_golden.json` (new) | the golden file and its readers |
| View | `test/screens/result_screen_test.dart` (updated) | the scene of J4's state; on the screen with the app's fonts: KO / time / opponent-left wins play the cut-in with their band and end on the seat, then the report's buttons work; a loss and a draw frustrate on the seat; a tap skips and does not reach the report's button; reduced motion (from the start, and turned on while playing, not replayed when off); plays once; data arriving while it plays; the scene follows the seat when insets, text size, screen size or the scroll change; leaving while it plays; the default character. A past battle: 다시 대결's battle (`rematchOf`); the report opened from the archive with the end look only from its first frame, system back to the archive; J4's record view model and the feedback link; the latest battles only with a score; 다시 대결 from home for a past battle, in the report's place for one just played |
| View | `test/screens/history_screen_test.dart` (updated, two tests, exception) | a row opens its battle's report with the end look only (one without feedback too), and the report links to the feedback; the full list the same way |
| View | `test/screens/feedback_screen_test.dart` (updated, one test, exception) | a battle in 기록보관소 opens its report, and its 자세 피드백 전체 보기 the same feedback screen |
| Design | `test/design_tokens_test.dart` (updated) | `victory_motion.dart`, `victory_overlay.dart`, `victory_rig_data.dart`, `victory_scene.dart` in the token check |

### Acceptance criteria → tests
- Given I win, the animation plays and the result shows win, loss or draw with both scores (UAT-4 AC1). Tests: `'$name: the cut-in with "$band" over the report, then my character on its seat right of the headline; then the report\'s buttons work'` (KO, time, opponent left), `'a ${outcome.name}: no cut-in and no band; $character frustrates once on the seat on a white stand, then the end look stays ($endMs ms)'`, and W6's `'a time-up ${squat ? 'squat' : 'push-up'} ${outcome.name}: "$headline", both scores, the seconds'`
- Each character's poses, expression and whole-picture move match the golden within 0.01. Tests: `'$id matches every golden sample within 0.01'`, `'the samples cover the end blends 0.3, 0.6 and 1, wrapped times …'`
- Every scene sample matches. Tests: `'$id: a KO win matches every golden time'`, `'$id: a loss matches every golden time, and a draw is the same'`
- Every W4 and W5 drawPatch target is found and the stage effects are not drawn. Tests: `'every W4 and W5 patch finds its W3 shape, W5\'s right after it …'`, `'the five stage effects are marked in every character\'s list'`
- The band reads as the spec by result. Tests: `'the band reads the result (spec 4); a loss or a draw has none, …'`, `'${result.name}: the band reads "$words"'`
- A tap jumps to the end; after the end the page under it takes taps. Tests: `'a tap anywhere skips to the end look on the seat; that tap does not reach the report\'s button, the next one does'`, `'a tap anywhere jumps to the end look, not to the report\'s button'`
- Reduced motion and "do not play" show one still picture. Tests: `'with reduced motion a ${outcome.name} does not play: the seat shows the end look from the first frame'`, `'reduced motion turned on while it plays: the end look at once; turned off again, it does not play again'`, `'a past report (play: false) shows only the end look and its button works at once'`
- The seat is the spec's 144 × 148 cell right of the headline (spec 2, 11.2). Tests: `'on a 360 x 780 phone the seat is x 200-344, 144 x 148, and ends on the score row\'s top: …'`, `'${result.name}: the stand and the end pose in a 144 x 148 box, …'`
- A battle in 기록보관소 opens its report with only the end look. Tests: `'a row opens its battle\'s report, with the end look only: …'`, `'$name: the report opens on top with the end look only, from its first frame; system back returns to 기록보관소'`, `'a battle in 기록보관소 opens the same feedback screen'`

#### 2026-11-15 · code at commit `cf801f0` · A6 (unplanned; meant for PR #68, which was merged first, so it goes in a follow-up PR from `feat/victory_animation`): no button in the battle setup
- **What changed (team decision 2026-11-15):** the battle setup no longer shows a button in the camera area: no 시작 in AI battles, no 준비 / 준비 취소 in online battles. Both setups already went on by themselves, so the button only confused first-time players. The bot round still starts 3 s (`SetupConfig.autoStartDelay`) after the pose is ready. Online ready is still sent after the same 3 s, taken back when the pose is lost, and sent again 3 s after it is found again. The arena's button inputs, `BattleViewModel.startNow` and the demo are unchanged.
- **Tests:** on `cf801f0`, `flutter test` had 3214 passed, 0 failed and 10 skipped (the same 10 as before). `flutter analyze` found no issues. The three changed test files have 116 tests. Coverage: TODO(Woohyun Song): from the CI comment on the follow-up PR (commit and run link).
- **Mutation checks (by me, files restored by hash):** all caught. Putting the AI 시작 button back fails 7 tests in its file, and putting the online 준비 button back fails 8 in the two online files. Not taking ready back when the pose is lost fails 3 of the tests run by name. Keeping the auto-ready count through a lost connection fails 1 of the tests run by name.
- **Other checks:** reviewer run 1 returned CHANGES_REQUESTED with 1 Critical (a harness bookkeeping row) and 4 Minor; one of the Minor findings was a lost-connection check that could not fail, which is now rewritten. The re-check returned APPROVE. `ownership_guard.py --check-diff`: ok on `cf801f0`, 27 changed files. Server `pytest` was not run, because `server/` did not change.
- **Merge of `main` (no rebase), after #68 was found merged:** `23a00ce` brought in #68's merge commit (`52fb957`; its code was already on the branch) and #66 (`fix/squat_judge_accuracy`). There was no conflict, and #66 changed none of A6's files. On `23a00ce`, `flutter test` had 3218 passed, 0 failed and 10 skipped (the +4 are #66's tests), and `flutter analyze` found no issues. `ownership_guard.py --check-diff` was ok with 8 changed files against `main`: A6's 5 code and test files and these 3 notes.
- **Manual check:** not done on a phone yet; it is part of the one check on a `main` build after all PRs are merged (AI and online setups, push-up and squat).

### Test cases added or changed in A6
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/battle_screen_test.dart` (updated, exception) | no 시작 button in the setup, the countdown or the UAT-1 setup checks; for push-ups and squats, the pose held makes the round start by itself 3 s after the pose was ready, with GO!. The stage's start cue (`go`) is still told to a screen reader as 시작, while no 시작 text shows. Replaces the test of 시작 cutting the countdown short |
| View | `test/screens/online_preparation_test.dart` (updated, exception) | no 준비 / 준비 취소 button in the setup or the countdown, on camera failure, or in the squat checks; ready goes by itself 3 s after a ready pose (also with a propped and still phone); for push-ups and squats, ready is sent once while the pose is held, taken back when it is lost, and sent again 3 s after it is found again; a lost connection drops the count, and a new one runs once it is back. The two tests of pressing 준비 / 준비 취소 are replaced |
| View | `test/screens/online_lobby_screen_test.dart` (updated, exception) | the lobby-to-setup flow shows no 준비 / 준비 취소 button |

### Acceptance criteria → tests (A6)
- The setup shows no button. Tests: `'opens on the setup: the band, my tag setting up and the bot's ready, the setup bar and the hint, and no 시작 button (team decision 2026-11-15)'`, `'both players set up on the stage; the camera area has the setup bar and the hint, and no 준비 / 준비 취소 button (team decision 2026-11-15): the pose held, ready goes by itself'`
- AI: the pose held, the round starts by itself (push-up and squat). Tests: `'$name: no 시작 button in the setup or the countdown; the pose held, the round starts by itself, and the start is still told as 시작 to a screen reader'`
- Online: ready by itself, taken back when the pose is lost (push-up and squat). Tests: `'$name: no 준비 / 준비 취소 button (team decision 2026-11-15); the pose held, ready goes once by itself; losing the pose takes it back, and holding it again sends it again'`, `'losing the valid pose revokes ready instead of starting the round'`, `'a lost connection is said in the hint, and the auto ready starts over once it is back'`

## W9 setup-readability records

#### 2026-11-17 · code at commits `a3db21a`, `20c623f` · step W9 `feat/setup_readability` (A9, setup and battle cues readable from a distance, squat and push-up, team order #19)
- **What changed:** UAT cycle 1 comment 3 (the squat's words could not be read at 2.5 m). Design UxSq variant A2, for push-ups and squats, in AI and online battles.
  - **Setup band:** two short lines in Do Hyeon 76, an icon box and a hold bar (`lib/models/setup_hint_short.dart`, new). A different cue waits 600 ms, unless it says the setup is right. The long sentence is the band's screen-reader name.
  - **Status frame:** the camera area has a 12 wide frame. While setting up it has the cue's green or red. It is green in the countdown, green for 700 ms after my counted rep, and amber or red while the sign of my average or rejected rep is up.
  - **Reject sign:** 216 x 250, label 66.
  - **Lines and silhouettes:** bold squat and push-up lines with name pills, bold joints on the battle camera, and silhouettes twice as wide.
  - **Removed:** the AI battle's squat line during the round.
- **Commands (Windows, `gymrats_app/`):** `flutter analyze`; `flutter test`.
- **Tests:** on the working tree committed as `20c623f`, `flutter test` had 3387 passed, 0 failed and 10 skipped (the same 10 as before). `flutter analyze` found no issues.
- **Coverage:** not measured on this Windows PC. TODO(Woohyun Song): fill in from the CI comment once the PR is opened (CI runs on `pull_request` only).
- **Other checks:**
  - Reviewer run 1 returned CHANGES_REQUESTED: 1 Major (a raw `fontSize: 13` in the line-name pills) and 4 Minor (no check of the battle camera's bold flag; no online test that the squat round has no line; the silhouettes' under-line not ink; the pills covering the line starts). All were fixed, and the re-check returned APPROVE.
  - `ownership_guard.py --check-diff`: ok, 32 changed files, among them the two exceptions approved on 11-17.
  - Server `pytest` was not run, because `server/` did not change.
- **Manual check:** TODO(Woohyun Song): the phone check. Squat at 2.5 m and push-up at 1 m: the cue, the frame colors, the lines and the sign; whether the band hides the silhouette's head; whether the sign meets the opponent's combo mark.

### Test cases added or changed in W9
| Layer | File | What it covers |
|---|---|---|
| Model | `test/models/setup_hint_short_test.dart` (new) | every row of the A9 short-cue table, ready and holding, a squat outside the silhouette; one, two, three or more and no missing parts with 이/가 and '안' on the second line; the hand icon only for arms; the online cues (waiting, the auto-ready count, reconnecting); a right cue always shows the check; `looksLike` and equality |
| View | `test/widgets/battle_camera_area_test.dart` (updated) | the band's place, size, icon box, Do Hyeon 76 lines and hold bar; the sentence only as a live-region label; each icon; every cue on one line each, at 56 or more except two missing parts, at 1.0x, 1.3x and 2.0x text; the real-font sizes 76, 64.6 and 44.1; the 600 ms hold; the camera switch at the bottom right; the frame from the cue while setting up and from the round after; the frame under the buttons |
| View | `test/widgets/battle_fx_motion_test.dart` (updated) | the camera frame: green for 700 ms after my counted rep, amber or red while its sign is up, none without a sign, the latest rep replaces, the opponent ignored, green in the countdown, none while setting up or after the end |
| View | `test/widgets/battle_arena_test.dart` (updated) | the cue band and the camera switch on an S22; the cue and the stage's frame passed to the camera area; the larger sign 76 above the line |
| View | `test/widgets/battle_reject_sign_test.dart` (updated) | the 216 x 250 sign: tile 156 with a 5 edge and corner 30, pictogram 136, label Do Hyeon 66 on a band with a 4 edge, the longest label inside 360, pivot and wobble |
| View | `test/widgets/squat_height_overlay_test.dart` (new) | the lines as 8 of color over 14 of ink, the knee amber, the hip white and status green at the bottom over the knee line; the pills after the lines; the lines start after the wider pill; nothing without a frame or heights or when lost |
| View | `test/widgets/chest_height_overlay_test.dart` (new) | the start-height dashes (white 3 over ink 6); the shoulder line (white 8 over ink 14) with a 9 dot, green at the bottom; the start pill lifted above the shoulder pill at the top of a rep; the phase passed to the painter |
| View | `test/widgets/landmark_overlay_test.dart`, `test/widgets/pose_camera_view_test.dart` (new), `test/widgets/battle_camera_view_test.dart` (updated) | the bold look: white joints of 8 with a 2.5 ink edge and ink-edged bones only between likely joints; off by default (tutorial, demos); `PoseCameraView` passes the flag to `LandmarkOverlay`; the battle camera turns it on |
| View | `test/widgets/pose_silhouette_guide_test.dart`, `test/widgets/pose_silhouette_squat_test.dart` (updated) | outlines twice as wide over ink, status green once the pose fits |
| View | `test/screens/battle_screen_test.dart` (updated) | the UAT-1 setup checks through the short cue (phone angle, missing hand, missing feet, too close); a squat outside the silhouette says 실루엣에 / 맞춰요 in red; the squat round has no line of words |
| View | `test/screens/online_preparation_test.dart` (updated) | the online cues (the auto-ready count with the hold bar, waiting for the opponent, the phone angle and shaking, reconnecting in amber); no line of words in the online squat round |
| View | `test/screens/online_lobby_screen_test.dart` (updated, exception) | the waiting check reads the cue's lines and its sentence as the label |
| Design | `test/theme/app_theme_test.dart` (updated) | `statusGood`, `cameraSetupCue` (76, line 0.98), `stageSignLabel` (66, line 1.12), `cameraLineLabel` |

### Acceptance criteria → tests (W9)
- UAT-1 AC1-AC3 still pass with the short cue: a wrong phone angle or a missing body part is named, and no countdown starts. Tests: `'AC1, step 2 (push-up): a phone lying almost flat, then the left wrist out of the picture: the hint says what to fix, and nothing counts down'`, `'step 5 (squat): missing feet and standing too close are named, and nothing counts down; standing still then counts down and starts with the standing silhouette'`, `'a squat whose pose is right but which is not in the silhouette says 실루엣에 / 맞춰요 in red, and nothing counts down (A9 spec 2)'`, `'online setup requires a propped and still phone'`
- The camera frame shows green, red or orange as in spec 3. Tests: the groups `'the status frame (A9 spec 3)'` (camera area) and `"the camera's status frame (A9 spec 3)"` (stage)
- The sign and the lines are larger. Tests: `battle_reject_sign_test.dart`, `squat_height_overlay_test.dart`, `chest_height_overlay_test.dart`, `landmark_overlay_test.dart` (group `'the bold look (A9 spec 4, the battle camera)'`). Whether they read at about 2.5 m and 1 m is the phone check (TODO above).
- No squat line of words in the round, AI and online. Tests: `'a squat setup has a silhouette; the round has the squat lines and no line of words (A9 spec 6)'`, `'a squat setup shows the silhouette; the squat lines come with the round, and no line of words (A9 spec 6)'`
