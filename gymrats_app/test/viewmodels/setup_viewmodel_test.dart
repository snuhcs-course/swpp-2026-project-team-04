import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/viewmodels/setup_viewmodel.dart';

import '../support/fakes.dart';
import '../support/placed_phone.dart';
import '../support/pose_fixtures.dart';

void main() {
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late Duration now;
  late SetupViewModel vm;
  late bool guideMatches;
  late PhoneTiltMonitor phone;
  late bool disposed;

  setUp(() {
    camera = FakeCameraService();
    estimator = FakePoseEstimator();
    now = Duration.zero;
    guideMatches = true;
    disposed = false;
    phone = placedPhone();
    vm = SetupViewModel(
      exercise: ExerciseType.pushUp,
      camera: camera,
      estimator: estimator,
      clock: () => now,
      phoneTilt: phone,
      guideMatcher: (_, _, _) => guideMatches,
    );
    vm.setGuideViewport(const Size(400, 400));
  });

  tearDown(() {
    if (!disposed) vm.dispose();
  });

  /// Feeds [frame] (null = ML Kit error) at [ms] milliseconds.
  Future<void> feed(int ms, PoseFrame? frame) async {
    now = Duration(milliseconds: ms);
    estimator.frames.add(frame);
    camera.emit();
    await pumpEventQueue();
  }

  Future<void> hold(int from, int to, PoseFrame frame) async {
    for (var ms = from; ms < to; ms += 500) {
      await feed(ms, frame);
    }
    await feed(to, frame);
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
      expect(vm.state.status.message, '카메라 앞에 서 주세요.');
      expect(vm.state.lastFrame, isNotNull);
    });

    test('hands missing keeps Start disabled', () async {
      final frame = standingFrame(
        move: {for (final l in handLandmarks) l: (500, 995)},
      );
      await feed(0, frame);
      await feed(2000, frame);
      expect(vm.state.status.message, '손이 화면에 안 보여요.');
      expect(vm.state.canStart, isFalse);
    });

    test('not facing the camera keeps Start disabled', () async {
      final frame = standingFrame(hide: faceLandmarks);
      await feed(0, frame);
      await feed(2000, frame);
      expect(vm.state.status.reason, SetupReason.notFacingForward);
      expect(vm.state.status.message, '카메라를 정면으로 봐 주세요.');
      expect(vm.state.canStart, isFalse);
    });

    test('Ready after 1.5 s, one bad frame keeps it, 0.5 s drops it', () async {
      await hold(0, 1000, standingFrame());
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
      await hold(0, 1500, standingFrame());
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

    test(
      'out-of-guide poses cancel and must hold for three fresh seconds',
      () async {
        guideMatches = false;
        await feed(0, standingFrame());
        expect(vm.state.autoStartIn, isNull);
        expect(vm.state.message, contains('실루엣'));
        guideMatches = true;
        await hold(100, 1600, standingFrame());
        guideMatches = false;
        await feed(1700, standingFrame());
        expect(vm.state.autoStartIn, isNull);
        guideMatches = true;
        await hold(1800, 4700, standingFrame());
        expect(vm.state.autoStarted, isFalse);
        await feed(4800, standingFrame());
        expect(vm.state.autoStarted, isTrue);
      },
    );

    test(
      'counts from the first valid push-up frame and finishes after 3 s',
      () async {
        await feed(0, standingFrame());
        expect(vm.state.autoStartIn, const Duration(seconds: 3));
        await hold(500, 1500, standingFrame());
        expect(vm.state.status.isReady, isTrue);
        expect(vm.state.autoStartIn, const Duration(milliseconds: 1500));
        await feed(2100, standingFrame());
        expect(vm.state.message, '준비 완료! 1초 뒤 시작해요.');
        expect(vm.state.autoStarted, isFalse);
        await hold(2600, 3000, standingFrame());
        expect(vm.state.autoStarted, isTrue);
        expect(vm.state.autoStartIn, isNull);
      },
    );

    test('auto start stays set once reached', () async {
      await hold(0, 1500, standingFrame());
      await hold(2000, 3000, standingFrame());
      await feed(3100, emptyFrame());
      expect(vm.state.autoStarted, isTrue);
    });

    test('losing Ready cancels and restarts the countdown', () async {
      await hold(0, 1500, standingFrame());
      await feed(2000, standingFrame());
      // 0.5 s of invalid frames drops Ready.
      await feed(2100, emptyFrame());
      await feed(2600, emptyFrame());
      expect(vm.state.status.isReady, isFalse);
      expect(vm.state.autoStartIn, isNull);
      // The new countdown starts with the first valid frame.
      await feed(2700, standingFrame());
      expect(vm.state.autoStartIn, const Duration(seconds: 3));
      await hold(3200, 5600, standingFrame());
      expect(vm.state.autoStarted, isFalse);
      await feed(5700, standingFrame());
      expect(vm.state.autoStarted, isTrue);
    });

    test('an invalid frame restarts the countdown', () async {
      await hold(0, 1500, standingFrame());
      await feed(2000, emptyFrame());
      expect(vm.state.autoStartIn, isNull);
      await feed(2100, standingFrame());
      expect(vm.state.autoStartIn, const Duration(seconds: 3));
      await hold(2600, 4500, standingFrame());
      expect(vm.state.autoStarted, isFalse);
      await feed(5100, standingFrame());
      expect(vm.state.autoStarted, isTrue);
    });

    test('pause and resume restart the hold and the countdown', () async {
      await hold(0, 1500, standingFrame());
      await feed(2000, standingFrame());
      expect(vm.state.autoStartIn, isNotNull);
      await vm.pause();
      await vm.resume();
      expect(vm.state.autoStartIn, isNull);
      await feed(3100, standingFrame());
      expect(vm.state.status.isReady, isFalse);
      await hold(3600, 4600, standingFrame());
      expect(vm.state.autoStartIn, const Duration(milliseconds: 1500));
      await hold(5100, 6000, standingFrame());
      expect(vm.state.autoStarted, isFalse);
      await feed(6100, standingFrame());
      expect(vm.state.autoStarted, isTrue);
    });

    test('0.5 s of detector failures cancels the countdown', () async {
      await hold(0, 1500, standingFrame());
      await feed(2000, standingFrame());
      await feed(2100, null);
      await feed(2600, null);
      expect(vm.state.status.isReady, isFalse);
      expect(vm.state.autoStartIn, isNull);
      // Detection recovers: a fresh 3 s countdown starts immediately.
      await feed(2700, standingFrame());
      await hold(3200, 4200, standingFrame());
      expect(vm.state.autoStartIn, const Duration(milliseconds: 1500));
      await hold(4700, 5600, standingFrame());
      expect(vm.state.autoStarted, isFalse);
    });

    test('a long push-up frame gap restarts the countdown', () async {
      final good = standingFrame();
      await hold(0, 2000, good);
      await feed(3000, good);
      expect(vm.state.autoStarted, isFalse);
      expect(vm.state.autoStartIn, const Duration(seconds: 3));
    });

    test('a new preview crop starts a new hold', () async {
      final good = standingFrame();
      await hold(0, 2500, good);
      vm.setGuideViewport(const Size(400, 250));
      await feed(3000, good);
      expect(vm.state.autoStarted, isFalse);
      expect(vm.state.autoStartIn, const Duration(seconds: 3));
    });

    test(
      'distance and phone tilt interrupt an otherwise aligned hold',
      () async {
        final good = standingFrame();
        await hold(0, 2000, good);
        await feed(2500, standingFrame(scale: .3));
        expect(vm.state.status.reason, SetupReason.tooFar);
        expect(vm.state.autoStartIn, isNull);
        phone.isPropped = false;
        await feed(3000, good);
        expect(vm.state.status.reason, SetupReason.phoneTooFlat);
        expect(vm.state.autoStartIn, isNull);
        phone.isPropped = true;
        await hold(3500, 6000, good);
        expect(vm.state.autoStarted, isFalse);
        await feed(6500, good);
        expect(vm.state.autoStarted, isTrue);
      },
    );

    test('custom auto start delay is used', () async {
      final custom = SetupViewModel(
        exercise: ExerciseType.pushUp,
        config: const SetupConfig(autoStartDelay: Duration(seconds: 2)),
        camera: camera,
        estimator: estimator,
        clock: () => now,
        phoneTilt: placedPhone(),
        guideMatcher: (_, _, _) => true,
      );
      custom.setGuideViewport(const Size(400, 400));
      await custom.start();
      await hold(0, 1500, standingFrame());
      await feed(2000, standingFrame());
      expect(custom.state.autoStarted, isTrue);
      custom.dispose();
    });
  });

  test(
    'real guide matching gates the three-second push-up countdown',
    () async {
      final actual = SetupViewModel(
        exercise: ExerciseType.pushUp,
        camera: camera,
        estimator: estimator,
        clock: () => now,
        phoneTilt: placedPhone(),
      );
      actual.setGuideViewport(const Size(1000, 1000));
      await actual.start();
      PoseFrame frame({double shift = 0}) => standingFrame(
        move: {
          BodyLandmark.nose: (500 + shift, 140),
          BodyLandmark.leftShoulder: (360 + shift, 270),
          BodyLandmark.rightShoulder: (640 + shift, 270),
          BodyLandmark.leftElbow: (280 + shift, 550),
          BodyLandmark.rightElbow: (720 + shift, 550),
          BodyLandmark.leftWrist: (200 + shift, 850),
          BodyLandmark.rightWrist: (800 + shift, 850),
        },
      );
      await feed(0, frame(shift: 250));
      expect(actual.state.guideAligned, isFalse);
      expect(actual.state.autoStarted, isFalse);
      await feed(100, frame());
      expect(actual.state.guideAligned, isTrue);
      await hold(600, 3100, frame());
      expect(actual.state.autoStarted, isTrue);
      actual.dispose();
    },
  );

  test('squat alignment gates and resets the three-second countdown', () async {
    final squat = SetupViewModel(
      exercise: ExerciseType.squat,
      camera: camera,
      estimator: estimator,
      clock: () => now,
      phoneTilt: placedPhone(),
    );
    squat.setGuideViewport(const Size(400, 800));
    await squat.start();
    final good = standingFrame(
      showHips: true,
      move: {
        BodyLandmark.leftAnkle: (830, 870),
        BodyLandmark.rightAnkle: (170, 870),
      },
    );
    final centered = standingFrame(showHips: true);
    final outside = PoseFrame(
      imageWidth: centered.imageWidth,
      imageHeight: centered.imageHeight,
      keypoints: {
        for (final entry in centered.keypoints.entries)
          entry.key: Keypoint(
            landmark: entry.key,
            x: entry.value.x + 200,
            y: entry.value.y,
            likelihood: entry.value.likelihood,
          ),
      },
    );
    await feed(0, outside);
    expect(squat.state.status.reason, SetupReason.ready);
    expect(squat.state.guideAligned, isFalse);
    expect(squat.state.autoStartIn, isNull);
    await feed(100, good);
    expect(squat.state.guideAligned, isTrue);
    expect(squat.state.autoStartIn, const Duration(seconds: 3));
    for (final ms in [600, 1100, 1600]) {
      await feed(ms, good);
    }
    expect(squat.state.status.isReady, isTrue);
    await feed(1700, outside);
    expect(squat.state.autoStartIn, isNull);
    expect(squat.state.canStart, isFalse);
    for (final ms in [1800, 2300, 2800, 3300, 3800, 4300, 4700]) {
      await feed(ms, good);
    }
    expect(squat.state.autoStarted, isFalse);
    await feed(4800, good);
    expect(squat.state.autoStarted, isTrue);
    squat.dispose();
  });

  test('a long squat frame gap restarts the countdown', () async {
    final squat = SetupViewModel(
      exercise: ExerciseType.squat,
      camera: camera,
      estimator: estimator,
      clock: () => now,
      phoneTilt: placedPhone(),
      guideMatcher: (_, _, _) => true,
    );
    squat.setGuideViewport(const Size(400, 800));
    await squat.start();
    final good = standingFrame(showHips: true);
    await feed(0, good);
    await feed(500, good);
    await feed(3000, good);
    expect(squat.state.autoStarted, isFalse);
    expect(squat.state.autoStartIn, const Duration(seconds: 3));
    squat.dispose();
  });

  test('a stalled squat stream clears the ready indication', () async {
    final squat = SetupViewModel(
      exercise: ExerciseType.squat,
      camera: camera,
      estimator: estimator,
      clock: () => now,
      phoneTilt: placedPhone(),
      guideMatcher: (_, _, _) => true,
    );
    squat.setGuideViewport(const Size(400, 800));
    await squat.start();
    final good = standingFrame(showHips: true);
    for (final ms in [0, 500, 1000, 1500]) {
      await feed(ms, good);
    }
    expect(squat.state.status.isReady, isTrue);
    now = const Duration(milliseconds: 2400);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(squat.state.status.isReady, isFalse);
    expect(squat.state.guideAligned, isFalse);
    expect(squat.state.autoStartIn, isNull);
    squat.dispose();
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

    test('one failed detection clears Ready during normal setup', () async {
      await hold(0, 1500, standingFrame());
      expect(vm.state.canStart, isTrue);
      await feed(1600, null);
      expect(vm.state.canStart, isFalse);
      expect(vm.state.autoStartIn, isNull);
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
      await hold(0, 1500, standingFrame());
      await vm.pause();
      await vm.resume();
      expect(vm.state.phase, SetupPhase.running);
      expect(camera.startCount, 2);
      expect(vm.state.canStart, isFalse);
    });

    test('releaseCamera stops the camera and keeps it off', () async {
      await vm.start();
      await vm.releaseCamera();
      expect(camera.stopCount, 1);
      expect(camera.isStreaming, isFalse);
      expect(vm.state.phase, SetupPhase.paused);
      expect(vm.cameraController, isNull);
      await vm.pause();
      await vm.resume();
      await vm.onScreenRotated();
      expect(camera.startCount, 1);
      expect(camera.isStreaming, isFalse);
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
      disposed = true;
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
      disposed = true;
      await starting;
      expect(camera.isStreaming, isFalse);
    });
  });
}
