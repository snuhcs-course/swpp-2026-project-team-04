import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
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

  test('the round ends when 60 seconds have passed', () async {
    await vm.start();
    await countOneRep();
    await feed(59999, pose());
    expect(vm.state.phase, CounterPhase.running);
    await feed(60000, pose());
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
