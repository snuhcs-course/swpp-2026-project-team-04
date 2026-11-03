import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'help_rules.dart';

/// The rules screen's first picture: a score pushing the health bar from
/// the player's lime toward the opponent's pink.
class HelpBarPicture extends StatelessWidget {
  const HelpBarPicture({super.key});

  /// The player's share of the bar a few reps in.
  static const _myShare = 65;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ko = text.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w700,
    );
    final side = text.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    final note = text.bodySmall?.copyWith(color: AppColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Above the end of the lime part.
        Align(
          alignment: const Alignment(0.3, 0),
          child: Text(
            HelpRules.barScore,
            style: text.titleLarge?.copyWith(color: AppColors.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Text('KO', style: ko),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.small),
                ),
                child: SizedBox(
                  height: AppSpacing.s24,
                  child: Row(
                    children: [
                      const Expanded(
                        flex: _myShare,
                        child: ColoredBox(color: AppColors.accent),
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      const Expanded(
                        flex: 100 - _myShare,
                        child: ColoredBox(color: AppColors.opponent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text('KO', style: ko),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('나', style: side?.copyWith(color: AppColors.accent)),
              Text('상대', style: side?.copyWith(color: AppColors.opponent)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('내 점수', style: note),
            const SizedBox(width: AppSpacing.s8),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.accent),
            const SizedBox(width: AppSpacing.s8),
            Text('바를 밀어요', style: note),
          ],
        ),
      ],
    );
  }
}

/// The rules screen's second picture: the points per judgment, and the
/// battle's timeline with fever at the end.
class HelpScorePicture extends StatelessWidget {
  const HelpScorePicture({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tick = text.bodySmall?.copyWith(color: AppColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (index, (points, label))
                in HelpRules.scores.indexed) ...[
              if (index > 0) const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: _ScoreTile(points: points, label: label),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.s24),
        ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.small),
          ),
          child: SizedBox(
            height: AppSpacing.s32,
            child: Row(
              children: [
                Expanded(
                  flex: HelpRules.baseSeconds,
                  child: ColoredBox(
                    color: AppColors.cardHigh,
                    child: Center(
                      child: Text(HelpRules.baseLabel, style: tick),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  flex: HelpRules.feverSeconds,
                  child: ColoredBox(
                    color: AppColors.accent,
                    child: Center(
                      child: Text(
                        HelpRules.feverLabel,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0초', style: tick),
            Text('${HelpRules.totalSeconds}초', style: tick),
          ],
        ),
      ],
    );
  }
}

/// "+10" over "Good" on a box a step lighter than the card. Both shrink rather
/// than break on a large system font: four tiles share the line.
class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.points, required this.label});

  final String points;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.cardHigh,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  points,
                  maxLines: 1,
                  style: text.titleLarge?.copyWith(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rules screen's last picture: the danger edge, the winner, and
/// safety, one row each.
class HelpReminderPicture extends StatelessWidget {
  const HelpReminderPicture({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final (index, rule) in HelpRules.reminders.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              _IconBox(icon: rule.icon, warning: rule.warning),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      rule.body,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// An icon on a faint box of its own color: red for a warning, else lime.
class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.warning});

  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.danger : AppColors.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Icon(icon, color: color),
      ),
    );
  }
}
