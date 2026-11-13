import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Framing guide for the front-facing push-up setup.
///
/// Dims the camera viewport outside one smooth rounded aperture that leaves
/// room for the face, shoulders, straight arms with hands planted near the
/// lower edge, and the body receding behind. The aperture interior stays
/// fully transparent. The geometry adapts to whatever size this widget is
/// given, so it fits a full-screen preview or a shorter camera panel.
/// [ready] reflects the existing setup checker; the guide itself does not
/// measure alignment.
class PoseSilhouetteGuide extends StatelessWidget {
  const PoseSilhouetteGuide({super.key, required this.ready});

  /// Whether the setup checker currently reports the pose as ready.
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      image: true,
      label: ready ? '푸시업 준비 자세 확인됨' : '푸시업 준비 자세 안내: 경계선 안에 몸을 맞추세요',
      child: IgnorePointer(
        child: SizedBox.expand(
          child: CustomPaint(painter: _PushUpFramePainter(ready: ready)),
        ),
      ),
    );
  }
}

class _PushUpFramePainter extends CustomPainter {
  _PushUpFramePainter({required this.ready});

  final bool ready;

  static const Color _readyColor = Color(0xFF4CD964);
  static const Color _idleColor = Colors.white;
  static const Color _scrimColor = Color(0x73000000);
  static const double _borderWidth = 2.0;
  static const double _verticalOffset = 0.03;

  // Front push-up body outline in unit space of the camera panel, traced
  // from a reference photo. Head is clipped by the top edge; arms fan out to
  // hands on the floor, leaving gaps beside the torso and legs.
  static const List<Offset> _outline = [
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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);

    final aperture = _apertureRect(size);
    if (aperture.isEmpty) return;

    final frame = _smooth(
      _outline
          .map(
            (p) => Offset(
              aperture.left + p.dx * aperture.width,
              aperture.top + (p.dy + _verticalOffset) * aperture.height,
            ),
          )
          .toList(),
    );

    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(frame, Offset.zero);
    canvas.drawPath(
      scrim,
      Paint()
        ..style = PaintingStyle.fill
        ..color = _scrimColor
        ..isAntiAlias = true,
    );

    canvas.drawPath(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth * 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withAlpha(60)
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth
        ..strokeJoin = StrokeJoin.round
        ..color = (ready ? _readyColor : _idleColor).withAlpha(220)
        ..isAntiAlias = true,
    );
  }

  /// The outline is traced in camera-panel coordinates, so it spans the
  /// whole viewport.
  static Rect _apertureRect(Size size) => Offset.zero & size;

  /// Closed centripetal Catmull-Rom curve through [points]; avoids the
  /// overshoot and kinks of the uniform form when point spacing varies.
  static Path _smooth(List<Offset> points) {
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

  @override
  bool shouldRepaint(_PushUpFramePainter oldDelegate) =>
      oldDelegate.ready != ready;
}
