import '../../models/pose_frame.dart';

/// ML Kit image coordinates, NOT metric world coordinates. Use the same width
/// for x/y/z to preserve directions and aspect ratio. The renderer only uses
/// relative vectors; hip centering avoids large image-space offsets. Preserve
/// the original hip position separately for screen-relative root translation.
Map<String, Object?> avatarPosePayload(
  PoseFrame? frame, {
  required bool mirror,
}) {
  if (frame == null ||
      !frame.hasPerson ||
      !frame.imageWidth.isFinite ||
      !frame.imageHeight.isFinite ||
      frame.imageWidth <= 0 ||
      frame.imageHeight <= 0) {
    return {'landmarks': null, 'screenAnchor': null, 'mirror': mirror};
  }
  final left = frame[BodyLandmark.leftHip];
  final right = frame[BodyLandmark.rightHip];
  final cx = left != null && right != null ? (left.x + right.x) / 2 : 0.0;
  final cy = left != null && right != null ? (left.y + right.y) / 2 : 0.0;
  final cz = left != null && right != null ? (left.z + right.z) / 2 : 0.0;
  final width = frame.imageWidth;
  return {
    'mirror': mirror,
    'screenAnchor':
        left != null &&
            right != null &&
            cx.isFinite &&
            cy.isFinite &&
            left.likelihood.isFinite &&
            right.likelihood.isFinite &&
            left.likelihood >= .6 &&
            right.likelihood >= .6 &&
            cx >= 0 &&
            cx <= width &&
            cy >= 0 &&
            cy <= frame.imageHeight
        ? {
            'x': cx / width,
            'y': cy / frame.imageHeight,
            'imageAspect': width / frame.imageHeight,
          }
        : null,
    'landmarks': [
      for (final landmark in BodyLandmark.values)
        if (frame[landmark] case final point?
            when point.x.isFinite &&
                point.y.isFinite &&
                point.z.isFinite &&
                point.likelihood.isFinite &&
                cx.isFinite &&
                cy.isFinite &&
                cz.isFinite)
          {
            'x': (point.x - cx) / width,
            'y': (point.y - cy) / width,
            'z': (point.z - cz) / width,
            'visibility': point.likelihood.clamp(0.0, 1.0),
          }
        else
          null,
    ],
  };
}
