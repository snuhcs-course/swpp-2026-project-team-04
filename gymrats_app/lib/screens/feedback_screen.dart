// AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/battle_rules.dart';
import '../models/form_report.dart';
import '../models/reject_reason_korean.dart';
import '../services/feedback/form_analyzer.dart';
import '../theme/app_theme.dart';
import '../widgets/form_fault_clip.dart';
import '../widgets/grid_background.dart';

/// The form feedback of one battle: the rule findings, the head drop and
/// elbow angles over the round, and every judged rep.
///
/// Everything comes from [report], read from this device; the findings are
/// computed when the screen opens. Back returns to where it was opened.
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({
    super.key,
    required this.report,
    this.analyzer = const FormAnalyzer(),
  });

  final FormReport report;
  final FormAnalyzer analyzer;

  @override
  Widget build(BuildContext context) {
    final findings = analyzer.analyze(report);
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _Header(report: report),
              const SizedBox(height: 12),
              _Summary(report: report),
              const SizedBox(height: 24),
              const _SectionTitle('자세 피드백'),
              const SizedBox(height: 10),
              for (final finding in findings) ...[
                _FindingCard(finding: finding),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 14),
              const _SectionTitle('머리 하강 깊이', detail: '어깨 너비 기준'),
              const SizedBox(height: 10),
              _DepthChart(report: report),
              const SizedBox(height: 24),
              const _SectionTitle('팔꿈치 각도', detail: '180° = 쭉 편 팔'),
              const SizedBox(height: 10),
              _ElbowChart(report: report),
              if (report.reps.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionTitle(
                  '속도',
                  detail:
                      '${_sliceSeconds(report.roundLength).round()}초마다 인정 횟수',
                ),
                const SizedBox(height: 10),
                _PaceChart(report: report),
              ],
              const SizedBox(height: 24),
              _SectionTitle('횟수별 기록', detail: '${report.reps.length}회 판정'),
              const SizedBox(height: 10),
              _RepTable(report: report),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back, "FORM", and which battle this is.
class _Header extends StatelessWidget {
  const _Header({required this.report});

  final FormReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = report.endedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return Row(
      children: [
        IconButton(
          tooltip: '뒤로',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Text(
          'FORM',
          style: text.bodySmall?.copyWith(
            fontFamily: AppFonts.number,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 2.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'vs ${report.opponentName} · ${t.month}/${t.day} '
            '${two(t.hour)}:${two(t.minute)}',
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Counted and rejected reps, and the average depth of the counted ones.
class _Summary extends StatelessWidget {
  const _Summary({required this.report});

  final FormReport report;

  @override
  Widget build(BuildContext context) {
    final depths = [
      for (final r in report.reps)
        if (r.valid && r.maxDepth != null) r.maxDepth!,
    ];
    final meanDepth = depths.isEmpty
        ? null
        : depths.reduce((a, b) => a + b) / depths.length;
    return Row(
      children: [
        Expanded(
          child: _Stat(label: '인정', value: '${report.validReps}', unit: '회'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            label: '무효',
            value: '${report.invalidReps}',
            unit: '회',
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            label: '평균 깊이',
            value: meanDepth?.toStringAsFixed(2) ?? '—',
            unit: meanDepth == null ? '' : '배',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    this.color = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: value,
              style: text.displaySmall?.copyWith(fontSize: 24, color: color),
              children: [
                TextSpan(
                  text: unit,
                  style: text.bodySmall?.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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
        Text(
          title,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (detail != null)
          Text(
            detail,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

/// A card with the app's border and radius.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// One finding: amber for a fix, lime for a good point, gray for a note.
class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final FormFinding finding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (color, icon) = switch (finding.kind) {
      FindingKind.issue => (AppColors.warning, Icons.error_outline_rounded),
      FindingKind.good => (AppColors.accent, Icons.check_circle_rounded),
      FindingKind.note => (AppColors.textSecondary, Icons.info_outline_rounded),
    };
    final fix = finding.fix;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: text.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(finding.detail, style: text.bodyMedium),
                if (fix != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '→ $fix',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (finding.demo case final demo?) ...[
                  const SizedBox(height: 12),
                  FormFaultClip(demo: demo),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _seconds(Duration d) => d.inMilliseconds / 1000;

/// What the depth chart is, and whether the counted reps stayed deep.
String _depthSentence(FormReport report) {
  const marks = '초록 점선은 인정, 노란 점선은 거절된 횟수예요.';
  final valid = [
    for (final rep in report.reps)
      if (rep.valid && rep.maxDepth != null) rep.maxDepth!,
  ];
  if (valid.length < 4) return marks;
  final mid = valid.length ~/ 2;
  final early = valid.take(mid).reduce((a, b) => a + b) / mid;
  final lateCount = valid.length - mid;
  final late = valid.skip(mid).reduce((a, b) => a + b) / lateCount;
  final held = early - late < 0.25;
  return '$marks ${held ? '깊이는 끝까지 유지됐어요.' : '후반으로 갈수록 깊이가 줄었어요.'}';
}

/// What the elbow chart is, and whether the arms matched.
String _elbowSentence(FormReport report) {
  const legend = '연두가 왼팔, 하양이 오른팔이에요. 끊긴 곳은 팔이 안 보인 때예요.';
  final both = [
    for (final sample in report.samples)
      if (sample.leftElbow != null && sample.rightElbow != null)
        (sample.leftElbow! - sample.rightElbow!).abs(),
  ];
  if (both.length < 10) return legend;
  final gap = both.reduce((a, b) => a + b) / both.length;
  if (gap <= 15) return '$legend 좌우 각도가 비슷해요.';
  final left = [
    for (final sample in report.samples)
      if (sample.leftElbow != null) sample.leftElbow!,
  ];
  final right = [
    for (final sample in report.samples)
      if (sample.rightElbow != null) sample.rightElbow!,
  ];
  final leftMean = left.reduce((a, b) => a + b) / left.length;
  final rightMean = right.reduce((a, b) => a + b) / right.length;
  final bent = leftMean < rightMean ? '왼팔이 더 굽혀져 있어요.' : '오른팔이 더 굽혀져 있어요.';
  return '$legend $bent';
}

/// Seconds in one pace bar and one time-axis gap. Six slices, so a 30 s
/// round is 5 s and a saved 60 s round stays 10 s.
double _sliceSeconds(Duration round) {
  final seconds = round.inMilliseconds / 1000;
  if (seconds <= 0) return 5;
  return seconds / battleTimeSlices;
}

/// Seconds along the bottom, one label per slice; values on the left.
FlTitlesData _titles(
  String Function(double) leftLabel,
  double leftStep,
  double timeStep,
) {
  const style = TextStyle(fontSize: 10, color: AppColors.textMuted);
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: timeStep,
        reservedSize: 22,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text('${value.round()}s', style: style),
        ),
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: leftStep,
        reservedSize: 34,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(leftLabel(value), style: style),
        ),
      ),
    ),
  );
}

FlGridData _grid(double step) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: step,
  getDrawingHorizontalLine: (_) =>
      const FlLine(color: AppColors.border, strokeWidth: 1),
);

/// A line through [values] over time, broken where a value is missing.
LineChartBarData _line(
  List<FormSample> samples,
  double? Function(FormSample) value,
  Color color,
) => LineChartBarData(
  spots: [
    for (final s in samples)
      if (value(s) case final v?)
        FlSpot(_seconds(s.at), v)
      else
        FlSpot.nullSpot,
  ],
  color: color,
  barWidth: 2,
  isCurved: true,
  preventCurveOverShooting: true,
  dotData: const FlDotData(show: false),
);

/// The head drop over the round, with a mark at each judged rep: lime when
/// it counted, amber when it did not.
class _DepthChart extends StatelessWidget {
  const _DepthChart({required this.report});

  final FormReport report;

  @override
  Widget build(BuildContext context) {
    final samples = report.samples;
    final depths = [for (final s in samples) ?s.depth];
    if (depths.isEmpty) return const _NoData();
    final maxY = math.max(2.0, depths.reduce(math.max)).ceilToDouble();
    final minY = math.min(0.0, depths.reduce(math.min)).floorToDouble();
    final text = Theme.of(context).textTheme;
    return _Panel(
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: _seconds(report.roundLength),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  _line(samples, (s) => s.depth, AppColors.accent),
                ],
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    for (final r in report.reps)
                      VerticalLine(
                        x: _seconds(r.at),
                        color: (r.valid ? AppColors.accent : AppColors.warning)
                            .withValues(alpha: 0.5),
                        strokeWidth: 1,
                        dashArray: [3, 3],
                      ),
                  ],
                ),
                titlesData: _titles(
                  (v) => v.toStringAsFixed(1),
                  0.5,
                  _sliceSeconds(report.roundLength),
                ),
                gridData: _grid(0.5),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(_depthSentence(report), style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Both elbow angles over the round: lime for the left arm, white for the
/// right. Gaps are where the arms were hidden.
class _ElbowChart extends StatelessWidget {
  const _ElbowChart({required this.report});

  final FormReport report;

  @override
  Widget build(BuildContext context) {
    final samples = report.samples;
    final seen = samples.any(
      (s) => s.leftElbow != null || s.rightElbow != null,
    );
    if (!seen) return const _NoData();
    final text = Theme.of(context).textTheme;
    return _Panel(
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: _seconds(report.roundLength),
                minY: 60,
                maxY: 180,
                lineBarsData: [
                  _line(samples, (s) => s.leftElbow, AppColors.accent),
                  _line(samples, (s) => s.rightElbow, AppColors.textPrimary),
                ],
                titlesData: _titles(
                  (v) => '${v.round()}°',
                  30,
                  _sliceSeconds(report.roundLength),
                ),
                gridData: _grid(30),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(_elbowSentence(report), style: text.bodySmall),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (label, color) in [
                ('왼팔', AppColors.accent),
                ('오른팔', AppColors.textPrimary),
              ]) ...[
                Container(width: 12, height: 3, color: color),
                const SizedBox(width: 6),
                Text(label, style: text.bodySmall),
                const SizedBox(width: 16),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Valid reps in each time slice, and whether the pace held.
class _PaceChart extends StatelessWidget {
  const _PaceChart({required this.report});

  final FormReport report;

  @override
  Widget build(BuildContext context) {
    final slice = _sliceSeconds(report.roundLength);
    final buckets = battleTimeSlices;
    final counts = List<int>.filled(buckets, 0);
    for (final rep in report.reps) {
      if (!rep.valid) continue;
      final index = (_seconds(rep.at) / slice).floor();
      if (index >= 0 && index < buckets) counts[index]++;
    }
    final peak = counts.reduce(math.max);
    final text = Theme.of(context).textTheme;
    final rate = report.validReps / math.max(1, report.roundLength.inSeconds);
    return _Panel(
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: math.max(2, peak).toDouble(),
                barGroups: [
                  for (var i = 0; i < buckets; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: counts[i].toDouble(),
                          color: AppColors.accent,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
                titlesData: _paceTitles(slice),
                gridData: _grid(1),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${slice.round()}초마다 인정된 횟수예요. 초반 ${slice.round()}초 ${counts.first}회, '
            '마지막 ${slice.round()}초 ${counts.last}회, 평균 ${rate.toStringAsFixed(2)}회/초.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

FlTitlesData _paceTitles(double sliceSeconds) {
  const style = TextStyle(fontSize: 10, color: AppColors.textMuted);
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 22,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text('${(value * sliceSeconds).round()}s', style: style),
        ),
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: 1,
        reservedSize: 28,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(value.round().toString(), style: style),
        ),
      ),
    ),
  );
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Text(
        '이 구간은 카메라에 잡히지 않았어요.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// One row per judged rep: number, time, verdict and reason, depth, and
/// the smallest elbow angle seen.
class _RepTable extends StatelessWidget {
  const _RepTable({required this.report});

  final FormReport report;

  @override
  Widget build(BuildContext context) {
    if (report.reps.isEmpty) return const _NoData();
    final text = Theme.of(context).textTheme;
    final head = text.bodySmall?.copyWith(color: AppColors.textSecondary);
    final cell = text.bodyMedium;
    Widget row(List<Widget> cells) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 28, child: cells[0]),
          SizedBox(width: 44, child: cells[1]),
          Expanded(child: cells[2]),
          SizedBox(width: 48, child: cells[3]),
          SizedBox(width: 44, child: cells[4]),
        ],
      ),
    );
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          row([
            Text('#', style: head),
            Text('시간', style: head),
            Text('판정', style: head),
            Text('깊이', style: head, textAlign: TextAlign.end),
            Text('팔꿈치', style: head, textAlign: TextAlign.end),
          ]),
          const Divider(height: 1, color: AppColors.border),
          for (final r in report.reps)
            row([
              Text('${r.index}', style: cell),
              Text('${r.at.inSeconds}s', style: cell),
              Text(
                r.valid ? '인정' : '무효 · ${r.reason?.koreanMessage ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: cell?.copyWith(
                  color: r.valid ? AppColors.accent : AppColors.warning,
                ),
              ),
              Text(
                r.maxDepth?.toStringAsFixed(2) ?? '—',
                style: cell,
                textAlign: TextAlign.end,
              ),
              Text(
                r.minElbowAngle == null ? '—' : '${r.minElbowAngle!.round()}°',
                style: cell,
                textAlign: TextAlign.end,
              ),
            ]),
        ],
      ),
    );
  }
}
