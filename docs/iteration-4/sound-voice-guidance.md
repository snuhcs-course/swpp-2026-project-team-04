# Sound 1/2: voice guidance (J1, `feat/voice_guidance`)

Iteration 4, task P9 "Add voice guidance for setup and battle". Owner: Jinyoung Park (`ishlove77`).
Part 2 (BGM by round phase and the screen wiring) is J2 `feat/battle_bgm`, written up in `sound-battle-bgm.md`.

## Decision: device TTS, not recorded clips (2026-11-07)
The voice lines are spoken by the phone's Korean text-to-speech through `flutter_tts` (Android `TextToSpeech`).
Recorded clips with `audioplayers` were the alternative. TTS won because there are no clips to record, license, or
re-record when a line changes (the setup hints are still moving in S3 `feat/pose_silhouette_guide`), every line is one
string in `VoiceCue`, and the diff stays small. `audioplayers` arrives with the BGM files in J2.
Known cost: the voice depends on the phone's TTS engine (Samsung TTS or Google TTS on the S22/S23 test devices), and
the first utterance after app start can lag a little while the engine warms up.

## What J1 adds (no screen edits)
| File | What |
|---|---|
| `lib/models/voice_cue.dart` | `VoiceCue`: every line with its Korean text, group (setup / battle), and whether it cuts off the current line |
| `lib/services/audio/speech_engine.dart` | `SpeechEngine` interface: `speak(text)` (completes when the utterance ends) and `stop()` |
| `lib/services/audio/tts_speech_engine.dart` | `TtsSpeechEngine`: `flutter_tts`, configured once (ko-KR, rate 0.5, pitch 1.0, awaited completion, audio focus) |
| `lib/services/audio/voice_guidance.dart` | `VoiceGuidance` interface (`say`, `stop`, `reset`, `dispose`) and `VoiceGuidanceService` with the rules below |
| `lib/services/audio/voice_cue_table.dart` | `VoiceCueTable`: `forSetup(SetupStatus)`, `forCountdown(Duration?)`, `forEnd(GameEnd)`, `forOutcome(MatchOutcome)` |
| `lib/services/audio/sound_settings.dart` | `SoundSettings` (ChangeNotifier, the one sound switch) + `SoundSettingsStore` (secure storage, memory) |
| `lib/services/device/device_controls.dart` | `DeviceRepSound([SoundSettings?])`: the rep beep follows the switch when given one |
| `test/support/audio_fakes.dart` | `FakeSpeechEngine`, `FakeVoiceGuidance` for J2's widget tests and anyone wiring sound |
| `pubspec.yaml` | `flutter_tts: ^4.2.5` (no asset lines: TTS needs no files) |

## Rules of `VoiceGuidanceService`
- **One line per change.** `say(cue)` may be called every frame or on every state update. A cue equal to the newest
  requested cue is dropped, so a hint or an event is spoken once until the cue changes. `reset()` forgets the last cue
  (new screen, new round). Optional `repeatAfter` says the same cue again after that long for a user stuck on one hint.
- **While speaking.** A setup hint waits as the single pending cue (the newest wins; a pending cue equal to the line
  just spoken is not repeated). A cue with `interrupts` (ready, countdown, every battle event) stops the current line
  and speaks at once.
- **Sound off.** `SoundSettings.enabled == false` stops the current line and silences new ones. The same switch is
  meant for the BGM (J2) and the rep beep.
- **Background.** The service is a `WidgetsBindingObserver`: any state but `resumed` stops the current line and
  silences `say` until the app is resumed.
- **Failures.** A phone without a TTS engine or a Korean voice: errors from the engine are swallowed, the battle goes on.
  `flutter_tts` 4.2.5 does not finish the awaited `speak` on a TTS error, so `TtsSpeechEngine` also ends the utterance
  from the plugin's completion and error callbacks (counted only after the line's own `onStart`, because the callbacks
  name no utterance and a cut-off line's cancel would otherwise end its replacement), and the service waits at most
  `maxUtterance` (8 s, a cancellable timer) per line. A failed first configuration (TTS service not bound yet) is
  retried on the next line.
- **Owner disposes.** Whoever creates a `VoiceGuidanceService` (J2's sound widget) calls `dispose()` when it goes away:
  it unregisters the lifecycle observer and cancels the per-line timer (a widget test fails with a pending timer
  otherwise).

## Voice lines (cue table)
| Trigger (J2 reads it from the screen state) | `VoiceCue` | Spoken |
|---|---|---|
| `SetupReason.noPerson` | `noPerson` | 카메라 앞에 서 주세요. |
| `tooClose` / `tooFar` | `tooClose` / `tooFar` | 조금 뒤로 물러나 주세요. / 카메라에 조금 더 가까이 와 주세요. |
| `notFacingForward` | `notFacingForward` | 카메라를 정면으로 봐 주세요. |
| `missingParts` | `missingParts` | 몸 전체가 화면에 보이게 해 주세요. |
| `notInPushUp` / `notStanding` | `notInPushUp` / `notStanding` | 팔을 펴고 푸시업 자세를 잡아 주세요. / 정면을 보고 똑바로 서 주세요. |
| `phoneTooFlat` / `phoneShaky` | `phoneTooFlat` / `phoneShaky` | 폰을 더 세워 주세요. / 폰이 흔들리지 않게 두세요. |
| `SetupReason.ready`, not yet stable | `holdStill` | 그대로 잠시 유지하세요. |
| `SetupStatus.isReady` | `ready` | 준비 완료! |
| auto start in 3 / 2 / 1 s (rounded up like the screen) | `countdownThree/Two/One` | 셋 / 둘 / 하나 |
| round starts | `battleStart` | 시작! |
| fever begins | `fever` | 피버 타임! |
| last seconds (threshold chosen in J2; the line names no number) | `lastSeconds` | 마지막 스퍼트! |
| `GameEnd.ko` / `GameEnd.timeUp` | `ko` / `timeUp` | 케이오! / 타임 업! |
| `MatchOutcome.win` / `lose` / `draw` | `win` / `lose` / `draw` | 승리! / 패배. / 무승부. |

## How J2 wires it (planned)
One small widget in `lib/widgets/sound_*` listens to the setup and battle view models and calls
`VoiceGuidance.say(VoiceCueTable.forSetup(status))`, `say(VoiceCueTable.forCountdown(autoStartIn))`, and the battle
events from `BattleState` (contract: phase, fever, time left, result). Screens get a few lines; nothing calls
`flutter_tts` directly. The setup cue keys on S3's `SetupHint` enum once it lands (contract in the team plan);
`VoiceCueTable.forSetup` moves from `SetupReason` to it then.

## Tests (`flutter test test/models/voice_cue_test.dart test/services/audio test/services/device/device_controls_test.dart`)
| Layer | File | Covers |
|---|---|---|
| Model | `test/models/voice_cue_test.dart` | every cue has a Korean line, lines are distinct, which cues interrupt |
| Service | `test/services/audio/voice_guidance_test.dart` | one line per change (hint, event, countdown, reset, repeatAfter), pending newest hint, interrupts, stop, sound off, background (observer and binding), engine failures, dispose |
| Service | `test/services/audio/voice_cue_table_test.dart` | every `SetupReason`, ready, countdown rounding and bounds, end, outcome |
| Service | `test/services/audio/sound_settings_test.dart` | default on, load, notify and save, failing store, secure store next to the session key |
| Service | `test/services/audio/tts_speech_engine_test.dart` | one-time configuration, speak, stop, language, plugin error (mock `flutter_tts` channel) |
| Service | `test/services/device/device_controls_test.dart` (updated) | the rep beep follows the sound switch |

Acceptance criteria → tests: "a setup hint or a battle event plays its line once, not every frame" →
`a setup hint repeated every frame is spoken once`, `a battle event repeated with every state update is spoken once`,
`every setup reason has a "what to fix" line`; "sound off plays nothing" → `nothing is spoken while the sound is off`,
`turning the sound off cuts the current line`, `the rep beep follows the sound switch`; "no sound in the background" →
`a paused app cuts the current line and stays silent until resumed`, `the service hears the lifecycle from the binding`.
