import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A player's picture: a colored ring with a soft halo around it.
///
/// Inside, a bot shows a robot, anyone else the first letter of [name]. A
/// person icon stands in while the name is unknown.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.color,
    this.name,
    this.isBot = false,
    this.size = 104,
  });

  /// Ring and halo color: lime for the user, pink for the opponent.
  final Color color;

  final String? name;
  final bool isBot;

  /// Outer diameter, halo included.
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    final Widget content;
    if (isBot) {
      content = Icon(Icons.smart_toy_rounded, size: size * 0.4, color: color);
    } else if (name == null || name.isEmpty) {
      content = Icon(
        Icons.person_rounded,
        size: size * 0.4,
        color: AppColors.textSecondary,
      );
    } else {
      content = Text(
        name.characters.first,
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontSize: size * 0.34,
          height: 1,
        ),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.alphaBlend(
                color.withValues(alpha: 0.06),
                AppColors.cardHigh,
              ),
              border: Border.all(color: color, width: size * 0.035),
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
