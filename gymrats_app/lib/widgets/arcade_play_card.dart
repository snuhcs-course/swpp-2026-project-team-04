import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'arcade_parts.dart';
import 'battle_stage_model.dart';
import 'lobby_parts.dart';

/// One of 게임 시작's two cards (P16 spec 3, design `PlayX`): a color panel
/// with its characters, a slanted shade and an arrow chip, and the name
/// under it. 온라인 대결: 펭뚱이 against GYM마우스 on two discs with VS
/// between them, on lime. 아케이드: 1F's gym owner in goggles on a floor
/// line, on pink. The pictures are fixed: the online card's lower
/// character is always GYM마우스, not the user's.
class ArcadePlayCard extends StatelessWidget {
  const ArcadePlayCard._({
    required this.name,
    required this.color,
    required this.shade,
    required this.shadeRises,
    required this.picture,
    required this.onTap,
  });

  /// 온라인 대결.
  const ArcadePlayCard.online({required VoidCallback onTap})
    : this._(
        name: '온라인 대결',
        color: AppColors.accent,
        shade: AppColors.accentDeep,
        shadeRises: true,
        picture: const _OnlinePicture(),
        onTap: onTap,
      );

  /// 아케이드.
  const ArcadePlayCard.arcade({required VoidCallback onTap})
    : this._(
        name: '아케이드',
        color: AppColors.opponent,
        shade: AppColors.opponentDeep,
        shadeRises: false,
        picture: const _ArcadePicture(),
        onTap: onTap,
      );

  final String name;
  final Color color;
  final Color shade;

  /// Whether the shade's edge rises to the right (else it falls).
  final bool shadeRises;
  final Widget picture;
  final VoidCallback onTap;

  /// The design's card and its color panel.
  static const width = 154.0;
  static const height = 430.0;
  static const panel = Size(152, 306);

  /// The room between the page's title and the cards.
  static const topGap = 22.0;

  static const _corners = 18.0;
  static const _arrowChip = 34.0;
  static const _arrowCorners = 11.0;
  static const _arrowInset = 10.0;
  static const _arrow = 18.0;
  static const _arrowStroke = 2.8;
  static const _nameSide = 14.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: name,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: AppColors.card,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_corners),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: panel.height,
                  child: ClipRect(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PanelPainter(
                              color,
                              shade,
                              rises: shadeRises,
                            ),
                          ),
                        ),
                        Positioned.fill(child: picture),
                        Positioned(
                          right: _arrowInset,
                          bottom: _arrowInset,
                          child: Container(
                            width: _arrowChip,
                            height: _arrowChip,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(
                                _arrowCorners,
                              ),
                            ),
                            child: ArcadeGlyphIcon(
                              ArcadeGlyph.arrow,
                              size: _arrow,
                              color: color,
                              strokeWidth: _arrowStroke,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _nameSide),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: LobbySkew(
                          degrees: 8,
                          alignment: Alignment.center,
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.arcadeCardName,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [color] with [shade] under a slanted edge: from 62% down on the left to
/// 34% on the right when it [rises], the other way when not (the design's
/// `clip-path` polygons).
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

/// Where a character's 140 x 160 box goes for its feet at [feet] in the
/// panel (`fighter`, `coach`: the box's top left is the feet less (70,
/// 150)), and its size about the feet, facing left with [mirror].
Widget _standing(
  Offset feet,
  double scale,
  Widget figure, {
  bool mirror = false,
}) => Positioned(
  left: feet.dx - 70,
  top: feet.dy - 150,
  child: Transform(
    transform: Matrix4.diagonal3Values(mirror ? -scale : scale, scale, 1),
    origin: const Offset(70, 150),
    child: figure,
  ),
);

/// A disc under a fighter's feet: [width] wide, 16 high, centered on [x],
/// its middle on [y], white at 55% with an ink edge (`disc`).
Widget _disc(double x, double y, double width) => Positioned(
  left: x - width / 2,
  top: y - _OnlinePicture.discHalf,
  child: Container(
    width: width,
    height: _OnlinePicture.discHalf * 2,
    decoration: BoxDecoration(
      color: AppColors.card.withValues(alpha: _OnlinePicture.discShade),
      borderRadius: BorderRadius.all(
        Radius.elliptical(width / 2, _OnlinePicture.discHalf),
      ),
      border: Border.all(color: AppColors.ink, width: _OnlinePicture.discEdge),
    ),
  ),
);

/// 펭뚱이 (opponent, facing left) on the upper disc, GYM마우스 (user) on the
/// lower one, and VS between them.
class _OnlinePicture extends StatelessWidget {
  const _OnlinePicture();

  static const _opponentFeet = Offset(92, 118);
  static const _meFeet = Offset(60, 246);
  static const _scale = 0.62;
  static const _discWidth = 84.0;
  static const discHalf = 8.0;
  static const discShade = 0.55;
  static const discEdge = 3.0;
  static const _vs = Offset(76, 136);
  static const _vsPadding = EdgeInsets.fromLTRB(
    AppSpacing.s8,
    _vsOver,
    AppSpacing.s8,
    _vsUnder,
  );
  static const _vsOver = 1.0;
  static const _vsUnder = 2.0;
  static const _vsCorners = 8.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _disc(_opponentFeet.dx, _opponentFeet.dy, _discWidth),
          _disc(_meFeet.dx, _meFeet.dy, _discWidth),
          _standing(
            _opponentFeet,
            _scale,
            const ArcadeFigure(id: 'penguin'),
            mirror: true,
          ),
          _standing(
            _meFeet,
            _scale,
            const ArcadeFigure(id: 'mouse', side: BattleSide.me),
          ),
          Positioned(
            left: _vs.dx,
            top: _vs.dy,
            child: FractionalTranslation(
              translation: const Offset(-0.5, 0),
              child: Container(
                padding: _vsPadding,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(_vsCorners),
                ),
                child: LobbySkew(
                  degrees: 10,
                  alignment: Alignment.center,
                  child: Text(
                    'VS',
                    style: Theme.of(context).textTheme.arcadeVsChip,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1F's gym owner, 물렁범 in goggles, alone on an ink floor line, facing
/// left.
class _ArcadePicture extends StatelessWidget {
  const _ArcadePicture();

  static const _feet = Offset(78, 248);
  static const _scale = 1.1;
  static const _lineLeft = 16.0;
  static const _lineWidth = 120.0;
  static const _lineHeight = 4.0;
  static const _lineCorners = 2.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _lineLeft,
            top: _feet.dy - 1,
            child: Container(
              width: _lineWidth,
              height: _lineHeight,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(_lineCorners),
              ),
            ),
          ),
          _standing(
            _feet,
            _scale,
            const ArcadeOwnerFigure(id: 'seal'),
            mirror: true,
          ),
        ],
      ),
    );
  }
}
