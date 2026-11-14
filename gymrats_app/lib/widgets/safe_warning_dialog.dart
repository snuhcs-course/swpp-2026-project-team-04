import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reminds the player not to overdo it, once a match is found and before
/// the pose setup: a picture of a push-up done too hard, then 무리하지 마세요
/// and a lime 확인 button.
///
/// Pops true on 확인. With [autoClose] (online matches) it also closes by
/// itself, counting down on the button, and pops true, because the server
/// cancels a match whose players are not ready in time. Back pops false, so
/// the screen below can ask whether to leave; a tap outside does nothing.
/// Under the button a line says what happens next (copy of sketch A; the
/// online line names the seconds left).
class SafeWarningDialog extends StatefulWidget {
  const SafeWarningDialog({super.key, this.autoClose});

  /// How long it stays open at most, in whole seconds; null waits for 확인.
  final Duration? autoClose;

  /// What a screen reader says for the picture ([SafeWarningPicturePainter]).
  static const pictureLabel = '팔을 깊게 굽힌 채 무리하다 팔꿈치를 다친 모습';

  @override
  State<SafeWarningDialog> createState() => _SafeWarningDialogState();
}

class _SafeWarningDialogState extends State<SafeWarningDialog> {
  /// The ink edge of 확인.
  static const _edge = 2.0;

  Timer? _tick;

  /// Seconds left on the countdown; null without [SafeWarningDialog.autoClose].
  int? _secondsLeft;

  /// Set once it has popped, so 확인 and the countdown never pop twice.
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final autoClose = widget.autoClose;
    if (autoClose == null) return;
    _secondsLeft = autoClose.inSeconds;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _secondsLeft! - 1;
      if (left <= 0) {
        _close(confirmed: true);
      } else {
        setState(() => _secondsLeft = left);
      }
    });
  }

  void _close({required bool confirmed}) {
    if (_closed) return;
    _closed = true;
    _tick?.cancel();
    Navigator.pop(context, confirmed);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final left = _secondsLeft;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(confirmed: false);
      },
      child: Dialog(
        backgroundColor: AppColors.card,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s32,
          vertical: AppSpacing.s24,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sheet)),
          side: BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          // Phone sized, like the exit dialog.
          constraints: const BoxConstraints(maxWidth: 360),
          // Scrolls rather than overflow on a short screen.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s24,
              AppSpacing.s24,
              AppSpacing.s24,
              AppSpacing.s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Picture(),
                const SizedBox(height: AppSpacing.s20),
                Text(
                  '무리하지 마세요',
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.s8),
                // Line breaks are written in: Korean would otherwise break
                // inside a word.
                _KeepLines(
                  child: Text(
                    '무리해서 운동하면 몸을 다칠 수 있어요.\n몸 상태를 살피며 플레이해 주세요.',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
                FilledButton(
                  onPressed: () => _close(confirmed: true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    // Lime with an ink edge, as the design (palette B).
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.card),
                      ),
                      side: BorderSide(color: AppColors.ink, width: _edge),
                    ),
                    textStyle: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(left == null ? '확인' : '확인 ($left)'),
                ),
                const SizedBox(height: AppSpacing.s12),
                _KeepLines(
                  child: Text(
                    left == null
                        ? '확인을 누르면 자세 세팅을 시작할 수 있어요'
                        : '$left초 뒤 자동으로 닫혀요',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
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

/// Keeps [child]'s lines as they are written at the system's own text size,
/// shrinking them a little where a line is a few points too wide for the
/// dialog: Korean would otherwise break inside a word and leave one
/// syllable alone. With a larger text size the lines wrap as usual, so the
/// letters keep the size the user asked for.
class _KeepLines extends StatelessWidget {
  const _KeepLines({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(1) > 1) return child;
    return FittedBox(fit: BoxFit.scaleDown, child: child);
  }
}

/// The picture ([SafeWarningPicturePainter]) on a box a step lighter than
/// the dialog, read as one picture by a screen reader.
class _Picture extends StatelessWidget {
  const _Picture();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.cardHigh,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Center(
          child: Semantics(
            container: true,
            image: true,
            label: SafeWarningDialog.pictureLabel,
            child: const CustomPaint(
              size: SafeWarningPicturePainter.size,
              painter: SafeWarningPicturePainter(),
            ),
          ),
        ),
      ),
    );
  }
}

/// The safety picture of the design (`BMatchFound.dc.html`, its 240 x 150
/// SVG): a push-up done too hard, the arms bent deep, an impact star at the
/// elbow. Lines in [AppColors.line] on the light box; the head a white
/// circle with a [AppColors.line] edge; the star [AppColors.warning] with an
/// ink edge. The numbers are the SVG's, in its own points. A box of another
/// size draws it as the SVG's view box does: scaled the same both ways, as
/// large as fits, in the middle (the dialog is 232 wide on a 360 phone).
class SafeWarningPicturePainter extends CustomPainter {
  const SafeWarningPicturePainter();

  /// The SVG's view box, and the size the dialog draws it at.
  static const size = Size(240, 150);

  /// `M16 132 H224`, 4 wide, round ends.
  static const floor = (start: Offset(16, 132), end: Offset(224, 132));
  static const floorWidth = 4.0;

  /// The body, `M80 100 L150 112 L206 127`, 9 wide, round.
  static const body = [Offset(80, 100), Offset(150, 112), Offset(206, 127)];
  static const bodyWidth = 9.0;

  /// The bent arm, `M84 102 L104 116 L86 128`, 7 wide, round.
  static const arm = [Offset(84, 102), Offset(104, 116), Offset(86, 128)];
  static const armWidth = 7.0;

  /// The head, `circle cx 60 cy 92 r 13`, white with a 3 wide edge.
  static const head = (center: Offset(60, 92), radius: 13.0);
  static const headEdge = 3.0;

  /// The two sweat drops, `M42 60 q5 7 0 11 q-5 -4 0 -11 z` and
  /// `M30 74 q4 6 0 9 q-4 -3 0 -9 z`, in absolute points: from the top,
  /// curving out to the right to the bottom and back on the left.
  static const drops = [
    (
      top: Offset(42, 60),
      right: Offset(47, 67),
      bottom: Offset(42, 71),
      left: Offset(37, 67),
    ),
    (
      top: Offset(30, 74),
      right: Offset(34, 80),
      bottom: Offset(30, 83),
      left: Offset(26, 80),
    ),
  ];

  /// The impact star's 12 corners, with a 1.5 wide ink edge.
  static const star = [
    Offset(106, 95),
    Offset(109, 104.8),
    Offset(119, 102.5),
    Offset(112, 110),
    Offset(119, 117.5),
    Offset(109, 115.2),
    Offset(106, 125),
    Offset(103, 115.2),
    Offset(93, 117.5),
    Offset(100, 110),
    Offset(93, 102.5),
    Offset(103, 104.8),
  ];
  static const starEdge = 1.5;

  static Path _line(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const own = SafeWarningPicturePainter.size;
    final scale = math.min(size.width / own.width, size.height / own.height);
    canvas.save();
    canvas.translate(
      (size.width - own.width * scale) / 2,
      (size.height - own.height * scale) / 2,
    );
    canvas.scale(scale, scale);
    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = width;
    Paint round(Paint paint) => paint
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(
      floor.start,
      floor.end,
      stroke(AppColors.line, floorWidth)..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(_line(body), round(stroke(AppColors.line, bodyWidth)));
    canvas.drawPath(_line(arm), round(stroke(AppColors.line, armWidth)));
    canvas.drawCircle(
      head.center,
      head.radius,
      Paint()..color = AppColors.card,
    );
    canvas.drawCircle(
      head.center,
      head.radius,
      stroke(AppColors.line, headEdge),
    );
    for (final drop in drops) {
      canvas.drawPath(
        Path()
          ..moveTo(drop.top.dx, drop.top.dy)
          ..quadraticBezierTo(
            drop.right.dx,
            drop.right.dy,
            drop.bottom.dx,
            drop.bottom.dy,
          )
          ..quadraticBezierTo(
            drop.left.dx,
            drop.left.dy,
            drop.top.dx,
            drop.top.dy,
          )
          ..close(),
        Paint()..color = AppColors.line,
      );
    }
    final starPath = _line(star)..close();
    canvas.drawPath(starPath, Paint()..color = AppColors.warning);
    canvas.drawPath(
      starPath,
      stroke(AppColors.ink, starEdge)..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SafeWarningPicturePainter oldDelegate) => false;
}

/// The route [showSafeWarning] pushes, for a screen that must be able to
/// close the warning itself: push it on the root navigator, as showDialog
/// does.
DialogRoute<bool> safeWarningRoute(
  BuildContext context, {
  Duration? autoClose,
}) => DialogRoute<bool>(
  context: context,
  barrierDismissible: false,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  themes: InheritedTheme.capture(
    from: context,
    to: Navigator.of(context, rootNavigator: true).context,
  ),
  builder: (_) => SafeWarningDialog(autoClose: autoClose),
);

/// Shows [SafeWarningDialog]. True once it is seen (확인, or the countdown
/// ran out), false when back closed it, and null when something else
/// removed it, such as a logout closing every screen.
Future<bool?> showSafeWarning(BuildContext context, {Duration? autoClose}) =>
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(safeWarningRoute(context, autoClose: autoClose));
