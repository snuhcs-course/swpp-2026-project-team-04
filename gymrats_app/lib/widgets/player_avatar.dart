import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A player's picture: an ink ring on a faint fill of the player's color,
/// with a halo of that color around it (palette B: the color only fills).
///
/// Inside, a bot shows an ink robot, anyone else the first letter of [name].
/// A person icon stands in while the name is unknown.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.color,
    this.name,
    this.isBot = false,
    this.size = 104,
  });

  /// Halo and fill color: lime for the user, pink for the opponent.
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
      content = Icon(
        Icons.smart_toy_rounded,
        size: size * 0.4,
        color: AppColors.ink,
      );
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
          color: color.withValues(alpha: _haloOf(color)),
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
              border: Border.all(color: AppColors.ink, width: size * 0.035),
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }

  /// How much of [color] the halo shows, as the design draws it: the pink
  /// is the stronger color, so it shows less than the lime.
  static double _haloOf(Color color) => color == AppColors.opponent ? 0.3 : 0.4;
}
