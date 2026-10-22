import 'package:flutter/material.dart';

import '../models/exercise_type_korean.dart';
import '../models/match_record.dart';
import '../theme/app_theme.dart';

/// One battle in a card: result badge, exercise and opponent (and the date
/// when [showDate], the one-line form feedback when [showFeedback]), and
/// both scores. Used by home's "최근 경기" and the history list. Tappable
/// when [onTap] is set.
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
                    Text(
                      '${match.exercise.koreanName} · vs ${match.opponentName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge,
                    ),
                    if (showDate && playedAt != null) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        formatPlayedAt(playedAt),
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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

  @override
  Widget build(BuildContext context) {
    final color = switch (outcome) {
      MatchOutcome.win => AppColors.accent,
      MatchOutcome.lose => AppColors.opponent,
      MatchOutcome.draw => AppColors.textSecondary,
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Text(
        outcome.label,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: color),
      ),
    );
  }
}

/// My score and the opponent's, each with a label underneath. Mine always
/// stands out, whoever won.
class _Scores extends StatelessWidget {
  const _Scores({required this.match});

  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final number = text.titleLarge;
    final label = text.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${match.myReps}',
              style: number?.copyWith(color: AppColors.textPrimary),
            ),
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
                child: Text(
                  '나',
                  style: label?.copyWith(color: AppColors.background),
                ),
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
            Text(
              '${match.opponentReps}',
              style: number?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('상대', style: label?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
/// The battle's form feedback in one line: the top thing to fix in amber,
/// "좋은 자세" in lime when there was nothing to fix, or "피드백 없음" for a
/// battle stored without feedback.
class FeedbackLine extends StatelessWidget {
  const FeedbackLine({super.key, required this.match});

  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    final summary = match.feedbackSummary;
    final (icon, color, label) = switch (summary) {
      null => (Icons.remove_rounded, AppColors.textMuted, '피드백 없음'),
      _ when summary.topIssue != null => (
        Icons.error_outline_rounded,
        AppColors.warning,
        summary.line,
      ),
      _ => (Icons.check_circle_outline_rounded, AppColors.accent, summary.line),
    };
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, color: color, size: text.bodyMedium?.fontSize),
        const SizedBox(width: AppSpacing.s4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
