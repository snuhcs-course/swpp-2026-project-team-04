import 'package:flutter/material.dart';

import '../main.dart';
import '../models/battle_result.dart';
import '../models/game_score.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/result_report.dart';

/// The result report of a battle (BResult): how it ended, both scores, the
/// user's reps, and the cards its values allow.
///
/// It draws only the values [reportOf] gathers and its only behavior is
/// navigation. The battle was saved before this screen opened. The back
/// button, 홈으로 and system back go home; 다시 대결 replaces this screen
/// with a new search.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result});

  final BattleResult result;

  /// The one place the report takes its values from. For now they come from
  /// [BattleResult] alone, which has none for the personal best, the latest
  /// battles or the tip, so those cards stay hidden. When 박진영's result
  /// view model (J4) arrives, it gives these values and only this changes.
  static ResultReportData reportOf(BattleResult result) => ResultReportData(
    outcome: result.outcome,
    byKo: result.end == GameEnd.ko,
    exercise: result.matchup.exercise,
    opponent: result.matchup.opponent,
    played: result.roundLength,
    myScore: result.myDisplayScore,
    opponentScore: result.opponentDisplayScore,
    myValidReps: result.myReps,
    myInvalidReps: result.myInvalidReps,
    endedAt: result.endedAt,
    hasFeedback: result.form != null,
  );

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  /// Set once a leaving button is pressed, so a second tap does nothing.
  bool _leaving = false;

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
      arguments: widget.result.form,
    );
  }

  void _matchAgain() => _leaveOnce(() {
    Navigator.pushReplacementNamed(
      context,
      GymRatsApp.matchingRoute,
      arguments: widget.result.matchup.rematch,
    );
  });

  @override
  Widget build(BuildContext context) {
    return ResultReport(
      data: ResultScreen.reportOf(widget.result),
      onGoHome: _goHome,
      onRematch: _matchAgain,
      onOpenFeedback: _openFeedback,
    );
  }
}
