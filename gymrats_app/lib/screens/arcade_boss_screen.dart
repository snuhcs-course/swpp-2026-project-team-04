import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/arcade_catalog.dart';
import '../models/arcade_stage.dart';
import '../models/battle_result.dart';
import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../theme/app_theme.dart';
import '../viewmodels/arcade_viewmodel.dart';
import '../widgets/arcade_parts.dart';
import '../widgets/arcade_stage_sheet.dart';
import '../widgets/battle_fx_motion.dart';
import '../widgets/lobby_parts.dart';
import 'arcade_flow.dart';

/// A boss match (P16 spec 7, design `P16Boss`): the floor's gym owner, R1
/// push-ups then R2 squats.
///
/// Without [first] it is the intro: the owner in goggles, the two rounds
/// and the star conditions, and 자세 잡기 to R1's setup; back returns to
/// the map. With [first], R1 won, it is the break between the rounds: no
/// rest timer, 자세 잡기 to R2's setup, 그만하기 back to the map without
/// stars.
class ArcadeBossScreen extends StatelessWidget {
  const ArcadeBossScreen({super.key, required this.stage, this.first});

  final ArcadeBossStage stage;

  /// R1 as played and won; null on the intro.
  final BattleResult? first;

  /// This screen as a page.
  static Route<void> route({
    required ArcadeBossStage stage,
    BattleResult? first,
  }) => MaterialPageRoute<void>(
    builder: (_) => ArcadeBossScreen(stage: stage, first: first),
  );

  /// Opens round [round]'s setup and battle in this screen's place.
  void _setUp(BuildContext context, int round) =>
      Navigator.pushReplacementNamed(
        context,
        GymRatsApp.battleRoute,
        arguments: ArcadeMatchups.boss(
          stage,
          round,
          playerName: ArcadeFlow.playerName(context),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final first = this.first;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomPaint(
        painter: const ArcadeGridPainter(cell: ArcadeGridPainter.groundCell),
        child: SafeArea(
          child: first == null
              ? _Intro(stage: stage, onSetUp: () => _setUp(context, 1))
              : PopScope<Object?>(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop) ArcadeFlow.leave(context);
                  },
                  child: _Break(
                    stage: stage,
                    first: first,
                    onSetUp: () => _setUp(context, 2),
                    onQuit: () => ArcadeFlow.leave(context),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The intro: the header, the owner's card, the two rounds, the star
/// conditions and 자세 잡기.
class _Intro extends StatelessWidget {
  const _Intro({required this.stage, required this.onSetUp});

  final ArcadeBossStage stage;
  final VoidCallback onSetUp;

  static const _side = AppSpacing.s20;
  static const _bottom = 22.0;
  static const _gap = 14.0;
  static const _goalsGap = AppSpacing.s12;
  static const _titleGap = 2.0;
  static const _buttonHeight = 58.0;
  static const _buttonGap = 10.0;
  static const _arrow = 22.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final best =
        Provider.of<ArcadeViewModel?>(context)?.progress
            ?.bestOf(stage.number) ??
        0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_side, 0, _side, _bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LobbySquareButton(
                icon: Icons.chevron_left_rounded,
                tooltip: '지도로',
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STAGE ${stage.number} · ${stage.floor}F BOSS',
                      style: text.arcadeTag,
                    ),
                    const SizedBox(height: _titleGap),
                    LobbySkew(
                      degrees: 10,
                      child: Semantics(
                        header: true,
                        child: Text('보스 매치', style: text.arcadeBossTitle),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: _gap),
          _OwnerCard(stage: stage),
          const SizedBox(height: _gap),
          _Rounds(stage: stage),
          const SizedBox(height: _goalsGap),
          ArcadeStarGoals(
            labels: [for (final star in stage.stars) star.label],
            best: best,
            style: text.arcadeBossGoal,
          ),
          const Spacer(),
          ArcadeDarkButton(
            label: '자세 잡기',
            onPressed: onSetUp,
            height: _buttonHeight,
            gap: _buttonGap,
            arrowSize: _arrow,
            style: text.arcadeBossAction,
          ),
        ],
      ),
    );
  }
}

/// The boss's card: grey on the left with the BOSS tag, the name, "1F
/// 체육관 관장" and its AI level; pink on the right with the owner in
/// goggles on a pedestal, facing left.
class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.stage});

  final ArcadeBossStage stage;

  static const _height = 292.0;
  static const _edge = 2.5;
  static const _corners = 22.0;
  static const _panelLeft = -40.0;
  static const _panelOut = -20.0;
  static const _panelWidth = 200.0;
  static const _panelEdge = 3.0;
  static const _pedestalRight = 22.0;
  static const _pedestalBottom = 16.0;
  static const _pedestalWidth = 128.0;
  static const _ownerRight = 16.0;
  static const _ownerBottom = 22.0;
  static const _ownerScale = 1.5;
  static const _inset = 16.0;
  static const _wordsWidth = 150.0;
  static const _wordsGap = 6.0;
  static const _tagHeight = 24.0;
  static const _tagSide = 8.0;
  static const _tagCorners = 7.0;
  static const _tagEdge = 2.0;
  static const _crown = 15.0;
  static const _crownStroke = 2.2;
  static const _tagGap = 4.0;
  static const _levelHeight = 22.0;
  static const _levelCorners = 6.0;
  static const _nameBand = 15.0;
  static const _nameBandBottom = 3.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final floor = ArcadeCatalog.floorOf(stage);
    return Container(
      height: _height,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_corners),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_corners),
        child: ColoredBox(
          color: AppColors.opponent,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: _panelLeft,
                top: _panelOut,
                bottom: _panelOut,
                width: _panelWidth,
                child: Transform(
                  alignment: Alignment.center,
                  transform: AppHighlight.battleSlant,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border(
                        right: BorderSide(
                          color: AppColors.ink,
                          width: _panelEdge,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                right: _pedestalRight,
                bottom: _pedestalBottom,
                child: ArcadePedestal(width: _pedestalWidth),
              ),
              Positioned(
                right: _ownerRight,
                bottom: _ownerBottom,
                child: Transform(
                  transform: Matrix4.diagonal3Values(
                    -_ownerScale,
                    _ownerScale,
                    1,
                  ),
                  origin: const Offset(70, 150),
                  child: ArcadeOwnerFigure(id: floor.owner, idle: true),
                ),
              ),
              Positioned(
                left: _inset,
                top: _inset,
                width: _wordsWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: _tagHeight,
                      padding: const EdgeInsets.symmetric(horizontal: _tagSide),
                      decoration: BoxDecoration(
                        color: AppColors.opponent,
                        borderRadius: BorderRadius.circular(_tagCorners),
                        border: Border.all(
                          color: AppColors.ink,
                          width: _tagEdge,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ArcadeGlyphIcon(
                            ArcadeGlyph.crown,
                            size: _crown,
                            strokeWidth: _crownStroke,
                          ),
                          const SizedBox(width: _tagGap),
                          Text('BOSS', style: text.arcadeBossChip),
                        ],
                      ),
                    ),
                    const SizedBox(height: _wordsGap),
                    ArcadeMarkedName(
                      name: floor.ownerName,
                      style: text.arcadeBossName,
                      bandHeight: _nameBand,
                      bandBottom: _nameBandBottom,
                    ),
                    const SizedBox(height: _wordsGap),
                    Text('${floor.number}F 체육관 관장', style: text.arcadeBossRole),
                    const SizedBox(height: _wordsGap),
                    Container(
                      height: _levelHeight,
                      padding: const EdgeInsets.symmetric(horizontal: _tagSide),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(_levelCorners),
                      ),
                      child: Text(
                        'AI LV ${stage.aiLevel.level}',
                        style: text.arcadeLevelChip,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ROUND 1 and ROUND 2 side by side with an arrow between them.
class _Rounds extends StatelessWidget {
  const _Rounds({required this.stage});

  final ArcadeBossStage stage;

  static const _between = 26.0;
  static const _arrow = 18.0;
  static const _arrowStroke = 3.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _RoundCard(number: 1, exercise: stage.rounds[0])),
        const SizedBox(
          width: _between,
          child: Center(
            child: ArcadeGlyphIcon(
              ArcadeGlyph.arrow,
              size: _arrow,
              strokeWidth: _arrowStroke,
            ),
          ),
        ),
        Expanded(child: _RoundCard(number: 2, exercise: stage.rounds[1])),
      ],
    );
  }
}

/// One round on the intro: "ROUND n", the exercise's figure and name, and
/// its length.
class _RoundCard extends StatelessWidget {
  const _RoundCard({required this.number, required this.exercise});

  final int number;
  final ExerciseType exercise;

  static const _inside = AppSpacing.s12;
  static const _under = 10.0;
  static const _padding = EdgeInsets.fromLTRB(
    _inside,
    _inside,
    _inside,
    _under,
  );
  static const _corners = 16.0;
  static const _edge = 2.0;
  static const _gap = 6.0;
  static const _icon = 26.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_corners),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ROUND $number', style: text.arcadeRoundLabel),
          const SizedBox(height: _gap),
          Row(
            children: [
              ArcadeGlyphIcon(arcadeExerciseGlyph(exercise), size: _icon),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: LobbySkew(
                  degrees: 10,
                  child: Text(
                    exercise.koreanName,
                    style: text.arcadeRoundName,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _gap),
          Text('${battleDuration.inSeconds}초', style: text.arcadeRoundTime),
        ],
      ),
    );
  }
}

/// The figure of [exercise].
ArcadeGlyph arcadeExerciseGlyph(ExerciseType exercise) =>
    exercise == ExerciseType.pushUp ? ArcadeGlyph.pushUp : ArcadeGlyph.squat;

/// The break after R1 won: "1라운드 승리!", R1's score, R1 checked and R2
/// next, the owner hit, R2's card, 자세 잡기 and 그만하기.
class _Break extends StatelessWidget {
  const _Break({
    required this.stage,
    required this.first,
    required this.onSetUp,
    required this.onQuit,
  });

  final ArcadeBossStage stage;
  final BattleResult first;
  final VoidCallback onSetUp;
  final VoidCallback onQuit;

  static const _side = AppSpacing.s20;
  static const _top = AppSpacing.s12;
  static const _bottom = 22.0;
  static const _bannerSide = 18.0;
  static const _bannerOver = 2.0;
  static const _bannerUnder = 5.0;
  static const _bannerPadding = EdgeInsets.fromLTRB(
    _bannerSide,
    _bannerOver,
    _bannerSide,
    _bannerUnder,
  );
  static const _gap = 14.0;
  static const _scoreGap = AppSpacing.s16;
  static const _figureBox = Size(320, 178);
  static const _figureScale = 1.05;
  static const _pedestalWidth = 112.0;
  static const _pedestalHeight = 14.0;
  static const _pedestalBottom = 4.0;
  static const _figureBottom = 10.0;
  static const _buttonHeight = 58.0;
  static const _buttonGap = 10.0;
  static const _arrow = 22.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final floor = ArcadeCatalog.floorOf(stage);
    final next = stage.rounds[1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(_side, _top, _side, _bottom),
      child: Column(
        children: [
          Text(
            'STAGE ${stage.number} · ${stage.floor}F BOSS',
            style: text.arcadeResultTag,
          ),
          const SizedBox(height: AppSpacing.s8),
          ArcadeTitleBand(
            label: '1라운드 승리!',
            color: AppColors.accent,
            style: text.arcadeBannerSmall,
            padding: _bannerPadding,
          ),
          const SizedBox(height: _scoreGap),
          ArcadeScoreLine(
            me: first.myDisplayScore,
            opponent: first.opponentDisplayScore,
            meLarger: true,
          ),
          const SizedBox(height: _gap),
          const _RoundProgress(),
          const SizedBox(height: _gap),
          SizedBox.fromSize(
            size: _figureBox,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  bottom: _pedestalBottom,
                  child: ArcadePedestal(
                    width: _pedestalWidth,
                    height: _pedestalHeight,
                  ),
                ),
                Positioned(
                  bottom: _figureBottom,
                  child: Transform(
                    transform: Matrix4.diagonal3Values(
                      -_figureScale,
                      _figureScale,
                      1,
                    ),
                    origin: const Offset(70, 150),
                    child: ArcadeFigure(id: floor.owner, pose: BattlePose.hit),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _gap),
          _NextRoundCard(exercise: next),
          const Spacer(),
          ArcadeDarkButton(
            label: '자세 잡기',
            onPressed: onSetUp,
            height: _buttonHeight,
            gap: _buttonGap,
            arrowSize: _arrow,
            style: text.arcadeBossAction,
          ),
          const SizedBox(height: AppSpacing.s8),
          ArcadeTextLink(label: '그만하기', onPressed: onQuit),
        ],
      ),
    );
  }
}

/// R1 checked on lime, a line, and R2 next with a lime glow.
class _RoundProgress extends StatelessWidget {
  const _RoundProgress();

  static const _disc = 48.0;
  static const _edge = 3.0;
  static const _check = 24.0;
  static const _checkStroke = 3.2;
  static const _line = Size(54, 4);
  static const _glow = 5.0;
  static const _glowShade = 0.7;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '라운드 진행, 1라운드 승리, 다음 2라운드',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _disc,
            height: _disc,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: _edge),
            ),
            child: const ArcadeGlyphIcon(
              ArcadeGlyph.check,
              size: _check,
              strokeWidth: _checkStroke,
            ),
          ),
          SizedBox.fromSize(
            size: _line,
            child: const ColoredBox(color: AppColors.ink),
          ),
          Container(
            width: _disc,
            height: _disc,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: _edge),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: _glowShade),
                  spreadRadius: _glow,
                ),
              ],
            ),
            child: Text(
              'R2',
              style: Theme.of(context).textTheme.arcadeRoundDisc,
            ),
          ),
        ],
      ),
    );
  }
}

/// NEXT · ROUND 2 with the exercise's figure and "스쿼트 30초".
class _NextRoundCard extends StatelessWidget {
  const _NextRoundCard({required this.exercise});

  final ExerciseType exercise;

  static const _over = 14.0;
  static const _padding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s16,
    vertical: _over,
  );
  static const _corners = 18.0;
  static const _edge = 2.0;
  static const _gap = 14.0;
  static const _iconBox = 56.0;
  static const _iconCorners = 16.0;
  static const _icon = 34.0;
  static const _lineGap = 3.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '2라운드 준비',
      child: Container(
        width: double.infinity,
        padding: _padding,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(_corners),
          border: Border.all(color: AppColors.ink, width: _edge),
        ),
        child: Row(
          children: [
            Container(
              width: _iconBox,
              height: _iconBox,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.selectedFill,
                borderRadius: BorderRadius.circular(_iconCorners),
                border: Border.all(color: AppColors.ink, width: _edge),
              ),
              child: ArcadeGlyphIcon(
                arcadeExerciseGlyph(exercise),
                size: _icon,
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEXT · ROUND 2', style: text.arcadeRoundLabel),
                  const SizedBox(height: _lineGap),
                  LobbySkew(
                    degrees: 10,
                    child: Text(
                      '${exercise.koreanName} ${battleDuration.inSeconds}초',
                      style: text.arcadeNextRound,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
