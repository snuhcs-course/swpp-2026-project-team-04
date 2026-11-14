import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_result.dart';
import '../models/exercise_type.dart';
import '../models/feedback_stats.dart';
import '../models/game_score.dart';
import '../models/matchup.dart';
import '../services/feedback/feedback_stats.dart';
import '../services/user/user_repository.dart';
import '../viewmodels/result_viewmodel.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/result_cards.dart';
import '../widgets/result_report.dart';

/// The result report of a battle (BResult): how it ended, both scores, the
/// user's reps, and the cards its values allow.
///
/// It draws only the values [reportOf] takes from 박진영's result view model
/// (J4) and its only behavior is navigation. The battle was saved before
/// this screen opened. The back button, 홈으로 and system back go home;
/// 다시 대결 replaces this screen with a new search.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result, this.createViewModel});

  final BattleResult result;

  /// Builds the report's view model, for tests. Null builds
  /// [ResultViewModel.battle] of [result] on [historyOf].
  final ResultViewModel Function()? createViewModel;

  /// Where the earlier battles come from: the app's [UserRepository] when it
  /// can give them (the server one can). Otherwise none, and the comparison
  /// is left out as after a failed load.
  static FeedbackStatsSource historyOf(BuildContext context) {
    final repository = Provider.of<UserRepository?>(context, listen: false);
    if (repository case final FeedbackStatsSource source) return source;
    return const _NoHistory();
  }

  /// The one place the report takes its values from: [state] as J4's view
  /// model gives it, as the report's cards take them. A card whose values
  /// are missing is left out; [scored] false (a battle without a game score,
  /// from a server without the game) leaves out the latest battles and the
  /// placeholder too, as their last bar would not be this battle.
  static ResultReportData reportOf(ResultState state, {bool scored = true}) {
    final ready = state.history == ResultHistoryPhase.ready;
    final previous = state.previousBest;
    final average = state.recentAverage;
    final from = state.recentFrom;
    final tip = state.nextTip;
    return ResultReportData(
      outcome: state.outcome,
      byKo: state.end == GameEnd.ko,
      exercise: state.exercise,
      // A past battle keeps only the name.
      opponent:
          state.opponent ?? Opponent(name: state.opponentName, isBot: false),
      // A battle a player left carries the whole round, not when they left.
      played: state.departure == BattleDeparture.none
          ? state.roundLength
          : null,
      myScore: state.myScore,
      opponentScore: state.opponentScore,
      myValidReps: state.myReps,
      myInvalidReps: state.myInvalidReps,
      opponentValidReps: state.opponentReps,
      endedAt: state.endedAt,
      departure: state.departure,
      hasFeedback: state.form != null,
      // Without a score of its own nothing will replace the placeholder.
      comparisonLoading: scored && state.history == ResultHistoryPhase.loading,
      // The first battle has no earlier best, so it is never a new one.
      best: ready && state.isNewBest && previous != null
          ? ResultNewBest(
              previous: previous,
              current: state.myScore,
              gain: state.myScore - previous,
            )
          : null,
      // Without an earlier battle there is no average to compare with.
      recent:
          ready &&
              scored &&
              average != null &&
              from != null &&
              state.recentScores.isNotEmpty
          ? ResultRecent(
              scores: state.recentScores,
              firstPlayedAt: from,
              average: average,
              averageCount: state.recentAverageOf,
              difference: state.myScore - average,
            )
          : null,
      tip: tip == null
          ? null
          : ResultTip(title: tip.headline, reason: tip.detail),
    );
  }

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final ResultViewModel _viewModel;

  /// Set once a leaving button is pressed, so a second tap does nothing.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        ResultViewModel.battle(
          widget.result,
          history: ResultScreen.historyOf(context),
        );
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// The leaving buttons go through here, so only the first one pressed
  /// acts: after 홈으로, 다시 대결 does nothing either.
  void _leaveOnce(VoidCallback navigate) {
    if (_leaving) return;
    _leaving = true;
    navigate();
  }

  void _goHome() => _leaveOnce(() => popToHome(context));

  /// Opens on top, so back comes here again. Not one of the leaving buttons.
  void _openFeedback() {
    if (_leaving) return;
    Navigator.pushNamed(
      context,
      GymRatsApp.feedbackRoute,
      arguments: _viewModel.state.form,
    );
  }

  /// The same battle again: a bot of the same level, or, after an online
  /// battle, the online lobby with the same exercise.
  void _matchAgain() => _leaveOnce(() {
    final state = _viewModel.state;
    final rematch = state.rematch;
    if (rematch != null) {
      Navigator.pushReplacementNamed(
        context,
        GymRatsApp.matchingRoute,
        arguments: rematch,
      );
    } else {
      Navigator.pushReplacementNamed(
        context,
        GymRatsApp.onlineBattleRoute,
        arguments: state.exercise,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ResultViewModel>.value(
      value: _viewModel,
      child: Consumer<ResultViewModel>(
        builder: (context, viewModel, _) => ResultReport(
          data: ResultScreen.reportOf(
            viewModel.state,
            scored: widget.result.hasGame,
          ),
          onGoHome: _goHome,
          onRematch: _matchAgain,
          onOpenFeedback: _openFeedback,
        ),
      ),
    );
  }
}

/// No earlier battles to give: every fetch fails.
class _NoHistory implements FeedbackStatsSource {
  const _NoHistory();

  @override
  Future<List<StatsPoint>> fetchStatsPoints({
    ExerciseType? exercise,
    DateTime? since,
  }) async => throw Exception('this repository keeps no battle list');
}
