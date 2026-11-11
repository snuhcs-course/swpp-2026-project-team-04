import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'battle_banner.dart';
import 'battle_fx_motion.dart';

/// The top of the battle stage: both nicknames, the clock with its chip, the
/// two game scores, the valid rep counts between them, and the time bar.
///
/// It fills the stage's 360 x 390 design points and is laid out in them; the
/// stage sizes it with everything else, so it does not follow the system
/// text size. It holds still while the fighters' layer shakes.
class BattleStageHud extends StatelessWidget {
  const BattleStageHud({
    super.key,
    required this.myName,
    required this.opponentName,
    required this.secondsLeft,
    required this.elapsed,
    required this.chip,
    required this.myScore,
    required this.opponentScore,
    required this.myReps,
    required this.opponentReps,
    this.myScoreBump = 1,
    this.opponentScoreBump = 1,
    this.myRepsBump = 1,
    this.opponentRepsBump = 1,
  });

  final String myName;
  final String opponentName;

  /// Whole seconds left, shown as "0:23".
  final int secondsLeft;

  /// How much of the round has passed, from 0 to 1, for the time bar.
  final double elapsed;

  /// The chip beside the clock ([BattleFx.chip]); null hides it.
  final ({String text, BattleFxTone tone})? chip;

  final int myScore;
  final int opponentScore;

  /// The valid rep counts: the user's on the left.
  final int myReps;
  final int opponentReps;

  /// What the scores and the counts are sized by while they bump.
  final double myScoreBump;
  final double opponentScoreBump;
  final double myRepsBump;
  final double opponentRepsBump;

  static const _side = 12.0;
  static const _nameTop = 26.0;
  static const _nameHeight = 28.0;
  static const _nameWidth = 80.0;
  static const _swatch = 12.0;
  static const _gap = 6.0;
  static const _chipEdge = 1.5;

  /// The room around the chip's text. The design's edge lies outside its
  /// padding (8 beside, 2 above and below); here it is painted inside the
  /// box, so the box makes room for it.
  static const _chipSide = 8.0 + _chipEdge;
  static const _chipTop = 2.0 + _chipEdge;
  static const _scoreTop = 54.0;

  /// The score's box reaches 2 past the side margin.
  static const _scoreSide = _side - 2;
  static const _scorePadding = 6.0;

  /// The score's letters sit 3 closer than they are wide. Flutter takes half
  /// of that off each side of a letter, the design's browser all of it off
  /// the letter's end, so the number is moved back by the half.
  static const _scoreNudge = 1.5;
  static const _scoreBandHeight = 32.0;
  static const _scoreBandBottom = 6.0;
  static const _countTop = 68.0;
  static const _countLabelGap = 2.0;
  static const _countWidth = 22.0;
  static const _countGap = 5.0;
  static const _barTop = 131.0;
  static const _barHeight = 5.0;

  /// "0:23" for [seconds] left.
  static String clockText(int seconds) {
    final left = seconds < 0 ? 0 : seconds;
    return '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final chip = this.chip;
    return MediaQuery.withNoTextScaling(
      child: Stack(
        children: [
          Positioned(
            left: _side,
            right: _side,
            top: _nameTop,
            height: _nameHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _name(text, myName, AppColors.accent, who: '나', mine: true),
                _name(
                  text,
                  opponentName,
                  AppColors.opponent,
                  who: '상대',
                  mine: false,
                ),
              ],
            ),
          ),
          // Centered on the stage whatever the names' lengths.
          Positioned(
            left: 0,
            right: 0,
            top: _nameTop,
            height: _nameHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  clockText(secondsLeft),
                  style: text.stageClock,
                  semanticsLabel: '남은 시간 ${secondsLeft < 0 ? 0 : secondsLeft}초',
                ),
                if (chip != null) ...[
                  const SizedBox(width: _gap),
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: chip.tone.color,
                      shape: const StadiumBorder(
                        side: BorderSide(
                          color: AppColors.ink,
                          width: _chipEdge,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _chipSide,
                        vertical: _chipTop,
                      ),
                      child: Text(chip.text, style: text.stageChip),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: _scoreSide,
            top: _scoreTop,
            child: Transform.scale(
              scale: myScoreBump,
              alignment: Alignment.bottomLeft,
              child: _score(text, myScore, AppColors.accent, '내 점수'),
            ),
          ),
          Positioned(
            right: _scoreSide,
            top: _scoreTop,
            child: Transform.scale(
              scale: opponentScoreBump,
              alignment: Alignment.bottomRight,
              child: _score(text, opponentScore, AppColors.opponent, '상대 점수'),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _countTop,
            child: Semantics(
              container: true,
              label: '유효 횟수 나 $myReps회, 상대 $opponentReps회',
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    Text('유효 횟수', style: text.stageCountLabel),
                    const SizedBox(height: _countLabelGap),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        _count(text, myReps, myRepsBump, TextAlign.right),
                        const SizedBox(width: _countGap),
                        Text(':', style: text.stageCount),
                        const SizedBox(width: _countGap),
                        _count(
                          text,
                          opponentReps,
                          opponentRepsBump,
                          TextAlign.left,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: _side,
            right: _side,
            top: _barTop,
            height: _barHeight,
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.mark),
                ),
                child: ColoredBox(
                  color: AppColors.border,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: elapsed.clamp(0.0, 1.0),
                    child: const ColoredBox(color: AppColors.ink),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A nickname beside its color swatch: the user's swatch first, the
  /// opponent's last. A name wider than [_nameWidth] ends in "…"; a screen
  /// reader gets all of it, and whose it is ([who]), which the eye reads
  /// from the swatch's color and side.
  Widget _name(
    TextTheme text,
    String name,
    Color color, {
    required String who,
    required bool mine,
  }) {
    final swatch = SizedBox.square(
      dimension: _swatch,
      child: DecoratedBox(decoration: AppHighlight.swatch(color)),
    );
    final label = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _nameWidth),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        semanticsLabel: '$who $name',
        style: text.stageName,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: mine
          ? [swatch, const SizedBox(width: _gap), label]
          : [label, const SizedBox(width: _gap), swatch],
    );
  }

  /// A game score over a slanted band of the player's [color].
  Widget _score(TextTheme text, int score, Color color, String who) {
    final style = text.stageScore;
    return Semantics(
      container: true,
      label: '$who $score점',
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: _scoreBandBottom,
              height: _scoreBandHeight,
              child: Transform(
                transform: AppHighlight.battleSlant,
                alignment: Alignment.center,
                child: ColoredBox(color: color),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: _scorePadding + _scoreNudge,
                right: _scorePadding - _scoreNudge,
              ),
              // The line's exact height: a text box alone is rounded up to
              // whole points, which would lower the band under it.
              child: SizedBox(
                height: style.fontSize! * style.height!,
                child: Text('$score', maxLines: 1, style: style),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A valid rep count in its own cell, so the ":" between the two stays in
  /// the middle of the stage whatever the numbers are.
  Widget _count(TextTheme text, int reps, double bump, TextAlign align) {
    return Transform.scale(
      scale: bump,
      // The design grows the number around a point low in its line.
      alignment: const Alignment(0, 0.7),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _countWidth),
        child: Text('$reps', textAlign: align, style: text.stageCount),
      ),
    );
  }
}
