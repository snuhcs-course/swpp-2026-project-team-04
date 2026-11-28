import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'exercise_sheet.dart';

/// A card in the list's place when there is nothing to list (A13 design
/// `RankF2`): the podium icon, a bold [title] and a gray [line], on white
/// at 70% inside a dashed gray edge. With [onAddFriends] (the friends tab
/// with only me) a white button '친구 추가하러 가기' under them; without it
/// (an empty global week) the words alone.
class WeeklyRankingsEmptyCard extends StatelessWidget {
  const WeeklyRankingsEmptyCard({
    super.key,
    required this.title,
    required this.line,
    this.onAddFriends,
  });

  /// The friends tab with only me in it.
  const WeeklyRankingsEmptyCard.noFriends({
    super.key,
    required VoidCallback this.onAddFriends,
  }) : title = '아직 비교할 친구가 없어요',
       line = '친구를 추가하면 이번 주 점수를 함께 겨뤄요.';

  /// The global tab before anyone's battle this week (P11's words).
  const WeeklyRankingsEmptyCard.emptyWeek({super.key})
    : title = '이번 주 온라인 대결 기록이 아직 없어요.',
      line = '첫 승점을 올려 보세요!',
      onAddFriends = null;

  final String title;
  final String line;
  final VoidCallback? onAddFriends;

  static const _padding = AppSpacing.s16;
  static const _edge = 1.5;
  static const _corner = AppRadius.card;
  static const _shade = 0.7;
  static const _icon = 40.0;
  static const _textGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onAddFriends = this.onAddFriends;
    return CustomPaint(
      foregroundPainter: const _DashedEdgePainter(
        color: AppColors.inactive,
        width: _edge,
        corner: _corner,
      ),
      child: Container(
        padding: const EdgeInsets.all(_padding),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: _shade),
          borderRadius: const BorderRadius.all(Radius.circular(_corner)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const ExcludeSemantics(child: RankingPodiumIcon(size: _icon)),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.rankingEmptyTitle),
                      const SizedBox(height: _textGap),
                      Text(
                        line,
                        style: text.rankingEmptyLine.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onAddFriends != null) ...[
              const SizedBox(height: AppSpacing.s12),
              _AddFriendsButton(onPressed: onAddFriends),
            ],
          ],
        ),
      ),
    );
  }
}

/// '친구 추가하러 가기' and a chevron on a white button with a 2 ink edge.
class _AddFriendsButton extends StatelessWidget {
  const _AddFriendsButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _height = 44.0;
  static const _edge = 2.0;
  static const _corner = 14.0;
  static const _chevron = 16.0;
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(_height),
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.ink, width: _edge),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_corner)),
        ),
        textStyle: Theme.of(context).textTheme.rankingButton,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text('친구 추가하러 가기')),
          SizedBox(width: _gap),
          Icon(Icons.chevron_right_rounded, size: _chevron),
        ],
      ),
    );
  }
}

/// A dashed rounded edge (`border: 1.5px dashed`): dashes three times the
/// line's width, as a browser draws them.
class _DashedEdgePainter extends CustomPainter {
  const _DashedEdgePainter({
    required this.color,
    required this.width,
    required this.corner,
  });

  final Color color;
  final double width;
  final double corner;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      Radius.circular(corner - width / 2),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final dash = width * 3;
    for (final PathMetric metric in (Path()..addRRect(edge)).computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += dash * 2) {
        canvas.drawPath(metric.extractPath(at, at + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedEdgePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.corner != corner;
}
