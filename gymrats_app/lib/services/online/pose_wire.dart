import '../../shared/battle_protocol.dart';
import '../../models/pose_frame.dart';

Map<String, dynamic> encodeBattlePose(
  PoseFrame? frame, {
  required int sequence,
  required int elapsedMs,
}) {
  final valid =
      frame != null &&
      frame.imageWidth.isFinite &&
      frame.imageHeight.isFinite &&
      frame.imageWidth > 0 &&
      frame.imageHeight > 0;
  final joints = <List<num>>[];
  if (valid) {
    for (final entry in frame.keypoints.entries) {
      final p = entry.value,
          x = p.x / frame.imageWidth,
          y = p.y / frame.imageHeight,
          z = p.z / frame.imageWidth;
      if (!x.isFinite ||
          !y.isFinite ||
          !z.isFinite ||
          !p.likelihood.isFinite ||
          x < -2 ||
          x > 3 ||
          y < -2 ||
          y > 3 ||
          z < -10 ||
          z > 10) {
        continue;
      }
      joints.add([entry.key.index, x, y, z, p.likelihood.clamp(0, 1)]);
    }
  }
  return checkedPose({
    'frame_seq': sequence,
    'elapsed_ms': elapsedMs,
    'aspect_ratio': valid ? frame.imageWidth / frame.imageHeight : 1.0,
    'has_person': joints.isNotEmpty,
    'joints': joints,
  });
}

PoseFrame decodeBattlePose(
  Map<String, dynamic> payload, {
  int durationMs = 60000,
}) {
  final p = checkedPose(payload, durationMs: durationMs),
      aspect = p['aspect_ratio'] as double;
  // A virtual image has height 1000. Rebuild all axes using the sender's
  // aspect, not the receiver's screen. z uses image width, as specified.
  final width = 1000 * aspect;
  return PoseFrame(
    imageWidth: width,
    imageHeight: 1000,
    keypoints: {
      for (final row in p['joints'] as List)
        BodyLandmark.values[(row[0] as num).toInt()]: Keypoint(
          landmark: BodyLandmark.values[(row[0] as num).toInt()],
          x: (row[1] as num) * width,
          y: (row[2] as num) * 1000,
          z: (row[3] as num) * width,
          likelihood: (row[4] as num).toDouble(),
        ),
    },
  );
}
