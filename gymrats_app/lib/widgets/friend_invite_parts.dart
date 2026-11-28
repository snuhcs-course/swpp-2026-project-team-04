import 'package:flutter/material.dart';

import '../models/character_rig.dart';
import '../models/exercise_type_korean.dart';
import '../services/friends/friend_repository.dart';
import '../theme/app_theme.dart';
import 'arcade_parts.dart';
import 'battle_stage_model.dart';
import 'character_figure.dart';

/// The time left as the cards show it, "m:ss" ("0:48", "1:00").
String friendClock(int seconds) {
  final left = seconds < 0 ? 0 : seconds;
  return '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
}

/// The inviter's character to draw for [invite]: the one their app sent,
/// or the default (GYM마우스) when it sent none or one that cannot be
/// picked (A11 spec 7).
String friendInviteCharacter(BattleInvite invite) =>
    CharacterRig.standard.selectableOrDefault(invite.character);

/// The pink panel at an invite's left (A11 `FrFriends`, `FrAlert` kind a):
/// [characterId] on the opponent's team, facing right, idling, edged white,
/// with its feet at [feet] on a disc [discWidth] wide, at [scale]; the
/// shade under an edge rising from 66% down on the left to 50% on the
/// right. A picture: a screen reader hears the card's words.
class FriendInvitePanel extends StatelessWidget {
  const FriendInvitePanel({
    super.key,
    required this.characterId,
    required this.feet,
    required this.scale,
    required this.discWidth,
  });

  final String characterId;
  final Offset feet;
  final double scale;
  final double discWidth;

  static const _discHalf = 7.0;
  static const _discEdge = 3.0;
  static const _discShade = 0.55;

  /// The figure's 140 x 160 box puts the feet 70 in and 150 down.
  static const _anchor = Offset(70, 150);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRect(
        child: CustomPaint(
          painter: const _InviteShade(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: feet.dx - discWidth / 2,
                top: feet.dy - _discHalf,
                child: Container(
                  width: discWidth,
                  height: _discHalf * 2,
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: _discShade),
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(discWidth / 2, _discHalf),
                    ),
                    border: Border.all(color: AppColors.ink, width: _discEdge),
                  ),
                ),
              ),
              Positioned(
                left: feet.dx - _anchor.dx,
                top: feet.dy - _anchor.dy,
                child: Transform(
                  transform: Matrix4.diagonal3Values(scale, scale, 1),
                  origin: _anchor,
                  child: ArcadeWhiteOutline(
                    child: CharacterIdleFigure(
                      characterId: characterId,
                      side: BattleSide.opponent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [AppColors.opponent] with [AppColors.opponentDeep] under the edge.
class _InviteShade extends CustomPainter {
  const _InviteShade();

  static const _left = 0.66;
  static const _right = 0.50;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.opponent);
    canvas.drawPath(
      Path()..addPolygon([
        Offset(0, size.height * _left),
        Offset(size.width, size.height * _right),
        Offset(size.width, size.height),
        Offset(0, size.height),
      ], true),
      Paint()..color = AppColors.opponentDeep,
    );
  }

  @override
  bool shouldRepaint(_InviteShade oldDelegate) => false;
}

/// The time left as a bar: [AppColors.opponent] over [FriendColors.quiet],
/// [seconds] of the invite's minute, [height] high with [corners].
class FriendTimeBar extends StatelessWidget {
  const FriendTimeBar({
    super.key,
    required this.seconds,
    required this.height,
    this.corners = 0,
  });

  final int seconds;
  final double height;
  final double corners;

  /// How much of the minute is left, 0 to 1.
  double get fraction =>
      (seconds / BattleInvite.ttl.inSeconds).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(corners);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: FriendColors.quiet),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.opponent,
                  borderRadius: radius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 거절 (white, 1.5 ink edge) and 수락 (lime, 2 ink edge, 1.6 times as
/// wide), 40 high; both off while [busy].
class FriendAnswerButtons extends StatelessWidget {
  const FriendAnswerButtons({
    super.key,
    required this.busy,
    required this.onDecline,
    required this.onAccept,
  });

  final bool busy;
  final VoidCallback onDecline, onAccept;

  static const _height = 40.0;
  static const _corners = 12.0;
  static const _thin = 1.5;
  static const _thick = 2.0;

  /// 1 to 1.6, as designed.
  static const _declineFlex = 10, _acceptFlex = 16;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    ButtonStyle style(Color fill, double edge, TextStyle words) =>
        OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(_height),
          padding: EdgeInsets.zero,
          backgroundColor: fill,
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.textMuted,
          side: BorderSide(color: AppColors.ink, width: edge),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_corners),
          ),
          textStyle: words,
        );
    return Row(
      children: [
        Expanded(
          flex: _declineFlex,
          child: OutlinedButton(
            onPressed: busy ? null : onDecline,
            style: style(AppColors.card, _thin, text.friendButton),
            child: const Text('거절'),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          flex: _acceptFlex,
          child: OutlinedButton(
            onPressed: busy ? null : onAccept,
            style: style(AppColors.accent, _thick, text.friendAccept),
            child: const Text('수락'),
          ),
        ),
      ],
    );
  }
}

/// A battle invite to me on the friends page (A11 spec 4, `FrFriends`):
/// the inviter's character at the left, then their nickname with the time
/// left, the exercise on a pill, the time bar and 거절 · 수락.
class FriendInviteCard extends StatelessWidget {
  const FriendInviteCard({
    super.key,
    required this.invite,
    required this.secondsLeft,
    required this.busy,
    required this.onDecline,
    required this.onAccept,
  });

  final BattleInvite invite;
  final int secondsLeft;
  final bool busy;
  final VoidCallback onDecline, onAccept;

  static const panelWidth = 96.0;
  static const _feet = Offset(48, 122);
  static const _scale = 0.55;
  static const _disc = 62.0;
  static const _edge = 2.0;
  static const _corners = 18.0;
  static const _padding = EdgeInsets.fromLTRB(
    _side,
    AppSpacing.s12,
    _side,
    _side,
  );
  static const _side = 14.0;
  static const _pillPadding = EdgeInsets.symmetric(
    horizontal: _pillSide,
    vertical: _pillOver,
  );
  static const _pillSide = 10.0;
  static const _pillOver = 1.0;
  static const _pillEdge = 1.5;
  static const _barHeight = 6.0;
  static const _barCorners = 3.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_corners),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: panelWidth,
              child: FriendInvitePanel(
                characterId: friendInviteCharacter(invite),
                feet: _feet,
                scale: _scale,
                discWidth: _disc,
              ),
            ),
            Expanded(
              child: Padding(
                padding: _padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            invite.from.nickname,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: text.friendInviteName,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Text(friendClock(secondsLeft), style: text.friendClock),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: _pillPadding,
                        decoration: const ShapeDecoration(
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: AppColors.ink,
                              width: _pillEdge,
                            ),
                          ),
                        ),
                        child: Text(
                          '${invite.exercise.koreanName} 대결',
                          style: text.friendPill,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    FriendTimeBar(
                      seconds: secondsLeft,
                      height: _barHeight,
                      corners: _barCorners,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    FriendAnswerButtons(
                      busy: busy,
                      onDecline: onDecline,
                      onAccept: onAccept,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The frame of the invite alert (A11 spec 6): white with a 2 ink edge,
/// 20 corners and a hard ink shadow 3 right and 4 down.
BoxDecoration friendAlertFrame() => BoxDecoration(
  color: AppColors.card,
  borderRadius: BorderRadius.circular(FriendInviteAlertCard._corners),
  border: Border.all(color: AppColors.ink, width: FriendInviteAlertCard._edge),
  boxShadow: const [
    BoxShadow(color: AppColors.ink, offset: FriendInviteAlertCard._shadow),
  ],
);

/// The app-wide alert's card for [invite] (A11 spec 6, `FrAlert` kind a):
/// the inviter's character at the left, "{nickname}님이" with the time
/// left, "{exercise} 대결을 신청했어요", 거절 · 수락, and the time bar along
/// the bottom. A screen reader hears the sentence as it comes.
class FriendInviteAlertCard extends StatelessWidget {
  const FriendInviteAlertCard({
    super.key,
    required this.invite,
    required this.secondsLeft,
    required this.busy,
    required this.onDecline,
    required this.onAccept,
  });

  final BattleInvite invite;
  final int secondsLeft;
  final bool busy;
  final VoidCallback onDecline, onAccept;

  /// What it says: "{nickname}님이 {exercise} 대결을 신청했어요".
  static String lineOf(BattleInvite invite) =>
      '${invite.from.nickname}님이 ${invite.exercise.koreanName} 대결을 신청했어요';

  static const panelWidth = 88.0;
  static const _feet = Offset(44, 108);
  static const _scale = 0.52;
  static const _disc = 58.0;
  static const _edge = 2.0;
  static const _corners = 20.0;
  static const _shadow = Offset(3, 4);
  static const _padding = EdgeInsets.fromLTRB(
    _start,
    AppSpacing.s12,
    AppSpacing.s12,
    _bottom,
  );
  static const _start = 14.0;
  static const _bottom = 17.0;
  static const _lineGap = 2.0;
  static const _barHeight = 5.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      label: lineOf(invite),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: friendAlertFrame(),
        child: Stack(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: panelWidth,
                    child: FriendInvitePanel(
                      characterId: friendInviteCharacter(invite),
                      feet: _feet,
                      scale: _scale,
                      discWidth: _disc,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: _padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Read out as one sentence (the label above).
                          ExcludeSemantics(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${invite.from.nickname}님이',
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.friendInviteName,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Text(
                                  friendClock(secondsLeft),
                                  style: text.friendClock,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: _lineGap),
                          ExcludeSemantics(
                            child: Text(
                              '${invite.exercise.koreanName} 대결을 신청했어요',
                              style: text.friendInviteLine,
                            ),
                          ),
                          const SizedBox(height: _lineGap + AppSpacing.s8),
                          FriendAnswerButtons(
                            busy: busy,
                            onDecline: onDecline,
                            onAccept: onAccept,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FriendTimeBar(seconds: secondsLeft, height: _barHeight),
            ),
          ],
        ),
      ),
    );
  }
}

/// The alert's card for an answer that failed: its [line] alone, in the
/// alert's frame (A11 spec 6).
class FriendAlertErrorCard extends StatelessWidget {
  const FriendAlertErrorCard({super.key, required this.line});

  final String line;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      decoration: friendAlertFrame(),
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Text(line, style: Theme.of(context).textTheme.lobbyRowTitle),
    ),
  );
}
