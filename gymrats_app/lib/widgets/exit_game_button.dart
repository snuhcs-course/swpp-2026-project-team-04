import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "게임 나가기" with an exit icon on a card-colored pill, for leaving a
/// found match from the versus and setup screens.
class ExitGameButton extends StatelessWidget {
  const ExitGameButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded),
      label: const Text('게임 나가기'),
      style: OutlinedButton.styleFrom(
        // The tap target pads it to 48, as tall as SetupScreen's buttons.
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        textStyle: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
