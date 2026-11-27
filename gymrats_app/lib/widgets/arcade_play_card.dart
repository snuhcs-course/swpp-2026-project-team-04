import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'arcade_parts.dart';
import 'battle_stage_model.dart';
import 'lobby_parts.dart';

/// One of 게임 시작's two cards (P16 spec 3, design `PlayX`): a color panel
/// with its characters, a slanted shade and an arrow chip, and the name
/// under it, centered (A11 spec 3). 온라인 대결: 펭뚱이 against GYM마우스 on
/// two discs with VS between them, on lime. 아케이드: 1F's gym owner in
/// goggles on a floor line, on pink. The pictures are fixed: the online
/// card's lower character is always GYM마우스, not the user's.
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

  /// The name's room at either side (A11 `FrPlay` `names=new`: 10).
  static const _nameSide = 10.0;

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

/// [color] with [shade] under a slanted edge: from [low] down on the left to
/// [high] on the right when it [rises] (62% and 34% on the two cards), the
/// other way when not (the design's `clip-path` polygons).
class _PanelPainter extends CustomPainter {
  const _PanelPainter(
    this.color,
    this.shade, {
    required this.rises,
    this.low = 0.62,
    this.high = 0.34,
  });

  final Color color;
  final Color shade;
  final bool rises;
  final double low, high;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final (left, right) = rises ? (low, high) : (high, low);
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
      oldDelegate.rises != rises ||
      oldDelegate.low != low ||
      oldDelegate.high != high;
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
          _vsChip(_vs),
        ],
      ),
    );
  }
}

/// The ink "VS" chip with its middle on [at]'s x and its top on [at]'s y,
/// slanted 10° (the online card's and the friend card's).
Widget _vsChip(Offset at) => Positioned(
  left: at.dx,
  top: at.dy,
  child: const FractionalTranslation(
    translation: Offset(-0.5, 0),
    child: _VsChip(),
  ),
);

class _VsChip extends StatelessWidget {
  const _VsChip();

  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.s8,
    _over,
    AppSpacing.s8,
    _under,
  );
  static const _over = 1.0;
  static const _under = 2.0;
  static const _corners = 8.0;

  @override
  Widget build(BuildContext context) => Container(
    padding: _padding,
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(_corners),
    ),
    child: LobbySkew(
      degrees: 10,
      alignment: Alignment.center,
      child: Text('VS', style: Theme.of(context).textTheme.arcadeVsChip),
    ),
  );
}

/// 친구와의 대전's picture panel (A11 spec 3, `FrPlay` shape a, figure big):
/// 그루 (the user's team, lime) and 곰탱이 (the opponent's, pink, facing
/// left) on two discs with VS between their chests, on [AppColors.fever]
/// with its shade under an edge rising from 72% down on the left to 46% on
/// the right. Still pictures with the white edge, as on the cards above.
///
/// The [picture]-sized drawing is drawn at [scale] at the panel's bottom
/// center; the panel is as high and wide as its parent makes it (the friend
/// card: [picture]'s width times [scale]), the sky filling above.
class ArcadeFriendPanel extends StatelessWidget {
  const ArcadeFriendPanel({super.key, this.scale = 1});

  final double scale;

  /// The drawing's box, its coordinates as designed.
  static const picture = Size(190, 152);

  static const _meFeet = Offset(52, 132);
  static const _friendFeet = Offset(142, 132);
  static const _figureScale = 0.65;
  static const _discWidth = 68.0;
  static const _vs = Offset(97, 76);
  static const _shadeLeft = 0.72;
  static const _shadeRight = 0.46;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: const _PanelPainter(
          AppColors.fever,
          FriendColors.skyShade,
          rises: true,
          low: _shadeLeft,
          high: _shadeRight,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox.fromSize(
            size: picture * scale,
            child: FittedBox(
              child: SizedBox.fromSize(
                size: picture,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _disc(_meFeet.dx, _meFeet.dy, _discWidth),
                    _disc(_friendFeet.dx, _friendFeet.dy, _discWidth),
                    _standing(
                      _meFeet,
                      _figureScale,
                      const ArcadeFigure(id: 'kangaroo', side: BattleSide.me),
                    ),
                    _standing(
                      _friendFeet,
                      _figureScale,
                      const ArcadeFigure(id: 'bear'),
                      mirror: true,
                    ),
                    _vsChip(_vs),
                  ],
                ),
              ),
            ),
          ),
        ),
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
