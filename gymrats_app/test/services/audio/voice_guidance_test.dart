import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/voice_cue.dart';
import 'package:gymrats_app/services/audio/sound_settings.dart';
import 'package:gymrats_app/services/audio/voice_guidance.dart';

import '../../support/audio_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSpeechEngine engine;
  late SoundSettings settings;
  late VoiceGuidanceService voice;
  var now = Duration.zero;

  VoiceGuidanceService build({bool manual = false, Duration? repeatAfter}) {
    engine = FakeSpeechEngine(manual: manual);
    settings = SoundSettings(store: MemorySoundSettingsStore());
    now = Duration.zero;
    return voice = VoiceGuidanceService(
      engine: engine,
      settings: settings,
      repeatAfter: repeatAfter,
      clock: () => now,
    );
  }

  tearDown(() => voice.dispose());

  group('one line per change', () {
    test('a setup hint repeated every frame is spoken once', () async {
      build();
      for (var frame = 0; frame < 30; frame++) {
        voice.say(VoiceCue.tooFar);
      }
      await pumpEventQueue();
      expect(engine.spoken, [VoiceCue.tooFar.text]);
    });

    test(
      'a changed hint is spoken, and the first one again after it',
      () async {
        build();
        voice
          ..say(VoiceCue.tooFar)
          ..say(VoiceCue.tooFar);
        await pumpEventQueue();
        voice
          ..say(VoiceCue.notFacingForward)
          ..say(VoiceCue.notFacingForward);
        await pumpEventQueue();
        voice.say(VoiceCue.tooFar);
        await pumpEventQueue();
        expect(engine.spoken, [
          VoiceCue.tooFar.text,
          VoiceCue.notFacingForward.text,
          VoiceCue.tooFar.text,
        ]);
      },
    );

    test(
      'a battle event repeated with every state update is spoken once',
      () async {
        build();
        for (var update = 0; update < 20; update++) {
          voice.say(VoiceCue.fever);
        }
        await pumpEventQueue();
        voice.say(VoiceCue.ko);
        await pumpEventQueue();
        expect(engine.spoken, [VoiceCue.fever.text, VoiceCue.ko.text]);
      },
    );

    test('the countdown says three, two, one', () async {
      build();
      for (final cue in [
        VoiceCue.countdownThree,
        VoiceCue.countdownThree,
        VoiceCue.countdownTwo,
        VoiceCue.countdownTwo,
        VoiceCue.countdownOne,
      ]) {
        voice.say(cue);
        await pumpEventQueue();
      }
      expect(engine.spoken, ['셋', '둘', '하나']);
    });

    test('after reset the same cue is spoken again', () async {
      build();
      voice.say(VoiceCue.ready);
      await pumpEventQueue();
      voice.reset();
      expect(voice.current, isNull);
      voice.say(VoiceCue.ready);
      await pumpEventQueue();
      expect(engine.spoken, [VoiceCue.ready.text, VoiceCue.ready.text]);
    });

    test(
      'with repeatAfter, a hint the user is stuck on is said again later',
      () async {
        build(repeatAfter: const Duration(seconds: 5));
        voice.say(VoiceCue.tooClose);
        await pumpEventQueue();
        now = const Duration(seconds: 4, milliseconds: 999);
        voice.say(VoiceCue.tooClose);
        await pumpEventQueue();
        expect(engine.spoken, hasLength(1));
        now = const Duration(seconds: 5);
        voice.say(VoiceCue.tooClose);
        await pumpEventQueue();
        expect(engine.spoken, [VoiceCue.tooClose.text, VoiceCue.tooClose.text]);
      },
    );
  });

  group('while a line is being spoken', () {
    test('a hint waits and the newest pending hint is spoken next', () async {
      build(manual: true);
      voice.say(VoiceCue.noPerson);
      await pumpEventQueue();
      expect(voice.isSpeaking, isTrue);
      voice
        ..say(VoiceCue.tooFar)
        ..say(VoiceCue.tooClose);
      await pumpEventQueue();
      expect(engine.spoken, [VoiceCue.noPerson.text]);
      expect(engine.stops, 0);

      engine.finish();
      await pumpEventQueue();
      expect(engine.spoken, [VoiceCue.noPerson.text, VoiceCue.tooClose.text]);
      expect(voice.current, VoiceCue.tooClose);

      engine.finish();
      await pumpEventQueue();
      expect(voice.isSpeaking, isFalse);
      expect(engine.spoken, hasLength(2));
    });

    test(
      'a hint that flickers back to the current line is not repeated',
      () async {
        build(manual: true);
        voice.say(VoiceCue.noPerson);
        await pumpEventQueue();
        voice
          ..say(VoiceCue.tooFar)
          ..say(VoiceCue.noPerson);
        engine.finish();
        await pumpEventQueue();
        expect(engine.spoken, [VoiceCue.noPerson.text]);
        expect(voice.isSpeaking, isFalse);
      },
    );

    test('an event cuts the line off and drops the pending hint', () async {
      build(manual: true);
      voice.say(VoiceCue.noPerson);
      await pumpEventQueue();
      voice.say(VoiceCue.tooFar);
      voice.say(VoiceCue.ready);
      await pumpEventQueue();
      expect(engine.stops, 1);
      expect(engine.spoken, [VoiceCue.noPerson.text, VoiceCue.ready.text]);
      expect(voice.current, VoiceCue.ready);

      engine.finish();
      await pumpEventQueue();
      expect(engine.spoken, hasLength(2), reason: 'tooFar was dropped');
    });

    test('stop cuts the line off and drops the pending hint', () async {
      build(manual: true);
      voice.say(VoiceCue.noPerson);
      await pumpEventQueue();
      voice.say(VoiceCue.tooFar);
      voice.stop();
      await pumpEventQueue();
      expect(engine.stops, 1);
      expect(voice.isSpeaking, isFalse);
      expect(engine.spoken, [VoiceCue.noPerson.text]);
      voice.stop();
      expect(engine.stops, 1, reason: 'nothing to stop');
    });
  });

  group('voice off', () {
    test('nothing is spoken while the voice is off', () async {
      build();
      settings.setVoiceEnabled(false);
      voice
        ..say(VoiceCue.tooFar)
        ..say(VoiceCue.ko);
      await pumpEventQueue();
      expect(engine.spoken, isEmpty);
    });

    test('turning the voice off cuts the current line', () async {
      build(manual: true);
      voice.say(VoiceCue.fever);
      await pumpEventQueue();
      settings.setVoiceEnabled(false);
      expect(engine.stops, 1);
      expect(voice.isSpeaking, isFalse);
    });

    test(
      'a pending hint is dropped when the sound goes off before its turn',
      () async {
        build(manual: true);
        voice.say(VoiceCue.noPerson);
        await pumpEventQueue();
        voice.say(VoiceCue.tooFar);
        settings.setVoiceEnabled(false);
        engine.finish();
        await pumpEventQueue();
        expect(engine.spoken, [VoiceCue.noPerson.text]);
      },
    );

    test('turning the voice back on speaks again', () async {
      build();
      settings.setVoiceEnabled(false);
      voice.say(VoiceCue.tooFar);
      settings.setVoiceEnabled(true);
      voice.say(VoiceCue.tooFar);
      await pumpEventQueue();
      expect(engine.spoken, [VoiceCue.tooFar.text]);
    });
  });

  group('in the background', () {
    test(
      'a paused app cuts the current line and stays silent until resumed',
      () async {
        build(manual: true);
        voice.say(VoiceCue.fever);
        await pumpEventQueue();
        voice.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(engine.stops, 1);
        voice.say(VoiceCue.ko);
        await pumpEventQueue();
        expect(engine.spoken, [VoiceCue.fever.text]);

        voice.didChangeAppLifecycleState(AppLifecycleState.resumed);
        voice.say(VoiceCue.ko);
        await pumpEventQueue();
        expect(engine.spoken, [VoiceCue.fever.text, VoiceCue.ko.text]);
      },
    );

    test('inactive and hidden count as background too', () async {
      build();
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        voice.didChangeAppLifecycleState(state);
        voice.say(VoiceCue.ko);
        voice.reset();
      }
      await pumpEventQueue();
      expect(engine.spoken, isEmpty);
    });

    testWidgets('a service created while the app is paused starts silent', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      build();
      voice.say(VoiceCue.ko);
      await tester.pump();
      expect(engine.spoken, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      voice.say(VoiceCue.ko);
      await tester.pump();
      expect(engine.spoken, [VoiceCue.ko.text]);
    });

    testWidgets('the service hears the lifecycle from the binding', (
      tester,
    ) async {
      build();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      voice.say(VoiceCue.ko);
      await tester.pump();
      expect(engine.spoken, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      voice.say(VoiceCue.ko);
      await tester.pump();
      expect(engine.spoken, [VoiceCue.ko.text]);
    });
  });

  group('robustness', () {
    test(
      'an engine without a Korean voice is ignored and the service goes on',
      () async {
        build();
        engine.failure = StateError('no voice');
        voice.say(VoiceCue.tooFar);
        await pumpEventQueue();
        expect(voice.isSpeaking, isFalse);
        engine.failure = null;
        voice.say(VoiceCue.ko);
        await pumpEventQueue();
        expect(engine.spoken, [VoiceCue.ko.text]);
      },
    );

    test('a failing stop is ignored', () async {
      build(manual: true);
      voice.say(VoiceCue.fever);
      await pumpEventQueue();
      engine.failure = StateError('gone');
      voice.say(VoiceCue.ko);
      voice.stop();
      await pumpEventQueue();
      expect(voice.isSpeaking, isFalse);
    });

    test(
      'a line the engine never finishes gives way after maxUtterance',
      () async {
        engine = FakeSpeechEngine(manual: true);
        settings = SoundSettings(store: MemorySoundSettingsStore());
        voice = VoiceGuidanceService(
          engine: engine,
          settings: settings,
          maxUtterance: const Duration(milliseconds: 20),
        );
        voice.say(VoiceCue.noPerson);
        await pumpEventQueue();
        voice.say(VoiceCue.tooFar);
        await pumpEventQueue();
        expect(engine.spoken, [VoiceCue.noPerson.text]);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(engine.spoken, [VoiceCue.noPerson.text, VoiceCue.tooFar.text]);
        expect(voice.current, VoiceCue.tooFar);
      },
    );

    test('without a clock the service keeps its own time', () async {
      engine = FakeSpeechEngine();
      settings = SoundSettings(store: MemorySoundSettingsStore());
      voice = VoiceGuidanceService(
        engine: engine,
        settings: settings,
        repeatAfter: Duration.zero,
      );
      voice.say(VoiceCue.tooFar);
      await pumpEventQueue();
      voice.say(VoiceCue.tooFar);
      await pumpEventQueue();
      expect(engine.spoken, [VoiceCue.tooFar.text, VoiceCue.tooFar.text]);
    });

    test('dispose stops, silences, and may be called twice', () async {
      build(manual: true);
      voice.say(VoiceCue.fever);
      await pumpEventQueue();
      voice.dispose();
      expect(engine.stops, 1);
      voice.say(VoiceCue.ko);
      await pumpEventQueue();
      expect(engine.spoken, [VoiceCue.fever.text]);
      voice.dispose();
      settings.setVoiceEnabled(false);
      expect(engine.stops, 1, reason: 'no longer listening to settings');
    });
  });
}
