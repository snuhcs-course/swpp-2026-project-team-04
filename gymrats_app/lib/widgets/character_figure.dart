import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/character_idle_motion.dart';
import '../models/character_rig.dart';
import '../theme/app_theme.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_model.dart';
import 'character_draw_patch.dart';
import 'character_motion.dart';

/// One character in one pose, in a team's color (W3 spec 3 and 6).
///
/// It is the box of the rig (140 x 160) times [scale], faces right and
/// stands with its feet on (70, 150) of that box, like the stage's fighters;
/// parts may leave the box (the attack's fist does). A parent that forces
/// another size gets the box scaled the same both ways and centred. An unknown
/// [characterId] draws the default character (`mouse`). It does not move:
/// the stage and the selection preview move it. 그루 has the inner tail fur
/// of home's motion here too (user, 2026-11-14, W4 spec 10.1).
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
    final art = rig.art(characterId);
    return CustomPaint(
      size: Size(rig.boxWidth * scale, rig.boxHeight * scale),
      painter: CharacterFigurePainter(
        rig: rig,
        art: art,
        pose: characterPoseKey(pose),
        teamColor: side == BattleSide.me
            ? AppColors.accent
            : AppColors.opponent,
        flash: flash,
        patches: CharacterMotionRig.standard.stagePatchOf(art.id),
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
/// The stage draws a pose by its name. A motion (home's exercise, W4 spec 8;
/// W5's celebration) gives from outside what a name gives: the pose table
/// ([values]), the expression's tags ([tags]), and changes to the drawing
/// list with the flags they test ([patches], [flags], [effects]). With none
/// of these it draws exactly what it drew before W4.
///
/// The paths of a character and a named pose are built once and kept; a
/// motion's are built each frame but for the fixed ones.
class CharacterFigurePainter extends CustomPainter {
  CharacterFigurePainter({
    required this.rig,
    required this.art,
    this.pose = 'idle',
    required this.teamColor,
    this.flash = false,
    this.values,
    this.tags,
    this.patches = const [],
    this.flags = const {},
    this.effects = const [],
  });

  final CharacterRig rig;
  final CharacterArt art;

  /// The pose key (idle, atk, hit, ko, win): its table unless [values] is
  /// given, and the shapes shown in it unless [tags] is given.
  final String pose;
  final Color teamColor;
  final bool flash;

  /// A pose table from outside, drawn instead of [pose]'s: a frame of a
  /// motion, blended between its key poses.
  final RigPoseTable? values;

  /// The `show` tags of an expression: a shape with a pose list shows when
  /// the list has one of them. Null shows the shapes of [pose].
  final Set<String>? tags;

  /// Changes to [art]'s drawing list, applied in order (W4's, then W5's).
  final List<CharacterDrawPatch> patches;

  /// The motion flags that are on (gBack, pa): which shapes the patches
  /// made conditional show.
  final Set<String> flags;

  /// Shapes left out: a motion leaves out the stage's effects.
  final List<CharacterOpMatch> effects;

  static final _shapes =
      <
        (CharacterRig, String, String, List<CharacterDrawOp>, String, String),
        List<_Shape>
      >{};

  /// The fixed paths (all but the ones a pose table gives), built once.
  static final _fixedPaths = Expando<Path>();

  /// The built shapes to draw: each one's moves and path.
  List<_Shape> _shapesNow() {
    final list = characterDrawList(art, patches, effects);
    final shown = tags ?? {pose};
    final table = values;
    if (table != null) return _build(list, table, shown);
    final flagKey = (flags.toList()..sort()).join(' ');
    final tagKey = (shown.toList()..sort()).join(' ');
    return _shapes.putIfAbsent((rig, art.id, pose, list, tagKey, flagKey), () {
      final table =
          art.poses[pose] ?? (throw ArgumentError.value(pose, 'pose'));
      return _build(list, table, shown);
    });
  }

  List<_Shape> _build(
    List<CharacterDrawOp> list,
    RigPoseTable table,
    Set<String> shown,
  ) {
    return [
      for (final item in list)
        if (!item.effect &&
            (item.condition?.passes(flags) ?? true) &&
            (item.op.show?.any(shown.contains) ?? true))
          _Shape(
            transforms: item.op.transformsIn(table),
            path: _pathOf(item.op.prim, table),
            prim: item.op.prim,
          ),
    ];
  }

  static Path _pathOf(RigPrim prim, RigPoseTable table) {
    if (prim.shape == RigShape.path && prim.pathKey != null) {
      return _buildPath(prim, table);
    }
    return _fixedPaths[prim] ??= _buildPath(prim, table);
  }

  static Path _buildPath(RigPrim prim, RigPoseTable table) {
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
    for (final shape in _shapesNow()) {
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
      oldDelegate.flash != flash ||
      !identical(oldDelegate.values, values) ||
      !setEquals(oldDelegate.tags, tags) ||
      !listEquals(oldDelegate.patches, patches) ||
      !setEquals(oldDelegate.flags, flags) ||
      !listEquals(oldDelegate.effects, effects);
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
