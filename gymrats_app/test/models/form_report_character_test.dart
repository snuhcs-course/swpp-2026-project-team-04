import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';

/// A short squat battle's report, played as [characterId].
FormReport _report({String? characterId}) => FormReport(
  endedAt: DateTime(2026, 11, 18, 15),
  opponentName: 'RepBot',
  roundLength: const Duration(seconds: 30),
  exercise: ExerciseType.squat,
  reps: const [RepRecord(index: 1, valid: true, at: Duration(seconds: 2))],
  samples: const [],
  characterId: characterId,
);

void main() {
  group('FormReport.characterId (A11, the record\'s character)', () {
    test('a report played as a character keeps it through its JSON', () {
      final json = _report(characterId: 'bear').toJson();
      expect(json['characterId'], 'bear');
      expect(FormReport.fromJson(json).characterId, 'bear');
    });

    test('without one the JSON has no such key, as before', () {
      final json = _report().toJson();
      expect(json.containsKey('characterId'), isFalse);
      expect(FormReport.fromJson(json).characterId, isNull);
    });

    test('a report saved before it was kept still loads, without one', () {
      // As a report of 2026-11-17 was written: no such key at all.
      final old = <String, Object?>{
        'version': 1,
        'endedAt': DateTime(2026, 11, 17, 14).millisecondsSinceEpoch,
        'opponentName': 'RepBot',
        'exercise': 'squat',
        'roundMs': 30000,
        'reps': [
          {'index': 1, 'valid': true, 'ms': 2000},
        ],
        'samples': <Object?>[],
        'poses': <Object?>[],
        'leftFlarePose': null,
        'rightFlarePose': null,
        'handsPose': null,
        'headPose': null,
      };
      final read = FormReport.fromJson(old);
      expect(read.characterId, isNull);
      expect(read.exercise, ExerciseType.squat);
      expect(read.validReps, 1);
    });

    test('a value of another kind reads as none', () {
      final odd = _report().toJson()..['characterId'] = 7;
      expect(FormReport.fromJson(odd).characterId, isNull);
    });
  });
}
