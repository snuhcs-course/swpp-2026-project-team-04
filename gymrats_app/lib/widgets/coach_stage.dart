import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/feedback/coach_script.dart';
import '../theme/app_theme.dart';
import '../viewmodels/coach_viewmodel.dart';
import 'battle_fx_motion.dart';
import 'character_figure.dart';
import 'coach_graphics.dart';
import 'coach_parts.dart';

/// The talk screen's layout (A10 spec 3, UxDlg variant A), at the design's
/// S22 values: the pill and 건너뛰기 at the top, the card under them, the
/// character in the middle with its feet behind the dialog box, the box
/// with the name tag, and the dots or the end buttons under it.
///
/// It only draws [state] and passes taps on. Top parts keep their place
/// from the top of the safe area, the box and what is under it from its
/// bottom, so a taller phone has more room around the character.
class CoachStage extends StatelessWidget {
  const CoachStage({
    super.key,
    required this.state,
    required this.voice,
    required this.summary,
    required this.onTap,
    required this.onSkip,
    required this.onChoose,
    required this.onRestart,
    required this.onLeave,
    this.arrowOn = true,
    this.reducedMotion = false,
  });

  final CoachState state;
  final CoachVoice voice;

  /// The pill, e.g. "스쿼트 · RepBot 중수 · 승리".
  final String summary;

  /// The dialog box.
  final VoidCallback onTap;

  /// 건너뛰기.
  final VoidCallback onSkip;

  /// A goal, or null for '사양할래'.
  final ValueChanged<GoalSuggestion?> onChoose;

  /// 처음부터 다시.
  final VoidCallback onRestart;

  /// 리포트로.
  final VoidCallback onLeave;

  /// The blinking "next" mark's phase (the screen toggles it).
  final bool arrowOn;

  /// Reduced motion: no bob, no blink, no sliding.
  final bool reducedMotion;

  // The design's numbers, from the top of the safe area (its 28 is 24
  // under a 24 status bar) and from the bottom of it.
  static const sideMargin = AppSpacing.s16;
  static const topBarTop = AppSpacing.s4;
  static const topBarHeight = 44.0;
  static const graphicTop = 60.0;
  static const choicesTop = 166.0;

  /// The highest the choices go when the room under [choicesTop] is short:
  /// just under the top bar.
  static const choicesRegionTop = topBarTop + topBarHeight + AppSpacing.s8;
  static const choicesRight = 14.0;
  static const choicesWidth = 226.0;
  static const choicesGap = AppSpacing.s8;
  static const boxSide = 14.0;
  static const boxHeight = 196.0;
  static const boxBottom = 86.0;
  static const belowBox = 20.0;
  static const buttonsBottom = AppSpacing.s16;
  static const buttonsHeight = 52.0;

  /// The character's feet are this far below the box's top edge.
  static const feetInBox = 22.0;

  /// The character's centre when it stands beside the choices.
  static const besideChoicesX = 84.0;

  /// Its sizes: alone on the disc, under a card, beside the choices.
  static const bigScale = 1.75;
  static const cardScale = 1.0;
  static const choiceScale = 1.2;

  /// The disc behind it when no card shows.
  static const discSize = 250.0;
  static const _discEdge = 3.0;
  static const _discRing = 14.0;

  /// How far the character rises every third letter.
  static const bob = 4.0;
  static const move = Duration(milliseconds: 300);

  /// The talk's text size is capped here so the box keeps its shape.
  static const maxTextScale = 1.5;

  /// The rig's box and where its feet are in it.
  static const _figureWidth = 140.0;
  static const _figureHeight = 160.0;
  static const _feetY = 150.0;

  /// The box's height at [scaler]: four lines grow with the text.
  static double boxHeightAt(TextScaler scaler, TextStyle line) {
    final size = line.fontSize!;
    final lineHeight = size * line.height!;
    final grown = scaler.scale(size) / size;
    return boxHeight + 4 * lineHeight * math.max(0, grown - 1);
  }

  /// The hint under the dots.
  static String hintOf(CoachState state) {
    if (state.onQuestion) {
      return state.fullyShown ? '위에서 하나 골라 줘' : '대화창을 누르면 바로 다 보여요';
    }
    return '대화창을 누르면 다음으로';
  }

  /// The character's pose for [pose].
  static BattlePose poseOf(CoachPose pose) => switch (pose) {
    CoachPose.idle => BattlePose.idle,
    CoachPose.win => BattlePose.win,
    CoachPose.hit => BattlePose.hit,
  };

  @override
  Widget build(BuildContext context) {
    final line = state.line;
    if (line == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final text = Theme.of(context).textTheme;
    final boxH = boxHeightAt(MediaQuery.textScalerOf(context), text.coachLine);
    final graphic = state.ended ? null : line.graphic;
    final choices = state.showsChoices;
    final duration = reducedMotion ? Duration.zero : move;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final boxTop = box.maxHeight - boxBottom - boxH;
        final feet = boxTop + feetInBox;
        final x = choices ? besideChoicesX : width / 2;
        final scale = choices
            ? choiceScale
            : graphic == null
            ? bigScale
            : cardScale;
        final rising =
            !reducedMotion && !state.fullyShown && (state.revealed ~/ 3).isOdd;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (graphic == null)
              AnimatedPositioned(
                duration: duration,
                left: x - discSize / 2,
                top: feet - discSize,
                width: discSize,
                height: discSize,
                child: const ExcludeSemantics(child: _Disc()),
              ),
            AnimatedPositioned(
              duration: duration,
              left: x - _figureWidth / 2,
              top: feet - _feetY,
              width: _figureWidth,
              height: _figureHeight,
              child: ExcludeSemantics(
                child: Transform.translate(
                  offset: Offset(0, rising ? -bob : 0),
                  child: AnimatedScale(
                    duration: duration,
                    scale: scale,
                    alignment: const Alignment(
                      0,
                      _feetY / _figureHeight * 2 - 1,
                    ),
                    child: CharacterFigure(
                      key: const ValueKey('coach-character'),
                      characterId: voice.characterId,
                      pose: poseOf(line.pose),
                    ),
                  ),
                ),
              ),
            ),
            if (graphic != null)
              Positioned(
                left: sideMargin,
                right: sideMargin,
                top: graphicTop,
                child: CoachGraphicCard(graphic: graphic),
              ),
            if (choices)
              Positioned(
                left: choicesRight,
                right: choicesRight,
                top: choicesRegionTop,
                // Always above the dialog box: on a short screen or with
                // larger text they move up, and scroll when even that is
                // short.
                bottom: math.min(
                  box.maxHeight - boxTop + choicesGap,
                  box.maxHeight - choicesRegionTop,
                ),
                child: CustomSingleChildLayout(
                  delegate: _ChoicesLayout(
                    width: choicesWidth,
                    top: choicesTop - choicesRegionTop,
                  ),
                  child: SingleChildScrollView(
                    child: _Choices(
                      suggestions: state.script!.suggestions,
                      onChoose: onChoose,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: boxSide,
              right: boxSide,
              top: boxTop,
              height: boxH,
              child: _DialogBox(
                name: voice.name,
                line: line,
                pieces: state.shownPieces,
                fullyShown: state.fullyShown,
                arrow:
                    state.fullyShown &&
                    !state.onQuestion &&
                    !state.ended &&
                    (reducedMotion || arrowOn),
                onTap: _boxTap(),
              ),
            ),
            if (!state.ended)
              Positioned(
                left: 0,
                right: 0,
                top: boxTop + boxH + belowBox,
                child: Column(
                  children: [
                    ExcludeSemantics(
                      child: CoachPageDots(
                        count: state.pageCount,
                        current: state.index,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      hintOf(state),
                      style: text.coachSmall.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Positioned(
                left: boxSide,
                right: boxSide,
                bottom: buttonsBottom,
                height: buttonsHeight,
                child: _EndButtons(onRestart: onRestart, onLeave: onLeave),
              ),
            Positioned(
              left: sideMargin,
              right: sideMargin,
              top: topBarTop,
              height: topBarHeight,
              child: _TopBar(
                summary: summary,
                onSkip: state.ended ? null : onSkip,
              ),
            ),
          ],
        );
      },
    );
  }

  /// The box is a button only when a tap does something: while a line
  /// types, or to go on from a line that is out (not the question, not
  /// the end).
  VoidCallback? _boxTap() {
    if (!state.fullyShown) return onTap;
    if (state.onQuestion || state.ended) return null;
    return onTap;
  }
}

/// The white disc behind the character: an ink edge, a lime ring and an
/// ink ring inside it (the design's two inset shadows).
class _Disc extends StatelessWidget {
  const _Disc();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CoachStage._discRing),
    decoration: BoxDecoration(
      color: AppColors.accent,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.ink, width: CoachStage._discEdge),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: CoachStage._discEdge),
      ),
    ),
  );
}

/// The pill and 건너뛰기 (hidden once the talk has ended: [onSkip] null).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.summary, required this.onSkip});

  final String summary;
  final VoidCallback? onSkip;

  static const _pillEdge = 1.0;
  static const _pillPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s12,
    vertical: AppSpacing.s4,
  );
  static const _skipEdge = 1.5;
  static const _skipIcon = 18.0;
  static const _skipPadding = EdgeInsets.only(
    left: AppSpacing.s16,
    right: _skipRight,
  );
  static const _skipRight = 14.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onSkip = this.onSkip;
    return Row(
      children: [
        Flexible(
          child: Container(
            padding: _pillPadding,
            decoration: const ShapeDecoration(
              color: AppColors.card,
              shape: StadiumBorder(
                side: BorderSide(color: AppColors.border, width: _pillEdge),
              ),
            ),
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.coachSmallBold.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        if (onSkip != null)
          OutlinedButton(
            onPressed: onSkip,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, CoachStage.topBarHeight),
              padding: _skipPadding,
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.ink, width: _skipEdge),
              shape: const StadiumBorder(),
              textStyle: text.coachButton,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('건너뛰기'),
                SizedBox(width: AppSpacing.s4),
                Icon(Icons.fast_forward_rounded, size: _skipIcon),
              ],
            ),
          ),
      ],
    );
  }
}

/// Puts the choices [width] wide at the right of their room, [top] down
/// when they fit there, else as low as fits, else at the top (and they
/// scroll).
class _ChoicesLayout extends SingleChildLayoutDelegate {
  const _ChoicesLayout({required this.width, required this.top});

  final double width;
  final double top;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final shown = math.min(width, constraints.maxWidth);
    return BoxConstraints(
      minWidth: shown,
      maxWidth: shown,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    size.width - childSize.width,
    math.max(0, math.min(top, size.height - childSize.height)),
  );

  @override
  bool shouldRelayout(_ChoicesLayout oldDelegate) =>
      oldDelegate.width != width || oldDelegate.top != top;
}

/// The two goals and '사양할래'.
class _Choices extends StatelessWidget {
  const _Choices({required this.suggestions, required this.onChoose});

  final List<GoalSuggestion> suggestions;
  final ValueChanged<GoalSuggestion?> onChoose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final goal in suggestions) ...[
        CoachChoiceButton(
          title: goal.title,
          subtitle: goal.subtitle,
          onPressed: () => onChoose(goal),
        ),
        const SizedBox(height: CoachStage.choicesGap),
      ],
      CoachChoiceButton(
        title: '사양할래',
        decline: true,
        onPressed: () => onChoose(null),
      ),
    ],
  );
}

/// The dialog box: white, a thick ink edge with uneven corners, a solid
/// shadow under it, the name tag over its top left, the line, and the lime
/// "next" mark at the bottom.
class _DialogBox extends StatelessWidget {
  const _DialogBox({
    required this.name,
    required this.line,
    required this.pieces,
    required this.fullyShown,
    required this.arrow,
    required this.onTap,
  });

  final String name;
  final CoachLine line;
  final List<CoachPiece> pieces;
  final bool fullyShown;
  final bool arrow;
  final VoidCallback? onTap;

  static const _edge = 3.0;
  static const _shadow = 0.12;
  static const _shadowDrop = 6.0;
  static const _shape = BorderRadius.only(
    topLeft: Radius.elliptical(36, 30),
    topRight: Radius.elliptical(30, 36),
    bottomRight: Radius.elliptical(38, 30),
    bottomLeft: Radius.elliptical(30, 38),
  );
  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.s24,
    AppSpacing.s32,
    AppSpacing.s24,
    _bottomPadding,
  );
  static const _bottomPadding = 34.0;
  static const _tagLeft = 18.0;
  static const _tagTop = -24.0;
  static const _tagTilt = -4 * math.pi / 180;
  static const _arrowWidth = 22.0;
  static const _arrowHeight = 16.0;
  static const _arrowBottom = 10.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onTap = this.onTap;
    return Semantics(
      container: true,
      button: onTap != null,
      label: onTap == null ? null : (fullyShown ? '다음' : '전부 보기'),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: _shape,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: _shadow),
                    offset: const Offset(0, _shadowDrop),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: AppColors.card,
              shape: const RoundedRectangleBorder(
                borderRadius: _shape,
                side: BorderSide(color: AppColors.ink, width: _edge),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('coach-dialog'),
                onTap: onTap,
                excludeFromSemantics: true,
                child: Padding(
                  padding: _padding,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      // Read once, whole, when the last letter is out.
                      label: fullyShown ? '$name, ${line.text}' : '',
                      child: ExcludeSemantics(
                        child: CoachMarkedText(
                          pieces: pieces,
                          style: text.coachLine,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: _tagLeft,
            top: _tagTop,
            child: ExcludeSemantics(
              child: Transform.rotate(
                angle: _tagTilt,
                child: CoachNameTag(name: name),
              ),
            ),
          ),
          if (arrow)
            const Positioned(
              left: 0,
              right: 0,
              bottom: _arrowBottom,
              child: ExcludeSemantics(
                child: Center(
                  child: CustomPaint(
                    key: ValueKey('coach-next-mark'),
                    size: Size(_arrowWidth, _arrowHeight),
                    painter: _NextMarkPainter(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The lime down triangle with an ink edge.
class _NextMarkPainter extends CustomPainter {
  const _NextMarkPainter();

  static const _edge = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    // The design's path M2 2h18L11 14z in a 22 x 16 box.
    final unitX = size.width / 22, unitY = size.height / 16;
    final path = Path()
      ..moveTo(2 * unitX, 2 * unitY)
      ..lineTo(20 * unitX, 2 * unitY)
      ..lineTo(11 * unitX, 14 * unitY)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = AppColors.accent)
      ..drawPath(
        path,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _edge
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_NextMarkPainter oldDelegate) => false;
}

/// 처음부터 다시 (white) and 리포트로 (ink, a lime arrow).
class _EndButtons extends StatelessWidget {
  const _EndButtons({required this.onRestart, required this.onLeave});

  final VoidCallback onRestart;
  final VoidCallback onLeave;

  static const _edge = 1.5;
  static const _radius = 16.0;
  static const _arrowSize = 18.0;
  static const _gap = 10.0;
  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(_radius)),
  );

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.coachChoice;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onRestart,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.ink, width: _edge),
              shape: _shape,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('처음부터 다시', maxLines: 1, style: style),
            ),
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          child: FilledButton(
            onPressed: onLeave,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.onInk,
              shape: _shape,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '리포트로',
                    maxLines: 1,
                    style: style.copyWith(color: AppColors.onInk),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: _arrowSize,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
