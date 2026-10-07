import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The opponent as a glossy side-view mannequin doing push-ups on a pink
/// stage, as in the battle design.
///
/// It dips down and back up once each time [moves] goes up. Give it a box
/// of [designSize]'s shape.
class OpponentMannequin extends StatefulWidget {
  const OpponentMannequin({super.key, required this.moves});

  /// How many reps the opponent has made so far, valid or not.
  final int moves;

  /// The design's canvas; the painters scale it to their size.
  static const designSize = Size(142, 128);

  /// One dip, down and up again. Shorter than the bot's closest reps.
  static const dipDuration = Duration(milliseconds: 800);

  @override
  State<OpponentMannequin> createState() => _OpponentMannequinState();
}

class _OpponentMannequinState extends State<OpponentMannequin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dip = AnimationController(
    vsync: this,
    duration: OpponentMannequin.dipDuration,
  );

  /// 0 with the arms extended, 1 at the bottom.
  late final Animation<double> _depth = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 55,
    ),
  ]).animate(_dip);

  @override
  void didUpdateWidget(OpponentMannequin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.moves > oldWidget.moves) _dip.forward(from: 0);
  }

  @override
  void dispose() {
    _dip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Separate layers, so a dip repaints only the figure.
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: CustomPaint(painter: _StagePainter())),
        RepaintBoundary(child: CustomPaint(painter: _FigurePainter(_depth))),
      ],
    );
  }
}

/// The faint spotlight, the floor grid, the disc, and the figure's shadow.
/// Nothing here moves.
class _StagePainter extends CustomPainter {
  const _StagePainter();

  /// Floor grid lines, as (x1, y1, x2, y2).
  static const _grid = [
    (134.3, 68.9, -4.6, 73.2),
    (142.0, 71.8, -8.9, 76.9),
    (151.0, 75.3, -14.0, 81.5),
    (161.9, 79.5, -20.4, 87.0),
    (175.2, 84.6, -28.4, 94.0),
    (191.7, 91.0, -38.8, 103.2),
    (212.8, 99.1, -52.8, 115.4),
    (240.9, 109.9, -72.8, 133.0),
    (280.0, 125.0, -103.7, 160.0),
    (134.3, 68.9, 280.0, 125.0),
    (118.6, 69.4, 244.0, 128.2),
    (102.4, 69.9, 205.4, 131.8),
    (85.9, 70.4, 163.8, 135.6),
    (68.8, 70.9, 118.9, 139.7),
    (51.2, 71.5, 70.2, 144.1),
    (33.2, 72.0, 17.3, 148.9),
    (14.6, 72.6, -40.4, 154.2),
    (-4.6, 73.2, -103.7, 160.0),
  ];

  static const _discCenter = Offset(78.8, 96.8);
  static const _discRadius = 79.0;
  static const _discHeight = 44.4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..clipRect(Offset.zero & size)
      ..scale(
        size.width / OpponentMannequin.designSize.width,
        size.height / OpponentMannequin.designSize.height,
      );
    _paintSpotlight(canvas);
    final line = Paint()
      ..color = AppColors.opponent.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    for (final (x1, y1, x2, y2) in _grid) {
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), line);
    }
    _paintDisc(canvas);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(72.3, 90.3),
        width: 55,
        height: 14.6,
      ),
      Paint()
        ..color = AppColors.background.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  }

  void _paintSpotlight(Canvas canvas) {
    final light = Rect.fromCenter(
      center: const Offset(79, 67),
      width: 156,
      height: 108,
    );
    canvas.drawOval(
      light,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.opponent.withValues(alpha: 0.13),
            AppColors.opponent.withValues(alpha: 0),
          ],
        ).createShader(light),
    );
  }

  /// The glowing disc under the figure. Its gradient is drawn as a circle
  /// and squashed, so it follows the oval.
  void _paintDisc(Canvas canvas) {
    final circle = Rect.fromCircle(center: Offset.zero, radius: _discRadius);
    canvas
      ..save()
      ..translate(_discCenter.dx, _discCenter.dy)
      ..scale(1, _discHeight / (2 * _discRadius))
      ..drawCircle(
        Offset.zero,
        _discRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.opponent.withValues(alpha: 0.42),
              AppColors.opponent.withValues(alpha: 0.12),
              AppColors.opponent.withValues(alpha: 0),
            ],
            stops: const [0, 0.6, 1],
          ).createShader(circle),
      )
      ..restore()
      ..drawOval(
        Rect.fromCenter(
          center: _discCenter,
          width: 2 * _discRadius,
          height: _discHeight,
        ),
        Paint()
          ..color = AppColors.opponent.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_StagePainter oldDelegate) => false;
}

/// One limb or body part: a thick rounded line between two points, in the
/// up pose and in the down pose.
class _Segment {
  const _Segment(this.up, this.down, this.width, this.shade);

  final (Offset, Offset) up;
  final (Offset, Offset) down;
  final double width;

  /// 0 for the far side of the body, which is darker, to 1 for the near
  /// side.
  final double shade;
}

/// The figure: a pink glow, gray body parts with a highlight, the head, and
/// the visor. It lerps between the design's two poses.
class _FigurePainter extends CustomPainter {
  _FigurePainter(this.depth) : super(repaint: depth);

  /// 0 with the arms extended, 1 at the bottom.
  final Animation<double> depth;

  /// Back to front, as the design draws them; each as up pose, down pose.
  static const _segments = [
    _Segment(
      (Offset(119.8, 81.0), Offset(125.3, 85.5)),
      (Offset(119.8, 81.0), Offset(125.3, 85.5)),
      4.2,
      0,
    ), // far foot
    _Segment(
      (Offset(96.2, 72.1), Offset(119.8, 81.0)),
      (Offset(94.3, 79.6), Offset(119.8, 81.0)),
      6.2,
      0.1,
    ), // far shin
    _Segment(
      (Offset(42.6, 85.0), Offset(37.0, 86.2)),
      (Offset(42.6, 85.0), Offset(37.0, 86.2)),
      4.0,
      0.13,
    ), // far hand
    _Segment(
      (Offset(41.5, 68.6), Offset(42.6, 85.0)),
      (Offset(47.2, 70.8), Offset(42.6, 85.0)),
      5.0,
      0.18,
    ), // far forearm
    _Segment(
      (Offset(70.7, 62.4), Offset(96.2, 72.1)),
      (Offset(67.0, 78.0), Offset(94.3, 79.6)),
      8.5,
      0.24,
    ), // far thigh
    _Segment(
      (Offset(123.9, 83.6), Offset(129.8, 88.2)),
      (Offset(123.9, 83.6), Offset(129.8, 88.2)),
      4.5,
      0.29,
    ), // near foot
    _Segment(
      (Offset(40.1, 50.5), Offset(41.5, 68.6)),
      (Offset(34.9, 75.5), Offset(47.2, 70.8)),
      6.1,
      0.31,
    ), // far upper arm
    _Segment(
      (Offset(99.5, 74.5), Offset(123.9, 83.6)),
      (Offset(97.5, 82.4), Offset(123.9, 83.6)),
      6.5,
      0.42,
    ), // near shin
    _Segment(
      (Offset(70.7, 62.4), Offset(72.9, 64.6)),
      (Offset(67.0, 78.0), Offset(69.0, 81.4)),
      10.6,
      0.5,
    ), // pelvis
    _Segment(
      (Offset(40.1, 51.6), Offset(71.7, 63.5)),
      (Offset(34.5, 78.0), Offset(68.0, 79.6)),
      20.2,
      0.6,
    ), // torso
    _Segment(
      (Offset(72.9, 64.6), Offset(99.5, 74.5)),
      (Offset(69.0, 81.4), Offset(97.5, 82.4)),
      9.1,
      0.61,
    ), // near thigh
    _Segment(
      (Offset(40.1, 50.5), Offset(40.0, 52.8)),
      (Offset(34.9, 75.5), Offset(34.1, 80.9)),
      8.9,
      0.69,
    ), // shoulders
    _Segment(
      (Offset(33.4, 47.7), Offset(24.6, 43.0)),
      (Offset(27.5, 76.4), Offset(18.2, 73.2)),
      6.3,
      0.76,
    ), // neck
    _Segment(
      (Offset(42.9, 93.3), Offset(36.3, 95.0)),
      (Offset(42.9, 93.3), Offset(36.3, 95.0)),
      4.7,
      0.94,
    ), // near hand
    _Segment(
      (Offset(41.5, 74.0), Offset(42.9, 93.3)),
      (Offset(48.9, 81.5), Offset(42.9, 93.3)),
      5.8,
      0.96,
    ), // near forearm
    _Segment(
      (Offset(40.0, 52.8), Offset(41.5, 74.0)),
      (Offset(34.1, 80.9), Offset(48.9, 81.5)),
      6.9,
      1,
    ), // near upper arm
  ];

  static const _headUp = Offset(24.6, 43.0);
  static const _headDown = Offset(18.2, 73.2);
  static const _headRadius = 8.4;
  static const _visorUp = (Offset(18.6, 40.2), Offset(17.7, 40.5));
  static const _visorDown = (Offset(12.4, 70.1), Offset(11.3, 71.5));

  /// How much wider than its part the glow around it is.
  static const _glowSpread = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final t = depth.value;
    canvas
      ..clipRect(Offset.zero & size)
      ..scale(
        size.width / OpponentMannequin.designSize.width,
        size.height / OpponentMannequin.designSize.height,
      );
    final head = Offset.lerp(_headUp, _headDown, t)!;
    final parts = [
      for (final segment in _segments)
        (
          Offset.lerp(segment.up.$1, segment.down.$1, t)!,
          Offset.lerp(segment.up.$2, segment.down.$2, t)!,
          segment,
        ),
    ];

    // The pink glow, blurred as one layer. Only the layer paint's opacity
    // counts, not its color: the glow shows at half strength.
    canvas.saveLayer(
      null,
      Paint()
        ..color = AppColors.opponent.withValues(alpha: 0.5)
        ..imageFilter = ImageFilter.blur(sigmaX: 7, sigmaY: 7),
    );
    for (final (from, to, segment) in parts) {
      canvas.drawLine(
        from,
        to,
        _stroke(AppColors.opponent, segment.width + _glowSpread),
      );
    }
    canvas
      ..drawCircle(
        head,
        _headRadius + _glowSpread / 2,
        Paint()..color = AppColors.opponent,
      )
      ..restore();

    for (final (from, to, segment) in parts) {
      final shade = Color.lerp(
        AppColors.textSecondary,
        AppColors.textPrimary,
        0.15 + 0.85 * segment.shade,
      )!;
      // A thin light line along the top edge makes the part look glossy.
      final highlight = const Offset(-0.1, -0.17) * segment.width;
      canvas
        ..drawLine(from, to, _stroke(shade, segment.width))
        ..drawLine(
          from + highlight,
          to + highlight,
          _stroke(
            AppColors.textPrimary.withValues(alpha: 0.55),
            math.max(1.5, segment.width * 0.3),
          ),
        );
    }

    final headBox = Rect.fromCircle(center: head, radius: _headRadius);
    canvas
      ..drawCircle(
        head,
        _headRadius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.24, -0.36),
            radius: 0.72,
            colors: [
              AppColors.textPrimary,
              Color.lerp(AppColors.textSecondary, AppColors.textPrimary, 0.7)!,
              AppColors.textSecondary,
            ],
            stops: const [0, 0.55, 1],
          ).createShader(headBox),
      )
      ..drawLine(
        Offset.lerp(_visorUp.$1, _visorDown.$1, t)!,
        Offset.lerp(_visorUp.$2, _visorDown.$2, t)!,
        _stroke(AppColors.opponent, 2.8),
      );
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  @override
  bool shouldRepaint(_FigurePainter oldDelegate) => oldDelegate.depth != depth;
}
