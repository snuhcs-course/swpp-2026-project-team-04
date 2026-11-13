import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'pose_frame.dart';

/// Checks the head, shoulders and hands against regions of the drawn guide.
/// The points use the same centered BoxFit.cover crop as the camera preview.
/// Thresholds are initial heuristics and require physical-device calibration.
class SetupSilhouetteAlignment {
  const SetupSilhouetteAlignment({this.minLikelihood = 0.6});

  final double minLikelihood;

  bool matches(PoseFrame frame, Size viewport, {required bool mirror}) {
    if (viewport.isEmpty || frame.imageWidth <= 0 || frame.imageHeight <= 0) {
      return false;
    }
    final input = Size(frame.imageWidth, frame.imageHeight);
    final source = Alignment.center.inscribe(
      applyBoxFit(BoxFit.cover, input, viewport).source,
      Offset.zero & input,
    );
    Offset? point(BodyLandmark landmark) {
      final p = frame[landmark];
      if (p == null ||
          !p.x.isFinite ||
          !p.y.isFinite ||
          !p.likelihood.isFinite ||
          p.likelihood < minLikelihood) {
        return null;
      }
      var x = (p.x - source.left) / source.width;
      final y = (p.y - source.top) / source.height;
      if (mirror) x = 1 - x;
      return Offset(x, y);
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
    // Coordinates are fractions of the displayed silhouette, not the raw
    // camera image; distance is zero while a point lies within its region.
    final head = _outside(nose, const Rect.fromLTRB(.32, .02, .68, .28));
    final leftShoulder = _outside(
      shoulders[0],
      const Rect.fromLTRB(.21, .16, .46, .43),
    );
    final rightShoulder = _outside(
      shoulders[1],
      const Rect.fromLTRB(.54, .16, .79, .43),
    );
    final leftHand = _outside(
      wrists[0],
      const Rect.fromLTRB(.08, .68, .33, .98),
    );
    final rightHand = _outside(
      wrists[1],
      const Rect.fromLTRB(.67, .68, .92, .98),
    );
    final total =
        2 * head + leftShoulder + rightShoulder + 2 * leftHand + 2 * rightHand;
    return head <= .07 && leftHand <= .07 && rightHand <= .07 && total <= .18;
  }

  static double _outside(Offset p, Rect r) {
    final dx = math.max(math.max(r.left - p.dx, 0), p.dx - r.right);
    final dy = math.max(math.max(r.top - p.dy, 0), p.dy - r.bottom);
    return math.sqrt(dx * dx + dy * dy);
  }
}
