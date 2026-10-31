import 'exercise_type.dart';
import 'feedback_summary.dart';
import 'game_score.dart';

/// How a battle ended for the user.
enum MatchOutcome {
  win('승'),
  lose('패'),
  draw('무');

  const MatchOutcome(this.label);

  /// Short label for the result badge.
  final String label;
}

/// A finished battle, seen from the user's side.
class MatchRecord {
  const MatchRecord({
    required this.exercise,
    required this.opponentName,
    required this.myReps,
    required this.opponentReps,
    this.playedAt,
    this.id,
    this.decidedOutcome,
    this.gameEnd,
    this.feedbackSummary,
  });

  final ExerciseType exercise;

  /// e.g. "RepBot".
  final String opponentName;

  /// Reps counted for the user.
  final int myReps;

  /// Reps counted for the opponent.
  final int opponentReps;

  /// When the battle ended; null for sample data that has no time.
  final DateTime? playedAt;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// The server's id for this battle, used to load its feedback; null for a
  /// battle not stored yet.
  final int? id;

  /// The outcome the server stored. An online forfeit or disconnect is a
  /// loss whatever the reps, so it wins over [myReps] and [opponentReps].
  final MatchOutcome? decidedOutcome;

  /// How a battle just played stopped, for its upload; null otherwise.
  final GameEnd? gameEnd;

  /// The battle's one-line form feedback; null when none was stored, e.g.
  /// for a battle saved before feedback was kept.
  final FeedbackSummary? feedbackSummary;

  bool get hasFeedback => feedbackSummary != null;

  /// The stored outcome; otherwise more reps wins and the same count is a
  /// draw.
  MatchOutcome get outcome =>
      decidedOutcome ??
      switch (myReps.compareTo(opponentReps)) {
        > 0 => MatchOutcome.win,
        < 0 => MatchOutcome.lose,
        _ => MatchOutcome.draw,
      };
}
