import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../theme/app_theme.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_model.dart';

/// The theme color of a stage fill. The text on it is always ink.
extension BattleFxToneColor on BattleFxTone {
  Color get color => switch (this) {
    BattleFxTone.me => AppColors.accent,
    BattleFxTone.opponent => AppColors.opponent,
    BattleFxTone.plain => AppColors.card,
    BattleFxTone.average => AppColors.warning,
    BattleFxTone.fever => AppColors.fever,
    BattleFxTone.danger => AppColors.danger,
  };
}

/// Ink text on a slanted band of [color] with an ink edge: how the battle
/// stage shouts ("MISS", "K.O.", "자세 세팅 중") and labels the reject sign.
///
/// It is as wide as its text needs, whatever room it is given, and never
/// follows the system text size: the stage is sized as a whole.
class BattleBand extends StatelessWidget {
  const BattleBand({
    super.key,
    required this.text,
    required this.style,
    required this.color,
    this.sidePadding = _koreanSidePadding,
    this.topPadding = 0,
  }) : height = null,
       textTop = 0;

  /// A band of numbers or English with text [size] design points tall, as
  /// large as [BattleFx.bandBox] makes it: the capitals sit in its middle,
  /// with the same room above and below them.
  BattleBand.number({
    super.key,
    required this.text,
    required double size,
    required this.color,
    required TextTheme theme,
  }) : style = theme.stageBand.apply(
         fontSizeFactor: size / StageText.stageBandSize,
       ),
       height = BattleFx.bandBox(size).height,
       sidePadding = BattleFx.bandBox(size).padX,
       textTop = BattleFx.bandBox(size).baseline - _numberAscent * size,
       topPadding = 0;

  /// A band of Korean with text [size] design points tall: as tall as its
  /// line ([BattleFx.koreanBandBox]).
  BattleBand.korean({
    super.key,
    required this.text,
    required double size,
    required this.color,
    required TextTheme theme,
  }) : style = theme.stageBandKorean.apply(
         fontSizeFactor: size / StageText.stageBandSize,
       ),
       height = null,
       sidePadding = BattleFx.koreanBandBox(size).padX,
       textTop = 0,
       topPadding = 0;

  final String text;
  final TextStyle style;
  final Color color;

  /// The band's height, when it is not the text's line: a number band is
  /// shorter than its line. Null: as tall as the line and [topPadding].
  final double? height;

  /// How far below the band's top the text's line begins, in a band of
  /// its own [height].
  final double textTop;

  /// The room beside the text, and above and below it, in design points.
  final double sidePadding;
  final double topPadding;

  /// How far below the top of a line 1.0 tall Oxanium's letters stand: its
  /// ascent, 790 of 1000.
  static const _numberAscent = 0.79;
  static const _koreanSidePadding = 16.0;
  static const _edge = 3.0;

  @override
  Widget build(BuildContext context) {
    Widget label = Text(
      text,
      maxLines: 1,
      softWrap: false,
      textScaler: TextScaler.noScaling,
      style: style,
    );
    final height = this.height;
    if (height != null) {
      // The letters stand where the band wants them; the empty room of
      // their line above and below hangs over the band's edges unseen.
      label = SizedBox(
        height: height,
        child: OverflowBox(
          fit: OverflowBoxFit.deferToChild,
          alignment: Alignment.topLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Transform.translate(offset: Offset(0, textTop), child: label),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Transform(
            transform: AppHighlight.battleSlant,
            alignment: Alignment.center,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: AppColors.ink, width: _edge),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sidePadding,
            vertical: topPadding,
          ),
          child: label,
        ),
      ],
    );
  }
}

/// One band of the stage's effects, where and how [banner] says: centered
/// across the stage's 360 design points with its top at the banner's top,
/// then moved, turned and sized around its own middle.
///
/// It goes into the stage's [Stack]. It is a picture to a screen reader:
/// the stage says what happened once, instead of a band being read again on
/// every frame it moves.
class BattleStageBanner extends StatelessWidget {
  const BattleStageBanner({super.key, required this.banner});

  final BattleFxBanner banner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final transform = Matrix4.translationValues(banner.dx, banner.dy, 0)
        .multiplied(Matrix4.rotationZ(banner.rotation * math.pi / 180))
        .multiplied(Matrix4.diagonal3Values(banner.scaleX, banner.scaleY, 1));
    final band = switch (banner.font) {
      BattleFxFont.number => BattleBand.number(
        text: banner.text,
        size: banner.textSize,
        color: banner.tone.color,
        theme: theme,
      ),
      BattleFxFont.display => BattleBand.korean(
        text: banner.text,
        size: banner.textSize,
        color: banner.tone.color,
        theme: theme,
      ),
    };
    return Positioned(
      left: 0,
      top: banner.top,
      width: BattleFx.stageWidth,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            opacity: banner.opacity.clamp(0.0, 1.0),
            child: Transform(
              transform: transform,
              alignment: Alignment.center,
              // A band wider than the stage spills over its sides instead of
              // being squeezed.
              child: OverflowBox(
                fit: OverflowBoxFit.deferToChild,
                minWidth: 0,
                maxWidth: double.infinity,
                child: band,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A side's combo mark, "N HIT", as the camera area shows it in its top
/// corner on that side: a white band whose outer end is [BattleFx.comboSide]
/// from the side, turned and sized around that end's middle.
///
/// Like the reject sign over it, it is drawn in the stage's design points
/// and sized with the stage by [scale], from its top outer corner; it does
/// not follow the system text size. It is a picture to a screen reader.
class BattleComboMark extends StatelessWidget {
  const BattleComboMark({super.key, required this.combo, this.scale = 1});

  final BattleFxCombo combo;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final mine = combo.side == BattleSide.me;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: combo.opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            alignment: mine ? Alignment.topLeft : Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.only(
                left: mine ? BattleFx.comboSide : 0,
                right: mine ? 0 : BattleFx.comboSide,
              ),
              child: Transform(
                transform: Matrix4.rotationZ(combo.rotation * math.pi / 180)
                    .multiplied(
                      Matrix4.diagonal3Values(combo.scaleX, combo.scaleY, 1),
                    ),
                alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
                child: BattleBand.number(
                  text: combo.text,
                  size: BattleFx.comboTextSize,
                  color: BattleFxTone.plain.color,
                  theme: Theme.of(context).textTheme,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
