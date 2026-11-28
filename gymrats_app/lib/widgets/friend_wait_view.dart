import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../theme/app_theme.dart';
import 'arcade_parts.dart';
import 'battle_stage_model.dart';
import 'character_figure.dart';
import 'lobby_parts.dart';

/// Where a friend battle's wait stands (A11 spec 5, `FrWait` `state`).
enum FriendWaitState {
  /// I invited and wait for the friend to accept (CHALLENGE).
  waiting,

  /// I accepted; we wait to be paired (MATCHING).
  joining,

  /// The friend declined (DECLINED).
  declined,

  /// My invite's minute ran out (TIME OUT).
  expired,

  /// It ended for another reason (CLOSED): [FriendWaitView.closedTitle].
  closed;

  /// The wait is over.
  bool get ended => this != waiting && this != joining;
}

/// The friend battle's waiting room (A11 spec 5, `FrWait`): the back pill
/// and a slanted band over the exercise, a two-line title, then the match
/// board of MATCH FOUND (2-A3): me on lime above, the friend below ("?",
/// or their character once I accepted), and a circle between them with the
/// minute left on a ring, ✕ or VS. Under it, how to set up the phone while
/// waiting, or, once over, 다시 신청 (when I invited) and 친구 목록으로.
class FriendWaitView extends StatelessWidget {
  const FriendWaitView({
    super.key,
    required this.state,
    required this.friendName,
    required this.myName,
    required this.myCharacter,
    required this.exercise,
    required this.duration,
    required this.secondsLeft,
    required this.onBack,
    required this.onToList,
    this.friendCharacter,
    this.onRetry,
    this.closedTitle,
  });

  final FriendWaitState state;
  final String friendName, myName;
  final String myCharacter;

  /// The inviter's character, standing in for "?" once I accepted.
  final String? friendCharacter;
  final ExerciseType exercise;
  final Duration duration;

  /// The whole seconds left of my invite's minute, from its `expires_at`.
  final int secondsLeft;

  /// 신청 취소 / 나가기.
  final VoidCallback onBack;

  /// "{friend}님에게 다시 신청": only when I invited and it is over.
  final VoidCallback? onRetry;
  final VoidCallback onToList;

  /// What the title says when [FriendWaitState.closed]: the end's words.
  final String? closedTitle;

  /// Inside the safe area: the design's 40 less its 28 high status bar.
  static const padding = EdgeInsets.fromLTRB(
    AppSpacing.s20,
    _top,
    AppSpacing.s20,
    AppSpacing.s24,
  );
  static const _top = 12.0;
  static const _gap = AppSpacing.s16;

  /// The board's least height, so the circle and the two names fit.
  static const boardMinHeight = 220.0;

  /// The band's word for [state].
  static String tagOf(FriendWaitState state) => switch (state) {
    FriendWaitState.waiting => 'CHALLENGE',
    FriendWaitState.joining => 'MATCHING',
    FriendWaitState.declined => 'DECLINED',
    FriendWaitState.expired => 'TIME OUT',
    FriendWaitState.closed => 'CLOSED',
  };

  /// The title for [state] with [friend] (two lines, as designed).
  static String titleOf(FriendWaitState state, String friend, String? closed) =>
      switch (state) {
        FriendWaitState.waiting => '$friend님의\n수락을 기다리는 중',
        FriendWaitState.joining => '$friend님을\n기다리는 중',
        FriendWaitState.declined => '$friend님이\n대결 신청을 거절했어요',
        FriendWaitState.expired => '$friend님이\n1분 안에 수락하지 않았어요',
        FriendWaitState.closed => closed ?? '',
      };

  /// The placement words for [exercise], as the matching screen's card has
  /// them (`matching_screen.dart` `_GuideCard`, hand-broken lines).
  static String tipOf(ExerciseType exercise) => switch (exercise) {
    ExerciseType.pushUp => '휴대폰을 머리 앞 약 1m 바닥에 세워\n화면이 나를 보게 두세요.',
    ExerciseType.squat =>
      '휴대폰을 세로로 세워 내 앞 2~3m에\n'
          '두세요. 의자나 선반 위면 더 좋아요.\n'
          '머리부터 발목까지\n'
          '화면에 들어와야 해요.',
  };

  /// The matching screen's card's line.
  static const prepTitle = '기다리는 동안 자리를 준비해 두세요';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, box.maxHeight - padding.vertical),
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopRow(
                  state: state,
                  exercise: exercise,
                  duration: duration,
                  onBack: onBack,
                ),
                const SizedBox(height: _gap),
                Semantics(
                  liveRegion: true,
                  child: LobbySkew(
                    degrees: 8,
                    child: Text(
                      titleOf(state, friendName, closedTitle),
                      style: text.friendWaitTitle,
                    ),
                  ),
                ),
                const SizedBox(height: _gap),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: boardMinHeight,
                    ),
                    child: _Board(
                      state: state,
                      myName: myName,
                      myCharacter: myCharacter,
                      friendName: friendName,
                      friendCharacter: friendCharacter,
                      secondsLeft: secondsLeft,
                    ),
                  ),
                ),
                const SizedBox(height: _gap),
                if (state.ended)
                  _EndButtons(
                    friendName: friendName,
                    onRetry: onRetry,
                    onToList: onToList,
                  )
                else
                  _PrepCard(exercise: exercise),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The back pill at the left; the band and "스쿼트 · 30초" at the right.
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.state,
    required this.exercise,
    required this.duration,
    required this.onBack,
  });

  final FriendWaitState state;
  final ExerciseType exercise;
  final Duration duration;
  final VoidCallback onBack;

  static const _pill = 44.0;
  static const _pillCorners = 22.0;
  static const _pillPadding = EdgeInsets.fromLTRB(
    AppSpacing.s12,
    0,
    AppSpacing.s16,
    0,
  );
  static const _edge = 1.5;
  static const _icon = 18.0;
  static const _iconStroke = 2.4;
  static const _bandPadding = EdgeInsets.symmetric(
    horizontal: _bandSide,
    vertical: _bandOver,
  );
  static const _bandSide = 10.0;
  static const _bandOver = 1.0;
  static const _bandSkew = 12.0;
  static const _infoGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final waiting = state == FriendWaitState.waiting;
    final quiet = state.ended;
    return Row(
      children: [
        OutlinedButton(
          onPressed: onBack,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, _pill),
            padding: _pillPadding,
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.ink, width: _edge),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_pillCorners),
            ),
            textStyle: text.friendWaitBack,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (waiting)
                const ArcadeGlyphIcon(
                  ArcadeGlyph.cross,
                  size: _icon,
                  strokeWidth: _iconStroke,
                )
              else
                const _Chevron(size: _icon, stroke: _iconStroke),
              const SizedBox(width: AppSpacing.s8),
              Text(waiting ? '신청 취소' : '나가기'),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Stack(
                children: [
                  Positioned.fill(
                    child: LobbySkew(
                      degrees: _bandSkew,
                      alignment: Alignment.center,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: quiet ? FriendColors.quiet : AppColors.accent,
                          border: Border.all(
                            color: AppColors.ink,
                            width: _edge,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: _bandPadding,
                    child: Text(
                      FriendWaitView.tagOf(state),
                      maxLines: 1,
                      softWrap: false,
                      style: text.friendWaitTag,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _infoGap),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${exercise.koreanName} · '),
                    TextSpan(
                      text: '${duration.inSeconds}',
                      style: text.friendWaitInfoNumber,
                    ),
                    const TextSpan(text: '초'),
                  ],
                ),
                style: text.friendWaitInfo,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "‹": a stroked chevron, the design's back icon.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.size, required this.stroke});

  final double size, stroke;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ChevronPainter(stroke));
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.stroke);

  final double stroke;

  /// The design's 24-point box: M15 6 l-6 6 6 6.
  static const _box = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _box, size.height / _box)
      ..drawPath(
        Path()
          ..moveTo(15, 6)
          ..lineTo(9, 12)
          ..lineTo(15, 18),
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}

/// MATCH FOUND's board: my lime cell over the friend's, an ink line
/// between them and the circle in the middle.
class _Board extends StatelessWidget {
  const _Board({
    required this.state,
    required this.myName,
    required this.myCharacter,
    required this.friendName,
    required this.friendCharacter,
    required this.secondsLeft,
  });

  final FriendWaitState state;
  final String myName, myCharacter, friendName;
  final String? friendCharacter;
  final int secondsLeft;

  static const _edge = 2.0;
  static const _corners = 22.0;
  static const _line = 3.0;

  @override
  Widget build(BuildContext context) {
    final ended = state.ended;
    final friend = friendCharacter;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_corners),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Cell(
                  color: AppColors.accent,
                  mine: true,
                  role: '나',
                  name: myName,
                  figure: _Standing(id: myCharacter, side: BattleSide.me),
                ),
              ),
              const SizedBox(
                height: _line,
                child: ColoredBox(color: AppColors.ink),
              ),
              Expanded(
                child: _Cell(
                  color: ended ? FriendColors.quiet : AppColors.opponent,
                  mine: false,
                  role: '친구',
                  name: friendName,
                  faded: ended,
                  figure: state == FriendWaitState.joining && friend != null
                      ? _Standing(
                          id: friend,
                          side: BattleSide.opponent,
                          mirror: true,
                        )
                      : null,
                ),
              ),
            ],
          ),
          Center(
            child: _Circle(state: state, secondsLeft: secondsLeft),
          ),
        ],
      ),
    );
  }
}

/// One player's cell: the [role] pill and [name] on the side away from the
/// figure; the figure (or the friend's "?") on a white pad in the corner.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.color,
    required this.mine,
    required this.role,
    required this.name,
    required this.figure,
    this.faded = false,
  });

  final Color color;

  /// Mine: the figure at the bottom left; the friend's at the bottom right.
  final bool mine;
  final String role, name;

  /// The figure; null shows "?".
  final Widget? figure;

  /// An ended wait dims the friend's pad and "?".
  final bool faded;

  static const _padSide = 12.0;
  static const _padBottom = 14.0;
  static const _pad = Size(116, 16);
  static const _padCorners = 7.0;
  static const _padEdge = 3.0;
  static const _figureBottom = 20.0;
  static const _mysteryBottom = 22.0;
  static const _mystery = Size(116, 150);
  static const _fade = 0.45;

  /// The words stay clear of the figure's 146.
  static const _wordsAway = 146.0;
  static const _wordsGap = 6.0;
  static const _pillPadding = EdgeInsets.symmetric(
    horizontal: _pillSide,
    vertical: _pillOver,
  );
  static const _pillSide = 10.0;
  static const _pillOver = 1.0;
  static const _pillEdge = 1.5;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final figure = this.figure;
    final opacity = faded ? _fade : 1.0;
    return ColoredBox(
      color: color,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: mine ? _padSide : null,
            right: mine ? null : _padSide,
            bottom: _padBottom,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: _pad.width,
                height: _pad.height,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(_padCorners),
                  border: Border.all(color: AppColors.ink, width: _padEdge),
                ),
              ),
            ),
          ),
          if (figure != null)
            Positioned(
              left: mine ? 0 : null,
              right: mine ? null : 0,
              bottom: _figureBottom,
              child: figure,
            )
          else
            Positioned(
              right: _padSide,
              bottom: _mysteryBottom,
              child: Opacity(
                opacity: opacity,
                child: ExcludeSemantics(
                  child: SizedBox.fromSize(
                    size: _mystery,
                    child: FittedBox(
                      child: Stack(
                        children: [
                          Text(
                            '?',
                            textScaler: TextScaler.noScaling,
                            style: text.friendMysteryEdge,
                          ),
                          Text(
                            '?',
                            textScaler: TextScaler.noScaling,
                            style: text.friendMystery.copyWith(
                              color: AppColors.card,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                left: mine ? _wordsAway : AppSpacing.s16,
                right: mine ? AppSpacing.s16 : _wordsAway,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: _pillPadding,
                    decoration: const ShapeDecoration(
                      color: AppColors.card,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: AppColors.ink,
                          width: _pillEdge,
                        ),
                      ),
                    ),
                    child: Text(role, style: text.friendPill),
                  ),
                  const SizedBox(height: _wordsGap),
                  Text(
                    name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: text.friendWaitName,
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

/// A character standing in its 140 x 160 box, idling, edged white; facing
/// left with [mirror].
class _Standing extends StatelessWidget {
  const _Standing({required this.id, required this.side, this.mirror = false});

  final String id;
  final BattleSide side;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    Widget figure = ArcadeWhiteOutline(
      child: CharacterIdleFigure(characterId: id, side: side),
    );
    if (mirror) figure = Transform.flip(flipX: true, child: figure);
    return ExcludeSemantics(child: figure);
  }
}

/// The white circle in the board's middle: the ring and the seconds while
/// I wait for an accept (and 0 when it ran out), VS once I accepted, ✕
/// otherwise.
class _Circle extends StatelessWidget {
  const _Circle({required this.state, required this.secondsLeft});

  final FriendWaitState state;
  final int secondsLeft;

  static const _size = 92.0;
  static const _edge = 3.6;
  static const _cross = 40.0;
  static const _crossStroke = 3.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final left = state == FriendWaitState.expired
        ? 0
        : secondsLeft.clamp(0, FriendWaitRing.minute);
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: switch (state) {
        FriendWaitState.waiting || FriendWaitState.expired => Stack(
          alignment: Alignment.center,
          children: [
            FriendWaitRing(seconds: left),
            Text(
              '$left',
              textScaler: TextScaler.noScaling,
              style: text.friendSeconds,
            ),
          ],
        ),
        FriendWaitState.joining => Text(
          'VS',
          textScaler: TextScaler.noScaling,
          style: text.friendVs,
        ),
        FriendWaitState.declined ||
        FriendWaitState.closed => const ExcludeSemantics(
          child: ArcadeGlyphIcon(
            ArcadeGlyph.cross,
            size: _cross,
            strokeWidth: _crossStroke,
          ),
        ),
      },
    );
  }
}

/// The minute's ring: [seconds] of 60, ink over [FriendColors.quiet], from
/// 12 o'clock clockwise with round ends (`FrWait` `v.offset`).
class FriendWaitRing extends StatelessWidget {
  const FriendWaitRing({super.key, required this.seconds});

  final int seconds;

  static const minute = 60;
  static const size = 70.0;
  static const stroke = 7.0;

  /// How much of the ring is drawn, 0 to 1.
  double get sweep => (seconds / minute).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size.square(size + stroke),
      painter: _RingPainter(sweep),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.sweep);

  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: FriendWaitRing.size / 2,
    );
    Paint line(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = FriendWaitRing.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, line(FriendColors.quiet));
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * sweep,
        false,
        line(AppColors.ink),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.sweep != sweep;
}

/// While waiting: how to set up the phone, as on the matching screen, in
/// the design's card (1.5 ink edge, 18 corners, an outline phone).
class _PrepCard extends StatelessWidget {
  const _PrepCard({required this.exercise});

  final ExerciseType exercise;

  static const _padding = EdgeInsets.symmetric(
    horizontal: _side,
    vertical: AppSpacing.s16,
  );
  static const _side = 18.0;
  static const _edge = 1.5;
  static const _icon = 26.0;
  static const _iconGap = 14.0;
  static const _lineGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.smartphone_outlined,
            size: _icon,
            color: AppColors.ink,
          ),
          const SizedBox(width: _iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // One line; on narrow phones it shrinks a little, as on the
                // matching screen.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    FriendWaitView.prepTitle,
                    style: text.friendPrepTitle,
                  ),
                ),
                const SizedBox(height: _lineGap),
                Text(FriendWaitView.tipOf(exercise), style: text.friendPrepTip),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Once over: "{friend}님에게 다시 신청" (only with [onRetry]) and 친구 목록으로.
class _EndButtons extends StatelessWidget {
  const _EndButtons({
    required this.friendName,
    required this.onRetry,
    required this.onToList,
  });

  final String friendName;
  final VoidCallback? onRetry;
  final VoidCallback onToList;

  static const _retryPadding = EdgeInsets.fromLTRB(
    AppSpacing.s24,
    _retryOver,
    AppSpacing.s20,
    _retryOver,
  );
  static const _retryOver = 14.0;
  static const _thick = 2.0;
  static const _thin = 1.5;
  static const _arrow = 26.0;
  static const _arrowStroke = 2.4;
  static const _listHeight = 48.0;
  static const _listCorners = 16.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final retry = onRetry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (retry != null) ...[
          OutlinedButton(
            onPressed: retry,
            style: OutlinedButton.styleFrom(
              padding: _retryPadding,
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.ink, width: _thick),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              textStyle: text.friendRetry,
            ),
            child: Row(
              children: [
                Expanded(child: Text('$friendName님에게 다시 신청')),
                const SizedBox(width: AppSpacing.s12),
                const ArcadeGlyphIcon(
                  ArcadeGlyph.arrow,
                  size: _arrow,
                  strokeWidth: _arrowStroke,
                ),
              ],
            ),
          ),
          const SizedBox(height: _gap),
        ],
        OutlinedButton(
          onPressed: onToList,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(_listHeight),
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.ink, width: _thin),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_listCorners),
            ),
            textStyle: text.friendButton,
          ),
          child: const Text('친구 목록으로'),
        ),
      ],
    );
  }
}
