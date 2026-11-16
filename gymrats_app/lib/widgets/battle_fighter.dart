import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'battle_art_path.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_model.dart';

/// Builds the picture of a fighter in a [pose] for a [side].
///
/// The stage depends on nothing else about a fighter: it places, turns,
/// sizes, flashes and mirrors whatever this returns. The picture is
/// [BattleFighter.size] large, faces right, and stands with its feet on
/// [BattleFighter.foot]; the opponent's is drawn mirrored by the stage. It
/// may draw outside its box (the attack's fist does).
typedef BattleFighterBuilder = Widget Function(
  BattlePose pose,
  BattleSide side,
);

/// The stand-in fighter, until the characters arrive: the design's five
/// poses, in the player's team color.
class BattleFighter extends StatelessWidget {
  const BattleFighter({super.key, required this.pose, required this.side});

  final BattlePose pose;
  final BattleSide side;

  /// The box every pose is drawn in.
  static const size = Size(140, 160);

  /// Where the feet stand in that box: the point the stage moves, turns and
  /// sizes the picture around.
  static const foot = Offset(70, 150);

  /// The stage's default [BattleFighterBuilder].
  static Widget standIn(BattlePose pose, BattleSide side) =>
      BattleFighter(pose: pose, side: side);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: BattleFighterPainter(
        pose: pose,
        color: side == BattleSide.me ? AppColors.accent : AppColors.opponent,
      ),
    );
  }
}

/// Paints one pose of the stand-in fighter, a port of the design's drawing
/// (FxFighter): an ink body with the team [color] on its outline, headband,
/// gloves and feet.
class BattleFighterPainter extends CustomPainter {
  const BattleFighterPainter({required this.pose, required this.color});

  final BattlePose pose;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / BattleFighter.size.width,
      size.height / BattleFighter.size.height,
    );
    switch (pose) {
      case BattlePose.idle:
        _foot(canvas, 48, 143);
        _foot(canvas, 88, 143);
        _turned(canvas, 4, () {
          _ear(canvas, 'M36 70L16 60L20 78Z');
          _body(canvas, const Rect.fromLTWH(34, 36, 68, 102));
          _headband(canvas, 'M36 68Q68 80 100 66');
          _eye(canvas, 74, 95, 6.5, 10);
          _eye(canvas, 91, 95, 6, 10);
        });
        _glove(canvas, 94, 121, 15);
        _glove(canvas, 112, 103, 17);
      case BattlePose.attack:
        _foot(canvas, 34, 143);
        _foot(canvas, 100, 143);
        _turned(canvas, 15, () {
          _ear(canvas, 'M36 70L6 64L12 84Z');
          _body(canvas, const Rect.fromLTWH(34, 36, 68, 102));
          _headband(canvas, 'M36 68Q68 80 100 66');
          _eye(canvas, 76, 95, 6.5, 7);
          _eye(canvas, 93, 95, 6, 7);
        });
        _glove(canvas, 84, 125, 14);
        _glove(canvas, 136, 96, 21, edge: 3.5);
        _line(
          canvas,
          'M126 90Q136 84 146 90',
          AppColors.ink.withValues(alpha: 0.45),
          2.5,
        );
      case BattlePose.hit:
        _foot(canvas, 50, 143);
        _foot(canvas, 86, 136, turn: -26);
        _turned(canvas, -18, () {
          _ear(canvas, 'M36 70L22 86L40 88Z');
          _body(canvas, const Rect.fromLTWH(34, 36, 68, 102));
          _headband(canvas, 'M36 68Q68 80 100 66');
          _line(
            canvas,
            'M66 87L78 95L66 103M98 87L86 95L98 103',
            AppColors.card,
            4.5,
          );
        });
        _glove(canvas, 8, 112, 15);
        _glove(canvas, 98, 56, 16);
        _line(canvas, 'M84 22L92 12M98 32H110M72 14L72 4', AppColors.ink, 3);
      case BattlePose.knockedOut:
        _foot(canvas, 126, 118, upright: true);
        _foot(canvas, 130, 143);
        _body(canvas, const Rect.fromLTWH(14, 92, 104, 56));
        _headband(canvas, 'M58 93Q66 120 56 147');
        _line(
          canvas,
          'M22 104L31 113M31 104L22 113M38 104L47 113M47 104L38 113',
          AppColors.card,
          4,
        );
        _glove(canvas, 76, 86, 15);
        _glove(canvas, 4, 142, 15);
        _dizzyStar(canvas, 'M24 60l3.5 8 8 3.5-8 3.5-3.5 8-3.5-8-8-3.5 8-3.5z');
        _dizzyStar(
          canvas,
          'M50 50l2.5 5.5 5.5 2.5-5.5 2.5-2.5 5.5-2.5-5.5-5.5-2.5 5.5-2.5z',
        );
      case BattlePose.win:
        _foot(canvas, 50, 143);
        _foot(canvas, 86, 143);
        _ear(canvas, 'M36 72L16 62L20 80Z');
        _body(canvas, const Rect.fromLTWH(34, 38, 68, 100));
        _headband(canvas, 'M36 70Q68 82 100 68');
        _line(
          canvas,
          'M62 100q7.5-12 15 0M83 100q7-12 14 0',
          AppColors.card,
          4.5,
        );
        _glove(canvas, 24, 34, 17);
        _glove(canvas, 110, 28, 17);
        _line(canvas, 'M4 12l7 7M132 6l-7 7M68 16V5', AppColors.ink, 3);
    }
    canvas.restore();
  }

  Paint _fill(Color color) => Paint()..color = color;

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Draws [draw] turned by [degrees] around the hips, as the upright poses
  /// lean.
  void _turned(Canvas canvas, double degrees, VoidCallback draw) {
    const hips = Offset(68, 138);
    canvas.save();
    canvas.translate(hips.dx, hips.dy);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-hips.dx, -hips.dy);
    draw();
    canvas.restore();
  }

  /// A foot: a flat oval in the team color, or an [upright] one for the foot
  /// in the air of the knocked-out pose.
  void _foot(
    Canvas canvas,
    double x,
    double y, {
    double turn = 0,
    bool upright = false,
  }) {
    final oval = Rect.fromCenter(
      center: Offset.zero,
      width: upright ? 17 : 34,
      height: upright ? 34 : 17,
    );
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(turn * math.pi / 180);
    canvas.drawOval(oval, _fill(color));
    canvas.drawOval(oval, _stroke(AppColors.ink, 3));
    canvas.restore();
  }

  void _glove(
    Canvas canvas,
    double x,
    double y,
    double radius, {
    double edge = 3,
  }) {
    canvas.drawCircle(Offset(x, y), radius, _fill(color));
    canvas.drawCircle(Offset(x, y), radius, _stroke(AppColors.ink, edge));
  }

  /// The headband's loose end behind the head.
  void _ear(Canvas canvas, String data) {
    final path = battleArtPath(data);
    canvas.drawPath(path, _fill(color));
    canvas.drawPath(path, _stroke(AppColors.ink, 2.5));
  }

  /// The pill-shaped ink body: an ink edge outside a team-colored one.
  void _body(Canvas canvas, Rect box) {
    final pill = RRect.fromRectAndRadius(
      box,
      Radius.circular(box.shortestSide / 2),
    );
    canvas.drawRRect(pill, _fill(AppColors.ink));
    canvas.drawRRect(pill, _stroke(AppColors.ink, 11));
    canvas.drawRRect(pill, _stroke(color, 5.5));
  }

  void _headband(Canvas canvas, String data) => _line(canvas, data, color, 8);

  void _eye(Canvas canvas, double x, double y, double rx, double ry) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
      _fill(AppColors.card),
    );
  }

  void _line(Canvas canvas, String data, Color color, double width) =>
      canvas.drawPath(battleArtPath(data), _stroke(color, width));

  void _dizzyStar(Canvas canvas, String data) {
    final path = battleArtPath(data);
    canvas.drawPath(path, _fill(AppColors.warning));
    canvas.drawPath(path, _stroke(AppColors.ink, 2));
  }

  @override
  bool shouldRepaint(BattleFighterPainter oldDelegate) =>
      oldDelegate.pose != pose || oldDelegate.color != color;
}
