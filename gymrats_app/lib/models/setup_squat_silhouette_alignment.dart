import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'pose_frame.dart';

/// The camera uses BoxFit.contain, so both the guide and pose points must
/// use the displayed image rectangle rather than the surrounding letterbox.
Rect squatPreviewRect(Size image, Size viewport) {
  if (image.isEmpty ||
      viewport.isEmpty ||
      !image.width.isFinite ||
      !image.height.isFinite ||
      !viewport.width.isFinite ||
      !viewport.height.isFinite) {
    return Rect.zero;
  }
  final destination = applyBoxFit(BoxFit.contain, image, viewport).destination;
  return Alignment.center.inscribe(destination, Offset.zero & viewport);
}

/// The standing figure keeps human proportions in both screen orientations.
Rect standingGuideRect(Size viewport) {
  final height = math.min(viewport.height * .92, viewport.width / .65);
  return Rect.fromCenter(
    center: Offset(viewport.width / 2, viewport.height / 2),
    width: height * .65,
    height: height,
  );
}

/// Broad regions matching the standing-body guide in the camera preview.
class StandingSilhouetteAlignment {
  const StandingSilhouetteAlignment({this.minLikelihood = 0.6});
  final double minLikelihood;

  bool matches(PoseFrame frame, Size viewport, {required bool mirror}) {
    if (viewport.isEmpty || frame.imageWidth <= 0 || frame.imageHeight <= 0) {
      return false;
    }
    final input = Size(frame.imageWidth, frame.imageHeight);
    final preview = squatPreviewRect(input, viewport);
    final guide = standingGuideRect(preview.size).shift(preview.topLeft);
    if (preview.isEmpty || guide.isEmpty) return false;
    Offset? point(BodyLandmark landmark) {
      final p = frame[landmark];
      if (p == null ||
          !p.x.isFinite ||
          !p.y.isFinite ||
          !p.likelihood.isFinite ||
          p.likelihood < minLikelihood) {
        return null;
      }
      var normalizedX = p.x / input.width;
      if (mirror) normalizedX = 1 - normalizedX;
      final x = preview.left + normalizedX * preview.width;
      final y = preview.top + p.y / input.height * preview.height;
      final displayed = Offset(x, y);
      if (!preview.contains(displayed)) return null;
      return Offset(
        (x - guide.left) / guide.width,
        (y - guide.top) / guide.height,
      );
    }

    bool inside(BodyLandmark part, Rect region) {
      final p = point(part);
      return p != null && region.contains(p);
    }

    bool pair(BodyLandmark a, BodyLandmark b, Rect region) =>
        inside(a, region) && inside(b, region);
    return inside(BodyLandmark.nose, const Rect.fromLTRB(.25, .02, .75, .28)) &&
        pair(
          BodyLandmark.leftShoulder,
          BodyLandmark.rightShoulder,
          const Rect.fromLTRB(.10, .12, .90, .42),
        ) &&
        pair(
          BodyLandmark.leftHip,
          BodyLandmark.rightHip,
          const Rect.fromLTRB(.16, .32, .84, .70),
        ) &&
        pair(
          BodyLandmark.leftKnee,
          BodyLandmark.rightKnee,
          const Rect.fromLTRB(.10, .47, .90, .86),
        ) &&
        pair(
          BodyLandmark.leftAnkle,
          BodyLandmark.rightAnkle,
          // Allow a wider stance while keeping the same ankle height range.
          const Rect.fromLTRB(-.08, .67, 1.08, .98),
        );
  }
}
