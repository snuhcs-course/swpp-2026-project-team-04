import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/pose_estimator.dart';

import '../../support/pose_fixtures.dart';

class _ChangingDetector extends PoseDetector {
  _ChangingDetector() : super(options: PoseDetectorOptions());

  double nextX = 100;

  @override
  Future<List<Pose>> processImage(InputImage inputImage) async => [
    Pose(
      landmarks: {
        PoseLandmarkType.leftShoulder: PoseLandmark(
          type: PoseLandmarkType.leftShoulder,
          x: nextX,
          y: 100,
          z: 0,
          likelihood: 0.99,
        ),
      },
    ),
  ];

  @override
  Future<void> close() async {}
}

void main() {
  test(
    'documents that detector identity switches reach the consumer',
    () async {
      final detector = _ChangingDetector();
      final estimator = PoseEstimator(detector: detector);
      final first = await estimator.process(fakeCameraImage(), 0);
      detector.nextX =
          500; // A synthetic detector switch, not a video recording.
      final second = await estimator.process(fakeCameraImage(), 0);
      expect(first![BodyLandmark.leftShoulder]!.x, 100);
      expect(second![BodyLandmark.leftShoulder]!.x, 500);
      await estimator.close();
    },
  );
  PoseFrame moved(PoseFrame frame, double dx) => PoseFrame(
    imageWidth: frame.imageWidth,
    imageHeight: frame.imageHeight,
    keypoints: {
      for (final entry in frame.keypoints.entries)
        entry.key: Keypoint(
          landmark: entry.key,
          x: entry.value.x + dx,
          y: entry.value.y,
          z: entry.value.z,
          likelihood: entry.value.likelihood,
        ),
    },
  );

  test('identical landmark geometry cannot establish identity', () {
    final guard = PersonContinuityGuard();
    final pose = pushUpFrame();
    guard.begin(pose, Duration.zero);
    // A different person with the same landmarks is indistinguishable here.
    expect(guard.accepts(pose, const Duration(milliseconds: 100)), isTrue);
  });

  test('a large pose jump stays blocked until explicit confirmation', () {
    final guard = PersonContinuityGuard();
    final original = pushUpFrame();
    final other = moved(original, 300);
    guard.begin(original, Duration.zero);
    expect(
      guard.accepts(moved(original, 30), const Duration(milliseconds: 100)),
      isTrue,
    );
    expect(guard.accepts(other, const Duration(milliseconds: 200)), isFalse);
    expect(guard.needsConfirmation, isTrue);
    expect(guard.accepts(original, const Duration(milliseconds: 300)), isFalse);
    expect(guard.needsConfirmation, isTrue);
    expect(guard.confirm(const Duration(milliseconds: 300)), isTrue);
    expect(guard.accepts(original, const Duration(milliseconds: 400)), isTrue);
  });

  test(
    'lost landmarks suspend scoring and a long loss requires confirmation',
    () {
      final guard = PersonContinuityGuard();
      final original = pushUpFrame();
      const empty = PoseFrame.empty(imageWidth: 1000, imageHeight: 1000);
      guard.begin(original, Duration.zero);
      expect(guard.accepts(empty, const Duration(milliseconds: 100)), isFalse);
      expect(guard.needsConfirmation, isFalse);
      expect(
        guard.accepts(original, const Duration(milliseconds: 200)),
        isTrue,
      );
      expect(guard.accepts(empty, const Duration(milliseconds: 1000)), isFalse);
      expect(guard.needsConfirmation, isTrue);
      expect(guard.confirm(const Duration(milliseconds: 1000)), isFalse);
      expect(
        guard.accepts(original, const Duration(milliseconds: 1100)),
        isFalse,
      );
      expect(guard.confirm(const Duration(milliseconds: 2000)), isFalse);
      expect(
        guard.accepts(original, const Duration(milliseconds: 2050)),
        isFalse,
      );
      expect(guard.confirm(const Duration(milliseconds: 2050)), isTrue);
    },
  );

  test('missing shoulders fail closed when the round is armed', () {
    final guard = PersonContinuityGuard();
    const empty = PoseFrame.empty(imageWidth: 1000, imageHeight: 1000);
    guard.begin(empty, Duration.zero);
    expect(guard.needsConfirmation, isTrue);
    expect(
      guard.accepts(pushUpFrame(), const Duration(milliseconds: 50)),
      isFalse,
    );
    expect(guard.confirm(const Duration(milliseconds: 50)), isTrue);
  });

  PoseFrame narrowShoulders(PoseFrame frame) {
    final left = frame[BodyLandmark.leftShoulder]!;
    final right = frame[BodyLandmark.rightShoulder]!;
    final center = (left.x + right.x) / 2;
    return PoseFrame(
      imageWidth: frame.imageWidth,
      imageHeight: frame.imageHeight,
      keypoints: {
        ...frame.keypoints,
        for (final p in [left, right])
          p.landmark: Keypoint(
            landmark: p.landmark,
            x: center + (p.x - center) * .3,
            y: p.y,
            likelihood: p.likelihood,
          ),
      },
    );
  }

  test('an isolated shoulder-width outlier is withheld then recovers', () {
    final guard = PersonContinuityGuard();
    final original = pushUpFrame();
    guard.begin(original, Duration.zero);
    expect(
      guard.accepts(
        narrowShoulders(original),
        const Duration(milliseconds: 100),
      ),
      isFalse,
    );
    expect(guard.needsConfirmation, isFalse);
    expect(guard.accepts(original, const Duration(milliseconds: 167)), isTrue);
    expect(guard.needsConfirmation, isFalse);
  });

  test('a sustained size change is blocked and requires confirmation', () {
    final guard = PersonContinuityGuard();
    final original = pushUpFrame();
    final changed = narrowShoulders(original);
    guard.begin(original, Duration.zero);
    for (final ms in [100, 167, 233, 300]) {
      expect(guard.accepts(changed, Duration(milliseconds: ms)), isFalse);
    }
    expect(guard.needsConfirmation, isTrue);
    expect(guard.accepts(original, const Duration(milliseconds: 400)), isFalse);
    expect(guard.confirm(const Duration(milliseconds: 400)), isTrue);
  });

  test('a width outlier cannot conceal a position jump', () {
    final guard = PersonContinuityGuard();
    final original = pushUpFrame();
    guard.begin(original, Duration.zero);
    expect(
      guard.accepts(
        narrowShoulders(moved(original, 300)),
        const Duration(milliseconds: 100),
      ),
      isFalse,
    );
    expect(guard.needsConfirmation, isTrue);
  });
}
