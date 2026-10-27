import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/rep_judge_demo.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../support/pose_fixtures.dart';
import '../../support/pushup_case_loader.dart';

/// Recorded cases today's judge gets wrong, by case id. Each stays here,
/// skipped with its reason, until the judge fix turns it back on.
const knownErrors = <String, String>{
  '20261026-000317_normal':
      'known error: the belly-down rep 5 (labelled from memory) has no torso '
      'sag and is rejected as kneesDown by a 2-frame hip fold at the top',
  '20261026-000418_normal':
      'known error: the base model reads the plank hip at 127-139°, so '
      'every normal rep latches kneesDown at the top',
  '20261026-000522_normal':
      'known error: normal rep 2 is rejected as kneesDown by a 2-frame hip '
      'dip at the top (141° against the 162° baseline); a 3-frame rule '
      'would also miss knee reps 2 and 3 of 20261026-000615_knees',
  '20261027-142000_halfRepHeadNod':
      'known error: half reps 3 and 4 dropped the shoulders 0.90 and 0.78, '
      'past the 0.70 line, and are rejected as kneesDown, not '
      'insufficientDepth',
  '20261027-142116_bellyDown':
      'known error: belly rep 1 never reached the bottom and is '
      'insufficientDepth, not bellyDown',
  '20261027-142432_normal':
      'known error: farther from the phone, normal rep 5 is '
      'insufficientDepth: the shoulders dropped 0.27 although the elbows '
      'reached 44°',
  '20261027-145535_knees':
      'known error: kneeling-bow rep 2 kept the elbows straight through '
      'the bottom and is armsStraight, not kneesDown',
  '20261027-222907_knees':
      'known error: wrong reason (knee rep 18 is insufficientDepth) and an '
      'extra rejected event (the rock back after rep 19)',
};

/// What today's judge closes, rep by rep, for each known error: `valid` or
/// the reason name. Pins the partial fixes inside the skipped cases, so a
/// regression there fails even while the labelled test stays skipped.
const knownVerdicts = <String, List<String>>{
  '20261026-000317_normal': ['valid', 'valid', 'valid', 'valid', 'kneesDown'],
  '20261026-000418_normal': [
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
  ],
  '20261026-000522_normal': [
    'valid',
    'kneesDown',
    'valid',
    'valid',
    'valid',
    'valid',
    'valid',
  ],
  '20261027-142000_halfRepHeadNod': [
    'insufficientDepth',
    'insufficientDepth',
    'kneesDown',
    'kneesDown',
    'insufficientDepth',
  ],
  '20261027-142116_bellyDown': [
    'insufficientDepth',
    'bellyDown',
    'bellyDown',
    'bellyDown',
    'bellyDown',
  ],
  '20261027-142432_normal': [
    'valid',
    'valid',
    'valid',
    'valid',
    'insufficientDepth',
  ],
  '20261027-145535_knees': [
    'kneesDown',
    'armsStraight',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
  ],
  '20261027-222907_knees': [
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'kneesDown',
    'insufficientDepth',
    'kneesDown',
    'insufficientDepth',
  ],
};

void main() {
  group('recorded push-up cases', () {
    final cases = loadPushUpCases();

    test('every case file reads, is named after its id, and is unique', () {
      final ids = <String>{};
      for (final c in cases) {
        expect(c.fileName, '${c.id}.json');
        expect(ids.add(c.id), isTrue, reason: 'duplicate id ${c.id}');
      }
      for (final MapEntry(key: id, value: reason) in knownErrors.entries) {
        expect(ids, contains(id), reason: 'known error for a missing case');
        expect(reason, startsWith('known error: '));
      }
      expect(knownVerdicts.keys.toSet(), knownErrors.keys.toSet());
    });

    test('every per-rep label agrees with the set totals', () {
      for (final c in cases) {
        final label = c.recording.label;
        final perRep = label.perRep;
        if (perRep == null) continue;
        expect(perRep, hasLength(label.reps), reason: c.fileName);
        final expected = label.expected;
        if (expected == null) continue;
        final totals = CaseResult([
          for (final (i, reason) in perRep.indexed)
            RepEvent(
              index: i + 1,
              valid: reason == null,
              reason: reason,
              at: Duration.zero,
            ),
        ]);
        expect(totals.valid, expected.valid, reason: c.fileName);
        expect(totals.rejected, expected.rejected, reason: c.fileName);
      }
    });

    for (final c in cases) {
      final label = c.recording.label;
      // A free set has no label to check; it is kept for analysis.
      if (label.expected == null && label.perRep == null) continue;
      test('${c.id} gives the labelled result', () {
        final result = replay(c.recording);
        expect(result.matches(label), isTrue, reason: describeCase(c, result));
      }, skip: knownErrors[c.id]);
      if (knownVerdicts[c.id] case final verdicts?) {
        test('${c.id} still replays as known, rep by rep', () {
          final result = replay(c.recording);
          expect([
            for (final e in result.events) e.reason?.name ?? 'valid',
          ], verdicts);
        });
      }
    }
  });

  group('case loader', () {
    RecordedFrame at(int ms, PoseFrame pose, {bool moved = false}) =>
        RecordedFrame(
          at: Duration(milliseconds: ms),
          pose: pose,
          phoneMoved: moved,
        );

    /// Extended arms long enough for the judge to start counting.
    List<RecordedFrame> top() => [at(0, pushUpFrame()), at(300, pushUpFrame())];

    List<RecordedFrame> rep(
      int start, {
      double bottom = 1.5,
      bool movedAtTop = false,
    }) => [
      at(start, pushUpFrame(depth: 0.6, elbowAngle: 160)),
      at(start + 400, pushUpFrame(depth: bottom, elbowAngle: 150)),
      at(start + 800, pushUpFrame(), moved: movedAtTop),
    ];

    PushUpRecording recording(
      List<RecordedFrame> frames, {
      CaseKind kind = CaseKind.normal,
      int reps = 1,
      RecordingLabel? label,
      List<RepEvent> live = const [],
      Map<String, Object?> judge = const {},
    }) => PushUpRecording(
      id: 'synthetic',
      recordedAt: DateTime(2026, 10, 25, 14, 3, 12),
      judge: judge,
      label: label ?? RecordingLabel.of(kind, reps),
      setup: const RecordingSetup(device: 'test'),
      frames: frames,
      liveEvents: live,
    );

    test('a replay counts a full rep and rejects a shallow one', () {
      final result = replay(
        recording([...top(), ...rep(400), ...rep(1600, bottom: 0.9)]),
      );
      expect(result.valid, 1);
      expect(result.rejected, {RejectReason.insufficientDepth: 1});
      expect(
        result.matches(
          const RecordingLabel(
            kind: CaseKind.normal,
            reps: 2,
            expected: CaseExpectation(
              valid: 1,
              rejected: {RejectReason.insufficientDepth: 1},
            ),
          ),
        ),
        isTrue,
      );
    });

    test('an abandon mark drops the attempt in progress', () {
      final frames = [
        ...top(),
        at(400, pushUpFrame(depth: 0.6, elbowAngle: 160)),
        RecordedFrame(
          at: const Duration(milliseconds: 500),
          mark: FrameMark.abandon,
        ),
        at(800, pushUpFrame(depth: 1.5, elbowAngle: 150)),
        at(1200, pushUpFrame()),
      ];
      expect(replay(recording(frames)).events, isEmpty);
      expect(replay(recording([...top(), ...rep(400)])).valid, 1);
    });

    test('a rep that closes while the phone moved is rejected for it', () {
      final result = replay(
        recording([...top(), ...rep(400, movedAtTop: true)]),
      );
      expect(result.valid, 0);
      expect(result.rejected, {RejectReason.phoneMoved: 1});
    });

    test('encode then decode keeps every value, rounded', () {
      final partial = PoseFrame(
        imageWidth: 480,
        imageHeight: 640,
        keypoints: {
          BodyLandmark.nose: const Keypoint(
            landmark: BodyLandmark.nose,
            x: 240.04,
            y: 101.26,
            z: -33.33,
            likelihood: 0.123456,
          ),
        },
      );
      final original = recording(
        [
          RecordedFrame(
            at: const Duration(microseconds: 1234567),
            pose: partial,
            phoneTilt: 72.346,
            gyro: 0.01234,
            phoneMoved: true,
            fps: 24,
          ),
          const RecordedFrame(
            at: Duration(milliseconds: 1300),
            pose: PoseFrame.empty(imageWidth: 480, imageHeight: 640),
          ),
          const RecordedFrame(
            at: Duration(milliseconds: 1400),
            mark: FrameMark.abandon,
          ),
        ],
        label: const RecordingLabel(
          kind: CaseKind.knees,
          reps: 3,
          expected: CaseExpectation(
            valid: 1,
            rejected: {RejectReason.kneesDown: 2},
          ),
          perRep: [RejectReason.kneesDown, null, RejectReason.kneesDown],
          note: 'one rep with the knees up',
        ),
        judge: describeJudge(const RepJudgeConfig()),
        live: [
          const RepEvent(
            index: 1,
            valid: false,
            reason: RejectReason.kneesDown,
            at: Duration(milliseconds: 900),
            maxDepth: 1.4,
            minElbowAngle: 140,
            maxTilt: 3,
            descent: Duration(milliseconds: 400),
          ),
        ],
      );

      final json = original.encode();
      final copy = PushUpRecording.decode(json);

      expect(copy.id, 'synthetic');
      expect(copy.recordedAt, DateTime(2026, 10, 25, 14, 3, 12));
      expect(copy.label.kind, CaseKind.knees);
      expect(copy.label.reps, 3);
      expect(copy.label.expected!.valid, 1);
      expect(copy.label.expected!.rejected, {RejectReason.kneesDown: 2});
      expect(copy.label.perRep, [
        RejectReason.kneesDown,
        null,
        RejectReason.kneesDown,
      ]);
      expect(copy.label.note, 'one rep with the knees up');
      final config = copy.judge['config']! as Map<String, Object?>;
      expect(config['bottomDepth'], 1.1);
      expect(config['topHoldMs'], 300);
      expect(config, hasLength(34));
      expect(copy.judge['commit'], isNull);
      expect(copy.setup.device, 'test');
      expect(copy.setup.model, PoseDetectionModel.accurate);
      expect(copy.setup.roundLength, const Duration(seconds: 30));
      expect(copy.frames, hasLength(3));

      final first = copy.frames[0];
      expect(first.at, const Duration(microseconds: 1234567));
      expect(first.phoneTilt, 72.35);
      expect(first.gyro, 0.012);
      expect(first.phoneMoved, isTrue);
      expect(first.fps, 24);
      expect(first.pose!.imageWidth, 480);
      expect(first.pose!.keypoints.keys, [BodyLandmark.nose]);
      final nose = first.pose![BodyLandmark.nose]!;
      expect(nose.x, 240.0);
      expect(nose.y, 101.3);
      expect(nose.z, -33.3);
      expect(nose.likelihood, 0.1235);

      expect(copy.frames[1].pose!.hasPerson, isFalse);
      expect(copy.frames[1].phoneTilt, isNull);
      expect(copy.frames[1].fps, isNull);
      expect(copy.frames[2].mark, FrameMark.abandon);
      expect(copy.frames[2].pose, isNull);

      final event = copy.liveEvents.single;
      expect(event.reason, RejectReason.kneesDown);
      expect(event.at, const Duration(milliseconds: 900));
      expect(event.maxDepth, 1.4);
      expect(event.descent, const Duration(milliseconds: 400));
      expect(liveResult(copy).rejected, {RejectReason.kneesDown: 1});

      // One frame per line keeps diffs of the fixtures readable.
      expect(
        RegExp(r'^    \{"t":', multiLine: true).allMatches(json),
        hasLength(3),
      );
    });

    test('setup frames keep their verdict through encode and decode', () {
      final original = PushUpRecording(
        id: 'synthetic',
        recordedAt: DateTime(2026, 10, 27),
        label: RecordingLabel.of(CaseKind.normal, 1),
        setup: const RecordingSetup(device: 'test'),
        frames: top(),
        liveEvents: const [],
        setupFrames: [
          SetupFrame(
            at: const Duration(milliseconds: 40),
            pose: pushUpFrame(),
            reason: SetupReason.missingParts,
            progress: 0.123,
            missing: const [BodyPart.hands, BodyPart.elbows],
            phoneTilt: 71.234,
            gyro: 0.0123,
            gravity: const [1.5, 9.6, 0.4],
            fps: 22,
          ),
          SetupFrame(
            at: const Duration(milliseconds: 1500),
            pose: pushUpFrame(),
            reason: SetupReason.ready,
            ready: true,
            progress: 1,
          ),
        ],
      );
      final json = original.encode();
      final copy = PushUpRecording.decode(json);

      final [missing, ready] = copy.setupFrames;
      expect(missing.at, const Duration(milliseconds: 40));
      expect(missing.reason, SetupReason.missingParts);
      expect(missing.ready, isFalse);
      expect(missing.progress, 0.12);
      expect(missing.missing, [BodyPart.hands, BodyPart.elbows]);
      expect(missing.phoneTilt, 71.23);
      expect(missing.gyro, 0.012);
      expect(missing.gravity, [1.5, 9.6, 0.4]);
      expect(missing.fps, 22);
      expect(missing.pose.keypoints.keys, pushUpFrame().keypoints.keys);
      expect(ready.reason, SetupReason.ready);
      expect(ready.ready, isTrue);
      expect(ready.missing, isEmpty);
      expect(ready.phoneTilt, isNull);
      expect(ready.gravity, isNull);
      expect(copy.frames, hasLength(2));
      // One setup frame per line, like the judged frames.
      expect(
        RegExp(r'^    \{"t":', multiLine: true).allMatches(json),
        hasLength(4),
      );
    });

    test('a recording made before setup was recorded has no setup frames', () {
      final json = recording(top()).encode();
      expect(json, contains('"setupFrames": []'));
      final old = json.replaceFirst('"setupFrames": [],', '');
      expect(old, isNot(contains('setupFrames')));
      expect(PushUpRecording.decode(old).setupFrames, isEmpty);
      expect(PushUpRecording.decode(old).frames, hasLength(2));
    });

    test('a full set survives the round trip with the same replay', () {
      final original = recording([...top(), ...rep(400), ...rep(1600)]);
      final copy = PushUpRecording.decode(original.encode());
      expect(replay(copy).valid, replay(original).valid);
      expect(replay(copy).valid, 2);
    });

    test('decode rejects another format or version', () {
      expect(
        () => PushUpRecording.decode('{"format":"other","version":1}'),
        throwsFormatException,
      );
      expect(
        () => PushUpRecording.decode(
          '{"format":"${PushUpRecording.format}","version":2}',
        ),
        throwsFormatException,
      );
    });

    test('cases load from json files in name order, skipping the rest', () {
      final dir = Directory.systemTemp.createTempSync('pushup_cases');
      addTearDown(() => dir.deleteSync(recursive: true));
      final a = recording(top());
      File('${dir.path}/b.json').writeAsStringSync(a.encode());
      File('${dir.path}/a.json').writeAsStringSync(a.encode());
      File('${dir.path}/README.md').writeAsStringSync('# notes');

      final cases = loadPushUpCases(dir.path);
      expect([for (final c in cases) c.fileName], ['a.json', 'b.json']);
      expect(cases.first.id, 'synthetic');
      expect(loadPushUpCases('${dir.path}/missing'), isEmpty);
    });

    test('a broken case file fails the load with its name', () {
      final dir = Directory.systemTemp.createTempSync('pushup_cases');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/broken.json').writeAsStringSync('{"format":');
      expect(
        () => loadPushUpCases(dir.path),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('broken.json'),
          ),
        ),
      );
    });

    RecordingLabel totals(CaseExpectation expected) =>
        RecordingLabel(kind: CaseKind.knees, reps: 2, expected: expected);

    test('error types name a false count, a missed rep, a wrong reason', () {
      final knees = totals(
        const CaseExpectation(valid: 0, rejected: {RejectReason.kneesDown: 2}),
      );
      RepEvent event(int i, {RejectReason? reason}) => RepEvent(
        index: i,
        valid: reason == null,
        reason: reason,
        at: Duration(seconds: i),
      );

      final counted = CaseResult([
        event(1),
        event(2, reason: RejectReason.kneesDown),
      ]);
      expect(counted.errorTypes(knees), ['false count']);
      expect(
        CaseResult([event(1)])
            .errorTypes(totals(const CaseExpectation(valid: 2))),
        ['missed rep'],
      );
      final wrongReason = CaseResult([
        event(1, reason: RejectReason.kneesDown),
        event(2, reason: RejectReason.insufficientDepth),
      ]);
      expect(wrongReason.errorTypes(knees), ['wrong reason']);
      expect(wrongReason.matches(knees), isFalse);
      expect(
        CaseResult([
          event(1, reason: RejectReason.kneesDown),
          event(2, reason: RejectReason.kneesDown),
        ]).errorTypes(knees),
        isEmpty,
      );
      expect(
        CaseResult([event(1)]).errorTypes(
          const RecordingLabel(
            kind: CaseKind.unlabelled,
            reps: 1,
            expected: null,
          ),
        ),
        isEmpty,
      );
    });

    test('per-rep labels catch a false count and a missed rep that cancel', () {
      RepEvent event(int i, {RejectReason? reason}) => RepEvent(
        index: i,
        valid: reason == null,
        reason: reason,
        at: Duration(seconds: i),
      );
      const knee = RejectReason.kneesDown;
      RecordingLabel mixed({required bool perRep}) => RecordingLabel(
        kind: CaseKind.knees,
        reps: 2,
        expected: const CaseExpectation(valid: 1, rejected: {knee: 1}),
        perRep: perRep ? const [null, knee] : null,
      );
      // The knee rep counted, the good rep rejected: same totals.
      final swapped = CaseResult([event(1, reason: knee), event(2)]);
      expect(swapped.matches(mixed(perRep: false)), isTrue);
      expect(swapped.errorTypes(mixed(perRep: true)), [
        'false count',
        'missed rep',
      ]);
      expect(
        CaseResult([event(1), event(2, reason: knee)])
            .matches(mixed(perRep: true)),
        isTrue,
      );
      // A labelled rejection the judge never closed, and an extra one.
      expect(CaseResult([event(1)]).errorTypes(mixed(perRep: true)), [
        'wrong reason',
      ]);
      expect(
        CaseResult([
          event(1),
          event(2, reason: knee),
          event(3, reason: RejectReason.insufficientDepth),
        ]).errorTypes(mixed(perRep: true)),
        ['wrong reason'],
      );
      // An extra counted rep, and a good rep never closed.
      expect(
        CaseResult([event(1), event(2, reason: knee), event(3)])
            .errorTypes(mixed(perRep: true)),
        ['false count'],
      );
      expect(CaseResult(const []).errorTypes(mixed(perRep: true)), [
        'missed rep',
        'wrong reason',
      ]);
    });

    test('one rep the judge never closed does not shift the later reps', () {
      const knee = RejectReason.kneesDown;
      const label = RecordingLabel(
        kind: CaseKind.unlabelled,
        reps: 4,
        expected: null,
        perRep: [null, null, knee, null],
      );
      final dropped = CaseResult([
        for (final (i, reason) in const [null, knee, null].indexed)
          RepEvent(
            index: i + 1,
            valid: reason == null,
            reason: reason,
            at: Duration(seconds: i),
          ),
      ]);
      expect(dropped.errorTypes(label), ['missed rep']);
    });

    test('a case line names the setup, expected, replay, and live result', () {
      final c = PushUpCase(
        fileName: 'synthetic.json',
        recording: recording([...top(), ...rep(400, bottom: 0.9)]),
      );
      final line = describeCase(c, replay(c.recording));
      expect(line, contains('synthetic.json: Normal push-ups x1'));
      expect(line, contains('expected 1 valid'));
      expect(line, contains('replay 1 × Go lower'));
      expect(line, contains('live 0 valid'));
      expect(line, contains('missed rep'));
    });

    test(
      'an unlabelled set expects nothing; a cheat set expects its reason',
      () {
        expect(CaseExpectation.of(CaseKind.unlabelled, 5), isNull);
        expect(CaseExpectation.of(CaseKind.normal, 5)!.valid, 5);
        for (final kind in CaseKind.values) {
          final reason = kind.reason;
          if (reason == null) continue;
          final expected = CaseExpectation.of(kind, 4)!;
          expect(expected.valid, 0);
          expect(expected.rejected, {reason: 4});
        }
        expect(
          const CaseExpectation(
            valid: 0,
            rejected: {RejectReason.kneesDown: 3},
          ).toString(),
          '3 × Knees up',
        );
      },
    );
  });
}
