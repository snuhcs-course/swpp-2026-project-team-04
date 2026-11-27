import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'arcade_parts.dart';
import 'arcade_play_card.dart';
import 'exercise_sheet.dart';
import 'lobby_parts.dart';

/// 게임 시작's 친구와의 대전 card (A11 spec 3, `FrPlay` shape a): the sky
/// picture panel ([ArcadeFriendPanel]) at the left, "친구와의 / 대전" in the
/// middle of the white rest, an ink arrow chip at the bottom right, and the
/// orange "수락 대기!" sticker over the top right corner while a friend
/// request or a battle invite to me waits ([waiting]). One button: [onTap].
///
/// It takes the height its parent gives it (게임 시작: the rest of the
/// screen) and reports [minHeight] as its height when measured, so a page
/// that measures its children ([LobbyPage]) gives it at least that.
class FriendBattleCard extends StatelessWidget {
  const FriendBattleCard({
    super.key,
    required this.waiting,
    required this.onTap,
  });

  /// A friend request or a battle invite to me waits for an answer.
  final bool waiting;
  final VoidCallback onTap;

  /// The least height (user, 2026-11-27).
  static const minHeight = 132.0;

  /// The name's least width, and the picture's largest scale.
  static const nameMinWidth = 128.0;
  static const maxScale = 1.3;

  /// What a screen reader hears: the name, and the waiting request.
  static const label = '친구와의 대전';
  static const waitingLabel = '친구와의 대전, 수락을 기다리는 신청이 있어요';

  static const _edge = 1.0;
  static const _corners = 18.0;
  static const _arrowChip = 34.0;
  static const _arrowCorners = 11.0;
  static const _arrowInset = 10.0;
  static const _arrow = 18.0;
  static const _arrowStroke = 2.8;
  static const _nameSide = 6.0;

  /// The sticker's place from the card's inside (`right: -6px; top: -16px`).
  static const _stickerRight = -6.0;
  static const _stickerTop = -16.0;

  /// The picture's scale for a card whose inside, within its 1 px edge, is
  /// [inside]: `min(height / 152, (width − 128) / 190, 1.3)`, so the name
  /// keeps at least [nameMinWidth] (user, 2026-11-27). 1 at 360 x 780.
  static double pictureScale(Size inside) {
    final picture = ArcadeFriendPanel.picture;
    final scale = math.min(
      math.min(
        inside.height / picture.height,
        (inside.width - nameMinWidth) / picture.width,
      ),
      maxScale,
    );
    return math.max(0, scale);
  }

  @override
  Widget build(BuildContext context) {
    // Measured, it is [minHeight] high; laid out, as high as it is given.
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(height: minHeight),
      child: Semantics(
        button: true,
        label: waiting ? waitingLabel : label,
        onTap: onTap,
        excludeSemantics: true,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Material(
              color: AppColors.card,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_corners),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(_edge),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final scale = pictureScale(box.biggest);
                      return Stack(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: ArcadeFriendPanel.picture.width * scale,
                                child: ArcadeFriendPanel(scale: scale),
                              ),
                              const Expanded(child: _Name()),
                            ],
                          ),
                          const Positioned(
                            right: _arrowInset,
                            bottom: _arrowInset,
                            child: _ArrowChip(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (waiting)
              const Positioned(
                right: _edge + _stickerRight,
                top: _edge + _stickerTop,
                child: IgnorePointer(child: FriendWaitSticker()),
              ),
          ],
        ),
      ),
    );
  }
}

/// "친구와의 / 대전", centered in the white part, slanted 8°.
class _Name extends StatelessWidget {
  const _Name();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: FriendBattleCard._nameSide),
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: LobbySkew(
          degrees: 8,
          alignment: Alignment.center,
          child: Text(
            '친구와의\n대전',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.friendCardName,
          ),
        ),
      ),
    ),
  );
}

/// The ink chip with a sky arrow, as on the cards above.
class _ArrowChip extends StatelessWidget {
  const _ArrowChip();

  @override
  Widget build(BuildContext context) => Container(
    width: FriendBattleCard._arrowChip,
    height: FriendBattleCard._arrowChip,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(FriendBattleCard._arrowCorners),
    ),
    child: const ArcadeGlyphIcon(
      ArcadeGlyph.arrow,
      size: FriendBattleCard._arrow,
      color: AppColors.fever,
      strokeWidth: FriendBattleCard._arrowStroke,
    ),
  );
}

/// The orange "수락 대기!" sticker (A11 spec 3): ink words on amber with an
/// ink edge and shadow, turned 6°, giving the 미션 sticker's short shake
/// every [GoalSticker.period] ([GoalSticker.poseAt]; `FrPlay`'s `frWiggle`
/// has the same keyframes as MsGoal's `msWiggle`). It holds still with
/// reduced motion. A picture to a screen reader: the card says it.
class FriendWaitSticker extends StatefulWidget {
  const FriendWaitSticker({super.key});

  static const text = '수락 대기!';

  @override
  State<FriendWaitSticker> createState() => _FriendWaitStickerState();
}

class _FriendWaitStickerState extends State<FriendWaitSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: GoalSticker.period,
  );

  static const _height = 32.0;
  static const _edge = 2.0;
  static const _corner = 10.0;

  /// Inside the edge: 5 above, 10 before and 11 after the words.
  static const _padding = EdgeInsets.fromLTRB(_padStart, _padTop, _padEnd, 0);
  static const _padStart = 10.0;
  static const _padTop = 5.0;
  static const _padEnd = 11.0;

  /// The ink shadow: 2 right, 3 down, no blur.
  static const _shadow = Offset(2, 3);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shake
        ..stop()
        ..value = 0;
    } else if (!_shake.isAnimating) {
      _shake.repeat();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sticker = Container(
      height: _height,
      padding: _padding,
      decoration: const BoxDecoration(
        color: AppColors.warning,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.ink, width: _edge),
        ),
        borderRadius: BorderRadius.all(Radius.circular(_corner)),
        boxShadow: [BoxShadow(color: AppColors.ink, offset: _shadow)],
      ),
      // At the design's size whatever the text size: the sticker is 32
      // high, and the card tells a screen reader.
      child: Text(
        FriendWaitSticker.text,
        maxLines: 1,
        softWrap: false,
        textScaler: TextScaler.noScaling,
        style: Theme.of(context).textTheme.friendSticker,
      ),
    );
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _shake,
        child: sticker,
        builder: (context, child) {
          final pose = GoalSticker.poseAt(_shake.value);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(pose.degrees * math.pi / 180)
              ..scaleByDouble(pose.scale, pose.scale, 1, 1),
            child: child,
          );
        },
      ),
    );
  }
}
