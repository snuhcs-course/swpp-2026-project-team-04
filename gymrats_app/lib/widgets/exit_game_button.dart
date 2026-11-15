import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "게임 나가기" with an exit icon on a card-colored pill, for leaving a
/// found match from the versus and setup screens.
class ExitGameButton extends StatelessWidget {
  const ExitGameButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const _iconSize = 18.0;
  static const _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded, size: _iconSize),
      label: const Text('게임 나가기'),
      style: OutlinedButton.styleFrom(
        // The tap target pads it to 48, as tall as SetupScreen's buttons.
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        // A line, as the design's outlined buttons (palette B rule 3).
        side: const BorderSide(color: AppColors.line, width: _edge),
        shape: const StadiumBorder(),
        textStyle: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
