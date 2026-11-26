import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/character_rig.dart';
import '../models/matchup.dart';
import '../theme/app_theme.dart';
import 'battle_stage_model.dart' show BattleSide;
import 'character_figure.dart';
import 'character_motion.dart';
import 'victory_defeat.dart';
import 'victory_motion.dart';
import 'victory_scene.dart';

/// The victory scene over the result report (W5 spec 2 to 8, A7): a win's
/// cut-in (the lime panel, the confetti, my character celebrating big, the
/// band), a loss's red one (the rain, my character frustrating big, the band
/// 패배) or a draw's lime and pink one (the two characters bumping fists and
/// standing in guard, the band 무승부), each ending with my character on its
/// seat. It fills its parent; put it over the report in a `Stack`.
///
/// It plays once, from when it first appears, and then keeps its end look:
/// the stand and the end pose on the seat. While it plays, one see-through
/// button over all of it skips to the end; after that nothing of it takes a
/// tap, so the report's buttons work. With reduced motion, or when [play]
/// is false (a past report opened from 기록보관소, spec 11.1 answered
/// 2026-11-14), it shows only the end look.
///
/// The result screen keeps the end look in the report itself ([VictorySeat]
/// in the seat, so it scrolls with the page): it shows this overlay only
/// while the scene plays and takes it away at [onEnd].
class VictoryOverlay extends StatefulWidget {
  const VictoryOverlay({
    super.key,
    required this.result,
    required this.characterId,
    required this.seat,
    this.play = true,
    this.onEnd,
    this.opponent,
  });

  final VictoryResult result;

  /// My character; an id a person may not pick (RepBot's) or an unknown one
  /// draws the default (`mouse`, spec 8).
  final String characterId;

  /// Who I played, for a draw's scene, where the two meet: drawn as
  /// [opponentCharacterOf] says. Null when not known.
  final Opponent? opponent;

  /// The character [opponent] is drawn as, as the battle stages draw it:
  /// its own; without one a bot is RepBot, and a person, or an opponent
  /// not known, the default (`mouse`).
  static String opponentCharacterOf(Opponent? opponent) =>
      opponent?.characterId ??
      (opponent?.isBot ?? false ? CharacterRig.botId : CharacterRig.defaultId);

  /// The top left of the seat, the [seatSize] cell right of the win/lose
  /// title, in this widget's own points: the character ends there (feet at
  /// its left + 86, top + 132) on its stand (left + 44, top + 129).
  final Offset seat;

  /// Whether to play the scene (the report's first opening after a battle)
  /// or show only its end look.
  final bool play;

  /// Called once when the scene it played ends: played out or skipped with
  /// a tap. Not called when it never plays, nor when reduced motion or
  /// [play] turned off stops it (whoever turned it off knows).
  final VoidCallback? onEnd;

  /// The seat's size (spec 2).
  static const seatSize = Size(144, 148);

  /// The words of the skip button for screen readers (spec 8).
  static const skipWinLabel = '승리 연출 건너뛰기';
  static const skipLabel = '연출 건너뛰기';

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(_tick);

  /// Milliseconds since the scene started.
  final _clock = ValueNotifier<double>(0);

  /// Whether the scene is over: played out, skipped or never played.
  bool _over = false;

  VictoryRig get _rig => VictoryRig.standard;

  double get _endMs => VictoryScene.endMsOf(_rig, widget.result);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.play || still) {
      _stop();
    } else if (!_over && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(VictoryOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.play) _stop();
  }

  void _tick(Duration elapsed) {
    final ms = elapsed.inMicroseconds / 1000;
    if (ms >= _endMs) {
      _end();
    } else {
      _clock.value = ms;
    }
  }

  /// Jumps to the end look and stays there (a build follows).
  void _stop() {
    _over = true;
    _ticker.stop();
  }

  /// The scene ends while playing: played out or skipped.
  void _end() {
    if (_over) return;
    setState(_stop);
    widget.onEnd?.call();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rig = _rig;
    final character = rig.characterOf(widget.characterId);
    final band = rig.scene.band;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          // Repaints alone each frame, not the report under it.
          child: RepaintBoundary(
            child: CustomPaint(
              painter: VictoryPainter(
                rig: rig,
                character: character,
                opponentId: VictoryOverlay.opponentCharacterOf(widget.opponent),
                result: widget.result,
                seat: widget.seat,
                clock: _clock,
                over: _over,
                bandStyle: Theme.of(context).textTheme.stageBandKorean
                    .apply(
                      fontSizeFactor: band.textSize / StageText.stageBandSize,
                    )
                    .copyWith(height: band.height / band.textSize),
              ),
            ),
          ),
        ),
        if (!_over)
          Semantics(
            button: true,
            label: widget.result.isWin
                ? VictoryOverlay.skipWinLabel
                : VictoryOverlay.skipLabel,
            onTap: _end,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _end,
            ),
          ),
      ],
    );
  }
}

/// The scene's end look alone, in a [VictoryOverlay.seatSize] box: the
/// stand and the end pose of [result] (spec 8; a draw's is my character in
/// guard on the lime and pink stand, A7). The result report keeps it
/// in its seat after the scene, with reduced motion, and on a past report.
/// It takes no taps and says nothing to screen readers.
class VictorySeat extends StatelessWidget {
  const VictorySeat({
    super.key,
    required this.result,
    required this.characterId,
  });

  final VictoryResult result;

  /// My character, as [VictoryOverlay.characterId].
  final String characterId;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: VictoryOverlay.seatSize,
    child: VictoryOverlay(
      result: result,
      characterId: characterId,
      seat: Offset.zero,
      play: false,
    ),
  );
}

/// Paints the victory scene's layers at the time [clock] holds (ms), or its
/// end look when [over]: from the bottom the stand, the panel (a loss's
/// rain on it), the confetti, the characters (the figure in its motion, a
/// draw's two fighters and their spark, moved by the shake) and the band
/// (spec 2, A7). Repaints whenever [clock] changes.
class VictoryPainter extends CustomPainter {
  VictoryPainter({
    required this.rig,
    required this.character,
    this.opponentId = CharacterRig.defaultId,
    required this.result,
    required this.seat,
    required this.clock,
    required this.over,
    required this.bandStyle,
  }) : super(repaint: clock);

  final VictoryRig rig;
  final VictoryCharacter character;

  /// The opponent's character in a draw's scene.
  final String opponentId;
  final VictoryResult result;
  final Offset seat;
  final ValueNotifier<double> clock;
  final bool over;

  /// The band's words: Do Hyeon at the rig's size and line height.
  final TextStyle bandStyle;

  /// The scene on a screen of [size].
  VictoryScene sceneIn(Size size) => VictoryScene(
    rig: rig,
    character: character,
    result: result,
    layout: VictoryLayout(size: size, seat: seat, values: rig.scene),
    opponentId: opponentId,
  );

  /// What the layers show now on a screen of [size].
  VictoryFrame frameIn(Size size) {
    final scene = sceneIn(size);
    return over ? scene.end : scene.at(clock.value);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scene = sceneIn(size);
    final layout = scene.layout;
    final frame = over ? scene.end : scene.at(clock.value);
    _paintStand(canvas, frame.stand);
    _paintPanel(canvas, layout, frame.panel, frame.rain);
    _paintConfetti(canvas, layout, frame.confetti);
    canvas
      ..save()
      ..translate(frame.shake * layout.designScale, 0);
    for (final fighter in frame.fighters) {
      _paintFighter(canvas, fighter);
    }
    _paintFigure(canvas, frame.figure);
    _paintSpark(canvas, layout, frame.spark);
    canvas.restore();
    _paintBand(canvas, layout, frame.band);
  }

  void _paintStand(Canvas canvas, VictoryStand? stand) {
    if (stand == null || stand.opacity <= 0 || stand.scaleX <= 0) return;
    final values = rig.scene.stand;
    final rect = stand.rect;
    _inLayer(canvas, stand.opacity, () {
      canvas
        ..save()
        ..translate(rect.center.dx, rect.center.dy)
        ..scale(stand.scaleX, 1)
        ..translate(-rect.center.dx, -rect.center.dy);
      final shape = RRect.fromRectAndRadius(
        rect,
        Radius.circular(values.radius),
      );
      final right = stand.rightColor;
      if (right == null) {
        canvas.drawRRect(shape, Paint()..color = stand.color);
      } else {
        // A draw's: lime left of the middle, pink right of it.
        canvas
          ..save()
          ..clipRRect(shape)
          ..drawRect(
            Rect.fromLTRB(rect.left, rect.top, rect.center.dx, rect.bottom),
            Paint()..color = stand.color,
          )
          ..drawRect(
            Rect.fromLTRB(rect.center.dx, rect.top, rect.right, rect.bottom),
            Paint()..color = right,
          )
          ..restore();
      }
      canvas
        // The edge inside the box, as the design's border-box.
        ..drawRRect(shape.deflate(values.border / 2), _ink(values.border))
        ..restore();
    });
  }

  void _paintPanel(
    Canvas canvas,
    VictoryLayout layout,
    VictoryPanel? panel,
    List<VictoryRaindrop> rain,
  ) {
    if (panel == null || panel.opacity <= 0) return;
    final size = layout.size;
    final shape = switch (panel) {
      VictoryWipe(:final polygon) => Path()..addPolygon(polygon, true),
      final VictoryShrink shrink => Path()..addRRect(shrink.rectIn(size)),
      VictoryShutter() || VictorySplit() => null,
    };
    canvas.save();
    if (shape != null) canvas.clipPath(shape);
    _inLayer(canvas, panel.opacity, () {
      switch (panel) {
        case VictoryShrink(:final inner?):
          _paintInside(canvas, layout, inner, rain);
        case VictoryWipe() || VictoryShrink():
          _paintLime(canvas, layout, Offset.zero & size);
        case VictoryShutter() || VictorySplit():
          _paintInside(canvas, layout, panel, rain);
      }
    });
    canvas.restore();
  }

  /// A loss's or a draw's panel, whole: the red one with its rain, or the
  /// two halves and the seam.
  void _paintInside(
    Canvas canvas,
    VictoryLayout layout,
    VictoryPanel panel,
    List<VictoryRaindrop> rain,
  ) {
    final screen = Offset.zero & layout.size;
    switch (panel) {
      case VictoryShutter(:final polygon):
        canvas.save();
        if (polygon != null) {
          canvas.clipPath(Path()..addPolygon(polygon, true));
        }
        canvas
          ..drawRect(screen, Paint()..color = VictoryDefeat.loseFill)
          ..drawRect(
            screen,
            Paint()
              ..shader = _stripes(
                layout,
                rig.scene.panel.stripeAngleDeg,
                VictoryDefeat.white(VictoryDefeat.loseStripeAlpha),
              ),
          );
        _paintRain(canvas, layout, rain);
        canvas.restore();
      case VictorySplit(:final lime, :final pink, :final seam):
        canvas
          ..save()
          ..clipPath(Path()..addPolygon(lime, true));
        _paintLime(canvas, layout, screen);
        canvas
          ..restore()
          ..save()
          ..clipPath(Path()..addPolygon(pink, true))
          ..drawRect(screen, Paint()..color = VictoryDefeat.pinkFill)
          ..drawRect(
            screen,
            Paint()
              ..shader = _stripes(
                layout,
                VictoryDefeat.pinkStripeAngleDeg,
                VictoryDefeat.white(VictoryDefeat.pinkStripeAlpha),
              ),
          )
          ..restore();
        if (seam != null) {
          canvas.drawLine(seam.top, seam.bottom, _ink(VictoryDefeat.seamWidth));
        }
      case VictoryWipe() || VictoryShrink():
        _paintLime(canvas, layout, screen);
    }
  }

  /// The lime panel with its white stripes over [area].
  void _paintLime(Canvas canvas, VictoryLayout layout, Rect area) {
    final values = rig.scene.panel;
    canvas
      ..drawRect(area, Paint()..color = values.fill)
      ..drawRect(
        area,
        Paint()
          ..shader = _stripes(
            layout,
            values.stripeAngleDeg,
            values.stripeColor,
          ),
      );
  }

  /// A loss's rain, in the design's points.
  void _paintRain(
    Canvas canvas,
    VictoryLayout layout,
    List<VictoryRaindrop> rain,
  ) {
    if (rain.isEmpty) return;
    const size = Size(VictoryDefeat.rainWidth, VictoryDefeat.rainHeight);
    final streak = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width,
        height: size.height,
      ),
      const Radius.circular(VictoryDefeat.rainRadius),
    );
    final paint = Paint()..color = VictoryDefeat.white(VictoryDefeat.rainAlpha);
    canvas
      ..save()
      ..translate(layout.designOrigin.dx, layout.designOrigin.dy)
      ..scale(layout.designScale);
    for (final drop in rain) {
      final middle = drop.topLeft + size.center(Offset.zero);
      canvas
        ..save()
        ..translate(middle.dx, middle.dy)
        ..rotate(VictoryDefeat.rainTurnDeg * math.pi / 180)
        ..drawRRect(streak, paint)
        ..restore();
    }
    canvas.restore();
  }

  /// The design's stripes: a repeating gradient at [angleDeg] over a box
  /// 800 x 780 from x -220 (`dc/W5F.dc.html`), placed as the design places
  /// it (CSS: the gradient line through the box's middle, as long as the box
  /// is across that angle).
  ui.Shader _stripes(VictoryLayout layout, double angleDeg, Color color) {
    final values = rig.scene.panel;
    final radians = angleDeg * math.pi / 180;
    final along = Offset(math.sin(radians), -math.cos(radians));
    final length =
        (_stripeBox.width * math.sin(radians)).abs() +
        (_stripeBox.height * math.cos(radians)).abs();
    final start = layout.fromDesign(_stripeBox.center - along * (length / 2));
    final on = values.stripeOn / values.stripePeriod;
    final gap = color.withValues(alpha: 0);
    return ui.Gradient.linear(
      start,
      start + along * (values.stripePeriod * layout.designScale),
      [color, color, gap, gap],
      [0, on, on, 1],
      TileMode.repeated,
    );
  }

  static const _stripeBox = Rect.fromLTWH(-220, 0, 800, 780);

  void _paintConfetti(
    Canvas canvas,
    VictoryLayout layout,
    List<VictoryConfetto> confetti,
  ) {
    if (confetti.every((piece) => piece.opacity <= 0)) return;
    final values = rig.scene.confetti;
    canvas
      ..save()
      ..translate(layout.designOrigin.dx, layout.designOrigin.dy)
      ..scale(layout.designScale);
    for (final piece in confetti) {
      if (piece.opacity <= 0) continue;
      final middle = piece.topLeft + piece.size.center(Offset.zero);
      final shape = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: piece.size.width,
          height: piece.size.height,
        ),
        Radius.circular(values.radius),
      );
      canvas
        ..save()
        ..translate(middle.dx, middle.dy)
        ..rotate(piece.rotDeg * math.pi / 180)
        ..drawRRect(
          shape,
          Paint()
            ..color = piece.color.withValues(
              alpha: piece.color.a * piece.opacity,
            ),
        )
        ..drawRRect(
          shape.deflate(values.border / 2),
          _ink(values.border, opacity: piece.opacity),
        )
        ..restore();
    }
    canvas.restore();
  }

  void _paintFigure(Canvas canvas, VictoryFigure? figure) {
    if (figure == null || figure.opacity <= 0) return;
    final w3 = CharacterRig.standard;
    final frame = figure.frame;
    _inLayer(canvas, figure.opacity, () {
      canvas
        ..save()
        ..translate(figure.foot.dx, figure.foot.dy)
        ..scale(figure.scale * figure.stretchX, figure.scale * figure.stretchY)
        ..translate(-w3.anchorX, -w3.anchorY);
      frame.global.applyTo(canvas, w3.anchorX, w3.anchorY);
      CharacterFigurePainter(
        rig: w3,
        art: w3.art(character.id),
        // The scene is always the player's own: the team lime (spec 2).
        teamColor: AppColors.accent,
        values: frame.pose,
        tags: rig.tagsOf(frame.expression, character.id),
        patches: character.drawPatch,
        flags: character.motionOf(figure.motion).motion.flags,
        effects: rig.effects,
      ).paint(canvas, Size(w3.boxWidth, w3.boxHeight));
      canvas.restore();
    });
  }

  /// A character as the battle stage draws it ([CharacterFigure]): its pose
  /// by name, its team's color, the stage's drawPatch, the idle motion about
  /// its feet.
  void _paintFighter(Canvas canvas, VictoryFighter fighter) {
    if (fighter.opacity <= 0) return;
    final w3 = CharacterRig.standard;
    final art = w3.art(fighter.characterId);
    final idle = fighter.idle;
    _inLayer(canvas, fighter.opacity, () {
      canvas
        ..save()
        ..translate(fighter.foot.dx, fighter.foot.dy)
        ..scale(
          fighter.mirrored ? -fighter.scale : fighter.scale,
          fighter.scale,
        )
        ..translate(0, -idle.up)
        ..rotate(idle.rockDeg * math.pi / 180)
        ..scale(idle.scaleX, idle.scaleY)
        ..translate(-w3.anchorX, -w3.anchorY);
      CharacterFigurePainter(
        rig: w3,
        art: art,
        pose: characterPoseKey(fighter.pose),
        teamColor: fighter.side == BattleSide.me
            ? AppColors.accent
            : AppColors.opponent,
        patches: CharacterMotionRig.standard.stagePatchOf(art.id),
      ).paint(canvas, Size(w3.boxWidth, w3.boxHeight));
      canvas.restore();
    });
  }

  /// A draw's spark: white with an ink edge, and eight ink rays.
  void _paintSpark(Canvas canvas, VictoryLayout layout, VictorySpark? spark) {
    if (spark == null || spark.opacity <= 0) return;
    canvas
      ..save()
      ..translate(layout.designOrigin.dx, layout.designOrigin.dy)
      ..scale(layout.designScale)
      ..translate(spark.center.dx, spark.center.dy)
      ..rotate(spark.rotDeg * math.pi / 180)
      ..scale(spark.scale);
    _inLayer(canvas, spark.opacity, () {
      final rays = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = VictoryDefeat.sparkRayWidth
        ..strokeCap = StrokeCap.round
        ..color = AppColors.ink;
      for (final (from, to) in VictoryDefeat.sparkRays) {
        canvas.drawLine(from, to, rays);
      }
      final star = Path()..addPolygon(VictoryDefeat.sparkStar, true);
      canvas
        ..drawPath(star, Paint()..color = AppColors.card)
        ..drawPath(
          star,
          _ink(VictoryDefeat.sparkEdgeWidth)..strokeJoin = StrokeJoin.round,
        );
    });
    canvas.restore();
  }

  void _paintBand(Canvas canvas, VictoryLayout layout, VictoryBand? band) {
    if (band == null || band.opacity <= 0) return;
    final values = rig.scene.band;
    final words = TextPainter(
      text: TextSpan(text: band.text, style: bandStyle),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final width = words.width + values.padX * 2;
    final height = values.height;
    canvas
      ..save()
      ..translate(layout.designOrigin.dx, layout.designOrigin.dy)
      ..scale(layout.designScale)
      ..translate(
        rig.scene.screen.width / 2 + band.dx,
        values.top + height / 2 + band.dy,
      )
      ..rotate(band.rotDeg * math.pi / 180);
    _inLayer(canvas, band.opacity, () {
      final ground = Rect.fromCenter(
        center: Offset.zero,
        width: width,
        height: height,
      );
      canvas
        ..save()
        ..skew(math.tan(values.skewXDeg * math.pi / 180), 0)
        ..drawRect(ground, Paint()..color = values.fill)
        ..drawRect(ground.deflate(values.border / 2), _ink(values.border))
        ..restore();
      words.paint(canvas, Offset(-width / 2 + values.padX, -words.height / 2));
    });
    canvas.restore();
    words.dispose();
  }

  /// Draws [draw] at [opacity] as one picture, so shapes over each other
  /// fade together.
  static void _inLayer(Canvas canvas, double opacity, VoidCallback draw) {
    if (opacity >= 1) {
      draw();
      return;
    }
    canvas.saveLayer(
      null,
      Paint()..color = AppColors.ink.withValues(alpha: opacity),
    );
    draw();
    canvas.restore();
  }

  static Paint _ink(double width, {double opacity = 1}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = AppColors.ink.withValues(alpha: opacity);

  @override
  bool shouldRepaint(VictoryPainter oldDelegate) =>
      oldDelegate.rig != rig ||
      oldDelegate.character.id != character.id ||
      oldDelegate.opponentId != opponentId ||
      oldDelegate.result != result ||
      oldDelegate.seat != seat ||
      oldDelegate.clock != clock ||
      oldDelegate.over != over ||
      oldDelegate.bandStyle != bandStyle;
}
