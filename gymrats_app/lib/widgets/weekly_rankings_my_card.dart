import 'package:flutter/material.dart';

import '../models/ranking_standing.dart';
import '../theme/app_theme.dart';
import 'character_figure.dart';
import 'lobby_parts.dart';
import 'weekly_rankings_row.dart';

/// My place this week (A13 design `RankD1`, `RankG2`, `RankG3`, `RankF1`–
/// `RankF3`): my character on a slanted lime panel, the scope over my rank,
/// my name, record and goal line, and my points. Before my first battle
/// ([RankingStanding.unranked]) the card is white with a gray panel, '–'
/// for the rank and 0 points in gray.
class WeeklyRankingsMyCard extends StatelessWidget {
  const WeeklyRankingsMyCard({
    super.key,
    required this.standing,
    required this.name,
    required this.record,
    required this.characterId,
  });

  final RankingStanding standing;

  /// My nickname.
  final String name;

  /// "4전 2승 · KO 1", or '이번 주 기록 없음'.
  final String record;

  /// The character I chose (only mine is drawn: the ranking has nobody
  /// else's).
  final String characterId;

  static const height = 92.0;
  static const _edge = 2.0;
  static const _corner = 16.0;
  static const _left = 6.0;
  static const _right = 14.0;
  static const _gap = 10.0;
  static const panelWidth = 84.0;

  @override
  Widget build(BuildContext context) {
    final unranked = standing.unranked;
    final scope = standing.friends ? '친구' : '전체';
    final rank = standing.rank;
    final words = [
      '$scope ${rank == null ? '순위 없음' : '$rank위'}',
      name,
      '${standing.points}점',
      record,
      ?standing.goalLine,
    ].join(', ');
    return Semantics(
      container: true,
      label: words,
      excludeSemantics: true,
      child: WeeklyRankingsOutline(
        minHeight: height,
        fill: unranked ? AppColors.card : AppColors.selectedFill,
        edge: _edge,
        corner: _corner,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: panelWidth,
              child: CustomPaint(
                painter: _PanelPainter(
                  unranked ? AppColors.cardHigh : AppColors.accent,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_left, 0, _right, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: height - 2 * _edge,
                ),
                child: Row(
                  children: [
                    WeeklyRankingsMyFigure(characterId: characterId),
                    const SizedBox(width: _gap),
                    _Rank(scope: scope, rank: rank),
                    const SizedBox(width: _gap),
                    Expanded(
                      child: _Middle(
                        name: name,
                        record: record,
                        standing: standing,
                      ),
                    ),
                    const SizedBox(width: _gap),
                    _Points(points: standing.points, gray: unranked),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The panel behind my character: `polygon(0 0, 100% 0, 78% 100%, 0 100%)`.
class _PanelPainter extends CustomPainter {
  const _PanelPainter(this.color);

  final Color color;

  static const _foot = 0.78;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()..addPolygon([
      Offset.zero,
      Offset(size.width, 0),
      Offset(size.width * _foot, size.height),
      Offset(0, size.height),
    ], true),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_PanelPainter oldDelegate) => oldDelegate.color != color;
}

/// My character standing idle in my team's color in a 76 x 76 window: its
/// 140 x 160 box at 0.507, feet at (38, 73).
class WeeklyRankingsMyFigure extends StatelessWidget {
  const WeeklyRankingsMyFigure({super.key, required this.characterId});

  final String characterId;

  static const size = 76.0;
  static const feet = Offset(38, 73);
  static const scale = 0.507;
  static const _boxFeet = Offset(70, 150);

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: feet.dx - _boxFeet.dx,
              top: feet.dy - _boxFeet.dy,
              child: Transform(
                transform: Matrix4.diagonal3Values(scale, scale, 1),
                origin: _boxFeet,
                child: CharacterFigure(characterId: characterId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scope's name over my rank, "4위" slanted 8°; '–' in gray unranked.
class _Rank extends StatelessWidget {
  const _Rank({required this.scope, required this.rank});

  final String scope;
  final int? rank;

  static const _unitGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rank = this.rank;
    final color = rank == null ? AppColors.inactive : AppColors.ink;
    // Two digits and more in the smaller size.
    final number = rank != null && rank >= 10
        ? text.archiveTotal
        : text.statsAverage;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scope,
          style: text.rankingTiny.copyWith(color: AppColors.textSecondary),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            LobbySkew(
              degrees: 8,
              alignment: Alignment.center,
              child: Text(
                rank == null ? '–' : '$rank',
                style: number.copyWith(color: color),
              ),
            ),
            const SizedBox(width: _unitGap),
            Text(
              '위',
              style: text.rankingScopeTab.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// My name, my record and the goal line: a bar with "3위까지 3점", or one
/// sentence, or nothing.
class _Middle extends StatelessWidget {
  const _Middle({
    required this.name,
    required this.record,
    required this.standing,
  });

  final String name;
  final String record;
  final RankingStanding standing;

  static const _lineGap = 2.0;
  static const _goalDrop = 3.0;
  static const _barGap = 6.0;

  /// The most of the line the goal's words take; the bar takes the rest.
  static const _wordsShare = 0.6;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final parts = standing.goalParts;
    final plain = standing.plainLine;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.rankingName,
        ),
        const SizedBox(height: _lineGap),
        Text(
          record,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.rankingRecord.copyWith(color: AppColors.textSecondary),
        ),
        if (parts != null) ...[
          const SizedBox(height: _lineGap + _goalDrop),
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(child: WeeklyRankingsGoalBar(standing.fill ?? 0)),
                const SizedBox(width: _barGap),
                // The words keep the bar beside them: on a narrow card or
                // with a large text size they shrink rather than push.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * _wordsShare,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: parts.lead),
                          TextSpan(
                            text: '${parts.number}',
                            style: text.rankingGoalNumber,
                          ),
                          TextSpan(text: parts.tail),
                        ],
                      ),
                      maxLines: 1,
                      style: text.rankingTiny,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (plain != null) ...[
          const SizedBox(height: _lineGap + _goalDrop),
          Text(
            plain,
            style: text.rankingRecord.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}

/// The goal's bar: 8 high, a 1.5 ink edge, 4 corners, white, filled lime
/// by [fill].
class WeeklyRankingsGoalBar extends StatelessWidget {
  const WeeklyRankingsGoalBar(this.fill, {super.key});

  final double fill;

  static const height = 8.0;
  static const _edge = 1.5;
  static const _corner = 4.0;

  @override
  Widget build(BuildContext context) {
    return WeeklyRankingsOutline(
      height: height,
      fill: AppColors.card,
      edge: _edge,
      corner: _corner,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fill.clamp(0.0, 1.0),
        child: const ColoredBox(color: AppColors.accent),
      ),
    );
  }
}

/// My points, "19점"; 0 in gray unranked.
class _Points extends StatelessWidget {
  const _Points({required this.points, required this.gray});

  final int points;
  final bool gray;

  static const _unitGap = 1.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = gray ? AppColors.inactive : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$points', style: text.archiveGain.copyWith(color: color)),
        const SizedBox(width: _unitGap),
        Text(
          '점',
          style: text.rankingLead.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
