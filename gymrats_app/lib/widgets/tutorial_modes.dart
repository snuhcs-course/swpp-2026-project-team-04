import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/rankings/rankings_repository.dart';
import '../theme/app_theme.dart';
import 'arcade_parts.dart';
import 'battle_stage_model.dart';
import 'lobby_parts.dart';
import 'tutorial_figure_painters.dart';
import 'tutorial_person.dart';
import 'tutorial_setup_scenes.dart';

/// The game's second page (A13 design `TutModes`, 316 x 326): the online
/// battle above (펭뚱이 against GYM마우스 on a lime card, its four points
/// and the weekly ranking) and the arcade below (the seal gym owner on a
/// pink card, and the four exercises as small side views). The points come
/// from [RankingPoints], as the server counts them.
class TutorialModes extends StatelessWidget {
  const TutorialModes({super.key});

  static const size = Size(316, 326);

  /// What a screen reader hears (the design's `aria-label`).
  static String get label =>
      '온라인 대결: 다른 사람과 1:1 대결, '
      '${[for (final (name, points) in scores) '$name $points점'].join(', ')}, '
      '점수를 모아 주간 랭킹을 올려요. '
      '아케이드: 혼자서 층마다 보스 깨기, 푸시업, 스쿼트, 하이 플랭크, 의자 자세';

  /// The four points of an online battle, KO first (the lime one).
  static List<(String, int)> get scores => const [
    ('KO승', RankingPoints.koWin),
    ('승리', RankingPoints.win),
    ('무승부', RankingPoints.draw),
    ('패배', RankingPoints.loss),
  ];

  /// The four arcade exercises as drawn (`renderVals` `icon()` calls).
  static const icons = [
    TutorialModeIcon('푸시업', TutorialSidePose.push, 0.75, 0.5),
    TutorialModeIcon('스쿼트', TutorialSidePose.squat, 0.9, 0.38),
    TutorialModeIcon('플랭크', TutorialSidePose.push, 0, 0.5, clock: true),
    TutorialModeIcon(
      '의자 자세',
      TutorialSidePose.squat,
      1.08,
      0.44,
      clock: true,
      shift: -7,
    ),
  ];

  static const _cardLeft = AppSpacing.s12;
  static const _onlineTop = 12.0;
  static const _arcadeTop = 174.0;
  static const _wordsLeft = 142.0;
  static const _wordsWidth = 164.0;
  static const _onlineWordsTop = 16.0;
  static const _arcadeWordsTop = 178.0;
  static const _dividerTop = 162.0;
  static const _dividerHeight = 2.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: TutorialGridPainter(background: AppColors.card),
            ),
          ),
          const Positioned(
            left: _cardLeft,
            top: _onlineTop,
            child: _ModeCard(
              color: AppColors.accent,
              shade: AppColors.accentDeep,
              rises: true,
              child: _OnlinePicture(),
            ),
          ),
          const Positioned(
            left: _wordsLeft,
            top: _onlineWordsTop,
            width: _wordsWidth,
            child: _OnlineWords(),
          ),
          const Positioned(
            left: _cardLeft,
            right: _cardLeft,
            top: _dividerTop,
            height: _dividerHeight,
            child: ColoredBox(color: AppColors.border),
          ),
          const Positioned(
            left: _cardLeft,
            top: _arcadeTop,
            child: _ModeCard(
              color: AppColors.opponent,
              shade: AppColors.opponentDeep,
              rises: false,
              child: _ArcadePicture(),
            ),
          ),
          const Positioned(
            left: _wordsLeft,
            top: _arcadeWordsTop,
            width: _wordsWidth,
            child: _ArcadeWords(),
          ),
        ],
      ),
    );
  }
}

/// One arcade exercise's small side view: [pose] at [k] (0 up, 1 down),
/// [scale] times the body's units, its width's middle [shift] from the
/// board's middle, with a clock for a hold ([clock]). On a 60 x 47 board.
class TutorialModeIcon {
  const TutorialModeIcon(
    this.name,
    this.pose,
    this.k,
    this.scale, {
    this.clock = false,
    this.shift = 0,
  });

  final String name;
  final TutorialSidePose pose;
  final double k;
  final double scale;
  final bool clock;
  final double shift;

  /// The board the person is drawn on (the design's `viewBox`).
  static const board = Size(60, 47);

  /// The floor line's top; the feet stand on it.
  static const floorY = 41.0;

  /// The clock of a hold: its middle and radius.
  static const clockCenter = Offset(44.5, 14.5);
  static const clockRadius = 8.6;

  /// The person placed on the board (the design's `T`).
  SideJoints get joints => TutorialSide.place(
    TutorialSide.joints(pose, k),
    scale: scale,
    centerX: board.width / 2 + shift,
    floorY: floorY,
  );

  SideShapes get shapes => TutorialSide.shapes(joints, scale);
}

/// A card of [color] 118 x 140 with a 2 ink edge and 14 corners, [shade]
/// under an edge rising to the right ([rises]: from 62% down on the left to
/// 34% on the right) or falling; [child] is laid out inside the edge, as
/// the design's box, and clipped there.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.color,
    required this.shade,
    required this.rises,
    required this.child,
  });

  final Color color;
  final Color shade;
  final bool rises;
  final Widget child;

  static const size = Size(118, 140);
  static const _edge = 2.0;
  static const _corner = 14.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: AppColors.ink, width: _edge),
        borderRadius: const BorderRadius.all(Radius.circular(_corner)),
      ),
      padding: const EdgeInsets.all(_edge),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(_corner - _edge)),
        child: CustomPaint(
          painter: _PanelPainter(color, shade, rises: rises),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

/// [color] with [shade] under a slanted edge (`clip-path` 62% / 34%).
class _PanelPainter extends CustomPainter {
  const _PanelPainter(this.color, this.shade, {required this.rises});

  final Color color;
  final Color shade;
  final bool rises;

  static const _low = 0.62;
  static const _high = 0.34;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final (left, right) = rises ? (_low, _high) : (_high, _low);
    canvas.drawPath(
      Path()..addPolygon([
        Offset(0, size.height * left),
        Offset(size.width, size.height * right),
        Offset(size.width, size.height),
        Offset(0, size.height),
      ], true),
      Paint()..color = shade,
    );
  }

  @override
  bool shouldRepaint(_PanelPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.shade != shade ||
      oldDelegate.rises != rises;
}

/// A character's 140 x 160 box placed for its feet at [feet], [scale] times
/// its size about the feet (the design's `transform-origin: 70px 150px`).
Widget _standing(Offset feet, double scale, Widget figure) => Positioned(
  left: feet.dx - _box.width / 2,
  top: feet.dy - _feet.dy,
  child: Transform(
    transform: Matrix4.diagonal3Values(scale, scale, 1),
    origin: _feet,
    child: SizedBox.fromSize(size: _box, child: figure),
  ),
);

const _box = Size(140, 160);
const _feet = Offset(70, 150);

/// 펭뚱이 (the opponent, facing left) high on the right, GYM마우스 (the
/// user) low on the left, each on a disc, VS between.
class _OnlinePicture extends StatelessWidget {
  const _OnlinePicture();

  /// The feet, from the card's 118 x 140 (the design's 0.6w 0.42h and
  /// 0.38w 0.86h).
  static const opponentFeet = Offset(70.8, 58.8);
  static const meFeet = Offset(44.84, 120.4);
  static const scale = 0.4;

  /// The VS chip's middle (0.8w, 0.58h).
  static const vs = Offset(94.4, 81.2);

  static const _discWidth = 59.0;
  static const _discHeight = 12.0;
  static const _discEdge = 2.5;
  static const _discShade = 0.55;

  @override
  Widget build(BuildContext context) {
    Widget disc(Offset feet) => Positioned(
      left: feet.dx - _discWidth / 2,
      top: feet.dy - _discHeight / 2,
      child: Container(
        width: _discWidth,
        height: _discHeight,
        decoration: ShapeDecoration(
          color: AppColors.card.withValues(alpha: _discShade),
          shape: const OvalBorder(
            side: BorderSide(color: AppColors.ink, width: _discEdge),
          ),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        disc(opponentFeet),
        disc(meFeet),
        _standing(
          opponentFeet,
          scale,
          const ArcadeFigure(id: 'penguin', mirror: true),
        ),
        _standing(
          meFeet,
          scale,
          const ArcadeFigure(id: 'mouse', side: BattleSide.me),
        ),
        Positioned(
          left: vs.dx,
          top: vs.dy,
          child: const FractionalTranslation(
            translation: Offset(-0.5, -0.5),
            child: _VsChip(),
          ),
        ),
      ],
    );
  }
}

/// The game start card's ink "VS" chip made small: Oxanium 800 12 in white,
/// slanted 10°.
class _VsChip extends StatelessWidget {
  const _VsChip();

  static const _side = 6.0;
  static const _under = 1.0;
  static const _padding = EdgeInsets.fromLTRB(_side, 0, _side, _under);
  static const _corner = 6.0;
  static const _size = 12.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.arcadeVsChip;
    return Container(
      padding: _padding,
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(_corner)),
      ),
      child: LobbySkew(
        degrees: 10,
        alignment: Alignment.center,
        child: TutorialModeWord('VS', style: style, size: _size),
      ),
    );
  }
}

/// The seal gym owner (facing left) on an ink floor line.
class _ArcadePicture extends StatelessWidget {
  const _ArcadePicture();

  static const feet = Offset(59, 120.4);
  static const scale = 0.62;
  static const _lineSide = AppSpacing.s12;
  static const _lineHeight = 3.0;
  static const _lineCorner = 2.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _lineSide,
          right: _lineSide,
          top: feet.dy - _lineHeight / 2,
          height: _lineHeight,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.all(Radius.circular(_lineCorner)),
            ),
          ),
        ),
        _standing(
          feet,
          scale,
          const ArcadeOwnerFigure(id: 'seal', mirror: true),
        ),
      ],
    );
  }
}

/// A mode's name in Do Hyeon 23, slanted 8° (`skewX(-8deg)` about its
/// bottom left).
class _ModeName extends StatelessWidget {
  const _ModeName(this.name);

  final String name;

  static const _size = 23.0;

  @override
  Widget build(BuildContext context) => LobbySkew(
    degrees: 8,
    child: TutorialModeWord(
      name,
      style: Theme.of(context).textTheme.arcadeCardName,
      size: _size,
      lineHeight: _size,
    ),
  );
}

/// A mode's one-line summary: 13 bold on 18.
class _Summary extends StatelessWidget {
  const _Summary(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => TutorialModeWord(
    text,
    style: Theme.of(context).textTheme.rankingName,
    size: 13,
    lineHeight: 18,
  );
}

const _wordsGap = 6.0;

class _OnlineWords extends StatelessWidget {
  const _OnlineWords();

  static const _summaryDrop = 2.0;
  static const _scoreGap = AppSpacing.s4;
  static const _scoreHeight = 22.0;
  static const _scoreEdge = 1.5;
  static const _scoreCorner = 6.0;
  static const _scoreTop = 3.0;
  static const _scoreInnerGap = 3.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scores = TutorialModes.scores;
    Widget score((String, int) entry, {required bool ko}) {
      final (name, points) = entry;
      return Container(
        height: _scoreHeight,
        padding: const EdgeInsets.only(top: _scoreTop),
        decoration: BoxDecoration(
          color: ko ? AppColors.accent : AppColors.card,
          border: Border.all(color: AppColors.ink, width: _scoreEdge),
          borderRadius: const BorderRadius.all(Radius.circular(_scoreCorner)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TutorialModeWord(name, style: text.rankingName, size: 10.5),
            const SizedBox(width: _scoreInnerGap),
            TutorialModeWord(
              '$points',
              style: text.rankingGoalNumber,
              size: 12.5,
            ),
            TutorialModeWord('점', style: text.rankingName, size: 10.5),
          ],
        ),
      );
    }

    Widget pair(int first) => Row(
      children: [
        Expanded(child: score(scores[first], ko: first == 0)),
        const SizedBox(width: _scoreGap),
        Expanded(child: score(scores[first + 1], ko: false)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ModeName('온라인 대결'),
        const SizedBox(height: _wordsGap + _summaryDrop),
        const _Summary('다른 사람과 1:1 대결'),
        const SizedBox(height: _wordsGap),
        pair(0),
        const SizedBox(height: _scoreGap),
        pair(2),
        const SizedBox(height: _wordsGap),
        TutorialModeWord(
          '점수를 모아 주간 랭킹을 올려요',
          style: text.rankingName.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          size: 11.5,
          lineHeight: 16,
        ),
      ],
    );
  }
}

class _ArcadeWords extends StatelessWidget {
  const _ArcadeWords();

  static const _summaryDrop = AppSpacing.s4;
  static const _iconGap = AppSpacing.s4;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ModeName('아케이드'),
        const SizedBox(height: _wordsGap + _summaryDrop),
        const _Summary('혼자서 층마다 보스 깨기'),
        const SizedBox(height: _wordsGap),
        Row(
          children: [
            for (final (index, icon) in TutorialModes.icons.indexed) ...[
              if (index > 0) const SizedBox(width: _iconGap),
              _ExerciseIcon(icon),
            ],
          ],
        ),
      ],
    );
  }
}

/// An exercise's 37 x 29 white tile with its person and its name under it.
class _ExerciseIcon extends StatelessWidget {
  const _ExerciseIcon(this.icon);

  final TutorialModeIcon icon;

  static const tile = Size(37, 29);
  static const _edge = 1.5;
  static const _corner = 9.0;
  static const _nameGap = 2.0;
  static const _nameSize = 10.5;
  static const _nameLine = 13.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tile.width,
      child: Column(
        children: [
          Container(
            width: tile.width,
            height: tile.height,
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: AppColors.ink, width: _edge),
              borderRadius: const BorderRadius.all(Radius.circular(_corner)),
            ),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.all(Radius.circular(_corner)),
            ),
            padding: const EdgeInsets.all(_edge),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(_corner - _edge),
              ),
              // The board starts at the tile's outer corner, as the
              // design's svg at (-1.5, -1.5) inside the edge.
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Transform.translate(
                  offset: const Offset(-_edge, -_edge),
                  child: CustomPaint(
                    size: tile,
                    painter: TutorialModeIconPainter(icon),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _nameGap),
          SizedBox(
            width: tile.width,
            height: _nameLine,
            child: OverflowBox(
              maxWidth: double.infinity,
              child: TutorialModeWord(
                icon.name,
                style: Theme.of(context).textTheme.rankingName,
                size: _nameSize,
                lineHeight: _nameLine,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [icon]'s floor line, person and clock on its 60 x 47 board, scaled to
/// the size it is given (the design's 37 x 29 svg).
class TutorialModeIconPainter extends CustomPainter {
  const TutorialModeIconPainter(this.icon);

  final TutorialModeIcon icon;

  static const _floor = Rect.fromLTWH(4, TutorialModeIcon.floorY, 52, 2.4);
  static const _floorRound = 1.2;
  static const _floorCorner = Radius.circular(_floorRound);
  static const _armEdge = 1.2;
  static const _clockEdge = 1.7;

  @override
  void paint(Canvas canvas, Size size) {
    const board = TutorialModeIcon.board;
    canvas
      ..save()
      ..scale(size.width / board.width, size.height / board.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(_floor, _floorCorner),
      Paint()..color = AppColors.pictogramFloor,
    );
    final shapes = icon.shapes;
    final far = Paint()..color = AppColors.textSecondary;
    final ink = Paint()..color = AppColors.ink;
    for (final piece in [...shapes.farLeg, ...shapes.farArm]) {
      canvas.drawPath(piece, far);
    }
    // No nose: the small views draw the head round (`TutModes`).
    for (final piece in [
      ...shapes.leg,
      ...shapes.torso,
      ...shapes.neck,
      ...shapes.head,
    ]) {
      canvas.drawPath(piece, ink);
    }
    TutorialSidePainter.paintEdged(canvas, shapes.arm, _armEdge);
    if (icon.clock) _paintClock(canvas);
    canvas.restore();
  }

  static void _paintClock(Canvas canvas) {
    const center = TutorialModeIcon.clockCenter;
    final edge = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _clockEdge
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawCircle(
        center,
        TutorialModeIcon.clockRadius,
        Paint()..color = AppColors.warning,
      )
      ..drawCircle(center, TutorialModeIcon.clockRadius, edge)
      ..drawPath(
        Path()
          ..moveTo(center.dx, 9.9)
          ..lineTo(center.dx, center.dy)
          ..lineTo(47.7, 16.5),
        edge,
      );
  }

  @override
  bool shouldRepaint(TutorialModeIconPainter oldDelegate) =>
      oldDelegate.icon != icon;
}

/// [text] in [style] drawn at [size] inside the picture: the style scaled
/// as a whole (the theme keeps one size per style; the picture's words
/// follow the design's), laid out as large as it is drawn. [lineHeight]
/// gives the design's line box, the words in its middle; without it, the
/// style's own line.
class TutorialModeWord extends StatelessWidget {
  const TutorialModeWord(
    this.text, {
    super.key,
    required this.style,
    required this.size,
    this.lineHeight,
  });

  final String text;
  final TextStyle style;
  final double size;
  final double? lineHeight;

  double get scale => size / style.fontSize!;

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final width = painter.width * scale;
    final drawn = painter.height * scale;
    final baseline =
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic) *
        scale;
    painter.dispose();
    final height = lineHeight ?? drawn;
    final top = (height - drawn) / 2;
    return _Baseline(
      baseline: top + baseline,
      child: SizedBox(
        width: width,
        height: height,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(0, top),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: Text(
                text,
                style: style,
                maxLines: 1,
                softWrap: false,
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [child] reporting [baseline] as its alphabetic baseline, so scaled words
/// line up in a baseline row.
class _Baseline extends SingleChildRenderObjectWidget {
  const _Baseline({required this.baseline, required super.child});

  final double baseline;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBaseline(baseline);

  @override
  void updateRenderObject(BuildContext context, _RenderBaseline renderObject) {
    renderObject.baseline = baseline;
  }
}

class _RenderBaseline extends RenderProxyBox {
  _RenderBaseline(this._baseline);

  double _baseline;
  set baseline(double value) {
    if (value == _baseline) return;
    _baseline = value;
    markNeedsLayout();
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;
}
