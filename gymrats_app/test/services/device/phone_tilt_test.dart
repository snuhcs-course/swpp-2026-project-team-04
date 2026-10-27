import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';

GravitySample _upright({double gyro = 0}) => GravitySample(
  0,
  9.8,
  0,
  gyroX: gyro,
  gyroY: 0,
  gyroZ: 0,
);

void main() {
  test('flat and vertical gravity', () {
    expect(
      tiltFromFlatDegrees(const GravitySample(0, 0, 9.8)),
      closeTo(0, 0.1),
    );
    expect(
      tiltFromFlatDegrees(const GravitySample(0, 0, -9.8)),
      closeTo(0, 0.1),
    );
    expect(
      tiltFromFlatDegrees(const GravitySample(0, 9.8, 0)),
      closeTo(90, 0.1),
    );
  });

  test('ready only after the phone stays propped and still', () {
    var now = Duration.zero;
    final samples = StreamController<GravitySample>(sync: true);
    addTearDown(samples.close);
    final tilt = PhoneTiltMonitor(samples: samples.stream, clock: () => now);
    tilt.retain();

    samples.add(_upright());
    now = const Duration(milliseconds: 100);
    samples.add(_upright());
    expect(tilt.isPropped, isFalse);
    expect(tilt.isStill, isFalse);

    now = const Duration(milliseconds: 500);
    samples.add(_upright());
    expect(tilt.isPlaced, isTrue);

    now = const Duration(milliseconds: 600);
    samples.add(const GravitySample(0, 0, 9.8, gyroX: 0, gyroY: 0, gyroZ: 0));
    expect(tilt.isPropped, isTrue);
    now = const Duration(milliseconds: 1100);
    samples.add(const GravitySample(0, 0, 9.8, gyroX: 0, gyroY: 0, gyroZ: 0));
    expect(tilt.isPropped, isFalse);
    tilt.release();
  });

  test('a gyro reading is required before the phone counts as still', () {
    var now = Duration.zero;
    final samples = StreamController<GravitySample>(sync: true);
    addTearDown(samples.close);
    final tilt = PhoneTiltMonitor(samples: samples.stream, clock: () => now);
    tilt.retain();

    samples.add(const GravitySample(0, 9.8, 0));
    now = const Duration(milliseconds: 500);
    samples.add(const GravitySample(0, 9.8, 0));
    expect(tilt.isPropped, isTrue);
    expect(tilt.isStill, isFalse);
    tilt.release();
  });

  test('the latest raw sample is kept for the screen-plane roll', () {
    final samples = StreamController<GravitySample>(sync: true);
    addTearDown(samples.close);
    final tilt = PhoneTiltMonitor(samples: samples.stream);
    expect(tilt.lastSample, isNull);
    tilt.retain();

    samples.add(_upright());
    const rolled = GravitySample(2.5, 9.4, 0.3);
    samples.add(rolled);
    expect(tilt.lastSample, same(rolled));
    tilt.release();
  });

  test('lean or shake after the start is disturbed', () {
    var now = Duration.zero;
    final samples = StreamController<GravitySample>(sync: true);
    addTearDown(samples.close);
    final tilt = PhoneTiltMonitor(samples: samples.stream, clock: () => now);
    tilt.retain();

    now = const Duration(milliseconds: 500);
    samples.add(_upright());
    tilt.lock();
    expect(tilt.isDisturbed, isFalse);

    now = const Duration(milliseconds: 600);
    samples.add(_upright(gyro: 2));
    expect(tilt.isDisturbed, isFalse);
    now = const Duration(milliseconds: 1100);
    samples.add(_upright(gyro: 2));
    expect(tilt.isDisturbed, isTrue);

    now = const Duration(milliseconds: 1200);
    samples.add(_upright());
    expect(tilt.isDisturbed, isTrue);
    now = const Duration(milliseconds: 1700);
    samples.add(_upright());
    expect(tilt.isDisturbed, isFalse);

    now = const Duration(milliseconds: 1800);
    samples.add(const GravitySample(0, 0, 9.8, gyroX: 0, gyroY: 0, gyroZ: 0));
    now = const Duration(milliseconds: 2300);
    samples.add(const GravitySample(0, 0, 9.8, gyroX: 0, gyroY: 0, gyroZ: 0));
    expect(tilt.isDisturbed, isTrue);
    tilt.release();
  });

  test('the round keeps the gravity stream after setup lets go', () async {
    var listeners = 0;
    final samples = StreamController<GravitySample>.broadcast(
      sync: true,
      onListen: () {
        listeners++;
        if (listeners > 1) throw StateError('two gravity listeners');
      },
      onCancel: () => listeners--,
    );
    addTearDown(samples.close);
    PhoneTiltMonitor.debugUsePlatformStream(samples.stream);
    addTearDown(() => PhoneTiltMonitor.debugUsePlatformStream(null));

    final setup = PhoneTiltMonitor.platform();
    final round = PhoneTiltMonitor.platform();
    expect(identical(setup, round), isTrue);

    setup.retain();
    samples.add(_upright());
    expect(setup.tiltDegrees, closeTo(90, 0.1));
    setup.release();
    round.retain();
    await pumpEventQueue();
    samples.add(_upright(gyro: 0.1));
    expect(round.tiltDegrees, closeTo(90, 0.1));
    expect(round.gyroSpeed, closeTo(0.1, 0.001));
    expect(listeners, 1);
    round.release();
    await pumpEventQueue();
    expect(listeners, 0);
  });

  test('a moved phone does not count the rep', () {
    const counted = RepEvent(index: 1, valid: true, at: Duration(seconds: 3));
    final rejected = rejectIfPhoneMoved(counted, phoneMoved: true);
    expect(rejected.valid, isFalse);
    expect(rejected.reason, RejectReason.phoneMoved);
    expect(rejectIfPhoneMoved(counted, phoneMoved: false).valid, isTrue);
  });
}
