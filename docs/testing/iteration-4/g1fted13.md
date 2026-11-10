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

#### 2026-11-11 · code at commit `15e0dcd` · step W1 `feat/home_lobby`, follow-up to the Codex review of PR #45 (team order #2)
The Codex review of PR #45 (on `78351da`, 2026-11-10) left three comments. This push fixes two of them on the same branch:
- **Result screen (Codex P1), commit `5909acd`.** WIN and LOSE were lime and pink text on the light ground, about 1.03:1 and 2.58:1. Now:
  - the verdict word is ink on a slanted band, lime for a win and pink for a loss;
  - the scores and the 자세 피드백 보기 label are ink;
  - DRAW, the layout and the wording are unchanged.
  - `result_screen.dart` is W6's file. It was changed under a one-off exception: text readability only.
- **환경설정 nickname (Codex P2), commit `15e0dcd`.** A 12-letter nickname at a large text size overflowed its row. It is now one line, at most 40% of the screen width, and ends in "…".
- **Not fixed here (Codex P2, issue #47).** "최근 설정으로 다시 하기" guesses bot or online from the opponent's name. A fix needs the mode in the match record, which is in J3's files, so there is no code change.

I ran the commands from the Plan in `gymrats_app/` on Windows, on `15e0dcd`, without coverage.

| Component | Frameworks | Target | Actual | Date | Command / Report |
|---|---|---|---|---|---|
| Model | flutter_test | 90% | not measured on this Windows PC (coverage collection hangs); TODO(Woohyun Song): fill from the PR's CI coverage comment | 11/11 | CI comment "Tests and coverage (GitHub Actions)" on PR #45 after the push |
| ViewModel | flutter_test, fakes | 90% | not measured on this Windows PC; TODO(Woohyun Song): fill from the PR's CI coverage comment | 11/11 | same CI comment |
| Service | flutter_test, MockClient, fakes | 85% | not measured on this Windows PC; TODO(Woohyun Song): fill from the PR's CI coverage comment | 11/11 | same CI comment |
| View | flutter_test (widget) | 75% | not measured on this Windows PC; TODO(Woohyun Song): fill from the PR's CI coverage comment | 11/11 | same CI comment |
| API server | pytest, pytest-django, pytest-cov | 90% | not run (`server/` unchanged) | 11/11 | – |

- **Tests:** `flutter test` had 1499 passed, 0 failed and 10 skipped. `flutter analyze` found no issues.
  - The 10 skipped tests are the same ones as on 11-08.
  - The count grew from 1490 by the 9 new tests below. No test was removed.
- **Tests before the fix:** I wrote the new and changed tests first and ran them on the code before the fix (`78351da`). 10 failed:
  - In `result_screen_test.dart`, 8 failed: the three updated ink checks, WIN and LOSE on a band, and "no lime or pink text" for a win, a loss and a draw. The draw screen fails too, through its lime and pink scores and the feedback button's lime label.
  - In `settings_screen_test.dart`, 2 failed: the 12-letter nickname at 1.3× (no ellipsis) and at 2× ("A RenderFlex overflowed by 114 pixels on the right"), the overflow Codex described.
  - The DRAW test and the short-nickname test passed on the old code as well. They guard what must not change.
- **Other checks:** `dart format --set-exit-if-changed` passes on the four changed files, and `ownership_guard.py --check-diff` is ok. Server `pytest` was not run because `server/` did not change.
- **Coverage:** TODO(Woohyun Song): fill from the CI comment on PR #45 after the push (commit hash and run link).
- **Shortfalls:** none known; coverage is pending.
- **Manual check:** not checked on a phone for this push. The agent rendered the result screen (393×852; WIN, LOSE, DRAW) and 환경설정 (360×780 at 1.0×, 1.3× and 2.0× text) from `15e0dcd` to images for a look by eye. The images are not committed.

### Test cases added or changed in this follow-up
| Layer | File | What it covers |
|---|---|---|
| View | `test/screens/result_screen_test.dart` (updated; W6's file, exception) | WIN and LOSE are ink on a slanted lime or pink band, 4.5:1 or more; DRAW stays ink with its glow and no band, 4.5:1 or more on the ground; a win, a loss and a draw paint no text in lime or pink, the feedback button included; the scores are ink |
| View | `test/screens/settings_screen_test.dart` (updated) | a 12-letter nickname at 1.3× and 2× text is one line ending in "…", right of its title and inside the screen, and a screen reader gets the whole name; a short nickname shows whole at the right of its row |

### Acceptance criteria → tests (this follow-up)
- The verdict word is 4.5:1 or more (user spec 2026-11-11, Codex P1). Tests: `'$word is ink on a slanted band, 4.5:1 or more'` (WIN, LOSE), `'DRAW stays ink on the screen ground, with no band'`.
- Lime and pink text become ink, button text included. Test: `'a ${outcome.name} paints no text in lime or pink, the feedback button included'` (win, lose, draw).
- The nickname is one line ending in "…" with 12 letters at 1.3× and 2× text (Codex P2). Tests: `'a 12-letter nickname at ${scale}x text is one line that ends in …, beside its title'`, `'a short nickname shows whole, at the right of its row'`.
- UAT-4 AC1 (win, loss or draw with both scores) still holds. Tests: `'a win: WIN, the margin, both players, and my stats'`, `'$mine:$theirs is a $word'`.
