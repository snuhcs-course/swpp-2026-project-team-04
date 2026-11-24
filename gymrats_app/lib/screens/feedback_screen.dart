// AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/form_report.dart';
import '../models/reject_reason_korean.dart';
import '../models/rep_event.dart';
import '../services/feedback/form_analyzer.dart';
import '../services/feedback/form_report_store.dart';
import '../services/feedback/report_metrics.dart';
import '../theme/app_theme.dart';
import '../viewmodels/feedback_viewmodel.dart';
import '../widgets/feedback_charts.dart';
import '../widgets/feedback_parts.dart';
import '../widgets/form_fault_clip.dart';

/// The post-game report of one battle (P14, design D-3): the form score, the
/// five-axis form analysis against the recent battles, the estimated
/// calories, lifted weight and endurance, the highlights, the trend and the
/// coach's line. 자세 분석 자세히 보기 opens the evidence ([FeedbackDetailScreen]).
///
/// It draws what [FeedbackViewModel] made of [report] and only words it.
/// Opened with only a report (the result screen's route), it makes that view
/// model itself and reads the recent battles kept on the phone, when the app
/// provides the store. Back returns to where it was opened.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.report,
    this.form,
    this.metrics,
    this.history,
    this.analyzer = const FormAnalyzer(),
  });

  final FormReport report;

  /// What the view model that loaded [report] made of it; with [metrics],
  /// both null to make that view model here from [report] with [analyzer].
  final FormFeedback? form;

  /// The report's numbers and the comparison, from the same view model.
  final ReportMetrics? metrics;
  final ReportHistory? history;

  /// The rules the screen's own view model uses when [form] is null.
  final FormAnalyzer analyzer;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  FeedbackViewModel? _own;

  FeedbackViewModel get _model {
    final own = _own;
    if (own != null) return own;
    FormReportStore? store;
    try {
      store = context.read<FormReportStore>();
    } on ProviderNotFoundException {
      store = null;
    }
    final made = FeedbackViewModel.fromReport(
      widget.report,
      analyzer: widget.analyzer,
      phoneReports: store,
    )..addListener(_changed);
    made.load();
    return _own = made;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(FeedbackScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report != widget.report ||
        oldWidget.analyzer != widget.analyzer) {
      _own?.dispose();
      _own = null;
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final given = widget.form, givenMetrics = widget.metrics;
    final FormFeedback form;
    final ReportMetrics metrics;
    final ReportHistory history;
    if (given != null && givenMetrics != null) {
      form = given;
      metrics = givenMetrics;
      history = widget.history ?? ReportHistory.none;
    } else {
      final state = _model.state;
      form = state.form!;
      metrics = state.metrics!;
      history = state.history;
    }
    final report = widget.report;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.s24),
          children: [
            const _Header(title: 'REPORT', number: true),
            _ScoreSection(report: report, metrics: metrics, history: history),
            _gap,
            _FormSection(report: report, metrics: metrics, history: history),
            _gap,
            _ExerciseSection(metrics: metrics, history: history),
            ..._highlights(metrics, history),
            if (history.trend.length >= 2) ...[
              _gap,
              _TrendSection(history: history),
            ],
            _gap,
            _CoachSection(
              line: form.coachLine,
              onDetail: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => FeedbackDetailScreen(
                    report: report,
                    form: form,
                    metrics: metrics,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _highlights(ReportMetrics metrics, ReportHistory history) {
    final lines = history.highlights(metrics);
    if (lines.isEmpty) return const [];
    return [_gap, _HighlightSection(lines: lines)];
  }
}

const _gap = SizedBox(height: AppSpacing.s8);

/// A white band the width of the screen: every part of the report is one.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.padding = _padding});

  static const _padding = EdgeInsets.fromLTRB(
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = this.detail;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
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
      ],
    );
  }
}

/// Back, and the screen's name.
class _Header extends StatelessWidget {
  const _Header({required this.title, this.number = false, this.trailing});

  final String title;

  /// Whether [title] is set in the number font, as "REPORT" is.
  final bool number;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trailing = this.trailing;
    return ColoredBox(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
        child: Row(
          children: [
            IconButton(
              tooltip: '뒤로',
              onPressed: () => Navigator.maybePop(context),
              color: AppColors.textPrimary,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                title,
                style: number ? text.feedbackTag : text.reportCardTitle,
              ),
            ),
            if (trailing != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s12),
                  child: Text(
                    trailing,
                    textAlign: TextAlign.end,
                    style: text.feedbackMeta,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "26.11.23(월) 14:30".
String reportDate(DateTime time) {
  final t = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  return '${two(t.year % 100)}.${two(t.month)}.${two(t.day)}'
      '(${days[t.weekday - 1]}) ${two(t.hour)}:${two(t.minute)}';
}

/// A small signed number on a tint: lime-tinted when it went up.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip(this.value, {this.decimals = 0});

  final double value;
  final int decimals;

  static String format(double value, int decimals) {
    final rounded = value.toStringAsFixed(decimals);
    if (double.parse(rounded) == 0) return (0.0).toStringAsFixed(decimals);
    return value > 0 ? '+$rounded' : '−${rounded.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final up = double.parse(value.toStringAsFixed(decimals)) > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: up ? AppColors.selectedFill : AppColors.cardHigh,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        child: Text(format(value, decimals), style: text.coachChipNumber),
      ),
    );
  }
}

/// The date, then the form score with its change against the recent mean.
class _ScoreSection extends StatelessWidget {
  const _ScoreSection({
    required this.report,
    required this.metrics,
    required this.history,
  });

  final FormReport report;
  final ReportMetrics metrics;
  final ReportHistory history;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final score = metrics.score;
    final change = history.scoreChange(metrics);
    final seconds = report.roundLength.inSeconds;
    return ColoredBox(
      color: AppColors.card,
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
            child: Text(reportDate(report.endedAt), style: text.archiveLabel),
          ),
          const Divider(height: 1, color: AppColors.cardHigh),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s20,
              AppSpacing.s20,
              AppSpacing.s20,
              AppSpacing.s20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('자세 점수', style: text.reportCardTitle),
                          if (change != null) _DeltaChip(change),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        '${report.exercise.koreanName} · '
                        'vs ${report.opponentName} · $seconds초',
                        style: text.feedbackMeta,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  label: score == null ? '자세 점수 없음' : '자세 점수 $score점',
                  child: ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          score == null ? '—' : '$score',
                          style: text.reportMyScore,
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text('점', style: text.reportCardTitle),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 자세 분석: the pentagon of the five axes, their status cards and the
/// battle's pace type. With earlier battles, 최근 평균과 비교 lays their mean
/// over the pentagon and adds the change to each card.
class _FormSection extends StatefulWidget {
  const _FormSection({
    required this.report,
    required this.metrics,
    required this.history,
  });

  final FormReport report;
  final ReportMetrics metrics;
  final ReportHistory history;

  @override
  State<_FormSection> createState() => _FormSectionState();
}

class _FormSectionState extends State<_FormSection> {
  bool _compare = false;

  static const _radarHeight = 260.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final metrics = widget.metrics, history = widget.history;
    final report = widget.report;
    final compare = _compare && history.hasHistory;
    final pace = metrics.pace;
    final bounds = metrics.splitBounds;
    final split = metrics.splitValid;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            '자세 분석',
            detail: '인정 ${report.validReps} · 무효 ${report.invalidReps}',
          ),
          if (history.hasHistory) ...[
            const SizedBox(height: AppSpacing.s12),
            _Segments(
              labels: const ['이번 경기', '최근 평균과 비교'],
              selected: compare ? 1 : 0,
              onSelect: (i) => setState(() => _compare = i == 1),
            ),
          ],
          const SizedBox(height: AppSpacing.s8),
          Semantics(
            container: true,
            label: [
              '자세 오각형',
              for (final axis in ReportAxis.values)
                '${axis.label} ${metrics.statusOf(axis)?.label ?? '측정 안 됨'}',
            ].join(', '),
            child: ExcludeSemantics(
              child: SizedBox(
                height: _radarHeight,
                child: CustomPaint(
                  painter: ReportRadarPainter(
                    values: metrics.axes,
                    mean: compare ? history.meanAxes : null,
                    labelStyle: text.reportCardTitle,
                    textScaler: _chartScaler(context),
                  ),
                ),
              ),
            ),
          ),
          if (compare) ...[
            const _RadarLegend(),
            const SizedBox(height: AppSpacing.s8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, axis) in ReportAxis.values.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: _AxisCard(
                    axis: axis,
                    status: metrics.statusOf(axis),
                    change: compare ? history.axisChange(metrics, axis) : null,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1, color: AppColors.cardHigh),
          const SizedBox(height: AppSpacing.s12),
          Text('이번 경기 유형', style: text.feedbackMeta),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.selectedFill,
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.small),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s4,
                  ),
                  child: Text(pace.label, style: text.reportCardTitle),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  '${bounds[0]}–${bounds[1]}초 ${split.first}회 · '
                  '${bounds[2]}–${bounds[3]}초 ${split.last}회',
                  style: text.feedbackMeta,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Two or three choices on one grey rail; the chosen one on white.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  /// The design system's smallest tap target.
  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.cardHigh,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Row(
          children: [
            for (final (i, label) in labels.indexed)
              Expanded(
                child: Semantics(
                  selected: i == selected,
                  button: true,
                  child: InkWell(
                    onTap: () => onSelect(i),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.small),
                    ),
                    child: Ink(
                      height: _height,
                      decoration: BoxDecoration(
                        color: i == selected ? AppColors.card : null,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(AppRadius.small),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: text.archiveLabel.copyWith(
                            color: i == selected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
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

class _RadarLegend extends StatelessWidget {
  const _RadarLegend();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget swatch(Color color, {List<int>? dashes}) => SizedBox(
      width: AppSpacing.s16,
      height: AppSpacing.s8,
      child: CustomPaint(
        painter: FeedbackLegendLine(color: color, dashes: dashes),
      ),
    );
    Widget item(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: AppSpacing.s4),
        Text(label, style: text.feedbackMeta),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.s16,
      runSpacing: AppSpacing.s4,
      children: [
        item(swatch(AppColors.ink), '이번 경기'),
        item(swatch(AppColors.statusGood, dashes: const [4, 3]), '최근 5경기 평균'),
      ],
    );
  }
}

/// One axis under the pentagon: its name, its status and, when comparing,
/// the change from the recent mean in points of 100.
class _AxisCard extends StatelessWidget {
  const _AxisCard({required this.axis, required this.status, this.change});

  final ReportAxis axis;
  final ReportStatus? status;
  final int? change;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = this.status, change = this.change;
    final low = status == ReportStatus.low;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: low ? AppColors.selectedFill : AppColors.card,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
        border: Border.all(color: low ? AppColors.warning : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s8,
          horizontal: AppSpacing.s4,
        ),
        child: Column(
          children: [
            Text(
              axis.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: text.statsAxis,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(status?.label ?? '—', style: text.reportCardTitle),
            if (change != null)
              Text(
                change == 0
                    ? '평균'
                    : change > 0
                    ? '▲ $change'
                    : '▼ ${-change}',
                style: text.coachChipNumber.copyWith(
                  color: change < 0
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The five-axis pentagon: three grey rings, the battle's shape in ink and,
/// with [mean], the recent mean dashed in green. Axis names sit around it.
/// An axis that was not measured is left out of the shape, which joins the
/// measured corners only, and its name is greyed: it is not drawn as 0.
class ReportRadarPainter extends CustomPainter {
  ReportRadarPainter({
    required this.values,
    required this.labelStyle,
    this.mean,
    this.textScaler = TextScaler.noScaling,
  });

  final Map<ReportAxis, double> values;
  final Map<ReportAxis, double>? mean;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  /// Room left around the pentagon for the names.
  static const _margin = 44.0;

  Offset _point(Offset center, double radius, int i, double share) {
    final angle = -1.5707963267948966 + i * 2 * 3.141592653589793 / 5;
    return center + Offset.fromDirection(angle, radius * share.clamp(0.0, 1.0));
  }

  /// The closed shape through each corner with a share; corners without
  /// one are skipped.
  Path _shape(Offset center, double radius, List<double?> shares) {
    final path = Path();
    var first = true;
    for (final (i, share) in shares.indexed) {
      if (share == null) continue;
      final p = _point(center, radius, i, share);
      first ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      first = false;
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - _margin;
    final axes = ReportAxis.values;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.border;
    for (final share in [1 / 3, 2 / 3, 1.0]) {
      canvas.drawPath(
        _shape(center, radius, List.filled(axes.length, share)),
        ring,
      );
    }
    for (var i = 0; i < axes.length; i++) {
      canvas.drawLine(center, _point(center, radius, i, 1), ring);
    }
    final shares = [for (final a in axes) values[a]];
    canvas.drawPath(
      _shape(center, radius, shares),
      Paint()..color = AppColors.ink.withValues(alpha: 0.78),
    );
    final mean = this.mean;
    if (mean != null && mean.isNotEmpty) {
      final dashed = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.statusGood;
      final path = _shape(center, radius, [
        for (final a in axes) values.containsKey(a) ? mean[a] : null,
      ]);
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 10) {
          canvas.drawPath(metric.extractPath(d, d + 6), dashed);
        }
      }
    }
    for (final (i, axis) in axes.indexed) {
      final painter = TextPainter(
        text: TextSpan(
          text: axis.label,
          style: values.containsKey(axis)
              ? labelStyle
              : labelStyle.copyWith(color: AppColors.textMuted),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        textScaler: textScaler,
      )..layout();
      final at = _point(center, radius + _margin / 2 + 4, i, 1);
      painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(ReportRadarPainter old) =>
      old.values != values ||
      old.mean != mean ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}

/// 운동 분석: the counted reps, the estimated calories and lifted weight and
/// the endurance index, each with its change from the recent mean and its
/// place on the 평균 이하 · 평균 · 평균 이상 bar.
class _ExerciseSection extends StatelessWidget {
  const _ExerciseSection({required this.metrics, required this.history});

  final ReportMetrics metrics;
  final ReportHistory history;

  @override
  Widget build(BuildContext context) {
    final weight = metrics.weightKg.round();
    final estimate = metrics.weightAssumed
        ? '체중 $weight kg(기본값) 기준 추정'
        : '체중 $weight kg 기준 추정';
    _ExerciseRow word(ReportRow row) => switch (row.kind) {
      ReportRowKind.validReps => _ExerciseRow(
        label: '인정 횟수',
        value: '${row.value.round()}',
        unit: '회',
        change: row.change,
        bar: row.bar,
      ),
      ReportRowKind.kcal => _ExerciseRow(
        label: '예상 소모 칼로리',
        note: estimate,
        value: row.value.toStringAsFixed(1),
        unit: 'kcal',
        change: row.change,
        decimals: 1,
        bar: row.bar,
      ),
      ReportRowKind.liftedKg => _ExerciseRow(
        label: '들어 올린 무게',
        note: estimate,
        value: '${row.value.round()}',
        unit: 'kg',
        change: row.change,
        bar: row.bar,
      ),
      ReportRowKind.endurance => _ExerciseRow(
        label: '근지구력 지수',
        value: '${row.value.round()}',
        unit: '평균 = 100',
        change: row.change,
        bar: row.bar,
      ),
    };
    final rows = [for (final row in history.rowsOf(metrics)) word(row)];
    return _Section(
      padding: const EdgeInsets.only(top: AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.s20),
            child: _SectionTitle('운동 분석'),
          ),
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.cardHigh),
            row,
          ],
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.label,
    required this.value,
    required this.unit,
    this.note,
    this.change,
    this.decimals = 0,
    this.bar,
  });

  final String label;
  final String value;
  final String unit;
  final String? note;
  final double? change;
  final int decimals;

  /// The share of the bar up to the value; null without a mean to compare.
  final double? bar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final change = this.change, bar = this.bar, note = this.note;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s16,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.feedbackMeta),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: AppSpacing.s4,
                  children: [
                    Text(value, style: text.archiveTotal),
                    Text(unit, style: text.feedbackMeta),
                  ],
                ),
                if (note != null) Text(note, style: text.statsAxis),
                if (change != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  _DeltaChip(change, decimals: decimals),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          if (bar != null)
            Expanded(
              flex: 5,
              child: Semantics(
                container: true,
                label: bar < 1 / 3
                    ? '평균 이하'
                    : bar <= 2 / 3
                    ? '평균'
                    : '평균 이상',
                child: ExcludeSemantics(child: _AverageBar(share: bar)),
              ),
            )
          else
            const Spacer(flex: 5),
        ],
      ),
    );
  }
}

/// The 평균 이하 · 평균 · 평균 이상 bar in thirds, the middle one shaded,
/// filled in green up to [share].
class _AverageBar extends StatelessWidget {
  const _AverageBar({required this.share});

  final double share;

  static const _height = 14.0;
  static const _tick = 5.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.small),
          ),
          child: SizedBox(
            height: _height,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: AppColors.cardHigh),
                ),
                const Positioned.fill(
                  child: Row(
                    children: [
                      Spacer(),
                      Expanded(child: ColoredBox(color: AppColors.border)),
                      Spacer(),
                    ],
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: share,
                  heightFactor: 1,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.statusGood,
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.small),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: _tick,
          child: Row(
            children: [
              Spacer(),
              VerticalDivider(width: 1, color: AppColors.inactive),
              Spacer(),
              VerticalDivider(width: 1, color: AppColors.inactive),
              Spacer(),
            ],
          ),
        ),
        Row(
          children: [
            for (final (label, middle) in [
              ('평균 이하', false),
              ('평균', true),
              ('평균 이상', false),
            ])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: middle
                      ? text.statsAxis.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )
                      : text.statsAxis,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 이번 경기 성과: what this battle reached, and the next thing to reach.
class _HighlightSection extends StatelessWidget {
  const _HighlightSection({required this.lines});

  final List<ReportHighlight> lines;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('이번 경기 성과'),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final line in lines)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: line.achieved
                        ? AppColors.selectedFill
                        : AppColors.cardHigh,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.small),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (line.achieved) ...[
                          const Icon(
                            Icons.check_rounded,
                            size: AppSpacing.s16,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: AppSpacing.s4),
                        ],
                        Flexible(
                          child: Text(
                            line.text,
                            style: text.archiveLabel.copyWith(
                              color: line.achieved
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 변화: counted reps of the latest battles, this one last, with the form
/// scores and the dates under them.
class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.history});

  final ReportHistory history;

  static const _chartHeight = 130.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trend = history.trend;
    String day(DateTime t) {
      final l = t.toLocal();
      return '${l.month}.${l.day.toString().padLeft(2, '0')}';
    }

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle('변화', detail: '최근 ${trend.length}경기 · 인정 횟수'),
          const SizedBox(height: AppSpacing.s12),
          Semantics(
            container: true,
            label:
                '최근 ${trend.length}경기 인정 횟수: '
                '${trend.map((p) => p.validReps).join(', ')}',
            child: ExcludeSemantics(
              child: SizedBox(
                height: _chartHeight,
                child: CustomPaint(
                  painter: ReportTrendPainter(
                    values: [for (final p in trend) p.validReps],
                    labelStyle: text.coachChipNumber,
                    textScaler: _chartScaler(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          const Divider(height: 1, color: AppColors.cardHigh),
          const SizedBox(height: AppSpacing.s8),
          _TrendRow(
            label: '자세 점수',
            cells: [for (final p in trend) p.score?.toString() ?? '—'],
            style: text.coachChipNumber,
          ),
          const SizedBox(height: AppSpacing.s4),
          _TrendRow(
            label: '날짜',
            cells: [
              for (final (i, p) in trend.indexed)
                i == trend.length - 1 ? '이번' : day(p.endedAt),
            ],
            style: text.statsAxis,
          ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.label,
    required this.cells,
    required this.style,
  });

  final String label;
  final List<String> cells;
  final TextStyle style;

  static const _labelWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: _labelWidth,
          child: Text(label, style: text.statsAxis),
        ),
        for (final cell in cells)
          Expanded(
            child: Text(cell, textAlign: TextAlign.center, style: style),
          ),
      ],
    );
  }
}

/// The counted reps as a green line over their dashed mean, the last point
/// filled, each value above its point.
class ReportTrendPainter extends CustomPainter {
  ReportTrendPainter({
    required this.values,
    required this.labelStyle,
    this.textScaler = TextScaler.noScaling,
  });

  final List<int> values;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  /// Room left above and below the line for the values.
  static const _pad = 20.0;

  /// Where the line starts, past the 56-point label column of the rows
  /// under the chart, so each point sits over its column.
  static const _left = 56.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce((a, b) => a < b ? a : b).toDouble();
    final high = values.reduce((a, b) => a > b ? a : b).toDouble();
    final span = high - low == 0 ? 1.0 : high - low;
    final column = (size.width - _left) / values.length;
    Offset at(int i) => Offset(
      _left + column * (i + 0.5),
      size.height - _pad - (values[i] - low) / span * (size.height - 2 * _pad),
    );
    final mean = values.reduce((a, b) => a + b) / values.length;
    final meanY =
        size.height - _pad - (mean - low) / span * (size.height - 2 * _pad);
    final dash = Paint()
      ..color = AppColors.inactive
      ..strokeWidth = 1;
    for (var x = _left; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, meanY), Offset(x + 4, meanY), dash);
    }
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.statusGood,
    );
    for (var i = 0; i < values.length; i++) {
      final last = i == values.length - 1;
      canvas.drawCircle(
        at(i),
        last ? 6 : 4,
        Paint()..color = last ? AppColors.statusGood : AppColors.card,
      );
      if (!last) {
        canvas.drawCircle(
          at(i),
          4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.statusGood,
        );
      }
      final painter = TextPainter(
        text: TextSpan(text: '${values[i]}', style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      painter.paint(
        canvas,
        at(i) - Offset(painter.width / 2, painter.height + 8),
      );
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(ReportTrendPainter old) =>
      old.values != values ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}

/// 코치 한마디, then the way into the evidence.
class _CoachSection extends StatelessWidget {
  const _CoachSection({required this.line, required this.onDetail});

  final String line;
  final VoidCallback onDetail;

  static const _avatar = 48.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s20,
              AppSpacing.s20,
              AppSpacing.s20,
              AppSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle('코치 한마디'),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox.square(
                      dimension: _avatar,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppRadius.small),
                          ),
                        ),
                        child: Icon(
                          Icons.sports_gymnastics_rounded,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(child: Text(line, style: text.feedbackBody)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.cardHigh),
          Semantics(
            container: true,
            button: true,
            child: InkWell(
              onTap: onDetail,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s20,
                  vertical: AppSpacing.s16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('자세 분석 자세히 보기', style: text.reportCardTitle),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The text size the charts' painted labels follow: the user's setting, up
/// to 1.5 times, so the names still fit around the pentagon and over the
/// trend line.
TextScaler _chartScaler(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5);

/// What the depth is called and measured in for an exercise, in the
/// analyzer's own words.
class _DepthWords {
  const _DepthWords(this.title, this.unit);

  factory _DepthWords.of(ExerciseType exercise) => switch (exercise) {
    ExerciseType.pushUp => const _DepthWords('깊이', '어깨 너비 기준'),
    ExerciseType.squat => const _DepthWords('앉은 깊이', '서 있을 때 허벅지 길이 기준'),
  };

  final String title;
  final String unit;
}

const _unseen = '이 구간은 카메라에 잡히지 않았어요.';

/// The analyzer's verdict on the depth, as a sentence; none with too few
/// counted reps to tell.
String? _trendSentence(DepthTrend trend) => switch (trend) {
  DepthTrend.kept => '깊이는 끝까지 유지됐어요.',
  DepthTrend.dropped => '후반으로 갈수록 깊이가 줄었어요.',
  DepthTrend.tooFew => null,
};

/// 자세 분석 자세히 보기 (P14, design D-3 detail): the evidence behind the
/// report. What to fix with the moment it happened, what went well, why reps
/// did not count, the reps per third of the round, and the depth and joint
/// angle over time. The rep-by-rep table is gone.
class FeedbackDetailScreen extends StatelessWidget {
  const FeedbackDetailScreen({
    super.key,
    required this.report,
    required this.form,
    required this.metrics,
  });

  final FormReport report;
  final FormFeedback form;
  final ReportMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final issues = form.issues, good = form.goods;
    final reasons = metrics.rejectCounts;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.s24),
          children: [
            _Header(title: '자세 분석', trailing: reportDate(report.endedAt)),
            if (issues.isNotEmpty) ...[
              _gap,
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('고칠 점'),
                    for (final (i, f) in issues.indexed) ...[
                      if (i > 0) const Divider(color: AppColors.cardHigh),
                      const SizedBox(height: AppSpacing.s12),
                      _IssueRow(finding: f),
                    ],
                  ],
                ),
              ),
            ],
            if (good.isNotEmpty) ...[
              _gap,
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('잘한 점'),
                    for (final f in good) ...[
                      const SizedBox(height: AppSpacing.s12),
                      _CheckLine(f.title),
                    ],
                  ],
                ),
              ),
            ],
            if (reasons.isNotEmpty) ...[
              _gap,
              _ReasonSection(
                reasons: reasons,
                judged: report.reps.length,
                invalid: report.invalidReps,
              ),
            ],
            _gap,
            _SplitSection(report: report, metrics: metrics),
            _gap,
            _depthSection(),
            _gap,
            _angleSection(),
          ],
        ),
      ),
    );
  }

  Widget _depthSection() {
    final words = _DepthWords.of(report.exercise);
    final verdict = _trendSentence(form.depthTrend);
    final Widget body;
    if (FeedbackDepthPlot.hasData(
      report.samples,
      sliceSeconds: form.sliceSeconds,
    )) {
      body = FeedbackChartPanel(
        label: '${words.title} 그래프',
        chart: FeedbackDepthPlot(
          samples: report.samples,
          reps: report.reps,
          sliceSeconds: form.sliceSeconds,
          squat: report.exercise == ExerciseType.squat,
        ),
        caption: ['회색 점선은 인정, 주황 칸이 붙은 점선은 무효 횟수예요.', ?verdict].join('\n'),
      );
    } else if (report.reps.any((r) => r.maxDepth != null)) {
      body = FeedbackNote(['시간별 깊이는 저장되지 않았어요.', ?verdict].join('\n'));
    } else {
      body = const FeedbackNote(_unseen);
    }
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(words.title, detail: words.unit),
          const SizedBox(height: AppSpacing.s12),
          body,
        ],
      ),
    );
  }

  Widget _angleSection() {
    final squat = report.exercise == ExerciseType.squat;
    final Widget body;
    if (squat) {
      body =
          FeedbackHipPlot.hasData(
            report.samples,
            sliceSeconds: form.sliceSeconds,
          )
          ? FeedbackChartPanel(
              label: '엉덩이 각도 그래프',
              chart: FeedbackHipPlot(
                samples: report.samples,
                sliceSeconds: form.sliceSeconds,
              ),
              caption:
                  '똑바로 서면 180°에 가깝고, 깊이 앉을수록 작아져요.\n'
                  '끊긴 곳은 몸이 안 보인 때예요.',
            )
          : const FeedbackNote(_unseen);
    } else if (FeedbackElbowPlot.hasData(
      report.samples,
      sliceSeconds: form.sliceSeconds,
    )) {
      final verdict = switch (form.armBalance) {
        ArmBalance.even => '좌우 각도가 비슷해요.',
        ArmBalance.leftDeeper => '왼팔이 더 굽혀졌어요.',
        ArmBalance.rightDeeper => '오른팔이 더 굽혀졌어요.',
        ArmBalance.unknown => null,
      };
      body = FeedbackChartPanel(
        label: '팔꿈치 각도 그래프',
        chart: FeedbackElbowPlot(
          samples: report.samples,
          sliceSeconds: form.sliceSeconds,
        ),
        caption: ['위가 쭉 편 팔(180°), 아래로 갈수록 많이 굽힌 팔이에요.', ?verdict].join('\n'),
        legend: const FeedbackLegend(),
      );
    } else {
      body = const FeedbackNote(_unseen);
    }
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            squat ? '엉덩이 각도' : '팔꿈치 각도',
            detail: squat ? null : '실선 왼팔 · 점선 오른팔',
          ),
          const SizedBox(height: AppSpacing.s12),
          body,
        ],
      ),
    );
  }
}

/// One thing to fix: the moment it happened as a stick figure when the
/// report kept one, the title, the measured detail and, when there is one,
/// the prepared side-view example of the fault.
class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.finding});

  final FormFinding finding;

  static const _figure = 96.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pose = finding.pose;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pose != null) ...[
          SizedBox.square(
            dimension: _figure,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.cardHigh,
                borderRadius: BorderRadius.all(
                  Radius.circular(AppRadius.small),
                ),
              ),
              child: Semantics(
                label: '${finding.title} 순간의 자세 그림',
                child: CustomPaint(
                  painter: ReportPosePainter(
                    pose: pose,
                    highlight: finding.highlight,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(finding.title, style: text.reportCardTitle),
              const SizedBox(height: AppSpacing.s4),
              Text(finding.detail, style: text.feedbackBody),
              if (finding.demo case final demo?) ...[
                const SizedBox(height: AppSpacing.s12),
                FormFaultClip(demo: demo),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A stick figure of a [FormPose]: the shoulders, arms, nose, hips and
/// knees in ink, the [highlight]ed joints in the warning color.
class ReportPosePainter extends CustomPainter {
  ReportPosePainter({required this.pose, this.highlight = const []});

  final FormPose pose;
  final List<String> highlight;

  static const _bones = [
    ('leftShoulder', 'rightShoulder'),
    ('leftShoulder', 'leftElbow'),
    ('leftElbow', 'leftWrist'),
    ('rightShoulder', 'rightElbow'),
    ('rightElbow', 'rightWrist'),
    ('leftShoulder', 'leftHip'),
    ('rightShoulder', 'rightHip'),
    ('leftHip', 'rightHip'),
    ('leftHip', 'leftKnee'),
    ('rightHip', 'rightKnee'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final points = pose.points.values;
    if (points.isEmpty) return;
    var minX = points.first.x, maxX = minX;
    var minY = points.first.y, maxY = minY;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    final span = [
      maxX - minX,
      maxY - minY,
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    final scale = (size.shortestSide * 0.8) / span;
    final offset = Offset(
      size.width / 2 - (minX + maxX) / 2 * scale,
      size.height / 2 - (minY + maxY) / 2 * scale,
    );
    Offset? at(String name) {
      final p = pose.points[name];
      return p == null ? null : Offset(p.x * scale, p.y * scale) + offset;
    }

    final bone = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in _bones) {
      final pa = at(a), pb = at(b);
      if (pa != null && pb != null) canvas.drawLine(pa, pb, bone);
    }
    final nose = at('nose');
    if (nose != null) {
      canvas.drawCircle(
        nose,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.ink,
      );
    }
    for (final name in highlight) {
      final p = at(name);
      if (p == null) continue;
      canvas.drawCircle(p, 5, Paint()..color = AppColors.warning);
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.ink,
      );
    }
  }

  @override
  bool shouldRepaint(ReportPosePainter old) =>
      old.pose != pose || old.highlight != highlight;
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.line);

  final String line;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        const Icon(
          Icons.check_rounded,
          size: AppSpacing.s20,
          color: AppColors.statusGood,
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(child: Text(line, style: text.reportCardTitle)),
      ],
    );
  }
}

/// 무효 사유: how many reps each reason turned down, as warning bars.
class _ReasonSection extends StatelessWidget {
  const _ReasonSection({
    required this.reasons,
    required this.judged,
    required this.invalid,
  });

  /// Most often first, as [ReportMetrics.rejectCounts].
  final List<(RejectReason, int)> reasons;
  final int judged;
  final int invalid;

  static const _barHeight = 10.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final most = reasons.first.$2;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle('무효 사유', detail: '$judged회 중 $invalid회'),
          for (final (reason, count) in reasons) ...[
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(reason.koreanMessage, style: text.statsIssueName),
                ),
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
                            child: ColoredBox(color: AppColors.cardHigh),
                          ),
                          FractionallySizedBox(
                            widthFactor: count / most,
                            heightFactor: 1,
                            child: const ColoredBox(color: AppColors.warning),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text('$count회', style: text.coachChipNumber),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 10초 구간: counted reps in green with the rejected ones stacked on top in
/// the warning color, for each third of the round.
class _SplitSection extends StatelessWidget {
  const _SplitSection({required this.report, required this.metrics});

  final FormReport report;
  final ReportMetrics metrics;

  static const _barsHeight = 120.0;
  static const _barWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bounds = metrics.splitBounds;
    final valid = metrics.splitValid, invalid = metrics.splitInvalid;
    final most = [
      for (var i = 0; i < valid.length; i++) valid[i] + invalid[i],
      1,
    ].reduce((a, b) => a > b ? a : b);
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            // Equal parts (a full round) are named by their length; a KO
            // round's uneven parts are not.
            bounds[2] == 2 * bounds[1] && bounds[3] == 3 * bounds[1]
                ? '${bounds[1]}초 구간'
                : '구간별 횟수',
            detail: '초록 인정 · 주황 무효',
          ),
          const SizedBox(height: AppSpacing.s12),
          Semantics(
            label: [
              for (var i = 0; i < valid.length; i++)
                '${bounds[i]}–${bounds[i + 1]}초 인정 ${valid[i]}회 무효 ${invalid[i]}회',
            ].join(', '),
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < valid.length; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            invalid[i] == 0
                                ? '${valid[i]}'
                                : '${valid[i]} +${invalid[i]}',
                            style: text.coachChipNumber,
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          SizedBox(
                            width: _barWidth,
                            height: _barsHeight,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (invalid[i] > 0)
                                  SizedBox(
                                    height: _barsHeight * invalid[i] / most,
                                    child: const ColoredBox(
                                      color: AppColors.warning,
                                    ),
                                  ),
                                SizedBox(
                                  height: _barsHeight * valid[i] / most,
                                  child: const ColoredBox(
                                    color: AppColors.statusGood,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            '${bounds[i]}–${bounds[i + 1]}초',
                            style: text.statsAxis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
