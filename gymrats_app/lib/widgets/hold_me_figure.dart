import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/character_rig.dart';
import '../theme/app_theme.dart';
import 'character_figure.dart' show CharacterFigurePainter;
import 'hold_me_rig.dart';
import 'hold_me_scene.dart';
import 'victory_motion.dart' show VictoryRig;

/// The user's character holding along on a hold stage (A8 spec 3, 4): a
/// [HoldMeFrame] drawn in its box (140 x 160 times the place's scale), the
/// shadow under its feet, the character and the effects around it. Parts
/// may leave the box (a hop, the sweat). Decoration only: screen readers
/// skip it, the HUD and the owner's bubbles tell the state.
class HoldMeFigure extends StatelessWidget {
  const HoldMeFigure({super.key, required this.frame});

  final HoldMeFrame frame;

  @override
  Widget build(BuildContext context) {
    final box = HoldMeRig.standard.box;
    return ExcludeSemantics(
      child: CustomPaint(
        size: box * frame.place.scale,
        painter: HoldMePainter(frame),
      ),
    );
  }
}

/// Paints a [HoldMeFrame] as the mockup draws its character (`HoldMe.dc
/// .html`): the shadow, then the box moved about the feet (across, up,
/// squashed) with the character and its effects in it. A rig pose is drawn
/// by `CharacterFigurePainter` with the home and W5 drawing changes, as the
/// victory scene draws; a drawing shape by shape, its parts turned.
class HoldMePainter extends CustomPainter {
  HoldMePainter(this.frame, {HoldMeRig? rig}) : rig = rig ?? HoldMeRig.standard;

  final HoldMeFrame frame;
  final HoldMeRig rig;

  /// 곰탱이 tips this far about its toes on a warning; the lying ones
  /// flatten this much (the mockup's `tiltT`).
  static const tipDeg = 4.0;
  static const tipPivot = Offset(10, 146);
  static const flattenX = 0.05;
  static const flattenY = 0.1;

  @override
  void paint(Canvas canvas, Size size) {
    final place = frame.place;
    final scale = math.min(
      size.width / rig.box.width,
      size.height / rig.box.height,
    );
    final fx = rig.fx;
    canvas.save();
    canvas.scale(scale);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(frame.shadowX, fx.shadowY),
        width: frame.shadowRx * 2,
        height: fx.shadowRy * 2,
      ),
      Paint()
        ..color = holdMeColor(fx.shadowColor)
            .withValues(alpha: fx.shadowOpacity),
    );
    final feet = rig.feet;
    canvas
      ..save()
      ..translate(frame.jx, -frame.hop)
      ..translate(feet.dx, feet.dy)
      ..scale(frame.sx, frame.sy)
      ..translate(-feet.dx, -feet.dy);
    final drawing = place.drawing;
    if (drawing == null) {
      _paintRig(canvas);
    } else {
      _paintDrawing(canvas, drawing);
    }
    _paintFx(canvas);
    canvas
      ..restore()
      ..restore();
  }

  void _paintRig(Canvas canvas) {
    final w3 = CharacterRig.standard;
    final w5 = VictoryRig.standard;
    final id = frame.place.characterId;
    CharacterFigurePainter(
      rig: w3,
      art: w3.art(id),
      teamColor: AppColors.accent,
      values: frame.pose,
      tags: w5.tagsOf(frame.expression, id),
      patches: w5.characterOf(id).drawPatch,
      flags: frame.place.flags,
      effects: w5.effects,
    ).paint(canvas, Size(w3.boxWidth, w3.boxHeight));
  }

  void _paintDrawing(Canvas canvas, List<HoldMeShape> shapes) {
    final tags = frame.drawingTags;
    for (final shape in shapes) {
      if (!shape.shownWith(tags)) continue;
      canvas.save();
      for (final link in shape.chain) {
        final matrix = link.matrix;
        if (matrix != null) {
          canvas.transform(matrix);
        } else {
          _move(canvas, link.part!);
        }
      }
      paintHoldMeShape(canvas, shape);
      canvas.restore();
    }
  }

  /// Moves [canvas] as the frame moves a drawing's [part].
  void _move(Canvas canvas, String part) {
    final place = frame.place;
    switch (part) {
      case 'tilt' when frame.tilt != 0:
        if (place.drawingName == 'bearPlank') {
          _turn(canvas, tipPivot, tipDeg * frame.tilt);
        } else {
          final feet = rig.feet;
          canvas
            ..translate(feet.dx, feet.dy)
            ..scale(1 + flattenX * frame.tilt, 1 - flattenY * frame.tilt)
            ..translate(-feet.dx, -feet.dy);
        }
      case 'nearArm' when place.nearArm != null:
        _turn(canvas, place.nearArm!.pivot, frame.nearArmDeg);
      case 'head' when place.headTilt != null:
        _turn(canvas, place.headTilt!.pivot, frame.headDeg);
      default:
        // farArm, and a part at rest.
        break;
    }
  }

  void _paintFx(Canvas canvas) {
    final fx = rig.fx;
    for (final drop in frame.sweat) {
      _withOpacity(canvas, drop.opacity, () {
        canvas
          ..translate(drop.at.dx, drop.at.dy)
          ..rotate(drop.rotDeg * math.pi / 180)
          ..scale(drop.scale);
        for (final shape in fx.sweat) {
          paintHoldMeShape(canvas, shape);
        }
      });
    }
    if (frame.shake) {
      final path = Path();
      for (final (from, bend, to) in frame.shakeArcs) {
        path
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(bend.dx, bend.dy, to.dx, to.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fx.shakeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = holdMeColor(fx.shakeColor),
      );
    }
    final spark = frame.spark;
    if (spark != null) {
      _withOpacity(canvas, spark.opacity, () {
        canvas
          ..translate(spark.at.dx, spark.at.dy)
          ..scale(spark.scale);
        for (final shape in fx.spark) {
          paintHoldMeShape(canvas, shape);
        }
      });
    }
    final dust = frame.dust;
    if (dust != null) {
      _withOpacity(canvas, dust.opacity, () {
        canvas
          ..translate(rig.feet.dx, 0)
          ..scale(dust.scaleX, 1);
        for (final shape in fx.dust) {
          paintHoldMeShape(canvas, shape);
        }
      });
    }
  }

  @override
  bool shouldRepaint(HoldMePainter oldDelegate) =>
      !identical(oldDelegate.frame, frame) || oldDelegate.rig != rig;
}

/// Paints the star flying to the bar (A8 spec 4, 5) on the 360 x 390
/// stage: its trail, then the star turned and scaled about its place.
class HoldMeFlightPainter extends CustomPainter {
  HoldMeFlightPainter(this.flight, {HoldMeRig? rig})
    : rig = rig ?? HoldMeRig.standard;

  final HoldMeFlight flight;
  final HoldMeRig rig;

  @override
  void paint(Canvas canvas, Size size) {
    final fx = rig.fx;
    final at = flight.at;
    final trail = Path()..moveTo(at.dx, at.dy);
    for (final point in flight.trail) {
      trail.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = fx.trailWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = holdMeColor(fx.trailColor).withValues(alpha: fx.trailOpacity),
    );
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(flight.rotDeg * math.pi / 180)
      ..scale(flight.scale);
    for (final shape in fx.star) {
      canvas.save();
      for (final link in shape.chain) {
        if (link.matrix case final matrix?) canvas.transform(matrix);
      }
      paintHoldMeShape(canvas, shape);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HoldMeFlightPainter oldDelegate) =>
      oldDelegate.flight != flight || oldDelegate.rig != rig;
}

/// A drawing color: the team's lime or its own.
Color holdMeColor(HoldMeColor color) =>
    color.team ? AppColors.accent : Color(color.argb!);

/// Fills and then outlines [shape] on [canvas] as it stands.
void paintHoldMeShape(Canvas canvas, HoldMeShape shape) {
  final fill = shape.fill;
  if (fill != null) {
    canvas.drawPath(
      shape.path,
      Paint()..color = holdMeColor(fill).withValues(alpha: shape.opacity),
    );
  }
  final stroke = shape.stroke;
  if (stroke != null) {
    canvas.drawPath(
      shape.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = shape.width
        ..strokeCap = shape.cap
        ..strokeJoin = shape.join
        ..color = holdMeColor(stroke)
            .withValues(alpha: shape.strokeOpacity * shape.opacity),
    );
  }
}

void _turn(Canvas canvas, Offset pivot, double deg) {
  canvas
    ..translate(pivot.dx, pivot.dy)
    ..rotate(deg * math.pi / 180)
    ..translate(-pivot.dx, -pivot.dy);
}

/// Runs [paint] in a saved canvas, as one layer at [opacity] (a group's
/// opacity in the mockup) when it is under 1.
void _withOpacity(Canvas canvas, double opacity, VoidCallback paint) {
  if (opacity <= 0) return;
  if (opacity < 1) {
    // Only the paint's alpha counts for a layer.
    canvas.saveLayer(
      null,
      Paint()..color = AppColors.ink.withValues(alpha: opacity),
    );
  } else {
    canvas.save();
  }
  paint();
  canvas.restore();
}
