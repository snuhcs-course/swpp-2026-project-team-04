import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/character_idle_motion.dart';
import '../models/character_rig.dart';
import '../theme/app_theme.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_model.dart';

/// One character in one pose, in a team's color (W3 spec 3 and 6).
///
/// It is the box of the rig (140 x 160) times [scale], faces right and
/// stands with its feet on (70, 150) of that box, like the stage's fighters;
/// parts may leave the box (the attack's fist does). A parent that forces
/// another size gets the box scaled the same both ways and centred. An unknown
/// [characterId] draws the default character (`mouse`). It does not move:
/// the stage and the selection preview move it.
class CharacterFigure extends StatelessWidget {
  const CharacterFigure({
    super.key,
    required this.characterId,
    this.pose = BattlePose.idle,
    this.side = BattleSide.me,
    this.flash = false,
    this.scale = 1,
  });

  final String characterId;
  final BattlePose pose;

  /// Whose team color it wears: lime for me, pink for the opponent.
  final BattleSide side;

  /// The white flash of a blow: fills turn white, ink outlines stay.
  final bool flash;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final rig = CharacterRig.standard;
    return CustomPaint(
      size: Size(rig.boxWidth * scale, rig.boxHeight * scale),
      painter: CharacterFigurePainter(
        rig: rig,
        art: rig.art(characterId),
        pose: characterPoseKey(pose),
        teamColor: side == BattleSide.me
            ? AppColors.accent
            : AppColors.opponent,
        flash: flash,
      ),
    );
  }
}

/// A [CharacterFigure] standing idle and moving as its character does
/// (spec 6 "대기 움직임"): hopping, rocking or stretching about its feet,
/// on its own clock. Off when the device asks for reduced motion. For the
/// selection screen's preview, and anywhere a character stands alone.
class CharacterIdleFigure extends StatefulWidget {
  const CharacterIdleFigure({
    super.key,
    required this.characterId,
    this.side = BattleSide.me,
    this.scale = 1,
  });

  final String characterId;
  final BattleSide side;
  final double scale;

  @override
  State<CharacterIdleFigure> createState() => _CharacterIdleFigureState();
}

class _CharacterIdleFigureState extends State<CharacterIdleFigure>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(
    (elapsed) => _now.value = elapsed.inMicroseconds / 1000,
  );

  /// Milliseconds since the figure appeared.
  final _now = ValueNotifier<double>(0);
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _ticker.stop();
      _now.value = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rig = CharacterRig.standard;
    final motion = rig.art(widget.characterId).idleMotion;
    final scale = widget.scale;
    final figure = CharacterFigure(
      characterId: widget.characterId,
      side: widget.side,
      scale: scale,
    );
    return ValueListenableBuilder<double>(
      valueListenable: _now,
      builder: (context, now, child) {
        final idle = _still ? IdleSample.rest : motion.sampleAt(now);
        return Transform(
          transform: Matrix4.translationValues(0, -idle.up * scale, 0)
              .multiplied(Matrix4.rotationZ(idle.rockDeg * math.pi / 180))
              .multiplied(Matrix4.diagonal3Values(idle.scaleX, idle.scaleY, 1)),
          origin: Offset(rig.anchorX * scale, rig.anchorY * scale),
          child: child,
        );
      },
      child: figure,
    );
  }
}

/// The two characters on a battle stage: mine and the opponent's (W3).
class BattleCharacters {
  const BattleCharacters({required this.me, required this.opponent});

  /// Character ids; an unknown one draws the default (`mouse`).
  final String me;
  final String opponent;

  String of(BattleSide side) => side == BattleSide.me ? me : opponent;

  /// What these characters change in the stage's effects (spec 6): their
  /// own idle motions, the opponent's running 230 ms later, and the hit
  /// star where the blows land.
  BattleFxCast get cast {
    final rig = CharacterRig.standard;
    return BattleFxCast(
      meIdle: rig.art(me).idleMotion,
      opponentIdle: rig.art(opponent).idleMotion,
      opponentIdleOffsetMs: rig.idleOpponentOffsetMs,
      hitStarDx: rig.hitStarDx,
      hitStarUp: rig.hitStarUp,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BattleCharacters && other.me == me && other.opponent == opponent;

  @override
  int get hashCode => Object.hash(me, opponent);
}

/// The rig's key for a stage pose.
String characterPoseKey(BattlePose pose) => switch (pose) {
  BattlePose.idle => 'idle',
  BattlePose.attack => 'atk',
  BattlePose.hit => 'hit',
  BattlePose.knockedOut => 'ko',
  BattlePose.win => 'win',
};

/// Paints a character from the rig, as the reference renderer does: the
/// shapes in order, each one skipped when its pose list leaves this pose
/// out, moved by its chain, then filled and outlined.
///
/// The paths of a character and pose are built once and kept.
class CharacterFigurePainter extends CustomPainter {
  CharacterFigurePainter({
    required this.rig,
    required this.art,
    required this.pose,
    required this.teamColor,
    this.flash = false,
  });

  final CharacterRig rig;
  final CharacterArt art;

  /// The pose key (idle, atk, hit, ko, win).
  final String pose;
  final Color teamColor;
  final bool flash;

  static final _shapes = <(CharacterRig, String, String), List<_Shape>>{};

  /// The built shapes of [art] in [pose]: each one's moves and path.
  static List<_Shape> _shapesOf(
    CharacterRig rig,
    CharacterArt art,
    String pose,
  ) {
    return _shapes.putIfAbsent((rig, art.id, pose), () {
      final table =
          art.poses[pose] ?? (throw ArgumentError.value(pose, 'pose'));
      return [
        for (final op in art.ops)
          if (op.showsIn(pose))
            _Shape(
              transforms: op.transformsIn(table),
              path: _pathOf(op.prim, table),
              prim: op.prim,
            ),
      ];
    });
  }

  static Path _pathOf(RigPrim prim, RigPoseTable table) {
    switch (prim.shape) {
      case RigShape.circle:
        return Path()..addOval(
          Rect.fromCircle(center: Offset(prim.cx, prim.cy), radius: prim.r),
        );
      case RigShape.ellipse:
        return Path()..addOval(
          Rect.fromCenter(
            center: Offset(prim.cx, prim.cy),
            width: prim.rx * 2,
            height: prim.ry * 2,
          ),
        );
      case RigShape.rect:
        return Path()..addRRect(
          RRect.fromRectXY(
            Rect.fromLTWH(prim.x, prim.y, prim.w, prim.h),
            prim.rx,
            prim.rx,
          ),
        );
      case RigShape.path:
        final path = Path();
        for (final segment in prim.segmentsIn(table)) {
          final v = segment.values;
          switch (segment.command) {
            case RigCommand.move:
              path.moveTo(v[0], v[1]);
            case RigCommand.line:
              path.lineTo(v[0], v[1]);
            case RigCommand.quad:
              path.quadraticBezierTo(v[0], v[1], v[2], v[3]);
            case RigCommand.cubic:
              path.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
            case RigCommand.arc:
              path.arcToPoint(
                Offset(v[5], v[6]),
                radius: Radius.elliptical(v[0], v[1]),
                rotation: v[2],
                largeArc: v[3] != 0,
                clockwise: v[4] != 0,
              );
            case RigCommand.close:
              path.close();
          }
        }
        return path;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The same scale both ways, the box centred: a parent of another shape
    // gets the character whole, not stretched.
    final scale = math.min(
      size.width / rig.boxWidth,
      size.height / rig.boxHeight,
    );
    canvas.save();
    canvas.translate(
      (size.width - rig.boxWidth * scale) / 2,
      (size.height - rig.boxHeight * scale) / 2,
    );
    canvas.scale(scale);
    for (final shape in _shapesOf(rig, art, pose)) {
      final prim = shape.prim;
      canvas.save();
      for (final move in shape.transforms) {
        final v = move.values;
        switch (move.kind) {
          case RigTransformKind.translate:
            canvas.translate(v[0], v[1]);
          case RigTransformKind.rotate:
            canvas.translate(v[1], v[2]);
            canvas.rotate(v[0] * math.pi / 180);
            canvas.translate(-v[1], -v[2]);
          case RigTransformKind.scale:
            canvas.scale(v[0], v[1]);
        }
      }
      final fill = prim.fill;
      if (fill != null) {
        canvas.drawPath(shape.path, Paint()..color = colorOf(fill));
      }
      final stroke = prim.stroke;
      if (stroke != null) {
        canvas.drawPath(
          shape.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = prim.strokeWidth
            ..strokeCap = prim.roundCap ? StrokeCap.round : StrokeCap.butt
            ..strokeJoin = StrokeJoin.round
            ..color = colorOf(
              stroke,
              outline: true,
            ).withValues(alpha: prim.strokeOpacity),
        );
      }
      canvas.restore();
    }
    canvas.restore();
  }

  /// The color [paint] shows: the team's or its own; in a [flash] every fill
  /// and every outline but the ink ones turns white.
  Color colorOf(RigPaint paint, {bool outline = false}) {
    if (flash && !(outline && !paint.team && paint.argb == rig.ink)) {
      return AppColors.card;
    }
    return paint.team ? teamColor : Color(paint.argb);
  }

  @override
  bool shouldRepaint(CharacterFigurePainter oldDelegate) =>
      oldDelegate.rig != rig ||
      oldDelegate.art.id != art.id ||
      oldDelegate.pose != pose ||
      oldDelegate.teamColor != teamColor ||
      oldDelegate.flash != flash;
}

class _Shape {
  const _Shape({
    required this.transforms,
    required this.path,
    required this.prim,
  });

  final List<RigTransform> transforms;
  final Path path;
  final RigPrim prim;
}
