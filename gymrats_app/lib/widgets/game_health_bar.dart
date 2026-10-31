import 'package:flutter/material.dart';

import '../models/game_score.dart';
import '../theme/app_theme.dart';

/// The tug-of-war bar: lime from the left for the user, pink for the rest,
/// half and half at the start. Over it, each side's share and its latest +N.
class GameHealthBar extends StatelessWidget {
  const GameHealthBar({
    super.key,
    required this.myShare,
    this.myLastScore,
    this.opponentLastScore,
  });

  /// The user's share of the bar, from 0 to 1.
  final double myShare;

  /// What the latest valid reps earned. A new one pops up over the bar.
  final GameRepScore? myLastScore;
  final GameRepScore? opponentLastScore;

  static const _barHeight = 16.0;

  /// Fits a popup, so the bar stays put when one appears.
  static const _labelsHeight = 28.0;
  static const _centerLineWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final percent = (myShare * 100).round();
    final labels = Theme.of(context).textTheme.bodySmall;
    final my = myLastScore;
    final their = opponentLastScore;
    return Semantics(
      label: '체력 바, 나 $percent%, 상대 ${100 - percent}%',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _labelsHeight,
            child: Row(
              children: [
                Text(
                  '나 $percent%',
                  style: labels?.copyWith(color: AppColors.accent),
                ),
                const SizedBox(width: AppSpacing.s8),
                if (my != null)
                  _ScorePopup(
                    key: ObjectKey(my),
                    points: my.points,
                    color: AppColors.accent,
                  ),
                const Spacer(),
                if (their != null)
                  _ScorePopup(
                    key: ObjectKey(their),
                    points: their.points,
                    color: AppColors.opponent,
                  ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  '상대 ${100 - percent}%',
                  style: labels?.copyWith(color: AppColors.opponent),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: SizedBox(
              height: _barHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.opponent),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: myShare),
                    duration: const Duration(milliseconds: 220),
                    builder: (_, share, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        key: const Key('myBarShare'),
                        widthFactor: share,
                        heightFactor: 1,
                        child: const ColoredBox(color: AppColors.accent),
                      ),
                    ),
                  ),
                  Center(
                    child: SizedBox(
                      width: _centerLineWidth,
                      height: _barHeight,
                      child: ColoredBox(
                        color: AppColors.background.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "+15", which fades in, stays a moment, and fades away.
class _ScorePopup extends StatelessWidget {
  const _ScorePopup({super.key, required this.points, required this.color});

  final int points;
  final Color color;

  static const _duration = Duration(milliseconds: 1200);

  /// Opacity at [t] of the popup's life, from 0 to 1.
  static double _opacity(double t) {
    if (t < 0.15) return t / 0.15;
    if (t > 0.7) return (1 - t) / 0.3;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _duration,
      child: Text(
        '+$points',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
      ),
      builder: (_, t, child) => Opacity(opacity: _opacity(t), child: child),
    );
  }
}
