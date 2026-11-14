// AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/form_report.dart';
import '../services/feedback/form_analyzer.dart';
import '../theme/app_theme.dart';
import '../viewmodels/feedback_viewmodel.dart';
import '../widgets/feedback_charts.dart';
import '../widgets/feedback_parts.dart';
import '../widgets/grid_background.dart';

/// The form feedback of one battle in palette B (BFeedback): the counts,
/// the rule findings, the depth, a joint angle (a push-up's elbows, a
/// squat's hip) and the pace over the round, and every judged rep.
///
/// It draws [form], what [FeedbackViewModel] made of [report], and only
/// words it: every verdict in the chart sentences is the analyzer's own
/// (`FormFeedback.depthTrend`, `armBalance`), so the cards and the
/// sentences never disagree, for push-ups and squats alike. Opened with
/// only a report (the result screen's route), it makes that view model
/// itself with [FeedbackViewModel.fromReport]. Back returns to where it was
/// opened.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.report,
    this.form,
    this.analyzer = const FormAnalyzer(),
  });

  final FormReport report;

  /// What the view model that loaded [report] made of it; null to make it
  /// here from [report] with [analyzer].
  final FormFeedback? form;

  /// The rules the screen's own view model uses when [form] is null.
  final FormAnalyzer analyzer;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  FeedbackViewModel? _own;

  FormFeedback get _form =>
      widget.form ??
      (_own ??= FeedbackViewModel.fromReport(
        widget.report,
        analyzer: widget.analyzer,
      )).state.form!;

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
    final report = widget.report;
    final form = _form;
    final squat = report.exercise == ExerciseType.squat;
    final depth = _DepthWords.of(report.exercise);
    final slice = feedbackSeconds(form.sliceSeconds);
    const gap = SizedBox(height: AppSpacing.s12);
    const section = SizedBox(height: AppSpacing.s24);
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s20,
              AppSpacing.s8,
              AppSpacing.s20,
              AppSpacing.s32,
            ),
            children: [
              _Header(report: report),
              gap,
              _Summary(report: report, meanDepth: form.meanDepth),
              section,
              const FeedbackSectionTitle('자세 피드백'),
              gap,
              for (final finding in form.findings) ...[
                FeedbackFindingCard(finding: finding),
                gap,
              ],
              gap,
              FeedbackSectionTitle(depth.title, detail: depth.unit),
              gap,
              _depthBlock(report, form, depth.title),
              section,
              if (squat) ...[
                const FeedbackSectionTitle('엉덩이 각도', detail: '180° = 똑바로 선 자세'),
                gap,
                _hipBlock(report, form),
              ] else ...[
                const FeedbackSectionTitle('팔꿈치 각도', detail: '180° = 쭉 편 팔'),
                gap,
                _elbowBlock(report, form),
              ],
              if (report.reps.isNotEmpty) ...[
                section,
                FeedbackSectionTitle('속도', detail: '$slice초마다 인정 횟수'),
                gap,
                FeedbackChartPanel(
                  label: '$slice초마다 인정 횟수 막대 그래프',
                  chart: FeedbackPacePlot(
                    buckets: form.paceBuckets,
                    sliceSeconds: form.sliceSeconds,
                  ),
                  caption: _paceSentence(form),
                ),
              ],
              section,
              FeedbackSectionTitle(
                '횟수별 기록',
                detail: '${report.reps.length}회 판정',
              ),
              gap,
              if (report.reps.isEmpty)
                const FeedbackNote('판정된 횟수가 없어요.')
              else
                FeedbackRepTable(reps: report.reps, showElbow: !squat),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the depth is called and measured in for an exercise, in the
/// analyzer's own words.
class _DepthWords {
  const _DepthWords(this.title, this.unit);

  factory _DepthWords.of(ExerciseType exercise) => switch (exercise) {
    ExerciseType.pushUp => const _DepthWords('머리 하강 깊이', '어깨 너비 기준'),
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

/// The depth chart, or a note when no depth was saved over time: a battle
/// with each rep's depth but no depth per moment (an AI squat, #59) says
/// where the depths are and still gives the verdict.
Widget _depthBlock(FormReport report, FormFeedback form, String title) {
  final verdict = _trendSentence(form.depthTrend);
  if (FeedbackDepthPlot.hasData(report.samples)) {
    return FeedbackChartPanel(
      label: '$title 그래프',
      chart: FeedbackDepthPlot(
        samples: report.samples,
        reps: report.reps,
        sliceSeconds: form.sliceSeconds,
        squat: report.exercise == ExerciseType.squat,
      ),
      caption: ['회색 점선은 판정된 횟수, 위에 주황 칸이 붙은 점선은 거절된 횟수예요.', ?verdict].join(' '),
    );
  }
  if (!report.reps.any((r) => r.maxDepth != null)) {
    return const FeedbackNote(_unseen);
  }
  return FeedbackNote(
    ['시간별 깊이는 저장되지 않았어요. 횟수별 깊이는 아래 표에 있어요.', ?verdict].join(' '),
  );
}

/// The joint-angle chart of a squat (Requirements 5.6: depth and
/// joint-angle charts): the hip angle, in place of the arms, which the
/// analyzer does not judge for a squat. The analyzer has no verdict on the
/// hip either, so the sentence only says how to read the line.
Widget _hipBlock(FormReport report, FormFeedback form) {
  if (!FeedbackHipPlot.hasData(report.samples)) {
    return const FeedbackNote(_unseen);
  }
  return FeedbackChartPanel(
    label: '엉덩이 각도 그래프',
    chart: FeedbackHipPlot(
      samples: report.samples,
      sliceSeconds: form.sliceSeconds,
    ),
    caption:
        '어깨-엉덩이-무릎 각도예요. 똑바로 서면 180°에 가깝고, 깊이 앉을수록 작아져요. '
        '끊긴 곳은 몸이 안 보인 때예요.',
  );
}

/// The elbow chart of a push-up. The sentence judges the arms only as the
/// analyzer did: nothing when it could not tell ([ArmBalance.unknown]).
Widget _elbowBlock(FormReport report, FormFeedback form) {
  if (!FeedbackElbowPlot.hasData(report.samples)) {
    return const FeedbackNote(_unseen);
  }
  final verdict = switch (form.armBalance) {
    ArmBalance.even => '좌우 각도가 비슷해요.',
    ArmBalance.leftDeeper => '왼팔이 더 굽혀져 있어요.',
    ArmBalance.rightDeeper => '오른팔이 더 굽혀져 있어요.',
    ArmBalance.unknown => null,
  };
  return FeedbackChartPanel(
    label: '팔꿈치 각도 그래프',
    chart: FeedbackElbowPlot(
      samples: report.samples,
      sliceSeconds: form.sliceSeconds,
    ),
    caption: ['실선이 왼팔, 점선이 오른팔이에요. 끊긴 곳은 팔이 안 보인 때예요.', ?verdict].join(' '),
    legend: const FeedbackLegend(),
  );
}

/// The pace in words, from the view model's slices and rate.
String _paceSentence(FormFeedback form) {
  final slice = feedbackSeconds(form.sliceSeconds);
  return '$slice초마다 인정된 횟수예요. 초반 $slice초 ${form.paceBuckets.first}회, '
      '마지막 $slice초 ${form.paceBuckets.last}회, '
      '평균 ${form.repsPerSecond.toStringAsFixed(2)}회/초.';
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
        // The arrow lines up with the cards, as in the design.
        Transform.translate(
          offset: const Offset(-AppSpacing.s12, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '뒤로',
                onPressed: () => Navigator.maybePop(context),
                color: AppColors.textPrimary,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: AppSpacing.s4),
              Text('FORM', style: text.feedbackTag),
            ],
          ),
        ),
        Expanded(
          child: Text(
            'vs ${report.opponentName} · ${t.month}/${t.day} '
            '${two(t.hour)}:${two(t.minute)}',
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.feedbackMeta,
          ),
        ),
      ],
    );
  }
}

/// Counted and rejected reps, and the view model's mean depth of the
/// counted ones.
class _Summary extends StatelessWidget {
  const _Summary({required this.report, required this.meanDepth});

  final FormReport report;
  final double? meanDepth;

  @override
  Widget build(BuildContext context) {
    final meanDepth = this.meanDepth;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FeedbackStat(
              label: '인정',
              value: '${report.validReps}',
              unit: '회',
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: FeedbackStat(
              label: '무효',
              value: '${report.invalidReps}',
              unit: '회',
              swatch: AppColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: FeedbackStat(
              label: '평균 깊이',
              value: meanDepth?.toStringAsFixed(2) ?? '—',
              unit: meanDepth == null ? '' : '배',
            ),
          ),
        ],
      ),
    );
  }
}
