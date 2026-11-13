import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'battle_art_path.dart';
import 'battle_banner.dart';
import 'battle_fighter.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_hud.dart';
import 'battle_stage_model.dart';

/// The fighting stage at one moment: the HUD, the bar the two fighters
/// stand on, the fighters, and the effects over them, drawn from a [frame]
/// of the effect math and the battle's [state].
///
/// It is 360 x 390 design points ([BattleFx.stageWidth] by
/// [BattleFx.stageHeight]); what holds it sizes it as a whole. It has no
/// clock of its own: give it a new frame to move it. Only the fighters'
/// layer shakes and zooms; the HUD holds still.
class BattleStage extends StatelessWidget {
  const BattleStage({
    super.key,
    required this.frame,
    required this.state,
    this.fighterBuilder = BattleFighter.standIn,
  });

  final BattleFxFrame frame;
  final BattleStageState state;

  /// Draws a fighter's picture for a pose; the characters come in here.
  final BattleFighterBuilder fighterBuilder;

  /// The height the KO zoom grows from.
  static const _zoomOriginY = 300.0;

  @override
  Widget build(BuildContext context) {
    final me = _FighterView(
      fighter: frame.me,
      side: BattleSide.me,
      glowRadius: frame.glowRadius,
      builder: fighterBuilder,
    );
    final opponent = _FighterView(
      fighter: frame.opponent,
      side: BattleSide.opponent,
      glowRadius: frame.glowRadius,
      builder: fighterBuilder,
    );
    final star = frame.star;
    final twinkle = frame.twinkle;
    final puff = frame.puff;
    return SizedBox(
      width: BattleFx.stageWidth,
      height: BattleFx.stageHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: BattleStageHud(
              myName: state.myName,
              opponentName: state.opponentName,
              secondsLeft: state.secondsLeft,
              elapsed: state.elapsed,
              chip: BattleFx.chip(
                lead: state.lead,
                fever: state.fever,
                beforeStart: frame.beforeStart,
                feverMultiplier: state.feverMultiplier,
              ),
              myScore: state.myScore,
              opponentScore: state.opponentScore,
              myReps: state.myReps,
              opponentReps: state.opponentReps,
              myScoreBump: frame.myScoreBump,
              opponentScoreBump: frame.opponentScoreBump,
              myRepsBump: frame.myRepsBump,
              opponentRepsBump: frame.opponentRepsBump,
              countsOpacity: frame.countsOpacity,
            ),
          ),
          // In the valid counts' place while setting up, with the HUD: they
          // hold still.
          for (final chip in frame.readyChips) _ReadyChip(chip: chip),
          Positioned.fill(
            child: Transform(
              transform: Matrix4.translationValues(
                frame.shakeX,
                frame.shakeY,
                0,
              ).multiplied(Matrix4.diagonal3Values(frame.zoom, frame.zoom, 1)),
              origin: Offset(frame.meetX, _zoomOriginY),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _Bar(meetX: frame.meetX, share: state.barShare),
                  // The user's fighter is drawn over the opponent's, as in
                  // the design, unless only the opponent is attacking: the
                  // attacker is drawn over the one who is hit.
                  if (frame.opponent.front && !frame.me.front) ...[
                    me,
                    opponent,
                  ] else ...[
                    opponent,
                    me,
                  ],
                  if (frame.myTag case final tag?) _Tag(tag: tag),
                  if (frame.opponentTag case final tag?) _Tag(tag: tag),
                  if (star != null)
                    _Spark(
                      center: Offset(star.centerX, star.centerY),
                      rotation: star.rotation,
                      scale: star.diameter / BattleStarPainter.width,
                      opacity: star.opacity,
                      size: BattleStarPainter.box,
                      painter: const BattleStarPainter(),
                    ),
                  if (twinkle != null)
                    _Spark(
                      center: Offset(twinkle.centerX, twinkle.centerY),
                      rotation: twinkle.rotation,
                      scale: twinkle.scale,
                      opacity: twinkle.opacity,
                      size: BattleTwinklePainter.box,
                      painter: const BattleTwinklePainter(),
                    ),
                  if (puff != null)
                    _Spark(
                      center: Offset(puff.centerX, puff.centerY),
                      rotation: 0,
                      scale: puff.scale,
                      opacity: puff.opacity,
                      size: BattlePuffPainter.box,
                      painter: const BattlePuffPainter(),
                    ),
                ],
              ),
            ),
          ),
          for (final banner in frame.banners) BattleStageBanner(banner: banner),
        ],
      ),
    );
  }
}

/// The bar the fighters stand on, which is the health bar: lime on the
/// user's side up to where the two meet, pink beyond, a white tick in the
/// middle, and "KO" under each end.
class _Bar extends StatelessWidget {
  const _Bar({required this.meetX, required this.share});

  final double meetX;
  final double share;

  static const _left = 24.0;
  static const _width = 312.0;
  static const _height = 22.0;
  static const _edge = 3.0;
  static const _corner = 7.0;
  static const _tickLeft = 152.0;
  static const _tickWidth = 2.0;
  static const _endsTop = 371.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const inner = _width - 2 * _edge;
    final lime = (meetX - _left - _edge).clamp(0.0, inner);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _left,
          top: BattleFx.groundY,
          width: _width,
          height: _height,
          child: Semantics(
            container: true,
            label: '체력 바',
            value: '내 쪽 ${(share.clamp(0.0, 1.0) * 100).round()}%',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(_corner),
              ),
              child: Padding(
                padding: const EdgeInsets.all(_edge),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_corner - _edge),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: AppColors.opponent),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: lime,
                        child: const ColoredBox(color: AppColors.accent),
                      ),
                      Positioned(
                        left: lime,
                        top: 0,
                        bottom: 0,
                        width: _edge,
                        child: const ColoredBox(color: AppColors.ink),
                      ),
                      Positioned(
                        left: _tickLeft,
                        top: 0,
                        bottom: 0,
                        width: _tickWidth,
                        child: ColoredBox(
                          color: AppColors.card.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: _left,
          top: _endsTop,
          child: ExcludeSemantics(
            child: Text(
              'KO',
              textScaler: TextScaler.noScaling,
              style: text.stageBarEnd,
            ),
          ),
        ),
        Positioned(
          right: BattleFx.stageWidth - _left - _width,
          top: _endsTop,
          child: ExcludeSemantics(
            child: Text(
              'KO',
              textScaler: TextScaler.noScaling,
              style: text.stageBarEnd,
            ),
          ),
        ),
      ],
    );
  }
}

/// One fighter where the effect math puts them: moved to their feet, turned
/// and sized around the feet, faded, and lit (the white flash of a blow, the
/// aura of fever). The picture itself comes from [builder] and knows none of
/// this.
class _FighterView extends StatelessWidget {
  const _FighterView({
    required this.fighter,
    required this.side,
    required this.glowRadius,
    required this.builder,
  });

  final BattleFxFighter fighter;
  final BattleSide side;
  final double glowRadius;
  final BattleFighterBuilder builder;

  /// How far the flash's ink edge spreads around the white shape.
  static const _flashEdge = 1.0;

  @override
  Widget build(BuildContext context) {
    if (fighter.opacity <= 0) return const SizedBox.shrink();
    final picture = RepaintBoundary(child: builder(fighter.pose, side));
    final Widget lit;
    if (fighter.flash) {
      // A white shape with a soft ink edge, so it shows on the light ground.
      final edge = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: _flashEdge,
          sigmaY: _flashEdge,
        ),
        child: _tinted(AppColors.ink, picture),
      );
      lit = Stack(
        clipBehavior: Clip.none,
        children: [edge, edge, _tinted(AppColors.card, picture)],
      );
    } else if (fighter.glow) {
      lit = Stack(
        clipBehavior: Clip.none,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: glowRadius / 2,
              sigmaY: glowRadius / 2,
            ),
            child: _tinted(AppColors.card, picture),
          ),
          picture,
        ],
      );
    } else {
      lit = picture;
    }
    return Positioned(
      left: fighter.footX - BattleFighter.foot.dx,
      top: fighter.footY - BattleFighter.foot.dy,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: fighter.opacity.clamp(0.0, 1.0),
          child: Transform(
            transform: Matrix4.rotationZ(fighter.rotation * math.pi / 180)
                .multiplied(
                  Matrix4.diagonal3Values(fighter.scaleX, fighter.scaleY, 1),
                ),
            origin: BattleFighter.foot,
            child: lit,
          ),
        ),
      ),
    );
  }

  /// [child] as a flat shape of [color].
  static Widget _tinted(Color color, Widget child) => ColorFiltered(
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    child: child,
  );
}

/// The pill over a fighter's head: "준비 완료" counting down, "연결 끊김".
class _Tag extends StatelessWidget {
  const _Tag({required this.tag});

  final BattleFxTag tag;

  static const _top = 200.0;
  static const _room = 120.0;

  @override
  Widget build(BuildContext context) {
    if (tag.opacity <= 0) return const SizedBox.shrink();
    return Positioned(
      left: tag.centerX - _room / 2,
      top: _top,
      width: _room,
      child: Center(
        child: Opacity(
          opacity: tag.opacity.clamp(0.0, 1.0),
          child: _Pill(text: tag.text, tone: tag.tone),
        ),
      ),
    );
  }
}

/// A player's ready chip between the scores while setting up (W2b 3-B):
/// the user's begins [_inset] from the stage's left side, the opponent's
/// ends as far from its right. A screen reader hears whose it is.
class _ReadyChip extends StatelessWidget {
  const _ReadyChip({required this.chip});

  final BattleFxReadyChip chip;

  static const _top = 106.0;
  static const _inset = 72.0;

  @override
  Widget build(BuildContext context) {
    final mine = chip.side == BattleSide.me;
    return Positioned(
      left: mine ? _inset : null,
      right: mine ? null : _inset,
      top: _top,
      child: Opacity(
        opacity: chip.opacity.clamp(0.0, 1.0),
        child: _Pill(
          text: chip.text,
          tone: chip.tone,
          semanticsLabel: '${mine ? '나' : '상대'} ${chip.text}',
        ),
      ),
    );
  }
}

/// The stage's small pill: ink words on a [tone] fill with an ink edge, as a
/// tag over a fighter or a ready chip.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.tone, this.semanticsLabel});

  final String text;
  final BattleFxTone tone;
  final String? semanticsLabel;

  static const _edge = 1.5;
  static const _corner = 11.0;

  /// The design's edge lies outside its padding (9 beside, 2 above and
  /// below); here it is painted inside the box, so the box makes room.
  static const _side = 9.0 + _edge;
  static const _topPadding = 2.0 + _edge;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.color,
        border: Border.all(color: AppColors.ink, width: _edge),
        borderRadius: BorderRadius.circular(_corner),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _side,
          vertical: _topPadding,
        ),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textScaler: TextScaler.noScaling,
          semanticsLabel: semanticsLabel,
          style: Theme.of(context).textTheme.stageTag,
        ),
      ),
    );
  }
}

/// A small picture of the effects (the impact star, the twinkle, the puff),
/// centered on a point, turned and sized around its own middle.
class _Spark extends StatelessWidget {
  const _Spark({
    required this.center,
    required this.rotation,
    required this.scale,
    required this.opacity,
    required this.size,
    required this.painter,
  });

  final Offset center;
  final double rotation;
  final double scale;
  final double opacity;
  final Size size;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - size.width / 2,
      top: center.dy - size.height / 2,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform(
              transform: Matrix4.rotationZ(rotation * math.pi / 180)
                  .multiplied(Matrix4.diagonal3Values(scale, scale, 1)),
              alignment: Alignment.center,
              child: CustomPaint(size: size, painter: painter),
            ),
          ),
        ),
      ),
    );
  }
}

/// The impact star: sixteen points in amber with an ink edge, and a white
/// star inside.
class BattleStarPainter extends CustomPainter {
  const BattleStarPainter();

  /// The box the star is drawn in.
  static const box = Size.square(120);

  /// How wide the star itself is in that box, tip to tip: what the effect
  /// math's diameter is measured against.
  static const width = 112.0;

  static const _outer =
      'M60 4L70.7 34.1L99.6 20.4L85.9 49.3L116 60L85.9 70.7L99.6 99.6'
      'L70.7 85.9L60 116L49.3 85.9L20.4 99.6L34.1 70.7L4 60L34.1 49.3'
      'L20.4 20.4L49.3 34.1Z';
  static const _inner =
      'M60 32L65.4 47.1L79.8 40.2L72.9 54.6L88 60L72.9 65.4L79.8 79.8'
      'L65.4 72.9L60 88L54.6 72.9L40.2 79.8L47.1 65.4L32 60L47.1 54.6'
      'L40.2 40.2L54.6 47.1Z';

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / box.width, size.height / box.height);
    final outer = battleArtPath(_outer);
    canvas.drawPath(outer, Paint()..color = AppColors.warning);
    canvas.drawPath(
      outer,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(battleArtPath(_inner), Paint()..color = AppColors.card);
    canvas.restore();
  }

  @override
  bool shouldRepaint(BattleStarPainter oldDelegate) => false;
}

/// The white twinkle where a knocked-out fighter left the screen.
class BattleTwinklePainter extends CustomPainter {
  const BattleTwinklePainter();

  static const box = Size.square(40);

  static const _shape = 'M20 2l5 13 13 5-13 5-5 13-5-13-13-5 13-5z';

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / box.width, size.height / box.height);
    final shape = battleArtPath(_shape);
    canvas.drawPath(shape, Paint()..color = AppColors.card);
    canvas.drawPath(
      shape,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BattleTwinklePainter oldDelegate) => false;
}

/// The puff of smoke a player who left leaves behind: three white clouds
/// with ink edges.
class BattlePuffPainter extends CustomPainter {
  const BattlePuffPainter();

  static const box = Size.square(80);

  /// Each cloud: its middle and its radius.
  static const _clouds = [
    (28.0, 46.0, 18.0),
    (52.0, 50.0, 15.0),
    (42.0, 28.0, 14.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / box.width, size.height / box.height);
    final fill = Paint()..color = AppColors.card;
    final edge = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final (x, y, radius) in _clouds) {
      canvas.drawCircle(Offset(x, y), radius, fill);
      canvas.drawCircle(Offset(x, y), radius, edge);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BattlePuffPainter oldDelegate) => false;
}

/// The stage's ground behind everything: a faint grid, and in fever a cyan
/// wash with white stripes drifting across it.
///
/// It fills whatever box it is given (the stage's half of the screen, up
/// behind the status bar), drawing the design's 28 point grid at [scale]
/// from [origin], where the stage's own top left corner is.
class BattleStageBackdrop extends StatelessWidget {
  const BattleStageBackdrop({
    super.key,
    required this.feverOpacity,
    required this.stripeShift,
    this.scale = 1,
    this.origin = Offset.zero,
  });

  /// How much of the fever wash shows, from 0 to 1.
  final double feverOpacity;

  /// How far the stripes have drifted, in design points.
  final double stripeShift;

  final double scale;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.background),
          RepaintBoundary(
            child: CustomPaint(
              painter: BattleGridPainter(scale: scale, origin: origin),
            ),
          ),
          if (feverOpacity > 0)
            Opacity(
              opacity: feverOpacity.clamp(0.0, 1.0),
              child: ColoredBox(
                color: AppColors.fever,
                child: CustomPaint(
                  painter: BattleFeverStripesPainter(
                    shift: stripeShift,
                    scale: scale,
                    origin: origin,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The stage's faint grid: a line every 28 design points.
class BattleGridPainter extends CustomPainter {
  const BattleGridPainter({required this.scale, required this.origin});

  final double scale;
  final Offset origin;

  /// The grid's cell, and how faint its lines are.
  static const cell = 28.0;
  static const _strength = 0.07;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.line.withValues(alpha: _strength)
      ..strokeWidth = 1;
    final step = cell * scale;
    if (step <= 0) return;
    // The first line at or before the box's edge, counted from the origin.
    for (var x = origin.dx % step - step; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = origin.dy % step - step; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(BattleGridPainter oldDelegate) =>
      oldDelegate.scale != scale || oldDelegate.origin != origin;
}

/// The white stripes of fever: 22 wide every 56, leaning as the design's
/// 115 degree gradient does, drifting to the right by [shift].
class BattleFeverStripesPainter extends CustomPainter {
  const BattleFeverStripesPainter({
    required this.shift,
    required this.scale,
    required this.origin,
  });

  final double shift;
  final double scale;
  final Offset origin;

  static const _width = 22.0;
  static const _period = 56.0;
  static const _strength = 0.34;

  /// The direction the stripes repeat in: 115 degrees clockwise from
  /// straight up, which is 25 degrees below the x axis.
  static const _lean = 25 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.card.withValues(alpha: _strength);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(origin.dx + shift * scale, origin.dy);
    canvas.scale(scale);
    canvas.rotate(_lean);
    // Stripes counted from the stage's corner, as many either way as cover
    // the box from any corner in the stripes' own direction.
    final reach = (size.width + size.height) / scale + 2 * _period;
    final count = (reach / _period).ceil();
    for (var i = -count; i <= count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * _period, -reach, _width, 2 * reach),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BattleFeverStripesPainter oldDelegate) =>
      oldDelegate.shift != shift ||
      oldDelegate.scale != scale ||
      oldDelegate.origin != origin;
}
