import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/avatar_pose_payload.dart';

void main() {
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
