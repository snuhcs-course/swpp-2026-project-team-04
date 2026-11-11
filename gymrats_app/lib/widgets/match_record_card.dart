import 'package:flutter/material.dart';

import '../models/exercise_type_korean.dart';
import '../models/match_record.dart';
import '../theme/app_theme.dart';

/// One battle in a card: result badge, the opponent over the exercise (with
/// the date when [showDate], and the one-line form feedback when
/// [showFeedback]), and both scores. Used by home's "최근 경기" and the
/// history list. Tappable when [onTap] is set.
class MatchRecordCard extends StatelessWidget {
  const MatchRecordCard({
    super.key,
    required this.match,
    this.showDate = false,
    this.showFeedback = false,
    this.onTap,
  });

  final MatchRecord match;
  final bool showDate;
  final bool showFeedback;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final playedAt = match.playedAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Row(
            children: [
              MatchOutcomeBadge(outcome: match.outcome),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A 12 letter name stays whole on a 360 wide phone, even
                    // beside wide scores. A bot's level is the end of its name.
                    Text(
                      'vs ${match.opponentName}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      showDate && playedAt != null
                          ? '${match.exercise.koreanName} · '
                                '${formatPlayedAt(playedAt)}'
                          : match.exercise.koreanName,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (showFeedback) ...[
                      const SizedBox(height: AppSpacing.s4),
                      FeedbackLine(match: match),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              _Scores(match: match),
            ],
          ),
        ),
      ),
    );
  }
}

/// "10월 15일 21:30", in the phone's time zone.
String formatPlayedAt(DateTime time) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.month}월 ${local.day}일 ${two(local.hour)}:${two(local.minute)}';
}

/// 승, 패 or 무 in the outcome color on a faint tint of it: lime when the
/// user won, pink when the opponent did.
class MatchOutcomeBadge extends StatelessWidget {
  const MatchOutcomeBadge({super.key, required this.outcome});

  final MatchOutcome outcome;

  /// Badge width and height.
  static const size = 40.0;

  static const _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    // Palette B: the outcome's color fills the badge, with an ink edge and
    // the label in ink, like WIN on lime and LOSE on pink.
    final fill = switch (outcome) {
      MatchOutcome.win => AppColors.accent,
      MatchOutcome.lose => AppColors.opponent,
      MatchOutcome.draw => AppColors.cardHigh,
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: Text(
        outcome.label,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: AppColors.ink),
      ),
    );
  }
}

/// My score and the opponent's, each with a label underneath. Mine always
/// stands out, whoever won. A battle saved before scores were kept shows its
/// reps, with a unit so they do not read as points.
class _Scores extends StatelessWidget {
  const _Scores({required this.match});

  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final number = text.titleLarge;
    final label = text.bodySmall;
    final (mine, theirs, unit) = match.hasScores
        ? (match.myScore!, match.opponentScore!, '')
        : (match.myReps, match.opponentReps, '회');
    Widget amount(int value, Color color) => Text.rich(
      TextSpan(
        text: '$value',
        children: [
          if (unit.isNotEmpty)
            TextSpan(
              text: unit,
              style: label?.copyWith(color: color),
            ),
        ],
      ),
      style: number?.copyWith(color: color),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            amount(mine, AppColors.textPrimary),
            const SizedBox(height: AppSpacing.s4),
            DecoratedBox(
              decoration: const ShapeDecoration(
                color: AppColors.accent,
                shape: StadiumBorder(),
              ),
              child: Padding(
                // Korean badge padding, 12 x 4 (2.5.7).
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s4,
                ),
                child: Text('나', style: label?.copyWith(color: AppColors.ink)),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          child: Text(':', style: number?.copyWith(color: AppColors.textMuted)),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            amount(theirs, AppColors.textSecondary),
            const SizedBox(height: AppSpacing.s4),
            Text('상대', style: label?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
/// The battle's form feedback in one line: the top thing to fix on an amber
/// band, "좋은 자세" on a lime band when there was nothing to fix, or
/// "피드백 없음" in gray for a battle stored without feedback.
class FeedbackLine extends StatelessWidget {
  const FeedbackLine({super.key, required this.match});

  final MatchRecord match;

  /// How much of the band's color shows behind the text.
  static const _bandStrength = 0.6;

  @override
  Widget build(BuildContext context) {
    final summary = match.feedbackSummary;
    // The icon's shape says it, and an amber or lime band behind the ink
    // text (palette B) shows it.
    final (icon, band, label) = switch (summary) {
      null => (Icons.remove_rounded, null, '피드백 없음'),
      _ when summary.topIssue != null => (
        Icons.error_outline_rounded,
        AppColors.warning,
        summary.line,
      ),
      _ => (Icons.check_circle_outline_rounded, AppColors.accent, summary.line),
    };
    final text = Theme.of(context).textTheme;
    final style = text.bodySmall!;
    return Row(
      children: [
        Icon(
          icon,
          color: band == null ? AppColors.line : AppColors.ink,
          size: text.bodyMedium?.fontSize,
        ),
        const SizedBox(width: AppSpacing.s4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: band == null
                ? style.copyWith(color: AppColors.textMuted)
                : AppHighlight.marked(
                    style,
                    band.withValues(alpha: _bandStrength),
                  ),
          ),
        ),
      ],
    );
  }
}
