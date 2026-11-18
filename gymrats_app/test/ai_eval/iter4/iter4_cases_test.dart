import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import 'iter4_cases.dart';

Map<String, dynamic> sample({
  String exercise = 'squat',
  String scenario = 'normal',
}) => {
  'format': 'gymrats-iter4-ai-eval',
  'version': 1,
  'id': 'sample',
  'participant': 'synthetic',
  'exercise': exercise,
  'scenario': scenario,
  'source': {'width': 720, 'height': 1280, 'frameCount': 2, 'sha256': '0' * 64},
  'landmarks': BodyLandmark.values.map((e) => e.name).toList(),
  'label': <String, dynamic>{
    'status': 'pending',
    'actualReps': null,
    'perRep': null,
    'confirmedBy': null,
  },
  'chairPolicy': scenario == 'chair' ? 'pending' : null,
  'evaluationWindowUs': null,
  'frames': <Map<String, dynamic>>[
    {'t': 0, 'p': null},
    {'t': 100000, 'p': null},
  ],
};

void main() {
  test(
    'dataset contains16 coordinate-only cases for the selected two people',
    () {
      final cases = loadIter4Cases();
      expect(cases, hasLength(16));
      expect(cases.map((c) => c.participant).toSet(), {'hyunwoo', 'sangwoo'});
      for (final person in ['hyunwoo', 'sangwoo']) {
        expect(
          cases.where((c) => c.participant == person && c.exercise == 'pushUp'),
          hasLength(4),
        );
        expect(
          cases.where((c) => c.participant == person && c.exercise == 'squat'),
          hasLength(4),
        );
        expect(
          File('$iter4CaseRoot/$person/record-sheet.md').existsSync(),
          isTrue,
        );
      }
      expect(
        Directory(iter4CaseRoot)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.mp4')),
        isEmpty,
      );
      final manifest = jsonDecode(
        File('$iter4CaseRoot/manifest.json').readAsStringSync(),
      );
      expect(manifest['containsVideo'], isFalse);
      expect(manifest['caseCount'], cases.length);
    },
  );

  test('pending cases expose no expected repetition labels', () {
    final c = Iter4Case.fromJson(sample());
    expect(c.expected, isNull);
    expect(c.frames.first.pose.keypoints, isEmpty);
    expect(replayIter4(c), isEmpty);
  });

  test('confirmed labels require a confirmer and exact actual count', () {
    final data = sample();
    data['label'] = <String, dynamic>{
      'status': 'confirmed',
      'actualReps': 2,
      'perRep': ['valid'],
      'confirmedBy': 'recorder',
    };
    expect(() => Iter4Case.fromJson(data), throwsFormatException);
    data['label']['actualReps'] = 1;
    data['label']['confirmedBy'] = null;
    expect(() => Iter4Case.fromJson(data), throwsFormatException);
    data['label']['confirmedBy'] = 'recorder';
    expect(Iter4Case.fromJson(data).expected, ['valid']);
  });

  test('chair squats use depth and full standing, not support rejection', () {
    final data = sample(scenario: 'chair');
    data['label'] = {
      'status': 'confirmed',
      'actualReps': 1,
      'perRep': ['valid'],
      'confirmedBy': 'PM',
    };
    expect(() => Iter4Case.fromJson(data), throwsFormatException);
    data['chairPolicy'] = 'range_only';
    expect(Iter4Case.fromJson(data).expected, ['valid']);
    data['label']['perRep'] = ['chairSupport'];
    expect(() => Iter4Case.fromJson(data), throwsFormatException);
  });

  test(
    'exercise-specific labels timestamps and coordinate shapes are validated',
    () {
      final unknown = sample()..['exercise'] = 'plank';
      expect(() => Iter4Case.fromJson(unknown), throwsFormatException);
      final badTime = sample();
      badTime['frames'][1]['t'] = 0;
      expect(() => Iter4Case.fromJson(badTime), throwsFormatException);
      final badPoint = sample();
      badPoint['frames'][0] = <String, dynamic>{
        't': 0,
        'p': [1, 2, 3],
      };
      expect(() => Iter4Case.fromJson(badPoint), throwsFormatException);
      final label = sample(exercise: 'pushUp');
      label['label'] = {
        'status': 'confirmed',
        'actualReps': 1,
        'perRep': ['shallowSquat'],
        'confirmedBy': 'recorder',
      };
      expect(() => Iter4Case.fromJson(label), throwsFormatException);
    },
  );

  test('manual scoring windows do not change input observations', () {
    final data = sample()..['evaluationWindowUs'] = [1000, 100000];
    final c = Iter4Case.fromJson(data);
    expect(c.frames.length, 2);
    expect(c.includes(Duration.zero), isFalse);
    expect(c.includes(const Duration(microseconds: 100000)), isTrue);
  });

  test('default follows the explicitly conservative build fallback', () {
    expect(
      RepJudge().useFrameKnee,
      const bool.fromEnvironment('PUSHUP_FRAME_KNEE', defaultValue: false),
    );
  });
}
