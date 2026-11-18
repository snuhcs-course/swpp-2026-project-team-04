import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_goal.dart';

final _goal = FeedbackGoal(
  exercise: ExerciseType.squat,
  kind: GoalKind.lateReps,
  target: 8,
  baseline: 6,
  title: '후반 15초에 8회 이상',
  setAt: DateTime(2026, 11, 17, 14, 31),
  characterId: 'seal',
  fromMatch: '1795412345678',
);

void main() {
  test('every value of spec 5.2 goes to JSON and back', () {
    final json = _goal.toJson();
    expect(json, {
      'exercise': 'squat',
      'kind': 'lateReps',
      'target': 8,
      'baseline': 6,
      'title': '후반 15초에 8회 이상',
      'setAt': DateTime(2026, 11, 17, 14, 31).millisecondsSinceEpoch,
      'characterId': 'seal',
      'fromMatch': '1795412345678',
    });
    expect(FeedbackGoal.fromJson(json), _goal);
  });

  test('a missing value, one of another kind or an unknown name is a '
      'FormatException', () {
    final json = _goal.toJson();
    for (final broken in [
      {...json}..remove('target'),
      {...json, 'target': '8'},
      {...json, 'kind': 'pushUpsInARow'},
      {...json, 'exercise': 'burpee'},
      {...json, 'characterId': null},
    ]) {
      expect(
        () => FeedbackGoal.fromJson(broken),
        throwsFormatException,
        reason: '$broken',
      );
    }
  });

  test('equal by value; printed by exercise, kind and target', () {
    final same = FeedbackGoal.fromJson(_goal.toJson());
    expect(same, _goal);
    expect(same.hashCode, _goal.hashCode);
    final other = FeedbackGoal.fromJson({..._goal.toJson(), 'target': 9});
    expect(other, isNot(_goal));
    expect(_goal.toString(), 'FeedbackGoal(squat, lateReps 8)');
  });
}
