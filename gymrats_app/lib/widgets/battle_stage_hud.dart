import 'package:flutter/material.dart';

import '../models/feedback_goal.dart';
import '../services/feedback/goal_progress.dart';
import '../theme/app_theme.dart';
import 'battle_banner.dart';
import 'battle_fx_motion.dart';

/// The top of the battle stage: both nicknames, the clock with its chip, the
/// two game scores, the valid rep counts between them with the user's goal
/// chip under them, and the time bar.
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
    this.countsOpacity = 1,
    this.topOpacity = 1,
    this.goal,
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

  /// How strongly the valid rep counts show: not at all while setting up,
  /// where the ready chips take their place; a screen reader does not get
  /// them then either.
  final double countsOpacity;

  /// How strongly the names, the clock with its chip, the two scores and
  /// the time bar show: not at all while setting up, where the top area
  /// holds only the cue board and the ready chips (A12 spec 2); a screen
  /// reader does not get them then either.
  final double topOpacity;

  /// The user's goal for this battle, as a chip under the valid counts
  /// (A11 spec 5); null draws none. It shows with the counts: while setting
  /// up the ready chips are in its place (task.md W11 decision 7).
  final GoalProgress? goal;

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

  /// The goal chip's distance under the valid counts.
  static const _goalGap = 3.0;
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
    final top = topOpacity.clamp(0.0, 1.0);
    Widget shown(Widget child) => Opacity(opacity: top, child: child);
    return MediaQuery.withNoTextScaling(
      child: Stack(
        children: [
          Positioned(
            left: _side,
            right: _side,
            top: _nameTop,
            height: _nameHeight,
            child: shown(
              Row(
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
          ),
          // Centered on the stage whatever the names' lengths.
          Positioned(
            left: 0,
            right: 0,
            top: _nameTop,
            height: _nameHeight,
            child: shown(
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    clockText(secondsLeft),
                    style: text.stageClock,
                    semanticsLabel:
                        '남은 시간 ${secondsLeft < 0 ? 0 : secondsLeft}초',
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
          ),
          Positioned(
            left: _scoreSide,
            top: _scoreTop,
            child: shown(
              Transform.scale(
                scale: myScoreBump,
                alignment: Alignment.bottomLeft,
                child: _score(text, myScore, AppColors.accent, '내 점수'),
              ),
            ),
          ),
          Positioned(
            right: _scoreSide,
            top: _scoreTop,
            child: shown(
              Transform.scale(
                scale: opponentScoreBump,
                alignment: Alignment.bottomRight,
                child: _score(text, opponentScore, AppColors.opponent, '상대 점수'),
              ),
            ),
          ),
          if (countsOpacity > 0)
            Positioned(
              left: 0,
              right: 0,
              top: _countTop,
              child: Opacity(
                opacity: countsOpacity.clamp(0.0, 1.0),
                child: Column(
                  children: [
                    _counts(text),
                    if (goal case final goal?) ...[
                      const SizedBox(height: _goalGap),
                      BattleGoalChip(goal: goal, late: elapsed >= 0.5),
                    ],
                  ],
                ),
              ),
            ),
          Positioned(
            left: _side,
            right: _side,
            top: _barTop,
            height: _barHeight,
            child: shown(
              ExcludeSemantics(
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
          ),
        ],
      ),
    );
  }

  /// "유효 횟수" over the two valid rep counts, read out as one.
  Widget _counts(TextTheme text) => Semantics(
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
              _count(text, opponentReps, opponentRepsBump, TextAlign.left),
            ],
          ),
        ],
      ),
    ),
  );

  /// A nickname beside its color swatch: the user's swatch first, the
  /// opponent's last. A name wider than [_nameWidth] ends in "…" and keeps
  /// to its swatch: the user's from the left, the opponent's from the right.
  /// A screen reader gets all of it, and whose it is ([who]), which the eye
  /// reads from the swatch's color and side.
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
        textAlign: mine ? TextAlign.left : TextAlign.right,
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

/// The user's goal on the battle HUD (A11 spec 5, UxGoal battle): its words
/// (e.g. "미션 12/20") on a white pill filled with lime from the left as far
/// as the goal has come. Reached, it is all lime with a check before the
/// words; a [GoalKind.maxRejects] goal past its number is red. In the
/// stage's design points, like the rest of the HUD.
class BattleGoalChip extends StatelessWidget {
  const BattleGoalChip({super.key, required this.goal, required this.late});

  final GoalProgress goal;

  /// Whether the round is in its later half, for a [GoalKind.lateReps]
  /// goal's words.
  final bool late;

  static const height = 20.0;
  static const _edge = 1.5;

  /// The design's padding (8 beside) lies inside its edge; here the edge is
  /// painted over the box, so the box makes room for it.
  static const _side = 8.0 + _edge;
  static const _check = 11.0;
  static const _checkGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reached = goal.reached;
    return Semantics(
      container: true,
      label: goal.chipLabel(late: late),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: const ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(color: AppColors.ink, width: _edge),
              ),
            ),
            child: ClipPath(
              clipper: const ShapeBorderClipper(shape: StadiumBorder()),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: goal.over ? AppColors.danger : AppColors.card,
                    ),
                  ),
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: goal.fill,
                      child: const ColoredBox(color: AppColors.accent),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _side),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (reached) ...[
                          const Icon(
                            Icons.check_rounded,
                            size: _check,
                            color: AppColors.ink,
                          ),
                          const SizedBox(width: _checkGap),
                        ],
                        Text(
                          goal.chipText(late: late),
                          maxLines: 1,
                          softWrap: false,
                          style: text.goalChip,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
