import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'help_rules.dart';
import 'lobby_parts.dart';

/// The rules screen's first picture: a score pushing the health bar from
/// the player's lime toward the opponent's pink.
class HelpBarPicture extends StatelessWidget {
  const HelpBarPicture({super.key});

  /// The player's share of the bar a few reps in.
  static const _myShare = 65;

  /// The room before and after the score above the bar, 1.3 : 0.7 as the
  /// design spaces it, so the score sits over the lime part's end.
  static const _roomBefore = 13;
  static const _roomAfter = 7;

  /// The bar's ink edge.
  static const barEdge = 2.0;

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
        Row(
          children: [
            const Spacer(flex: _roomBefore),
            HelpMarkedPoints(HelpRules.barScore),
            const Spacer(flex: _roomAfter),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Text('KO', style: ko),
            const SizedBox(width: AppSpacing.s8),
            const Expanded(child: _HealthBar(myShare: _myShare)),
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
              Row(
                children: [
                  const HelpSwatch(AppColors.accent),
                  const SizedBox(width: AppSpacing.s4),
                  Text('나', style: side),
                ],
              ),
              Row(
                children: [
                  Text('상대', style: side),
                  const SizedBox(width: AppSpacing.s4),
                  const HelpSwatch(AppColors.opponent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('내 점수', style: note),
            const SizedBox(width: AppSpacing.s8),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.ink),
            const SizedBox(width: AppSpacing.s8),
            Text('바를 밀어요', style: note),
          ],
        ),
      ],
    );
  }
}

/// The battle's one health bar: white inside an ink edge, the player's lime
/// on the left and the opponent's pink on the right, a white gap between.
/// The two parts stretch to the bar's full inner height.
class _HealthBar extends StatelessWidget {
  const _HealthBar({required this.myShare});

  /// Out of 100.
  final int myShare;

  static const _edge = HelpBarPicture.barEdge;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.s24,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(
          Radius.circular(AppRadius.small - _edge),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: myShare,
              child: const ColoredBox(color: AppColors.accent),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              flex: 100 - myShare,
              child: const ColoredBox(color: AppColors.opponent),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small square of [color] with an ink edge beside "나" or "상대".
class HelpSwatch extends StatelessWidget {
  const HelpSwatch(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: AppHighlight.swatch(color),
    child: const SizedBox.square(dimension: AppHighlight.swatchSize),
  );
}

/// Points such as "+10" in ink, over a slanted lime band that leaves the
/// top of the digits clear, like a marker stroke.
class HelpMarkedPoints extends StatelessWidget {
  const HelpMarkedPoints(this.points, {super.key});

  final String points;

  /// The band's lean, as the design's `skewX(-12deg)`.
  static const _lean = 12.0;

  /// How far below the top of the line the band starts.
  static const _bandTop = 6.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          top: _bandTop,
          bottom: AppSpacing.s4,
          child: LobbySkew(
            degrees: _lean,
            alignment: Alignment.center,
            child: ColoredBox(color: AppColors.accent),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Text(
            points,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

/// The rules screen's second picture: the points per judgment, and the
/// battle's timeline with fever at the end.
class HelpScorePicture extends StatelessWidget {
  const HelpScorePicture({super.key});

  /// The timeline's ink edge.
  static const timelineEdge = 1.5;

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
        Container(
          height: AppSpacing.s32,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.small),
            ),
            border: Border.all(color: AppColors.ink, width: timelineEdge),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.small - timelineEdge),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: HelpRules.baseSeconds,
                  child: _TimelinePart(
                    color: AppColors.cardHigh,
                    label: HelpRules.baseLabel,
                    style: tick,
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  flex: HelpRules.feverSeconds,
                  child: _TimelinePart(
                    color: AppColors.accent,
                    label: HelpRules.feverLabel,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
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

/// One part of the timeline: its label in the middle of a [color] fill. The
/// label shrinks rather than breaks on a large system font.
class _TimelinePart extends StatelessWidget {
  const _TimelinePart({
    required this.color,
    required this.label,
    required this.style,
  });

  final Color color;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: style),
          ),
        ),
      ),
    );
  }
}

/// "+10" on its lime band over "Good", on a box a step lighter than the
/// card. Both shrink rather than break on a large system font: four tiles
/// share the line.
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s12,
        ),
        child: Column(
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: HelpMarkedPoints(points)),
            const SizedBox(height: AppSpacing.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
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
              HelpIconBox(icon: rule.icon, warning: rule.warning),
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

/// An ink icon on a 48-point box of color: red for a warning, else lime
/// (palette B: the color fills, the icon stays ink).
class HelpIconBox extends StatelessWidget {
  const HelpIconBox({super.key, required this.icon, required this.warning});

  final IconData icon;
  final bool warning;

  /// How much of the color shows, as the design: red at 30%, lime at 55%.
  static const warningStrength = 0.30;
  static const strength = 0.55;

  /// The box's fill.
  Color get fill => warning
      ? AppColors.danger.withValues(alpha: warningStrength)
      : AppColors.accent.withValues(alpha: strength);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: SizedBox.square(
        dimension: AppSpacing.s48,
        child: Icon(icon, color: AppColors.ink),
      ),
    );
  }
}
