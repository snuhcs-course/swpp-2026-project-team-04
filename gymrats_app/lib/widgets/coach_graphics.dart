import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/exercise_type_korean.dart';
import '../services/feedback/coach_script.dart';
import '../theme/app_theme.dart';
import '../utils/korean_josa.dart';
import 'battle_reject_sign.dart';
import 'battle_stage_model.dart';
import 'coach_parts.dart';
import 'lobby_parts.dart';

/// The card above the character (A10 spec 6, UxGfx): white with an ink
/// edge, its kind's drawing inside. A screen reader reads it as one
/// sentence ([sentenceOf]).
class CoachGraphicCard extends StatelessWidget {
  const CoachGraphicCard({super.key, required this.graphic});

  final CoachGraphic graphic;

  static const edge = 2.5;
  static const radius = 20.0;

  /// The card in one sentence, for a screen reader (A10 spec 7).
  static String sentenceOf(CoachGraphic graphic) => switch (graphic) {
    CoachScoreGraphic(:final reps, :final earlier, :final average) => [
      '이번 판 인정 횟수 $reps회',
      if (average != null) '최근 ${earlier.length}판 평균 $average회',
    ].join(', '),
    final CoachPaceGraphic pace => CoachPaceCard.sentenceOf(pace),
    CoachFormGraphic(:final word, :final count, :final sentence) => [
      count == null ? word : '$word $count회',
      sentence,
    ].join(', '),
    CoachComboGraphic(:final combo, :final previousBest) =>
      '가장 긴 콤보 $combo HIT, 지난 최고 $previousBest HIT',
    CoachGoalGraphic(:final title, :final subtitle) =>
      '다음 판 목표, $title, $subtitle',
  };

  @override
  Widget build(BuildContext context) {
    final graphic = this.graphic;
    return Semantics(
      container: true,
      label: sentenceOf(graphic),
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.all(Radius.circular(radius)),
            border: Border.all(color: AppColors.ink, width: edge),
          ),
          child: switch (graphic) {
            final CoachScoreGraphic score => CoachScoreCard(score),
            final CoachPaceGraphic pace => CoachPaceCard(pace),
            final CoachFormGraphic form => CoachFormCard(form),
            final CoachComboGraphic combo => CoachComboCard(combo),
            final CoachGoalGraphic goal => CoachGoalCard(goal),
          },
        ),
      ),
    );
  }
}

/// A small chip with an ink edge inside: lime for a gain, gray otherwise.
class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color, this.style});

  final String text;
  final Color color;
  final TextStyle? style;

  static const _edge = 1.5;
  static const _radius = 8.0;
  static const _side = 10.0;
  static const _top = 1.0;
  static const _padding = EdgeInsets.symmetric(
    horizontal: _side,
    vertical: _top,
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: _padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.all(Radius.circular(_radius)),
      border: Border.all(color: AppColors.ink, width: _edge),
    ),
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      // Text on a colored fill is ink (palette B).
      style:
          style ??
          Theme.of(context).textTheme.coachCardLabel
              .copyWith(color: AppColors.ink),
    ),
  );
}

/// "이번 판 인정 횟수": the big count, the chip against the average, and
/// the earlier battles' bars with this one in ink at the right.
class CoachScoreCard extends StatelessWidget {
  const CoachScoreCard(this.score, {super.key});

  final CoachScoreGraphic score;

  /// Bars: the earlier battles the talk compares with, and this one.
  static const slots = 6;
  static const barsHeight = 84.0;
  static const _barGap = AppSpacing.s8;
  static const _numberGap = AppSpacing.s4;

  /// The chip against the average: "+2회", "-1회" or "±0회".
  static String differenceText(int difference) => switch (difference) {
    > 0 => '+$difference회',
    0 => '±0회',
    _ => '$difference회',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final average = score.average;
    final earlier = score.earlier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('이번 판 인정 횟수', style: text.coachCardLabel),
        const SizedBox(height: AppSpacing.s12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${score.reps}', style: text.coachBigNumber),
                    const SizedBox(width: _numberGap),
                    Text('회', style: text.coachUnit),
                  ],
                ),
              ),
            ),
            if (average != null)
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Chip(
                      text: differenceText(score.reps - average),
                      color: score.reps > average
                          ? AppColors.accent
                          : AppColors.border,
                      style: text.coachDifference,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      '최근 ${earlier.length}판 평균 $average회',
                      textAlign: TextAlign.end,
                      style: text.coachSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (average != null && earlier.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          SizedBox(
            height: barsHeight,
            child: _bars([...earlier, score.reps], average),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${earlier.length}판 전', style: text.coachAxis),
              Text(
                '이번 판',
                style: text.coachAxis.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _bars(List<int> values, int average) {
    final top = math.max(values.fold(average, math.max), 1);
    double heightOf(num v) => (v / top * barsHeight).roundToDouble();
    final shown = values.length > slots
        ? values.sublist(values.length - slots)
        : values;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var slot = 0; slot < slots; slot++) ...[
              if (slot > 0) const SizedBox(width: _barGap),
              Expanded(child: _barAt(slot, shown, heightOf)),
            ],
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: heightOf(average),
          child: const CoachDashedLine(color: AppColors.line, width: 2),
        ),
      ],
    );
  }

  Widget _barAt(int slot, List<int> shown, double Function(num) heightOf) {
    final index = slot - (slots - shown.length);
    if (index < 0) return const SizedBox.shrink();
    return Container(
      key: ValueKey('coach-score-bar-$index'),
      height: heightOf(shown[index]),
      decoration: BoxDecoration(
        color: index == shown.length - 1 ? AppColors.ink : AppColors.chartBar,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.bar),
          bottom: Radius.circular(AppRadius.mark),
        ),
      ),
    );
  }
}

/// "N초마다 인정 횟수": six bars with their counts over them, a dashed mark
/// at the usual count in each slice, and the start (lime) or the later part
/// (amber) colored with a chip over it. Without earlier battles the dashes
/// mark the start's own pace and the chip compares with the start.
class CoachPaceCard extends StatelessWidget {
  const CoachPaceCard(this.pace, {super.key});

  final CoachPaceGraphic pace;

  static const chipRowHeight = 26.0;
  static const barsHeight = 118.0;

  /// With few reps a rep is [_unitMax] high, as in the design; the tallest
  /// bar leaves room for its count over it.
  static const _unitMax = 20.0;
  static const _countHeight = 16.0;
  static const _gap = AppSpacing.s8;
  static const _edge = 2.0;
  static const _dashReach = 3.0;
  static const _legendSwatch = 10.0;
  static const _legendDash = 14.0;

  /// The dashes' level in each slice: the usual counts, or without them
  /// the start's mean count in every slice.
  static List<double> levelsOf(CoachPaceGraphic pace) {
    final usual = pace.usual;
    if (usual != null) return usual;
    final start = pace.buckets.take(CoachPace.earlySlices);
    final mean = start.isEmpty
        ? 0.0
        : start.reduce((a, b) => a + b) / start.length;
    return List.filled(pace.buckets.length, mean);
  }

  /// The chip's words, or null for none.
  static String? chipOf(CoachPaceGraphic pace) => switch (pace.mark) {
    CoachPaceMark.none => null,
    CoachPaceMark.early => '평소보다 빨라요',
    CoachPaceMark.late => pace.usual == null ? '초반보다 느려졌어요' : '평소보다 느려졌어요',
  };

  /// The time under each bar: "0~5초", "~10", ... "~30".
  static List<String> timesOf(CoachPaceGraphic pace) => [
    for (var i = 0; i < pace.buckets.length; i++)
      i == 0
          ? '0~${_seconds(pace.sliceSeconds)}초'
          : '~${_seconds(pace.sliceSeconds * (i + 1))}',
  ];

  /// The card in one sentence: each slice's count and its usual count.
  static String sentenceOf(CoachPaceGraphic pace) {
    final levels = levelsOf(pace);
    final slice = pace.sliceSeconds;
    final usualWord = pace.usual == null ? '초반 평균' : '평소';
    return [
      '${_seconds(slice)}초마다 인정 횟수',
      for (var i = 0; i < pace.buckets.length; i++)
        '${_seconds(slice * i)}~${_seconds(slice * (i + 1))}초 '
            '${pace.buckets[i]}회, $usualWord ${_seconds(levels[i])}회',
      ?chipOf(pace),
    ].join(', ');
  }

  bool _hot(int slice) => switch (pace.mark) {
    CoachPaceMark.none => false,
    CoachPaceMark.early => slice < CoachPace.earlySlices,
    CoachPaceMark.late => slice >= CoachPace.earlySlices,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final levels = levelsOf(pace);
    final top = [
      ...pace.buckets.map((b) => b.toDouble()),
      ...levels,
    ].fold(1.0, math.max);
    // The count over a bar grows with the system text size.
    final countHeight = MediaQuery.textScalerOf(context).scale(_countHeight);
    final room = barsHeight - countHeight;
    // Whole points, so the bars and their counts never pass the room.
    final unit = math.min(_unitMax, (room / top).floorToDouble());
    final chip = chipOf(pace);
    final legend = text.coachAxis.copyWith(color: AppColors.textSecondary);
    final early = CoachPace.earlySlices;
    final rest = pace.buckets.length - early;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_seconds(pace.sliceSeconds)}초마다 인정 횟수',
                style: text.coachCardLabel,
              ),
            ),
            Container(
              width: _legendSwatch,
              height: _legendSwatch,
              decoration: const BoxDecoration(
                color: AppColors.chartBar,
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.mark)),
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Text('이번 판', style: legend),
            const SizedBox(width: AppSpacing.s8),
            const SizedBox(
              width: _legendDash,
              child: CoachDashedLine(color: AppColors.ink, width: _edge),
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(pace.usual == null ? '초반 평균' : '평소', style: legend),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        SizedBox(
          height: chipRowHeight,
          child: chip == null
              ? null
              : Row(
                  children: [
                    if (pace.mark == CoachPaceMark.late) Spacer(flex: early),
                    Expanded(
                      flex: pace.mark == CoachPaceMark.early ? early : rest,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _Chip(
                            text: chip,
                            color: pace.mark == CoachPaceMark.early
                                ? AppColors.accent
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                    if (pace.mark == CoachPaceMark.early) Spacer(flex: rest),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.s8),
        SizedBox(
          height: barsHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < pace.buckets.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: _slice(context, i, unit, levels[i])),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            for (final (i, time) in timesOf(pace).indexed) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(
                child: Text(
                  time,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: text.coachAxis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _slice(BuildContext context, int i, double unit, double level) {
    final text = Theme.of(context).textTheme;
    final hot = _hot(i);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${pace.buckets[i]}',
              textAlign: TextAlign.center,
              style: text.coachChipNumber,
            ),
            Container(
              key: ValueKey('coach-pace-bar-$i'),
              height: pace.buckets[i] * unit,
              decoration: BoxDecoration(
                color: !hot
                    ? AppColors.chartBar
                    : pace.mark == CoachPaceMark.early
                    ? AppColors.accent
                    : AppColors.warning,
                border: hot
                    ? Border.all(color: AppColors.ink, width: _edge)
                    : null,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.bar),
                  bottom: Radius.circular(AppRadius.mark),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: -_dashReach,
          right: -_dashReach,
          bottom: (level * unit).roundToDouble(),
          child: const CoachDashedLine(color: AppColors.ink, width: 2.5),
        ),
      ],
    );
  }
}

/// The form card: the rejection's pictogram, its short words on a red
/// band and how often, its sentence, then the round's time line with the
/// counted reps as ink ticks, the rejections as red circles and the later
/// half shaded amber.
class CoachFormCard extends StatelessWidget {
  const CoachFormCard(this.form, {super.key});

  final CoachFormGraphic form;

  static const tileSize = 76.0;
  static const _tileEdge = 3.0;
  static const _tileRadius = 18.0;
  static const _iconSize = 67.0;
  static const _bandEdge = 2.0;
  static const _bandSide = 10.0;
  static const _bandPadding = EdgeInsets.symmetric(horizontal: _bandSide);
  static const lineHeight = 34.0;

  /// The labels under the time line: the start, the half, the later
  /// rejections (for a rejection) and the end.
  static List<String> labelsOf(CoachFormGraphic form) => [
    '0초',
    '${_seconds(form.half.inMilliseconds / 1000)}초',
    if (form.count != null) '후반에 ${form.lateCount}번',
    '${_seconds(form.roundLength.inMilliseconds / 1000)}초',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final icon = form.reason?.signIcon;
    final count = form.count;
    final labels = labelsOf(form);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Container(
                width: tileSize,
                height: tileSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(_tileRadius),
                  ),
                  border: Border.all(color: AppColors.ink, width: _tileEdge),
                ),
                child: CustomPaint(
                  size: const Size.square(_iconSize),
                  painter: BattleRejectIconPainter(icon),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Positioned.fill(
                            child: LobbySkew(
                              degrees: CoachNameTag.bandLean,
                              alignment: Alignment.center,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  border: Border.all(
                                    color: AppColors.ink,
                                    width: _bandEdge,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: _bandPadding,
                            child: Text(form.word, style: text.coachRejectWord),
                          ),
                        ],
                      ),
                      if (count != null)
                        Text('× $count', style: text.coachTimes),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(form.sentence, style: text.coachCardSentence),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        SizedBox(
          height: lineHeight,
          child: CustomPaint(
            size: const Size.fromHeight(lineHeight),
            painter: CoachTimeLinePainter(form),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final (i, label) in labels.indexed)
              Text(
                label,
                style: i == 2 && count != null
                    ? text.coachAxis.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      )
                    : text.coachAxis,
              ),
          ],
        ),
      ],
    );
  }
}

/// The form card's time line: 0 at the left, the round's end at the right.
class CoachTimeLinePainter extends CustomPainter {
  const CoachTimeLinePainter(this.form);

  final CoachFormGraphic form;

  static const _lateShade = 0.35;
  static const _trackTop = 15.0;
  static const _trackHeight = 4.0;
  static const _tickTop = 9.0;
  static const _tickWidth = 3.0;
  static const _tickHeight = 16.0;
  static const _rejectRadius = 12.0;
  static const _rejectCenter = 17.0;
  static const _rejectEdge = 2.0;
  static const _crossHalf = 3.0;
  static const _crossWidth = 2.2;
  static const _corner = 6.0;

  /// Where [at] falls on a line [width] wide.
  double xOf(Duration at, double width) {
    final round = form.roundLength.inMilliseconds;
    if (round <= 0) return 0;
    return (at.inMilliseconds / round).clamp(0.0, 1.0) * width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final halfX = xOf(form.half, width);
    canvas.drawRRect(
      RRect.fromLTRBR(
        halfX,
        0,
        width,
        size.height,
        const Radius.circular(_corner),
      ),
      Paint()..color = AppColors.warning.withValues(alpha: _lateShade),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        _trackTop,
        width,
        _trackTop + _trackHeight,
        const Radius.circular(_trackHeight / 2),
      ),
      Paint()..color = AppColors.border,
    );
    final ink = Paint()..color = AppColors.ink;
    for (final at in form.validTimes) {
      final x = xOf(at, width);
      canvas.drawRRect(
        RRect.fromLTRBR(
          x - _tickWidth / 2,
          _tickTop,
          x + _tickWidth / 2,
          _tickTop + _tickHeight,
          const Radius.circular(_tickWidth / 2),
        ),
        ink,
      );
    }
    final edge = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _rejectEdge;
    final cross = Paint()
      ..color = AppColors.ink
      ..strokeWidth = _crossWidth
      ..strokeCap = StrokeCap.round;
    for (final at in form.rejectTimes) {
      final center = Offset(xOf(at, width), _rejectCenter);
      canvas
        ..drawCircle(center, _rejectRadius, Paint()..color = AppColors.danger)
        ..drawCircle(center, _rejectRadius - _rejectEdge / 2, edge)
        ..drawLine(
          center.translate(-_crossHalf, -_crossHalf),
          center.translate(_crossHalf, _crossHalf),
          cross,
        )
        ..drawLine(
          center.translate(_crossHalf, -_crossHalf),
          center.translate(-_crossHalf, _crossHalf),
          cross,
        );
    }
  }

  @override
  bool shouldRepaint(CoachTimeLinePainter oldDelegate) =>
      oldDelegate.form != form;
}

/// "가장 긴 콤보": the new combo big on a slanted white band, and the old
/// best beside it.
class CoachComboCard extends StatelessWidget {
  const CoachComboCard(this.combo, {super.key});

  final CoachComboGraphic combo;

  static const bandHeight = 74.0;
  static const _bandEdge = 4.0;
  static const _bandSide = 26.0;
  static const _bandPadding = EdgeInsets.symmetric(horizontal: _bandSide);
  static const _tilt = -5 * math.pi / 180;
  static const _arrowSize = 20.0;
  static const _top = 6.0;
  static const _padding = EdgeInsets.only(top: _top, bottom: AppSpacing.s4);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final line = text.coachButton;
    return Padding(
      padding: _padding,
      child: Column(
        children: [
          _Chip(text: '가장 긴 콤보', color: AppColors.accent),
          const SizedBox(height: AppSpacing.s12),
          Transform.rotate(
            angle: _tilt,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: bandHeight),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LobbySkew(
                        degrees: CoachNameTag.bandLean,
                        alignment: Alignment.center,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            border: Border.all(
                              color: AppColors.ink,
                              width: _bandEdge,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: _bandPadding,
                      child: Text('${combo.combo} HIT', style: text.coachHit),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            children: [
              Text(
                '지난 최고 ${combo.previousBest} HIT',
                style: line.copyWith(color: AppColors.textMuted),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: _arrowSize,
                color: AppColors.ink,
              ),
              Text('${combo.combo} HIT', style: line),
            ],
          ),
        ],
      ),
    );
  }
}

/// "다음 판 목표": a lime tag with the target icon, the goal big, its line,
/// and under a dashed rule where the goal will show.
class CoachGoalCard extends StatelessWidget {
  const CoachGoalCard(this.goal, {super.key});

  final CoachGoalGraphic goal;

  static const _tagEdge = 2.0;
  static const _tagRadius = 10.0;
  static const _tagTop = 3.0;
  static const _tagPadding = EdgeInsets.fromLTRB(
    AppSpacing.s8,
    _tagTop,
    AppSpacing.s12,
    _tagTop,
  );
  static const _iconGap = 6.0;

  /// Where the goal will show (A11 shows it there).
  static String whereText(CoachGoalGraphic goal) =>
      '${Josa.eulReul.after(goal.exercise.koreanName)} 고르면 '
      '운동 선택과 대결 시작 화면에 떠요';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: _tagPadding,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: const BorderRadius.all(Radius.circular(_tagRadius)),
            border: Border.all(color: AppColors.ink, width: _tagEdge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoachTargetIcon(),
              const SizedBox(width: _iconGap),
              Text('다음 판 목표', style: text.coachButton),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(goal.title, style: text.coachGoalTitle),
        const SizedBox(height: AppSpacing.s4),
        Text(goal.subtitle, style: text.coachCardSentence),
        const SizedBox(height: AppSpacing.s12),
        const CoachDashedLine(color: AppColors.border, width: 1.5),
        const SizedBox(height: AppSpacing.s8),
        Text(
          whereText(goal),
          style: text.coachSmallBold.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// A dashed line across its width, [width] thick.
class CoachDashedLine extends StatelessWidget {
  const CoachDashedLine({super.key, required this.color, required this.width});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.fromHeight(width),
    painter: _DashPainter(color: color, width: width),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color, required this.width});

  final Color color;
  final double width;

  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
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
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.width != width;
}

/// Seconds as the cards write them: whole, or with one decimal.
String _seconds(double seconds) {
  final tenths = (seconds * 10).round();
  return tenths % 10 == 0
      ? '${tenths ~/ 10}'
      : (tenths / 10).toStringAsFixed(1);
}
