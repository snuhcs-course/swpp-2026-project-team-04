import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/pose_estimator.dart';

import '../../support/pose_fixtures.dart';

class _FakeDetector extends PoseDetector {
  _FakeDetector() : super(options: PoseDetectorOptions());

  Completer<List<Pose>>? pending;
  InputImage? lastInput;
  int calls = 0;
  bool closed = false;

  @override
  Future<List<Pose>> processImage(InputImage inputImage) {
    calls++;
    lastInput = inputImage;
    return (pending = Completer<List<Pose>>()).future;
  }

  @override
  Future<void> close() async => closed = true;
}

Pose _pose() => Pose(
  landmarks: {
    for (final type in PoseLandmarkType.values)
      type: PoseLandmark(
        type: type,
        x: type.index.toDouble(),
        y: 2.0 * type.index,
        z: 0,
        likelihood: 0.9,
      ),
  },
);

void main() {
  late _FakeDetector detector;
  late PoseEstimator estimator;

  setUp(() {
    detector = _FakeDetector();
    estimator = PoseEstimator(detector: detector);
  });

  test('converts ML Kit landmarks to a PoseFrame', () async {
    final result = estimator.process(fakeCameraImage(), 0);
    detector.pending!.complete([_pose()]);
    final frame = (await result)!;
    expect(frame.keypoints, hasLength(33));
    final wrist = frame[BodyLandmark.leftWrist]!;
    expect(wrist.x, PoseLandmarkType.leftWrist.index.toDouble());
    expect(wrist.y, 2.0 * PoseLandmarkType.leftWrist.index);
    expect(wrist.likelihood, 0.9);
    expect(frame.imageWidth, 640);
    expect(frame.imageHeight, 480);
  });

  test('passes NV21 metadata and rotation to ML Kit', () async {
    final result = estimator.process(fakeCameraImage(), 270);
    final metadata = detector.lastInput!.metadata!;
    expect(metadata.format, InputImageFormat.nv21);
    expect(metadata.rotation, InputImageRotation.rotation270deg);
    expect(metadata.bytesPerRow, 640);
    detector.pending!.complete([]);
    await result;
  });

  test('swaps width and height for 90 and 270 degree rotation', () async {
    final result = estimator.process(fakeCameraImage(), 90);
    detector.pending!.complete([]);
    final frame = (await result)!;
    expect(frame.imageWidth, 480);
    expect(frame.imageHeight, 640);
  });

  test('no pose gives an empty frame', () async {
    final result = estimator.process(fakeCameraImage(), 0);
    detector.pending!.complete([]);
    expect((await result)!.hasPerson, isFalse);
  });

  test('drops frames while busy instead of queueing them', () async {
    final first = estimator.process(fakeCameraImage(), 0);
    expect(estimator.isBusy, isTrue);
    expect(await estimator.process(fakeCameraImage(), 0), isNull);
    expect(detector.calls, 1);
    detector.pending!.complete([]);
    await first;
    expect(estimator.isBusy, isFalse);
    final third = estimator.process(fakeCameraImage(), 0);
    expect(detector.calls, 2);
    detector.pending!.complete([]);
    await third;
  });

  test('ML Kit errors are thrown and free the estimator', () async {
    final result = estimator.process(fakeCameraImage(), 0);
    detector.pending!.completeError(Exception('ml kit'));
    await expectLater(result, throwsException);
    expect(estimator.isBusy, isFalse);
  });

  test('unsupported frame formats throw', () async {
    await expectLater(
      estimator.process(fakeCameraImage(planeCount: 3), 0),
      throwsUnsupportedError,
    );
    await expectLater(
      estimator.process(fakeCameraImage(rawFormat: 35), 0),
      throwsUnsupportedError,
    );
    expect(estimator.isBusy, isFalse);
  });

  test('close while busy waits for the frame and drops its result', () async {
    final result = estimator.process(fakeCameraImage(), 0);
    final closing = estimator.close();
    await pumpEventQueue();
    expect(detector.closed, isFalse);
    var secondDone = false;
    final second = estimator.close().then((_) => secondDone = true);
    await pumpEventQueue();
    expect(secondDone, isFalse);
    detector.pending!.complete([_pose()]);
    expect(await result, isNull);
    await closing;
    await second;
    expect(detector.closed, isTrue);
  });

  test('close releases the detector and stops processing', () async {
    await estimator.close();
    await estimator.close();
    expect(detector.closed, isTrue);
    expect(await estimator.process(fakeCameraImage(), 0), isNull);
    expect(detector.calls, 0);
  });
}
