import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/arcade_catalog.dart';
import '../models/arcade_stage.dart';
import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../theme/app_theme.dart';
import '../viewmodels/arcade_viewmodel.dart';
import 'arcade_parts.dart';
import 'gym_background.dart';

/// A fight stage's sheet over the map (P16 spec 5, design `ArcMap`
/// `sheet`): the floor's gym with the opponent and the stage's chips, the
/// exercise and the floor's rule, the three star conditions with the stars
/// got lit, and 닫기 / 도전.
class ArcadeStageSheet extends StatelessWidget {
  const ArcadeStageSheet({
    super.key,
    required this.stage,
    required this.best,
    required this.onClose,
    required this.onChallenge,
  });

  final ArcadeFightStage stage;

  /// The most stars got in the stage.
  final int best;
  final VoidCallback onClose;
  final VoidCallback onChallenge;

  static const _corners = 26.0;
  static const _edge = 2.5;
  static const _side = 18.0;
  static const _top = 10.0;
  static const _bottom = 22.0;
  static const _gap = 14.0;
  static const _handle = Size(44, 5);
  static const _handleCorners = 3.0;
  static const _closeWidth = 96.0;
  static const _buttonGap = 10.0;

  /// Shows [stage]'s sheet over [context]'s map, the map dimmed under it,
  /// as a route named [routeName]. 도전 closes it and runs [onChallenge].
  static Future<void> show(
    BuildContext context, {
    required ArcadeFightStage stage,
    required int best,
    required VoidCallback onChallenge,
    String? routeName,
  }) => showModalBottomSheet<void>(
    context: context,
    routeSettings: RouteSettings(name: routeName),
    isScrollControlled: true,
    backgroundColor: AppColors.card.withValues(alpha: 0),
    barrierColor: AppColors.ink.withValues(alpha: 0.5),
    elevation: 0,
    builder: (sheet) => ArcadeStageSheet(
      stage: stage,
      best: best,
      onClose: () => Navigator.pop(sheet),
      onChallenge: () {
        Navigator.pop(sheet);
        onChallenge();
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final floor = ArcadeCatalog.floorOf(stage);
    final rule = floor.rule;
    final text = Theme.of(context).textTheme;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: '스테이지 ${stage.number}',
      child: Container(
        padding: EdgeInsets.fromLTRB(
          _side,
          _top,
          _side,
          _bottom + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(_corners)),
          border: Border(
            top: BorderSide(color: AppColors.ink, width: _edge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: _handle.width,
                height: _handle.height,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(_handleCorners),
                ),
              ),
            ),
            const SizedBox(height: _gap),
            _Picture(stage: stage),
            const SizedBox(height: _gap),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                _Chip(
                  color: AppColors.selectedFill,
                  icon: ArcadeGlyphIcon(
                    stage.exercise == ExerciseType.pushUp
                        ? ArcadeGlyph.pushUp
                        : ArcadeGlyph.squat,
                    size: _Chip.exerciseIcon,
                  ),
                  label:
                      '${stage.exercise.koreanName} · '
                      '${battleDuration.inSeconds}초',
                  side: _Chip.exerciseSide,
                  gap: _Chip.exerciseGap,
                ),
                if (rule != null)
                  _Chip(
                    color: AppColors.warning,
                    icon: const ArcadeGlyphIcon(
                      ArcadeGlyph.bolt,
                      size: _Chip.boltIcon,
                    ),
                    label: rule.label,
                    side: _Chip.ruleSide,
                    gap: _Chip.ruleGap,
                  ),
              ],
            ),
            const SizedBox(height: _gap),
            ArcadeStarGoals(
              title: '별 조건',
              labels: [for (final star in stage.stars) star.label],
              best: best,
              style: text.arcadeGoal,
            ),
            const SizedBox(height: _gap),
            Row(
              children: [
                SizedBox(
                  width: _closeWidth,
                  child: ArcadeLightButton(label: '닫기', onPressed: onClose),
                ),
                const SizedBox(width: _buttonGap),
                Expanded(
                  child: ArcadeDarkButton(
                    label: '도전',
                    onPressed: onChallenge,
                    style: text.arcadeSheetAction,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The sheet's picture: the floor's gym, the opponent on the right facing
/// left, "STAGE 8" and "2F · AI LV 6" at the top left and the opponent's
/// name over a lime band.
class _Picture extends StatelessWidget {
  const _Picture({required this.stage});

  final ArcadeFightStage stage;

  static const _height = 176.0;
  static const _edge = 2.5;
  static const _corners = 20.0;
  static const _art = Offset(-20, -150);
  static const _inset = 14.0;
  static const _figureRight = 18.0;
  static const _figureBottom = 6.0;
  static const _figureScale = 0.9;
  static const _chipGap = 8.0;
  static const _lineGap = 5.0;
  static const _metaSide = 6.0;
  static const _metaOver = 1.0;
  static const _metaPadding = EdgeInsets.symmetric(
    horizontal: _metaSide,
    vertical: _metaOver,
  );
  static const _metaShade = 0.9;
  static const _metaCorners = 6.0;
  static const _chipHeight = 24.0;
  static const _chipSide = 9.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = ArcadeWords.characterName(stage.character);
    return Container(
      height: _height,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_corners),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_corners),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            const Positioned.fill(
              child: ColoredBox(
                color: AppColors.facetLight,
                child: CustomPaint(
                  painter: ArcadeGridPainter(
                    cell: ArcadeGridPainter.sheetCell,
                    strength: ArcadeGridPainter.sheetStrength,
                  ),
                ),
              ),
            ),
            Positioned(
              left: _art.dx,
              top: _art.dy,
              width: gymBackgroundSize.width,
              height: gymBackgroundSize.height,
              child: GymBackground(floor: stage.floor),
            ),
            Positioned(
              right: _figureRight,
              bottom: _figureBottom,
              child: Transform(
                transform: Matrix4.diagonal3Values(
                  -_figureScale,
                  _figureScale,
                  1,
                ),
                origin: const Offset(70, 150),
                child: ArcadeFigure(id: stage.character),
              ),
            ),
            Positioned(
              left: _inset,
              top: _inset,
              right: _inset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ArcadeSlantChip(
                        label: 'STAGE ${stage.number}',
                        style: text.arcadeStageChip,
                        height: _chipHeight,
                        padding: _chipSide,
                      ),
                      const SizedBox(width: _chipGap),
                      Container(
                        padding: _metaPadding,
                        decoration: BoxDecoration(
                          color: AppColors.card.withValues(alpha: _metaShade),
                          borderRadius: BorderRadius.circular(_metaCorners),
                        ),
                        child: Text(
                          '${stage.floor}F · ${ArcadeWords.levelChip(stage)}',
                          style: text.arcadeSheetMeta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _lineGap),
                  ArcadeMarkedName(name: name, style: text.arcadeSheetName),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A name over a lime band slanted 14°, the band from 4 before it to 8
/// after it, 13 high, 2 over its bottom (the sheet's and the boss intro's
/// names; the boss's band is 15 high and 3 up).
class ArcadeMarkedName extends StatelessWidget {
  const ArcadeMarkedName({
    super.key,
    required this.name,
    required this.style,
    this.bandHeight = defaultBand,
    this.bandBottom = defaultBandBottom,
  });

  /// The sheet's band: 13 high, 2 over the name's bottom.
  static const defaultBand = 13.0;
  static const defaultBandBottom = 2.0;

  final String name;
  final TextStyle style;
  final double bandHeight;
  final double bandBottom;

  static const _before = -4.0;
  static const _after = -8.0;
  static const _slant = -14 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _before,
          right: _after,
          bottom: bandBottom,
          height: bandHeight,
          child: Transform(
            transform: Matrix4.skewX(_slant),
            alignment: Alignment.center,
            child: const ColoredBox(color: AppColors.accent),
          ),
        ),
        Text(name, style: style, maxLines: 1),
      ],
    );
  }
}

/// A chip on the sheet: an icon and a 13 bold label on [color], edged ink.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.color,
    required this.icon,
    required this.label,
    required this.side,
    required this.gap,
  });

  final Color color;
  final Widget icon;
  final String label;
  final double side;
  final double gap;

  static const exerciseIcon = 18.0;
  static const exerciseSide = 12.0;
  static const exerciseGap = 6.0;
  static const boltIcon = 13.0;
  static const ruleSide = 10.0;
  static const ruleGap = 4.0;
  static const _height = 32.0;
  static const _corners = 10.0;
  static const _edge = 2.0;

  @override
  Widget build(BuildContext context) => Container(
    height: _height,
    padding: EdgeInsets.symmetric(horizontal: side),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(_corners),
      border: Border.all(color: AppColors.ink, width: _edge),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(width: gap),
        Text(label, style: Theme.of(context).textTheme.arcadeSheetChip),
      ],
    ),
  );
}
