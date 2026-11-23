import 'package:flutter/material.dart';

import '../models/arcade_catalog.dart';
import '../models/arcade_stage.dart';
import '../models/battle_result.dart';
import '../models/exercise_type_korean.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import '../theme/app_theme.dart';
import '../viewmodels/arcade_viewmodel.dart';
import '../widgets/arcade_parts.dart';
import '../widgets/arcade_result_frame.dart';
import '../widgets/battle_fx_motion.dart';
import 'arcade_flow.dart';

/// What an arcade battle came to (P16 spec 6 and 7): a fight cleared
/// (`P16Arc` clear) or failed (`ArcResult` fail), a boss match's floor
/// cleared (`P16Boss` clear; 4F: `ArcResult` lastFloor) or a round lost
/// (`ArcResult` bossFail).
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

  /// The design's tops below the status bar: 44 and 54 less its 28.
  static const _top = AppSpacing.s16;
  static const _clearTop = 26.0;

  /// Between the stand and what follows it.
  static const _nextGap = 14.0;
  static const _rowsGap = 6.0;
  static const _floorGap = 10.0;

  /// The floor cleared's title band: 20 beside it (P16Boss clear).
  static const _bossTitlePadding = EdgeInsets.fromLTRB(
    AppSpacing.s20,
    _bandOver,
    AppSpacing.s20,
    _bandUnder,
  );
  static const _bandOver = 2.0;
  static const _bandUnder = 6.0;

  // A fight's clear (P16Arc clear).
  static const _clearTitleGap = 10.0;
  static const _clearStar = 64.0;
  static const _clearMiddleStar = 76.0;
  static const _clearStarGap = 14.0;
  static const _clearLabelGap = 6.0;
  static const _clearStarsGap = 22.0;
  static const _clearStandHeight = 200.0;
  static const _clearPedestal = 104.0;
  static const _clearMeLeft = 90.0;
  static const _clearMeScale = 1.15;
  static const _clearOpponentRight = 6.0;
  static const _clearOpponentShade = 0.9;
  static const _clearFiguresGap = 18.0;

  // A floor cleared (P16Boss clear) and the last floor (ArcResult
  // lastFloor).
  static const _floorPedestal = 70.0;
  static const _floorMeLeft = 56.0;
  static const _floorMeScale = 1.05;
  static const _floorOpponentRight = 4.0;
  static const _lastOpponentLeft = 182.0;
  static const _floorStarWidth = 96.0;

  // Everyone stands 12 up; a knocked-out opponent lies on the floor, small.
  static const _standBottom = 12.0;
  static const _lyingScale = 0.62;

  @override
  Widget build(BuildContext context) {
    final stage = this.stage;
    final text = Theme.of(context).textTheme;
    final labels = [for (final star in stage.stars) star.label];
    final last = rounds.last;
    void report() => ArcadeFlow.openReport(context, last);
    final ArcadeBattleResultFrame frame;
    switch (stage) {
      case ArcadeFightStage() when stars.cleared:
        frame = ArcadeBattleResultFrame(
          top: _clearTop,
          tag: ArcadeWords.stageTag(stage),
          title: '클리어!',
          titleColor: AppColors.accent,
          titleStyle: text.arcadeBannerLarge,
          titleGap: _clearTitleGap,
          stars: ArcadeResultStars(
            labels: labels,
            lit: stars.lit,
            size: _clearStar,
            middleSize: _clearMiddleStar,
            gap: _clearStarGap,
            labelGap: _clearLabelGap,
          ),
          starsGap: _clearStarsGap,
          figures: ArcadeBattleFigures(
            height: _clearStandHeight,
            pedestalLeft: _clearPedestal,
            stands: [
              ArcadeBattleStand.me(
                left: _clearMeLeft,
                bottom: _standBottom,
                scale: _clearMeScale,
              ),
              ArcadeBattleStand.opponent(
                id: stage.character,
                pose: BattlePose.knockedOut,
                right: _clearOpponentRight,
                bottom: 0,
                scale: _lyingScale,
                opacity: _clearOpponentShade,
                outline: false,
              ),
            ],
          ),
          figuresGap: _clearFiguresGap,
          below: [
            const SizedBox(height: _nextGap),
            ArcadeBattleNextCard(stage: ArcadeCatalog.stage(stage.number + 1)),
          ],
          buttons: ArcadeBattleButtons(
            first: '리포트 보기',
            onFirst: report,
            second: '다음 스테이지',
            onSecond: () => ArcadeFlow.next(context, stage.number + 1),
          ),
        );
      case ArcadeFightStage():
        frame = ArcadeBattleResultFrame(
          top: _top,
          tag: ArcadeWords.stageTag(stage),
          title: '실패',
          titleColor: AppColors.facetDark,
          titleStyle: text.arcadeBanner,
          score: ArcadeScoreLine(
            me: last.myDisplayScore,
            opponent: last.opponentDisplayScore,
            meLarger: last.myDisplayScore > last.opponentDisplayScore,
          ),
          stars: ArcadeResultStars(labels: labels, lit: stars.lit),
          figures: ArcadeBattleFigures.lost(opponent: stage.character),
          buttons: ArcadeBattleButtons(
            first: '리포트 보기',
            onFirst: report,
            second: '다시 도전',
            onSecond: () => ArcadeFlow.replay(context, stage.number),
            link: '아케이드로',
            onLink: () => ArcadeFlow.leave(context),
          ),
        );
      case ArcadeBossStage() when !stars.cleared:
        frame = ArcadeBattleResultFrame(
          top: _top,
          tag: 'STAGE ${stage.number} · ${stage.floor}F BOSS',
          title: 'R${rounds.length} 패배',
          titleColor: AppColors.facetDark,
          titleStyle: text.arcadeBanner,
          stars: ArcadeResultStars(labels: labels, lit: stars.lit),
          figures: ArcadeBattleFigures.lost(opponent: stage.character),
          below: [
            const SizedBox(height: _rowsGap),
            ArcadeRoundRows(stage: stage, rounds: rounds),
          ],
          buttons: ArcadeBattleButtons(
            first: '리포트 보기',
            onFirst: report,
            second: 'R1부터 다시',
            onSecond: () => ArcadeFlow.replay(context, stage.number),
            link: '아케이드로',
            onLink: () => ArcadeFlow.leave(context),
          ),
        );
      case ArcadeBossStage() when stage.floor == ArcadeCatalog.floors.length:
        frame = ArcadeBattleResultFrame(
          top: _top,
          tag: 'STAGE ${stage.number} · ${stage.floor}F BOSS',
          title: '${stage.floor}층 클리어!',
          titleColor: AppColors.accent,
          titleStyle: text.arcadeBanner,
          stars: ArcadeResultStars(labels: labels, lit: stars.lit),
          figures: ArcadeBattleFigures(
            pedestalLeft: _floorPedestal,
            stands: [
              ArcadeBattleStand.me(
                left: _floorMeLeft,
                bottom: _standBottom,
                scale: _floorMeScale,
              ),
              ArcadeBattleStand.opponent(
                id: stage.character,
                pose: BattlePose.knockedOut,
                left: _lastOpponentLeft,
                bottom: 0,
                scale: _lyingScale,
                mirror: true,
              ),
            ],
          ),
          below: const [
            SizedBox(height: AppSpacing.s8),
            ArcadeUnderConstructionCard(),
          ],
          buttons: ArcadeBattleButtons(
            first: '리포트 보기',
            onFirst: report,
            second: '아케이드로',
            onSecond: () => ArcadeFlow.leave(context),
          ),
        );
      case ArcadeBossStage():
        final floor = ArcadeCatalog.floorOf(stage);
        frame = ArcadeBattleResultFrame(
          top: _top,
          tag: 'STAGE ${stage.number} · ${floor.number}F ${floor.name}',
          title: '${floor.number}층 클리어!',
          titleColor: AppColors.accent,
          titleStyle: text.arcadeBanner,
          titlePadding: _bossTitlePadding,
          stars: ArcadeResultStars(
            labels: labels,
            lit: stars.lit,
            width: _floorStarWidth,
          ),
          starsGap: AppSpacing.s16,
          figures: ArcadeBattleFigures(
            pedestalLeft: _floorPedestal,
            stands: [
              ArcadeBattleStand.me(
                left: _floorMeLeft,
                bottom: _standBottom,
                scale: _floorMeScale,
              ),
              ArcadeBattleStand.opponent(
                id: stage.character,
                pose: BattlePose.knockedOut,
                right: _floorOpponentRight,
                bottom: 0,
                scale: _lyingScale,
                outline: false,
              ),
            ],
          ),
          below: [
            const SizedBox(height: _rowsGap),
            ArcadeRoundRows(stage: stage, rounds: rounds),
            const SizedBox(height: _floorGap),
            ArcadeNextFloorCard(floor: floor.number + 1),
          ],
          buttons: ArcadeBattleButtons(
            first: '리포트 보기',
            onFirst: report,
            second: '${floor.number + 1}층으로',
            onSecond: () => ArcadeFlow.next(context, stage.number + 1),
          ),
        );
      case ArcadeHoldStage():
        return const SizedBox.shrink();
    }
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ArcadeFlow.leave(context);
      },
      child: frame,
    );
  }
}

/// The next stage's card under a fight's clear: its face, an open lock
/// with "STAGE n", its title, and its kind ("HOLD", "BOSS").
class ArcadeBattleNextCard extends StatelessWidget {
  const ArcadeBattleNextCard({super.key, required this.stage});

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
            child: ArcadeStripesStrip(),
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
