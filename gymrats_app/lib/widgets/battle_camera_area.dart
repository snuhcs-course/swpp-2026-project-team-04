import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
///
/// Once the result is known the battle screen takes it away: the line
/// above it goes down and it gets shorter until it is gone (W2b end screen,
/// option A); 결과 보기 is the screen's ([BattleArena]), not its own.
///
/// While [settingUp] (W2b 3-B) the setup's things are drawn large instead:
/// the progress bar along the top, the guidance in a large band under it,
/// the camera switch under that, and a large ready button bottom right; the
/// leave button stays. When the countdown begins they fade out as
/// [setupLook] falls, keeping how the setup last gave them, and take no
/// taps meanwhile; the countdown's own guidance and button fade in in
/// their usual places.
///
/// Unlike the stage above it, its texts follow the system text size, and
/// its buttons grow with them; the large band's guidance keeps to one line
/// and shrinks to fit.
class BattleCameraArea extends StatefulWidget {
  const BattleCameraArea({
    super.key,
    required this.camera,
    this.onLeave,
    this.hint,
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
  });

  /// The camera picture with whatever is drawn on it. It is centered, and
  /// cut off where it does not fit; the sides it leaves stay plain.
  final Widget camera;

  /// Asks to leave the battle. Null hides the button: the battle has ended.
  final VoidCallback? onLeave;

  /// The guidance, when there is something to say: in the large band while
  /// [settingUp], otherwise one line of at most two lines at the bottom.
  final String? hint;

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

  /// Whether the battle is setting up now, so [hint], the ready button, the
  /// camera switch and [setupProgress] are the setup's, drawn large.
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

  /// The line between the stage and the camera.
  static const lineWidth = 3.0;

  /// A round button as it looks, and the room it takes for a finger.
  static const _buttonSize = 44.0;
  static const _tapSize = 48.0;
  static const _edge = 1.5;
  static const _progressHeight = 6.0;
  static const _bandHeight = 34.0;

  /// While setting up: the large band's height, the large ready button's
  /// least size, and their ink edges.
  static const _setupHintHeight = 54.0;
  static const _setupButtonSize = Size(132, 52);
  static const _setupEdge = 2.0;

  /// How far a round button's circle is from the edge of its finger room.
  static const _circleInset = (_tapSize - _buttonSize) / 2;

  @override
  State<BattleCameraArea> createState() => _BattleCameraAreaState();
}

/// What the setup last gave the camera area: its large things keep it while
/// they fade out, once the countdown has given other things.
class _SetupLook {
  _SetupLook.of(BattleCameraArea area)
    : hint = area.hint,
      readyLabel = area.readyLabel,
      readyEnabled = area.onReady != null,
      readyPressed = area.readyPressed,
      canSwitch = area.onSwitchCamera != null,
      progress = area.setupProgress;

  final String? hint;
  final String? readyLabel;
  final bool readyEnabled;
  final bool readyPressed;
  final bool canSwitch;
  final double? progress;
}

class _BattleCameraAreaState extends State<BattleCameraArea> {
  _SetupLook? _last;

  @override
  void initState() {
    super.initState();
    _remember();
  }

  @override
  void didUpdateWidget(BattleCameraArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    _remember();
  }

  void _remember() {
    if (widget.settingUp) _last = _SetupLook.of(widget);
  }

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
          children: [
            ClipRect(child: Center(child: area.camera)),
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

  /// The setup's things, large (W2b 3-B): the progress bar along the top,
  /// the guidance in a band under it, the camera switch under the band at
  /// the right, and the ready button at the bottom right, its bottom level
  /// with the leave button's circle. [live] says they can be
  /// pressed; otherwise they only show.
  Widget _setupLayer(
    _SetupLook setup,
    TextTheme text,
    double bottomInset,
    bool live,
  ) {
    final area = widget;
    final progress = setup.progress;
    final hint = setup.hint;
    final readyLabel = setup.readyLabel;
    const hintTop = BattleCameraArea._progressHeight + AppSpacing.s8;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (progress != null && !area.reconnecting)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _SetupProgress(progress: progress),
          ),
        if (hint != null)
          Positioned(
            left: AppSpacing.s12,
            right: AppSpacing.s12,
            top: hintTop,
            child: _SetupHint(text: hint, style: text.cameraSetupHint),
          ),
        if (setup.canSwitch)
          Positioned(
            right: AppSpacing.s12,
            top: hintTop + BattleCameraArea._setupHintHeight + AppSpacing.s8,
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

/// The setup's guidance, large (W2b 3-B): ink on a white band with an ink
/// edge, as wide as the area less its sides, one line that shrinks to fit
/// the band, also at a large system text size. A screen reader hears it
/// whole when it changes.
class _SetupHint extends StatelessWidget {
  const _SetupHint({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: SizedBox(
        height: BattleCameraArea._setupHintHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(
              color: AppColors.ink,
              width: BattleCameraArea._setupEdge,
            ),
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.small),
            ),
          ),
          child: Padding(
            // The design's room inside the edge, which is painted inside the
            // box here.
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8 + BattleCameraArea._setupEdge,
              vertical: BattleCameraArea._setupEdge,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
