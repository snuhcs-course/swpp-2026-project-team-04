import 'package:flutter/material.dart';

import '../models/arcade_stage.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/feedback_stats.dart';
import '../models/hold_record.dart';
import '../models/reject_reason_korean.dart';
import '../theme/app_theme.dart';
import '../viewmodels/history_viewmodel.dart';
import 'archive_chart.dart';

/// A white card with a border, as the archive's cards were drawn (BArchive);
/// the statistics screen still uses it.
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

/// One full-width white section of the journal (P13, draft C), on the grey
/// page as the post-game report's sections are.
class ArchiveSection extends StatelessWidget {
  const ArchiveSection({
    super.key,
    required this.child,
    this.padding = defaultPadding,
  });

  static const defaultPadding = EdgeInsets.fromLTRB(
    AppSpacing.s20,
    AppSpacing.s20,
    AppSpacing.s20,
    AppSpacing.s16,
  );

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.card,
    child: Padding(padding: padding, child: child),
  );
}

/// A section's title, with a quiet [detail] or a [trailing] control at the
/// right end.
class ArchiveSectionTitle extends StatelessWidget {
  const ArchiveSectionTitle(
    this.title, {
    super.key,
    this.detail,
    this.trailing,
  });

  final String title;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = this.detail;
    final trailing = this.trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: text.lobbyCardTitle),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            child: Text(
              detail,
              textAlign: TextAlign.end,
              style: text.feedbackMeta,
            ),
          ),
        ],
        ?trailing,
      ],
    );
  }
}

/// The period's words: 이번 주, 이번 달, 전체 기간.
String archivePeriodLabel(StatsPeriod period) => switch (period) {
  StatsPeriod.week => '이번 주',
  StatsPeriod.month => '이번 달',
  StatsPeriod.all => '전체 기간',
};

/// 이번 주 · 이번 달 · 전체 기간 as a segmented control on a grey track, the
/// chosen one white and bold.
class ArchivePeriodPicker extends StatelessWidget {
  const ArchivePeriodPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final StatsPeriod value;
  final ValueChanged<StatsPeriod> onChanged;

  static const order = [StatsPeriod.week, StatsPeriod.month, StatsPeriod.all];
  static const _height = 44.0;
  static const _inset = AppSpacing.s4;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.facetLight,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: Row(
          children: [
            for (final period in order)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: period == value,
                  child: Material(
                    color: period == value
                        ? AppColors.card
                        : AppColors.facetLight,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.small),
                    ),
                    child: InkWell(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadius.small),
                      ),
                      onTap: () => onChanged(period),
                      child: SizedBox(
                        height: _height - 2 * _inset,
                        child: Center(
                          child: Text(
                            archivePeriodLabel(period),
                            maxLines: 1,
                            style: period == value
                                ? text.reportCardTitle
                                : text.feedbackMeta,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A row of pill chips, the chosen one in ink; it scrolls sideways when it
/// does not fit.
class ArchiveChips<T> extends StatelessWidget {
  const ArchiveChips({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    this.scrolls = true,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Whether the row scrolls sideways; off where it sits in another row.
  final bool scrolls;

  static const _height = 44.0;
  static const _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, value) in values.indexed) ...[
          if (index > 0) const SizedBox(width: AppSpacing.s8),
          Semantics(
            button: true,
            selected: value == selected,
            child: Material(
              color: value == selected ? AppColors.ink : AppColors.card,
              shape: StadiumBorder(
                side: value == selected
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.border, width: _edge),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(value),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _height),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        labelOf(value),
                        maxLines: 1,
                        style: text.archiveLabel.copyWith(
                          color: value == selected
                              ? AppColors.onInk
                              : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
    if (!scrolls) return row;
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
  }
}

/// A big number with its unit, and its name under it.
class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.unit, required this.name});

  final String value;
  final String unit;
  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$name $value$unit',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: text.statsIssueName),
                  if (unit.isNotEmpty)
                    TextSpan(text: ' $unit', style: text.archiveLabel),
                ],
              ),
              maxLines: 1,
            ),
            Text(name, style: text.feedbackMeta),
          ],
        ),
      ),
    );
  }
}

/// The period's battles, counted reps per battle and best score.
class ArchiveSummary extends StatelessWidget {
  const ArchiveSummary({super.key, required this.growth});

  final ArchiveGrowth growth;

  /// "5.5", or "6" when it is whole.
  static String perMatch(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final best = growth.bestScore;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Figure(value: '${growth.matches}', unit: '판', name: '경기'),
        ),
        Expanded(
          child: _Figure(
            value: perMatch(growth.repsPerMatch),
            unit: '회',
            name: '경기당 인정',
          ),
        ),
        Expanded(
          child: _Figure(
            value: best == null ? '–' : '$best',
            unit: best == null ? '' : '점',
            name: '최고 점수',
          ),
        ),
      ],
    );
  }
}

/// What the chart shows of each battle.
enum ArchiveMeasure {
  score('점수'),
  reps('인정 횟수');

  const ArchiveMeasure(this.label);

  final String label;
}

/// "경기별 점수": the period's battles in time, by score or by counted reps,
/// with their mean as a dashed line and the newest in green; the days under
/// it. Battles without a kept score are left out of the score view.
class ArchiveScoreChart extends StatefulWidget {
  const ArchiveScoreChart({super.key, required this.points});

  final List<ArchivePoint> points;

  static const height = 150.0;

  @override
  State<ArchiveScoreChart> createState() => _ArchiveScoreChartState();
}

class _ArchiveScoreChartState extends State<ArchiveScoreChart> {
  ArchiveMeasure _measure = ArchiveMeasure.score;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = [
      for (final p in widget.points)
        if (_measure == ArchiveMeasure.reps || p.score != null) p,
    ];
    final values = [
      for (final p in shown)
        _measure == ArchiveMeasure.score ? p.score! : p.reps,
    ];
    final unit = _measure == ArchiveMeasure.score ? '점' : '회';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveSectionTitle(
          '경기별 ${_measure.label}',
          trailing: ArchiveChips<ArchiveMeasure>(
            values: ArchiveMeasure.values,
            labelOf: (m) => m.label,
            selected: _measure,
            onSelected: (m) => setState(() => _measure = m),
            scrolls: false,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        if (values.isEmpty)
          Text('이 기간에 기록된 경기가 없어요.', style: text.feedbackMeta)
        else ...[
          Semantics(
            container: true,
            label:
                '경기별 ${_measure.label}: '
                '${[for (final v in values) '$v$unit'].join(', ')}',
            child: ExcludeSemantics(
              child: SizedBox(
                height: ArchiveScoreChart.height,
                child: CustomPaint(
                  painter: ArchiveTrendPainter(
                    values: values,
                    labelStyle: text.coachChipNumber,
                    meanStyle: text.statsAxis,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          ExcludeSemantics(
            child: Row(
              children: [
                for (final p in shown)
                  Expanded(
                    child: Text(
                      archiveDay(p.playedAt),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: text.statsAxis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// "11.23", in the phone's time.
String archiveDay(DateTime at) {
  final local = at.toLocal();
  return '${local.month}.${local.day.toString().padLeft(2, '0')}';
}

/// "개인 최고": each exercise's best score with its reps and day, on grey
/// tiles.
class ArchiveBests extends StatelessWidget {
  const ArchiveBests({super.key, required this.bests});

  final List<ArchiveBest> bests;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (bests.isEmpty) {
      return Text('점수가 기록된 경기가 아직 없어요.', style: text.feedbackMeta);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, best) in bests.indexed) ...[
          if (index > 0) const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.cardHigh,
                borderRadius: BorderRadius.all(
                  Radius.circular(AppRadius.small),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s12),
                child: Semantics(
                  container: true,
                  label:
                      '${best.exercise.koreanName} 최고 ${best.score}점, '
                      '인정 ${best.reps}회, ${archiveDay(best.playedAt)}',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          best.exercise.koreanName,
                          style: text.feedbackMeta,
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${best.score}',
                                style: text.statsIssueName,
                              ),
                              TextSpan(text: ' 점', style: text.archiveLabel),
                            ],
                          ),
                        ),
                        Text(
                          '인정 ${best.reps}회 · ${archiveDay(best.playedAt)}',
                          style: text.feedbackMeta,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "자주 나온 자세 문제": the period's reject reasons as warning bars against
/// the most frequent, most first.
class ArchiveIssues extends StatelessWidget {
  const ArchiveIssues({super.key, required this.issues});

  final List<ArchiveIssue> issues;

  static const _barHeight = 10.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (issues.isEmpty) {
      return Text('이 기간에 무효 처리된 횟수가 없어요.', style: text.feedbackMeta);
    }
    final most = issues.first.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, issue) in issues.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.s12),
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    issue.reason.koreanMessage,
                    maxLines: 2,
                    style: text.reportCardTitle,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.small),
                    ),
                    child: SizedBox(
                      height: _barHeight,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: ColoredBox(color: AppColors.facetLight),
                          ),
                          FractionallySizedBox(
                            widthFactor: issue.count / most,
                            heightFactor: 1,
                            child: const ColoredBox(color: AppColors.warning),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text('${issue.count}회', style: text.coachChipNumber),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// "버티기" on the 전체 tab (P13): the period's holds and time held, each
/// pose's longest hold, and a pose's time held in the period as a trend
/// (the pose picked by chips); one hold says there is nothing to compare.
class ArchiveHoldSummary extends StatefulWidget {
  const ArchiveHoldSummary({
    super.key,
    required this.holds,
    required this.period,
  });

  final ArchiveHolds holds;
  final StatsPeriod period;

  @override
  State<ArchiveHoldSummary> createState() => _ArchiveHoldSummaryState();

  /// "24.6초", or "1분 12초" from a minute.
  static String time(Duration d) {
    final tenths = (d.inMilliseconds / 100).round();
    if (tenths >= 600) {
      final seconds = (tenths / 10).round();
      return '${seconds ~/ 60}분 ${seconds % 60}초';
    }
    final value = tenths / 10;
    return value == value.roundToDouble()
        ? '${value.toStringAsFixed(0)}초'
        : '${value.toStringAsFixed(1)}초';
  }
}

class _ArchiveHoldSummaryState extends State<ArchiveHoldSummary> {
  HoldPose? _picked;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final holds = widget.holds;
    final period = widget.period;
    final time = ArchiveHoldSummary.time;
    final held = time(holds.held);
    // The picked pose, else the first with holds in the period.
    final poses = [
      for (final pose in HoldPose.values)
        if (holds.trends.containsKey(pose)) pose,
    ];
    final pose = poses.contains(_picked)
        ? _picked!
        : (poses.isEmpty ? null : poses.first);
    final trend = pose == null ? const <HoldRecord>[] : holds.trends[pose]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveSectionTitle('버티기', detail: archivePeriodLabel(period)),
        const SizedBox(height: AppSpacing.s12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Figure(value: '${holds.count}', unit: '회', name: '횟수'),
            ),
            Expanded(
              child: _Figure(value: held, unit: '', name: '버틴 시간'),
            ),
          ],
        ),
        if (holds.bests.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, best) in holds.bests.indexed) ...[
                if (index > 0) const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.cardHigh,
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.small),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      child: Semantics(
                        container: true,
                        label:
                            '${best.pose.label} 최고 ${time(best.held)}, '
                            '${archiveDay(best.endedAt)}',
                        child: ExcludeSemantics(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(best.pose.label, style: text.feedbackMeta),
                              Text(time(best.held), style: text.statsIssueName),
                              Text(
                                '최고 · ${archiveDay(best.endedAt)}',
                                style: text.feedbackMeta,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.s16),
        ArchiveSectionTitle(
          '자세별 버틴 시간',
          detail: pose == null ? null : '${trend.length}회',
        ),
        const SizedBox(height: AppSpacing.s12),
        if (poses.length > 1) ...[
          ArchiveChips<HoldPose>(
            values: poses,
            labelOf: (p) => p.label,
            selected: pose!,
            onSelected: (p) => setState(() => _picked = p),
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        if (pose == null)
          Text('이 기간에 기록된 버티기가 없어요.', style: text.feedbackMeta)
        else if (trend.length < 2)
          Text(
            '${pose.label} ${time(trend.single.held)} · 비교 기록 없음',
            style: text.feedbackMeta,
          )
        else ...[
          Semantics(
            container: true,
            label:
                '${pose.label} 버틴 시간: '
                '${[for (final h in trend) time(h.held)].join(', ')}',
            child: ExcludeSemantics(
              child: SizedBox(
                height: ArchiveScoreChart.height,
                child: CustomPaint(
                  painter: ArchiveTrendPainter(
                    values: [
                      for (final h in trend) h.held.inMilliseconds / 1000,
                    ],
                    labelStyle: text.coachChipNumber,
                    meanStyle: text.statsAxis,
                    format: _oneDecimal,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          ExcludeSemantics(
            child: Row(
              children: [
                for (final h in trend)
                  Expanded(
                    child: Text(
                      archiveDay(h.endedAt),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: text.statsAxis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _oneDecimal(num v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }
}

/// The exercise chips of the 전체 tab.
class ArchiveExerciseChips extends StatelessWidget {
  const ArchiveExerciseChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ExerciseType selected;
  final ValueChanged<ExerciseType> onSelected;

  @override
  Widget build(BuildContext context) => ArchiveChips<ExerciseType>(
    values: ExerciseType.values,
    labelOf: (e) => e.koreanName,
    selected: selected,
    onSelected: onSelected,
  );
}

/// In the 전체 tab's place when the battles of the period failed to load:
/// one line and "다시 시도".
class ArchiveStatsRetry extends StatelessWidget {
  const ArchiveStatsRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ArchiveSection(
      child: Row(
        children: [
          Expanded(child: Text('기간별 기록을 불러오지 못했어요', style: text.feedbackMeta)),
          const SizedBox(width: AppSpacing.s12),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
