import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../theme/app_theme.dart';
import 'battle_fx_motion.dart';

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
    this.inset = 0,
    this.sidePadding = _koreanSidePadding,
    this.topPadding = 0,
  });

  /// A band of numbers or English, [size] design points tall.
  BattleBand.number({
    super.key,
    required this.text,
    required double size,
    required this.color,
    required TextTheme theme,
  }) : style = theme.stageBand.apply(
         fontSizeFactor: size / StageText.stageBandSize,
       ),
       inset = _numberInset,
       sidePadding = _numberSidePadding,
       topPadding = 0;

  /// A band of Korean, [size] design points tall.
  BattleBand.korean({
    super.key,
    required this.text,
    required double size,
    required this.color,
    required TextTheme theme,
  }) : style = theme.stageBandKorean.apply(
         fontSizeFactor: size / StageText.stageBandSize,
       ),
       inset = 0,
       sidePadding = _koreanSidePadding,
       topPadding = 0;

  final String text;
  final TextStyle style;
  final Color color;

  /// How much of the text's height the band leaves free at the top and at
  /// the bottom, from 0 to 0.5. Capital letters and numbers fill less of
  /// their line than Korean does.
  final double inset;

  /// The room beside the text, and above and below it, in design points.
  final double sidePadding;
  final double topPadding;

  static const _numberInset = 0.1;
  static const _numberSidePadding = 14.0;
  static const _koreanSidePadding = 16.0;
  static const _edge = 3.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FractionallySizedBox(
            heightFactor: 1 - 2 * inset,
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
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sidePadding,
            vertical: topPadding,
          ),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            textScaler: TextScaler.noScaling,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// One band of the stage's effects, where and how [banner] says: placed
/// across the stage's 360 design points, then moved, turned and sized
/// around its own anchor.
///
/// It goes into the stage's [Stack]. It is a picture to a screen reader:
/// the stage says what happened once, instead of a band being read again on
/// every frame it moves.
class BattleStageBanner extends StatelessWidget {
  const BattleStageBanner({super.key, required this.banner});

  final BattleFxBanner banner;

  /// The room between a band and the stage's side.
  static const _sideGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final anchor = switch (banner.align) {
      BattleFxAlign.left => _sideGap,
      BattleFxAlign.center => BattleFx.stageWidth / 2,
      BattleFxAlign.right => BattleFx.stageWidth - _sideGap,
    };
    final alignment = Alignment(anchor / BattleFx.stageWidth * 2 - 1, 0);
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
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _sideGap),
                // A band wider than the stage spills over its sides instead of
                // being squeezed.
                child: OverflowBox(
                  fit: OverflowBoxFit.deferToChild,
                  alignment: switch (banner.align) {
                    BattleFxAlign.left => Alignment.centerLeft,
                    BattleFxAlign.center => Alignment.center,
                    BattleFxAlign.right => Alignment.centerRight,
                  },
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: band,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
