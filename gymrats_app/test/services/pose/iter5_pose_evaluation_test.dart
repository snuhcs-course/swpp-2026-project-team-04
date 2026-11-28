import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/rep_judge_demo.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/game/battle_game.dart';
import 'package:gymrats_app/services/pose/exercise_judge.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../../ai_eval/eval_cases.dart';
import '../../ai_eval/iter4/iter4_cases.dart';
import '../../ai_eval/iter4/iter4_scorer.dart';

typedef Replay = ({double passDepth, List<RepEvent> events});

Replay replayLandmarks(Iter4Case recording) {
  var now = Duration.zero;
  final exercise = ExerciseType.values.byName(recording.exercise);
  final judge = judgeFor(exercise, clock: () => now);
  final events = <RepEvent>[];
  for (final frame in recording.frames) {
    now = frame.at;
    final event = judge.update(frame.pose).event;
    if (event != null && recording.includes(event.at)) events.add(event);
  }
  return (passDepth: judge.passDepth, events: events);
}

Replay replayWithRecordedTilt(LoadedEvalCase recording) {
  var now = Duration.zero;
  final judge = RepJudge.forBattle(clock: () => now);
  final events = <RepEvent>[];
  for (final frame in recording.recording.frames) {
    if (frame.mark == FrameMark.abandon) {
      judge.abandon();
      continue;
    }
    final pose = frame.pose;
    if (pose == null) continue;
    now = frame.at;
    final tilt = frame.phoneMoved ? null : frame.phoneTilt;
    final event = judge.updateWithPhoneTilt(pose, tilt).event;
    if (event != null) {
      events.add(rejectIfPhoneMoved(event, phoneMoved: frame.phoneMoved));
    }
  }
  return (passDepth: judge.config.bottomDepth, events: events);
}

Map<String, Object?> evaluate(
  String id,
  String group,
  String scenario,
  List<String> expected,
  Replay replay,
  Iter4Tally tally,
) {
  final actual = <String>[];
  final details = <Map<String, Object?>>[];
  var points = 0;
  var counted = 0;
  final round = BattleGame(passDepth: replay.passDepth);
  for (final e in replay.events) {
    if (e.at < battleDuration) round.addMyRep(e);
    // Each event is the first rep of a fresh round. The labels have no round
    // clock, combo history, or opponent with which to reconstruct a KO.
    final game = BattleGame(passDepth: replay.passDepth);
    expect(e.valid, e.reason == null, reason: id);
    final score = game.addMyRep(
      RepEvent(
        index: 1,
        at: Duration.zero,
        valid: e.valid,
        reason: e.reason,
        maxDepth: e.maxDepth,
        minElbowAngle: e.minElbowAngle,
      ),
    );
    final label = e.reason?.name ?? 'valid';
    actual.add(label);
    counted += game.me.validReps;
    points += game.me.points;
    details.add({
      'atUs': e.at.inMicroseconds,
      'label': label,
      'grade': score?.grade.name,
      'points': game.me.points,
    });
  }
  tally.add(expected, actual);
  final valid = expected.where((e) => e == 'valid').length;
  final shallow = expected.where((e) => e == 'insufficientDepth').length;
  expect(counted, actual.where((e) => e == 'valid').length, reason: id);
  return {
    'id': id,
    'group': group,
    'scenario': scenario,
    'expected': expected,
    'expectedCount': valid,
    'counted': counted,
    'expectedMin': 10 * valid,
    'expectedMax': 15 * valid + 5 * shallow,
    'points': points,
    'soloRoundPoints': round.me.points,
    'soloRoundCount': round.me.validReps,
    'actual': details,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('battle points, counted reps and grades at the scoring boundaries', () {
    for (final exercise in ExerciseType.values) {
      final passDepth = judgeFor(exercise).passDepth;
      final game = BattleGame(passDepth: passDepth);
      var index = 0;
      void check(
        int ms,
        double? depth,
        double? elbow,
        RejectReason? reason,
        String? grade,
        int delta,
        int count,
      ) {
        final before = game.me.points;
        final score = game.addMyRep(
          RepEvent(
            index: ++index,
            at: Duration(milliseconds: ms),
            valid: reason == null,
            reason: reason,
            maxDepth: depth,
            minElbowAngle: elbow,
          ),
        );
        expect(score?.grade.name, grade);
        expect(game.me.points - before, delta);
        expect(game.me.validReps, count);
      }

      check(0, passDepth, null, null, 'good', 10, 1);
      check(1500, 1.6 * passDepth, null, null, 'excellent', 20, 2);
      if (exercise == ExerciseType.pushUp) {
        check(2000, null, 120, RejectReason.insufficientDepth, 'average', 5, 2);
        check(2200, null, 121, RejectReason.insufficientDepth, null, 0, 2);
        check(2400, null, null, RejectReason.insufficientDepth, null, 0, 2);
        check(2500, null, 90, RejectReason.kneesDown, 'average', 0, 2);
        check(
          20000,
          null,
          119,
          RejectReason.insufficientDepth,
          'average',
          10,
          2,
        );
        check(20500, null, 90, RejectReason.kneesDown, 'average', 0, 2);
      } else {
        check(2000, null, null, RejectReason.shallowSquat, null, 0, 2);
        check(2100, null, null, RejectReason.standUpFully, null, 0, 2);
      }
      check(21000, passDepth, null, null, 'good', 20, 3);
    }
  });

  test(
    'replay confirmed human labels through the battle judges and scorer',
    () {
      final recordings = loadIter4Cases();
      final frozen = loadEvalCases();
      expect(recordings.where((c) => c.exercise == 'pushUp'), hasLength(8));
      expect(recordings.where((c) => c.exercise == 'squat'), hasLength(8));
      expect(frozen, hasLength(32));
      final tallies = <String, Iter4Tally>{};
      final rows = <Map<String, Object?>>[];
      for (final c in recordings) {
        expect(c.labelled, isTrue, reason: c.id);
        final replay = replayLandmarks(c);
        // Both knee recordings have explicit human reasons. A silent judge
        // should not pass just because it also awards zero points.
        if (c.exercise == 'pushUp' && c.scenario == 'kneesDown') {
          expect(
            replay.events.map((e) => e.reason?.name),
            c.expected,
            reason: c.id,
          );
        }
        final group = 'nov18-${c.exercise}';
        rows.add(
          evaluate(
            c.id,
            group,
            c.scenario,
            c.expected!,
            replay,
            tallies.putIfAbsent(group, Iter4Tally.new),
          ),
        );
      }
      for (final c in frozen) {
        const group = 'frozen-pushUp';
        rows.add(
          evaluate(
            c.id,
            group,
            c.set.name,
            [for (final label in c.labelled) label?.name ?? 'valid'],
            replayWithRecordedTilt(c),
            tallies.putIfAbsent(group, Iter4Tally.new),
          ),
        );
      }
      if (const bool.fromEnvironment('P18_REPORT')) {
        final output = File('build/p18/evaluation.json');
        output.parent.createSync(recursive: true);
        output.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'summaries': tallies.map(
              (name, tally) => MapEntry(name, tally.toJson()),
            ),
            'cases': rows,
          }),
        );
      }
    },
  );
}
