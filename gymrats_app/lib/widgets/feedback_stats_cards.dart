import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/feedback_stats.dart';
import '../theme/app_theme.dart';
import 'archive_cards.dart';
import 'feedback_stats_chart.dart';
import 'feedback_stats_slots.dart';
import 'feedback_stats_words.dart';

/// The summary card (W7-STATS 2, 4): the period, the average counted reps,
/// the battles and the total, and the graph by date; a period without
/// battles shows a notice over the graph (or under the numbers for every
/// record).
class FeedbackStatsSummaryCard extends StatelessWidget {
  const FeedbackStatsSummaryCard({
    super.key,
    required this.period,
    required this.exercise,
    required this.stats,
    required this.now,
  });

  final StatsPeriod period;
  final ExerciseType? exercise;
  final PeriodStats stats;

  /// The view model's clock, for today's slot.
  final DateTime now;

  /// From the numbers to the graph (W7A 14, on the 12 step).
  static const chartTop = AppSpacing.s12;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final chart = StatsChart.of(stats, now);
    final empty = stats.matches == 0;
    return ArchiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: FeedbackStatsWords.summaryLabel(period, stats, now),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    FeedbackStatsWords.range(period, stats, now),
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  _Numbers(stats: stats),
                ],
              ),
            ),
          ),
          if (!chart.isEmpty) ...[
            const SizedBox(height: chartTop),
            FeedbackStatsChart(
              chart: chart,
              semanticsLabel: FeedbackStatsWords.chartLabel(period, chart),
              notice: empty
                  ? _EmptyNotice(
                      period: period,
                      exercise: exercise,
                      overPlot: true,
                    )
                  : null,
            ),
          ],
          if (chart.kind == StatsChartKind.week) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              FeedbackStatsWords.weeksNote,
              style: text.statsNote.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (empty && chart.isEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            _EmptyNotice(period: period, exercise: exercise, overPlot: false),
          ],
        ],
      ),
    );
  }
}

/// The average on the left; the battles and the total on the right, their
/// bottoms a step above the average's (W7A 3, on the 4 step). With large
/// text the right pair may go under the average.
class _Numbers extends StatelessWidget {
  const _Numbers({required this.stats});

  final PeriodStats stats;

  static const _cellsLift = AppSpacing.s4;
  static const _cellGap = AppSpacing.s16;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = text.bodySmall?.copyWith(color: AppColors.textMuted);
    final unit = text.bodySmall?.copyWith(fontWeight: FontWeight.w700);
    Widget cell(String name, int value, String unitText) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: label),
        Text.rich(
          TextSpan(
            text: '$value',
            children: [TextSpan(text: unitText, style: unit)],
          ),
          style: text.statsCount.copyWith(color: AppColors.ink),
        ),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('경기당 평균 인정', style: label),
            const SizedBox(height: AppSpacing.s4),
            Text.rich(
              TextSpan(
                text: FeedbackStatsWords.average(stats),
                children: [
                  if (stats.matches > 0)
                    TextSpan(text: '회', style: text.statsStrong),
                ],
              ),
              style: text.statsAverage.copyWith(color: AppColors.ink),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: _cellsLift),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              cell('경기', stats.matches, '판'),
              const SizedBox(width: _cellGap),
              cell('총 인정', stats.totalReps, '회'),
            ],
          ),
        ),
      ],
    );
  }
}

/// "이번 주에는 아직 경기가 없어요" and its second line, on a pale panel,
/// told to a screen reader when it shows.
class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({
    required this.period,
    required this.exercise,
    required this.overPlot,
  });

  final StatsPeriod period;
  final ExerciseType? exercise;

  /// Over the graph's plot (this week, this month), or under the numbers.
  final bool overPlot;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const ValueKey('feedback-stats-empty'),
        padding: overPlot
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              )
            : const EdgeInsets.all(AppSpacing.s12),
        decoration: const BoxDecoration(
          color: AppColors.cardHigh,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: overPlot ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Text(
              FeedbackStatsWords.emptyTitle(period, exercise),
              style: text.lobbyRowTitle,
            ),
            Text(
              FeedbackStatsWords.emptyDetail(period),
              style: text.statsDetail.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The form-issue card (W7-STATS 2, 4): "거절된 이유" (reps not counted)
/// and "자세 리포트" (battles with the issue), five rows each until
/// "나머지 N개 더 보기" opens the rest. Give it a key per period and
/// exercise, so a change closes them again.
class FeedbackStatsIssuesCard extends StatefulWidget {
  const FeedbackStatsIssuesCard({super.key, required this.stats});

  final PeriodStats stats;

  @override
  State<FeedbackStatsIssuesCard> createState() =>
      _FeedbackStatsIssuesCardState();
}

class _FeedbackStatsIssuesCardState extends State<FeedbackStatsIssuesCard> {
  final _open = <StatsIssueGroup>{};

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stats = widget.stats;
    final base = FeedbackStatsWords.base(stats);
    final blank = FeedbackStatsWords.blank(stats);
    // Its header line names it; each row is read as one line.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: ArchiveCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('자세 문제', style: text.lobbyRowTitle),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    base ?? '',
                    textAlign: TextAlign.end,
                    style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            if (blank != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                blank,
                style: text.statsSentence.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.s12),
              _group(
                StatsIssueGroup.rejected,
                FeedbackStatsWords.rejectedRows(stats),
              ),
              const SizedBox(height: AppSpacing.s16),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.background,
              ),
              const SizedBox(height: AppSpacing.s12),
              _group(
                StatsIssueGroup.report,
                FeedbackStatsWords.reportRows(stats),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _group(StatsIssueGroup group, List<StatsIssueRow> rows) {
    final rejected = group == StatsIssueGroup.rejected;
    final open = _open.contains(group);
    final shown = open ? rows : rows.take(FeedbackStatsWords.cut).toList();
    final hidden = rows.length - FeedbackStatsWords.cut;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeader(rejected: rejected),
        const SizedBox(height: AppSpacing.s8),
        for (final (i, row) in shown.indexed) ...[
          if (i > 0) const SizedBox(height: _IssueRow.gap),
          _IssueRow(row: row),
        ],
        if (rows.isEmpty)
          Text(
            rejected ? '이 기간에 거절된 횟수가 없어요.' : '자세 리포트에 나온 문제가 없어요.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        if (hidden > 0) ...[
          const SizedBox(height: _IssueRow.gap),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => open ? _open.remove(group) : _open.add(group)),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, _moreHeight),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.textSecondary,
                textStyle: text.archiveLabel,
              ),
              // Inside the button, so its node says open or closed.
              child: Semantics(
                expanded: open,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(FeedbackStatsWords.moreLabel(hidden, open: open)),
                    Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: _chevronSize,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static const _moreHeight = 44.0;
  static const _chevronSize = 16.0;
}

/// A group's swatch and name on the left, its unit on the right.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.rejected});

  final bool rejected;

  static const _swatchEdge = 1.5;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: AppHighlight.swatchSize,
          height: AppHighlight.swatchSize,
          decoration: BoxDecoration(
            color: rejected ? AppColors.warning : AppColors.card,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.mark),
            ),
            border: Border.all(color: AppColors.ink, width: _swatchEdge),
          ),
        ),
        const SizedBox(width: AppHighlight.swatchGap),
        Text(
          rejected ? '거절된 이유' : '자세 리포트',
          style: text.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            rejected ? '카운트되지 않은 횟수' : '이 문제가 나온 경기 수',
            textAlign: TextAlign.end,
            style: text.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// A form issue's name, its count and its bar, read as one line.
class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.row});

  final StatsIssueRow row;

  /// Between rows (W7A 10, on the 8 step).
  static const gap = AppSpacing.s8;
  static const _barHeight = 8.0;
  static const _barRadius = 4.0;
  static const _barEdge = 1.5;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall;
    final rejected = row.group == StatsIssueGroup.rejected;
    const radius = BorderRadius.all(Radius.circular(_barRadius));
    final bar = FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: row.widthPct / 100,
      child: Container(
        height: _barHeight,
        decoration: BoxDecoration(
          color: rejected ? AppColors.warning : AppColors.card,
          borderRadius: radius,
          border: Border.all(color: AppColors.ink, width: _barEdge),
        ),
      ),
    );
    return Semantics(
      container: true,
      label: FeedbackStatsWords.rowLabel(row),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.statsIssueName,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text.rich(
                  TextSpan(
                    text: '${row.count}',
                    children: [
                      TextSpan(
                        text: rejected ? '회' : '판',
                        style: small?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (!rejected)
                        TextSpan(
                          text: ' / ${row.of}',
                          style: small?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  style: text.statsIssueCount.copyWith(color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            if (rejected)
              SizedBox(height: _barHeight, child: bar)
            else
              Container(
                height: _barHeight,
                decoration: const BoxDecoration(
                  color: AppColors.facetLight,
                  borderRadius: radius,
                ),
                child: bar,
              ),
          ],
        ),
      ),
    );
  }
}

/// The two placeholder cards while the battles load (W7-STATS 5): the
/// period's words, "불러오는 중" with a turning ring (still with reduced
/// motion), gray boxes for the numbers, [period]'s slots as gray bars,
/// and four gray rows for the form issues. Only "통계를 불러오는 중" is
/// read, once.
class FeedbackStatsLoadingCards extends StatelessWidget {
  const FeedbackStatsLoadingCards({
    super.key,
    required this.period,
    required this.now,
  });

  final StatsPeriod period;
  final DateTime now;

  static const _ring = 14.0;
  static const _ringStroke = 2.0;
  static const _rows = [(0.58, 0.92), (0.46, 0.64), (0.62, 0.48), (0.40, 0.30)];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final still = MediaQuery.disableAnimationsOf(context);
    final quiet = text.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        FeedbackStatsWords.range(period, null, now),
                        style: quiet,
                      ),
                    ),
                  ),
                  Semantics(
                    liveRegion: true,
                    label: '통계를 불러오는 중',
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: _ring,
                            child: CircularProgressIndicator(
                              key: const ValueKey('feedback-stats-ring'),
                              strokeWidth: _ringStroke,
                              color: AppColors.ink,
                              backgroundColor: AppColors.border,
                              value: still ? 0.25 : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Text('불러오는 중', style: quiet),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              const ExcludeSemantics(child: _SkeletonNumbers()),
              const SizedBox(height: FeedbackStatsSummaryCard.chartTop),
              FeedbackStatsChart(chart: StatsChart.skeleton(period, now)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        ExcludeSemantics(
          child: ArchiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '자세 문제',
                  style: text.lobbyRowTitle.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                for (final (label, bar) in _rows) ...[
                  const SizedBox(height: AppSpacing.s12),
                  FractionallySizedBox(
                    widthFactor: label,
                    child: const _SkeletonBox(_SkeletonBox.nameLine),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  FractionallySizedBox(
                    widthFactor: bar,
                    child: const _SkeletonBox(_SkeletonBox.issueBar),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The gray boxes where the numbers go.
class _SkeletonNumbers extends StatelessWidget {
  const _SkeletonNumbers();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(_SkeletonBox.averageName),
              SizedBox(height: AppSpacing.s8),
              _SkeletonBox(_SkeletonBox.average),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.s12),
        Padding(
          padding: EdgeInsets.only(bottom: _Numbers._cellsLift),
          child: Row(
            children: [
              _SkeletonBox(_SkeletonBox.matches),
              SizedBox(width: _Numbers._cellGap),
              _SkeletonBox(_SkeletonBox.total),
            ],
          ),
        ),
      ],
    );
  }
}

/// A still gray box of the placeholder, of one of the sizes W7-STATS 5
/// gives: (width, height, corner); a null width fills its parent.
class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox(this.shape);

  final (double?, double, double) shape;

  static const averageName = (88.0, 12.0, 6.0);
  static const average = (104.0, 36.0, 10.0);
  static const matches = (40.0, 34.0, 8.0);
  static const total = (52.0, 34.0, 8.0);
  static const nameLine = (null, 12.0, 6.0);
  static const issueBar = (null, 8.0, 4.0);

  @override
  Widget build(BuildContext context) {
    final (width, height, corner) = shape;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.facetLight,
        borderRadius: BorderRadius.all(Radius.circular(corner)),
      ),
    );
  }
}

/// In the cards' place when the battles failed to load (W7-STATS 5): a
/// "!" circle, the reason, "다시 시도" (the view model's `load`) and a
/// line that the choices stay; told to a screen reader when it shows.
class FeedbackStatsFailedCard extends StatelessWidget {
  const FeedbackStatsFailedCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  /// W7A's 28 / 20 / 24, on the steps.
  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.s20,
    AppSpacing.s24,
    AppSpacing.s20,
    AppSpacing.s24,
  );
  static const _mark = 44.0;
  static const _markEdge = 2.0;
  static const _buttonHeight = 48.0;
  static const _buttonRadius = 14.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: ArchiveCard(
        padding: _padding,
        child: Column(
          children: [
            ExcludeSemantics(
              child: Container(
                width: _mark,
                height: _mark,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: _markEdge),
                ),
                child: Text(
                  '!',
                  style: text.statsMark.copyWith(color: AppColors.ink),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              '통계를 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.statsSentence.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.onInk,
                minimumSize: const Size(0, _buttonHeight),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                textStyle: text.statsStrong,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(_buttonRadius),
                  ),
                ),
              ),
              child: const Text('다시 시도'),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              '고른 기간과 종목은 그대로 남아요.',
              textAlign: TextAlign.center,
              style: text.statsNote.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
