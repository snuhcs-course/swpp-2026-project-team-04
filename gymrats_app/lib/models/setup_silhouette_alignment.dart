import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Matrix4;

import 'pose_frame.dart';

/// The push-up camera guide drawn at its displayed size.
Path pushUpGuidePath(Size size) => _pushUpGuideOutline.transform(
  Matrix4.diagonal3Values(size.width, size.height, 1).storage,
);

final _pushUpGuideOutline = _smoothOutline(
  _pushUpOutlinePoints.map((point) => point.translate(0, .03)).toList(),
);

// Front push-up body outline in unit space of the camera panel, traced
// from a reference photo. Head is clipped by the top edge; arms fan out to
// hands on the floor, leaving gaps beside the torso and legs.
const List<Offset> _pushUpOutlinePoints = [
  // Head, rounded dome.
  Offset(0.50, 0.00),
  Offset(0.56, 0.008),
  Offset(0.605, 0.04),
  Offset(0.628, 0.095),
  Offset(0.635, 0.16),
  // Right shoulder, softly rounded.
  Offset(0.665, 0.205),
  Offset(0.715, 0.225),
  Offset(0.745, 0.27),
  Offset(0.758, 0.33),
  // Right arm, outer edge.
  Offset(0.768, 0.42),
  Offset(0.782, 0.53),
  Offset(0.806, 0.68),
  Offset(0.83, 0.81),
  // Right hand, rounded mitten.
  Offset(0.86, 0.855),
  Offset(0.895, 0.885),
  Offset(0.91, 0.92),
  Offset(0.895, 0.948),
  Offset(0.85, 0.958),
  Offset(0.77, 0.958),
  Offset(0.725, 0.948),
  Offset(0.705, 0.925),
  Offset(0.715, 0.895),
  // Right arm, inner edge up to the armpit.
  Offset(0.738, 0.855),
  Offset(0.725, 0.68),
  Offset(0.70, 0.535),
  Offset(0.665, 0.468),
  // Right side of torso and leg, rounded right foot.
  Offset(0.645, 0.515),
  Offset(0.63, 0.56),
  Offset(0.602, 0.60),
  Offset(0.59, 0.70),
  Offset(0.58, 0.765),
  Offset(0.565, 0.797),
  Offset(0.54, 0.807),
  Offset(0.522, 0.795),
  // Gap between the feet.
  Offset(0.50, 0.74),
  // Rounded left foot, left side of leg and torso.
  Offset(0.478, 0.795),
  Offset(0.46, 0.807),
  Offset(0.435, 0.797),
  Offset(0.42, 0.765),
  Offset(0.41, 0.70),
  Offset(0.398, 0.60),
  Offset(0.37, 0.56),
  Offset(0.355, 0.515),
  // Left arm, inner edge down from the armpit.
  Offset(0.335, 0.468),
  Offset(0.30, 0.535),
  Offset(0.275, 0.68),
  Offset(0.262, 0.855),
  // Left hand, rounded mitten.
  Offset(0.285, 0.895),
  Offset(0.295, 0.925),
  Offset(0.275, 0.948),
  Offset(0.23, 0.958),
  Offset(0.15, 0.958),
  Offset(0.105, 0.948),
  Offset(0.09, 0.92),
  Offset(0.105, 0.885),
  Offset(0.14, 0.855),
  // Left arm, outer edge.
  Offset(0.17, 0.81),
  Offset(0.194, 0.68),
  Offset(0.218, 0.53),
  Offset(0.232, 0.42),
  // Left shoulder, softly rounded.
  Offset(0.242, 0.33),
  Offset(0.255, 0.27),
  Offset(0.285, 0.225),
  Offset(0.335, 0.205),
  // Head, rounded dome.
  Offset(0.365, 0.16),
  Offset(0.372, 0.095),
  Offset(0.395, 0.04),
  Offset(0.44, 0.008),
];

/// Closed centripetal Catmull-Rom curve through [points]; avoids the
/// overshoot and kinks of the uniform form when point spacing varies.
Path _smoothOutline(List<Offset> points) {
  final n = points.length;
  final path = Path()..moveTo(points[0].dx, points[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = points[(i - 1 + n) % n];
    final p1 = points[i];
    final p2 = points[(i + 1) % n];
    final p3 = points[(i + 2) % n];

    final l1 = (p1 - p0).distance;
    final l2 = (p2 - p1).distance;
    final l3 = (p3 - p2).distance;
    if (l1 == 0 || l2 == 0 || l3 == 0) {
      path.lineTo(p2.dx, p2.dy);
      continue;
    }
    final d1 = math.sqrt(l1);
    final d2 = math.sqrt(l2);
    final d3 = math.sqrt(l3);

    final c1 =
        (p2 * l1 - p0 * l2 + p1 * (2 * l1 + 3 * d1 * d2 + l2)) /
        (3 * d1 * (d1 + d2));
    final c2 =
        (p1 * l3 - p3 * l2 + p2 * (2 * l3 + 3 * d3 * d2 + l2)) /
        (3 * d3 * (d3 + d2));
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path..close();
}

/// Centered fractions of the full preview occupied by the guide and by
/// the visible camera picture during setup.
typedef SetupCameraCrop = ({Size guide, Size visible});

/// Checks the head, shoulders and hands against regions of the drawn guide.
/// The points use the same centered BoxFit.cover crop as the camera preview.
/// Thresholds are initial heuristics and require physical-device calibration.
class SetupSilhouetteAlignment {
  const SetupSilhouetteAlignment({this.minLikelihood = 0.6});

  final double minLikelihood;

  bool matches(PoseFrame frame, Size viewport, {required bool mirror}) {
    final input = Size(frame.imageWidth, frame.imageHeight);
    if (viewport.isEmpty ||
        input.isEmpty ||
        !viewport.isFinite ||
        !input.isFinite) {
      return false;
    }
    final source = applyBoxFit(BoxFit.cover, input, viewport).source;
    return matchesImageCrop(frame, (
      guide: Size(source.width / input.width, source.height / input.height),
      visible: const Size(1, 1),
    ), mirror: mirror);
  }

  /// Maps full-frame points to the guide and rejects clipped landmarks.
  bool matchesImageCrop(
    PoseFrame frame,
    SetupCameraCrop crop, {
    required bool mirror,
  }) {
    final input = Size(frame.imageWidth, frame.imageHeight);
    bool validShare(Size share) =>
        share.isFinite &&
        !share.isEmpty &&
        share.width <= 1 &&
        share.height <= 1;
    if (!input.isFinite ||
        input.isEmpty ||
        !validShare(crop.guide) ||
        !validShare(crop.visible)) {
      return false;
    }
    Rect centered(Size share) => Rect.fromCenter(
      center: const Offset(.5, .5),
      width: share.width,
      height: share.height,
    );
    final source = centered(crop.guide);
    final visible = centered(crop.visible);
    Offset? point(BodyLandmark landmark) {
      final p = frame[landmark];
      if (p == null ||
          !p.x.isFinite ||
          !p.y.isFinite ||
          !p.likelihood.isFinite ||
          p.likelihood < minLikelihood) {
        return null;
      }
      final projected = Offset(p.x / input.width, p.y / input.height);
      if (!visible.contains(projected)) return null;
      var x = (projected.dx - source.left) / source.width;
      final y = (projected.dy - source.top) / source.height;
      if (mirror) x = 1 - x;
      final point = Offset(x, y);
      return _pushUpGuideOutline.contains(point) ? point : null;
    }

    final nose = point(BodyLandmark.nose);
    final shoulderA = point(BodyLandmark.leftShoulder);
    final shoulderB = point(BodyLandmark.rightShoulder);
    final wristA = point(BodyLandmark.leftWrist);
    final wristB = point(BodyLandmark.rightWrist);
    if (nose == null ||
        shoulderA == null ||
        shoulderB == null ||
        wristA == null ||
        wristB == null) {
      return false;
    }
    final shoulders = [shoulderA, shoulderB]
      ..sort((a, b) => a.dx.compareTo(b.dx));
    final wrists = [wristA, wristB]..sort((a, b) => a.dx.compareTo(b.dx));
    // Each landmark must be in its own region of the displayed guide.
    // A centered head cannot compensate for an arm or hand out of place.
    return const Rect.fromLTRB(.32, .02, .68, .28).contains(nose) &&
        const Rect.fromLTRB(.21, .16, .46, .43).contains(shoulders[0]) &&
        const Rect.fromLTRB(.54, .16, .79, .43).contains(shoulders[1]) &&
        const Rect.fromLTRB(.08, .68, .33, .98).contains(wrists[0]) &&
        const Rect.fromLTRB(.67, .68, .92, .98).contains(wrists[1]);
  }
}
