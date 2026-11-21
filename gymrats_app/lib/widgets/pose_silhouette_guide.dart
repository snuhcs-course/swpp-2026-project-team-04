import 'package:flutter/material.dart';

import '../models/setup_silhouette_alignment.dart';
import '../theme/app_theme.dart';

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

  static const Color _readyColor = AppColors.statusGood;
  static const Color _idleColor = Colors.white;
  static const Color _scrimColor = Color(0x73000000);

  /// Twice the outline it had before A9 (spec 4), to read from 1 m.
  static const double _borderWidth = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);

    final frame = pushUpGuidePath(size);

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
        // An ink edge under the line (A9 spec 1.3, design A2).
        ..color = AppColors.ink
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

  @override
  bool shouldRepaint(_PushUpFramePainter oldDelegate) =>
      oldDelegate.ready != ready;
}
