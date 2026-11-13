import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A personal best the battle set, in points of its exercise.
class ResultNewBest {
  const ResultNewBest({
    required this.previous,
    required this.current,
    required this.gain,
  });

  /// The best before this battle.
  final int previous;

  /// This battle's score, the new best.
  final int current;

  /// How much higher it is.
  final int gain;
}

/// This battle among the latest ones, for the bar chart.
class ResultRecent {
  const ResultRecent({
    required this.scores,
    required this.firstPlayedAt,
    required this.average,
    required this.averageCount,
    required this.difference,
  });

  /// The scores oldest first, this battle last. The chart draws the last
  /// [ResultRecentCard.slots] of them. The report leaves the card out when
  /// the list is empty; the card itself needs at least this battle.
  final List<int> scores;

  /// When the first battle of [scores] was played.
  final DateTime firstPlayedAt;

  /// The average the dashed line marks, over [averageCount] battles.
  final int average;
  final int averageCount;

  /// This battle's score above (or, below zero, under) [average].
  final int difference;
}

/// One thing to try in the next battle.
class ResultTip {
  const ResultTip({required this.title, required this.reason});

  /// e.g. "팔꿈치를 90°까지 굽혀 보세요".
  final String title;

  /// One line on why, e.g. "이번 판 평균 123° · 더 깊게 내려가면 Excellent +15".
  final String reason;
}

/// "개인 최고 기록 갱신" on lime with an ink edge: a lime trophy on an ink
/// disc, then the old best, the new one in bold, and the gain.
class ResultBestCard extends StatelessWidget {
  const ResultBestCard(this.best, {super.key});

  final ResultNewBest best;

  static const edge = 1.5;
  static const _discSize = 40.0;
  static const _trophySize = 20.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final line = text.reportLine.copyWith(color: AppColors.ink);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
        border: Border.all(color: AppColors.ink, width: edge),
      ),
      child: Row(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: _discSize,
              child: Icon(
                Icons.emoji_events_outlined,
                size: _trophySize,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '개인 최고 기록 갱신',
                  style: text.reportCardTitle.copyWith(color: AppColors.ink),
                ),
                Text.rich(
                  TextSpan(
                    text: '${best.previous}점 → ',
                    children: [
                      TextSpan(
                        text: '${best.current}점',
                        style: line.copyWith(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' · ${best.gain}점 올랐어요'),
                    ],
                  ),
                  style: line,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "최근 N판 중 이번 판": a bar per battle, this one in ink at the right,
/// the earlier ones gray, a dashed line at the average with its label, the
/// first battle's date under the left and this score under the right.
class ResultRecentCard extends StatelessWidget {
  const ResultRecentCard(this.recent, {super.key});

  final ResultRecent recent;

  /// Bars in the chart; with fewer battles the slots on the left stay
  /// empty, so this battle is always at the right.
  static const slots = 8;

  static const chartHeight = 96.0;

  /// The tallest bar, the highest score.
  static const barsHeight = 88.0;

  /// How far above the dashed line its label sits.
  static const _labelGap = AppSpacing.s4;

  /// Above this the label goes under the line, to stay in the chart.
  static const _labelBelowFrom = 60.0;

  /// How much of the lime shows behind a score above the average.
  static const _limeStrength = 0.6;

  /// The scores the chart draws, oldest first.
  List<int> get shown => recent.scores.length <= slots
      ? recent.scores
      : recent.scores.sublist(recent.scores.length - slots);

  /// [score]'s height in the chart: the highest score (or the average,
  /// when higher) is [barsHeight].
  double heightOf(num score) {
    final top = math.max(shown.fold(recent.average, math.max), 1);
    return (score / top * barsHeight).roundToDouble();
  }

  /// Whether this score is above the average: its chip is lime, else gray.
  bool get aboveAverage => recent.difference > 0;

  /// The average's chip: how far this score is above it or under it, or
  /// that it is the same.
  String get differenceText => switch (recent.difference) {
    0 => '평균과 같아요',
    > 0 => '평균보다 +${recent.difference}점',
    _ => '평균보다 ${recent.difference}점',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = this.shown;
    final small = text.labelSmall?.copyWith(fontWeight: FontWeight.w400);
    final lineAt = heightOf(recent.average);
    final date = recent.firstPlayedAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s16,
          AppSpacing.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '최근 ${shown.length}판 중 이번 판',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                DecoratedBox(
                  decoration: AppHighlight.chip(
                    aboveAverage ? AppColors.accent : AppColors.border,
                    strength: aboveAverage ? _limeStrength : 1,
                  ),
                  child: Padding(
                    padding: AppHighlight.chipPadding,
                    child: Text(
                      differenceText,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Semantics(
              container: true,
              label:
                  '최근 ${shown.length}판 점수 ${shown.join(', ')}, '
                  '최근 ${recent.averageCount}판 평균 ${recent.average}',
              child: ExcludeSemantics(
                child: SizedBox(
                  height: chartHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: lineAt,
                        child: const CustomPaint(
                          size: Size.fromHeight(ResultDashedLine.width),
                          painter: ResultDashedLine(),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var slot = 0; slot < slots; slot++) ...[
                              if (slot > 0)
                                const SizedBox(width: AppSpacing.s8),
                              Expanded(child: _barAt(slot, shown)),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        bottom: lineAt > _labelBelowFrom
                            ? null
                            : lineAt + _labelGap,
                        top: lineAt > _labelBelowFrom
                            ? chartHeight - lineAt + _labelGap
                            : null,
                        child: ColoredBox(
                          color: AppColors.card,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.s4,
                            ),
                            child: Text(
                              '최근 ${recent.averageCount}판 평균 '
                              '${recent.average}',
                              style: small?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${date.month}/${date.day}',
                  style: small?.copyWith(color: AppColors.textMuted),
                ),
                Text(
                  '이번 판 ${shown.last}',
                  style: small?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The bar in [slot], or nothing: the scores fill the slots from the
  /// right.
  Widget _barAt(int slot, List<int> shown) {
    final index = slot - (slots - shown.length);
    if (index < 0) return const SizedBox.shrink();
    final last = index == shown.length - 1;
    return Container(
      height: heightOf(shown[index]),
      decoration: BoxDecoration(
        color: last ? AppColors.ink : AppColors.inactive,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.bar),
          bottom: Radius.circular(AppRadius.mark),
        ),
      ),
    );
  }
}

/// The average's dashed line across the chart, in [AppColors.line].
class ResultDashedLine extends CustomPainter {
  const ResultDashedLine();

  static const width = 1.5;
  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = width;
    final y = width / 2;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + _dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ResultDashedLine oldDelegate) => false;
}

/// "다음 판 한 가지": the tip's title and reason, then 자세 피드백 전체
/// 보기. Without a tip only the link shows; without feedback only the tip.
class ResultTipCard extends StatelessWidget {
  const ResultTipCard({super.key, this.tip, this.onOpenFeedback})
    : assert(tip != null || onOpenFeedback != null);

  final ResultTip? tip;

  /// Null hides the link: the battle has no form feedback.
  final VoidCallback? onOpenFeedback;

  static const _markSize = 22.0;
  static const _targetSize = 15.0;
  static const _chevronSize = 16.0;
  static const _markStrength = 0.6;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tip = this.tip;
    final open = onOpenFeedback;
    // The link brings its own room above and below: it is a full tap
    // target tall.
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s16,
          tip == null ? 0 : AppSpacing.s12,
          AppSpacing.s16,
          open == null ? AppSpacing.s12 : 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tip != null) ...[
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: _markStrength),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadius.bar),
                      ),
                    ),
                    child: const SizedBox.square(
                      dimension: _markSize,
                      child: Icon(
                        Icons.track_changes_rounded,
                        size: _targetSize,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    '다음 판 한 가지',
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                tip.title,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                tip.reason,
                style: text.lobbyCardLine.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (open != null)
              TextButton.icon(
                onPressed: open,
                iconAlignment: IconAlignment.end,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  size: _chevronSize,
                ),
                label: const Text('자세 피드백 전체 보기'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, AppSpacing.s48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                  textStyle: text.reportLine.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
