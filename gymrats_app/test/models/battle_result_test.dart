import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

BattleResult _result({int mine = 0, int invalid = 0, int theirs = 0}) =>
    BattleResult(
      matchup: _matchup,
      myReps: mine,
      myInvalidReps: invalid,
      opponentReps: theirs,
      endedAt: DateTime(2026, 10, 4, 14, 32),
    );

void main() {
  test('the record keeps the exercise, the opponent, and both scores', () {
    final record = _result(mine: 26, invalid: 3, theirs: 24).record;
    expect(record.exercise, ExerciseType.pushUp);
    expect(record.opponentName, 'RepBot');
    expect(record.myReps, 26);
    expect(record.opponentReps, 24);
  });

  test('outcome and margin come from the two scores', () {
    expect(_result(mine: 26, theirs: 24).outcome, MatchOutcome.win);
    expect(_result(mine: 26, theirs: 24).margin, 2);
    expect(_result(mine: 20, theirs: 23).outcome, MatchOutcome.lose);
    expect(_result(mine: 20, theirs: 23).margin, 3);
    expect(_result(mine: 22, theirs: 22).outcome, MatchOutcome.draw);
    expect(_result(mine: 22, theirs: 22).margin, 0);
  });

  test('accuracy is counted reps over judged reps', () {
    expect(_result(mine: 26, invalid: 3).accuracy, closeTo(26 / 29, 1e-9));
    expect(_result(mine: 5).accuracy, 1);
    expect(_result(invalid: 2).accuracy, 0);
    expect(_result().accuracy, isNull);
  });
}
