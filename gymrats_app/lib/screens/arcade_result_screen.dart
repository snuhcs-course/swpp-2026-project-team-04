import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/arcade_catalog.dart';
import '../models/arcade_stage.dart';
import '../models/battle_result.dart';
import '../models/character_rig.dart';
import '../models/exercise_type_korean.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import '../theme/app_theme.dart';
import '../viewmodels/arcade_viewmodel.dart';
import '../viewmodels/character_viewmodel.dart';
import '../widgets/arcade_parts.dart';
import '../widgets/battle_fx_motion.dart';
import '../widgets/battle_stage_model.dart';
import '../widgets/character_figure.dart';
import '../widgets/grid_background.dart';
import 'arcade_flow.dart';
import 'hold_stage_brief.dart';
import 'hold_stage_result.dart';

/// What an arcade battle came to (P16 spec 6 and 7), in A4's result frame
/// ([ArcadeResultFrame], the design's `ArcResult`): a fight cleared or
/// failed, a boss match's floor cleared (4F: 4층 클리어 with 5F 공사중) or
/// a round lost.
///
/// [rounds] are the battles played, the last the one just ended: one for a
/// fight, one or two for a boss match. 리포트 보기 opens the last one's
/// report on top. Back, like 아케이드로, returns to the map.
class ArcadeResultScreen extends StatelessWidget {
  const ArcadeResultScreen({
    super.key,
    required this.stage,
    required this.rounds,
    required this.stars,
  });

  final ArcadeStage stage;
  final List<BattleResult> rounds;
  final ArcadeStars stars;

  // The stand, as `ArcResult` places it: a clear (lastFloor) has the user
  // cheering on the step and the opponent knocked out on the right; a fail
  // has the user knocked out on the left and the opponent cheering on the
  // step, facing left.
  static const _clearStep = 70.0;
  static const _clearMeLeft = 56.0;
  static const _clearMeScale = 1.05;
  static const _clearOpponentLeft = 182.0;
  static const _lyingScale = 0.62;
  static const _failStep = 160.0;
  static const _failMeLeft = 30.0;
  static const _failMeScale = 0.9;
  static const _failOpponentLeft = 150.0;
  static const _standBottom = 12.0;

  /// The gaps over what follows the stand.
  static const _nextGap = 14.0;
  static const _rowsGap = 6.0;
  static const _floorGap = 10.0;

  @override
  Widget build(BuildContext context) {
    final stage = this.stage;
    final me =
        context.watch<CharacterViewModel?>()?.characterId ??
        CharacterRig.defaultId;
    final last = rounds.last;
    final starList = [
      for (final (i, star) in stage.stars.indexed)
        ArcadeResultStar(lit: stars.lit[i], label: star.label),
    ];
    void report() => ArcadeFlow.openReport(context, last);
    void leave() => ArcadeFlow.leave(context);
    final cleared = stars.cleared;
    final figures = cleared
        ? ArcadeResultFigures(
            stepLeft: _clearStep,
            me: CharacterFigure(characterId: me, pose: BattlePose.win),
            meLeft: _clearMeLeft,
            meScale: _clearMeScale,
            opponent: _opponent(stage.character, BattlePose.knockedOut),
            opponentLeft: _clearOpponentLeft,
            opponentBottom: 0,
          )
        : ArcadeResultFigures(
            stepLeft: _failStep,
            me: CharacterFigure(characterId: me, pose: BattlePose.knockedOut),
            meLeft: _failMeLeft,
            meScale: _failMeScale,
            opponent: _opponent(stage.character, BattlePose.win, scale: 1),
            opponentLeft: _failOpponentLeft,
            opponentBottom: _standBottom,
          );
    final Widget frame;
    String? link;
    switch (stage) {
      case ArcadeFightStage() when cleared:
        frame = ArcadeResultFrame(
          tag: ArcadeWords.stageTag(stage),
          title: '클리어!',
          cleared: true,
          stars: starList,
          figures: figures,
          below: ArcadeNextStageFaceCard(
            stage: ArcadeCatalog.stage(stage.number + 1),
          ),
          belowGap: _nextGap,
          secondaryLabel: '리포트 보기',
          onSecondary: report,
          primaryLabel: '다음 스테이지',
          onPrimary: () => ArcadeFlow.next(context, stage.number + 1),
        );
      case ArcadeFightStage():
        link = '아케이드로';
        frame = ArcadeResultFrame(
          tag: ArcadeWords.stageTag(stage),
          title: '실패',
          cleared: false,
          middle: ArcadeScoreLine(
            me: last.myDisplayScore,
            opponent: last.opponentDisplayScore,
            meLarger: last.myDisplayScore > last.opponentDisplayScore,
          ),
          stars: starList,
          figures: figures,
          secondaryLabel: '리포트 보기',
          onSecondary: report,
          primaryLabel: '다시 도전',
          onPrimary: () => ArcadeFlow.replay(context, stage.number),
        );
      case ArcadeBossStage() when !cleared:
        link = '아케이드로';
        frame = ArcadeResultFrame(
          tag: 'STAGE ${stage.number} · ${stage.floor}F BOSS',
          title: 'R${rounds.length} 패배',
          cleared: false,
          stars: starList,
          figures: figures,
          below: ArcadeRoundRows(stage: stage, rounds: rounds),
          belowGap: _rowsGap,
          secondaryLabel: '리포트 보기',
          onSecondary: report,
          primaryLabel: 'R1부터 다시',
          onPrimary: () => ArcadeFlow.replay(context, stage.number),
        );
      case ArcadeBossStage() when stage.floor == ArcadeCatalog.floors.length:
        frame = ArcadeResultFrame(
          tag: 'STAGE ${stage.number} · ${stage.floor}F BOSS',
          title: '${stage.floor}층 클리어!',
          cleared: true,
          stars: starList,
          figures: figures,
          below: const ArcadeUnderConstructionCard(),
          belowGap: AppSpacing.s8,
          secondaryLabel: '리포트 보기',
          onSecondary: report,
          primaryLabel: '아케이드로',
          onPrimary: leave,
        );
      case ArcadeBossStage():
        final floor = ArcadeCatalog.floorOf(stage);
        frame = ArcadeResultFrame(
          tag: 'STAGE ${stage.number} · ${floor.number}F ${floor.name}',
          title: '${floor.number}층 클리어!',
          cleared: true,
          stars: starList,
          figures: figures,
          below: Column(
            children: [
              ArcadeRoundRows(stage: stage, rounds: rounds),
              const SizedBox(height: _floorGap),
              ArcadeNextFloorCard(floor: floor.number + 1),
            ],
          ),
          belowGap: _rowsGap,
          secondaryLabel: '리포트 보기',
          onSecondary: report,
          primaryLabel: '${floor.number + 1}층으로',
          onPrimary: () => ArcadeFlow.next(context, stage.number + 1),
        );
      case ArcadeHoldStage():
        return const SizedBox.shrink();
    }
    final linkLabel = link;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: GridBackground(
          child: linkLabel == null
              ? frame
              // The link under the frame's buttons (`ArcResult` fail and
              // bossFail): the frame keeps its own room under them.
              : Column(
                  children: [
                    Expanded(
                      child: MediaQuery.removePadding(
                        context: context,
                        removeBottom: true,
                        child: frame,
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: ArcadeTextLink(label: linkLabel, onPressed: leave),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// The opponent [id] as the stand puts it: [pose] in the opponent's
  /// color, facing left, [scale]d about the feet and edged white.
  static Widget _opponent(
    String id,
    BattlePose pose, {
    double scale = _lyingScale,
  }) => SizedBox.fromSize(
    size: HoldOwner.box,
    child: Transform(
      transform: Matrix4.diagonal3Values(-scale, scale, 1),
      origin: const Offset(70, 150),
      child: HoldOutlined(
        child: CharacterFigure(
          characterId: id,
          pose: pose,
          side: BattleSide.opponent,
        ),
      ),
    ),
  );
}

/// The next stage's card under a fight's clear (P16 spec 6): the face of
/// who is met there, an open lock with "STAGE n", its title, and its kind
/// ("HOLD", "BOSS").
class ArcadeNextStageFaceCard extends StatelessWidget {
  const ArcadeNextStageFaceCard({super.key, required this.stage});
  final ArcadeStage stage;

  static const _cardSide = 14.0;
  static const _padding = EdgeInsets.symmetric(
    horizontal: _cardSide,
    vertical: AppSpacing.s12,
  );
  static const _corners = 18.0;
  static const _edge = 2.0;
  static const _face = 46.0;
  static const _faceScale = 0.56;
  static const _lock = 13.0;
  static const _tagGap = 6.0;
  static const _lineGap = 1.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kind = switch (stage.kind) {
      ArcadeStageKind.hold => 'HOLD',
      ArcadeStageKind.boss => 'BOSS',
      ArcadeStageKind.fight => null,
    };
    return Container(
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
            width: _face,
            height: _face,
            decoration: BoxDecoration(
              color: AppColors.facetLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: _edge),
            ),
            child: ClipOval(
              child: ArcadeFace(
                id: stage.character,
                size: _face - 2 * _edge,
                scale: _faceScale,
                owner: stage.kind == ArcadeStageKind.hold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ArcadeGlyphIcon(
                      ArcadeGlyph.unlock,
                      size: _lock,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: _tagGap),
                    Text('STAGE ${stage.number}', style: text.arcadeNextTag),
                  ],
                ),
                const SizedBox(height: _lineGap),
                Text(
                  ArcadeWords.title(stage),
                  style: text.arcadeNextTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (kind != null) ...[
            const SizedBox(width: AppSpacing.s12),
            Text(kind, style: text.arcadeNextKind),
          ],
        ],
      ),
    );
  }
}

/// A boss match's rounds, one row each: a won round checked on lime with
/// how it was won, a lost one crossed on red, both with the score; a round
/// not reached locked and dashed.
class ArcadeRoundRows extends StatelessWidget {
  const ArcadeRoundRows({super.key, required this.stage, required this.rounds});

  final ArcadeBossStage stage;
  final List<BattleResult> rounds;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < stage.rounds.length; index++) ...[
          if (index > 0) const SizedBox(height: ArcadeResultScreen._rowsGap),
          _RoundRow(
            number: index + 1,
            exercise: stage.rounds[index].koreanName,
            result: index < rounds.length ? rounds[index] : null,
          ),
        ],
      ],
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({
    required this.number,
    required this.exercise,
    required this.result,
  });

  final int number;
  final String exercise;

  /// The round as played; null when it was not reached.
  final BattleResult? result;

  static const _over = 9.0;
  static const _padding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s12,
    vertical: _over,
  );
  static const _corners = 14.0;
  static const _edge = 1.5;
  static const _gap = 10.0;
  static const _disc = 24.0;
  static const _discEdge = 2.0;
  static const _check = 14.0;
  static const _cross = 12.0;
  static const _lock = 11.0;
  static const _lockStroke = 3.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final result = this.result;
    if (result == null) {
      return CustomPaint(
        painter: const _DashedEdge(),
        child: Container(
          padding: _padding,
          decoration: BoxDecoration(
            color: AppColors.roundLockedFill,
            borderRadius: BorderRadius.circular(_corners),
          ),
          child: Row(
            children: [
              Container(
                width: _disc,
                height: _disc,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.roundLockedEdge,
                    width: _discEdge,
                  ),
                ),
                child: const ArcadeGlyphIcon(
                  ArcadeGlyph.lock,
                  size: _lock,
                  color: AppColors.lockedEdge,
                  strokeWidth: _lockStroke,
                ),
              ),
              const SizedBox(width: _gap),
              Text(
                'R$number',
                style: text.arcadeRoundTag.copyWith(
                  color: AppColors.lockedEdge,
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: Text(
                  exercise,
                  style: text.arcadeRoundText.copyWith(
                    color: AppColors.lockedEdge,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final won = result.outcome == MatchOutcome.win;
    final how = switch (result.outcome) {
      MatchOutcome.win when result.end == GameEnd.ko => 'KO 승리',
      MatchOutcome.win => '승리',
      MatchOutcome.draw => '무승부',
      MatchOutcome.lose => '패배',
    };
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_corners),
        border: Border.all(color: AppColors.border, width: _edge),
      ),
      child: Row(
        children: [
          Container(
            width: _disc,
            height: _disc,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: won ? AppColors.accent : AppColors.danger,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: _discEdge),
            ),
            child: ArcadeGlyphIcon(
              won ? ArcadeGlyph.check : ArcadeGlyph.cross,
              size: won ? _check : _cross,
            ),
          ),
          const SizedBox(width: _gap),
          Text('R$number', style: text.arcadeRoundTag),
          const SizedBox(width: _gap),
          Expanded(
            child: Text('$exercise · $how', style: text.arcadeRoundText),
          ),
          Text(
            '${result.myDisplayScore} : ${result.opponentDisplayScore}',
            style: text.arcadeRoundScore,
          ),
        ],
      ),
    );
  }
}

/// A round not reached: its edge dashed (`1.5px dashed`).
class _DashedEdge extends CustomPainter {
  const _DashedEdge();

  static const _edge = 1.5;
  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(_edge / 2),
          const Radius.circular(_RoundRow._corners),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _edge
      ..color = AppColors.roundLockedEdge;
    for (final metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _gap) {
        canvas.drawPath(metric.extractPath(at, at + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedEdge oldDelegate) => false;
}

/// The next floor's card under a floor cleared: its chip, its name, its
/// gym owner, and OPEN.
class ArcadeNextFloorCard extends StatelessWidget {
  const ArcadeNextFloorCard({super.key, required this.floor});

  final int floor;

  static const _cardSide = 14.0;
  static const _padding = EdgeInsets.symmetric(
    horizontal: _cardSide,
    vertical: AppSpacing.s12,
  );
  static const _corners = 18.0;
  static const _edge = 2.0;
  static const _openHeight = 26.0;
  static const _openSide = 9.0;
  static const _openCorners = 8.0;
  static const _openGap = 4.0;
  static const _lock = 12.0;
  static const _lockStroke = 3.0;
  static const _lineGap = 1.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final next = ArcadeCatalog.floor(floor);
    return Container(
      width: double.infinity,
      padding: _padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_corners),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: Row(
        children: [
          ArcadeSlantChip(
            label: '${floor}F',
            style: text.arcadeCardFloor.copyWith(color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(next.name, style: text.arcadeNextTitle),
                const SizedBox(height: _lineGap),
                Text('체육관 관장 · ${next.ownerName}', style: text.arcadeNextOwner),
              ],
            ),
          ),
          Container(
            height: _openHeight,
            padding: const EdgeInsets.symmetric(horizontal: _openSide),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(_openCorners),
              border: Border.all(color: AppColors.ink, width: _edge),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ArcadeGlyphIcon(
                  ArcadeGlyph.unlock,
                  size: _lock,
                  strokeWidth: _lockStroke,
                ),
                const SizedBox(width: _openGap),
                Text(
                  'OPEN',
                  style: text.arcadeNextKind.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The last floor's card: "5F" and "공사중" over a striped strip.
class ArcadeUnderConstructionCard extends StatelessWidget {
  const ArcadeUnderConstructionCard({super.key});

  static const _height = 74.0;
  static const _side = 14.0;
  static const _corners = 18.0;
  static const _edge = 2.0;
  static const _strip = 12.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      height: _height,
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_corners),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      decoration: BoxDecoration(
        color: AppColors.wipCard,
        borderRadius: BorderRadius.circular(_corners),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _strip,
            child: _StripesStrip(),
          ),
          Positioned.fill(
            bottom: _strip,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _side),
              child: Row(
                children: [
                  ArcadeSlantChip(
                    label: '5F',
                    style: text.arcadeCardFloor.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Text('공사중', style: text.arcadeWipCard),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A strip of amber and ink stripes under an ink line: the bottom of the
/// last floor's card.
class _StripesStrip extends StatelessWidget {
  const _StripesStrip();

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
