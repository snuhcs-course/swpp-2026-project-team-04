import 'dart:async';

import 'package:flutter/services.dart';

/// Answered by MainActivity.kt, so these features need no plugin.
const _channel = MethodChannel('gymrats/device');

/// Plays the sound for a counted rep, which the versus screen's rules
/// promise. Injected so tests can count the sounds.
abstract interface class RepSound {
  void playRepCounted();
}

/// Beeps through MainActivity's ToneGenerator, at the media volume.
class DeviceRepSound implements RepSound {
  const DeviceRepSound();

  @override
  void playRepCounted() => unawaited(_send('beep'));
}

/// Keeps the screen from turning off while [on]. Nobody touches the phone
/// during a battle, so the screen timeout would otherwise stop the camera.
Future<void> keepScreenOn(bool on) => _send('keepScreenOn', on);

/// Calls MainActivity. A missing or failing native side is ignored: neither
/// feature is worth stopping the battle for.
Future<void> _send(String method, [Object? arguments]) async {
  try {
    await _channel.invokeMethod<void>(method, arguments);
  } on MissingPluginException {
    // Tests and other platforms have no native side.
  } on PlatformException {
    // The native side failed; the battle goes on without it.
  }
}
