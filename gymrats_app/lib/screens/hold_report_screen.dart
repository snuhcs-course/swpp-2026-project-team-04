import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hold_record.dart';
import '../services/feedback/hold_metrics.dart';
import '../services/feedback/hold_record_store.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/hold_report_viewmodel.dart';
import '../widgets/archive_cards.dart';
import '../widgets/archive_chart.dart';

/// The report of one played hold (P13, design H-A, as the post-game
/// report's D-3 sections): the date and the hold score, 자세 분석 (the time
/// line of the hold, its keep rate, warnings and goal, and the most
/// frequent warning), 운동 분석 (time held and calories), the
/// highlights, 변화 over the last holds of the pose, and the coach's line.
class HoldReportScreen extends StatefulWidget {
  const HoldReportScreen({
    super.key,
    required this.record,
    this.store,
    this.weightKg,
    this.accountId,
  });

  final HoldRecord record;

  /// The holds kept on the phone, for the comparisons.
  final HoldRecordStore? store;

  /// The user's body weight; null uses 65 kg and says so.
  final double? weightKg;

  /// The signed-in account, for a record kept before accounts.
  final int? accountId;

  @override
  State<HoldReportScreen> createState() => _HoldReportScreenState();
}

class _HoldReportScreenState extends State<HoldReportScreen> {
  late final HoldReportViewModel _viewModel = HoldReportViewModel(
    record: widget.record,
    store: widget.store,
    weightKg: widget.weightKg,
    profiles: _profiles(),
    accountId: widget.accountId,
  );

  /// The app's account data, for the body weight; none in tests without it.
  UserRepository? _profiles() {
    try {
      return context.read<UserRepository>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HoldReportViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Consumer<HoldReportViewModel>(
            builder: (context, vm, _) {
              final m = vm.metrics;
              return ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.s24),
                children: [
                  const _Header(),
                  _ScoreSection(metrics: m),
                  _gap,
                  ArchiveSection(child: _FormSection(metrics: m)),
                  _gap,
                  ArchiveSection(child: _ExerciseSection(metrics: m)),
                  _gap,
                  ArchiveSection(child: _HighlightSection(metrics: m)),
                  _gap,
                  ArchiveSection(child: _TrendSection(metrics: m)),
                  _gap,
                  ArchiveSection(child: _CoachSection(metrics: m)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

const _gap = SizedBox(height: AppSpacing.s8);

/// What 변화 says for the first hold of a pose.
const noEarlier = '비교 기록 없음';

/// "26.11.26(목) 21:10", in the phone's time.
String holdReportDate(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  return '${two(t.year % 100)}.${two(t.month)}.${two(t.day)}'
      '(${days[t.weekday - 1]}) ${two(t.hour)}:${two(t.minute)}';
}

/// "24.6초".
String _seconds(Duration d) =>
    '${HoldMetrics.oneDecimal(HoldMetrics.seconds(d))}초';

/// The back button and REPORT on white.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s8,
          AppSpacing.s4,
          AppSpacing.s20,
          AppSpacing.s4,
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '뒤로',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.chevron_left_rounded),
              color: AppColors.ink,
            ),
            Semantics(
              header: true,
              child: Text('REPORT', style: text.feedbackTag),
            ),
          ],
        ),
      ),
    );
  }
}

/// A "+4" or "-3" chip on lime or grey: a change against the recent mean.
class _ChangeChip extends StatelessWidget {
  const _ChangeChip(this.change, {this.unit = ''});

  final double change;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final up = change >= 0;
    final value = HoldMetrics.oneDecimal(change.abs());
    return Semantics(
      container: true,
      label: '최근 평균보다 $value$unit ${up ? '많음' : '적음'}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: up ? AppColors.selectedFill : AppColors.cardHigh,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.small),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: AppSpacing.s4,
            ),
            child: Text(
              '${up ? '+' : '-'}$value$unit',
              style: text.coachChipNumber,
            ),
          ),
        ),
      ),
    );
  }
}

/// The date, then 유지 점수 with its change, the pose, the floor and the
/// stars, and the score.
class _ScoreSection extends StatelessWidget {
  const _ScoreSection({required this.metrics});

  final HoldMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = metrics.record;
    final recent = metrics.recentScore;
    return ColoredBox(
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: AppColors.facetLight),
          SizedBox(
            height: kMinInteractiveDimension,
            child: Center(
              child: Text(
                holdReportDate(r.endedAt),
                style: text.reportCardTitle,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.facetLight),
          Padding(
            padding: ArchiveSection.defaultPadding,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.s8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('유지 점수', style: text.reportCardTitle),
                          if (recent != null)
                            _ChangeChip(metrics.score - recent),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'STAGE ${r.stage} · ${r.pose.label} · '
                        '별 ${r.stars}/${r.starSeconds.length}',
                        style: text.feedbackMeta,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  label: '유지 점수 ${metrics.score}점',
                  child: ExcludeSemantics(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${metrics.score}',
                            style: text.archiveTotal,
                          ),
                          TextSpan(text: ' 점', style: text.reportCardTitle),
                        ],
                      ),
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

/// Where the stars were reached, from GO: a star asks for seconds held, and
/// each pause before it moves it later.
List<Duration> holdStarTimes(HoldRecord r) {
  final pauses = [...r.pauses]..sort((a, b) => a.start.compareTo(b.start));
  return [
    for (final (i, s) in r.starSeconds.indexed)
      if (i < r.stars)
        () {
          var at = Duration(seconds: s);
          for (final p in pauses) {
            if (p.start < at) at += p.length;
          }
          return at;
        }(),
  ];
}

/// 자세 분석: the time line, the three cards and the most frequent warning.
class _FormSection extends StatelessWidget {
  const _FormSection({required this.metrics});

  final HoldMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = metrics.record;
    final paused = r.pauses.fold(Duration.zero, (sum, p) => sum + p.length);
    final common = metrics.commonWarning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveSectionTitle(
          '자세 분석',
          detail: '경고 ${r.warnings.length} · 멈춤 ${_seconds(paused)}',
        ),
        const SizedBox(height: AppSpacing.s12),
        HoldTimeline(record: r),
        const SizedBox(height: AppSpacing.s12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatusCard(
                name: '유지율',
                status: metrics.keepStatus,
                value: '${(metrics.keepRate * 100).round()}%',
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _StatusCard(
                name: '경고',
                status: metrics.warningStatus,
                value: '${r.warnings.length}회',
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _StatusCard(
                name: '목표 달성',
                status: metrics.goalStatus,
                value:
                    '${HoldMetrics.oneDecimal(HoldMetrics.seconds(r.held))}'
                    ' / ${metrics.goalSeconds}초',
              ),
            ),
          ],
        ),
        if (common != null) ...[
          const SizedBox(height: AppSpacing.s12),
          const Divider(height: 1, color: AppColors.facetLight),
          const SizedBox(height: AppSpacing.s12),
          Text('가장 많이 받은 경고', style: text.feedbackMeta),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: _tint),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.small),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s4,
                  ),
                  child: Text(common.words, style: text.reportCardTitle),
                ),
              ),
              Text(
                common.of == 1
                    ? '이번 기록'
                    : '최근 ${common.of}회 중 ${common.holds}회',
                style: text.feedbackMeta,
              ),
            ],
          ),
        ],
      ],
    );
  }

  static const _tint = 0.18;
}

/// A part's name, 우수 · 표준 · 부족 and its value; 부족 on a warm tint.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.name,
    required this.status,
    required this.value,
  });

  final String name;
  final HoldStatus status;
  final String value;

  static const _edge = 1.5;
  static const _tint = 0.12;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final poor = status == HoldStatus.poor;
    return Semantics(
      container: true,
      label: '$name ${status.label}, $value',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: poor
                ? AppColors.warning.withValues(alpha: _tint)
                : AppColors.card,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.small),
            ),
            border: Border.all(
              color: poor
                  ? AppColors.warning
                  : status == HoldStatus.good
                  ? AppColors.statusGood
                  : AppColors.border,
              width: _edge,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s8,
              horizontal: AppSpacing.s4,
            ),
            child: Column(
              children: [
                Text(name, textAlign: TextAlign.center, style: text.statsAxis),
                Text(
                  status.label,
                  textAlign: TextAlign.center,
                  style: text.reportCardTitle,
                ),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: text.coachChipNumber,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hold from GO to its end on one bar: held time in ink, the pauses on
/// a warm dashed box, a tick at each star with its seconds, each warning's
/// words under its moment, and 0초 and the end under the bar; a legend.
class HoldTimeline extends StatelessWidget {
  const HoldTimeline({super.key, required this.record});

  final HoldRecord record;

  static const height = 96.0;

  /// The time line as a screen reader says it.
  static String words(HoldRecord r) {
    final parts = <String>[];
    final stars = holdStarTimes(r);
    for (final (i, at) in stars.indexed) {
      parts.add('${_seconds(at)}에 ${r.starSeconds[i]}초 별');
    }
    for (final w in r.warnings) {
      parts.add('${_seconds(w.at)}에 "${w.words}" 경고');
    }
    for (final p in r.pauses) {
      parts.add('${_seconds(p.length)} 멈춤');
    }
    return '버틴 시간 흐름, ${_seconds(r.held)} 버팀, 전체 ${_seconds(r.elapsed)}'
        '${parts.isEmpty ? '' : ', ${parts.join(', ')}'}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: words(record),
          child: ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: CustomPaint(
                painter: HoldTimelinePainter(
                  record: record,
                  starStyle: text.coachChipNumber,
                  warningStyle: text.statsAxis.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  axisStyle: text.statsAxis,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        ExcludeSemantics(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.s16,
            children: [
              _Legend(held: true, label: '버틴 시간', style: text.feedbackMeta),
              _Legend(held: false, label: '경고로 멈춤', style: text.feedbackMeta),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.held, required this.label, required this.style});

  final bool held;
  final String label;
  final TextStyle style;

  static const _box = Size(14, 10);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.fromSize(
        size: _box,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: held
                ? AppColors.ink.withValues(alpha: HoldTimelinePainter.heldAlpha)
                : AppColors.warning.withValues(
                    alpha: HoldTimelinePainter.pauseAlpha,
                  ),
            border: held ? null : Border.all(color: AppColors.warning),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.s4),
      Text(label, style: style),
    ],
  );
}

/// Paints [HoldTimeline]'s bar.
class HoldTimelinePainter extends CustomPainter {
  HoldTimelinePainter({
    required this.record,
    required this.starStyle,
    required this.warningStyle,
    required this.axisStyle,
  });

  final HoldRecord record;
  final TextStyle starStyle;
  final TextStyle warningStyle;
  final TextStyle axisStyle;

  /// The ink of held time: as the pentagon of the post-game report.
  static const heldAlpha = 0.78;
  static const pauseAlpha = 0.14;

  static const _barTop = 30.0;
  static const _barHeight = 22.0;
  static const _radius = 6.0;
  static const _dash = 4.0;
  static const _gap = 3.0;

  /// Where [at] falls on a bar of [width].
  double xOf(Duration at, double width) {
    final total = record.elapsed.inMilliseconds;
    if (total <= 0) return 0;
    return (at.inMilliseconds / total).clamp(0.0, 1.0) * width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final bar = Rect.fromLTWH(0, _barTop, w, _barHeight);
    final rounded = RRect.fromRectAndRadius(
      bar,
      const Radius.circular(_radius),
    );
    canvas
      ..drawRRect(rounded, Paint()..color = AppColors.cardHigh)
      ..drawRRect(
        rounded,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.border,
      );
    canvas
      ..save()
      ..clipRRect(rounded);
    // Held time: the spans the hold kept; a record kept before them
    // shows everything but the pauses (PR #106 Codex review).
    final held = Paint()..color = AppColors.ink.withValues(alpha: heldAlpha);
    final spans = record.heldSpans;
    if (spans == null) {
      canvas.drawRect(bar, held);
    } else {
      for (final s in spans) {
        canvas.drawRect(
          Rect.fromLTRB(xOf(s.start, w), _barTop, xOf(s.end, w), bar.bottom),
          held,
        );
      }
    }
    for (final p in record.pauses) {
      final left = xOf(p.start, w), right = xOf(p.end, w);
      final box = Rect.fromLTRB(
        left,
        _barTop,
        math.max(left + 1, right),
        bar.bottom,
      );
      canvas
        ..drawRect(box, Paint()..color = AppColors.card)
        ..drawRect(
          box,
          Paint()..color = AppColors.warning.withValues(alpha: pauseAlpha),
        );
      _dashedRect(canvas, box.deflate(1));
    }
    canvas.restore();

    final tick = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1.5;
    for (final (i, at) in holdStarTimes(record).indexed) {
      final x = xOf(at, w);
      canvas.drawLine(Offset(x, _barTop - 6), Offset(x, bar.bottom + 4), tick);
      _text(canvas, '★ ${record.starSeconds[i]}초', starStyle, Offset(x, 0), w);
    }
    for (final warning in record.warnings) {
      _text(
        canvas,
        warning.words,
        warningStyle,
        Offset(xOf(warning.at, w), bar.bottom + 6),
        w,
      );
    }
    final axisY = size.height - 14;
    _text(canvas, '0초', axisStyle, Offset(0, axisY), w, align: -1);
    _text(
      canvas,
      _seconds(record.elapsed),
      axisStyle,
      Offset(w, axisY),
      w,
      align: 1,
    );
  }

  void _dashedRect(Canvas canvas, Rect r) {
    final paint = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 2;
    void line(Offset a, Offset b) {
      final length = (b - a).distance;
      if (length == 0) return;
      final dir = (b - a) / length;
      for (var d = 0.0; d < length; d += _dash + _gap) {
        canvas.drawLine(
          a + dir * d,
          a + dir * math.min(length, d + _dash),
          paint,
        );
      }
    }

    line(r.topLeft, r.topRight);
    line(r.bottomLeft, r.bottomRight);
    line(r.topLeft, r.bottomLeft);
    line(r.topRight, r.bottomRight);
  }

  /// [text] around [at]: centred, or from its left (-1) or right (1) end,
  /// kept inside [width].
  void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at,
    double width, {
    int align = 0,
  }) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final left = switch (align) {
      < 0 => at.dx,
      > 0 => at.dx - p.width,
      _ => at.dx - p.width / 2,
    };
    p.paint(
      canvas,
      Offset(left.clamp(0.0, math.max(0.0, width - p.width)), at.dy),
    );
  }

  @override
  bool shouldRepaint(HoldTimelinePainter old) =>
      old.record != record ||
      old.starStyle != starStyle ||
      old.warningStyle != warningStyle ||
      old.axisStyle != axisStyle;
}

/// 운동 분석: the time held and the calories, each with its change against
/// the recent mean when there is one. No endurance index: the reports judge
/// by counts and time (user, 2026-11-26).
class _ExerciseSection extends StatelessWidget {
  const _ExerciseSection({required this.metrics});

  final HoldMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final held = HoldMetrics.seconds(metrics.record.held);
    final recentHeld = metrics.recentHeld;
    final recentKcal = metrics.recentKcal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ArchiveSectionTitle('운동 분석'),
        _Row(
          name: '버틴 시간',
          value: HoldMetrics.oneDecimal(held),
          unit: '초',
          change: recentHeld == null ? null : held - recentHeld,
          changeUnit: '초',
        ),
        const Divider(height: 1, color: AppColors.facetLight),
        _Row(
          name: '예상 소모 칼로리',
          value: HoldMetrics.oneDecimal(metrics.kcal),
          unit: 'kcal',
          change: recentKcal == null ? null : metrics.kcal - recentKcal,
          note: metrics.weightAssumed
              ? '${HoldMetrics.defaultWeightKg.round()} kg 기준 추정'
              : '체중 ${HoldMetrics.oneDecimal(metrics.weightKg)} kg 기준 추정',
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.name,
    required this.value,
    required this.unit,
    this.change,
    this.changeUnit = '',
    this.note,
  });

  final String name;
  final String value;
  final String unit;
  final double? change;
  final String changeUnit;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final change = this.change;
    final note = this.note;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.feedbackMeta),
                Semantics(
                  container: true,
                  label: '$name $value$unit',
                  child: ExcludeSemantics(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: value, style: text.feedbackStat),
                          if (unit.isNotEmpty)
                            TextSpan(text: ' $unit', style: text.archiveLabel),
                        ],
                      ),
                    ),
                  ),
                ),
                if (note != null) Text(note, style: text.feedbackMeta),
              ],
            ),
          ),
          if (change != null) _ChangeChip(change, unit: changeUnit),
        ],
      ),
    );
  }
}

/// 이번 기록 성과: the reached lines with a check, the next goal in grey.
class _HighlightSection extends StatelessWidget {
  const _HighlightSection({required this.metrics});

  final HoldMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final next = metrics.nextGoal;
    final lines = metrics.highlights;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ArchiveSectionTitle('이번 기록 성과'),
        const SizedBox(height: AppSpacing.s12),
        if (lines.isEmpty && next == null)
          Text('다음 기록부터 비교해 드릴게요.', style: text.feedbackMeta)
        else
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final line in lines) _Chip(label: line, reached: true),
              if (next != null) _Chip(label: next, reached: false),
            ],
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.reached});

  final String label;
  final bool reached;

  static const _icon = 16.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: reached ? AppColors.selectedFill : AppColors.cardHigh,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reached) ...[
              const Icon(
                Icons.check_rounded,
                size: _icon,
                color: AppColors.statusGood,
              ),
              const SizedBox(width: AppSpacing.s4),
            ],
            Flexible(
              child: Text(
                label,
                style: reached
                    ? text.reportCardTitle
                    : text.reportCardTitle.copyWith(
                        color: AppColors.textSecondary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 변화: the time held over the last holds of the pose, oldest first.
class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.metrics});

  final HoldMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trend = metrics.trend;
    final values = [for (final r in trend) HoldMetrics.seconds(r.held)];
    final pose = metrics.record.pose.label;
    if (metrics.earlier.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArchiveSectionTitle('변화', detail: '$pose 버틴 시간'),
          const SizedBox(height: AppSpacing.s12),
          Text(noEarlier, style: text.feedbackMeta),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArchiveSectionTitle('변화', detail: '최근 ${trend.length}회 · $pose 버틴 시간'),
        const SizedBox(height: AppSpacing.s12),
        Semantics(
          container: true,
          label:
              '최근 ${trend.length}회 $pose 버틴 시간: '
              '${[for (final v in values) '${HoldMetrics.oneDecimal(v)}초'].join(', ')}',
          child: ExcludeSemantics(
            child: SizedBox(
              height: ArchiveScoreChart.height,
              child: CustomPaint(
                painter: ArchiveTrendPainter(
                  values: values,
                  labelStyle: text.coachChipNumber,
                  meanStyle: text.statsAxis,
                  format: (v) => HoldMetrics.oneDecimal(v.toDouble()),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final (i, r) in trend.indexed)
                Expanded(
                  child: Text(
                    i == trend.length - 1 ? '오늘' : archiveDay(r.endedAt),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: text.statsAxis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 코치 한마디: the lime character box and the coach's line.
class _CoachSection extends StatelessWidget {
  const _CoachSection({required this.metrics});

  final HoldMetrics metrics;

  static const _box = 48.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ArchiveSectionTitle('코치 한마디'),
        const SizedBox(height: AppSpacing.s12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox.square(
              dimension: _box,
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
            Expanded(child: Text(metrics.coachLine, style: text.feedbackBody)),
          ],
        ),
      ],
    );
  }
}
