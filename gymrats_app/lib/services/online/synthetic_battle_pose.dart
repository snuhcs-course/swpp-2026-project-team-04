import 'dart:math' as math;

import '../../models/pose_frame.dart';

/// Explicit debug fixture, not camera inference or a real scored workout.
PoseFrame syntheticBattlePose(int elapsedMs) {
  final bend = (1 - math.cos(elapsedMs / 3000 * math.pi * 2)) / 2;
  final points = <BodyLandmark, (double, double, double)>{
    BodyLandmark.nose: (500, 200 + bend * 110, -70),
    BodyLandmark.leftShoulder: (590, 310 + bend * 90, -25),
    BodyLandmark.rightShoulder: (410, 310 + bend * 90, 25),
    BodyLandmark.leftElbow: (625 + bend * 100, 430 + bend * 40, -20),
    BodyLandmark.rightElbow: (375 - bend * 100, 430 + bend * 40, 20),
    BodyLandmark.leftWrist: (640, 560, -20),
    BodyLandmark.rightWrist: (360, 560, 20),
    BodyLandmark.leftHip: (550, 560 + bend * 55, 100),
    BodyLandmark.rightHip: (450, 560 + bend * 55, 130),
    BodyLandmark.leftKnee: (550, 710 + bend * 25, 170),
    BodyLandmark.rightKnee: (450, 710 + bend * 25, 200),
    BodyLandmark.leftAnkle: (550, 850, 240),
    BodyLandmark.rightAnkle: (450, 850, 270),
    BodyLandmark.leftHeel: (550, 870, 250),
    BodyLandmark.rightHeel: (450, 870, 280),
    BodyLandmark.leftFootIndex: (550, 890, 250),
    BodyLandmark.rightFootIndex: (450, 890, 280),
  };
  return PoseFrame(
    imageWidth: 1000,
    imageHeight: 1000,
    keypoints: {
      for (final entry in points.entries)
        entry.key: Keypoint(
          landmark: entry.key,
          x: entry.value.$1,
          y: entry.value.$2,
          z: entry.value.$3,
          likelihood: .99,
        ),
    },
  );
}
