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
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.lobbyCardTitle,
            ),
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
                  TextSpan(text: value, style: text.feedbackStat),
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
  const ArchiveSummary({super.key, required this.growth, this.holds = 0});

  final ArchiveGrowth growth;

  /// The period's holds, shown for 전체 in the best score's place.
  final int holds;

  /// "푸쉬업 3판 · 스쿼트 1판 · 버티기 2회".
  static String split(ArchiveGrowth growth, int holds) => [
    for (final MapEntry(:key, :value) in growth.perExercise.entries)
      '${key.koreanName} $value판',
    '버티기 $holds회',
  ].join(' · ');

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
    final every = growth.exercise == null;
    final figures = Row(
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
          child: every
              ? _Figure(value: '$holds', unit: '회', name: '버티기')
              : _Figure(
                  value: best == null ? '–' : '$best',
                  unit: best == null ? '' : '점',
                  name: '최고 점수',
                ),
        ),
      ],
    );
    if (!every) return figures;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        figures,
        const SizedBox(height: AppSpacing.s8),
        Text(
          split(growth, holds),
          style: Theme.of(context).textTheme.feedbackMeta,
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

/// A battle's dot on 전체's chart: push-ups in green, squats in ink.
Color exerciseColor(ExerciseType exercise) => switch (exercise) {
  ExerciseType.pushUp => AppColors.statusGood,
  ExerciseType.squat => AppColors.ink,
};

class _ArchiveScoreChartState extends State<ArchiveScoreChart> {
  ArchiveMeasure _measure = ArchiveMeasure.score;

  static const _legendDot = 10.0;

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
    final mixed = shown.map((p) => p.exercise).toSet().length > 1;
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
                    colors: mixed
                        ? [for (final p in shown) exerciseColor(p.exercise)]
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          if (mixed) ...[
            ExcludeSemantics(
              child: Wrap(
                spacing: AppSpacing.s12,
                children: [
                  for (final e in ExerciseType.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: _legendDot,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: exerciseColor(e),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text(e.koreanName, style: text.feedbackMeta),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
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

/// "24.6초", or "1분 12초" from a minute: a hold's time.
String archiveHoldTime(Duration d) {
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

/// "개인 최고": each exercise's best score with its reps and day, and each
/// hold pose's longest hold with its day, on grey tiles two to a row.
class ArchiveBests extends StatelessWidget {
  const ArchiveBests({super.key, this.bests = const [], this.holds = const []});

  final List<ArchiveBest> bests;

  /// Each pose's longest hold.
  final List<HoldRecord> holds;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tiles = <({String name, String value, String unit, String line})>[
      for (final b in bests)
        (
          name: b.exercise.koreanName,
          value: '${b.score}',
          unit: '점',
          line: '인정 ${b.reps}회 · ${archiveDay(b.playedAt)}',
        ),
      for (final h in holds)
        (
          name: h.pose.label,
          value: archiveHoldTime(h.held),
          unit: '',
          line: '버티기 · ${archiveDay(h.endedAt)}',
        ),
    ];
    if (tiles.isEmpty) {
      return Text('기록된 최고 기록이 아직 없어요.', style: text.feedbackMeta);
    }
    Widget tile(({String name, String value, String unit, String line}) t) =>
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.cardHigh,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Semantics(
              container: true,
              label: '${t.name} 최고 ${t.value}${t.unit}, ${t.line}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, style: text.feedbackMeta),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: t.value, style: text.feedbackStat),
                          if (t.unit.isNotEmpty)
                            TextSpan(
                              text: ' ${t.unit}',
                              style: text.archiveLabel,
                            ),
                        ],
                      ),
                    ),
                    Text(t.line, style: text.feedbackMeta),
                  ],
                ),
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(tiles[i])),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tile(tiles[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
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

/// 버티기's summary on the 전체 tab, as an exercise's (user, 2026-11-26):
/// holds, time held and the longest hold of the period.
class ArchiveHoldFigures extends StatelessWidget {
  const ArchiveHoldFigures({super.key, required this.holds});

  final ArchiveHolds holds;

  @override
  Widget build(BuildContext context) {
    final best = holds.bestHeld;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Figure(value: '${holds.count}', unit: '회', name: '횟수'),
        ),
        Expanded(
          child: _Figure(
            value: archiveHoldTime(holds.held),
            unit: '',
            name: '버틴 시간',
          ),
        ),
        Expanded(
          child: _Figure(
            value: best == null ? '–' : archiveHoldTime(best),
            unit: '',
            name: '최고 버틴 시간',
          ),
        ),
      ],
    );
  }
}

/// A hold's dot: a high plank in green, a chair pose in ink.
Color holdPoseColor(HoldPose pose) => switch (pose) {
  HoldPose.plank => AppColors.statusGood,
  HoldPose.chair => AppColors.ink,
};

/// "경기별 버틴 시간": the period's holds in time, as 경기별 점수 is for the
/// battles; the poses told apart by colour when both are there.
class ArchiveHoldChart extends StatelessWidget {
  const ArchiveHoldChart({super.key, required this.holds});

  /// Oldest first.
  final List<HoldRecord> holds;

  static const _legendDot = 10.0;

  static String _oneDecimal(num v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mixed = holds.map((h) => h.pose).toSet().length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ArchiveSectionTitle('경기별 버틴 시간'),
        const SizedBox(height: AppSpacing.s12),
        if (holds.isEmpty)
          Text('이 기간에 기록된 버티기가 없어요.', style: text.feedbackMeta)
        else ...[
          Semantics(
            container: true,
            label:
                '경기별 버틴 시간: '
                '${[for (final h in holds) archiveHoldTime(h.held)].join(', ')}',
            child: ExcludeSemantics(
              child: SizedBox(
                height: ArchiveScoreChart.height,
                child: CustomPaint(
                  painter: ArchiveTrendPainter(
                    values: [
                      for (final h in holds) h.held.inMilliseconds / 1000,
                    ],
                    labelStyle: text.coachChipNumber,
                    meanStyle: text.statsAxis,
                    format: _oneDecimal,
                    colors: mixed
                        ? [for (final h in holds) holdPoseColor(h.pose)]
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          if (mixed) ...[
            ExcludeSemantics(
              child: Wrap(
                spacing: AppSpacing.s12,
                children: [
                  for (final pose in HoldPose.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: _legendDot,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: holdPoseColor(pose),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text(pose.label, style: text.feedbackMeta),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          ExcludeSemantics(
            child: Row(
              children: [
                for (final h in holds)
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
}

/// "이번 주 운동량" on the 전체 tab (P13, draft C): estimated calories,
/// lifted weight and the mean endurance index of the period's battles kept
/// on this phone, each against the period before with two bars (this one in
/// green, the one before in grey); 전체 기간 has no period before.
class ArchiveVolumeSection extends StatelessWidget {
  const ArchiveVolumeSection({
    super.key,
    required this.volume,
    required this.period,
    this.holdsOnly = false,
  });

  final ArchiveVolume volume;
  final StatsPeriod period;

  /// 버티기: calories only; a hold lifts no weight and has no rep-based
  /// endurance.
  final bool holdsOnly;

  /// "지난 주", "지난 달".
  static String previousLabel(StatsPeriod period) => switch (period) {
    StatsPeriod.week => '지난 주',
    StatsPeriod.month => '지난 달',
    StatsPeriod.all => '',
  };

  /// "750 kg", or "4.2 t" from a tonne.
  static (String, String) weight(double kg) =>
      kg >= 1000 ? (_oneDecimal(kg / 1000), 't') : ('${kg.round()}', 'kg');

  static String _oneDecimal(num v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = volume.current;
    final before = volume.previous;
    final (lifted, liftedUnit) = weight(now.liftedKg);
    final weightNote = volume.weightAssumed
        ? '${volume.weightKg.round()} kg 기준 추정'
        : '체중 ${_oneDecimal(volume.weightKg)} kg 기준 추정';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveSectionTitle(
          '${archivePeriodLabel(period)} 운동량',
          trailing: before == null
              ? null
              : _Legend(
                  now: archivePeriodLabel(period),
                  before: previousLabel(period),
                ),
        ),
        if (now.battles == 0 && now.holds == 0) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(
            holdsOnly ? '이 기간에 버티기 기록이 없어요.' : '이 기간에 이 폰에 남은 기록이 없어요.',
            style: text.feedbackMeta,
          ),
        ] else ...[
          _VolumeRow(
            name: '예상 소모 칼로리',
            value: _oneDecimal(now.kcal),
            unit: 'kcal',
            now: now.kcal,
            before: before?.kcal,
            change: before == null ? null : _oneDecimal(now.kcal - before.kcal),
            note: !holdsOnly && now.holds > 0 ? '버티기 ${now.holds}회 포함' : null,
          ),
        ],
        if (!holdsOnly && (now.battles > 0 || now.holds > 0)) ...[
          const Divider(height: 1, color: AppColors.facetLight),
          _VolumeRow(
            name: '들어 올린 무게',
            value: lifted,
            unit: liftedUnit,
            now: now.liftedKg,
            before: before?.liftedKg,
            change: before == null
                ? null
                : () {
                    final (v, u) = weight(
                      (now.liftedKg - before.liftedKg).abs(),
                    );
                    return '$v $u';
                  }(),
            down: before != null && now.liftedKg < before.liftedKg,
          ),
        ],
        // A hold lifts nothing but has an endurance index too (user,
        // 2026-11-26).
        if (now.battles > 0 || now.holds > 0) ...[
          const Divider(height: 1, color: AppColors.facetLight),
          _VolumeRow(
            name: '근지구력 지수',
            value: now.endurance == null ? '–' : '${now.endurance!.round()}',
            unit: '',
            now: now.endurance ?? 0,
            before: before?.endurance,
            change: now.endurance != null && before?.endurance != null
                ? '${(now.endurance! - before!.endurance!).round()}'
                : null,
            note: now.endurance == null
                ? '비교 기록 없음'
                : holdsOnly
                ? '기록마다 같은 자세 최근 평균 = 100 (첫 기록은 목표 시간)'
                : '기록마다 최근 평균 = 100',
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
        Text('이 폰에 남은 기록 기준 · $weightNote', style: text.feedbackMeta),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.now, required this.before});

  final String now;
  final String before;

  static const _box = 10.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.feedbackMeta;
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: _box,
          child: ColoredBox(color: color),
        ),
        const SizedBox(width: AppSpacing.s4),
        Text(label, style: style),
      ],
    );
    return ExcludeSemantics(
      child: Wrap(
        spacing: AppSpacing.s8,
        children: [
          item(AppColors.statusGood, now),
          item(AppColors.inactive, before),
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.name,
    required this.value,
    required this.unit,
    required this.now,
    this.before,
    this.change,
    this.down,
    this.note,
  });

  final String name;
  final String value;
  final String unit;
  final double now;
  final double? before;

  /// The change's words without its sign; null without a period before.
  final String? change;

  /// Whether the change is down; by default when [change] starts with "-".
  final bool? down;
  final String? note;

  static const _bar = 12.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final before = this.before;
    final change = this.change;
    final note = this.note;
    final isDown = down ?? (change?.startsWith('-') ?? false);
    final shown = change?.replaceFirst('-', '');
    final most = [now, ?before, 1e-9].reduce((a, b) => a > b ? a : b);
    Widget bar(double value, Color color) => ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
      child: SizedBox(
        height: _bar,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: (value / most).clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Semantics(
              container: true,
              label: [
                '$name $value$unit',
                if (shown != null) '${isDown ? '감소' : '증가'} $shown',
                ?note,
              ].join(', '),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.feedbackMeta),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: value, style: text.feedbackStat),
                          if (unit.isNotEmpty)
                            TextSpan(text: ' $unit', style: text.archiveLabel),
                        ],
                      ),
                    ),
                    if (shown != null)
                      Text(
                        '${isDown ? '-' : '+'}$shown',
                        style: text.coachChipNumber,
                      ),
                    if (note != null) Text(note, style: text.feedbackMeta),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            flex: 6,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  bar(now, AppColors.statusGood),
                  if (before != null) ...[
                    const SizedBox(height: AppSpacing.s4),
                    bar(before, AppColors.inactive),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 전체 · 푸쉬업 · 스쿼트 · 버티기 on the 전체 tab (user, 2026-11-26).
class ArchiveScopeChips extends StatelessWidget {
  const ArchiveScopeChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ArchiveScope selected;
  final ValueChanged<ArchiveScope> onSelected;

  @override
  Widget build(BuildContext context) => ArchiveChips<ArchiveScope>(
    values: ArchiveScope.values,
    labelOf: (s) => s.label,
    selected: selected,
    onSelected: onSelected,
  );
}

/// "자주 받은 경고" for 버티기: the period's warnings, most first, as bars.
class ArchiveHoldWarnings extends StatelessWidget {
  const ArchiveHoldWarnings({super.key, required this.warnings});

  final List<({String words, int count})> warnings;

  static const _barHeight = 10.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (warnings.isEmpty) {
      return Text('이 기간에 받은 경고가 없어요.', style: text.feedbackMeta);
    }
    final most = warnings.first.count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, w) in warnings.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.s12),
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(w.words, style: text.reportCardTitle),
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
                            widthFactor: w.count / most,
                            heightFactor: 1,
                            child: const ColoredBox(color: AppColors.warning),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text('${w.count}회', style: text.coachChipNumber),
              ],
            ),
          ),
        ],
      ],
    );
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
