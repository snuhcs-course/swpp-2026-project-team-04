import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'battle_fx_motion.dart';

/// The lower half of the battle screen: the user's camera, and over it the
/// few things to read or press while exercising.
///
/// - bottom left: the leave button, until the battle has ended
/// - bottom middle: one line of guidance, when there is something to say
/// - bottom right, before the start: the ready button
/// - top right, before the start: the camera switch
/// - along the top: the setup progress before the start, or the reconnect
///   band while the user's own connection is down
/// - in the middle, once the ending has played: 결과 보기, over a dimmed
///   camera
///
/// Unlike the stage above it, its texts follow the system text size, and
/// its buttons grow with them.
class BattleCameraArea extends StatelessWidget {
  const BattleCameraArea({
    super.key,
    required this.camera,
    this.onLeave,
    this.hint,
    this.readyLabel,
    this.onReady,
    this.onSwitchCamera,
    this.setupProgress,
    this.reconnecting = false,
    this.spin = 0,
    this.resultButton,
    this.onShowResult,
  });

  /// The camera picture with whatever is drawn on it, in its own shape. It
  /// is centered and never cropped; the sides it leaves stay plain.
  final Widget camera;

  /// Asks to leave the battle. Null hides the button: the battle has ended.
  final VoidCallback? onLeave;

  /// The one line of guidance, at most two lines long; null shows none.
  final String? hint;

  /// The ready button's words; null hides it. [onReady] null shows it but
  /// it cannot be pressed.
  final String? readyLabel;
  final VoidCallback? onReady;

  /// Switches between the cameras; null hides the button.
  final VoidCallback? onSwitchCamera;

  /// How far the setup has come, from 0 to 1; null hides the bar.
  final double? setupProgress;

  /// Whether the user's own connection is down and being restored.
  final bool reconnecting;

  /// How far the reconnect band's arc has turned, in degrees.
  final double spin;

  /// 결과 보기 as the effect math brings it up; null until the ending has
  /// played, and the button cannot be pressed before.
  final BattleFxResultButton? resultButton;
  final VoidCallback? onShowResult;

  /// The line between the stage and the camera.
  static const lineWidth = 3.0;

  /// A round button as it looks, and the room it takes for a finger.
  static const _buttonSize = 44.0;
  static const _tapSize = 48.0;
  static const _edge = 1.5;
  static const _progressHeight = 6.0;
  static const _bandHeight = 34.0;
  static const _resultSize = Size(240, 58);
  static const _arrowSize = 26.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final result = resultButton;
    final progress = setupProgress;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.border,
        border: Border(
          top: BorderSide(color: AppColors.ink, width: lineWidth),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: lineWidth),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: camera),
            if (progress != null && !reconnecting)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _SetupProgress(progress: progress),
              ),
            if (reconnecting)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _ReconnectBand(spin: spin, style: text.cameraNotice),
              ),
            if (onSwitchCamera != null)
              Positioned(
                right: AppSpacing.s12,
                // Clear of the band or the bar along the top.
                top: AppSpacing.s32 + AppSpacing.s12,
                child: _RoundButton(
                  icon: Icons.cameraswitch_outlined,
                  label: '카메라 전환',
                  alignment: Alignment.topRight,
                  onPressed: onSwitchCamera!,
                ),
              ),
            Positioned(
              left: AppSpacing.s12,
              right: AppSpacing.s12,
              bottom: AppSpacing.s12 + bottomInset,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (onLeave != null)
                    _RoundButton(
                      icon: Icons.logout_rounded,
                      label: '게임 나가기',
                      alignment: Alignment.centerLeft,
                      onPressed: onLeave!,
                    )
                  else
                    const SizedBox(width: _tapSize),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: hint == null
                        ? const SizedBox.shrink()
                        : _Hint(text: hint!, style: text.cameraHint),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  if (readyLabel != null)
                    _ReadyButton(
                      label: readyLabel!,
                      onPressed: onReady,
                      style: text.cameraButton,
                    )
                  else
                    const SizedBox(width: _tapSize),
                ],
              ),
            ),
            if (result != null) ...[
              // The camera fades behind the button: the battle is over.
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: AppColors.background.withValues(
                      alpha: result.scrim.clamp(0.0, 1.0),
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                  ),
                  child: Opacity(
                    opacity: result.opacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: result.scale,
                      child: _ResultButton(
                        onPressed: onShowResult,
                        style: text.cameraResult,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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

/// 결과 보기: the only way on once the battle has ended.
class _ResultButton extends StatelessWidget {
  const _ResultButton({required this.onPressed, required this.style});

  final VoidCallback? onPressed;
  final TextStyle style;

  static const _edge = 2.0;
  static const _glow = 0.22;
  static const _glowBlur = 36.0;
  static const _glowDrop = 14.0;

  @override
  Widget build(BuildContext context) {
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
      side: BorderSide(color: AppColors.ink, width: _edge),
    );
    return Semantics(
      container: true,
      button: true,
      label: '결과 보기',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.card),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: _glow),
                blurRadius: _glowBlur,
                offset: const Offset(0, _glowDrop),
              ),
            ],
          ),
          child: Material(
            color: AppColors.accent,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              // As wide as its words need, at least the design's width, and
              // never wider than the room it has.
              child: IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: BattleCameraArea._resultSize.width,
                    minHeight: BattleCameraArea._resultSize.height,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s24,
                      vertical: AppSpacing.s8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('결과 보기', maxLines: 1, style: style),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: BattleCameraArea._arrowSize,
                          color: AppColors.ink,
                        ),
                      ],
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
