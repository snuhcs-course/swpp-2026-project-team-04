import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
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
}
