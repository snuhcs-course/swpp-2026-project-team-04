import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';

import '../support/fakes.dart';
import '../support/pose_fixtures.dart';

void main() {
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late Duration now;
  late SetupViewModel vm;

  setUp(() {
    camera = FakeCameraService();
    estimator = FakePoseEstimator();
    now = Duration.zero;
    vm = SetupViewModel(
      exercise: ExerciseType.pushUp,
      camera: camera,
      estimator: estimator,
      clock: () => now,
    );
  });

  /// Feeds [frame] (null = ML Kit error) at [ms] milliseconds.
  Future<void> feed(int ms, PoseFrame? frame) async {
    now = Duration(milliseconds: ms);
    estimator.frames.add(frame);
    camera.emit();
    await pumpEventQueue();
  }

  test('starts the camera when permission is granted', () async {
    await vm.start();
    expect(vm.state.phase, SetupPhase.running);
    expect(camera.isStreaming, isTrue);
    expect(vm.state.canStart, isFalse);
  });

  group('permission', () {
    test(
      'denied shows the permission state and keeps the camera off',
      () async {
        camera.permission = CameraPermission.denied;
        await vm.start();
        expect(vm.state.phase, SetupPhase.permissionDenied);
        expect(vm.state.permanentlyDenied, isFalse);
        expect(camera.startCount, 0);
      },
    );

    test('permanently denied is reported', () async {
      camera.permission = CameraPermission.permanentlyDenied;
      await vm.start();
      expect(vm.state.phase, SetupPhase.permissionDenied);
      expect(vm.state.permanentlyDenied, isTrue);
    });

    test('open settings, then coming back retries', () async {
      camera.permission = CameraPermission.permanentlyDenied;
      await vm.start();
      await vm.openSettings();
      expect(camera.settingsCount, 1);
      await vm.pause();
      camera.permission = CameraPermission.granted;
      await vm.resume();
      expect(vm.state.phase, SetupPhase.running);
    });

    test('resume without a real pause does not ask again', () async {
      camera.permission = CameraPermission.denied;
      await vm.start();
      await vm.resume();
      expect(camera.startCount, 0);
      expect(vm.state.phase, SetupPhase.permissionDenied);
    });
  });

  test('camera failure shows an error and retry recovers', () async {
    camera.startError = const CameraUnavailableException('No camera found.');
    await vm.start();
    expect(vm.state.phase, SetupPhase.cameraError);
    expect(vm.state.errorMessage, 'No camera found.');
    camera.startError = null;
    await vm.retry();
    expect(vm.state.phase, SetupPhase.running);
  });

  group('frames', () {
    setUp(() => vm.start());

    test('no person', () async {
      await feed(0, emptyFrame());
      expect(vm.state.status.reason, SetupReason.noPerson);
      expect(
        vm.state.status.message,
        'No one detected. Step into the camera view.',
      );
      expect(vm.state.lastFrame, isNotNull);
    });

    test('hands missing keeps Start disabled', () async {
      final frame = standingFrame(
        move: {for (final l in handLandmarks) l: (500, 995)},
      );
      await feed(0, frame);
      await feed(2000, frame);
      expect(vm.state.status.message, 'Hands not visible.');
      expect(vm.state.canStart, isFalse);
    });

    test('not facing the camera keeps Start disabled', () async {
      final frame = standingFrame(hide: faceLandmarks);
      await feed(0, frame);
      await feed(2000, frame);
      expect(vm.state.status.reason, SetupReason.notFacingForward);
      expect(vm.state.status.message, 'Face the camera.');
      expect(vm.state.canStart, isFalse);
    });

    test('Ready after 1.5 s, one bad frame keeps it, 0.5 s drops it', () async {
      await feed(0, standingFrame());
      await feed(1000, standingFrame());
      expect(vm.state.canStart, isFalse);
      await feed(1500, standingFrame());
      expect(vm.state.canStart, isTrue);
      await feed(1600, emptyFrame());
      expect(vm.state.canStart, isTrue);
      await feed(2100, emptyFrame());
      expect(vm.state.canStart, isFalse);
    });

    test('processed FPS counts frames in the last second', () async {
      for (var i = 0; i < 10; i++) {
        await feed(i * 100, emptyFrame());
      }
      expect(vm.state.fps, 10);
      await feed(2000, emptyFrame());
      expect(vm.state.fps, 1);
    });
  });

  group('screen rotation', () {
    test('reopens the running camera and restarts the hold', () async {
      await vm.start();
      await feed(0, standingFrame());
      await feed(1500, standingFrame());
      expect(vm.state.status.isReady, isTrue);
      await vm.onScreenRotated();
      expect(camera.startCount, 2);
      expect(vm.state.phase, SetupPhase.running);
      expect(vm.state.status.isReady, isFalse);
    });

    test('does not open the camera when permission was denied', () async {
      camera.permission = CameraPermission.denied;
      await vm.start();
      await vm.onScreenRotated();
      expect(camera.startCount, 0);
      expect(vm.state.phase, SetupPhase.permissionDenied);
    });
  });

  group('auto start', () {
    setUp(() => vm.start());

    test('counts down after Ready and finishes after 3 s', () async {
      await feed(0, standingFrame());
      await feed(1500, standingFrame());
      expect(vm.state.status.isReady, isTrue);
      expect(vm.state.autoStartIn, const Duration(seconds: 3));
      expect(vm.state.message, 'Ready! Starting in 3...');
      await feed(3600, standingFrame());
      expect(vm.state.message, 'Ready! Starting in 1...');
      expect(vm.state.autoStarted, isFalse);
      await feed(4500, standingFrame());
      expect(vm.state.autoStarted, isTrue);
      expect(vm.state.autoStartIn, isNull);
    });

    test('auto start stays set once reached', () async {
      await feed(0, standingFrame());
      await feed(1500, standingFrame());
      await feed(4500, standingFrame());
      await feed(4600, emptyFrame());
      expect(vm.state.autoStarted, isTrue);
    });

    test('losing Ready cancels and restarts the countdown', () async {
      await feed(0, standingFrame());
      await feed(1500, standingFrame());
      await feed(3000, standingFrame());
      // 0.5 s of invalid frames drops Ready.
      await feed(3100, emptyFrame());
      await feed(3600, emptyFrame());
      expect(vm.state.status.isReady, isFalse);
      expect(vm.state.autoStartIn, isNull);
      // Ready again needs 1.5 s, then a full new 3 s countdown.
      await feed(3700, standingFrame());
      await feed(5200, standingFrame());
      expect(vm.state.autoStartIn, const Duration(seconds: 3));
      await feed(8100, standingFrame());
      expect(vm.state.autoStarted, isFalse);
      await feed(8200, standingFrame());
      expect(vm.state.autoStarted, isTrue);
    });

    test('one bad frame does not stop the countdown', () async {
      await feed(0, standingFrame());
      await feed(1500, standingFrame());
      await feed(2000, emptyFrame());
      expect(vm.state.autoStartIn, const Duration(milliseconds: 2500));
      await feed(4500, standingFrame());
      expect(vm.state.autoStarted, isTrue);
    });

    test('pause and resume restart the hold and the countdown', () async {
      await feed(0, standingFrame());
      await feed(1500, standingFrame());
      await feed(3000, standingFrame());
      expect(vm.state.autoStartIn, isNotNull);
      await vm.pause();
      await vm.resume();
      expect(vm.state.autoStartIn, isNull);
      await feed(3100, standingFrame());
      expect(vm.state.status.isReady, isFalse);
      await feed(4600, standingFrame());
      expect(vm.state.autoStartIn, const Duration(seconds: 3));
      await feed(7500, standingFrame());
      expect(vm.state.autoStarted, isFalse);
      await feed(7600, standingFrame());
      expect(vm.state.autoStarted, isTrue);
    });

    test('0.5 s of detector failures cancels the countdown', () async {
      await feed(0, standingFrame());
      await feed(1500, standingFrame());
      await feed(2000, standingFrame());
      await feed(2100, null);
      await feed(2600, null);
      expect(vm.state.status.isReady, isFalse);
      expect(vm.state.autoStartIn, isNull);
      // Detection recovers: a fresh 1.5 s hold, then a fresh 3 s countdown.
      await feed(2700, standingFrame());
      await feed(4200, standingFrame());
      expect(vm.state.autoStartIn, const Duration(seconds: 3));
      await feed(7100, standingFrame());
      expect(vm.state.autoStarted, isFalse);
    });

    test('custom auto start delay is used', () async {
      final custom = SetupViewModel(
        exercise: ExerciseType.pushUp,
        config: const SetupConfig(autoStartDelay: Duration(seconds: 1)),
        camera: camera,
        estimator: estimator,
        clock: () => now,
      );
      await custom.start();
      await feed(0, standingFrame());
      await feed(1500, standingFrame());
      await feed(2500, standingFrame());
      expect(custom.state.autoStarted, isTrue);
      custom.dispose();
    });
  });

  group('detector failures', () {
    setUp(() => vm.start());

    test('a failed frame is skipped and detection continues', () async {
      await feed(0, null);
      await feed(100, emptyFrame());
      expect(vm.state.phase, SetupPhase.running);
      expect(vm.state.status.reason, SetupReason.noPerson);
    });

    test('3 s of failures shows an error and stops the camera', () async {
      await feed(0, null);
      await feed(2900, null);
      expect(vm.state.phase, SetupPhase.running);
      await feed(3000, null);
      expect(vm.state.phase, SetupPhase.detectorError);
      expect(camera.isStreaming, isFalse);
      await vm.retry();
      expect(vm.state.phase, SetupPhase.running);
    });

    test('a success resets the failure timer', () async {
      await feed(0, null);
      await feed(2000, emptyFrame());
      await feed(2100, null);
      await feed(4000, null);
      expect(vm.state.phase, SetupPhase.running);
    });

    test('failures for the drop delay restart the hold timer', () async {
      await feed(0, standingFrame());
      await feed(100, null);
      await feed(1400, null);
      expect(vm.state.status.readyProgress, 0);
      await feed(1500, standingFrame());
      expect(vm.state.canStart, isFalse);
    });

    test('frames are dropped while ML Kit is busy', () async {
      estimator.gate = Completer();
      estimator.frames.add(emptyFrame());
      camera.emit();
      camera.emit();
      camera.emit();
      await pumpEventQueue();
      expect(estimator.processCount, 1);
      estimator.gate!.complete();
      await pumpEventQueue();
      expect(vm.state.lastFrame, isNotNull);
    });

    test('failures for the drop delay clear Ready', () async {
      await feed(0, standingFrame());
      await feed(1500, standingFrame());
      expect(vm.state.canStart, isTrue);
      await feed(1600, null);
      expect(vm.state.canStart, isTrue);
      await feed(2100, null);
      expect(vm.state.canStart, isFalse);
    });
  });

  group('lifecycle', () {
    test('pause releases the camera and ignores late frames', () async {
      await vm.start();
      final onImage = camera.onImage!;
      await vm.pause();
      expect(camera.stopCount, 1);
      expect(vm.state.phase, SetupPhase.paused);
      estimator.frames.add(emptyFrame());
      onImage(fakeCameraImage());
      await pumpEventQueue();
      expect(vm.state.lastFrame, isNull);
    });

    test('resume while the camera is still stopping restarts it', () async {
      await vm.start();
      camera.stopGate = Completer();
      final pausing = vm.pause();
      final resuming = vm.resume();
      camera.stopGate!.complete();
      await pausing;
      await resuming;
      await pumpEventQueue();
      expect(vm.state.phase, SetupPhase.running);
      expect(camera.isStreaming, isTrue);
    });

    test(
      'pause and resume while the camera is opening keep it running',
      () async {
        camera.startGate = Completer();
        final starting = vm.start();
        await pumpEventQueue();
        final pausing = vm.pause();
        final resuming = vm.resume();
        camera.startGate!.complete();
        await starting;
        await pausing;
        await resuming;
        await pumpEventQueue();
        expect(vm.state.phase, SetupPhase.running);
        expect(camera.isStreaming, isTrue);
      },
    );

    test('resume restarts the camera and clears Ready', () async {
      await vm.start();
      await feed(0, standingFrame());
      await feed(1500, standingFrame());
      await vm.pause();
      await vm.resume();
      expect(vm.state.phase, SetupPhase.running);
      expect(camera.startCount, 2);
      expect(vm.state.canStart, isFalse);
    });

    test('switch camera restarts with the next camera', () async {
      await vm.start();
      await vm.switchCamera();
      expect(camera.switchCount, 1);
      expect(camera.startCount, 2);
      expect(vm.state.phase, SetupPhase.running);
    });

    test('dispose stops the stream and closes the detector', () async {
      await vm.start();
      final onImage = camera.onImage!;
      vm.dispose();
      await pumpEventQueue();
      expect(camera.isStreaming, isFalse);
      expect(estimator.closed, isTrue);
      // A frame already in flight must not touch the disposed view model.
      onImage(fakeCameraImage());
      await pumpEventQueue();
      expect(estimator.processCount, 0);
    });

    test('dispose while starting does not leave the camera running', () async {
      final starting = vm.start();
      vm.dispose();
      await starting;
      expect(camera.isStreaming, isFalse);
    });
  });
}
