import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character_rig.dart';
import '../theme/app_theme.dart';
import '../viewmodels/character_viewmodel.dart';
import 'arcade_parts.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_model.dart';
import 'character_figure.dart';

/// The frame of the arcade's results (design `ArcResult`): the tag, the
/// title on its band, the score (when there is one), the three stars over
/// their conditions, the characters on their stand, what follows them
/// ([below]), and the buttons at the bottom. On a short screen it scrolls.
///
/// The values that differ between the designs' results come in from
/// outside; the defaults are `ArcResult`'s.
class ArcadeBattleResultFrame extends StatelessWidget {
  const ArcadeBattleResultFrame({
    super.key,
    required this.tag,
    required this.title,
    required this.titleColor,
    required this.titleStyle,
    required this.stars,
    required this.figures,
    required this.buttons,
    this.top = AppSpacing.s16,
    this.titleGap = AppSpacing.s8,
    this.titlePadding = ArcadeTitleBand.defaultPadding,
    this.score,
    this.starsGap = defaultStarsGap,
    this.figuresGap = defaultFiguresGap,
    this.below = const [],
  });

  /// "STAGE 8 · 2F".
  final String tag;
  final String title;
  final Color titleColor;
  final TextStyle titleStyle;
  final EdgeInsets titlePadding;
  final Widget stars;
  final Widget figures;
  final Widget buttons;

  /// The room over the tag, under the status bar.
  final double top;
  final double titleGap;

  /// "98 : 140" under the title; none on most results.
  final Widget? score;
  final double starsGap;
  final double figuresGap;
  final List<Widget> below;

  /// ArcResult's gaps over the stars and over the stand.
  static const defaultStarsGap = 14.0;
  static const defaultFiguresGap = 6.0;

  static const _side = AppSpacing.s20;
  static const _bottom = 22.0;
  static const _scoreGap = AppSpacing.s16;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final score = this.score;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomPaint(
        painter: const ArcadeGridPainter(cell: ArcadeGridPainter.groundCell),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(_side, top, _side, _bottom),
                  child: Column(
                    children: [
                      Text(tag, style: text.arcadeResultTag),
                      SizedBox(height: titleGap),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ArcadeTitleBand(
                          label: title,
                          color: titleColor,
                          style: titleStyle,
                          padding: titlePadding,
                        ),
                      ),
                      if (score != null) ...[
                        const SizedBox(height: _scoreGap),
                        score,
                      ],
                      SizedBox(height: starsGap),
                      // Narrower than the design, they shrink to fit.
                      FittedBox(fit: BoxFit.scaleDown, child: stars),
                      SizedBox(height: figuresGap),
                      FittedBox(fit: BoxFit.scaleDown, child: figures),
                      ...below,
                      const Spacer(),
                      const SizedBox(height: AppSpacing.s16),
                      buttons,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One character on the results' stand: where its 140 x 160 box is (from
/// the left or the right, and from the bottom), its size about its feet,
/// its pose, facing left with [mirror], edged white with [outline].
class ArcadeBattleStand {
  const ArcadeBattleStand._({
    required this.id,
    required this.side,
    required this.pose,
    this.left,
    this.right,
    required this.bottom,
    required this.scale,
    this.mirror = false,
    this.outline = true,
    this.opacity = 1,
  });

  /// The user's character ([id] null: the app's choice).
  const ArcadeBattleStand.me({
    BattlePose pose = BattlePose.win,
    double? left,
    required double bottom,
    required double scale,
  }) : this._(
         id: null,
         side: BattleSide.me,
         pose: pose,
         left: left,
         bottom: bottom,
         scale: scale,
       );

  /// The opponent [id], in the opponent's color.
  const ArcadeBattleStand.opponent({
    required String id,
    required BattlePose pose,
    double? left,
    double? right,
    required double bottom,
    required double scale,
    bool mirror = false,
    bool outline = true,
    double opacity = 1,
  }) : this._(
         id: id,
         side: BattleSide.opponent,
         pose: pose,
         left: left,
         right: right,
         bottom: bottom,
         scale: scale,
         mirror: mirror,
         outline: outline,
         opacity: opacity,
       );

  final String? id;
  final BattleSide side;
  final BattlePose pose;
  final double? left;
  final double? right;
  final double bottom;
  final double scale;
  final bool mirror;
  final bool outline;
  final double opacity;
}

/// The results' stand: a [height] high, 320 wide box with a white
/// pedestal [pedestalLeft] from its left and the [stands] on it.
class ArcadeBattleFigures extends StatelessWidget {
  const ArcadeBattleFigures({
    super.key,
    required this.stands,
    required this.pedestalLeft,
    this.height = standHeight,
  }) : _lostTo = null;

  /// A lost battle's stand (`ArcResult` fail and bossFail): the user
  /// knocked out on the left, the opponent [opponent] cheering on the
  /// pedestal, facing left.
  const ArcadeBattleFigures.lost({super.key, required String opponent})
    : height = standHeight,
      pedestalLeft = _lostPedestal,
      stands = const [],
      _lostTo = opponent;

  final List<ArcadeBattleStand> stands;
  final double pedestalLeft;
  final double height;
  final String? _lostTo;

  /// ArcResult's stand: 320 by 176.
  static const standHeight = 176.0;
  static const _width = 320.0;
  static const _lostPedestal = 160.0;
  static const _lostMeLeft = 30.0;
  static const _lostMeScale = 0.9;
  static const _lostOpponentLeft = 150.0;
  static const _standBottom = 12.0;
  static const _pedestalWidth = 112.0;
  static const _pedestalBottom = 6.0;
  static const _feet = Offset(70, 150);

  List<ArcadeBattleStand> get _stands => switch (_lostTo) {
    final opponent? => [
      const ArcadeBattleStand.me(
        pose: BattlePose.knockedOut,
        left: _lostMeLeft,
        bottom: _standBottom,
        scale: _lostMeScale,
      ),
      ArcadeBattleStand.opponent(
        id: opponent,
        pose: BattlePose.win,
        left: _lostOpponentLeft,
        bottom: _standBottom,
        scale: 1,
        mirror: true,
      ),
    ],
    null => stands,
  };

  @override
  Widget build(BuildContext context) {
    final me =
        context.watch<CharacterViewModel?>()?.characterId ??
        CharacterRig.defaultId;
    return ExcludeSemantics(
      child: SizedBox(
        width: _width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: pedestalLeft,
              bottom: _pedestalBottom,
              child: const ArcadePedestal(width: _pedestalWidth),
            ),
            for (final stand in _stands)
              Positioned(
                left: stand.left,
                right: stand.right,
                bottom: stand.bottom,
                child: Opacity(
                  opacity: stand.opacity,
                  child: Transform(
                    transform: Matrix4.diagonal3Values(
                      stand.mirror ? -stand.scale : stand.scale,
                      stand.scale,
                      1,
                    ),
                    origin: _feet,
                    child: _figure(stand, me),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _figure(ArcadeBattleStand stand, String me) {
    final figure = CharacterFigure(
      characterId: stand.id ?? me,
      pose: stand.pose,
      side: stand.side,
    );
    return stand.outline ? ArcadeWhiteOutline(child: figure) : figure;
  }
}

/// The results' buttons: [first] light and [second] dark side by side,
/// and under them, when given, the [link].
class ArcadeBattleButtons extends StatelessWidget {
  const ArcadeBattleButtons({
    super.key,
    required this.first,
    required this.onFirst,
    required this.second,
    required this.onSecond,
    this.link,
    this.onLink,
  });

  final String first;
  final VoidCallback onFirst;
  final String second;
  final VoidCallback onSecond;
  final String? link;
  final VoidCallback? onLink;

  static const _gap = 10.0;
  static const _linkGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final link = this.link;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ArcadeLightButton(label: first, onPressed: onFirst),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: ArcadeDarkButton(label: second, onPressed: onSecond),
            ),
          ],
        ),
        if (link != null) ...[
          const SizedBox(height: _linkGap),
          ArcadeTextLink(label: link, onPressed: onLink),
        ],
      ],
    );
  }
}

/// A strip of amber and ink stripes under an ink line: the bottom of the
/// last floor's card.
class ArcadeStripesStrip extends StatelessWidget {
  const ArcadeStripesStrip({super.key});

  static const _edge = 2.0;
  static const _stripe = 10.0;

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: AppColors.ink, width: _edge),
      ),
    ),
    child: CustomPaint(painter: ArcadeStripesPainter(_stripe)),
  );
}
