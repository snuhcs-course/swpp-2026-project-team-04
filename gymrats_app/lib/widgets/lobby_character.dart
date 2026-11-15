import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/character_rig.dart';
import '../theme/app_theme.dart';
import 'character_figure.dart';
import 'character_motion.dart';

/// The picked character doing its exercise again and again in the middle of
/// home (W4 spec 1 to 7): push-ups, squats or the bear's one-two punch, on
/// an unseen floor, with no stand and no name band.
///
/// The whole room is one button that opens 캐릭터 선택; nothing marks it.
/// The motion runs from 0 when the figure appears, when the character
/// changes, and when home shows again after a page covered it (spec 4 lets
/// it; so a character chosen meanwhile, from 환경설정 too, starts at 0).
/// When the device asks for less motion it shows one still picture. A page
/// over home mutes its clock (the navigator turns off the tickers of covered
/// pages), and an app in the background draws no frames.
class LobbyCharacter extends StatefulWidget {
  const LobbyCharacter({
    super.key,
    required this.characterId,
    required this.onTap,
  });

  /// The character drawn; an id a person may not pick (RepBot's, an
  /// unknown one) draws the default (`mouse`).
  final String characterId;
  final VoidCallback onTap;

  @override
  State<LobbyCharacter> createState() => _LobbyCharacterState();
}

class _LobbyCharacterState extends State<LobbyCharacter>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(
    (elapsed) => _clock.value = elapsed.inMicroseconds / 1000,
  );

  /// Milliseconds into the motion.
  final _clock = ValueNotifier<double>(0);
  bool _still = false;

  /// Whether home is shown: no page covers it.
  bool _shown = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shown = TickerMode.valuesOf(context).enabled;
    final shownAgain = shown && !_shown;
    _shown = shown;
    if (_still) {
      _ticker.stop();
      _clock.value = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    } else if (shownAgain) {
      _restart();
    }
  }

  @override
  void didUpdateWidget(LobbyCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.characterId != widget.characterId) _restart();
  }

  /// Runs the motion from its beginning.
  void _restart() {
    _clock.value = 0;
    if (_ticker.isActive) {
      _ticker
        ..stop()
        ..start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rig = CharacterRig.standard;
    // RepBot has no home motion: it is drawn as the default too.
    final art = rig.art(rig.selectableOrDefault(widget.characterId));
    return Semantics(
      button: true,
      label: '캐릭터 바꾸기, 지금 캐릭터 ${art.name}',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // Repaints alone each frame, not the menu around it.
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: LobbyCharacterPainter(
              rig: rig,
              art: art,
              motion: CharacterMotionRig.standard,
              clock: _clock,
              still: _still,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [art]'s home motion at the time [clock] holds (ms), or its rest
/// picture when [still], placed in the painted room by the W4 rule
/// ([CharacterHomeMotion.placeIn]). Repaints whenever [clock] changes.
class LobbyCharacterPainter extends CustomPainter {
  LobbyCharacterPainter({
    required this.rig,
    required this.art,
    required this.motion,
    required this.clock,
    required this.still,
  }) : super(repaint: clock);

  final CharacterRig rig;
  final CharacterArt art;
  final CharacterMotionRig motion;
  final ValueListenable<double> clock;
  final bool still;

  CharacterHomeMotion get _home => motion.motionOf(art.id);

  /// The frame drawn now.
  CharacterMotionFrame get frame =>
      still ? _home.rest : _home.frameAt(clock.value);

  /// Where the character stands in a room of [size].
  CharacterPlacement placementIn(Size size) =>
      _home.placeIn(size, Offset(rig.anchorX, rig.anchorY));

  @override
  void paint(Canvas canvas, Size size) {
    final home = _home;
    final placement = placementIn(size);
    if (placement.scale <= 0) return;
    final frame = this.frame;
    canvas
      ..save()
      ..translate(placement.foot.dx, placement.foot.dy)
      ..scale(placement.scale)
      ..translate(-rig.anchorX, -rig.anchorY);
    frame.global.applyTo(canvas, rig.anchorX, rig.anchorY);
    CharacterFigurePainter(
      rig: rig,
      art: art,
      // Home is always the player's own: the team lime (W4 spec 5).
      teamColor: AppColors.accent,
      values: frame.pose,
      tags: motion.tagsOf(frame.expression, art.id),
      patches: home.drawPatch,
      flags: home.motion.flags,
      effects: motion.effects,
    ).paint(canvas, Size(rig.boxWidth, rig.boxHeight));
    canvas.restore();
  }

  @override
  bool shouldRepaint(LobbyCharacterPainter oldDelegate) =>
      oldDelegate.rig != rig ||
      oldDelegate.art.id != art.id ||
      oldDelegate.motion != motion ||
      oldDelegate.clock != clock ||
      oldDelegate.still != still;
}
