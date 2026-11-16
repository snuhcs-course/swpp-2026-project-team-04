import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/character_rig.dart';
import '../theme/app_theme.dart';
import 'character_figure.dart';
import 'victory_motion.dart';
import 'victory_scene.dart';

/// The victory scene over the result report (W5 spec 2 to 8): a win's
/// cut-in (the lime panel, the confetti, my character celebrating big, the
/// band) that ends with the character on its seat, or a loss's or a draw's
/// frustration on the seat. It fills its parent; put it over the report in
/// a `Stack`.
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
  });

  final VictoryResult result;

  /// My character; an id a person may not pick (RepBot's) or an unknown one
  /// draws the default (`mouse`, spec 8).
  final String characterId;

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

  double get _endMs => VictoryScene.endMsOf(
    _rig,
    _rig.characterOf(widget.characterId),
    widget.result,
  );

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
/// stand and the end pose of [result] (spec 8). The result report keeps it
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
/// end look when [over]: from the bottom the stand, the lime panel, the
/// confetti, the character and the band (spec 2). Repaints whenever [clock]
/// changes.
class VictoryPainter extends CustomPainter {
  VictoryPainter({
    required this.rig,
    required this.character,
    required this.result,
    required this.seat,
    required this.clock,
    required this.over,
    required this.bandStyle,
  }) : super(repaint: clock);

  final VictoryRig rig;
  final VictoryCharacter character;
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
    final frame = over ? scene.end : scene.at(clock.value);
    _paintStand(canvas, frame.stand);
    _paintPanel(canvas, scene.layout, frame.panel);
    _paintConfetti(canvas, scene.layout, frame.confetti);
    _paintFigure(canvas, frame.figure);
    _paintBand(canvas, scene.layout, frame.band);
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
      canvas
        ..drawRRect(shape, Paint()..color = stand.color)
        // The edge inside the box, as the design's border-box.
        ..drawRRect(shape.deflate(values.border / 2), _ink(values.border))
        ..restore();
    });
  }

  void _paintPanel(Canvas canvas, VictoryLayout layout, VictoryPanel? panel) {
    if (panel == null || panel.opacity <= 0) return;
    final size = layout.size;
    final shape = switch (panel) {
      VictoryWipe(:final polygon) => Path()..addPolygon(polygon, true),
      final VictoryShrink shrink => Path()..addRRect(shrink.rectIn(size)),
    };
    final values = rig.scene.panel;
    final screen = Offset.zero & size;
    canvas
      ..save()
      ..clipPath(shape);
    _inLayer(canvas, panel.opacity, () {
      canvas
        ..drawRect(screen, Paint()..color = values.fill)
        ..drawRect(screen, Paint()..shader = _stripes(layout));
    });
    canvas.restore();
  }

  /// The design's stripes: a repeating gradient at the rig's angle over a
  /// box 800 x 780 from x -220 (`dc/W5F.dc.html`), placed as the design
  /// places it (CSS: the gradient line through the box's middle, as long as
  /// the box is across that angle).
  ui.Shader _stripes(VictoryLayout layout) {
    final values = rig.scene.panel;
    final radians = values.stripeAngleDeg * math.pi / 180;
    final along = Offset(math.sin(radians), -math.cos(radians));
    final length =
        (_stripeBox.width * math.sin(radians)).abs() +
        (_stripeBox.height * math.cos(radians)).abs();
    final start = layout.fromDesign(_stripeBox.center - along * (length / 2));
    final on = values.stripeOn / values.stripePeriod;
    final gap = values.stripeColor.withValues(alpha: 0);
    return ui.Gradient.linear(
      start,
      start + along * (values.stripePeriod * layout.designScale),
      [values.stripeColor, values.stripeColor, gap, gap],
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
        ..scale(figure.scale)
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
      ..rotate(values.rotateDeg * math.pi / 180);
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
      oldDelegate.result != result ||
      oldDelegate.seat != seat ||
      oldDelegate.clock != clock ||
      oldDelegate.over != over ||
      oldDelegate.bandStyle != bandStyle;
}
