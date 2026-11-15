import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/feedback_stats_viewmodel.dart';
import '../widgets/feedback_stats_cards.dart';
import '../widgets/feedback_stats_filters.dart';
import '../widgets/lobby_parts.dart';

/// 기간별 통계 (W7-STATS, UAT-4 AC3), opened from 기록보관소's pill: the
/// average counted reps, a graph of reps by date and how often each form
/// issue came up, for every record, this month or this week, of push-ups,
/// squats or both. It draws only the view model's values; the battles load
/// once when it opens, and switching tabs does not load them again.
class FeedbackStatsScreen extends StatefulWidget {
  const FeedbackStatsScreen({
    super.key,
    required this.createViewModel,
    this.now,
  });

  /// Builds the view model, on the archive's statistics source.
  final FeedbackStatsViewModel Function() createViewModel;

  /// The view model's clock, for today's slot; the clock by default.
  final DateTime Function()? now;

  @override
  State<FeedbackStatsScreen> createState() => _FeedbackStatsScreenState();
}

class _FeedbackStatsScreenState extends State<FeedbackStatsScreen> {
  late final FeedbackStatsViewModel _viewModel;

  /// Where the faint "STATS" starts, as designed.
  static const _watermarkLeft = 132.0;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.createViewModel()..load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FeedbackStatsViewModel>.value(
      value: _viewModel,
      child: Consumer<FeedbackStatsViewModel>(
        builder: (context, vm, _) {
          final state = vm.state;
          final now = widget.now?.call() ?? DateTime.now();
          final stats = state.stats;
          return LobbyPage(
            behind: const LobbyWatermark('STATS', left: _watermarkLeft),
            children: [
              const LobbyPageHeader(
                tag: '03 / STATS',
                title: '기간별 통계',
                tagColor: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.s16),
              FeedbackStatsPeriodTabs(
                selected: state.period,
                onSelect: vm.selectPeriod,
              ),
              // W7A's 6 under the tabs and the chips' 44 high row, on the
              // 4 step.
              const SizedBox(height: AppSpacing.s4),
              FeedbackStatsExerciseChips(
                selected: state.exercise,
                onSelect: vm.selectExercise,
              ),
              const SizedBox(height: AppSpacing.s4),
              ...switch (state.phase) {
                FeedbackStatsPhase.loading => [
                  FeedbackStatsLoadingCards(period: state.period, now: now),
                ],
                FeedbackStatsPhase.failed => [
                  FeedbackStatsFailedCard(
                    message: state.errorMessage ?? '',
                    onRetry: vm.load,
                  ),
                ],
                FeedbackStatsPhase.ready when stats != null => [
                  FeedbackStatsSummaryCard(
                    period: state.period,
                    exercise: state.exercise,
                    stats: stats,
                    now: now,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  FeedbackStatsIssuesCard(
                    // A new period or exercise closes the open groups.
                    key: ValueKey((state.period, state.exercise)),
                    stats: stats,
                  ),
                ],
                FeedbackStatsPhase.ready => const <Widget>[],
              },
            ],
          );
        },
      ),
    );
  }
}
