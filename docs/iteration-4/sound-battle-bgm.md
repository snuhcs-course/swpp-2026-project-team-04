# Sound 2/2: background music, battle sound effects and the sound widgets (J2, `feat/battle_bgm`)

Iteration 4, task P11 "Add battle BGM by round phase". Owner: Jinyoung Park (`ishlove77`).
Part 1 (the voice guidance) is J1 `feat/voice_guidance`, written up in `sound-voice-guidance.md`. This branch builds on
it ("depends on `feat/voice_guidance`").

## Tracks (picked by the team on 2026-11-11/12)
All are CC0 from OpenGameArt.org (no attribution required; the license was checked on each page on 2026-11-11).
The team compared the candidates on a shared listening page that previews a 30-second round.

| Cue | When | Track | Author | Source | File |
|---|---|---|---|---|---|
| `menu` | home, lobby and other menus | Menu Theme | tamesu | https://opengameart.org/content/menu-theme | `assets/audio/bgm_menu.mp3` |
| `setup` | pose setup, waiting for the opponent | Laid Back (The War Over A Melon Field) | – | https://opengameart.org/content/the-war-over-a-melon-field-themes-and-jingles | `assets/audio/bgm_setup.ogg` |
| `battle` | round, 0–20 s (from its first beat at 1.54 s, 0.15 s fade-in) | Fast Fight / Battle Music | bonsaiheldin | https://opengameart.org/content/fast-fight-battle-music | `assets/audio/bgm_battle.ogg` |
| `fever` | fever, 20–30 s (the game's fever lasts to the end) | the battle track at 1.25× speed and pitch | – | – | same file |
| `win` | the round was won (once) | Victory | – | https://opengameart.org/content/victory | `assets/audio/bgm_win.mp3` |
| `lose` | the round was lost (once) | Game Over! | – | https://opengameart.org/content/game-over-0 | `assets/audio/bgm_lose.m4a` (the 3 MB float WAV re-encoded to AAC) |

Decisions: fever plays the battle track faster (1.25×, user 2026-11-12; was 1.15×) instead of a separate track, and lasts the game's 10 fever seconds, so
there is no separate "last seconds" track (user 2026-11-12). The faster fever music marks the last seconds; there is no voice.

## Effects in the battle, no voice (user 2026-11-12, 2026-11-14)
The battle has no voice. The 2026-11-12 plan kept the voice for the setup and the countdown; after the phone check on
2026-11-14 the user dropped it there too, so the battle screens no longer pass `onSetup` to the voice. The user's reps sound by
their result instead, and an alarm repeats while the user is in danger. The opponent's reps make no sound. The design
reference is the team's battle-stage design (choice A, ring-out stage). The team compared the candidates on the
listening page (effects over the battle music in a scripted 30-second round); the picks below are its preset. On the
phone (2026-11-14) the light hit (0.2 s) was lost under the battle music, so it was raised to sit just under Good (loudest
50 ms: Excellent -5.5, Good -5.7, Average -7.2 dB; was -9.2), keeping Excellent > Good > Average.

| Effect | When | Sound | Source | File |
|---|---|---|---|---|
| `good` | my rep, Good | one punch | Punch (qubodup), https://opengameart.org/content/punch | `assets/audio/sfx_hit_good.wav` |
| `excellent` | my rep, Excellent | one-two punch (two of the punches above, 0.08 s apart) | same | `assets/audio/sfx_hit_excellent.wav` |
| `average` | my rejected rep that earned Average points | light hit | 100 CC0 SFX `hit_01`, https://opengameart.org/content/100-cc0-sfx | `assets/audio/sfx_hit_average.wav` |
| `reject` | my rep that earned nothing (a miss) | low double buzz | made for this app | `assets/audio/sfx_reject.wav` |
| danger alarm | while I am 60+ points behind, looped | two-tone beep (880/660 Hz) | made for this app | `assets/audio/sfx_danger.wav` |
| `ko` | the round ended by KO | gong | 100 CC0 SFX `gong_01`, https://opengameart.org/content/100-cc0-sfx | `assets/audio/sfx_ko.wav` |

All CC0 (checked on each page 2026-11-12) or made here. Each file was trimmed of leading silence (some had 0.2 s, which
felt like lag) and leveled to about -12 dB RMS; WAV 32 kHz mono, 13-76 KB. The battle music plays at half volume
(`battleVolume`), so the hits stand out as on the listening page (effects about twice as loud as the music). Fever has
no sound of its own: the music speeds up.

## Package: `just_audio` (2026-11-12)
`just_audio` (ExoPlayer on Android) was chosen over `audioplayers`: gapless loops, and speed and pitch can be set
together so fever sounds like the preview. It handles audio focus: `flutter_tts` asks for transient focus that may duck
(`AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`), so the music would duck under a voice line; moot while the battle has no voice (2026-11-14).
`pubspec.yaml` and `pubspec.lock` are PM files; the `just_audio` line and the `assets/audio/` line were added as an
approved one-off exception (PM agreed).

## What J2 adds
| File | What |
|---|---|
| `lib/services/audio/music_player.dart` | `MusicPlayer` interface: `load(asset, loop)`, `play`, `pause`, `stop`, `setVolume`, `setRate`, `dispose` |
| `lib/services/audio/just_audio_music_player.dart` | `JustAudioMusicPlayer`: `just_audio`; `play` is not awaited (it completes only when playback stops); `setRate` sets speed and pitch |
| `lib/services/audio/background_music.dart` | `MusicCue` (menu, setup, battle, fever, win, lose: file, loop, rate), `BackgroundMusic` interface (`play`, `stop`, `dispose`), `BackgroundMusicService` with the rules below |
| `lib/services/audio/sound_effects.dart` | `SoundEffect` (good, excellent, average, reject, ko; `forRep(grade)`), `SoundEffects` interface (`prepare`, `play`, `setDanger`, `dispose`), `SoundEffectsService`: one loaded player per effect, so a hit only rewinds and plays |
| `lib/services/audio/sound_services.dart` | `SoundServices`: the switches, the voice, the music and the effects as one app-wide set (`SoundServices.shared`, made on first use; tests set their own) |
| `lib/widgets/sound_cues.dart` | `SoundCues`: wraps a screen's body and passes its current music and voice cues on every build; its music comes back when the screen shows again |
| `lib/widgets/sound_battle.dart` | `BattleSounds`: one per battle screen; `show(stage)` (music by stage phase, danger alarm), `cue(BattleStageCue)` (my hit by grade, my miss, KO), `ended()`; `dispose()` frees the effects and, unless a decided result was shown, plays `menu` (left mid-battle or ended without a result; Codex, PR #53); `NoRepBeep` |
| `test/support/audio_fakes.dart` | adds `FakeMusicPlayer`, `FakeMusicPlayers`, `FakeBackgroundMusic`, `FakeSoundEffects`, `fakeSoundServices()` |

Also changed: `MusicPlayer.seekToStart` (to replay an effect), `SoundSettings.voiceEnabled` (the voice's own switch),
`VoiceGuidanceService` follows `voiceEnabled`, `home_screen.dart` (menu music, approved exception),
`settings_viewmodel.dart` (passes the switches on).

## Rules of `BackgroundMusicService`
- **One change per cue.** `play(cue)` may be called on every state update; the same cue again does nothing.
- **Fades.** A new track loads silent and fades in over 0.6 s while the old one fades out on its own player, which is
  then stopped and freed. A track replaced while it is still loading is freed without playing.
- **The battle starts on the beat.** The battle track's quiet 1.5 s build-up is clipped off (`MusicCue.start`, one
  `just_audio` clip, so the loop skips it too), and it fades in over 0.15 s (`MusicCue.fadeIn`) instead of 0.6 s.
- **Fever keeps its place.** Battle and fever share the file, so fever only raises the rate (and back): no restart.
- **Jingles once.** `win` and `lose` do not loop. A jingle cut off by sound off or the background is freed, not replayed; one still
  loading then is dropped too (Codex, PR #53).
- **Sound off / background.** `SoundSettings.enabled` false, or the app not in the foreground, fades the music out and
  pauses it; it fades back in when sound returns. A looping cue asked for while silent starts when sound returns.
- **Failures are ignored.** A file that fails to load is freed; the next cue plays normally.
- **Dispose** cuts the current track and any old one still fading out, and leaves no timers.

## Rules of `SoundEffectsService`
- **Ready before the first hit.** `prepare` (`BattleSounds` calls it when the battle screen opens) loads every
  effect on its own player; `play` only rewinds and plays, so nothing is opened when the rep lands. An effect asked for
  before it is ready is skipped (a late hit is worse than none).
- **Danger alarm.** `setDanger(true)` loops the alarm, `false` pauses it. A danger that starts while the alarm still
  loads sounds once it is ready.
- **Sound off / background** silences the hits (one still sounding is cut off and not resumed, also one that was
  rewinding) and pauses the alarm; the alarm comes back with the sound if the user is still in danger (Codex, PR #53).
- **Loaded for the battle only.** `BattleSounds.dispose` calls `release` when the screen goes: the players are freed and
  the next battle's `prepare` loads them again (also retrying one that failed).
- **Failures are ignored**; `dispose` releases the players for good.

## The switches (환경설정, W1's `SettingsViewModel`)
환경설정 has two switches, saved by W1's `SettingsStore`: 효과음 (default on) and 음성 안내 (default off).
`SettingsViewModel` passes them to `SoundServices.shared.settings` when it loads them and on every change:
효과음 → `SoundSettings.enabled` (BGM and effects; the battle's rep beep is replaced by the hits in phase 2), 음성 안내 → `SoundSettings.voiceEnabled` (voice).
The device set starts silent and waits for them (a store that fails passes the defaults), so the saved switches are
the only source; `SecureSoundSettingsStore` from J1 is no longer used by the app.

## Why one shared set (`SoundServices.shared`)
The music must fade from one screen's cue into the next (setup → battle → result → menu), so every screen talks to the
same players. Registering the services as providers would need `main.dart`, which belongs to W1; the shared set keeps
the wiring inside J2's files. `SoundCues` and the settings toggle take a set as a parameter, so tests pass fakes.
Under `flutter test` (the `FLUTTER_TEST` environment variable) the shared set is `SoundServices.silent()`, so the
existing widget tests of the screens J2 wraps (owned by 송우현 and 한상우) never reach the TTS or audio plugins or leave
timers, without any change to their files. The device set starts silent and turns on only when the saved switch has
been read (a store that fails means on), so a user who turned sound off never hears the first moment of a track.

## Screen wiring (2026-11-13, after S3 #49 and W2 #50 merged)
W2's battle screens do the setup in the battle screen itself (bot and online) and open two hooks for the sound:
`onCue` (each stage moment once, as it shows: `BattleStageCue` kind, side, grade) and `onSetup` (the setup's
`SetupStatus` and the time to the start). Each battle screen keeps one `BattleSounds` and adds a few lines:

| Screen | Change |
|---|---|
| `battle_screen.dart` (bot) | field `_sounds`; `_sounds.show(stage)` after the stage state is built; `onCue: widget.onCue ?? _sounds.cue` (`onSetup` stays W2's, unused by the sound); the view model's rep beep is `NoRepBeep` (the hits replace it); `_sounds.dispose()` |
| `online_battle_screen.dart` | the same; the screen's own `DeviceRepSound` beep line is removed; a battle that ends without a result calls `_sounds.ended()` (alarm and music stop) |
| `home_screen.dart` | the lobby backdrop is wrapped in `SoundCues(music: MusicCue.menu)` (approved exception) |
| `settings_viewmodel.dart` | passes 효과음 / 음성 안내 on to the audio service |

| Stage | Music | Voice | Effects |
|---|---|---|---|
| setup, countdown | `setup` | none (dropped 2026-11-14) | – |
| playing | `battle`, `fever` (1.25x) | none | my hit by grade, my miss; alarm while in danger |
| ended | `win` / `lose` once (a draw fades out; waiting for the server's result keeps the music) | none | gong at a KO |
| left before a result | `menu` (the screen under the battle plays none of its own) | none | alarm off |

`setup_screen.dart` and `match_setup_screen.dart` are no longer on the way to a battle (their routes stay in
`main.dart` but nothing opens them), so they get no sound.

## Tests (`flutter test test/services/audio test/widgets/sound_cues_test.dart test/widgets/sound_battle_test.dart test/viewmodels/settings_viewmodel_test.dart test/screens/battle_screen_test.dart test/screens/online_preparation_test.dart test/widgets/sound_battle_screen_test.dart`)
Fakes only (no plugin, no audio output): `FakeMusicPlayer` records load, volume, rate and play state; fades run under
`fake_async`. `JustAudioMusicPlayer` is tested against a recording `AudioPlayer` stand-in. `FakeSoundEffects` records
the effects and the alarm for the battle widget; the settings tests check both switches reach the shared set.
