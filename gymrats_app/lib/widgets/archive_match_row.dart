import 'package:flutter/material.dart';

import '../models/exercise_type_korean.dart';
import '../models/game_score.dart';
import '../models/hold_record.dart';
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
/// and "개인 최고" beside the title when it raised the exercise's best.
/// Tappable when [onTap] is set.
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
                        // The title, and "개인 최고" beside it when the battle
                        // raised the exercise's best (draft C).
                        Wrap(
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              titleLine(match),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.reportCardTitle,
                            ),
                            if (gain != null) _BestBadge(gain: gain),
                          ],
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

/// "개인 최고" in green on a pale lime band, beside a battle's title when
/// it raised the exercise's best (draft C); a screen reader hears by how
/// much.
class _BestBadge extends StatelessWidget {
  const _BestBadge({required this.gain});

  final int gain;

  static const label = '개인 최고';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, 최고 기록 $gain점 경신',
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const ValueKey('archive-best-badge'),
          decoration: const BoxDecoration(
            color: AppColors.selectedFill,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: AppSpacing.s4 / 2,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.archiveRowGain
                  .copyWith(color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// One played hold in the journal's 경기 tab (P13): a star chip (lime with a
/// star, pink without), "하이 플랭크 · 3스테이지", the time, 버티기 and the
/// warnings, the time held and the stars. Tappable when [onTap] is set: the
/// hold's report.
class ArchiveHoldRow extends StatelessWidget {
  const ArchiveHoldRow({super.key, required this.hold, this.onTap});

  final HoldRecord hold;
  final VoidCallback? onTap;

  static const _chip = 44.0;
  static const _chevron = 18.0;
  static const _failTint = 0.22;

  /// "하이 플랭크 · 3스테이지".
  static String titleLine(HoldRecord hold) =>
      '${hold.pose.label} · ${hold.stage}스테이지';

  /// "21:10 · 버티기 · 경고 2".
  static String detailLine(HoldRecord hold) {
    final at = hold.endedAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return [
      '${two(at.hour)}:${two(at.minute)}',
      '버티기',
      if (hold.warnings.isNotEmpty) '경고 ${hold.warnings.length}',
    ].join(' · ');
  }

  /// "24.6".
  static String heldWords(HoldRecord hold) {
    final tenths = (hold.held.inMilliseconds / 100).round() / 10;
    return tenths == tenths.roundToDouble()
        ? tenths.toStringAsFixed(0)
        : tenths.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final quiet = text.feedbackMeta;
    final cleared = hold.stars > 0;
    return MergeSemantics(
      child: Material(
        color: AppColors.card,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ArchiveMatchRow.minHeight,
            ),
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
                        color: cleared
                            ? AppColors.accent
                            : AppColors.opponent.withValues(alpha: _failTint),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(AppRadius.small),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '★${hold.stars}',
                          semanticsLabel: '별 ${hold.stars}개',
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
                          titleLine(hold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.reportCardTitle,
                        ),
                        Text(
                          detailLine(hold),
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
                              text: heldWords(hold),
                              style: text.archiveScore.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                            TextSpan(text: ' 초', style: text.archiveLabel),
                          ],
                        ),
                        semanticsLabel: '${heldWords(hold)}초 버팀',
                      ),
                      Text(
                        '별 ${hold.stars}/${hold.starSeconds.length}',
                        style: quiet,
                      ),
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
