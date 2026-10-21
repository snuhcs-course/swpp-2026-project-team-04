import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_summary.dart';
import 'package:gymrats_app/models/match_record.dart';

void main() {
  MatchRecord record(int myReps, int opponentReps) => MatchRecord(
    exercise: ExerciseType.pushUp,
    opponentName: 'RepBot',
    myReps: myReps,
    opponentReps: opponentReps,
  );

  test('more reps wins, fewer loses, the same count is a draw', () {
    expect(record(24, 19).outcome, MatchOutcome.win);
    expect(record(19, 24).outcome, MatchOutcome.lose);
    expect(record(20, 20).outcome, MatchOutcome.draw);
  });

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  test('a stored outcome wins over the reps, e.g. a forfeit', () {
    const forfeit = MatchRecord(
      exercise: ExerciseType.pushUp,
      opponentName: '진영',
      myReps: 20,
      opponentReps: 3,
      decidedOutcome: MatchOutcome.lose,
    );
    expect(forfeit.outcome, MatchOutcome.lose);
  });

  test('a battle has feedback only with a summary', () {
    expect(record(1, 2).hasFeedback, isFalse);
    expect(record(1, 2).id, isNull);
    const withFeedback = MatchRecord(
      id: 4,
      exercise: ExerciseType.pushUp,
      opponentName: 'RepBot',
      myReps: 1,
      opponentReps: 2,
      feedbackSummary: FeedbackSummary(
        validReps: 1,
        invalidReps: 0,
        issueCount: 0,
      ),
    );
    expect(withFeedback.hasFeedback, isTrue);
  });
}
