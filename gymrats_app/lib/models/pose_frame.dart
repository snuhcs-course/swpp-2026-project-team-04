/// The 33 body landmarks reported by ML Kit pose detection, in ML Kit's
/// index order, so `BodyLandmark.values[i]` matches ML Kit landmark `i`.
///
/// Left and right refer to the person's own body, not the image.
enum BodyLandmark {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  leftMouth,
  rightMouth,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// One detected landmark.
///
/// [x] and [y] are pixel coordinates in the upright image (after rotation),
/// with the origin at the top left. [likelihood] is ML Kit's in-frame
/// likelihood in the range 0..1.
class Keypoint {
  const Keypoint({
    required this.landmark,
    required this.x,
    required this.y,
    this.z = 0,
    required this.likelihood,
  });

  final BodyLandmark landmark;
  final double x;
  final double y;
  final double z;
  final double likelihood;

  @override
  String toString() =>
      'Keypoint(${landmark.name}, x: ${x.toStringAsFixed(1)}, '
      'y: ${y.toStringAsFixed(1)}, likelihood: ${likelihood.toStringAsFixed(2)})';
}

/// The pose detected in one camera frame.
///
/// An empty [keypoints] map means no person was detected.
class PoseFrame {
  const PoseFrame({
    required this.imageWidth,
    required this.imageHeight,
    required this.keypoints,
  });

  /// A frame in which nobody was detected.
  const PoseFrame.empty({required this.imageWidth, required this.imageHeight})
    : keypoints = const {};

  /// Upright image width in pixels.
  final double imageWidth;

  /// Upright image height in pixels.
  final double imageHeight;

  final Map<BodyLandmark, Keypoint> keypoints;

  bool get hasPerson => keypoints.isNotEmpty;

  Keypoint? operator [](BodyLandmark landmark) => keypoints[landmark];
}
