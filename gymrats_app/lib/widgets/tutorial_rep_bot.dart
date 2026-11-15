import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One limb of RepBot: a straight bar with round ends and a streak of light.
/// Each end moves in a straight line from the top pose to the bottom one.
class RepBotBar {
  const RepBotBar(
    this.ends, {
    required this.width,
    required this.color,
    this.shine = true,
  });

  /// The two ends at the top (x1, y1, x2, y2), then at the bottom.
  final List<double> ends;
  final double width;
  final Color color;

  /// Whether a see-through white streak runs along it.
  final bool shine;

  /// Its two ends at [depth] (0 top, 1 bottom).
  (Offset, Offset) endsAt(double depth) => (
    Offset(_mix(ends[0], ends[4], depth), _mix(ends[1], ends[5], depth)),
    Offset(_mix(ends[2], ends[6], depth), _mix(ends[3], ends[7], depth)),
  );
}

double _mix(double top, double bottom, double depth) =>
    top + (bottom - top) * depth;

/// RepBot in one exercise, from its top pose (depth 0) to its bottom one
/// (depth 1), in its own coordinates.
///
/// The side push-up is home's former RepBot (`lobby_rep_bot.dart`, W1,
/// removed by W4); the front squat and the front push-up are drawn the same
/// way for the tutorial.
class RepBotFigure {
  const RepBotFigure({
    required this.viewBox,
    required this.limbs,
    required this.visor,
    required this.headTop,
    required this.headBottom,
    required this.headRadius,
    this.hip,
    this.floor,
    this.shadow,
  });

  /// The part of the coordinates drawn, as large as fits and centered.
  final Rect viewBox;

  /// Farthest first, so nearer ones cover them.
  final List<RepBotBar> limbs;

  /// Drawn over the head in the team color.
  final RepBotBar visor;
  final Offset headTop;
  final Offset headBottom;
  final double headRadius;

  /// The bar whose middle is the hip, for a depth line; null for none.
  final RepBotBar? hip;

  /// The light on the floor and the shadow over it, as ellipses.
  final Rect? floor;
  final Rect? shadow;

  Offset headAt(double depth) => Offset(
    _mix(headTop.dx, headBottom.dx, depth),
    _mix(headTop.dy, headBottom.dy, depth),
  );

  /// Push-up from the side, head to the left.
  static const pushUpSide = RepBotFigure(
    viewBox: Rect.fromLTWH(24, 76, 340, 280),
    headTop: Offset(97.6, 129.9),
    headBottom: Offset(80.5, 268.7),
    headRadius: 37.9,
    floor: Rect.fromLTRB(18, 228, 410, 356),
    shadow: Rect.fromLTRB(110, 252, 334, 320),
    visor: RepBotBar(
      [62.3, 119.5, 89.2, 123.1, 45.5, 261.6, 71.3, 269.9],
      width: 13.2,
      color: AppColors.opponent,
      shine: false,
    ),
    limbs: [
      RepBotBar(
        [301.6, 207.5, 310.3, 217.2, 301.6, 207.5, 310.3, 217.2],
        width: 13,
        color: RepBotColors.footL,
      ),
      RepBotBar(
        [332.0, 213.2, 340.2, 223.1, 332.0, 213.2, 340.2, 223.1],
        width: 13.4,
        color: RepBotColors.footR,
      ),
      RepBotBar(
        [258.8, 194.6, 301.6, 207.5, 255.2, 220.6, 301.6, 207.5],
        width: 19.9,
        color: RepBotColors.shinL,
      ),
      RepBotBar(
        [295.2, 201.3, 332.0, 213.2, 291.3, 228.2, 332.0, 213.2],
        width: 20.5,
        color: RepBotColors.shinR,
      ),
      RepBotBar(
        [201.8, 177.7, 258.8, 194.6, 194.2, 237.0, 255.2, 220.6],
        width: 30.1,
        color: RepBotColors.thighL,
      ),
      RepBotBar(
        [248.9, 186.0, 295.2, 201.3, 240.4, 248.2, 291.3, 228.2],
        width: 31.4,
        color: RepBotColors.thighR,
      ),
      RepBotBar(
        [201.8, 177.7, 248.9, 186.0, 194.2, 237.0, 240.4, 248.2],
        width: 38.9,
        color: RepBotColors.pelvis,
      ),
      RepBotBar(
        [109.9, 287.8, 91.2, 299.2, 109.9, 287.8, 91.2, 299.2],
        width: 16.7,
        color: RepBotColors.handL,
      ),
      RepBotBar(
        [106.3, 223.5, 109.9, 287.8, 94.3, 226.5, 109.9, 287.8],
        width: 20.7,
        color: RepBotColors.forearmL,
      ),
      RepBotBar(
        [145.5, 157.0, 224.8, 181.7, 131.7, 269.8, 216.7, 242.5],
        width: 79,
        color: RepBotColors.torso,
      ),
      RepBotBar(
        [106.9, 150.7, 106.3, 223.5, 94.3, 258.7, 94.3, 226.5],
        width: 25.5,
        color: RepBotColors.upperArmL,
      ),
      RepBotBar(
        [206.2, 319.3, 192.4, 334.5, 206.2, 319.3, 192.4, 334.5],
        width: 18.7,
        color: RepBotColors.near,
      ),
      RepBotBar(
        [200.3, 247.2, 206.2, 319.3, 257.2, 268.8, 206.2, 319.3],
        width: 23,
        color: RepBotColors.near,
      ),
      RepBotBar(
        [106.9, 150.7, 187.9, 164.0, 94.3, 258.7, 172.8, 282.1],
        width: 37.4,
        color: RepBotColors.near,
      ),
      RepBotBar(
        [187.9, 164.0, 200.3, 247.2, 172.8, 282.1, 257.2, 268.8],
        width: 28.2,
        color: RepBotColors.upperArmR,
      ),
      RepBotBar(
        [125.7, 145.1, 97.6, 129.9, 110.7, 271.0, 80.5, 268.7],
        width: 27.7,
        color: RepBotColors.neck,
      ),
    ],
  );

  static const _squatPelvis = RepBotBar(
    [130, 224, 170, 224, 130, 282, 170, 282],
    width: 40,
    color: RepBotColors.pelvis,
  );

  /// Squat facing the phone: standing (0) to the deepest squat (1), knees
  /// out and arms forward.
  static const squatFront = RepBotFigure(
    viewBox: Rect.fromLTWH(20, 0, 260, 400),
    headTop: Offset(150, 58),
    headBottom: Offset(150, 150),
    headRadius: 34,
    hip: _squatPelvis,
    floor: Rect.fromLTRB(30, 330, 270, 396),
    shadow: Rect.fromLTRB(80, 346, 220, 380),
    visor: RepBotBar(
      [130, 60, 170, 60, 130, 152, 170, 152],
      width: 12,
      color: AppColors.opponent,
      shine: false,
    ),
    limbs: [
      RepBotBar(
        [126, 358, 112, 364, 110, 358, 96, 364],
        width: 15,
        color: RepBotColors.footL,
      ),
      RepBotBar(
        [174, 358, 188, 364, 190, 358, 204, 364],
        width: 15,
        color: RepBotColors.footR,
      ),
      RepBotBar(
        [128, 292, 126, 352, 90, 300, 110, 352],
        width: 22,
        color: RepBotColors.shinL,
      ),
      RepBotBar(
        [172, 292, 174, 352, 210, 300, 190, 352],
        width: 22,
        color: RepBotColors.shinR,
      ),
      RepBotBar(
        [132, 230, 128, 292, 130, 286, 90, 300],
        width: 31,
        color: RepBotColors.thighL,
      ),
      RepBotBar(
        [168, 230, 172, 292, 170, 286, 210, 300],
        width: 31,
        color: RepBotColors.thighR,
      ),
      _squatPelvis,
      RepBotBar(
        [150, 128, 150, 204, 150, 214, 150, 266],
        width: 76,
        color: RepBotColors.torso,
      ),
      RepBotBar(
        [108, 118, 192, 118, 108, 204, 192, 204],
        width: 38,
        color: RepBotColors.near,
      ),
      RepBotBar(
        [104, 120, 94, 186, 106, 206, 116, 232],
        width: 25,
        color: RepBotColors.upperArmL,
      ),
      RepBotBar(
        [196, 120, 206, 186, 194, 206, 184, 232],
        width: 25,
        color: RepBotColors.upperArmR,
      ),
      RepBotBar(
        [94, 186, 92, 240, 116, 232, 128, 246],
        width: 21,
        color: RepBotColors.forearmL,
      ),
      RepBotBar(
        [206, 186, 208, 240, 184, 232, 172, 246],
        width: 21,
        color: RepBotColors.near,
      ),
      RepBotBar(
        [92, 246, 92, 258, 131, 250, 134, 254],
        width: 17,
        color: RepBotColors.handL,
      ),
      RepBotBar(
        [208, 246, 208, 258, 169, 250, 166, 254],
        width: 17,
        color: RepBotColors.near,
      ),
      RepBotBar(
        [150, 88, 150, 106, 150, 180, 150, 196],
        width: 26,
        color: RepBotColors.neck,
      ),
    ],
  );

  /// The push-up start seen by the phone on the floor ahead: arms straight
  /// down to the hands, the body going away behind. Laid out on a 300 x 400
  /// camera panel to fill the setup guide's outline (`PoseSilhouetteGuide`).
  static const pushUpFront = RepBotFigure(
    viewBox: Rect.fromLTWH(0, 0, 300, 400),
    headTop: Offset(150, 52),
    headBottom: Offset(150, 52),
    headRadius: 36,
    visor: RepBotBar(
      [128, 54, 172, 54, 128, 54, 172, 54],
      width: 12,
      color: AppColors.opponent,
      shine: false,
    ),
    limbs: [
      RepBotBar(
        [140, 318, 140, 326, 140, 318, 140, 326],
        width: 18,
        color: RepBotColors.footL,
      ),
      RepBotBar(
        [160, 318, 160, 326, 160, 318, 160, 326],
        width: 18,
        color: RepBotColors.footR,
      ),
      RepBotBar(
        [140, 236, 140, 312, 140, 236, 140, 312],
        width: 22,
        color: RepBotColors.shinL,
      ),
      RepBotBar(
        [160, 236, 160, 312, 160, 236, 160, 312],
        width: 22,
        color: RepBotColors.shinR,
      ),
      RepBotBar(
        [150, 150, 150, 222, 150, 150, 150, 222],
        width: 74,
        color: RepBotColors.torso,
      ),
      RepBotBar(
        [98, 120, 202, 120, 98, 120, 202, 120],
        width: 40,
        color: RepBotColors.near,
      ),
      RepBotBar(
        [90, 128, 80, 242, 90, 128, 80, 242],
        width: 30,
        color: RepBotColors.upperArmL,
      ),
      RepBotBar(
        [210, 128, 220, 242, 210, 128, 220, 242],
        width: 30,
        color: RepBotColors.upperArmR,
      ),
      RepBotBar(
        [80, 242, 72, 352, 80, 242, 72, 352],
        width: 26,
        color: RepBotColors.forearmL,
      ),
      RepBotBar(
        [220, 242, 228, 352, 220, 242, 228, 352],
        width: 26,
        color: RepBotColors.near,
      ),
      RepBotBar(
        [48, 374, 84, 374, 48, 374, 84, 374],
        width: 22,
        color: RepBotColors.handL,
      ),
      RepBotBar(
        [216, 374, 252, 374, 216, 374, 252, 374],
        width: 22,
        color: RepBotColors.near,
      ),
      RepBotBar(
        [150, 84, 150, 104, 150, 84, 150, 104],
        width: 30,
        color: RepBotColors.neck,
      ),
    ],
  );
}

/// RepBot standing still at one [depth] of [figure], for a tutorial
/// picture. With [passDepth] a dashed line marks where the hip must reach,
/// labelled [passLabel].
class TutorialRepBot extends StatelessWidget {
  const TutorialRepBot({
    super.key,
    required this.figure,
    this.depth = 0,
    this.passDepth,
    this.passLabel = '기준 깊이',
  });

  final RepBotFigure figure;
  final double depth;
  final double? passDepth;
  final String passLabel;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: figure.viewBox.size,
      painter: RepBotPainter(
        figure: figure,
        depth: depth,
        passDepth: passDepth,
        passLabel: passLabel,
        labelStyle: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.ink),
      ),
    );
  }
}

/// Paints [figure] at [depth]: a pink light and a shadow on the floor, then
/// the body with a soft pink glow and a thin outline around it.
class RepBotPainter extends CustomPainter {
  const RepBotPainter({
    required this.figure,
    required this.depth,
    this.passDepth,
    this.passLabel = '',
    this.labelStyle,
  });

  final RepBotFigure figure;
  final double depth;
  final double? passDepth;
  final String passLabel;
  final TextStyle? labelStyle;

  static const _outlineWidth = 1.6;
  static const _glowSpread = 5.0;
  static const _glowBlur = 9.0;
  static const _glowOpacity = 0.5;
  static const _shineOpacity = 0.55;
  static const _dash = 12.0;
  static const _gap = 10.0;

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
    final box = figure.viewBox;
    final scale = math.min(size.width / box.width, size.height / box.height);
    canvas
      ..save()
      ..translate(
        (size.width - box.width * scale) / 2,
        (size.height - box.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-box.left, -box.top);

    if (figure.floor case final floor?) {
      _paintEllipse(
        canvas,
        floor,
        RadialGradient(
          colors: [
            AppColors.opponent.withValues(alpha: 0.3),
            AppColors.opponent.withValues(alpha: 0.1),
            AppColors.opponent.withValues(alpha: 0),
          ],
          stops: const [0, 0.6, 1],
        ),
      );
    }
    if (figure.shadow case final shadow?) {
      _paintEllipse(
        canvas,
        shadow,
        RadialGradient(
          colors: [
            RepBotColors.shadow.withValues(alpha: 0.22),
            RepBotColors.shadow.withValues(alpha: 0),
          ],
        ),
      );
    }

    final head = figure.headAt(depth);
    // The glow and the outline are the whole body grown a little, under the
    // body, so limbs that overlap show no line between them.
    canvas.saveLayer(
      box.inflate(60),
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

    for (final limb in figure.limbs) {
      _paintBar(canvas, limb);
    }
    canvas.drawCircle(
      head,
      figure.headRadius,
      Paint()
        ..shader = _headShading.createShader(
          Rect.fromCircle(center: head, radius: figure.headRadius),
        ),
    );
    _paintBar(canvas, figure.visor);

    if ((passDepth, figure.hip) case (final pass?, final hip?)) {
      _paintPassLine(canvas, box, hip, pass, scale);
    }
    canvas.restore();
  }

  /// The y of [hip]'s middle at [depth].
  static double hipY(RepBotBar hip, double depth) {
    final (from, to) = hip.endsAt(depth);
    return (from.dy + to.dy) / 2;
  }

  void _paintPassLine(
    Canvas canvas,
    Rect box,
    RepBotBar hip,
    double pass,
    double scale,
  ) {
    final y = hipY(hip, pass);
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2 / scale;
    final label = TextPainter(
      text: TextSpan(text: passLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final end = box.right - label.width / scale - _gap;
    for (var x = box.left; x < end; x += _dash + _gap) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + _dash, end), y), paint);
    }
    canvas
      ..save()
      ..translate(box.right - label.width / scale, y - label.height / scale / 2)
      ..scale(1 / scale);
    label.paint(canvas, Offset.zero);
    canvas.restore();
  }

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

  void _paintShape(
    Canvas canvas,
    Offset head, {
    required double grow,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    for (final bar in [...figure.limbs, figure.visor]) {
      final (from, to) = bar.endsAt(depth);
      canvas.drawLine(from, to, paint..strokeWidth = bar.width + 2 * grow);
    }
    canvas.drawCircle(head, figure.headRadius + grow, paint);
  }

  void _paintBar(Canvas canvas, RepBotBar bar) {
    final (from, to) = bar.endsAt(depth);
    final paint = Paint()
      ..color = bar.color
      ..strokeWidth = bar.width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    if (bar.shine) {
      final shift = Offset(-bar.width * 0.1, -bar.width * 0.17);
      canvas.drawLine(
        from + shift,
        to + shift,
        paint
          ..color = RepBotColors.shine.withValues(alpha: _shineOpacity)
          ..strokeWidth = bar.width * 0.3,
      );
    }
  }

  @override
  bool shouldRepaint(RepBotPainter oldDelegate) =>
      oldDelegate.figure != figure ||
      oldDelegate.depth != depth ||
      oldDelegate.passDepth != passDepth ||
      oldDelegate.passLabel != passLabel ||
      oldDelegate.labelStyle != labelStyle;
}
