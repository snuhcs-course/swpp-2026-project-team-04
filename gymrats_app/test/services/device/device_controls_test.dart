import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
