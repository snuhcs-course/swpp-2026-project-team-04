import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Big lime button: title and optional hint on the left, an arrow on the
/// right, and a soft lime glow underneath.
class AccentButton extends StatelessWidget {
  const AccentButton({
    super.key,
    required this.title,
    this.hint,
    required this.onPressed,
  });

  final String title;

  /// Smaller line under [title]; left out when null.
  final String? hint;

  final VoidCallback onPressed;

  static const _radius = BorderRadius.all(Radius.circular(AppTheme.cardRadius));
  static const _edge = 2.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hint = this.hint;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.22),
            offset: const Offset(0, 14),
            blurRadius: 36,
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.fromLTRB(24, 18, 20, 18),
          // An ink edge so the lime shows against the light screen
          // (palette B).
          shape: const RoundedRectangleBorder(
            borderRadius: _radius,
            side: BorderSide(color: AppColors.ink, width: _edge),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.headlineSmall?.copyWith(color: AppColors.ink),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      style: text.bodyMedium?.copyWith(color: AppColors.ink),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 28,
              color: AppColors.ink,
            ),
          ],
        ),
      ),
    );
  }
}
