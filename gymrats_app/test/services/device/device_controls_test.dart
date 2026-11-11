import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/audio/sound_settings.dart';
import 'package:gymrats_app/services/device/device_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The channel MainActivity.kt answers.
  const channel = MethodChannel('gymrats/device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('beeps and keeps the screen on through MainActivity', () async {
    final calls = <(String, Object?)>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add((call.method, call.arguments));
      return null;
    });

    const DeviceRepSound().playRepCounted();
    await keepScreenOn(true);
    await keepScreenOn(false);
    await pumpEventQueue();
    expect(calls, [
      ('beep', null),
      ('keepScreenOn', true),
      ('keepScreenOn', false),
    ]);
  });

  test('a missing native side is ignored', () async {
    await keepScreenOn(true);
    const DeviceRepSound().playRepCounted();
    await pumpEventQueue();
  });

  test('a failing native side is ignored', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'no-audio'),
    );
    await keepScreenOn(true);
    const DeviceRepSound().playRepCounted();
    await pumpEventQueue();
  });

  test('the rep beep follows the sound switch', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    final settings = SoundSettings();
    final sound = DeviceRepSound(settings);

    sound.playRepCounted();
    await settings.setEnabled(false);
    sound.playRepCounted();
    await settings.setEnabled(true);
    sound.playRepCounted();
    await pumpEventQueue();
    expect(calls, ['beep', 'beep']);
  });

  test(
    'the files folder comes from MainActivity, or is null without one',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'filesDir');
        return '/data/user/0/com.gymrats/files';
      });
      expect(await appFilesDirectory(), '/data/user/0/com.gymrats/files');

      messenger.setMockMethodCallHandler(channel, null);
      expect(await appFilesDirectory(), isNull);

      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'no-files'),
      );
      expect(await appFilesDirectory(), isNull);
    },
  );
}
