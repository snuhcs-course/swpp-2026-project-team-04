import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/character_rig.dart';
import '../services/feedback/coach_script.dart';
import '../theme/app_theme.dart';
import 'character_figure.dart';
import 'coach_parts.dart';

/// A personal best the battle set, in points of its exercise.
class ResultNewBest {
  const ResultNewBest({
    required this.previous,
    required this.current,
    required this.gain,
  });

  /// The best before this battle.
  final int previous;

  /// This battle's score, the new best.
  final int current;

  /// How much higher it is.
  final int gain;
}

/// This battle among the latest ones, for the bar chart.
class ResultRecent {
  const ResultRecent({
    required this.scores,
    required this.firstPlayedAt,
    required this.average,
    required this.averageCount,
    required this.difference,
  });

  /// The scores oldest first, this battle last. The chart draws the last
  /// [ResultRecentCard.slots] of them. The report leaves the card out when
  /// the list is empty; the card itself needs at least this battle.
  final List<int> scores;

  /// When the first battle of [scores] was played.
  final DateTime firstPlayedAt;

  /// The average the dashed line marks, over [averageCount] battles.
  final int average;
  final int averageCount;

  /// This battle's score above (or, below zero, under) [average].
  final int difference;
}

/// The character card's values (A10 spec 2): who talks and how many lines
/// the talk has.
class ResultCoachEntry {
  const ResultCoachEntry({
    required this.characterId,
    required this.name,
    required this.ending,
    this.lineCount,
  });

  /// The character the user has now, drawn idle on the card.
  final String characterId;

  /// Its name on the tag, e.g. "물렁범".
  final String name;

  /// The ending after its sentences, e.g. "범".
  final String ending;

  /// The lines before the goal question; null while the talk loads, when
  /// the card's buttons wait.
  final int? lineCount;
}

/// Where the personal best and the latest battles go while the earlier
/// battles load: one quiet line in a card, never a 0 or an empty chart.
class ResultComparisonPlaceholder extends StatelessWidget {
  const ResultComparisonPlaceholder({super.key});

  /// The line it shows.
  static const text = '이전 기록을 불러오는 중…';

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.reportLine
        .copyWith(color: AppColors.textMuted);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        child: Text(text, style: style),
      ),
    );
  }
}

/// "개인 최고 기록 갱신" on lime with an ink edge: a lime trophy on an ink
/// disc, then the old best, the new one in bold, and the gain.
class ResultBestCard extends StatelessWidget {
  const ResultBestCard(this.best, {super.key});

  final ResultNewBest best;

  static const edge = 1.5;
  static const _discSize = 40.0;
  static const _trophySize = 20.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final line = text.reportLine.copyWith(color: AppColors.ink);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
        border: Border.all(color: AppColors.ink, width: edge),
      ),
      child: Row(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: _discSize,
              child: Icon(
                Icons.emoji_events_outlined,
                size: _trophySize,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '개인 최고 기록 갱신',
                  style: text.reportCardTitle.copyWith(color: AppColors.ink),
                ),
                Text.rich(
                  TextSpan(
                    text: '${best.previous}점 → ',
                    children: [
                      TextSpan(
                        text: '${best.current}점',
                        style: line.copyWith(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' · ${best.gain}점 올랐어요'),
                    ],
                  ),
                  style: line,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "최근 N판 중 이번 판": a bar per battle, this one in ink at the right,
/// the earlier ones gray, a dashed line at the average with its label, the
/// first battle's date under the left and this score under the right.
class ResultRecentCard extends StatelessWidget {
  const ResultRecentCard(this.recent, {super.key});

  final ResultRecent recent;

  /// Bars in the chart; with fewer battles the slots on the left stay
  /// empty, so this battle is always at the right.
  static const slots = 8;

  static const chartHeight = 96.0;

  /// The tallest bar, the highest score.
  static const barsHeight = 88.0;

  /// How far above the dashed line its label sits.
  static const _labelGap = AppSpacing.s4;

  /// Above this the label goes under the line, to stay in the chart.
  static const _labelBelowFrom = 60.0;

  /// How much of the lime shows behind a score above the average.
  static const _limeStrength = 0.6;

  /// The scores the chart draws, oldest first.
  List<int> get shown => recent.scores.length <= slots
      ? recent.scores
      : recent.scores.sublist(recent.scores.length - slots);

  /// [score]'s height in the chart: the highest score (or the average,
  /// when higher) is [barsHeight].
  double heightOf(num score) {
    final top = math.max(shown.fold(recent.average, math.max), 1);
    return (score / top * barsHeight).roundToDouble();
  }

  /// Whether this score is above the average: its chip is lime, else gray.
  bool get aboveAverage => recent.difference > 0;

  /// The average's chip: how far this score is above it or under it, or
  /// that it is the same.
  String get differenceText => switch (recent.difference) {
    0 => '평균과 같아요',
    > 0 => '평균보다 +${recent.difference}점',
    _ => '평균보다 ${recent.difference}점',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = this.shown;
    final small = text.labelSmall?.copyWith(fontWeight: FontWeight.w400);
    final lineAt = heightOf(recent.average);
    final date = recent.firstPlayedAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s16,
          AppSpacing.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '최근 ${shown.length}판 중 이번 판',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                DecoratedBox(
                  decoration: AppHighlight.chip(
                    aboveAverage ? AppColors.accent : AppColors.border,
                    strength: aboveAverage ? _limeStrength : 1,
                  ),
                  child: Padding(
                    padding: AppHighlight.chipPadding,
                    child: Text(
                      differenceText,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Semantics(
              container: true,
              label:
                  '최근 ${shown.length}판 점수 ${shown.join(', ')}, '
                  '최근 ${recent.averageCount}판 평균 ${recent.average}',
              child: ExcludeSemantics(
                child: SizedBox(
                  height: chartHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: lineAt,
                        child: const CustomPaint(
                          size: Size.fromHeight(ResultDashedLine.width),
                          painter: ResultDashedLine(),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var slot = 0; slot < slots; slot++) ...[
                              if (slot > 0)
                                const SizedBox(width: AppSpacing.s8),
                              Expanded(child: _barAt(slot, shown)),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        bottom: lineAt > _labelBelowFrom
                            ? null
                            : lineAt + _labelGap,
                        top: lineAt > _labelBelowFrom
                            ? chartHeight - lineAt + _labelGap
                            : null,
                        child: ColoredBox(
                          color: AppColors.card,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.s4,
                            ),
                            child: Text(
                              '최근 ${recent.averageCount}판 평균 '
                              '${recent.average}',
                              style: small?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${date.month}/${date.day}',
                  style: small?.copyWith(color: AppColors.textMuted),
                ),
                Text(
                  '이번 판 ${shown.last}',
                  style: small?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The bar in [slot], or nothing: the scores fill the slots from the
  /// right.
  Widget _barAt(int slot, List<int> shown) {
    final index = slot - (slots - shown.length);
    if (index < 0) return const SizedBox.shrink();
    final last = index == shown.length - 1;
    return Container(
      height: heightOf(shown[index]),
      decoration: BoxDecoration(
        color: last ? AppColors.ink : AppColors.inactive,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.bar),
          bottom: Radius.circular(AppRadius.mark),
        ),
      ),
    );
  }
}

/// The average's dashed line across the chart, in [AppColors.line].
class ResultDashedLine extends CustomPainter {
  const ResultDashedLine();

  static const width = 1.5;
  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
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
  bool shouldRepaint(ResultDashedLine oldDelegate) => false;
}

/// The way into the character's talk (A10 spec 2, UxGoal report): the
/// character idle on a lime disc and a white floor at the left, its name
/// tag, "이번 판 이야기해 줄게! 할 말이 N개 있어.", and 이야기 듣기 and
/// 건너뛰기 (straight to the goal question). The buttons wait while the
/// talk loads.
class ResultCoachCard extends StatelessWidget {
  const ResultCoachCard({
    super.key,
    required this.entry,
    required this.onListen,
    required this.onSkip,
  });

  final ResultCoachEntry entry;
  final VoidCallback onListen;
  final VoidCallback onSkip;

  static const edge = 2.5;
  static const radius = 22.0;
  static const minHeight = 176.0;

  /// The room the character takes at the left.
  static const seatWidth = 128.0;
  static const _padding = 14.0;
  static const _discLeft = 12.0;
  static const _discTop = 22.0;
  static const _discSize = 104.0;
  static const figureScale = 0.82;

  /// Where the rig's feet land: the design's 140 x 160 box at (-6, -6),
  /// feet at (70, 150) of it.
  static const feet = Offset(64, 144);
  static const _rigFeet = Offset(70, 150);
  static const _floorLeft = 22.0;
  static const _floorTop = 140.0;
  static const _floorWidth = 84.0;
  static const _floorHeight = 12.0;
  static const _floorRadius = 6.0;
  static const _tagIndent = AppSpacing.s4;
  static const buttonHeight = 44.0;
  static const _buttonEdge = 2.0;
  static const _buttonRadius = 14.0;
  static const _playSize = 16.0;
  static const _skipSide = 6.0;

  /// The card's sentence.
  static List<CoachPiece> lineOf(ResultCoachEntry entry) => [
    CoachPiece('이번 판 이야기해 줄게${entry.ending}!'),
    if (entry.lineCount case final count?) ...[
      const CoachPiece(' 할 말이 '),
      CoachPiece('$count개', marked: true),
      const CoachPiece(' 있어.'),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ready = entry.lineCount != null;
    final pieces = lineOf(entry);
    final rig = CharacterRig.standard;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '캐릭터 피드백',
      child: Container(
        constraints: const BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.all(Radius.circular(radius)),
          border: Border.all(color: AppColors.ink, width: edge),
        ),
        child: Stack(
          children: [
            Positioned(
              left: _discLeft,
              top: _discTop,
              width: _discSize,
              height: _discSize,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: edge),
                ),
              ),
            ),
            Positioned(
              left: feet.dx - _rigFeet.dx * figureScale,
              top: feet.dy - _rigFeet.dy * figureScale,
              width: rig.boxWidth * figureScale,
              height: rig.boxHeight * figureScale,
              child: ExcludeSemantics(
                child: CharacterFigure(
                  key: const ValueKey('result-coach-character'),
                  characterId: entry.characterId,
                  scale: figureScale,
                ),
              ),
            ),
            Positioned(
              left: _floorLeft,
              top: _floorTop,
              width: _floorWidth,
              height: _floorHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(_floorRadius),
                  ),
                  border: Border.all(color: AppColors.ink, width: edge),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                seatWidth,
                _padding,
                _padding,
                _padding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: _tagIndent),
                    child: ExcludeSemantics(
                      child: CoachNameTag(name: entry.name, small: true),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Semantics(
                    label: '${entry.name}, ${pieces.map((p) => p.text).join()}',
                    child: ExcludeSemantics(
                      child: CoachMarkedText(
                        pieces: pieces,
                        style: text.coachCardLine,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: ready ? onListen : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(buttonHeight),
                            padding: EdgeInsets.zero,
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.ink,
                            disabledBackgroundColor: AppColors.border,
                            disabledForegroundColor: AppColors.textMuted,
                            side: const BorderSide(
                              color: AppColors.ink,
                              width: _buttonEdge,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(_buttonRadius),
                              ),
                            ),
                            textStyle: text.coachButton,
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('이야기 듣기', maxLines: 1),
                                SizedBox(width: _skipSide),
                                Icon(Icons.play_arrow_rounded, size: _playSize),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      TextButton(
                        onPressed: ready ? onSkip : null,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, buttonHeight),
                          padding: const EdgeInsets.symmetric(
                            horizontal: _skipSide,
                          ),
                          foregroundColor: AppColors.textSecondary,
                          textStyle: text.coachLink,
                        ),
                        child: const Text('건너뛰기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "자세 기록 표로 보기 ›" at the right under the character card: the form
/// feedback screen with its table (A10 spec 2).
class ResultFeedbackLink extends StatelessWidget {
  const ResultFeedbackLink({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const label = '자세 기록 표로 보기';
  static const _chevronSize = 14.0;
  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: onPressed,
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.chevron_right_rounded, size: _chevronSize),
        label: const Text(label),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: text.coachSmallBold,
        ),
      ),
    );
  }
}
