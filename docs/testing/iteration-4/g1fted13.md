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
| Model | flutter_test | 90% | not measured on this Windows PC (coverage collection hangs); TODO(Woohyun Song): fill from the PR's CI coverage comment | 11/08 | `flutter test`; coverage: CI comment "Tests and coverage (GitHub Actions)" on the W1 PR |
| ViewModel | flutter_test, fakes | 90% | same as above | 11/08 | same as above |
| Service | flutter_test, MockClient, fakes | 85% | same as above | 11/08 | same as above |
| View | flutter_test (widget) | 75% | same as above | 11/08 | same as above |
| API server | pytest, pytest-django, pytest-cov | 90% | not run: `server/` unchanged | 11/08 | – |

- **Tests:** `flutter test` 1490 passed, 0 failed, 10 skipped. `flutter analyze` found no issues. The skipped tests were already skipped on `main`, and W1 does not touch them:
  - `test/services/online/public_wss_smoke_test.dart`: a live team-server check that runs only with `RUN_PUBLIC_BATTLE_SMOKE`.
  - 9 recordings in `test/services/pose/pushup_error_cases_test.dart`: known push-up judge errors, each with its reason in `knownErrors`.
- **Count change:** `main` at `998a6fd` had 1476 passing tests. W1 deletes `test/widgets/bot_difficulty_sheet_test.dart` with its widget (the AI 1v1 page replaces the sheet), rewrites the home tests, and adds the files marked "(new)" below.
- **Other checks:** `ownership_guard.py --check-diff` ok (48 files, all W1's or approved exceptions). Server `pytest` was not run because `server/` did not change.
- **Checks after merging `origin/main`:** `git fetch origin && git merge origin/main` said "Already up to date": `main` is still `998a6fd`, which the branch already contains, so the code is still `38c44b1`. I reran the checks anyway on 2026-11-08: `flutter analyze` found no issues, and `flutter test` had 1490 passed, 0 failed and 10 skipped (the same tests). `ownership_guard.py --check-diff` is ok (48 files).
- **Shortfalls:** coverage is not known until the PR's CI comment exists. The View files W1 adds or rewrites have widget tests for every state and tap, so I expect View to stay above 75%. This is an expectation, not a measurement.
- **Manual check (2026-11-08, the user, on a phone):** the user checked these on a build of this branch and reported no problems ("폰 확인 끝났어. 문제없어."). TODO(Woohyun Song): which phone (S22 or S23) and its Android version.
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
