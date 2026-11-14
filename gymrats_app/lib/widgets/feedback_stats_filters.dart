import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/feedback_stats.dart';
import '../theme/app_theme.dart';

/// 전체 | 이번 달 | 이번 주 on a white track (W7-STATS 2): three equal tabs,
/// the picked one white on ink. A screen reader hears each as a button of
/// the group "기간" and which one is picked.
class FeedbackStatsPeriodTabs extends StatelessWidget {
  const FeedbackStatsPeriodTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final StatsPeriod selected;
  final ValueChanged<StatsPeriod> onSelect;

  /// In the order of UAT-4 AC3 (user, 2026-11-14).
  static const periods = [StatsPeriod.all, StatsPeriod.month, StatsPeriod.week];

  static String nameOf(StatsPeriod period) => switch (period) {
    StatsPeriod.all => '전체',
    StatsPeriod.month => '이번 달',
    StatsPeriod.week => '이번 주',
  };

  static const tabHeight = 44.0;
  static const _trackRadius = 14.0;
  static const _inset = 2.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.lobbyRowTitle;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '기간',
      child: Container(
        padding: const EdgeInsets.all(_inset),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.all(Radius.circular(_trackRadius)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            for (final (index, period) in periods.indexed) ...[
              if (index > 0) const SizedBox(width: _inset),
              Expanded(
                child: TextButton(
                  onPressed: () => onSelect(period),
                  style: TextButton.styleFrom(
                    fixedSize: const Size.fromHeight(tabHeight),
                    minimumSize: const Size(0, tabHeight),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: period == selected
                        ? AppColors.ink
                        : Colors.transparent,
                    foregroundColor: period == selected
                        ? AppColors.onInk
                        : AppColors.textSecondary,
                    textStyle: style,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.small),
                      ),
                    ),
                  ),
                  // Inside the button, so its node says it is the picked one.
                  child: Semantics(
                    selected: period == selected,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(nameOf(period), maxLines: 1),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 푸쉬업 · 스쿼트 · 둘 다 (W7-STATS 2): pill chips 32 high in a 44 high tap
/// row; the picked one lime with an ink edge. Both exercises are null.
class FeedbackStatsExerciseChips extends StatelessWidget {
  const FeedbackStatsExerciseChips({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final ExerciseType? selected;
  final ValueChanged<ExerciseType?> onSelect;

  /// Push-ups, squats, then both (null).
  static const choices = <ExerciseType?>[
    ExerciseType.pushUp,
    ExerciseType.squat,
    null,
  ];

  /// The app's own exercise names (user, 2026-11-14).
  static String nameOf(ExerciseType? exercise) => exercise?.koreanName ?? '둘 다';

  static const tapHeight = 44.0;
  static const chipHeight = 32.0;
  static const _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.archiveLabel
        .copyWith(color: AppColors.ink);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '종목',
      child: Wrap(
        // W7A's 6, on the 8 step.
        spacing: AppSpacing.s8,
        children: [
          for (final exercise in choices)
            _Chip(
              label: nameOf(exercise),
              picked: exercise == selected,
              style: style,
              onTap: () => onSelect(exercise),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.picked,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool picked;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: picked,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: FeedbackStatsExerciseChips.tapHeight,
          ),
          child: Center(
            widthFactor: 1,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: FeedbackStatsExerciseChips.chipHeight,
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              decoration: ShapeDecoration(
                color: picked ? AppColors.accent : AppColors.card,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: picked ? AppColors.ink : AppColors.border,
                    width: FeedbackStatsExerciseChips._edge,
                  ),
                ),
              ),
              // A row takes the chip's least height and centers the label.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(label, maxLines: 1, style: style)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
