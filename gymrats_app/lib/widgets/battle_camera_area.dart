import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/setup_hint_short.dart';
import '../theme/app_theme.dart';
import 'battle_art_path.dart';
import 'battle_banner.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_model.dart';

/// The battle screen under the stage: the user's camera, and over it the
/// few things to read or press while exercising.
///
/// - bottom left: the leave button, until the battle has ended
/// - bottom middle: one line of guidance, when there is something to say
/// - bottom right, before the start: the ready button
/// - top right, before the start: the camera switch
/// - along the top: the setup progress before the start, or the reconnect
///   band while the user's own connection is down
/// - in the top corners while the round is on: the combo marks ("2 HIT")
/// - around it, from the countdown on: the status frame of [frame] (A9)
///
/// Once the result is known the battle screen takes it away: the line
/// above it goes down and it gets shorter until it is gone (W2b end screen,
/// option A); 결과 보기 is the screen's ([BattleArena]), not its own.
///
/// While [settingUp] (W2b 3-B, A9, A12) the setup's things are drawn large
/// instead: the progress bar along the top, the board of the [setupCue]
/// (two short lines read from where the user exercises, an icon, and a hold
/// bar while the pose is held) above the camera, out of its box, at
/// [boardOffset] (the arena puts it in the top area, over the stage, so it
/// covers nothing of the user), the camera switch at the bottom right,
/// level with the leave button, and a status frame around the camera in
/// the cue's color. A new cue waits until the one shown has been up for
/// [cueHold], unless it says the setup is right. When the countdown
/// begins they fade out as [setupLook] falls, keeping how the setup last
/// gave them, and take no taps meanwhile; the countdown's own guidance and
/// button fade in in their usual places.
///
/// Unlike the stage above it, its texts follow the system text size, and
/// its buttons grow with them; the setup cue does not (it is already
/// large, in the stage's design points), and keeps each line to one line,
/// shrinking a board's lines alike to fit ([cueTextSize]).
class BattleCameraArea extends StatefulWidget {
  const BattleCameraArea({
    super.key,
    required this.camera,
    this.onLeave,
    this.hint,
    this.setupCue,
    this.readyLabel,
    this.onReady,
    this.readyPressed = false,
    this.onSwitchCamera,
    this.setupProgress,
    this.settingUp = false,
    this.setupLook = 0,
    this.reconnecting = false,
    this.spin = 0,
    this.combos = const [],
    this.stageScale = 1,
    this.frame,
    this.boardOffset = const Offset(
      BattleCameraArea.boardInset,
      BattleCameraArea.boardInset,
    ),
    this.boardScale = 1,
  });

  /// The camera picture with whatever is drawn on it. It is centered, and
  /// cut off where it does not fit; the sides it leaves stay plain.
  final Widget camera;

  /// Asks to leave the battle. Null hides the button: the battle has ended.
  final VoidCallback? onLeave;

  /// The guidance from the countdown on, when there is something to say:
  /// one line of at most two lines at the bottom. Not shown while
  /// [settingUp]: the [setupCue] says it then.
  final String? hint;

  /// The setup's short cue while [settingUp]: the board above the camera,
  /// and the camera's status frame in its color (none for a notice).
  final SetupHintShort? setupCue;

  /// Where the setup cue's board's top left corner is, from the top left of
  /// the camera under the line: above it, a negative height, under the
  /// arena (A12 spec 2). Alone (the default) it is inside the camera's top.
  final Offset boardOffset;

  /// What the board's design points ([boardSize]) are sized by: the
  /// stage's.
  final double boardScale;

  /// The ready button's words; null hides it. [onReady] null shows it but
  /// it cannot be pressed.
  final String? readyLabel;
  final VoidCallback? onReady;

  /// Whether the user is ready already, so the button takes it back: the
  /// large button is then white instead of lime.
  final bool readyPressed;

  /// Switches between the cameras; null hides the button.
  final VoidCallback? onSwitchCamera;

  /// How far the setup has come, from 0 to 1; null hides the bar.
  final double? setupProgress;

  /// Whether the battle is setting up now, so [setupCue], the ready button,
  /// the camera switch and [setupProgress] are the setup's, drawn large.
  final bool settingUp;

  /// How strongly the setup's large look shows: 1 while setting up, falling
  /// to 0 as the countdown begins ([BattleFxFrame.setupLook]). The guidance
  /// and button of the countdown and the round show the rest of the way.
  final double setupLook;

  /// Whether the user's own connection is down and being restored.
  final bool reconnecting;

  /// How far the reconnect band's arc has turned, in degrees.
  final double spin;

  /// The combo marks, in the top corners: mine on the left, the opponent's
  /// on the right, [BattleFx.comboBelowLine] stage points under the line, or
  /// as far under the reconnect band while it is up, however tall the
  /// system text size makes it.
  final List<BattleFxCombo> combos;

  /// What the stage above is sized by; the combo marks are sized with it.
  final double stageScale;

  /// The status frame from the countdown on ([BattleFxFrame.cameraFrame]);
  /// while [settingUp] the [setupCue] decides it instead.
  final BattleFxCameraFrame? frame;

  /// The line between the stage and the camera.
  static const lineWidth = 3.0;

  /// The status frame's width, inside the camera area under the line.
  static const frameWidth = 12.0;

  /// How long a setup cue stays before a different one replaces it, unless
  /// the new one says the setup is right (task.md W9 decision 1).
  static const cueHold = Duration(milliseconds: 600);

  /// The setup cue's text size, and the least it keeps (A12 spec 2) for
  /// every cue but the one naming two missing parts.
  static const cueMaxSize = 58.0;
  static const cueMinSize = 44.0;

  /// The setup cue's text size for lines whose widest is [widestAtMax] at
  /// [cueMaxSize], in [room]: [cueMaxSize] when it fits, otherwise as large
  /// as fits, so a line never wraps or is cut. The board's room is the same
  /// on every phone (its design points): every cue of the short table fits
  /// there at [cueMinSize] or more but the one naming two missing parts
  /// (task.md W9 decision 7), which alone goes about 0.3 under it to fit
  /// (task.md W12 decision 3). Cut to a tenth, so the text never ends a
  /// fraction past its room.
  static double cueTextSize({
    required double widestAtMax,
    required double room,
  }) {
    if (widestAtMax <= room || widestAtMax <= 0) return cueMaxSize;
    return (cueMaxSize * room / widestAtMax * 10).floorToDouble() / 10;
  }

  /// The setup cue's board (A12, SfSq top), in its own design points: its
  /// size, and how far it is from the camera's sides and top when alone.
  static const boardInset = 12.0;
  static const boardWidth = BattleFx.stageWidth - 2 * boardInset;
  static const boardSize = Size(boardWidth, 140);

  /// A round button as it looks, and the room it takes for a finger.
  static const _buttonSize = 44.0;
  static const _tapSize = 48.0;
  static const _edge = 1.5;
  static const _progressHeight = 6.0;
  static const _bandHeight = 34.0;

  /// While setting up: the large ready button's least size, and its ink
  /// edge.
  static const _setupButtonSize = Size(132, 52);
  static const _setupEdge = 2.0;

  /// The board's ink edge and corner, and the room beside its edge.
  static const _cueEdge = 3.0;
  static const _cueCorner = 22.0;
  static const _cueInset = 14.0;

  /// The cue's icon box, its corner, its icons (the check a little
  /// smaller), and the room after it.
  static const _cueIconBox = 72.0;
  static const _cueIconCorner = 18.0;
  static const _cueIconSize = 48.0;
  static const _cueCheckSize = 46.0;
  static const _cueIconGap = 14.0;

  /// The hold bar along the board's bottom while the pose is held, and its
  /// ink line on top.
  static const _holdHeight = 12.0;
  static const _holdEdge = 2.5;

  /// The room the cue's lines have on the board.
  static const cueRoom =
      boardWidth - 2 * _cueEdge - 2 * _cueInset - _cueIconBox - _cueIconGap;

  /// How far a round button's circle is from the edge of its finger room.
  static const _circleInset = (_tapSize - _buttonSize) / 2;

  @override
  State<BattleCameraArea> createState() => _BattleCameraAreaState();
}

/// What the setup last gave the camera area: its large things keep it while
/// they fade out, once the countdown has given other things.
class _SetupLook {
  _SetupLook.of(BattleCameraArea area, this.cue)
    : readyLabel = area.readyLabel,
      readyEnabled = area.onReady != null,
      readyPressed = area.readyPressed,
      canSwitch = area.onSwitchCamera != null,
      progress = area.setupProgress;

  /// The cue as the board showed it last.
  final SetupHintShort? cue;
  final String? readyLabel;
  final bool readyEnabled;
  final bool readyPressed;
  final bool canSwitch;
  final double? progress;
}

class _BattleCameraAreaState extends State<BattleCameraArea> {
  _SetupLook? _last;

  /// The setup cue the board shows, and the hold that keeps it up a moment
  /// before a different one may replace it.
  SetupHintShort? _cue;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _takeCue();
    _remember();
  }

  @override
  void didUpdateWidget(BattleCameraArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    _takeCue();
    _remember();
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _remember() {
    if (widget.settingUp) _last = _SetupLook.of(widget, _cue);
  }

  /// Shows the setup's latest cue now, or after the hold of the one shown:
  /// at once when nothing shows, when the hold is over, or when the new one
  /// says the setup is right. The same cue with a new sentence (a count)
  /// just takes the new sentence.
  void _takeCue() {
    if (!widget.settingUp) {
      _hold?.cancel();
      _hold = null;
      return;
    }
    final next = widget.setupCue;
    final shown = _cue;
    if (next == null) {
      _hold?.cancel();
      _hold = null;
      _cue = null;
    } else if (shown != null && next.looksLike(shown)) {
      _cue = next;
    } else if (shown == null ||
        _hold == null ||
        next.state == SetupCueState.match) {
      _show(next);
    }
  }

  void _show(SetupHintShort cue) {
    _cue = cue;
    _hold?.cancel();
    _hold = Timer(BattleCameraArea.cueHold, _holdOver);
  }

  /// The hold is over: the cue the setup gives now replaces the one shown.
  void _holdOver() {
    _hold = null;
    if (!mounted || !widget.settingUp) return;
    final next = widget.setupCue;
    final shown = _cue;
    if (next == null || (shown != null && next.looksLike(shown))) return;
    setState(() {
      _show(next);
      _remember();
    });
  }

  /// The status frame's color: the shown cue's while setting up, the
  /// round's [BattleCameraArea.frame] from the countdown on; null for none.
  Color? get _frameColor => widget.settingUp
      ? switch (_cue?.state) {
          SetupCueState.match => AppColors.statusGood,
          SetupCueState.mismatch => AppColors.danger,
          SetupCueState.notice || null => null,
        }
      : switch (widget.frame) {
          BattleFxCameraFrame.good => AppColors.statusGood,
          BattleFxCameraFrame.average => AppColors.warning,
          BattleFxCameraFrame.rejected => AppColors.danger,
          null => null,
        };

  static void _none() {}

  @override
  Widget build(BuildContext context) {
    final area = widget;
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final progress = area.setupProgress;
    final setup = _last;
    final setupLook = area.setupLook.clamp(0.0, 1.0);
    // The setup's large things take taps only while they are all there.
    final setupLive = area.settingUp && setupLook >= 1;
    // The countdown's and the round's things, as they come in.
    final round = !area.settingUp;
    final roundOpacity = 1 - setupLook;
    final hint = area.hint;
    final readyLabel = area.readyLabel;
    final frameColor = _frameColor;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.border,
        border: Border(
          top: BorderSide(
            color: AppColors.ink,
            width: BattleCameraArea.lineWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: BattleCameraArea.lineWidth),
        child: Stack(
          fit: StackFit.expand,
          // The setup's board is drawn above the camera's box.
          clipBehavior: Clip.none,
          children: [
            ClipRect(child: Center(child: area.camera)),
            // Over the camera and what is drawn on it, under the rest.
            if (frameColor != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: frameColor,
                        width: BattleCameraArea.frameWidth,
                      ),
                    ),
                  ),
                ),
              ),
            if (round && progress != null && !area.reconnecting)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _Fade(
                  opacity: roundOpacity,
                  child: _SetupProgress(progress: progress),
                ),
              ),
            if (round && area.onSwitchCamera != null)
              Positioned(
                right: AppSpacing.s12,
                // Clear of the band or the bar along the top.
                top: AppSpacing.s32 + AppSpacing.s12,
                child: _Fade(
                  opacity: roundOpacity,
                  child: _RoundButton(
                    icon: Icons.cameraswitch_outlined,
                    label: '카메라 전환',
                    alignment: Alignment.topRight,
                    onPressed: area.onSwitchCamera!,
                  ),
                ),
              ),
            Positioned(
              left: AppSpacing.s12,
              right: AppSpacing.s12,
              bottom: AppSpacing.s12 + bottomInset,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (area.onLeave != null)
                    _RoundButton(
                      icon: Icons.logout_rounded,
                      label: '게임 나가기',
                      alignment: Alignment.centerLeft,
                      onPressed: area.onLeave!,
                    )
                  else
                    const SizedBox(width: BattleCameraArea._tapSize),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: round && hint != null
                        ? _Fade(
                            opacity: roundOpacity,
                            child: _Hint(text: hint, style: text.cameraHint),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  if (round && readyLabel != null)
                    _Fade(
                      opacity: roundOpacity,
                      child: _ReadyButton(
                        label: readyLabel,
                        onPressed: area.onReady,
                        style: text.cameraButton,
                      ),
                    )
                  else
                    const SizedBox(width: BattleCameraArea._tapSize),
                ],
              ),
            ),
            if (setup != null && setupLook > 0)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !setupLive,
                  child: ExcludeSemantics(
                    excluding: !setupLive,
                    child: _Fade(
                      opacity: setupLook,
                      child: _setupLayer(setup, text, bottomInset, setupLive),
                    ),
                  ),
                ),
              ),
            // Over everything else here: the band, and the combo marks under
            // it, in the order of the design's layers.
            if (area.reconnecting || area.combos.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (area.reconnecting)
                      _ReconnectBand(spin: area.spin, style: text.cameraNotice),
                    if (area.combos.isNotEmpty)
                      _ComboRow(combos: area.combos, scale: area.stageScale),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The setup's things, large (W2b 3-B, A9, A12): the progress bar along
  /// the top, the cue's board at [BattleCameraArea.boardOffset] (above the
  /// camera under the arena), the camera switch at the bottom right,
  /// its circle level with the leave button's, and the ready button there,
  /// the switch then over it (no screen gives one since A6). [live] says
  /// they can be pressed; otherwise they only show.
  Widget _setupLayer(
    _SetupLook setup,
    TextTheme text,
    double bottomInset,
    bool live,
  ) {
    final area = widget;
    final progress = setup.progress;
    final cue = setup.cue;
    final readyLabel = setup.readyLabel;
    final bottom = AppSpacing.s12 + bottomInset;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (progress != null && !area.reconnecting)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _SetupProgress(progress: progress),
          ),
        if (cue != null)
          Positioned(
            left: area.boardOffset.dx,
            top: area.boardOffset.dy,
            width: BattleCameraArea.boardSize.width,
            height: BattleCameraArea.boardSize.height,
            child: Transform.scale(
              scale: area.boardScale,
              alignment: Alignment.topLeft,
              child: _SetupCueBoard(
                cue: cue,
                progress: progress ?? 0,
                style: text.cameraSetupCue,
              ),
            ),
          ),
        if (setup.canSwitch)
          Positioned(
            right: AppSpacing.s12,
            bottom: readyLabel == null
                ? bottom
                : bottom +
                      BattleCameraArea._circleInset +
                      BattleCameraArea._setupButtonSize.height +
                      AppSpacing.s8,
            child: _RoundButton(
              icon: Icons.cameraswitch_outlined,
              label: '카메라 전환',
              alignment: Alignment.centerRight,
              onPressed: live ? area.onSwitchCamera ?? _none : _none,
            ),
          ),
        if (readyLabel != null)
          Positioned(
            right: AppSpacing.s12,
            bottom:
                AppSpacing.s12 + bottomInset + BattleCameraArea._circleInset,
            child: _SetupReadyButton(
              label: readyLabel,
              enabled: setup.readyEnabled,
              pressed: setup.readyPressed,
              onPressed: live ? area.onReady : null,
              style: text.cameraSetupButton,
            ),
          ),
      ],
    );
  }
}

/// [child] at [opacity]; nothing at all at 0.
class _Fade extends StatelessWidget {
  const _Fade({required this.opacity, required this.child});

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (opacity >= 1) return child;
    if (opacity <= 0) return const SizedBox.shrink();
    return Opacity(opacity: opacity, child: child);
  }
}

/// The combo marks along the camera area's top: each in its own corner,
/// [BattleFx.comboBelowLine] stage points under the line, or as far under
/// the band above them.
class _ComboRow extends StatelessWidget {
  const _ComboRow({required this.combos, required this.scale});

  final List<BattleFxCombo> combos;
  final double scale;

  @override
  Widget build(BuildContext context) {
    // The line itself is not sized with the stage, and the row starts under
    // it or under the band.
    final gap = math.max(
      0.0,
      BattleFx.comboBelowLine * scale - BattleCameraArea.lineWidth,
    );
    return SizedBox(
      height: gap + BattleFx.bandBox(BattleFx.comboTextSize).height * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final combo in combos)
            Positioned(
              left: combo.side == BattleSide.me ? 0 : null,
              right: combo.side == BattleSide.me ? null : 0,
              top: gap,
              child: BattleComboMark(combo: combo, scale: scale),
            ),
        ],
      ),
    );
  }
}

/// A white round button with an ink edge and an ink icon. It takes a little
/// more room than it shows, for a finger; [alignment] says where in that
/// room the circle sits, so it lines up with the area's edge.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.alignment,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Alignment alignment;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // One node for a screen reader: a button with its name that can be
    // pressed, whatever it is drawn from.
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onPressed,
            radius: BattleCameraArea._tapSize / 2,
            child: SizedBox.square(
              dimension: BattleCameraArea._tapSize,
              child: Align(
                alignment: alignment,
                child: SizedBox.square(
                  dimension: BattleCameraArea._buttonSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.ink,
                        width: BattleCameraArea._edge,
                      ),
                    ),
                    child: Icon(icon, color: AppColors.ink),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one line of guidance: ink on white with an ink edge, two lines at
/// most. A screen reader hears it when it changes.
class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: BattleCameraArea._buttonSize,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(
              color: AppColors.ink,
              width: BattleCameraArea._edge,
            ),
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.small),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            child: Center(
              heightFactor: 1,
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ready button before the start: ink edged when it can be pressed,
/// gray when it cannot.
class _ReadyButton extends StatelessWidget {
  const _ReadyButton({
    required this.label,
    required this.onPressed,
    required this.style,
  });

  final String label;
  final VoidCallback? onPressed;
  final TextStyle style;

  static const _edge = 2.0;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.card,
          shape: StadiumBorder(
            side: BorderSide(
              color: enabled ? AppColors.ink : AppColors.border,
              width: _edge,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: BattleCameraArea._tapSize,
                minWidth: BattleCameraArea._tapSize,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: style.copyWith(
                      color: enabled ? AppColors.ink : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The setup cue's board (A12 spec 2, design SfSq `cue="top"`): ink on
/// white with an ink edge, the icon box in the cue's color, two short lines
/// beside it, and while the pose is held the hold bar along its bottom
/// filling with [progress]. [BattleCameraArea.boardSize] in its own design
/// points. A screen reader hears the cue's whole sentence, once for each
/// new one.
class _SetupCueBoard extends StatelessWidget {
  const _SetupCueBoard({
    required this.cue,
    required this.progress,
    required this.style,
  });

  final SetupHintShort cue;
  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    const edge = BattleCameraArea._cueEdge;
    const corner = BorderRadius.all(
      Radius.circular(BattleCameraArea._cueCorner),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: cue.message,
      child: ExcludeSemantics(
        child: DecoratedBox(
          // The edge over the box, so the hold bar runs under it.
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.ink, width: edge),
            borderRadius: corner,
          ),
          child: ClipRRect(
            borderRadius: corner,
            child: ColoredBox(
              color: AppColors.card,
              child: Padding(
                padding: const EdgeInsets.all(edge),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BattleCameraArea._cueInset,
                      ),
                      child: Row(
                        children: [
                          _CueIconBox(cue: cue),
                          const SizedBox(width: BattleCameraArea._cueIconGap),
                          Expanded(
                            child: _CueLines(cue: cue, style: style),
                          ),
                        ],
                      ),
                    ),
                    if (cue.holding)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: BattleCameraArea._holdHeight,
                        child: _HoldBar(progress: progress),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The cue's icon in a box of its state's color with an ink edge: green
/// when right, red when not, amber for a notice.
class _CueIconBox extends StatelessWidget {
  const _CueIconBox({required this.cue});

  final SetupHintShort cue;

  @override
  Widget build(BuildContext context) {
    final color = switch (cue.state) {
      SetupCueState.match => AppColors.statusGood,
      SetupCueState.mismatch => AppColors.danger,
      SetupCueState.notice => AppColors.warning,
    };
    const size = BattleCameraArea._cueIconSize;
    final icon = switch (cue.icon) {
      SetupCueIcon.hand => const Icon(
        Icons.back_hand_outlined,
        size: size,
        color: AppColors.ink,
      ),
      SetupCueIcon.connection => const Icon(
        Icons.wifi_rounded,
        size: size,
        color: AppColors.ink,
      ),
      SetupCueIcon.check => const CustomPaint(
        size: Size.square(BattleCameraArea._cueCheckSize),
        painter: SetupCueIconPainter(SetupCueIcon.check),
      ),
      final drawn => CustomPaint(
        size: const Size.square(size),
        painter: SetupCueIconPainter(drawn),
      ),
    };
    return SizedBox.square(
      dimension: BattleCameraArea._cueIconBox,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: AppColors.ink,
            width: BattleCameraArea._cueEdge,
          ),
          borderRadius: const BorderRadius.all(
            Radius.circular(BattleCameraArea._cueIconCorner),
          ),
        ),
        child: Center(child: icon),
      ),
    );
  }
}

/// The cue's two lines, each one line, the two at the same size: as large
/// as [BattleCameraArea.cueTextSize] lets them in the room they have,
/// whatever the system text size.
class _CueLines extends StatelessWidget {
  const _CueLines({required this.cue, required this.style});

  final SetupHintShort cue;

  /// The cue's style ([BattleCameraText.cameraSetupCue]), drawn at
  /// [BattleCameraArea.cueMaxSize] or less.
  final TextStyle style;

  TextStyle _at(double size) =>
      style.apply(fontSizeFactor: size / style.fontSize!);

  double _widthAtMax(String line) {
    final painter = TextPainter(
      text: TextSpan(text: line, style: _at(BattleCameraArea.cueMaxSize)),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = BattleCameraArea.cueTextSize(
          widestAtMax: math.max(
            _widthAtMax(cue.first),
            _widthAtMax(cue.second),
          ),
          room: constraints.maxWidth,
        );
        final sized = _at(size);
        Text line(String words) => Text(
          words,
          maxLines: 1,
          softWrap: false,
          textScaler: TextScaler.noScaling,
          style: sized,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [line(cue.first), line(cue.second)],
        );
      },
    );
  }
}

/// The bar along the board's bottom while a cue is held: white under an
/// ink line, filling with status green as the pose holds.
class _HoldBar extends StatelessWidget {
  const _HoldBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(
            color: AppColors.ink,
            width: BattleCameraArea._holdEdge,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: BattleCameraArea._holdEdge),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          heightFactor: 1,
          child: const ColoredBox(color: AppColors.statusGood),
        ),
      ),
    );
  }
}

/// The cue icons drawn in ink lines from the design (A9, UxSq A2), in its
/// 24 x 24 view: the check, the person, the phone, and the phone with an
/// arrow going away from it or coming to it. The hand and the connection
/// are Material icons.
class SetupCueIconPainter extends CustomPainter {
  const SetupCueIconPainter(this.icon)
    : assert(
        icon != SetupCueIcon.hand && icon != SetupCueIcon.connection,
        'a Material icon',
      );

  final SetupCueIcon icon;

  static const _view = 24.0;

  /// The phone's outline: beside an arrow, or standing alone.
  static const _sidePhone = Rect.fromLTWH(2.5, 5, 6, 11);
  static const _phone = Rect.fromLTWH(7, 2.5, 10, 19);
  static const _phoneCorner = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _view, size.height / _view);
    Paint ink(double width) => Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void phone(Rect box, Paint paint) => canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(_phoneCorner)),
      paint,
    );
    switch (icon) {
      case SetupCueIcon.check:
        canvas.drawPath(battleArtPath('M4.5 12.5l5 5L19.5 7'), ink(3));
      case SetupCueIcon.person:
        final line = ink(2.4);
        canvas.drawCircle(const Offset(12, 5), 2.2, line);
        canvas.drawPath(
          battleArtPath('M12 7.5v7M8 10.5h8M12 14.5l-2.5 6M12 14.5l2.5 6'),
          line,
        );
      case SetupCueIcon.stepBack:
        final line = ink(2.6);
        phone(_sidePhone, line);
        canvas.drawPath(battleArtPath('M11 10.5h9M17 7.5l3 3-3 3'), line);
      case SetupCueIcon.stepCloser:
        final line = ink(2.6);
        phone(_sidePhone, line);
        canvas.drawPath(battleArtPath('M20 10.5h-9M14 7.5l-3 3 3 3'), line);
      case SetupCueIcon.phone:
        final line = ink(2.4);
        phone(_phone, line);
        canvas.drawPath(battleArtPath('M10.5 18.5h3'), line);
      case SetupCueIcon.hand || SetupCueIcon.connection:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SetupCueIconPainter oldDelegate) =>
      oldDelegate.icon != icon;
}

/// The setup's ready button, large (W2b 3-B): a pill with an ink edge,
/// lime when it can be pressed, white when it takes the user's ready back,
/// gray when it cannot be pressed. It is [enabled] or not as the setup said;
/// [onPressed] is null while it only shows.
class _SetupReadyButton extends StatelessWidget {
  const _SetupReadyButton({
    required this.label,
    required this.enabled,
    required this.pressed,
    required this.onPressed,
    required this.style,
  });

  final String label;
  final bool enabled;
  final bool pressed;
  final VoidCallback? onPressed;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Material(
          color: enabled && !pressed ? AppColors.accent : AppColors.card,
          shape: StadiumBorder(
            side: BorderSide(
              color: enabled ? AppColors.ink : AppColors.border,
              width: BattleCameraArea._setupEdge,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: BattleCameraArea._setupButtonSize.width,
                minHeight: BattleCameraArea._setupButtonSize.height,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: style.copyWith(
                      color: enabled ? AppColors.ink : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The thin bar under the line that fills with lime as the setup goes on.
class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '자세 세팅 진행',
      value: '${(progress.clamp(0.0, 1.0) * 100).round()}%',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(
            bottom: BorderSide(
              color: AppColors.ink,
              width: BattleCameraArea._edge,
            ),
          ),
        ),
        child: SizedBox(
          height: BattleCameraArea._progressHeight,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: const ColoredBox(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

/// The amber band that says the connection is being restored, with a
/// turning arc. The clock keeps running meanwhile, and the band says so. A
/// screen reader is told by the arena when it comes up, so the band itself
/// is no live region.
class _ReconnectBand extends StatelessWidget {
  const _ReconnectBand({required this.spin, required this.style});

  final double spin;
  final TextStyle style;

  static const _arcSize = 16.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.warning,
          border: Border(
            bottom: BorderSide(
              color: AppColors.ink,
              width: BattleCameraArea._edge,
            ),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: BattleCameraArea._bandHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Transform.rotate(
                    angle: spin * math.pi / 180,
                    child: const CustomPaint(
                      size: Size.square(_arcSize),
                      painter: BattleReconnectArcPainter(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  child: Text(
                    '재연결 중 · 경기 시간은 계속 진행됩니다.',
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three quarters of a circle, open at the top right: the reconnect band's
/// turning arc.
class BattleReconnectArcPainter extends CustomPainter {
  const BattleReconnectArcPainter();

  /// The side of the square the design draws the arc in, and the arc's
  /// radius and line in it.
  static const _view = 16.0;
  static const _radius = 6.0;
  static const _line = 2.4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _view, size.height / _view);
    canvas.drawArc(
      Rect.fromCircle(
        center: const Offset(_view / 2, _view / 2),
        radius: _radius,
      ),
      0,
      1.5 * math.pi,
      false,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _line
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BattleReconnectArcPainter oldDelegate) => false;
}
