// AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/pose_frame.dart';
import '../../models/rep_event.dart';
import '../pose/pose_metrics.dart';

const _gravityChannel = EventChannel('gymrats/gravity');

/// Degrees from lying flat. The phone is propped, ready to film, at or above
/// this. Flat on the table is 0°. Standing straight up is 90°.
const placementTiltDegrees = 60.0;

/// How long a placement condition must hold before it flips.
const placementHold = Duration(milliseconds: 400);

/// Gyro speed, in rad/s, under which the phone counts as sitting still.
/// A phone left alone is near 0. Holding it in the hand is well above this.
const stillGyroRadPerSec = 0.4;

/// Gyro speed, in rad/s, that drops a rep once the round has started.
/// Higher than [stillGyroRadPerSec] so a push-up shaking the floor does not
/// erase a rep that was fine to start.
const shakeGyroRadPerSec = 1.2;

/// How far the phone may rock, in degrees, from the angle locked when the
/// round started. Past this, the rep is not counted.
const angleDriftDegrees = 10.0;

/// One motion sample. Android's axes: x right, y toward the top of the
/// phone, z out of the screen. Gyro is rad/s and is null until the gyro
/// sensor has reported.
class GravitySample {
  const GravitySample(
    this.x,
    this.y,
    this.z, {
    this.gyroX,
    this.gyroY,
    this.gyroZ,
  });

  final double x;
  final double y;
  final double z;
  final double? gyroX;
  final double? gyroY;
  final double? gyroZ;

  bool get hasGyro => gyroX != null && gyroY != null && gyroZ != null;

  double get gyroSpeed {
    if (!hasGyro) return 0;
    return math.sqrt(gyroX! * gyroX! + gyroY! * gyroY! + gyroZ! * gyroZ!);
  }
}

/// Angle between the screen and the floor.
///
/// A gyroscope only reports how fast the phone is turning. Sitting still on
/// the floor and sitting still on a wall are both zero, so the angle comes
/// from gravity. Flat, screen up or down, is 0°. Standing straight up is 90°.
double tiltFromFlatDegrees(GravitySample sample) {
  final g = math.sqrt(
    sample.x * sample.x + sample.y * sample.y + sample.z * sample.z,
  );
  if (g < 1) return 0;
  final cos = (sample.z.abs() / g).clamp(0.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

/// Latest phone placement.
///
/// [isPropped] is the phone at or above [placementTiltDegrees]. [isStill] is
/// the gyro under [stillGyroRadPerSec]. Both must hold for [placementHold].
/// [lock] remembers the angle at the start of a round. After that,
/// [isDisturbed] is a lean past [angleDriftDegrees] or a gyro past
/// [shakeGyroRadPerSec], again for [placementHold].
class PhoneTiltMonitor {
  PhoneTiltMonitor({Stream<GravitySample>? samples, Duration Function()? clock})
    : _samples = samples,
      _clock = clock ?? _sinceStart();

  /// The platform gravity stream. Missing on tests and desktop.
  factory PhoneTiltMonitor.platform() => PhoneTiltMonitor(samples: _platform());

  final Stream<GravitySample>? _samples;
  final Duration Function() _clock;

  StreamSubscription<GravitySample>? _sub;
  int _users = 0;
  bool _listenFailed = false;

  double? tiltDegrees;
  double? gyroSpeed;
  bool isPropped = false;
  bool isStill = false;
  bool isDisturbed = false;

  bool _locked = false;
  double? _lockedTilt;
  Duration? _proppedSince;
  Duration? _flatSince;
  Duration? _stillSince;
  Duration? _movingSince;
  Duration? _movedSince;
  Duration? _steadySince;

  bool get isPlaced => isPropped && isStill;

  static Duration Function() _sinceStart() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  static Stream<GravitySample> _platform() {
    return _gravityChannel.receiveBroadcastStream().map((event) {
      final list = event as List;
      final hasGyro = list.length >= 6;
      return GravitySample(
        (list[0] as num).toDouble(),
        (list[1] as num).toDouble(),
        (list[2] as num).toDouble(),
        gyroX: hasGyro ? (list[3] as num).toDouble() : null,
        gyroY: hasGyro ? (list[4] as num).toDouble() : null,
        gyroZ: hasGyro ? (list[5] as num).toDouble() : null,
      );
    });
  }

  void retain() {
    _users++;
    final samples = _samples;
    if (_sub != null || _listenFailed || samples == null) return;
    try {
      _sub = samples.listen(_onSample, onError: (_) {});
    } on MissingPluginException {
      _listenFailed = true;
    } on PlatformException {
      _listenFailed = true;
    }
  }

  void release() {
    if (_users == 0) return;
    _users--;
    if (_users > 0) return;
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /// Remembers the current angle. Later lean or shake sets [isDisturbed].
  void lock() {
    _locked = true;
    _lockedTilt = tiltDegrees;
    isDisturbed = false;
    _movedSince = null;
    _steadySince = null;
  }

  void _onSample(GravitySample sample) {
    final tilt = tiltFromFlatDegrees(sample);
    tiltDegrees = tilt;
    gyroSpeed = sample.hasGyro ? sample.gyroSpeed : null;
    final now = _clock();
    if (_locked && _lockedTilt == null) _lockedTilt = tilt;

    _hold(
      active: tilt >= placementTiltDegrees,
      now: now,
      flag: isPropped,
      setFlag: (value) => isPropped = value,
      onSince: _proppedSince,
      setOnSince: (value) => _proppedSince = value,
      offSince: _flatSince,
      setOffSince: (value) => _flatSince = value,
    );
    _hold(
      active: sample.hasGyro && sample.gyroSpeed < stillGyroRadPerSec,
      now: now,
      flag: isStill,
      setFlag: (value) => isStill = value,
      onSince: _stillSince,
      setOnSince: (value) => _stillSince = value,
      offSince: _movingSince,
      setOffSince: (value) => _movingSince = value,
    );
    if (!_locked || _lockedTilt == null) return;
    final drifted = (tilt - _lockedTilt!).abs() >= angleDriftDegrees;
    final shaking = sample.hasGyro && sample.gyroSpeed >= shakeGyroRadPerSec;
    _hold(
      active: drifted || shaking,
      now: now,
      flag: isDisturbed,
      setFlag: (value) => isDisturbed = value,
      onSince: _movedSince,
      setOnSince: (value) => _movedSince = value,
      offSince: _steadySince,
      setOffSince: (value) => _steadySince = value,
    );
  }

  void _hold({
    required bool active,
    required Duration now,
    required bool flag,
    required void Function(bool value) setFlag,
    required Duration? onSince,
    required void Function(Duration? value) setOnSince,
    required Duration? offSince,
    required void Function(Duration? value) setOffSince,
  }) {
    if (active) {
      setOffSince(null);
      final since = onSince ?? now;
      if (onSince == null) setOnSince(now);
      if (!flag && now - since >= placementHold) setFlag(true);
    } else {
      setOnSince(null);
      final since = offSince ?? now;
      if (offSince == null) setOffSince(now);
      if (flag && now - since >= placementHold) setFlag(false);
    }
  }
}

/// A finished rep while the phone has leaned or shaken is not counted.
RepEvent rejectIfPhoneMoved(RepEvent event, {required bool phoneMoved}) {
  if (!phoneMoved || !event.valid) return event;
  return RepEvent(
    index: event.index,
    valid: false,
    at: event.at,
    reason: RejectReason.phoneMoved,
    maxDepth: event.maxDepth,
    minElbowAngle: event.minElbowAngle,
    maxTilt: event.maxTilt,
    descent: event.descent,
  );
}

DateTime _lastPoseLog = DateTime.fromMillisecondsSinceEpoch(0);

/// One line every 250ms for `adb logcat`. Debug builds only.
void logPoseLive(
  String screen,
  PoseFrame frame, {
  double? depth,
  PhoneTiltMonitor? tilt,
}) {
  if (!kDebugMode) return;
  final now = DateTime.now();
  if (now.difference(_lastPoseLog) < const Duration(milliseconds: 250)) {
    return;
  }
  _lastPoseLog = now;
  final metrics = measurePose(frame);
  String n(double? value) => value == null ? '-' : value.toStringAsFixed(2);
  debugPrint(
    'pose_live screen=$screen depth=${n(depth)} '
    'elbow=${n(metrics.elbowAngle)} hipAngle=${n(metrics.hipAngle)} '
    'torso=${n(metrics.torsoDrop)} hipGap=${n(metrics.hipHandGap)} '
    'kneeGap=${n(metrics.kneeHandGap)} tilt=${n(tilt?.tiltDegrees)} '
    'gyro=${n(tilt?.gyroSpeed)} propped=${tilt?.isPropped ?? false} '
    'still=${tilt?.isStill ?? false} moved=${tilt?.isDisturbed ?? false}',
  );
}
