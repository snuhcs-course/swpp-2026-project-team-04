import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/hold_progress.dart';
import 'package:gymrats_app/models/hold_reading.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/hold_judge.dart';
import 'package:gymrats_app/services/pose/hold_pose_definition.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

const _knee = HoldFault(id: 'knee', cue: ('무릎', '떼요'), icon: HoldIcon.knee);
const _arm = HoldFault(id: 'arm', cue: ('팔', '펴요'), icon: HoldIcon.blank);
const _broken = HoldReading.broken(_knee);

Duration _ms(int ms) => Duration(milliseconds: ms);

/// Feeds [reading] every [step] from [from] (exclusive) to [to]
/// (inclusive), and returns the last progress.
HoldProgress _feed(
  HoldTimeline timeline,
  HoldReading reading, {
  required int from,
  required int to,
  int step = 10,
}) {
  var progress = timeline.progress;
  for (var t = from + step; t <= to; t += step) {
    progress = timeline.update(reading, _ms(t));
  }
  return progress;
}

/// A reader that answers from a script and keeps every call.
class _ScriptedReader implements HoldPoseReader {
  _ScriptedReader(this.answer);

  HoldReading Function(PoseFrame frame) answer;
  final calls = <({PoseFrame frame, Duration at, bool counting})>[];

  @override
  HoldReading read(
    PoseFrame frame, {
    required Duration at,
    bool counting = false,
  }) {
    calls.add((frame: frame, at: at, counting: counting));
    return answer(frame);
  }
}

/// A reader that also gives guide lines: its hip height counts its frames.
class _GuideReader extends _ScriptedReader implements HoldGuideReader {
  _GuideReader() : super((_) => HoldReading.ok);

  @override
  JudgeSnapshot get guide => JudgeSnapshot(
    phase: RepPhase.bottom,
    squatHipY: calls.length.toDouble(),
    squatKneeY: 10,
  );
}

HoldPoseDefinition _definition(_ScriptedReader reader, {bool entry = false}) =>
    HoldPoseDefinition(
      pose: HoldPose.chair,
      setupExercise: ExerciseType.squat,
      createReader: () => reader,
      entry: entry,
      checks: const ['a'],
      faults: const [_knee, _arm],
      silhouette: HoldSilhouette.sit,
      guide: HoldGuide.squatHeight,
    );

const _frame = PoseFrame.empty(imageWidth: 10, imageHeight: 10);

void main() {
  group('HoldTimeline: time', () {
    test('nothing runs before GO', () {
      final timeline = HoldTimeline(endsAt: const Duration(seconds: 30));
      expect(timeline.update(HoldReading.ok, _ms(500)).held, Duration.zero);
      expect(timeline.started, isFalse);
    });

    test('a held pose runs the time from GO, between frames', () {
      final timeline = HoldTimeline(endsAt: const Duration(seconds: 30))
        ..start(Duration.zero);
      expect(timeline.progress.state, HoldState.holding);
      _feed(timeline, HoldReading.ok, from: 0, to: 1000);
      // The first frame after GO sets the reading; the time runs from it.
      expect(timeline.progress.held, _ms(990));
    });

    test('held all along, the hold ends at the third star', () {
      final timeline = HoldTimeline(endsAt: const Duration(seconds: 15))
        ..start(Duration.zero);
      final progress = _feed(timeline, HoldReading.ok, from: 0, to: 16000);
      expect(progress.held, const Duration(seconds: 15));
      expect(progress.ended, isTrue);
      expect(progress.end, HoldEnd.held);
      expect(progress.warnings, isEmpty);
    });

    test('a clock that goes back is taken as standing still', () {
      final timeline = HoldTimeline(endsAt: const Duration(seconds: 30))
        ..start(_ms(100));
      timeline.update(HoldReading.ok, _ms(200));
      timeline.update(HoldReading.ok, _ms(150));
      expect(timeline.update(HoldReading.ok, _ms(300)).held, _ms(100));
    });
  });

  group('HoldTimeline: warnings', () {
    late HoldTimeline timeline;
    setUp(() {
      timeline = HoldTimeline(endsAt: const Duration(seconds: 30))
        ..start(Duration.zero);
      _feed(timeline, HoldReading.ok, from: 0, to: 1000);
    });

    test('broken for 0.49 s gives no warning', () {
      timeline.update(_broken, _ms(1010));
      final progress = timeline.update(_broken, _ms(1500));
      expect(progress.warnings, isEmpty);
      expect(progress.state, HoldState.holding);
    });

    test('broken for 0.5 s gives one warning and stops the time', () {
      timeline.update(_broken, _ms(1010));
      final progress = timeline.update(_broken, _ms(1510));
      expect(progress.warnings, [_knee]);
      expect(progress.state, HoldState.paused);
      expect(progress.paused, isTrue);
      expect(progress.fault, _knee);
    });

    test('the time does not run while broken or paused', () {
      final atBreak = timeline.update(_broken, _ms(1010)).held;
      _feed(timeline, _broken, from: 1010, to: 4000);
      final progress = _feed(timeline, HoldReading.ok, from: 4000, to: 4500);
      expect(progress.held, atBreak);
    });

    test('held for 0.59 s stays paused, for 0.6 s runs again', () {
      _feed(timeline, _broken, from: 1000, to: 1600);
      timeline.update(HoldReading.ok, _ms(2000));
      expect(
        timeline.update(HoldReading.ok, _ms(2590)).state,
        HoldState.paused,
      );
      final again = timeline.update(HoldReading.ok, _ms(2600));
      expect(again.state, HoldState.holding);
      expect(again.fault, isNull);
      final held = again.held;
      expect(timeline.update(HoldReading.ok, _ms(2700)).held, held + _ms(100));
    });

    test('a break that goes on while paused adds no warning', () {
      final progress = _feed(timeline, _broken, from: 1000, to: 9000);
      expect(progress.warnings, hasLength(1));
      expect(progress.state, HoldState.paused);
    });

    test('the second warning ends the hold', () {
      _feed(timeline, _broken, from: 1000, to: 1600);
      _feed(timeline, HoldReading.ok, from: 1600, to: 2300);
      expect(timeline.progress.state, HoldState.holding);
      final progress = _feed(
        timeline,
        const HoldReading.broken(_arm),
        from: 2300,
        to: 2900,
      );
      expect(progress.warnings, [_knee, _arm]);
      expect(progress.ended, isTrue);
      expect(progress.end, HoldEnd.warnings);
      // Nothing changes after the end.
      expect(timeline.update(HoldReading.ok, _ms(9000)).held, progress.held);
    });

    test('the warning names the fault read most in its run', () {
      timeline.update(const HoldReading.broken(_arm), _ms(1010));
      timeline.update(_broken, _ms(1100));
      timeline.update(_broken, _ms(1200));
      timeline.update(_broken, _ms(1300));
      timeline.update(_broken, _ms(1400));
      expect(
        timeline.update(const HoldReading.broken(_arm), _ms(1510)).warnings,
        [_knee],
      );
    });

    test('of a tie, the warning names the fault read last', () {
      timeline.update(_broken, _ms(1010));
      timeline.update(const HoldReading.broken(_arm), _ms(1200));
      timeline.update(_broken, _ms(1300));
      expect(
        timeline.update(const HoldReading.broken(_arm), _ms(1510)).warnings,
        [_arm],
      );
    });

    test('while paused the fault shown follows the latest one read', () {
      _feed(timeline, _broken, from: 1000, to: 1600);
      final progress = timeline.update(
        const HoldReading.broken(_arm),
        _ms(1700),
      );
      expect(progress.fault, _arm);
      expect(progress.warnings, [_knee]);
    });
  });

  group('HoldTimeline: unknown', () {
    late HoldTimeline timeline;
    setUp(() {
      timeline = HoldTimeline(endsAt: const Duration(seconds: 30))
        ..start(Duration.zero);
      _feed(timeline, HoldReading.ok, from: 0, to: 1000);
    });

    test('within 1 s an unknown pose keeps a held one: the time runs', () {
      final before = timeline.progress.held;
      final progress = _feed(
        timeline,
        HoldReading.unknown,
        from: 1000,
        to: 2000,
      );
      expect(progress.held, before + const Duration(seconds: 1));
      expect(progress.warnings, isEmpty);
    });

    test('within 1 s an unknown pose keeps a broken one: it counts on', () {
      timeline.update(_broken, _ms(1010));
      final progress = timeline.update(HoldReading.unknown, _ms(1510));
      expect(progress.warnings, [_knee]);
    });

    test('past 1 s it is off screen, warned 0.5 s later', () {
      timeline.update(HoldReading.unknown, _ms(1010));
      expect(
        timeline.update(HoldReading.unknown, _ms(2010)).state,
        HoldState.holding,
      );
      // Off screen from 2.01 s: no warning at 2.5 s, one at 2.51 s.
      expect(timeline.update(HoldReading.unknown, _ms(2500)).warnings, isEmpty);
      final progress = timeline.update(HoldReading.unknown, _ms(2510));
      expect(progress.warnings, [HoldFault.offScreen]);
      expect(progress.fault, HoldFault.offScreen);
    });

    test('an unknown pose right after GO starts no run', () {
      final fresh = HoldTimeline(endsAt: const Duration(seconds: 30))
        ..start(Duration.zero);
      final progress = _feed(fresh, HoldReading.unknown, from: 0, to: 900);
      expect(progress.held, Duration.zero);
      expect(progress.warnings, isEmpty);
    });
  });

  group('HoldTimeline: entry', () {
    test('a broken pose after GO keeps the time at 0, with no warning', () {
      final timeline = HoldTimeline(
        endsAt: const Duration(seconds: 20),
        entry: true,
      )..start(Duration.zero);
      expect(timeline.progress.state, HoldState.entering);
      final progress = _feed(timeline, _broken, from: 0, to: 5000);
      expect(progress.held, Duration.zero);
      expect(progress.warnings, isEmpty);
      expect(progress.state, HoldState.entering);
    });

    test('the time starts once the pose is held for 0.6 s', () {
      final timeline = HoldTimeline(
        endsAt: const Duration(seconds: 20),
        entry: true,
      )..start(Duration.zero);
      _feed(timeline, _broken, from: 0, to: 1000);
      timeline.update(HoldReading.ok, _ms(1010));
      expect(
        timeline.update(HoldReading.ok, _ms(1600)).state,
        HoldState.entering,
      );
      final started = timeline.update(HoldReading.ok, _ms(1610));
      expect(started.state, HoldState.holding);
      expect(started.held, Duration.zero);
      expect(timeline.update(HoldReading.ok, _ms(1710)).held, _ms(100));
    });
  });

  group('HoldJudge', () {
    test('frames of the 3·2·1 reach the reader, not the time or warnings', () {
      final reader = _ScriptedReader((_) => _broken);
      final judge = HoldJudge(
        definition: _definition(reader, entry: true),
        endsAt: const Duration(seconds: 20),
      );
      for (var t = 0; t <= 3000; t += 100) {
        judge.countdown(_frame, _ms(t));
      }
      expect(reader.calls, hasLength(31));
      expect(reader.calls.every((c) => c.counting), isTrue);
      expect(judge.started, isFalse);
      expect(judge.progress.warnings, isEmpty);
      expect(judge.progress.held, Duration.zero);
      // A frame before GO is not read as a held one either.
      expect(judge.frame(_frame, _ms(3100)).held, Duration.zero);
      expect(reader.calls, hasLength(31));
    });

    test('from GO each frame is read and timed; a missing one is unknown', () {
      final reader = _ScriptedReader((_) => HoldReading.ok);
      final judge = HoldJudge(
        definition: _definition(reader),
        endsAt: const Duration(seconds: 20),
      )..go(Duration.zero);
      judge.frame(_frame, _ms(100));
      judge.frame(_frame, _ms(200));
      expect(reader.calls.last.counting, isFalse);
      expect(judge.lastReading, HoldReading.ok);
      expect(judge.progress.held, _ms(100));
      // Frames stop: within 1 s the held reading stands.
      expect(judge.missing(_ms(700)).held, _ms(600));
      // The 3·2·1 is over: countdown frames are ignored now.
      judge.countdown(_frame, _ms(800));
      expect(reader.calls, hasLength(2));
    });

    test('nothing is read after the end', () {
      final reader = _ScriptedReader((_) => HoldReading.ok);
      final judge = HoldJudge(definition: _definition(reader), endsAt: _ms(300))
        ..go(Duration.zero);
      for (var t = 100; t <= 500; t += 100) {
        judge.frame(_frame, _ms(t));
      }
      expect(judge.progress.end, HoldEnd.held);
      final calls = reader.calls.length;
      judge.frame(_frame, _ms(600));
      judge.missing(_ms(700));
      expect(reader.calls, hasLength(calls));
    });

    test('a pose with an entry hands it to the time', () {
      final reader = _ScriptedReader((_) => HoldReading.ok);
      final judge = HoldJudge(
        definition: _definition(reader, entry: true),
        endsAt: const Duration(seconds: 20),
      )..go(Duration.zero);
      expect(judge.progress.state, HoldState.entering);
    });

    test('a reader without guide lines gives none', () {
      final judge = HoldJudge(
        definition: _definition(_ScriptedReader((_) => HoldReading.ok)),
        endsAt: const Duration(seconds: 20),
      );
      expect(judge.readsGuide, isFalse);
      expect(judge.guide, isNull);
    });

    test('a reader with guide lines gives its snapshot after each frame', () {
      final reader = _GuideReader();
      final judge = HoldJudge(
        definition: _definition(reader),
        endsAt: const Duration(seconds: 20),
      )..go(Duration.zero);
      expect(judge.readsGuide, isTrue);
      judge.frame(_frame, _ms(100));
      expect(judge.guide!.phase, RepPhase.bottom);
      expect(judge.guide!.squatHipY, 1);
      expect(judge.guide!.squatKneeY, 10);
      judge.frame(_frame, _ms(200));
      expect(judge.guide!.squatHipY, 2);
    });
  });

  group('HoldFault and HoldReading', () {
    test('faults are the same by id, and read as one line', () {
      expect(
        const HoldFault(id: 'knee', cue: ('x', 'y'), icon: HoldIcon.low),
        _knee,
      );
      expect(_knee.hashCode, 'knee'.hashCode);
      expect(_knee.words, '무릎 떼요');
      expect(HoldFault.offScreen.words, '화면 안으로');
      expect(HoldFault.offScreen.icon, HoldIcon.offScreen);
      expect(_knee.toString(), 'HoldFault(knee)');
    });

    test('readings compare by kind and fault', () {
      expect(const HoldReading.broken(_knee), _broken);
      expect(_broken == const HoldReading.broken(_arm), isFalse);
      expect(HoldReading.ok.fault, isNull);
      expect(_broken.hashCode, const HoldReading.broken(_knee).hashCode);
      expect(HoldReading.ok.toString(), 'HoldReading.ok');
      expect(HoldReading.unknown.toString(), 'HoldReading.unknown');
      expect(_broken.toString(), 'HoldReading.broken(knee)');
    });

    test('progress reads its warnings and state', () {
      const progress = HoldProgress(
        state: HoldState.paused,
        warnings: [_knee],
        fault: _knee,
      );
      expect(progress.warningCount, 1);
      expect(progress.paused, isTrue);
      expect(progress.ended, isFalse);
      expect(progress.toString(), contains('paused'));
    });
  });
}
