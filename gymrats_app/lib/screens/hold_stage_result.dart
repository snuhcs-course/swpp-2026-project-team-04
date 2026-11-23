import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/arcade_catalog.dart';
import '../models/arcade_floor.dart';
import '../models/arcade_stage.dart';
import '../models/character_rig.dart';
import '../models/exercise_type_korean.dart';
import '../theme/app_theme.dart';
import '../widgets/battle_fx_motion.dart';
import '../widgets/character_figure.dart';
import '../widgets/gym_owner_figure.dart';
import 'hold_stage_art.dart';
import 'hold_stage_brief.dart';
import 'hold_stage_play.dart';

/// One star on an arcade result: lit or not, and its words under it.
class ArcadeResultStar {
  const ArcadeResultStar({required this.lit, required this.label});

  final bool lit;

  /// e.g. "20초", "승리", "콤보 5 이상".
  final String label;
}

/// The arcade result's frame (the design's `ArcResult`), for every kind of
/// stage: the stage tag, the title band, a middle line (the time held, or
/// a battle's scores), the three stars with their words, the characters
/// over a step, a box under them, and two buttons. A hold stage fills it
/// with [HoldStageResult]; the fights and the boss match fill it the same
/// way (P16).
class ArcadeResultFrame extends StatelessWidget {
  const ArcadeResultFrame({
    super.key,
    required this.tag,
    required this.title,
    required this.cleared,
    required this.stars,
    required this.figures,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
    this.middle,
    this.below,
    this.belowGap = strikesGap,
  });

  /// "STAGE 9 · 2F".
  final String tag;

  /// "클리어!", "실패".
  final String title;

  /// Lime band when cleared, gray when not.
  final bool cleared;

  /// The middle line under the title: [ArcadeResultTime] for a hold.
  final Widget? middle;

  final List<ArcadeResultStar> stars;

  /// The characters, in a 320 x 176 box ([ArcadeResultFigures]).
  final Widget figures;

  /// The box under the characters: the next stage, or the warnings.
  final Widget? below;

  /// The room above [below]: [nextStageGap] over a next stage card,
  /// [strikesGap] over the warnings (the design's).
  final double belowGap;

  /// The room the design leaves above the next stage card.
  static const nextStageGap = 8.0;

  /// The room the design leaves above the warnings.
  static const strikesGap = 6.0;

  /// The white button on the left, e.g. "다시 하기", "아케이드로".
  final String secondaryLabel;
  final VoidCallback onSecondary;

  /// The ink button on the right, e.g. "다음 스테이지", "다시 도전".
  final String primaryLabel;
  final VoidCallback onPrimary;

  /// The design's 44 from the top, less its 28 for the status bar: the
  /// frame sits in a [SafeArea].
  static const _padTop = AppSpacing.s16;
  static const _padBottom = 22.0;
  static const _pad = EdgeInsets.fromLTRB(
    AppSpacing.s20,
    _padTop,
    AppSpacing.s20,
    _padBottom,
  );
  static const _gap = 14.0;
  static const _starWidth = 92.0;
  static const _starGap = AppSpacing.s12;
  static const _labelGap = 5.0;
  static const _figuresGap = 6.0;
  static const _figures = Size(320, 176);
  static const _buttonHeight = 56.0;
  static const _buttonGap = 10.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final middle = this.middle;
    final below = this.below;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: _pad,
                child: Column(
                  children: [
                    Text(tag, style: text.holdResultTag),
                    const SizedBox(height: AppSpacing.s8),
                    _TitleBand(title: title, cleared: cleared),
                    if (middle != null) ...[
                      const SizedBox(height: _gap),
                      middle,
                    ],
                    const SizedBox(height: _gap),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final (i, star) in stars.indexed) ...[
                          if (i > 0) const SizedBox(width: _starGap),
                          SizedBox(
                            width: _starWidth,
                            child: Semantics(
                              label:
                                  '${star.label} ${star.lit ? '별 받음' : '별 못 받음'}',
                              child: ExcludeSemantics(
                                child: Column(
                                  children: [
                                    HoldStar(
                                      key: ValueKey('result-star-$i'),
                                      size: i == 1 ? 72 : 60,
                                      lit: star.lit,
                                      edge: 1.6,
                                    ),
                                    const SizedBox(height: _labelGap),
                                    Text(
                                      star.label,
                                      textAlign: TextAlign.center,
                                      style: text.holdStarLabel.copyWith(
                                        color: star.lit
                                            ? AppColors.ink
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: _figuresGap),
                    SizedBox.fromSize(size: _figures, child: figures),
                    if (below != null) ...[SizedBox(height: belowGap), below],
                    const Spacer(),
                    const SizedBox(height: AppSpacing.s16),
                    Row(
                      children: [
                        Expanded(
                          child: _WhiteButton(
                            label: secondaryLabel,
                            onPressed: onSecondary,
                          ),
                        ),
                        const SizedBox(width: _buttonGap),
                        Expanded(
                          child: HoldDarkButton(
                            label: primaryLabel,
                            style: text.holdResultAction,
                            height: _buttonHeight,
                            arrowSize: 20,
                            gap: AppSpacing.s8,
                            onPressed: onPrimary,
                          ),
                        ),
                      ],
                    ),
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

/// The title on its slanted, tilted band with an ink edge and a hard ink
/// shadow.
class _TitleBand extends StatelessWidget {
  const _TitleBand({required this.title, required this.cleared});

  final String title;
  final bool cleared;

  static const _padSide = 22.0;
  static const _padTop = 2.0;
  static const _padBottom = 6.0;
  static const _pad = EdgeInsets.fromLTRB(
    _padSide,
    _padTop,
    _padSide,
    _padBottom,
  );
  static const _edge = 3.0;
  static const _tilt = -3 * math.pi / 180;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Stack(
      children: [
        Positioned.fill(
          child: Transform(
            transform: AppHighlight.battleSlant..rotateZ(_tilt),
            alignment: Alignment.center,
            child: DecoratedBox(
              key: const ValueKey('result-band'),
              decoration: BoxDecoration(
                color: cleared ? AppColors.accent : HoldColors.failBand,
                border: Border.all(color: AppColors.ink, width: _edge),
                boxShadow: const [
                  BoxShadow(color: AppColors.ink, offset: Offset(4, 5)),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: _pad,
          child: Transform.rotate(
            angle: _tilt,
            child: Text(
              title,
              style: Theme.of(context).textTheme.holdResultTitle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const _corner = 16.0;
  static const _edge = 1.5;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_corner),
      side: const BorderSide(color: AppColors.line, width: _edge),
    ),
    child: InkWell(
      onTap: onPressed,
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_corner),
      ),
      child: SizedBox(
        height: ArcadeResultFrame._buttonHeight,
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.holdResultButton,
          ),
        ),
      ),
    ),
  );
}

/// "버틴 시간" over the time: a hold result's middle line.
class ArcadeResultTime extends StatelessWidget {
  const ArcadeResultTime({super.key, required this.held});

  final Duration held;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text('버틴 시간', style: text.holdResultTimeLabel),
        Text(holdClock(held), style: text.holdResultTime),
      ],
    );
  }
}

/// The result's characters over a white step, in the 320 x 176 box: the
/// user's character on the left (if [me]), the floor's owner or an
/// opponent flipped on the right, each [scale]d about its feet and
/// outlined in white. Places are the design's, per scene.
class ArcadeResultFigures extends StatelessWidget {
  const ArcadeResultFigures({
    super.key,
    required this.stepLeft,
    required this.opponent,
    required this.opponentLeft,
    required this.opponentBottom,
    this.me,
    this.meLeft = 56,
    this.meScale = 1.05,
  });

  /// The step's left edge.
  final double stepLeft;

  /// The user's figure, e.g. a [CharacterFigure] cheering; null for none.
  final Widget? me;
  final double meLeft;
  final double meScale;

  /// The figure on the right, already flipped and scaled (e.g. a
  /// [HoldOwner]).
  final Widget opponent;
  final double opponentLeft;
  final double opponentBottom;

  static const _step = Size(112, 16);
  static const _stepBottom = 6.0;
  static const _stepEdge = 3.0;
  static const _stepCorner = 7.0;
  static const _meBottom = 12.0;

  @override
  Widget build(BuildContext context) {
    final me = this.me;
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: stepLeft,
            bottom: _stepBottom,
            width: _step.width,
            height: _step.height,
            child: DecoratedBox(
              key: const ValueKey('result-step'),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.ink, width: _stepEdge),
                borderRadius: BorderRadius.circular(_stepCorner),
              ),
            ),
          ),
          if (me != null)
            Positioned(
              left: meLeft,
              bottom: _meBottom,
              child: SizedBox.fromSize(
                size: HoldOwner.box,
                child: Transform(
                  transform: Matrix4.diagonal3Values(meScale, meScale, 1),
                  origin: const Offset(70, 150),
                  child: HoldOutlined(child: me),
                ),
              ),
            ),
          Positioned(
            left: opponentLeft,
            bottom: opponentBottom,
            child: opponent,
          ),
        ],
      ),
    );
  }
}

/// The next stage's card on a cleared result: "STAGE n+1" and who and what
/// it is, from the stage data (spec 6).
class ArcadeNextStageCard extends StatelessWidget {
  const ArcadeNextStageCard({super.key, required this.next});

  final ArcadeStage next;

  /// "{opponent} · {exercise}" for a fight, "{owner} · {pose}" for a hold,
  /// "보스 매치 · {owner}" for a boss match.
  static String nameOf(ArcadeStage next) {
    final floor = ArcadeCatalog.floorOf(next);
    return switch (next) {
      ArcadeFightStage(:final character, :final exercise) =>
        '${CharacterRig.standard.art(character).name} · ${exercise.koreanName}',
      ArcadeHoldStage(:final pose) => '${floor.ownerName} · ${pose.label}',
      ArcadeBossStage() => '보스 매치 · ${floor.ownerName}',
    };
  }

  static const _padSide = 14.0;
  static const _pad = EdgeInsets.symmetric(
    horizontal: _padSide,
    vertical: AppSpacing.s12,
  );
  static const _edge = 2.0;
  static const _icon = 40.0;
  static const _gap = AppSpacing.s12;
  static const _lockGap = 6.0;
  static const _nameGap = 1.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('result-next'),
      padding: _pad,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: _edge),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: _icon,
            height: _icon,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: _edge),
            ),
            child: const CustomPaint(
              size: Size.square(22),
              painter: HoldNextIconPainter.glove(),
            ),
          ),
          const SizedBox(width: _gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CustomPaint(
                      size: Size.square(12),
                      painter: HoldNextIconPainter.lock(),
                    ),
                    const SizedBox(width: _lockGap),
                    Text('STAGE ${next.number}', style: text.holdNextTag),
                  ],
                ),
                const SizedBox(height: _nameGap),
                Text(nameOf(next), style: text.holdNextName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The two warnings that ended a failed hold.
class ArcadeResultStrikes extends StatelessWidget {
  const ArcadeResultStrikes({super.key});

  static const _padSide = 14.0;
  static const _padTop = 10.0;
  static const _pad = EdgeInsets.symmetric(
    horizontal: _padSide,
    vertical: _padTop,
  );
  static const _corner = 14.0;
  static const _edge = 1.5;
  static const _textGap = 10.0;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('result-strikes'),
    padding: _pad,
    decoration: BoxDecoration(
      color: AppColors.card,
      border: Border.all(color: AppColors.border, width: _edge),
      borderRadius: BorderRadius.circular(_corner),
    ),
    child: Row(
      children: [
        const ExcludeSemantics(
          child: Row(
            children: [
              HoldStrike(size: Size(24, 18), fill: AppColors.danger),
              SizedBox(width: AppSpacing.s4),
              HoldStrike(size: Size(24, 18), fill: AppColors.danger),
            ],
          ),
        ),
        const SizedBox(width: _textGap),
        Text('경고 2번', style: Theme.of(context).textTheme.holdStrikes),
      ],
    ),
  );
}

/// A hold stage's result (spec 6, the design's `ArcResult` holdClear and
/// holdFail) in the [ArcadeResultFrame].
class HoldStageResult extends StatelessWidget {
  const HoldStageResult({
    super.key,
    required this.stage,
    required this.floor,
    required this.held,
    required this.litStars,
    required this.myCharacter,
    required this.onPlayAgain,
    required this.onNextStage,
    required this.onArcade,
  });

  final ArcadeHoldStage stage;
  final ArcadeFloor floor;
  final Duration held;

  /// Each star lit or not: none lit is a fail.
  final List<bool> litStars;
  final String myCharacter;

  /// 다시 하기, 다시 도전.
  final VoidCallback onPlayAgain;

  /// 다음 스테이지.
  final VoidCallback onNextStage;

  /// 아케이드로.
  final VoidCallback onArcade;

  @override
  Widget build(BuildContext context) {
    final cleared = litStars.any((lit) => lit);
    final stars = [
      for (final (i, seconds) in stage.starSeconds.indexed)
        ArcadeResultStar(lit: litStars[i], label: '$seconds초'),
    ];
    final next = ArcadeCatalog.stages.length > stage.number
        ? ArcadeCatalog.stage(stage.number + 1)
        : null;
    return ArcadeResultFrame(
      tag: HoldStageBrief.stageTag(stage),
      title: cleared ? '클리어!' : '실패',
      cleared: cleared,
      middle: ArcadeResultTime(held: held),
      stars: stars,
      figures: cleared
          ? ArcadeResultFigures(
              stepLeft: 48,
              me: CharacterFigure(
                characterId: myCharacter,
                pose: BattlePose.win,
              ),
              meLeft: 34,
              opponent: HoldOwner(
                ownerId: floor.owner,
                scale: 0.86,
                face: GymOwnerFace.ok,
              ),
              opponentLeft: 170,
              opponentBottom: 12,
            )
          : ArcadeResultFigures(
              stepLeft: 104,
              opponent: HoldOwner(
                ownerId: floor.owner,
                scale: 1,
                face: GymOwnerFace.blow,
              ),
              opponentLeft: 90,
              opponentBottom: 12,
            ),
      below: cleared
          ? (next == null ? null : ArcadeNextStageCard(next: next))
          : const ArcadeResultStrikes(),
      belowGap: cleared
          ? ArcadeResultFrame.nextStageGap
          : ArcadeResultFrame.strikesGap,
      secondaryLabel: cleared ? '다시 하기' : '아케이드로',
      onSecondary: cleared ? onPlayAgain : onArcade,
      primaryLabel: cleared ? '다음 스테이지' : '다시 도전',
      onPrimary: cleared ? onNextStage : onPlayAgain,
    );
  }
}
