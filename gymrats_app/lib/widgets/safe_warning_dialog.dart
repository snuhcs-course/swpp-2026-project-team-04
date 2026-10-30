import 'dart:async';

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

  /// The picture at 1x; its 2.0x and 3.0x variants sit in the folders of
  /// those names next to it.
  static const picture = 'assets/images/safe_warning.png';

  /// What a screen reader says for [picture].
  static const pictureLabel = '팔을 깊게 굽힌 채 무리하다 팔꿈치를 다친 모습';

  @override
  State<SafeWarningDialog> createState() => _SafeWarningDialogState();
}

class _SafeWarningDialogState extends State<SafeWarningDialog> {
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
                Text(
                  '무리해서 운동하면 몸을 다칠 수 있어요.\n몸 상태를 살피며 플레이해 주세요.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
                FilledButton(
                  onPressed: () => _close(confirmed: true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.card),
                      ),
                    ),
                    textStyle: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(left == null ? '확인' : '확인 ($left)'),
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  left == null
                      ? '확인을 누르면 자세 세팅을 시작할 수 있어요'
                      : '$left초 뒤 자동으로 닫혀요',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
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

/// [SafeWarningDialog.picture] on a box a step lighter than the dialog.
class _Picture extends StatelessWidget {
  const _Picture();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardHigh,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.s8),
        child: Center(
          child: Image(
            image: AssetImage(SafeWarningDialog.picture),
            width: 240,
            height: 150,
            semanticLabel: SafeWarningDialog.pictureLabel,
          ),
        ),
      ),
    );
  }
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
