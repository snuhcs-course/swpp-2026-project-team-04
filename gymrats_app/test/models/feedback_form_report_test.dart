import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';

import '../support/form_report_fixtures.dart';

void main() {
  test('a report is a push-up unless told otherwise', () {
    expect(sampleReport().exercise, ExerciseType.pushUp);
  });

  test('a squat report keeps its exercise through JSON', () {
    final json = squatReport().toJson();
    expect(json['exercise'], 'squat');
    final read = FormReport.fromJson(json);
    expect(read.exercise, ExerciseType.squat);
    expect(read.validReps, 4);
    expect(read.invalidReps, 2);
  });

  test('a report saved before the exercise was kept reads as a push-up', () {
    final json = squatReport().toJson()..remove('exercise');
    expect(FormReport.fromJson(json).exercise, ExerciseType.pushUp);
  });

  test('an exercise this version does not know reads as a push-up', () {
    final json = squatReport().toJson()..['exercise'] = 'lunge';
    expect(FormReport.fromJson(json).exercise, ExerciseType.pushUp);
  });

  test('the account that played keeps through JSON; a report saved before '
      'it was kept, or with a value it does not know, has none (A10)', () {
    final json = sampleReport(accountId: 7).toJson();
    expect(json['accountId'], 7);
    expect(FormReport.fromJson(json).accountId, 7);
    expect(sampleReport().toJson().containsKey('accountId'), isFalse);
    expect(FormReport.fromJson(sampleReport().toJson()).accountId, isNull);
    expect(
      FormReport.fromJson(sampleReport().toJson()..['accountId'] = 'seven')
          .accountId,
      isNull,
    );
  });
}
