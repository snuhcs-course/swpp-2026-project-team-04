import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/avatar_pose_payload.dart';

void main() {
  shoulderDepthTests();
  liveKneeTests();
  test('preserves all 33 indices, image aspect and depth without images', () {
    const frame = PoseFrame(
      imageWidth: 640,
      imageHeight: 480,
      keypoints: {
        BodyLandmark.leftHip: Keypoint(
          landmark: BodyLandmark.leftHip,
          x: 300,
          y: 300,
          z: 20,
          likelihood: 1,
        ),
        BodyLandmark.rightHip: Keypoint(
          landmark: BodyLandmark.rightHip,
          x: 340,
          y: 300,
          z: 20,
          likelihood: 1,
        ),
        BodyLandmark.leftShoulder: Keypoint(
          landmark: BodyLandmark.leftShoulder,
          x: 384,
          y: 172,
          z: -44,
          likelihood: .9,
        ),
      },
    );
    final payload = avatarPosePayload(frame, mirror: true);
    final points = payload['landmarks'] as List;
    expect(points, hasLength(33));
    expect(points[0], isNull);
    expect(points[11], {'x': .1, 'y': -.2, 'z': -.1, 'visibility': .9});
    expect(payload['mirror'], true);
    expect(payload['screenAnchor'], {
      'x': .5,
      'y': .625,
      'imageAspect': 640 / 480,
    });
    expect(
      payload.keys,
      unorderedEquals(['landmarks', 'screenAnchor', 'mirror']),
    );
  });

  test('no person and invalid dimensions clear pose', () {
    expect(avatarPosePayload(null, mirror: false)['landmarks'], isNull);
    expect(
      avatarPosePayload(
        const PoseFrame.empty(imageWidth: 640, imageHeight: 480),
        mirror: false,
      )['landmarks'],
      isNull,
    );
    const invalid = PoseFrame(
      imageWidth: 0,
      imageHeight: 480,
      keypoints: {
        BodyLandmark.nose: Keypoint(
          landmark: BodyLandmark.nose,
          x: 1,
          y: 2,
          likelihood: 1,
        ),
      },
    );
    expect(avatarPosePayload(invalid, mirror: false)['landmarks'], isNull);
  });

  test('non-finite points are omitted before JSON encoding', () {
    const frame = PoseFrame(
      imageWidth: 640,
      imageHeight: 480,
      keypoints: {
        BodyLandmark.leftShoulder: Keypoint(
          landmark: BodyLandmark.leftShoulder,
          x: double.nan,
          y: 3,
          likelihood: 1,
        ),
      },
    );
    expect(
      (avatarPosePayload(frame, mirror: false)['landmarks'] as List)[11],
      isNull,
    );
  });

  test(
    'translation survives hip centering while limb vectors stay unchanged',
    () {
      PoseFrame frame(double dx, double dy, {double likelihood = 1}) =>
          PoseFrame(
            imageWidth: 640,
            imageHeight: 480,
            keypoints: {
              BodyLandmark.leftHip: Keypoint(
                landmark: BodyLandmark.leftHip,
                x: 300 + dx,
                y: 240 + dy,
                likelihood: likelihood,
              ),
              BodyLandmark.rightHip: Keypoint(
                landmark: BodyLandmark.rightHip,
                x: 340 + dx,
                y: 240 + dy,
                likelihood: likelihood,
              ),
              BodyLandmark.leftShoulder: Keypoint(
                landmark: BodyLandmark.leftShoulder,
                x: 300 + dx,
                y: 100 + dy,
                likelihood: 1,
              ),
            },
          );
      final first = avatarPosePayload(frame(0, 0), mirror: false);
      final moved = avatarPosePayload(frame(64, 48), mirror: false);
      expect(first['landmarks'], moved['landmarks']);
      expect(first['screenAnchor'], {
        'x': .5,
        'y': .5,
        'imageAspect': 640 / 480,
      });
      expect(moved['screenAnchor'], {
        'x': .6,
        'y': .6,
        'imageAspect': 640 / 480,
      });
      expect(
        avatarPosePayload(
          frame(0, 0, likelihood: .2),
          mirror: false,
        )['screenAnchor'],
        isNull,
      );
      expect(
        avatarPosePayload(frame(1000, 0), mirror: false)['screenAnchor'],
        isNull,
      );
    },
  );
}

PoseFrame shoulders(double y, {double confidence = 1, double width = 100}) =>
    PoseFrame(
      imageWidth: 400,
      imageHeight: 600,
      keypoints: {
        for (final landmark in [
          BodyLandmark.leftWrist,
          BodyLandmark.rightWrist,
          BodyLandmark.leftAnkle,
          BodyLandmark.rightAnkle,
        ])
          landmark: Keypoint(
            landmark: landmark,
            x: 150,
            y: y + 80,
            likelihood: confidence,
          ),
        BodyLandmark.leftShoulder: Keypoint(
          landmark: BodyLandmark.leftShoulder,
          x: 100,
          y: y,
          likelihood: confidence,
        ),
        BodyLandmark.rightShoulder: Keypoint(
          landmark: BodyLandmark.rightShoulder,
          x: 100 + width,
          y: y,
          likelihood: confidence,
        ),
      },
    );

void shoulderDepthTests() {
  Duration at(int ms) => Duration(milliseconds: ms);
  void calibrate(ShoulderDepthTracker tracker) {
    for (var t = 0; t <= 600; t += 100) {
      tracker.update(shoulders(100), at(t));
    }
  }

  test('stable top, descent and ascent use shoulders without elbows', () {
    final tracker = ShoulderDepthTracker();
    calibrate(tracker);
    expect(tracker.isCalibrated, isTrue);
    expect(tracker.update(shoulders(100), at(700)), closeTo(0, .01));
    double? depth;
    for (var t = 800; t <= 1200; t += 100) {
      depth = tracker.update(shoulders(150), at(t));
    }
    expect(depth!, greaterThan(.25));
    for (var t = 1300; t <= 1800; t += 100) {
      depth = tracker.update(shoulders(100), at(t));
    }
    expect(depth!, lessThan(.05));
  });

  test('standing posture cannot establish a push-up baseline', () {
    final tracker = ShoulderDepthTracker();
    PoseFrame standing(double y) {
      final frame = shoulders(y);
      return PoseFrame(
        imageWidth: frame.imageWidth,
        imageHeight: frame.imageHeight,
        keypoints: {
          ...frame.keypoints,
          for (final landmark in [
            BodyLandmark.leftAnkle,
            BodyLandmark.rightAnkle,
          ])
            landmark: Keypoint(
              landmark: landmark,
              x: 150,
              y: y + 300,
              likelihood: 1,
            ),
        },
      );
    }

    for (var t = 0; t <= 1000; t += 100) {
      expect(tracker.update(standing(100), at(t)), isNull);
    }
    expect(tracker.isCalibrated, isFalse);
    for (var t = 1100; t <= 1800; t += 100) {
      tracker.update(shoulders(200), at(t));
    }
    expect(tracker.isCalibrated, isTrue);
    expect(tracker.update(shoulders(200), at(1900)), closeTo(0, .01));
  });

  test('one-frame bad top estimate does not bend a stationary avatar', () {
    final tracker = ShoulderDepthTracker();
    calibrate(tracker);
    tracker.update(shoulders(40), at(700));
    expect(tracker.update(shoulders(100), at(800))!, lessThan(.05));
  });

  test('one-frame downward spike does not bend a stationary avatar', () {
    final tracker = ShoulderDepthTracker();
    calibrate(tracker);
    final depth = tracker.update(shoulders(200), at(700));
    expect(depth!, lessThan(.12));
  });

  test('invalid tracking is ignored and a long gap recalibrates', () {
    final tracker = ShoulderDepthTracker();
    calibrate(tracker);
    expect(tracker.update(shoulders(150, confidence: .2), at(700)), isNull);
    expect(tracker.update(shoulders(150, width: 5), at(800)), isNull);
    expect(tracker.update(null, at(900)), isNull);
    expect(tracker.update(shoulders(150), at(1800)), isNull);
    for (var t = 1900; t <= 2400; t += 100) {
      tracker.update(shoulders(150), at(t));
    }
    expect(tracker.update(shoulders(150), at(2500)), closeTo(0, .01));
  });
}

PoseFrame kneeTestFrame(double left, double right, {bool hideLeft = false}) =>
    PoseFrame(
      imageWidth: 400,
      imageHeight: 600,
      keypoints: {
        for (final p in <(BodyLandmark, double, double, double)>[
          (BodyLandmark.leftShoulder, 100, 100, 1),
          (BodyLandmark.rightShoulder, 200, 100, 1),
          (BodyLandmark.leftWrist, 100, 300, 1),
          (BodyLandmark.rightWrist, 200, 300, 1),
          (BodyLandmark.leftKnee, 130, left, hideLeft ? 0 : 1),
          (BodyLandmark.rightKnee, 170, right, 1),
        ])
          p.$1: Keypoint(landmark: p.$1, x: p.$2, y: p.$3, likelihood: p.$4),
      },
    );

void liveKneeTests() {
  test('each knee responds independently and smoothly', () {
    final t = LiveKneeTracker();
    for (var i = 0; i <= 10; i++) {
      t.update(
        kneeTestFrame(220, 220),
        Duration(milliseconds: i * 100),
        readyForBaseline: true,
      );
    }
    expect(t.left, 0);
    expect(t.right, 0);
    for (var i = 11; i <= 20; i++) {
      t.update(kneeTestFrame(290, 220), Duration(milliseconds: i * 100));
    }
    expect(t.left, greaterThan(.9));
    expect(t.right, 0);
    for (var i = 21; i <= 30; i++) {
      t.update(kneeTestFrame(220, 290), Duration(milliseconds: i * 100));
    }
    expect(t.left, lessThan(.05));
    expect(t.right, greaterThan(.9));
  });
  test('ordinary movement near the calibrated plank does not lower knees', () {
    final t = LiveKneeTracker();
    for (var i = 0; i <= 10; i++) {
      t.update(
        kneeTestFrame(260, 250),
        Duration(milliseconds: i * 100),
        readyForBaseline: true,
      );
    }
    for (var i = 11; i <= 20; i++) {
      t.update(kneeTestFrame(275, 265), Duration(milliseconds: i * 100));
    }
    expect(t.left, 0);
    expect(t.right, 0);
    for (var i = 21; i <= 30; i++) {
      t.update(kneeTestFrame(320, 250), Duration(milliseconds: i * 100));
    }
    expect(t.left, greaterThan(.9));
    expect(t.right, 0);
  });
  test('a hidden knee retains briefly then resets independently', () {
    final t = LiveKneeTracker();
    for (var i = 0; i <= 10; i++) {
      t.update(
        kneeTestFrame(220, 220),
        Duration(milliseconds: i * 100),
        readyForBaseline: true,
      );
    }
    for (var i = 11; i <= 20; i++) {
      t.update(kneeTestFrame(290, 290), Duration(milliseconds: i * 100));
    }
    t.update(
      kneeTestFrame(290, 290, hideLeft: true),
      const Duration(milliseconds: 2500),
    );
    expect(t.left, greaterThan(.9));
    expect(t.right, greaterThan(.9));
    t.update(
      kneeTestFrame(290, 290, hideLeft: true),
      const Duration(milliseconds: 3200),
    );
    expect(t.left, inExclusiveRange(0, .9));
    expect(t.right, greaterThan(.9));
  });
}
