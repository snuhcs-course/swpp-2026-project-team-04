import 'package:flutter/material.dart';

import '../models/ranking_standing.dart';
import '../theme/app_theme.dart';
import 'lobby_parts.dart';

/// One player's row in the weekly list (A13 design `RankD1`, `RankF1`,
/// `RankF3`): the rank in a slanted cell (ink for me, orange for the first,
/// gray before a first battle), the name and record, and the points.
///
/// A row without a battle this week ([battles] 0, the friends tab only)
/// shows '–' instead of the server's shared rank, in gray; mine stays on
/// lime even then.
class WeeklyRankingsRow extends StatelessWidget {
  const WeeklyRankingsRow({
    super.key,
    required this.rank,
    required this.nickname,
    required this.points,
    required this.battles,
    required this.wins,
    required this.koWins,
    required this.isMe,
  });

  final int rank;
  final String nickname;
  final int points;
  final int battles;
  final int wins;
  final int koWins;
  final bool isMe;

  static const height = 46.0;
  static const rankWidth = 40.0;
  static const _edge = 1.5;
  static const _corner = 9.0;
  static const _nameSide = 10.0;
  static const _pointsSide = AppSpacing.s12;
  static const _lineGap = 1.0;
  static const _unitGap = 1.0;
  static const _markGap = 5.0;

  bool get idle => battles == 0;

  /// The rank cell's fill.
  Color get rankFill => isMe
      ? AppColors.ink
      : idle
      ? AppColors.cardHigh
      : rank == 1
      ? AppColors.warning
      : AppColors.card;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final record = RankingWeek.record(
      battles: battles,
      wins: wins,
      koWins: koWins,
    );
    final gray = idle && !isMe;
    final shown = idle ? '–' : '$rank';
    final rankStyle = !idle && rank >= 10
        ? text.rankingRowRankWide
        : text.statsCount;
    final name = isMe ? '$nickname (나)' : nickname;
    return Semantics(
      container: true,
      label: '${idle ? '순위 없음' : '$rank위'}, $name, $points점, $record',
      excludeSemantics: true,
      child: WeeklyRankingsOutline(
        minHeight: height,
        fill: isMe ? AppColors.accent : AppColors.card,
        edgeColor: gray ? AppColors.inactive : AppColors.ink,
        edge: _edge,
        corner: _corner,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: rankWidth,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankFill,
                  border: const Border(
                    right: BorderSide(color: AppColors.ink, width: _edge),
                  ),
                ),
                child: LobbySkew(
                  degrees: 12,
                  alignment: Alignment.center,
                  child: Text(
                    shown,
                    maxLines: 1,
                    style: rankStyle.copyWith(
                      color: isMe
                          ? AppColors.accent
                          : idle
                          ? AppColors.inactive
                          : AppColors.ink,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _nameSide),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.rankingName.copyWith(
                                color: gray
                                    ? AppColors.textSecondary
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: _markGap),
                            const WeeklyRankingsMeMark(),
                          ],
                        ],
                      ),
                      const SizedBox(height: _lineGap),
                      Text(
                        record,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.rankingRecord.copyWith(
                          color: isMe ? AppColors.ink : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _pointsSide),
                // In the row's middle, as the design's `align-items: center`.
                child: Align(
                  widthFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$points',
                        style: text.statsCount.copyWith(
                          color: gray ? AppColors.inactive : AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: _unitGap),
                      Text(
                        '점',
                        style: text.rankingSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: gray ? AppColors.inactive : AppColors.ink,
                        ),
                      ),
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

/// "나" after my name: a lime tag 16 high with a 1.2 ink edge.
class WeeklyRankingsMeMark extends StatelessWidget {
  const WeeklyRankingsMeMark({super.key});

  static const height = 16.0;
  static const _side = AppSpacing.s4;
  static const _edge = 1.2;
  static const _corner = 4.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(horizontal: _side),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        border: Border.all(color: AppColors.ink, width: _edge),
        borderRadius: const BorderRadius.all(Radius.circular(_corner)),
      ),
      child: Text('나', style: Theme.of(context).textTheme.rankingMeMark),
    );
  }
}

/// The list's name on the left ("TOP 50", "나와 친구 4명", Do Hyeon slanted
/// 8°) and a gray note on the right.
class WeeklyRankingsListHeading extends StatelessWidget {
  const WeeklyRankingsListHeading({
    super.key,
    required this.title,
    this.note = '',
  });

  final String title;

  /// "같은 점수는 같은 등수", or empty.
  final String note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Semantics(
          header: true,
          child: LobbySkew(
            degrees: 8,
            child: Text(title, style: text.rankingListTitle),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            note,
            textAlign: TextAlign.end,
            style: text.rankingSmall.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// A rounded box of [fill] whose [edge] is drawn over its content, the
/// content clipped inside the edge: the design's `border` with
/// `overflow: hidden`, so a fill inside never covers the edge's corners.
class WeeklyRankingsOutline extends StatelessWidget {
  const WeeklyRankingsOutline({
    super.key,
    required this.fill,
    required this.edge,
    required this.corner,
    required this.child,
    this.edgeColor = AppColors.ink,
    this.minHeight = 0,
    this.height,
  });

  final Color fill;
  final Color edgeColor;
  final double edge;
  final double corner;
  final double minHeight;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.all(edge),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.all(Radius.circular(corner)),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: edgeColor, width: edge),
        borderRadius: BorderRadius.all(Radius.circular(corner)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(corner - edge)),
        child: child,
      ),
    );
  }
}
