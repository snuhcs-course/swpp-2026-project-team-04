import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Asks before leaving the match flow: a pink exit icon, [title] over
/// [message], a big lime [stayLabel] button and a pink [leaveLabel] one.
///
/// Pops true for [leaveLabel], false for [stayLabel].
class ExitDialog extends StatelessWidget {
  const ExitDialog({
    super.key,
    required this.title,
    required this.message,
    required this.leaveLabel,
    this.stayLabel = '계속하기',
  });

  /// For leaving a found match, on the versus and setup screens.
  const ExitDialog.game({super.key, required String opponentName})
    : title = '게임에서 나갈까요?',
      // Fixed 과: RepBot is the only opponent until real users can match.
      message = '$opponentName과의 대결이 취소되고\n홈으로 돌아가요.',
      leaveLabel = '게임 나가기',
      stayLabel = '계속하기';

  /// For leaving the search, on the matching screen.
  const ExitDialog.matching({super.key})
    : title = '매칭을 취소할까요?',
      message = '상대 찾기를 멈추고\n홈으로 돌아가요.',
      leaveLabel = '매칭 취소',
      stayLabel = '계속하기';

  final String title;

  /// Line breaks are written into it: Korean would otherwise break inside
  /// a word.
  final String message;

  final String leaveLabel;
  final String stayLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final buttonText = text.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        // Phone sized even when setup turns the screen sideways.
        constraints: const BoxConstraints(maxWidth: 360),
        // Scrolls rather than overflow on a short landscape screen.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ExitIcon(),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  textStyle: buttonText,
                ),
                child: Text(stayLabel),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.opponent,
                  textStyle: buttonText,
                ),
                child: Text(leaveLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The exit icon in pink on a faint pink circle.
class _ExitIcon extends StatelessWidget {
  const _ExitIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.opponent.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.logout_rounded,
          size: 26,
          color: AppColors.opponent,
        ),
      ),
    );
  }
}

/// Shows [dialog]. True only for its leave button: the stay button, a tap
/// outside, or back while it is open all mean stay.
Future<bool> confirmExit(BuildContext context, ExitDialog dialog) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (_) => dialog,
  );
  return leave ?? false;
}

/// Leaves the matching flow: closes every screen above home.
///
/// These are plain pops, which `PopScope(canPop: false)` does not stop; it
/// only hears about them, with `didPop` true.
void popToHome(BuildContext context) =>
    Navigator.popUntil(context, (route) => route.isFirst);
