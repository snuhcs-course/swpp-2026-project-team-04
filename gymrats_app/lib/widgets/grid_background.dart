import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Faint lime grid behind a screen, as in the prototype.
///
/// Wrap a Scaffold body with it. The grid stays still while [child] scrolls.
class GridBackground extends StatelessWidget {
  const GridBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: const _GridPainter(), child: child);
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  static const _spacing = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
