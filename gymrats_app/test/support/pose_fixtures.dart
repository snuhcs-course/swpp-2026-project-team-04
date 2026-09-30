import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraImageData, CameraImageFormat, CameraImagePlane;
import 'package:gymrats_app/models/pose_frame.dart';

/// Synthetic pose frames for tests. The image is 1000 x 1000 pixels.
const double imageSize = 1000;

/// A standing person roughly in the middle of the frame, all landmarks
/// visible. Body height is about 75% of the frame.
const Map<BodyLandmark, (double, double)> _standing = {
  BodyLandmark.nose: (500, 150),
  BodyLandmark.leftEyeInner: (510, 140),
  BodyLandmark.leftEye: (515, 140),
  BodyLandmark.leftEyeOuter: (520, 140),
  BodyLandmark.rightEyeInner: (490, 140),
  BodyLandmark.rightEye: (485, 140),
  BodyLandmark.rightEyeOuter: (480, 140),
  BodyLandmark.leftEar: (530, 150),
  BodyLandmark.rightEar: (470, 150),
  BodyLandmark.leftMouth: (510, 170),
  BodyLandmark.rightMouth: (490, 170),
  BodyLandmark.leftShoulder: (560, 250),
  BodyLandmark.rightShoulder: (440, 250),
  BodyLandmark.leftElbow: (580, 380),
  BodyLandmark.rightElbow: (420, 380),
  BodyLandmark.leftWrist: (590, 500),
  BodyLandmark.rightWrist: (410, 500),
  BodyLandmark.leftPinky: (595, 520),
  BodyLandmark.rightPinky: (405, 520),
  BodyLandmark.leftIndex: (590, 525),
  BodyLandmark.rightIndex: (410, 525),
  BodyLandmark.leftThumb: (585, 515),
  BodyLandmark.rightThumb: (415, 515),
  BodyLandmark.leftHip: (530, 520),
  BodyLandmark.rightHip: (470, 520),
  BodyLandmark.leftKnee: (530, 700),
  BodyLandmark.rightKnee: (470, 700),
  BodyLandmark.leftAnkle: (530, 870),
  BodyLandmark.rightAnkle: (470, 870),
  BodyLandmark.leftHeel: (525, 890),
  BodyLandmark.rightHeel: (475, 890),
  BodyLandmark.leftFootIndex: (545, 900),
  BodyLandmark.rightFootIndex: (455, 900),
};

final Set<BodyLandmark> leftSideLandmarks = BodyLandmark.values
    .where((l) => l.name.startsWith('left'))
    .toSet();

final Set<BodyLandmark> rightSideLandmarks = BodyLandmark.values
    .where((l) => l.name.startsWith('right'))
    .toSet();

const Set<BodyLandmark> handLandmarks = {
  BodyLandmark.leftWrist,
  BodyLandmark.rightWrist,
  BodyLandmark.leftPinky,
  BodyLandmark.rightPinky,
  BodyLandmark.leftIndex,
  BodyLandmark.rightIndex,
  BodyLandmark.leftThumb,
  BodyLandmark.rightThumb,
};

/// Nose and eyes: hiding them looks like a user who turned away.
const Set<BodyLandmark> faceLandmarks = {
  BodyLandmark.nose,
  BodyLandmark.leftEyeInner,
  BodyLandmark.leftEye,
  BodyLandmark.leftEyeOuter,
  BodyLandmark.rightEyeInner,
  BodyLandmark.rightEye,
  BodyLandmark.rightEyeOuter,
};

const Set<BodyLandmark> feetLandmarks = {
  BodyLandmark.leftAnkle,
  BodyLandmark.rightAnkle,
  BodyLandmark.leftHeel,
  BodyLandmark.rightHeel,
  BodyLandmark.leftFootIndex,
  BodyLandmark.rightFootIndex,
};

Keypoint kp(BodyLandmark l, double x, double y, {double likelihood = 0.95}) =>
    Keypoint(landmark: l, x: x, y: y, likelihood: likelihood);

PoseFrame emptyFrame() =>
    const PoseFrame.empty(imageWidth: imageSize, imageHeight: imageSize);

/// A standing pose.
///
/// [scale] resizes the body around the frame center. [hide] gives landmarks
/// a low likelihood. [move] places landmarks at new coordinates.
/// [likelihoods] overrides single likelihoods.
PoseFrame standingFrame({
  double scale = 1,
  double likelihood = 0.95,
  Set<BodyLandmark> hide = const {},
  Map<BodyLandmark, (double, double)> move = const {},
  Map<BodyLandmark, double> likelihoods = const {},
}) {
  const c = imageSize / 2;
  return PoseFrame(
    imageWidth: imageSize,
    imageHeight: imageSize,
    keypoints: {
      for (final MapEntry(key: l, value: (x, y)) in _standing.entries)
        l: kp(
          l,
          move[l]?.$1 ?? c + (x - c) * scale,
          move[l]?.$2 ?? c + (y - c) * scale,
          likelihood: hide.contains(l) ? 0.1 : likelihoods[l] ?? likelihood,
        ),
    },
  );
}

/// Hips, knees, and feet: hidden behind the body in a front-view push-up.
final Set<BodyLandmark> lowerBodyLandmarks = BodyLandmark.values
    .where(
      (l) => const [
        'Hip',
        'Knee',
        'Ankle',
        'Heel',
        'FootIndex',
      ].any((part) => l.name.endsWith(part)),
    )
    .toSet();

/// A front-view push-up: the standing pose made wide and short, like a
/// body seen head-on from a phone on the floor, with the lower body hidden.
/// About 47% of the frame wide, facing the camera.
PoseFrame pushUpFrontFrame() {
  const c = imageSize / 2;
  return PoseFrame(
    imageWidth: imageSize,
    imageHeight: imageSize,
    keypoints: {
      for (final MapEntry(key: l, value: (x, y)) in _standing.entries)
        l: kp(
          l,
          c + (x - c) * 2.5,
          c + (y - c) * 0.3,
          likelihood: lowerBodyLandmarks.contains(l) ? 0.1 : 0.95,
        ),
    },
  );
}

/// A front-view push-up pose with a chosen elbow angle, arm span, and
/// shoulder tilt.
///
/// [spanRatio] is the raw shoulder-to-wrist distance divided by shoulder
/// width (not yet compared with the top pose). [tiltDeg] rotates the whole
/// pose so the shoulder line leaves horizontal by that many degrees.
PoseFrame pushUpFrame({
  double elbowAngle = 170,
  double spanRatio = 1.2,
  double tiltDeg = 0,
  double likelihood = 0.95,
  Set<BodyLandmark> hide = const {},
}) {
  const midX = 500.0;
  const midY = 400.0;
  const shoulderWidth = 200.0;
  final radians = elbowAngle * math.pi / 180;
  final denom = 1 - math.cos(radians);
  final arm = denom.abs() < 1e-6
      ? shoulderWidth
      : spanRatio * shoulderWidth / denom;
  final bend = math.sin(radians);
  final down = -math.cos(radians);

  Offset wristOf(Offset shoulder, double inward) {
    final elbow = Offset(shoulder.dx, shoulder.dy + arm);
    return Offset(elbow.dx + inward * bend * arm, elbow.dy + down * arm);
  }

  final origin = const Offset(midX, midY);
  final tilt = tiltDeg * math.pi / 180;
  final cos = math.cos(tilt);
  final sin = math.sin(tilt);
  Offset turn(Offset point) {
    final dx = point.dx - origin.dx;
    final dy = point.dy - origin.dy;
    return Offset(
      origin.dx + dx * cos - dy * sin,
      origin.dy + dx * sin + dy * cos,
    );
  }

  final leftShoulder = const Offset(midX - shoulderWidth / 2, midY);
  final rightShoulder = const Offset(midX + shoulderWidth / 2, midY);
  final points = {
    BodyLandmark.leftShoulder: turn(leftShoulder),
    BodyLandmark.rightShoulder: turn(rightShoulder),
    BodyLandmark.leftElbow: turn(
      Offset(leftShoulder.dx, leftShoulder.dy + arm),
    ),
    BodyLandmark.rightElbow: turn(
      Offset(rightShoulder.dx, rightShoulder.dy + arm),
    ),
    BodyLandmark.leftWrist: turn(wristOf(leftShoulder, 1)),
    BodyLandmark.rightWrist: turn(wristOf(rightShoulder, -1)),
  };

  return PoseFrame(
    imageWidth: imageSize,
    imageHeight: imageSize,
    keypoints: {
      for (final MapEntry(key: landmark, value: point) in points.entries)
        landmark: kp(
          landmark,
          point.dx,
          point.dy,
          likelihood: hide.contains(landmark) ? 0.1 : likelihood,
        ),
    },
  );
}

/// [frame] mirrored left-right, like the front camera preview.
PoseFrame mirrored(PoseFrame frame) => PoseFrame(
  imageWidth: frame.imageWidth,
  imageHeight: frame.imageHeight,
  keypoints: {
    for (final MapEntry(key: l, value: k) in frame.keypoints.entries)
      l: kp(l, frame.imageWidth - k.x, k.y, likelihood: k.likelihood),
  },
);

/// A blank camera frame, NV21 with a single plane by default, like the
/// Android CameraX stream.
CameraImage fakeCameraImage({
  int width = 640,
  int height = 480,
  int rawFormat = 17,
  int planeCount = 1,
}) => CameraImage.fromPlatformInterface(
  CameraImageData(
    format: CameraImageFormat(ImageFormatGroup.nv21, raw: rawFormat),
    width: width,
    height: height,
    planes: [
      for (var i = 0; i < planeCount; i++)
        CameraImagePlane(
          bytes: Uint8List(width * height * 3 ~/ 2),
          bytesPerRow: width,
          bytesPerPixel: 1,
        ),
    ],
  ),
);
