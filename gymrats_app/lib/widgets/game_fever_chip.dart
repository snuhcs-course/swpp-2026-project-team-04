import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "FEVER ×2" in dark letters on cyan, while every score counts more.
class GameFeverChip extends StatelessWidget {
  const GameFeverChip({super.key, required this.multiplier});

  /// What fever multiplies the points by.
  final int multiplier;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: AppColors.fever,
        shape: StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        child: Text(
          'FEVER ×$multiplier',
          maxLines: 1,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.background,
          ),
        ),
      ),
    );
  }
}
