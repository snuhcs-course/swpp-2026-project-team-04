import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'battle_art_path.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_model.dart';
import 'character_figure.dart';
import 'gym_owner_figure.dart';

/// The arcade's small drawings (P16 design), each in the design's own 24 x 24
/// box with its own path data.
enum ArcadeGlyph {
  /// A star: filled with [ArcadeGlyphIcon.fill], edged ink.
  star,

  /// The boss crown: amber, edged ink.
  crown,

  /// A floor rule's bolt: filled.
  bolt,

  /// A closed lock, and an open one.
  lock,
  unlock,

  /// A hold stage's stopwatch.
  timer,

  /// The push-up and squat figures.
  pushUp,
  squat,

  /// A won round's check and a lost round's cross.
  check,
  cross,

  /// A dark button's arrow.
  arrow,
}

/// One [ArcadeGlyph], [size] square, drawn in [color] with its design's
/// stroke ([strokeWidth] in its 24-point box, or the design's own).
class ArcadeGlyphIcon extends StatelessWidget {
  const ArcadeGlyphIcon(
    this.glyph, {
    super.key,
    this.size = defaultSize,
    this.color = AppColors.ink,
    this.fill,
    this.strokeWidth,
  });

  /// The design's 24-point box.
  static const defaultSize = 24.0;

  final ArcadeGlyph glyph;
  final double size;

  /// The lines, or for [ArcadeGlyph.bolt] the fill.
  final Color color;

  /// A star's or the crown's fill.
  final Color? fill;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: ArcadeGlyphPainter(
        glyph,
        color: color,
        fill: fill,
        strokeWidth: strokeWidth,
      ),
    ),
  );
}

/// Paints an [ArcadeGlyph] scaled from its 24-point box to the canvas.
class ArcadeGlyphPainter extends CustomPainter {
  const ArcadeGlyphPainter(
    this.glyph, {
    required this.color,
    this.fill,
    this.strokeWidth,
  });

  final ArcadeGlyph glyph;
  final Color color;
  final Color? fill;
  final double? strokeWidth;

  static const _box = 24.0;

  /// The lock's body corners and its shackle's bend.
  static const _lockCorner = 2.0;
  static const _shackle = 4.0;

  static const starPath =
      'M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3 6.1 20.6l1.3-6.6L2.5 '
      '9.4l6.6-.8z';
  static const _crown = 'M3 8l4.5 4L12 5l4.5 7L21 8l-2 11H5z';
  static const _bolt = 'M13 2L4 14h7l-1 8 9-12h-7z';
  static const _timer = 'M12 14V10.5M10 3h4';
  static const _pushUp = 'M7 10.6l13 3.9M8.6 11.1V17M20 14.5l1.3 2.6M2 19.5h20';
  static const _squat = 'M10.5 6.5L9 12.5l5.5.6-1.5 6M10 8.6l6.5.4M4 20h16';
  static const _check = 'M5 12.5l4.5 4.5L19 7.5';
  static const _cross = 'M6 6l12 12M18 6L6 18';
  static const _arrow = 'M5 12h14M13 6l6 6-6 6';

  /// The design's stroke for each glyph, in its box.
  static double defaultStroke(ArcadeGlyph glyph) => switch (glyph) {
    ArcadeGlyph.star => 2,
    ArcadeGlyph.crown => 2.4,
    ArcadeGlyph.bolt => 0,
    ArcadeGlyph.lock || ArcadeGlyph.unlock || ArcadeGlyph.timer => 2.8,
    ArcadeGlyph.pushUp || ArcadeGlyph.squat => 2,
    ArcadeGlyph.check => 3.4,
    ArcadeGlyph.cross => 3.6,
    ArcadeGlyph.arrow => 2.6,
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _box, size.height / _box);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = strokeWidth ?? defaultStroke(glyph)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.ink
      ..strokeWidth = strokeWidth ?? defaultStroke(glyph)
      ..strokeJoin = StrokeJoin.round;
    switch (glyph) {
      case ArcadeGlyph.star:
        final path = battleArtPath(starPath);
        canvas
          ..drawPath(path, Paint()..color = fill ?? AppColors.starOn)
          ..drawPath(path, ink);
      case ArcadeGlyph.crown:
        final path = battleArtPath(_crown);
        canvas
          ..drawPath(path, Paint()..color = fill ?? AppColors.starOn)
          ..drawPath(path, ink);
      case ArcadeGlyph.bolt:
        canvas.drawPath(battleArtPath(_bolt), Paint()..color = color);
      case ArcadeGlyph.lock:
      case ArcadeGlyph.unlock:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 11, 14, 10),
            const Radius.circular(_lockCorner),
          ),
          line,
        );
        // "M8 11V8a4 4 0 0 1 8 0v3", or open: "M8 11V8a4 4 0 0 1 7.5-2".
        final shackle = Path()
          ..moveTo(8, 11)
          ..lineTo(8, 8);
        if (glyph == ArcadeGlyph.lock) {
          shackle
            ..arcToPoint(
              const Offset(16, 8),
              radius: const Radius.circular(_shackle),
            )
            ..lineTo(16, 11);
        } else {
          shackle.arcToPoint(
            const Offset(15.5, 6),
            radius: const Radius.circular(_shackle),
          );
        }
        canvas.drawPath(shackle, line);
      case ArcadeGlyph.timer:
        canvas
          ..drawCircle(const Offset(12, 14), 7.5, line)
          ..drawPath(battleArtPath(_timer), line);
      case ArcadeGlyph.pushUp:
        canvas
          ..drawCircle(const Offset(4.5, 9), 2, line)
          ..drawPath(battleArtPath(_pushUp), line);
      case ArcadeGlyph.squat:
        canvas
          ..drawCircle(const Offset(10.5, 4), 2, line)
          ..drawPath(battleArtPath(_squat), line);
      case ArcadeGlyph.check:
        canvas.drawPath(battleArtPath(_check), line);
      case ArcadeGlyph.cross:
        canvas.drawPath(battleArtPath(_cross), line);
      case ArcadeGlyph.arrow:
        canvas.drawPath(battleArtPath(_arrow), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ArcadeGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.fill != fill ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Where each W3 character's face is centred in its 140 x 160 box, for the
/// round face crops (the design's `FACE`). The gym owners' are A3's
/// [gymOwnerFaceCenters], the same points.
const arcadeFaceCenters = <String, Offset>{
  'mouse': Offset(72, 55),
  'kangaroo': Offset(76, 50),
  'bear': Offset(72, 62),
  'penguin': Offset(70, 66),
  'seal': Offset(70, 66),
  'bot': Offset(78, 52),
};

/// A face cut round to a [size] square (the parent clips the circle): the
/// W3 character [id], or with [owner] the gym owner [id] in goggles, at
/// [scale], its face in the middle (the design's `face(id, size, k)`).
/// Locked ([gray]), it is grey and half seen through.
class ArcadeFace extends StatelessWidget {
  const ArcadeFace({
    super.key,
    required this.id,
    required this.size,
    required this.scale,
    this.owner = false,
    this.gray = false,
  });

  final String id;
  final double size;
  final double scale;
  final bool owner;
  final bool gray;

  /// Half seen through when locked (the design's `faceOp`).
  static const lockedOpacity = 0.5;

  static const _grayscale = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final center =
        (owner ? gymOwnerFaceCenters[id] : arcadeFaceCenters[id]) ??
        arcadeFaceCenters['mouse']!;
    Widget figure = owner
        ? GymOwnerFigure(ownerId: id, scale: scale)
        : CharacterFigure(
            characterId: id,
            side: BattleSide.opponent,
            scale: scale,
          );
    if (gray) {
      figure = Opacity(
        opacity: lockedOpacity,
        child: ColorFiltered(colorFilter: _grayscale, child: figure),
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: size / 2 - center.dx * scale,
              top: size / 2 - center.dy * scale,
              child: figure,
            ),
          ],
        ),
      ),
    );
  }

  /// [child] grey, as a locked floor's picture (`grayscale(1)`).
  static Widget grayed(Widget child) =>
      ColorFiltered(colorFilter: _grayscale, child: child);
}

/// [child] edged white [width] wide all round, as the design's four white
/// drop shadows: eight white copies under it.
class ArcadeWhiteOutline extends StatelessWidget {
  const ArcadeWhiteOutline({
    super.key,
    required this.child,
    this.width = defaultWidth,
  });

  /// The design's `drop-shadow(2.5px ...)`.
  static const defaultWidth = 2.5;

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ExcludeSemantics(
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              AppColors.card,
              BlendMode.srcIn,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final dx in [-width, 0.0, width])
                  for (final dy in [-width, 0.0, width])
                    if (dx != 0 || dy != 0)
                      Transform.translate(offset: Offset(dx, dy), child: child),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A W3 character standing on its feet in a 140 x 160 box times [scale]:
/// [pose] in [side]'s color, facing left with [mirror], edged white. The
/// design's characters on the arcade's screens (`ChB` with a white edge).
class ArcadeFigure extends StatelessWidget {
  const ArcadeFigure({
    super.key,
    required this.id,
    this.pose = BattlePose.idle,
    this.side = BattleSide.opponent,
    this.scale = 1,
    this.mirror = false,
    this.outline = true,
  });

  final String id;
  final BattlePose pose;
  final BattleSide side;
  final double scale;
  final bool mirror;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    Widget figure = CharacterFigure(
      characterId: id,
      pose: pose,
      side: side,
      scale: scale,
    );
    if (outline) figure = ArcadeWhiteOutline(child: figure);
    if (mirror) {
      figure = Transform.flip(flipX: true, child: figure);
    }
    return ExcludeSemantics(child: figure);
  }
}

/// A gym owner in goggles in a 140 x 160 box times [scale], facing left
/// with [mirror], edged white: `CoachB` on the arcade's screens.
class ArcadeOwnerFigure extends StatelessWidget {
  const ArcadeOwnerFigure({
    super.key,
    required this.id,
    this.face = GymOwnerFace.watch,
    this.scale = 1,
    this.mirror = false,
    this.idle = false,
  });

  final String id;
  final GymOwnerFace face;
  final double scale;
  final bool mirror;
  final bool idle;

  @override
  Widget build(BuildContext context) {
    Widget figure = ArcadeWhiteOutline(
      child: GymOwnerFigure(ownerId: id, face: face, scale: scale, idle: idle),
    );
    if (mirror) figure = Transform.flip(flipX: true, child: figure);
    return ExcludeSemantics(child: figure);
  }
}

/// The arcade's dark button: a white label slanted 10° and a lime arrow on
/// ink, [height] high with 16 corners ("도전", "다음 스테이지", "자세 잡기").
class ArcadeDarkButton extends StatelessWidget {
  const ArcadeDarkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = defaultHeight,
    this.style,
    this.arrowSize = defaultArrow,
    this.gap = AppSpacing.s8,
    this.padding = 0,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  /// The label's style; [ArcadeText.arcadeAction] by default.
  final TextStyle? style;
  final double arrowSize;
  final double gap;

  /// The room on each side, for a button that hugs its label.
  final double padding;

  static const defaultHeight = 56.0;
  static const defaultArrow = 20.0;
  static const radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Transform(
                      transform: AppHighlight.slant,
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style ?? text.arcadeAction,
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  ArcadeGlyphIcon(
                    ArcadeGlyph.arrow,
                    size: arrowSize,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The arcade's light button: a 14 bold label on white with a 1.5 grey
/// edge, 56 high ("닫기", "리포트 보기", "아케이드로").
class ArcadeLightButton extends StatelessWidget {
  const ArcadeLightButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  static const _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ArcadeDarkButton.defaultHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.ink,
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.line, width: _edge),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ArcadeDarkButton.radius),
          ),
          textStyle: Theme.of(context).textTheme.arcadeSecondary,
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// An underlined text button under the arcade's buttons: "아케이드로",
/// "그만하기". Its tap area is at least 44 high.
class ArcadeTextLink extends StatelessWidget {
  const ArcadeTextLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  static const _height = 44.0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(_height, _height),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
        foregroundColor: AppColors.textSecondary,
        textStyle: Theme.of(context).textTheme.arcadeLink,
      ),
      child: Text(label),
    );
  }
}

/// The results' title on its band (`ArcResult` title): [label] tilted 3°
/// on a [color] band slanted 12° and tilted with it, edged ink, with an
/// ink shadow 4 right and 5 down.
class ArcadeTitleBand extends StatelessWidget {
  const ArcadeTitleBand({
    super.key,
    required this.label,
    required this.color,
    required this.style,
    this.padding = defaultPadding,
  });

  final String label;
  final Color color;
  final TextStyle style;

  /// Around the label, inside the band.
  final EdgeInsets padding;

  /// The design's room around the title: 22 beside it, 2 over, 6 under.
  static const defaultPadding = EdgeInsets.fromLTRB(
    _side,
    _over,
    _side,
    _under,
  );
  static const _side = 22.0;
  static const _over = 2.0;
  static const _under = 6.0;

  static const _tilt = -3 * math.pi / 180;
  static const _edge = 3.0;
  static const _shadow = Offset(4, 5);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform(
              alignment: Alignment.center,
              transform: AppHighlight.battleSlant..rotateZ(_tilt),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    left: _shadow.dx,
                    top: _shadow.dy,
                    right: -_shadow.dx,
                    bottom: -_shadow.dy,
                    child: const ColoredBox(color: AppColors.ink),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: AppColors.ink, width: _edge),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: Transform.rotate(
              angle: _tilt,
              child: Text(label, style: style),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip slanted 12°: [label] upright on an ink (or [color]) fill, "STAGE
/// 8" on the stage sheet, "2F" on the bands and the next floor's card.
class ArcadeSlantChip extends StatelessWidget {
  const ArcadeSlantChip({
    super.key,
    required this.label,
    required this.style,
    this.color = AppColors.ink,
    this.height = defaultHeight,
    this.padding = defaultPadding,
  });

  static const defaultHeight = 26.0;
  static const defaultPadding = 10.0;

  final String label;
  final TextStyle style;
  final Color color;
  final double height;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Transform(
              transform: AppHighlight.battleSlant,
              alignment: Alignment.center,
              child: ColoredBox(color: color),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Text(label, style: style, maxLines: 1),
          ),
        ],
      ),
    );
  }
}

/// One star condition per row with its stars before it, on white (the
/// stage sheet's and the boss intro's 별 조건): row i shows i stars, lit
/// when the stage's best is at least i ([best]); dark lines between rows.
class ArcadeStarGoals extends StatelessWidget {
  const ArcadeStarGoals({
    super.key,
    required this.labels,
    required this.best,
    required this.style,
    this.title,
  });

  final List<String> labels;

  /// The most stars got in the stage, 0 to 3.
  final int best;
  final TextStyle style;

  /// "별 조건" over the rows; none on the boss intro.
  final String? title;

  static const _starSize = 16.0;
  static const _starsWidth = 50.0;
  static const _side = 14.0;
  static const _rowPadding = EdgeInsets.symmetric(
    horizontal: _side,
    vertical: AppSpacing.s8,
  );
  static const _edge = 1.5;
  static const _titleTop = 10.0;
  static const _titlePadding = EdgeInsets.fromLTRB(
    _side,
    _titleTop,
    _side,
    AppSpacing.s4,
  );
  static const _starGap = 1.0;
  static const _labelGap = 10.0;
  static const _corners = 16.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = this.title;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_corners),
        border: Border.all(color: AppColors.border, width: _edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: _titlePadding,
              child: Text(title, style: text.arcadeSheetChip),
            ),
          for (final (index, label) in labels.indexed)
            Semantics(
              label: '별 ${index + 1}개, $label${best > index ? ', 받음' : ''}',
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: index == 0
                      ? null
                      : const Border(top: BorderSide(color: AppColors.starOff)),
                ),
                child: Padding(
                  padding: _rowPadding,
                  child: Row(
                    children: [
                      SizedBox(
                        width: _starsWidth,
                        child: Row(
                          children: [
                            for (var star = 0; star < 3; star++) ...[
                              if (star > 0) const SizedBox(width: _starGap),
                              ArcadeGlyphIcon(
                                ArcadeGlyph.star,
                                size: _starSize,
                                fill: star <= index && best > index
                                    ? AppColors.starOn
                                    : AppColors.starOff,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: _labelGap),
                      Expanded(child: Text(label, style: style)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "내 : 상대" between the two color swatches; the winner's number larger
/// ([meLarger]).
class ArcadeScoreLine extends StatelessWidget {
  const ArcadeScoreLine({
    super.key,
    required this.me,
    required this.opponent,
    required this.meLarger,
  });

  final int me;
  final int opponent;
  final bool meLarger;

  static const _swatch = 12.0;
  static const _swatchEdge = 1.5;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget swatch(Color color) => Container(
      width: _swatch,
      height: _swatch,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.mark),
        border: Border.all(color: AppColors.ink, width: _swatchEdge),
      ),
    );
    return Semantics(
      label: '내 점수 $me, 상대 점수 $opponent',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          swatch(AppColors.accent),
          const SizedBox(width: _gap),
          Text(
            '$me',
            style: meLarger ? text.arcadeScoreBig : text.arcadeScoreSmall,
          ),
          const SizedBox(width: _gap),
          Text(':', style: text.arcadeScoreColon),
          const SizedBox(width: _gap),
          Text(
            '$opponent',
            style: meLarger ? text.arcadeScoreSmall : text.arcadeScoreBig,
          ),
          const SizedBox(width: _gap),
          swatch(AppColors.opponent),
        ],
      ),
    );
  }
}

/// A white pedestal under a standing figure, edged ink: [width] wide, 16
/// high (14 on the break) with 7 corners.
class ArcadePedestal extends StatelessWidget {
  const ArcadePedestal({
    super.key,
    required this.width,
    this.height = defaultHeight,
  });

  static const defaultHeight = 16.0;

  final double width;
  final double height;

  static const _edge = 3.0;
  static const _radius = 7.0;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(_radius),
      border: Border.all(color: AppColors.ink, width: _edge),
    ),
  );
}

/// `repeating-linear-gradient(135deg, amber 0 w, ink w 2w)`.
class ArcadeStripesPainter extends CustomPainter {
  const ArcadeStripesPainter(this.stripe);

  final double stripe;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(
            stripe * 2 * 0.7071067811865476,
            stripe * 2 * 0.7071067811865476,
          ),
          const [
            AppColors.warning,
            AppColors.warning,
            AppColors.ink,
            AppColors.ink,
          ],
          const [0, 0.5, 0.5, 1],
          TileMode.repeated,
        ),
    );
  }

  @override
  bool shouldRepaint(ArcadeStripesPainter oldDelegate) =>
      oldDelegate.stripe != stripe;
}

/// A boss round's pip at the bottom right of the battle's camera (design
/// `ArcPlay` `round`): "R1" with the rounds as dots, lime up to this one.
class ArcadeRoundPip extends StatelessWidget {
  const ArcadeRoundPip({super.key, required this.round});

  /// 1 or 2.
  final int round;

  /// From the camera's right and bottom edges.
  static const inset = 14.0;
  static const bottom = 16.0;

  static const _height = 30.0;
  static const _side = 10.0;
  static const _edge = 2.0;
  static const _gap = 6.0;
  static const _dot = 10.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '보스 매치 $round라운드',
      excludeSemantics: true,
      child: Container(
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: _side),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(_height / 2),
          border: Border.all(color: AppColors.ink, width: _edge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'R$round',
              style: Theme.of(context).textTheme.arcadeRoundTag
                  .copyWith(color: AppColors.ink),
            ),
            for (var dot = 1; dot <= 2; dot++) ...[
              const SizedBox(width: _gap),
              Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  color: dot <= round ? AppColors.accent : AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: _edge),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A faint grid, a line every [cell] points in the design's grey at
/// [strength]: the arcade screens' ground (28, 7%) and the stage sheet's
/// picture (22, 8%).
class ArcadeGridPainter extends CustomPainter {
  const ArcadeGridPainter({required this.cell, this.strength = groundStrength});

  final double cell;
  final double strength;

  /// The screens' ground: `rgba(88,96,115,0.07)` every 28.
  static const groundCell = 28.0;
  static const groundStrength = 0.07;

  /// The stage sheet's picture: 8% every 22.
  static const sheetCell = 22.0;
  static const sheetStrength = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.line.withValues(alpha: strength);
    for (var x = 0.0; x < size.width; x += cell) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += cell) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(ArcadeGridPainter oldDelegate) =>
      oldDelegate.cell != cell || oldDelegate.strength != strength;
}
