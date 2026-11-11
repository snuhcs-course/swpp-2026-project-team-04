import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// RepBot doing push-ups without a break, in the middle of the lobby.
///
/// It holds the top pose when the system asks for less motion.
class LobbyRepBot extends StatefulWidget {
  const LobbyRepBot({super.key});

  /// The design's slot. RepBot scales to any size, keeping its shape.
  static const designSize = Size(320, 264);

  @override
  State<LobbyRepBot> createState() => _LobbyRepBotState();
}

class _LobbyRepBotState extends State<LobbyRepBot>
    with SingleTickerProviderStateMixin {
  /// Time since RepBot appeared, as a share of one push-up.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: RepBotMotion.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    // Repaints alone each frame, not the screen around it.
    return Semantics(
      image: true,
      label: 'RepBot이 쉬지 않고 푸쉬업하는 모습',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (_, _) => CustomPaint(
            size: LobbyRepBot.designSize,
            painter: RepBotPainter(
              depth: still
                  ? 0
                  : RepBotMotion.depthAt(RepBotMotion.period * _clock.value),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where RepBot is in its push-up at a given time, as designed.
abstract final class RepBotMotion {
  /// One push-up, down and back up.
  static const period = Duration(milliseconds: 2000);

  /// RepBot appears this far into a push-up, on its way down.
  static const startOffset = Duration(milliseconds: 600);

  /// How far down RepBot is [elapsed] after it appeared: 0 at the top with
  /// straight arms, 1 at the bottom with the chest down, slowing at both.
  static double depthAt(Duration elapsed) {
    final intoRep =
        (elapsed + startOffset).inMicroseconds % period.inMicroseconds;
    return (1 - math.cos(2 * math.pi * intoRep / period.inMicroseconds)) / 2;
  }
}

/// One limb: a straight bar with round ends. Each end moves in a straight
/// line from the top pose to the bottom one.
class RepBotBar {
  const RepBotBar(
    this.name,
    this.ends, {
    required this.width,
    required this.color,
    this.shine,
  });

  /// The design's name, e.g. "footL".
  final String name;

  /// As in the design: the two ends at the top (x1, y1, x2, y2), then at the
  /// bottom (x1, y1, x2, y2), in its coordinates ([RepBotPainter.viewBox]).
  final List<double> ends;

  final double width;
  final Color color;

  /// The streak of light along it; null for none.
  final RepBotShine? shine;

  /// Its two ends at [depth] (0 top, 1 bottom).
  (Offset, Offset) endsAt(double depth) => (
    Offset(_mix(ends[0], ends[4], depth), _mix(ends[1], ends[5], depth)),
    Offset(_mix(ends[2], ends[6], depth), _mix(ends[3], ends[7], depth)),
  );
}

/// A see-through white bar [width] wide along a limb, moved by [shift].
class RepBotShine {
  const RepBotShine(this.width, this.shift);

  final double width;
  final Offset shift;
}

/// The design's `a + (b - a) * s`, so the numbers match it to the last digit.
double _mix(double top, double bottom, double depth) =>
    top + (bottom - top) * depth;

/// RepBot at one point of its push-up: a pink light and a shadow on the
/// floor, then the body with a soft pink glow and a thin outline around it.
class RepBotPainter extends CustomPainter {
  const RepBotPainter({required this.depth});

  /// 0 at the top, 1 at the bottom ([RepBotMotion.depthAt]).
  final double depth;

  /// The part of the design's coordinates the slot shows. It is drawn as
  /// large as fits, centered; the glow may spill over the edges.
  static const viewBox = Rect.fromLTWH(24, 76, 340, 280);

  /// The limbs, farthest first, so nearer ones cover them.
  static const limbs = [
    RepBotBar(
      'footL',
      [301.6, 207.5, 310.3, 217.2, 301.6, 207.5, 310.3, 217.2],
      width: 13,
      color: RepBotColors.footL,
      shine: RepBotShine(3.9, Offset(-1.3, -2.2)),
    ),
    RepBotBar(
      'footR',
      [332.0, 213.2, 340.2, 223.1, 332.0, 213.2, 340.2, 223.1],
      width: 13.4,
      color: RepBotColors.footR,
      shine: RepBotShine(4, Offset(-1.3, -2.3)),
    ),
    RepBotBar(
      'shinL',
      [258.8, 194.6, 301.6, 207.5, 255.2, 220.6, 301.6, 207.5],
      width: 19.9,
      color: RepBotColors.shinL,
      shine: RepBotShine(6, Offset(-2, -3.4)),
    ),
    RepBotBar(
      'shinR',
      [295.2, 201.3, 332.0, 213.2, 291.3, 228.2, 332.0, 213.2],
      width: 20.5,
      color: RepBotColors.shinR,
      shine: RepBotShine(6.2, Offset(-2.1, -3.5)),
    ),
    RepBotBar(
      'thighL',
      [201.8, 177.7, 258.8, 194.6, 194.2, 237.0, 255.2, 220.6],
      width: 30.1,
      color: RepBotColors.thighL,
      shine: RepBotShine(9, Offset(-3, -5.1)),
    ),
    RepBotBar(
      'thighR',
      [248.9, 186.0, 295.2, 201.3, 240.4, 248.2, 291.3, 228.2],
      width: 31.4,
      color: RepBotColors.thighR,
      shine: RepBotShine(9.4, Offset(-3.1, -5.3)),
    ),
    RepBotBar(
      'pelvis',
      [201.8, 177.7, 248.9, 186.0, 194.2, 237.0, 240.4, 248.2],
      width: 38.9,
      color: RepBotColors.pelvis,
      shine: RepBotShine(11.7, Offset(-3.9, -6.6)),
    ),
    RepBotBar(
      'handL',
      [109.9, 287.8, 91.2, 299.2, 109.9, 287.8, 91.2, 299.2],
      width: 16.7,
      color: RepBotColors.handL,
      shine: RepBotShine(5, Offset(-1.7, -2.8)),
    ),
    RepBotBar(
      'farmL',
      [106.3, 223.5, 109.9, 287.8, 94.3, 226.5, 109.9, 287.8],
      width: 20.7,
      color: RepBotColors.forearmL,
      shine: RepBotShine(6.2, Offset(-2.1, -3.5)),
    ),
    RepBotBar(
      'torso',
      [145.5, 157.0, 224.8, 181.7, 131.7, 269.8, 216.7, 242.5],
      width: 79,
      color: RepBotColors.torso,
      shine: RepBotShine(23.7, Offset(-7.9, -13.4)),
    ),
    RepBotBar(
      'uarmL',
      [106.9, 150.7, 106.3, 223.5, 94.3, 258.7, 94.3, 226.5],
      width: 25.5,
      color: RepBotColors.upperArmL,
      shine: RepBotShine(7.7, Offset(-2.6, -4.3)),
    ),
    RepBotBar(
      'handR',
      [206.2, 319.3, 192.4, 334.5, 206.2, 319.3, 192.4, 334.5],
      width: 18.7,
      color: RepBotColors.near,
      shine: RepBotShine(5.6, Offset(-1.9, -3.2)),
    ),
    RepBotBar(
      'farmR',
      [200.3, 247.2, 206.2, 319.3, 257.2, 268.8, 206.2, 319.3],
      width: 23,
      color: RepBotColors.near,
      shine: RepBotShine(6.9, Offset(-2.3, -3.9)),
    ),
    RepBotBar(
      'shoulders',
      [106.9, 150.7, 187.9, 164.0, 94.3, 258.7, 172.8, 282.1],
      width: 37.4,
      color: RepBotColors.near,
      shine: RepBotShine(11.2, Offset(-3.7, -6.4)),
    ),
    RepBotBar(
      'uarmR',
      [187.9, 164.0, 200.3, 247.2, 172.8, 282.1, 257.2, 268.8],
      width: 28.2,
      color: RepBotColors.upperArmR,
      shine: RepBotShine(8.5, Offset(-2.8, -4.8)),
    ),
    RepBotBar(
      'neck',
      [125.7, 145.1, 97.6, 129.9, 110.7, 271.0, 80.5, 268.7],
      width: 27.7,
      color: RepBotColors.neck,
      shine: RepBotShine(8.3, Offset(-2.8, -4.7)),
    ),
  ];

  /// The pink visor, drawn over the head.
  static const visor = RepBotBar(
    'visor',
    [62.3, 119.5, 89.2, 123.1, 45.5, 261.6, 71.3, 269.9],
    width: 13.2,
    color: AppColors.opponent,
  );

  /// All 17 bars in drawing order. The head goes in before the visor.
  static const bars = [...limbs, visor];

  /// The head at the top pose.
  static const headCenter = Offset(97.6, 129.9);
  static const headRadius = 37.9;

  /// How far the head moves from the top pose to the bottom one.
  static const headDrop = Offset(-17.1, 138.8);

  /// How far the head has moved at [depth].
  static Offset headShiftAt(double depth) =>
      Offset(_mix(0, headDrop.dx, depth), _mix(0, headDrop.dy, depth));

  /// The pink light on the floor and the shadow over it, as ellipses.
  static const _floor = Rect.fromLTRB(18, 228, 410, 356);
  static const _shadow = Rect.fromLTRB(110, 252, 334, 320);

  /// The body's outline, and its glow before the blur: how far each grows
  /// out from the body.
  static const _outlineWidth = 1.6;
  static const _glowSpread = 5.0;

  static const _glowBlur = 9.0;

  /// Where the glow may reach: the design's filter region.
  static const _glowBounds = Rect.fromLTWH(-20, 30, 440, 380);
  static const _glowOpacity = 0.5;
  static const _shineOpacity = 0.55;

  static const _headShading = RadialGradient(
    center: Alignment(-0.24, -0.36),
    radius: 0.72,
    colors: [
      RepBotColors.headLight,
      RepBotColors.headMid,
      RepBotColors.headDark,
    ],
    stops: [0, 0.55, 1],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / viewBox.width,
      size.height / viewBox.height,
    );
    canvas
      ..save()
      ..translate(
        (size.width - viewBox.width * scale) / 2,
        (size.height - viewBox.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-viewBox.left, -viewBox.top);

    _paintEllipse(
      canvas,
      _floor,
      RadialGradient(
        colors: [
          AppColors.opponent.withValues(alpha: 0.3),
          AppColors.opponent.withValues(alpha: 0.1),
          AppColors.opponent.withValues(alpha: 0),
        ],
        stops: const [0, 0.6, 1],
      ),
    );
    _paintEllipse(
      canvas,
      _shadow,
      RadialGradient(
        colors: [
          RepBotColors.shadow.withValues(alpha: 0.22),
          RepBotColors.shadow.withValues(alpha: 0),
        ],
      ),
    );

    final head = headCenter + headShiftAt(depth);
    // The glow and the outline are the whole body's shape grown a little,
    // under the body, so limbs that overlap show no line between them. A
    // layer uses only its paint's opacity, and blurs what is drawn in it.
    canvas.saveLayer(
      _glowBounds,
      Paint()
        ..color = AppColors.opponent.withValues(alpha: _glowOpacity)
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: _glowBlur,
          sigmaY: _glowBlur,
        ),
    );
    _paintShape(canvas, head, grow: _glowSpread, color: AppColors.opponent);
    canvas.restore();
    _paintShape(canvas, head, grow: _outlineWidth, color: RepBotColors.outline);

    for (final limb in limbs) {
      _paintBar(canvas, limb);
    }
    canvas.drawCircle(
      head,
      headRadius,
      Paint()
        ..shader = _headShading.createShader(
          Rect.fromCircle(center: head, radius: headRadius),
        ),
    );
    _paintBar(canvas, visor);
    canvas.restore();
  }

  /// Fills the ellipse in [box] with [gradient] stretched to its shape.
  void _paintEllipse(Canvas canvas, Rect box, RadialGradient gradient) {
    final radius = box.width / 2;
    canvas
      ..save()
      ..translate(box.center.dx, box.center.dy)
      ..scale(1, box.height / box.width)
      ..drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..shader = gradient.createShader(
            Rect.fromCircle(center: Offset.zero, radius: radius),
          ),
      )
      ..restore();
  }

  /// The body's shape grown by [grow] all round, in one flat [color].
  void _paintShape(
    Canvas canvas,
    Offset head, {
    required double grow,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    for (final bar in bars) {
      final (from, to) = bar.endsAt(depth);
      canvas.drawLine(from, to, paint..strokeWidth = bar.width + 2 * grow);
    }
    canvas.drawCircle(head, headRadius + grow, paint);
  }

  void _paintBar(Canvas canvas, RepBotBar bar) {
    final (from, to) = bar.endsAt(depth);
    final paint = Paint()
      ..color = bar.color
      ..strokeWidth = bar.width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    if (bar.shine case final shine?) {
      canvas.drawLine(
        from + shine.shift,
        to + shine.shift,
        paint
          ..color = RepBotColors.shine.withValues(alpha: _shineOpacity)
          ..strokeWidth = shine.width,
      );
    }
  }

  @override
  bool shouldRepaint(RepBotPainter oldDelegate) => oldDelegate.depth != depth;
}
