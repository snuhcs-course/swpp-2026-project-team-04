import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// An X in a rounded square on the card color, at the top left of the
/// matching and versus screens.
class SquareCloseButton extends StatelessWidget {
  const SquareCloseButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  /// Also what screen readers announce.
  final String tooltip;

  final VoidCallback onPressed;

  /// Side of the square.
  static const size = 46.0;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.card,
        fixedSize: const Size.square(size),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
