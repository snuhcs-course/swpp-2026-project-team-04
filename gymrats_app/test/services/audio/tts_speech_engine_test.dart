import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/audio/tts_speech_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The plugin's channel.
  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<(String, Object?)> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add((call.method, call.arguments));
      return 1;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  /// The spoken text, whatever shape the platform branch sends it in.
  String textOf(Object? arguments) =>
      arguments is Map ? arguments['text'] as String : arguments as String;

  test('the first line configures Korean, a normal rate, and awaited '
      'completion, then speaks', () async {
    final engine = TtsSpeechEngine();
    await engine.speak('셋');
    expect(calls.map((c) => c.$1), [
      'setLanguage',
      'setSpeechRate',
      'setPitch',
      'awaitSpeakCompletion',
      'speak',
    ]);
    expect(calls[0].$2, 'ko-KR');
    expect(calls[1].$2, 0.5);
    expect(calls[2].$2, 1.0);
    expect(calls[3].$2, isTrue);
    expect(textOf(calls[4].$2), '셋');
  });

  test('later lines only speak; stop stops', () async {
    final engine = TtsSpeechEngine();
    await engine.speak('셋');
    calls.clear();
    await engine.speak('둘');
    await engine.stop();
    expect(calls.map((c) => c.$1), ['speak', 'stop']);
    expect(textOf(calls[0].$2), '둘');
  });

  test('another language can be chosen', () async {
    await TtsSpeechEngine(language: 'en-US').speak('three');
    expect(calls.first, ('setLanguage', 'en-US'));
  });

  test(
    'a failing engine surfaces the error for the service to ignore',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'no-tts'),
      );
      expect(TtsSpeechEngine().speak('셋'), throwsA(isA<PlatformException>()));
    },
  );

  group('an utterance the plugin never finishes', () {
    /// The native side calling back into the plugin.
    Future<void> platformSends(String method, [Object? arguments]) async {
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );
    }

    late TtsSpeechEngine engine;

    setUp(() {
      engine = TtsSpeechEngine();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add((call.method, call.arguments));
        if (call.method == 'speak') return Completer<Object?>().future;
        return 1;
      });
    });

    for (final callback in ['speak.onError', 'speak.onComplete']) {
      test(
        'ends when the plugin reports $callback after the line started',
        () async {
          var ended = false;
          final speaking = engine.speak('셋').then((_) => ended = true);
          await pumpEventQueue();
          await platformSends(
            callback,
            callback == 'speak.onError' ? 'synthesis' : null,
          );
          await pumpEventQueue();
          expect(
            ended,
            isFalse,
            reason: 'not started yet: it is a stale callback',
          );
          await platformSends('speak.onStart');
          await platformSends(
            callback,
            callback == 'speak.onError' ? 'synthesis' : null,
          );
          await speaking;
          expect(ended, isTrue);
        },
      );
    }

    test('a cancel or completion of the line that was cut off does not end '
        'the line that replaced it', () async {
      final first = engine.speak('카메라 앞에 서 주세요.');
      await pumpEventQueue();
      await platformSends('speak.onStart');
      await engine.stop();
      var secondEnded = false;
      final second = engine.speak('준비 완료!').then((_) => secondEnded = true);
      await pumpEventQueue();
      // The old line's end arrives after the new one was posted.
      await platformSends('speak.onCancel');
      await platformSends('speak.onComplete');
      await pumpEventQueue();
      expect(secondEnded, isFalse);

      await platformSends('speak.onStart');
      await platformSends('speak.onComplete');
      await second;
      expect(secondEnded, isTrue);
      await first.timeout(const Duration(milliseconds: 50), onTimeout: () {});
    });

    test('a callback before any line is harmless', () async {
      await engine
          .speak('셋')
          .timeout(const Duration(milliseconds: 50), onTimeout: () {});
      await platformSends('speak.onComplete');
      await platformSends('speak.onComplete');
    });
  });

  test('a failed first configuration is retried on the next line', () async {
    var failing = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add((call.method, call.arguments));
      if (failing) throw PlatformException(code: 'not-bound');
      return 1;
    });
    final engine = TtsSpeechEngine();
    await expectLater(engine.speak('셋'), throwsA(isA<PlatformException>()));
    failing = false;
    calls.clear();
    await engine.speak('둘');
    expect(calls.map((c) => c.$1), contains('setLanguage'));
    expect(calls.last.$1, 'speak');
  });
}
