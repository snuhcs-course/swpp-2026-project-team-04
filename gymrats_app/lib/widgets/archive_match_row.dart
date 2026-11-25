import 'package:flutter/material.dart';

import '../models/exercise_type_korean.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import '../theme/app_theme.dart';

/// The head of one day in the journal's 경기 tab (P13, draft C): "오늘 ·
/// 11.24 (화)", "어제 · …" or "11.21 (토)", and how many battles it had.
class ArchiveDayHeader extends StatelessWidget {
  const ArchiveDayHeader({
    super.key,
    required this.date,
    required this.count,
    required this.now,
    this.unit = '경기',
  });

  /// Local midnight of the day.
  final DateTime date;
  final int count;

  /// For "오늘" and "어제".
  final DateTime now;

  /// What [count] counts: "경기", or "기록" when holds are among them.
  final String unit;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  /// "오늘 · 11.24 (화)", "어제 · 11.23 (월)" or "11.21 (토)".
  static String dayLine(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final label =
        '${day.month}.${day.day.toString().padLeft(2, '0')} '
        '(${_weekdays[day.weekday - 1]})';
    if (day == today) return '오늘 · $label';
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return '어제 · $label';
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = text.archiveLabel.copyWith(color: AppColors.textSecondary);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          AppSpacing.s16,
          AppSpacing.s20,
          AppSpacing.s4,
        ),
        child: Row(
          children: [
            Expanded(child: Text(dayLine(date, now.toLocal()), style: style)),
            Text('$count$unit', style: style),
          ],
        ),
      ),
    );
  }
}

/// One battle in the journal's 경기 tab (P13, draft C): a result chip (승,
/// 패, 무, KO승 or KO패), "푸쉬업 · vs 러너", the time and the kind (온라인,
/// 아케이드, 상대 나감), the user's score with its unit and the counted reps,
/// and a lime "↑55" chip when it raised the exercise's best. Tappable when
/// [onTap] is set.
class ArchiveMatchRow extends StatelessWidget {
  const ArchiveMatchRow({
    super.key,
    required this.match,
    this.bestGain,
    this.onTap,
  });

  final MatchRecord match;

  /// How much the battle beat the earlier best; null for no chip.
  final int? bestGain;
  final VoidCallback? onTap;

  static const minHeight = 68.0;
  static const _chip = 44.0;
  static const _chevron = 18.0;
  static const _loseTint = 0.22;

  /// The chip's word: "승", "KO승", "패", "KO패" or "무".
  static String chipLabel(MatchRecord match) {
    final ko = match.gameEnd == GameEnd.ko ? 'KO' : '';
    return switch (match.outcome) {
      MatchOutcome.win => '$ko승',
      MatchOutcome.lose => '$ko패',
      MatchOutcome.draw => '무',
    };
  }

  /// "푸쉬업 · vs 러너".
  static String titleLine(MatchRecord match) =>
      '${match.exercise.koreanName} · vs ${match.opponentName}';

  /// "16:04 · 온라인 · 상대 나감": the time when kept, the kind when the
  /// server said it, and the opponent leaving.
  static String detailLine(MatchRecord match) {
    final at = match.playedAt?.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return [
      if (at != null) '${two(at.hour)}:${two(at.minute)}',
      switch (match.isOnline) {
        true => '온라인',
        false => '아케이드',
        null => null,
      },
      if (match.opponentLeft) '상대 나감',
    ].nonNulls.join(' · ');
  }

  /// The score's words: "15점", or the reps for a battle without a score.
  static String scoreWords(MatchRecord match) {
    final score = match.myScore;
    return score == null ? '${match.myReps}회' : '$score점';
  }

  static Color _chipColor(MatchOutcome outcome) => switch (outcome) {
    MatchOutcome.win => AppColors.accent,
    MatchOutcome.lose => AppColors.opponent.withValues(alpha: _loseTint),
    MatchOutcome.draw => AppColors.facetLight,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final quiet = text.feedbackMeta;
    final gain = bestGain;
    final score = match.myScore;
    final detail = detailLine(match);
    // One node for a screen reader: the row's words and its tap.
    return MergeSemantics(
      child: Material(
        color: AppColors.card,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s20,
                vertical: AppSpacing.s12,
              ),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: _chip,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _chipColor(match.outcome),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(AppRadius.small),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          chipLabel(match),
                          maxLines: 1,
                          style: text.reportCardTitle.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titleLine(match),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.reportCardTitle,
                        ),
                        if (detail.isNotEmpty)
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: quiet,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${score ?? match.myReps}',
                              style: text.archiveScore.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                            TextSpan(
                              text: score == null ? ' 회' : ' 점',
                              style: text.archiveLabel,
                            ),
                          ],
                        ),
                        semanticsLabel: scoreWords(match),
                      ),
                      if (score != null)
                        Text('인정 ${match.myReps}회', style: quiet),
                      if (gain != null) ...[
                        const SizedBox(height: AppSpacing.s4),
                        _GainChip(gain: gain),
                      ],
                    ],
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: _chevron,
                    color: AppColors.inactive,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "↑55" in ink on a lime band: the battle set a new best by 55 points.
class _GainChip extends StatelessWidget {
  const _GainChip({required this.gain});

  final int gain;

  static const _radius = 6.0;
  static const _arrowSize = 12.0;
  static const _strength = 0.6;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '최고 기록 $gain점 경신',
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const ValueKey('archive-gain-chip'),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: _strength),
            borderRadius: const BorderRadius.all(Radius.circular(_radius)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_upward_rounded,
                  size: _arrowSize,
                  color: AppColors.ink,
                ),
                Text(
                  '$gain',
                  style: Theme.of(context).textTheme.archiveRowGain
                      .copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
