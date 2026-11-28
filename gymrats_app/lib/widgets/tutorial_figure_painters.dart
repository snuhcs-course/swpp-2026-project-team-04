import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tutorial_person.dart';

/// Paints a side-view person as an ink silhouette (A12 spec 1): the far leg
/// and arm gray, the rest ink, the arm in front with a thin white edge so
/// it reads over the body. [shapes] are already placed on the canvas;
/// [mirrored] turns the person to face right about [mirrorAxis].
class TutorialSidePainter extends CustomPainter {
  const TutorialSidePainter({
    required this.shapes,
    required this.armEdge,
    this.mirrored = false,
    this.mirrorAxis = 0,
  });

  final SideShapes shapes;

  /// The white edge around the near arm: 3 on page 1's person, 2.6 on the
  /// grade pages' (as designed).
  final double armEdge;
  final bool mirrored;

  /// The x the person is turned about when [mirrored].
  final double mirrorAxis;

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas
        ..save()
        ..translate(2 * mirrorAxis, 0)
        ..scale(-1, 1);
    }
    final far = Paint()..color = AppColors.textSecondary;
    final ink = Paint()..color = AppColors.ink;
    for (final piece in [...shapes.farLeg, ...shapes.farArm]) {
      canvas.drawPath(piece, far);
    }
    for (final piece in [
      ...shapes.leg,
      ...shapes.torso,
      ...shapes.neck,
      ...shapes.head,
      ...shapes.nose,
    ]) {
      canvas.drawPath(piece, ink);
    }
    paintEdged(canvas, shapes.arm, armEdge);
    if (mirrored) canvas.restore();
  }

  /// [pieces] in ink with a white edge [edge] wide around them as a whole:
  /// every piece's stroke first, then every fill over it, so the edge shows
  /// only outside (the design's `paint-order: stroke`).
  static void paintEdged(Canvas canvas, List<Path> pieces, double edge) {
    final white = Paint()
      ..color = AppColors.card
      ..style = PaintingStyle.stroke
      ..strokeWidth = edge
      ..strokeJoin = StrokeJoin.round;
    final ink = Paint()..color = AppColors.ink;
    for (final piece in pieces) {
      canvas.drawPath(piece, white);
    }
    for (final piece in pieces) {
      canvas.drawPath(piece, ink);
    }
  }

  @override
  bool shouldRepaint(TutorialSidePainter oldDelegate) =>
      oldDelegate.shapes != shapes ||
      oldDelegate.armEdge != armEdge ||
      oldDelegate.mirrored != mirrored ||
      oldDelegate.mirrorAxis != mirrorAxis;
}

/// The camera picture behind a front-view person (`cam2.js`, `cam3.js`): a
/// wall, lighter above and a floor below, in the camera's 290 x 387 box.
class TutorialCameraBackdropPainter extends CustomPainter {
  const TutorialCameraBackdropPainter();

  /// Where the lighter wall ends and the floor begins.
  static const _wallEnd = 190.0;
  static const _floorTop = 300.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = AppColors.pictogramFloor)
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, _wallEnd),
        Paint()..color = AppColors.border,
      )
      ..drawRect(
        Rect.fromLTRB(0, _floorTop, size.width, size.height),
        Paint()..color = HoldColors.cameraBox,
      );
  }

  @override
  bool shouldRepaint(TutorialCameraBackdropPainter oldDelegate) => false;
}

/// Paints a front-view person on the camera (`cam2.js`, `cam3.js`): the far
/// legs dark gray, the belly near-ink, the rest ink, held arms with a white
/// edge and the held fingers' gray line.
class TutorialFrontPainter extends CustomPainter {
  const TutorialFrontPainter(this.figure);

  final FrontFigure figure;

  /// The held arms' white edge, and the fingers' line.
  static const _armEdge = 3.5;
  static const _claspWidth = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final far = Paint()..color = AppColors.arcadeBand;
    final belly = Paint()..color = HoldColors.softInk;
    final ink = Paint()..color = AppColors.ink;
    for (final piece in figure.far) {
      canvas.drawPath(piece, far);
    }
    for (final piece in figure.belly) {
      canvas.drawPath(piece, belly);
    }
    for (final piece in figure.body) {
      canvas.drawPath(piece, ink);
    }
    TutorialSidePainter.paintEdged(canvas, figure.arms, _armEdge);
    final clasp = figure.clasp;
    if (clasp != null) {
      canvas.drawPath(
        clasp,
        Paint()
          ..color = AppColors.textSecondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = _claspWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(TutorialFrontPainter oldDelegate) =>
      oldDelegate.figure != figure;
}

/// Page 1's person doing the exercise over and over, as designed
/// (`TutFigSide`: a push-up every 2 s, a squat every 2.4 s), facing left
/// toward the phone, in a 220 x 200 box. Still at the top of the rep when
/// the device asks for reduced motion.
class TutorialSidePerson extends StatefulWidget {
  const TutorialSidePerson({super.key, required this.squat});

  final bool squat;

  /// The box, and where in it the person stands: the middle of their
  /// width at [_centerX] (from the pose at the top), the floor at
  /// [_floorY], 1.75 points a body unit.
  static const size = Size(220, 200);
  static const _centerX = 110.0;
  static const _floorY = 186.0;
  static const scale = 1.75;

  /// The white edge around the near arm here.
  static const _armEdge = 3.0;

  /// The person's shapes [ms] into the loop.
  static SideShapes shapesAt(double ms, {required bool squat}) {
    final pose = squat ? TutorialSidePose.squat : TutorialSidePose.push;
    final k = TutorialSide.phase(ms, squat: squat);
    final placed = TutorialSide.place(
      TutorialSide.joints(pose, k),
      scale: scale,
      centerX: _centerX,
      floorY: _floorY,
      middle: TutorialSide.middleOf(TutorialSide.joints(pose, 0)),
    );
    return TutorialSide.shapes(placed, scale);
  }

  @override
  State<TutorialSidePerson> createState() => _TutorialSidePersonState();
}

class _TutorialSidePersonState extends State<TutorialSidePerson>
    with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(
    vsync: this,
    duration: TutorialSide.loopOf(squat: widget.squat),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _loop
        ..stop()
        ..value = 0;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final length = TutorialSide.loopOf(squat: widget.squat).inMilliseconds;
    return SizedBox.fromSize(
      size: TutorialSidePerson.size,
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) => CustomPaint(
          painter: TutorialSidePainter(
            shapes: TutorialSidePerson.shapesAt(
              _loop.value * length,
              squat: widget.squat,
            ),
            armEdge: TutorialSidePerson._armEdge,
          ),
        ),
      ),
    );
  }
}
