import 'dart:async';

import 'package:gymrats_app/services/device/phone_tilt.dart';

/// A phone the setup gate already accepts. No sensor events, so a test
/// that is not about placement stays on the pose checks.
PhoneTiltMonitor placedPhone() {
  final tilt = PhoneTiltMonitor(samples: const Stream.empty());
  tilt.isPropped = true;
  tilt.isStill = true;
  return tilt;
}
