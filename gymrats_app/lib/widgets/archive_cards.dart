import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/feedback_stats.dart';
import '../theme/app_theme.dart';
import 'archive_chart.dart';

/// A white card with a border, as the archive's cards are drawn (BArchive).
class ArchiveCard extends StatelessWidget {
  const ArchiveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
      border: Border.all(color: AppColors.border),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// "최근 7일": the reps and battles of the last 7 days, the streak chip
/// (hidden at 0 days), and a bar per day, oldest first, today in ink.
class ArchiveWeekCard extends StatelessWidget {
  const ArchiveWeekCard({super.key, required this.stats});

  final ArchiveStats stats;

  /// The bars' room, the least bar and a day without battles, as designed.
  static const barsHeight = 58.0;
  static const barMinHeight = 6.0;
  static const zeroBarHeight = 3.0;
  static const _barRadius = 6.0;
  static const _zeroRadius = 2.0;
  static const _chipHeight = 32.0;
  static const _flameSize = 16.0;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  /// The first of the 7 days in the card's name, e.g. "11/8".
  static String sinceLabel(DayReps day) => '${day.date.month}/${day.date.day}';

  /// The bar's letter under it: the weekday, "오늘" for the last one.
  static String dayLabel(DayReps day, {required bool isToday}) =>
      isToday ? '오늘' : _weekdays[day.date.weekday - 1];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final days = stats.weekDaily;
    final heights = archiveBarHeights(
      [for (final day in days) day.reps],
      max: barsHeight,
      min: barMinHeight,
      zero: zeroBarHeight,
    );
    String label(int i) => dayLabel(days[i], isToday: i == days.length - 1);
    return ArchiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "최근 7일 · 11/8 ~ 오늘": the last 7 days up to today,
                    // unlike the statistics' week from Monday (W7-STATS 6).
                    Text.rich(
                      TextSpan(
                        text: '최근 7일',
                        children: [
                          if (days.isNotEmpty)
                            TextSpan(
                              text: ' · ${sinceLabel(days.first)} ~ 오늘',
                              style: text.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: '${stats.weekReps}',
                        children: [
                          TextSpan(
                            text: '회',
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: '  · ${stats.weekMatches}판',
                            style: text.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      style: text.archiveTotal.copyWith(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              if (stats.streakDays > 0) ...[
                const SizedBox(width: AppSpacing.s12),
                _StreakChip(days: stats.streakDays),
              ],
            ],
          ),
          if (days.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            Semantics(
              label: [
                for (var i = 0; i < days.length; i++)
                  '${label(i)} ${days[i].reps}회',
              ].join(', '),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: barsHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < days.length; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Container(
                                key: ValueKey('archive-bar-$i'),
                                height: heights[i],
                                decoration: BoxDecoration(
                                  color: days[i].reps == 0
                                      ? AppColors.border
                                      : i == days.length - 1
                                      ? AppColors.ink
                                      : AppColors.chartBar,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(
                                      days[i].reps == 0
                                          ? _zeroRadius
                                          : _barRadius,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Row(
                      children: [
                        for (var i = 0; i < days.length; i++) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              label(i),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: i == days.length - 1
                                  ? text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    )
                                  : text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted,
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "8일 연속" in white on an ink pill, after a lime flame (palette B: light
/// text and a lime icon on a dark fill).
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: ArchiveWeekCard._chipHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      decoration: const ShapeDecoration(
        color: AppColors.ink,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: ArchiveWeekCard._flameSize,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.s4),
          Text(
            '$days일 연속',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.onInk),
          ),
        ],
      ),
    );
  }
}

/// "점수 성장": one exercise's scores as a line graph, picked with the
/// 푸쉬업 / 스쿼트 tabs, with the rise from the first score to the best and
/// the first battle's date under the graph. An exercise without a scored
/// battle shows a short line instead.
class ArchiveGrowthCard extends StatefulWidget {
  const ArchiveGrowthCard({super.key, required this.growth});

  /// Score history per exercise; a missing one counts as no scores.
  final Map<ExerciseType, ScoreGrowth> growth;

  /// The graph's height, as designed.
  static const chartHeight = 96.0;

  /// The first battle's date under the graph, e.g. "10/28".
  static String dateLabel(DateTime time) {
    final local = time.toLocal();
    return '${local.month}/${local.day}';
  }

  /// The line beside the rise, e.g. "첫 기록 80점 → 최고 240점"; only the
  /// first score when there is one.
  static String caption(ScoreGrowth growth) {
    final first = growth.firstScore!;
    return growth.scores.length == 1
        ? '첫 기록 $first점'
        : '첫 기록 $first점 → 최고 ${growth.bestScore}점';
  }

  /// What a screen reader says for the graph.
  static String graphLabel(ScoreGrowth growth) {
    final name = growth.exercise.koreanName;
    final first = growth.firstScore!;
    final best = growth.bestScore!;
    return best > first
        ? '$name 점수 그래프, 첫 기록 $first점에서 최고 $best점으로 올랐어요'
        : '$name 점수 그래프, 첫 기록 $first점, 최고 $best점';
  }

  @override
  State<ArchiveGrowthCard> createState() => _ArchiveGrowthCardState();
}

class _ArchiveGrowthCardState extends State<ArchiveGrowthCard> {
  var _exercise = ExerciseType.values.first;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final growth = widget.growth[_exercise];
    final hasScores = growth != null && growth.scores.isNotEmpty;
    return ArchiveCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s12,
            children: [
              Text('점수 성장', style: text.lobbyRowTitle),
              _ExerciseTabs(
                selected: _exercise,
                onSelect: (exercise) => setState(() => _exercise = exercise),
              ),
            ],
          ),
          if (hasScores)
            ..._graph(context, growth)
          else
            _NoScores(exercise: _exercise),
        ],
      ),
    );
  }

  List<Widget> _graph(BuildContext context, ScoreGrowth growth) {
    final text = Theme.of(context).textTheme;
    final rise = growth.bestScore! - growth.firstScore!;
    final firstPlayedAt = growth.firstPlayedAt;
    return [
      const SizedBox(height: AppSpacing.s4),
      Row(
        children: [
          if (rise > 0) ...[
            _RiseChip(rise: rise),
            const SizedBox(width: AppSpacing.s8),
          ],
          Flexible(
            child: Text(
              ArchiveGrowthCard.caption(growth),
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.s8),
      Semantics(
        image: true,
        label: ArchiveGrowthCard.graphLabel(growth),
        child: SizedBox(
          height: ArchiveGrowthCard.chartHeight,
          child: CustomPaint(
            key: const ValueKey('archive-growth-chart'),
            painter: ArchiveGrowthPainter(
              scores: growth.scores,
              valueStyle: text.archiveChartValue,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: _valueMaxScale),
            ),
            size: Size.infinite,
          ),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            firstPlayedAt == null
                ? ''
                : ArchiveGrowthCard.dateLabel(firstPlayedAt),
            style: text.labelSmall?.copyWith(color: AppColors.textMuted),
          ),
          Text(
            '오늘',
            style: text.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    ];
  }

  /// The value over the last point grows with the system text size only so
  /// far, so it stays inside the graph.
  static const _valueMaxScale = 1.5;
}

/// "↑ 160점" in ink on a lime band: how much the best beat the first score.
class _RiseChip extends StatelessWidget {
  const _RiseChip({required this.rise});

  final int rise;

  static const _radius = 10.0;
  static const _arrowSize = 18.0;
  static const _strength = 0.6;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$rise점 올랐어요',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: _strength),
            borderRadius: const BorderRadius.all(Radius.circular(_radius)),
          ),
          child: Padding(
            padding: AppHighlight.tightBandPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_upward_rounded,
                  size: _arrowSize,
                  color: AppColors.ink,
                ),
                Text.rich(
                  TextSpan(
                    text: '$rise',
                    children: [TextSpan(text: '점', style: text.archiveLabel)],
                  ),
                  style: text.archiveGain.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The short line for an exercise without a scored battle.
class _NoScores extends StatelessWidget {
  const _NoScores({required this.exercise});

  final ExerciseType exercise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: Column(
        children: [
          Text(
            '아직 점수 기록이 없어요',
            textAlign: TextAlign.center,
            style: text.lobbyRowTitle,
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            '${exercise.koreanName} 대결을 마치면 점수가 쌓여요.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 푸쉬업 | 스쿼트 on a pale track; the picked one is white on ink. Each tab
/// is drawn 40 high, as designed, and takes taps over 48.
class _ExerciseTabs extends StatelessWidget {
  const _ExerciseTabs({required this.selected, required this.onSelect});

  final ExerciseType selected;
  final ValueChanged<ExerciseType> onSelect;

  static const _trackHeight = 44.0;
  static const _tabHeight = 40.0;
  static const _inset = 2.0;
  static const _tabRadius = 10.0;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.archiveLabel;
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(
          child: Center(
            child: SizedBox(
              height: _trackHeight,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.facetLight,
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.small),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _inset),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, exercise) in ExerciseType.values.indexed) ...[
                if (index > 0) const SizedBox(width: _inset),
                TextButton(
                  onPressed: () => onSelect(exercise),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, _tabHeight),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                    ),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    backgroundColor: exercise == selected
                        ? AppColors.ink
                        : Colors.transparent,
                    foregroundColor: exercise == selected
                        ? AppColors.onInk
                        : AppColors.textSecondary,
                    textStyle: label,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(_tabRadius),
                      ),
                    ),
                  ),
                  // Inside the button, so its node says it is the picked one.
                  child: Semantics(
                    selected: exercise == selected,
                    child: Text(exercise.koreanName),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// In the cards' place when the summary failed while the list shows: one
/// line and "다시 시도".
class ArchiveStatsRetry extends StatelessWidget {
  const ArchiveStatsRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ArchiveCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              '최근 7일과 점수 성장을 불러오지 못했어요',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
