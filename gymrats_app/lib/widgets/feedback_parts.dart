import 'package:flutter/material.dart';

import '../models/form_report.dart';
import '../models/reject_reason_korean.dart';
import '../services/feedback/form_analyzer.dart';
import '../theme/app_theme.dart';
import 'form_fault_clip.dart';

/// A white card with the app's border and radius: every block of the form
/// feedback screen (BFeedback) sits in one.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.s12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A section's title, with what its numbers are measured in on the right.
/// When both do not fit on one line, [detail] goes under the title.
class FeedbackSectionTitle extends StatelessWidget {
  const FeedbackSectionTitle(this.title, {super.key, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = this.detail;
    return Semantics(
      header: true,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: AppSpacing.s8,
        children: [
          Text(
            title,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (detail != null)
            Text(
              detail,
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// A color square with an ink edge, marking the ink text beside it.
class FeedbackSwatch extends StatelessWidget {
  const FeedbackSwatch(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppHighlight.swatchSize,
      height: AppHighlight.swatchSize,
      child: DecoratedBox(decoration: AppHighlight.swatch(color)),
    );
  }
}

/// One number at the top of the screen: 인정, 무효 (with an amber swatch),
/// 평균 깊이. A number too wide for its tile shrinks rather than wraps.
class FeedbackStat extends StatelessWidget {
  const FeedbackStat({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.swatch,
  });

  final String label;
  final String value;

  /// After [value], e.g. "회"; empty for none.
  final String unit;

  /// The color the label is marked with, or none.
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final swatch = this.swatch;
    return FeedbackPanel(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (swatch != null) ...[
                FeedbackSwatch(swatch),
                const SizedBox(width: AppHighlight.swatchGap),
              ],
              Flexible(
                child: Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(
                text: value,
                style: text.feedbackStat,
                children: [TextSpan(text: unit, style: text.feedbackMeta)],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The round mark at the start of a finding: "!" on amber for a fix, a
/// check on lime for a good point, an outlined "i" for a note. A screen
/// reader reads what kind of finding it is.
class FeedbackBadge extends StatelessWidget {
  const FeedbackBadge(this.kind, {super.key});

  final FindingKind kind;

  static const double size = 24;
  static const double _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    final glyph = Theme.of(context).textTheme.feedbackBadgeMark;
    final (label, fill, edge, mark) = switch (kind) {
      FindingKind.issue => (
        '고칠 점',
        AppColors.warning,
        AppColors.ink,
        Text(
          '!',
          style: glyph.copyWith(color: AppColors.ink),
          textScaler: TextScaler.noScaling,
        ),
      ),
      FindingKind.good => (
        '잘한 점',
        AppColors.accent,
        AppColors.ink,
        const Icon(Icons.check_rounded, size: 16, color: AppColors.ink),
      ),
      FindingKind.note => (
        '참고',
        null,
        AppColors.line,
        Text(
          'i',
          style: glyph.copyWith(color: AppColors.textMuted),
          textScaler: TextScaler.noScaling,
        ),
      ),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: edge, width: _edge),
        ),
        child: mark,
      ),
    );
  }
}

/// One finding: its badge, the title and the numbers in ink, how to fix it
/// in the quieter ink, and the side-view example when it has one.
class FeedbackFindingCard extends StatelessWidget {
  const FeedbackFindingCard({super.key, required this.finding});

  final FormFinding finding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final body = text.feedbackBody;
    final fix = finding.fix;
    final demo = finding.demo;
    return FeedbackPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeedbackBadge(finding.kind),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(finding.detail, style: body),
                if (fix != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    '→ $fix',
                    style: body.copyWith(color: AppColors.textSecondary),
                  ),
                ],
                if (demo != null) ...[
                  const SizedBox(height: AppSpacing.s12),
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

/// A chart in its panel, with the sentence that reads it and, for two
/// lines, the legend. A screen reader hears [label] for the chart, then the
/// sentence.
class FeedbackChartPanel extends StatelessWidget {
  const FeedbackChartPanel({
    super.key,
    required this.label,
    required this.chart,
    required this.caption,
    this.legend,
  });

  /// e.g. "머리 하강 깊이 그래프".
  final String label;
  final Widget chart;
  final String caption;
  final Widget? legend;

  @override
  Widget build(BuildContext context) {
    final legend = this.legend;
    return FeedbackPanel(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: label,
            image: true,
            excludeSemantics: true,
            child: chart,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.s8,
              left: AppSpacing.s12,
            ),
            child: Text(
              caption,
              style: Theme.of(context).textTheme.feedbackCaption,
            ),
          ),
          if (legend != null)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.s4,
                left: AppSpacing.s12,
              ),
              child: Center(child: legend),
            ),
        ],
      ),
    );
  }
}

/// A short line in a panel where a chart or the table has nothing to show.
class FeedbackNote extends StatelessWidget {
  const FeedbackNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return FeedbackPanel(
      child: Text(
        text,
        style: Theme.of(context).textTheme.feedbackBody
            .copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// One row per judged rep: number, time, verdict (a lime or amber swatch
/// and ink text) and the reason, depth, and, for a push-up, the smallest
/// elbow angle seen. The number columns keep their widths and a number
/// that does not fit shrinks, so the verdict keeps its room: at the normal
/// text size a long reason ends in "…" on one line (BFeedback); with larger
/// text it wraps, so the reason is never lost.
class FeedbackRepTable extends StatelessWidget {
  const FeedbackRepTable({
    super.key,
    required this.reps,
    this.showElbow = true,
  });

  final List<RepRecord> reps;

  /// False for a squat: its arms are not judged, so the column says nothing.
  final bool showElbow;

  static const double _numberWidth = 28;
  static const double _timeWidth = 44;
  static const double _depthWidth = 48;
  static const double _elbowWidth = 44;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final head = text.bodySmall?.copyWith(color: AppColors.textSecondary);
    final cell = text.bodyMedium;
    final larger = MediaQuery.textScalerOf(context).scale(1) > 1;

    // A right-aligned column keeps a small gap from the one before it, so
    // its head never touches the previous head when both shrink to fit.
    Widget fixed(double width, Widget child, {bool end = false}) => SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: end ? AppSpacing.s8 : 0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: end
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: child,
        ),
      ),
    );

    Widget row({
      required Widget number,
      required Widget time,
      required Widget verdict,
      required Widget depth,
      required Widget elbow,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        children: [
          fixed(_numberWidth, number),
          fixed(_timeWidth, time),
          Expanded(child: verdict),
          fixed(_depthWidth, depth, end: true),
          if (showElbow) fixed(_elbowWidth, elbow, end: true),
        ],
      ),
    );

    return FeedbackPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s4,
      ),
      child: Column(
        children: [
          row(
            number: Text('#', style: head),
            time: Text('시간', style: head),
            verdict: Text('판정', style: head),
            depth: Text('깊이', style: head),
            elbow: Text('팔꿈치', style: head),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (final r in reps)
            row(
              number: Text('${r.index}', style: cell),
              time: Text('${r.at.inSeconds}s', style: cell),
              verdict: Row(
                children: [
                  FeedbackSwatch(
                    r.valid ? AppColors.accent : AppColors.warning,
                  ),
                  const SizedBox(width: AppHighlight.swatchGap),
                  Flexible(
                    child: Text(
                      r.valid ? '인정' : '무효 · ${r.reason?.koreanMessage ?? ''}',
                      maxLines: larger ? null : 1,
                      overflow: larger ? null : TextOverflow.ellipsis,
                      style: cell,
                    ),
                  ),
                ],
              ),
              depth: Text(r.maxDepth?.toStringAsFixed(2) ?? '—', style: cell),
              elbow: Text(
                r.minElbowAngle == null ? '—' : '${r.minElbowAngle!.round()}°',
                style: cell,
              ),
            ),
        ],
      ),
    );
  }
}
