import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/squat_demo_judge.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';

import '../support/fakes.dart';
import '../support/pose_fixtures.dart';

void main() {
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late Duration now;
  late RepCounterViewModel vm;
  late List<RepEvent> events;

  const fast = RepJudgeConfig(smoothingTau: Duration.zero);

  setUp(() {
    camera = FakeCameraService();
    estimator = FakePoseEstimator();
    now = Duration.zero;
    events = [];
    vm = RepCounterViewModel(
      camera: camera,
      estimator: estimator,
      clock: () => now,
      phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
      judge: RepJudge(config: fast, clock: () => now),
    );
    vm.reps.listen(events.add);
  });

  tearDown(() => vm.dispose());

  Future<void> feed(int ms, PoseFrame? frame) async {
    now = Duration(milliseconds: ms);
    estimator.frames.add(frame);
    camera.emit();
    await pumpEventQueue();
  }

  PoseFrame pose({double depth = 0}) => pushUpFrame(depth: depth);

  Future<void> countOneRep() async {
    await feed(0, pose());
    await feed(300, pose());
    await feed(400, pose(depth: 0.6));
    await feed(800, pose(depth: 1.5));
    await feed(1200, pose());
  }

  test('a judged rep updates the counts and the stream', () async {
    await vm.start();
    await countOneRep();
    expect(vm.state.validReps, 1);
    expect(vm.state.invalidReps, 0);
    expect(events, hasLength(1));
    expect(events.single.valid, isTrue);
    expect(vm.state.snapshot.phase, RepPhase.up);
  });

  test('squat demo counts despite a disturbed phone sensor', () async {
    final demoCamera = FakeCameraService();
    final demoEstimator = FakePoseEstimator();
    final tilt = PhoneTiltMonitor(samples: const Stream.empty());
    var demoNow = Duration.zero;
    final demo = RepCounterViewModel(
      camera: demoCamera,
      estimator: demoEstimator,
      clock: () => demoNow,
      phoneTilt: tilt,
      judge: SquatDemoJudge(clock: () => demoNow),
    );
    addTearDown(demo.dispose);
    await demo.start();
    tilt.isDisturbed = true;
    for (final frame in [
      standingFrame(showHips: true),
      standingFrame(
        showHips: true,
        move: {
          BodyLandmark.leftHip: (530, 670),
          BodyLandmark.rightHip: (470, 670),
        },
      ),
      standingFrame(showHips: true),
    ]) {
      demoNow += const Duration(milliseconds: 100);
      demoEstimator.frames.add(frame);
      demoCamera.emit();
      await pumpEventQueue();
    }
    expect(demo.state.validReps, 1);
    expect(demo.state.invalidReps, 0);
  });

  test('a shallow rep is counted as invalid', () async {
    await vm.start();
    await feed(0, pose());
    await feed(300, pose());
    await feed(400, pose(depth: 0.9));
    await feed(800, pose());
    expect(vm.state.validReps, 0);
    expect(vm.state.invalidReps, 1);
    expect(events.single.reason, RejectReason.insufficientDepth);
  });

  test('form samples are taken at most every 100 ms of the round', () async {
    await vm.start();
    for (var ms = 0; ms <= 500; ms += 33) {
      await feed(ms, pose());
    }
    final times = [for (final s in vm.formSamples) s.at.inMilliseconds];
    expect(times, [0, 132, 264, 396]);
    expect(vm.formSamples.first.leftElbow, isNotNull);
    expect(vm.formSamples.first.rightElbow, isNotNull);
    expect(vm.formSamples.first.hipAngle, isNull);
  });

  test('rep records carry the time into the round', () async {
    await vm.start();
    await countOneRep();
    expect(vm.repRecords.single.at, const Duration(milliseconds: 1200));
    expect(vm.repRecords.single.valid, isTrue);
  });

  test('a new round clears the samples and the rep records', () async {
    await vm.start();
    await countOneRep();
    vm.reset();
    expect(vm.formSamples, isEmpty);
    expect(vm.repRecords, isEmpty);
  });

  test('reset clears the counts and the judge', () async {
    await vm.start();
    await countOneRep();
    vm.reset();
    expect(vm.state.validReps, 0);
    expect(vm.state.invalidReps, 0);
    expect(vm.state.lastEvent, isNull);
    expect(vm.state.snapshot.phase, RepPhase.idle);
    await feed(2000, pose());
    await feed(2300, pose());
    await feed(2400, pose(depth: 0.6));
    await feed(2800, pose(depth: 1.5));
    await feed(3200, pose());
    expect(vm.state.validReps, 1);
    expect(events.last.index, 1);
  });

  test('online reset restarts feedback clock after preparation', () async {
    await vm.start();
    await feed(10000, pose());
    vm.reset(restartClock: true);
    await feed(10100, pose());
    expect(vm.formSamples.single.at, const Duration(milliseconds: 100));
    expect(vm.state.remaining, const Duration(milliseconds: 29900));
  });

  test('pause releases the camera and resume starts it again', () async {
    await vm.start();
    expect(vm.state.phase, CounterPhase.running);
    await vm.pause();
    expect(vm.state.phase, CounterPhase.paused);
    expect(camera.isStreaming, isFalse);
    await vm.resume();
    expect(vm.state.phase, CounterPhase.running);
    expect(camera.isStreaming, isTrue);
  });

  test('rotating reopens the camera and keeps the score', () async {
    await vm.start();
    await countOneRep();
    await feed(1500, pose(depth: 0.6));
    expect(vm.state.snapshot.phase, RepPhase.descending);
    await vm.onScreenRotated();
    expect(camera.startCount, 2);
    expect(vm.state.phase, CounterPhase.running);
    expect(vm.state.validReps, 1);
    expect(vm.state.snapshot.phase, RepPhase.idle);
  });

  test('reopening the camera does not forgive a leaned phone', () async {
    final samples = StreamController<GravitySample>(sync: true);
    addTearDown(samples.close);
    final tilt = PhoneTiltMonitor(samples: samples.stream, clock: () => now);
    final leanedCamera = FakeCameraService();
    final leanedEstimator = FakePoseEstimator();
    final leaned = RepCounterViewModel(
      camera: leanedCamera,
      estimator: leanedEstimator,
      clock: () => now,
      phoneTilt: tilt,
      judge: RepJudge(config: fast, clock: () => now),
    );
    addTearDown(leaned.dispose);
    final leanedEvents = <RepEvent>[];
    leaned.reps.listen(leanedEvents.add);

    Future<void> feed(int ms, PoseFrame? frame) async {
      now = Duration(milliseconds: ms);
      leanedEstimator.frames.add(frame);
      leanedCamera.emit();
      await pumpEventQueue();
    }

    const held = GravitySample(0, 9.8, 0, gyroX: 0, gyroY: 0, gyroZ: 0);
    // About 20° off the upright lock. Past the 10° band.
    const leanedPhone = GravitySample(
      0,
      9.2,
      3.35,
      gyroX: 0,
      gyroY: 0,
      gyroZ: 0,
    );

    await leaned.start();
    now = const Duration(milliseconds: 500);
    samples.add(held);
    now = const Duration(milliseconds: 600);
    samples.add(leanedPhone);
    now = const Duration(milliseconds: 1100);
    samples.add(leanedPhone);
    expect(tilt.isDisturbed, isTrue);

    await leaned.onScreenRotated();
    expect(tilt.isDisturbed, isTrue);

    await feed(1200, pose());
    await feed(1500, pose());
    await feed(1600, pose(depth: 0.6));
    await feed(2000, pose(depth: 1.5));
    await feed(2400, pose());
    expect(leanedEvents.single.reason, RejectReason.phoneMoved);
    expect(leaned.state.validReps, 0);
  });

  test('rotating while paused does not open the camera', () async {
    await vm.start();
    await vm.pause();
    await vm.onScreenRotated();
    expect(camera.startCount, 1);
    expect(camera.isStreaming, isFalse);
  });

  test('denied permission keeps the camera off', () async {
    camera.permission = CameraPermission.denied;
    await vm.start();
    expect(vm.state.phase, CounterPhase.permissionDenied);
    expect(camera.startCount, 0);
  });

  test('3 s of detector failures stops the camera', () async {
    await vm.start();
    await feed(0, null);
    await feed(2900, null);
    expect(vm.state.phase, CounterPhase.running);
    await feed(3000, null);
    expect(vm.state.phase, CounterPhase.detectorError);
    expect(camera.isStreaming, isFalse);
    await vm.retry();
    expect(vm.state.phase, CounterPhase.running);
  });

  test('finish keeps the counts and releases the camera', () async {
    await vm.start();
    await countOneRep();
    await vm.finish(stoppedByUser: true);
    expect(vm.state.phase, CounterPhase.finished);
    expect(vm.state.roundEnd, RoundEnd.stopped);
    expect(vm.state.validReps, 1);
    expect(vm.history, hasLength(1));
    expect(camera.isStreaming, isFalse);
    await feed(2000, pose());
    expect(vm.state.validReps, 1);
    await vm.resume();
    expect(vm.state.phase, CounterPhase.finished);
  });

  test('the round ends when 30 seconds have passed', () async {
    await vm.start();
    await countOneRep();
    await feed(29999, pose());
    expect(vm.state.phase, CounterPhase.running);
    await feed(30000, pose());
    expect(vm.state.phase, CounterPhase.finished);
    expect(vm.state.roundEnd, RoundEnd.timeUp);
    expect(vm.state.remaining, Duration.zero);
    expect(vm.state.validReps, 1);
    expect(camera.isStreaming, isFalse);
  });

  test('time spent in the background does not count', () async {
    await vm.start();
    await countOneRep();
    await vm.pause();
    now = const Duration(seconds: 90);
    await vm.resume();
    expect(vm.state.phase, CounterPhase.running);
    expect(vm.state.validReps, 1);
    await feed(91000, pose());
    expect(vm.state.phase, CounterPhase.running);
  });

  test('a short detector failure drops the attempt in progress', () async {
    await vm.start();
    await feed(0, pose());
    await feed(300, pose());
    await feed(400, pose(depth: 0.6));
    expect(vm.state.snapshot.phase, RepPhase.descending);
    await feed(500, null);
    await feed(1000, null);
    expect(vm.state.snapshot.phase, RepPhase.lost);
    expect(vm.state.validReps, 0);
  });
}
