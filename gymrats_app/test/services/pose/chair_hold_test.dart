import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/hold_progress.dart';
import 'package:gymrats_app/models/hold_reading.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/chair_hold.dart';
import 'package:gymrats_app/services/pose/hold_judge.dart';
import 'package:gymrats_app/services/pose/hold_pose_definition.dart';
import 'package:gymrats_app/services/pose/hold_poses.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/squat_rep_judge.dart';

import '../../support/pose_fixtures.dart';

/// The standing legs of the fixtures: the knees 180 px under the hips, the
/// ankles 170 px under the knees.
const _standingThigh = 180.0;
const _shin = 170.0;

/// A front view of a user with the knees at y 700: the hips [thigh] px
/// above them, the ankles [_shin] px under them, the knees [kneeGap] px
/// apart across the picture and the ankles [ankleGap] px.
PoseFrame _legs({
  double thigh = _standingThigh,
  double kneeGap = 100,
  double ankleGap = 100,
  Set<BodyLandmark> hide = const {},
}) {
  const kneeY = 700.0;
  final hipY = kneeY - thigh;
  const ankleY = kneeY + _shin;
  return standingFrame(
    showHips: true,
    hide: hide,
    move: {
      BodyLandmark.leftHip: (530, hipY),
      BodyLandmark.rightHip: (470, hipY),
      BodyLandmark.leftKnee: (500 + kneeGap / 2, kneeY),
      BodyLandmark.rightKnee: (500 - kneeGap / 2, kneeY),
      BodyLandmark.leftAnkle: (500 + ankleGap / 2, ankleY),
      BodyLandmark.rightAnkle: (500 - ankleGap / 2, ankleY),
    },
  );
}

/// Seated at [depth]: the thigh that much shorter than standing.
PoseFrame _seated(
  double depth, {
  double kneeGap = 100,
  double ankleGap = 100,
  Set<BodyLandmark> hide = const {},
}) => _legs(
  thigh: _standingThigh * (1 - depth),
  kneeGap: kneeGap,
  ankleGap: ankleGap,
  hide: hide,
);

Duration _ms(int ms) => Duration(milliseconds: ms);

/// Reads [frame] every 100 ms after [from] ms up to [to] ms, and returns
/// the last reading.
HoldReading _feed(
  ChairHoldReader reader,
  PoseFrame frame, {
  required int from,
  required int to,
  bool counting = false,
}) {
  var reading = HoldReading.unknown;
  for (var t = from + 100; t <= to; t += 100) {
    reading = reader.read(frame, at: _ms(t), counting: counting);
  }
  return reading;
}

/// A reader that took the standing thigh in a 3·2·1 of 1 s (frames at 0 to
/// 1000 ms).
ChairHoldReader _afterCountdown() {
  final reader = ChairHoldReader();
  _feed(reader, _legs(), from: -100, to: 1000, counting: true);
  expect(reader.standingThigh, _standingThigh);
  return reader;
}

void main() {
  // The reader prints its numbers in debug builds, for the phone check:
  // kept here instead of in the test output.
  final printed = <String>[];
  setUp(() {
    printed.clear();
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
  });
  tearDown(() => debugPrint = debugPrintThrottled);

  group('the chair pose bundle', () {
    test('is set up as a squat, entered after GO, with its own words', () {
      final chair = HoldPoses.of(HoldPose.chair);
      expect(chair, same(chairHold));
      expect(chair.pose, HoldPose.chair);
      expect(chair.setupExercise, ExerciseType.squat);
      expect(chair.entry, isTrue);
      expect(chair.checks, ['엉덩이 높이', '무릎 안 모으기']);
      expect(chair.silhouette, HoldSilhouette.sit);
      expect(chair.guide, HoldGuide.squatHeight);
      // The owner's start bubble, two lines, until the time starts.
      expect(chair.startWords, ['스쿼트 자세로', '버텨!']);
      expect(chair.createReader(), isA<ChairHoldReader>());
      expect(chair.createReader(), isA<HoldGuideReader>());
      expect(chair.faults, [ChairFaults.low, ChairFaults.kneesIn]);
      expect(chair.faults.map((f) => f.cue), [('더', '앉아요'), ('무릎', '벌려요')]);
      expect(chair.faults.map((f) => f.icon), [HoldIcon.low, HoldIcon.spread]);
      expect(ChairFaults.low.words, '더 앉아요');
      expect(ChairFaults.kneesIn.words, '무릎 벌려요');
    });

    test('opens on the four chair stages, the fifth of each floor', () {
      final chairs = ArcadeCatalog.stages
          .whereType<ArcadeHoldStage>()
          .where((s) => s.pose == HoldPose.chair)
          .map((s) => s.number);
      expect(chairs, [5, 11, 17, 23]);
      for (final number in chairs) {
        final stage = ArcadeCatalog.stage(number) as ArcadeHoldStage;
        expect(HoldPoses.of(stage.pose), same(chairHold));
      }
    });

    test('its numbers are the squat judge\'s, and one new knee line', () {
      final reader = ChairHoldReader();
      expect(reader.squat.passDepth, .75);
      expect(reader.squat.minLikelihood, .6);
      expect(reader.squat.smoothingTau, _ms(65));
      expect(reader.squat.baselineTau, _ms(500));
      expect(ChairLines.standingThigh, .7);
      expect(ChairLines.standingFor, _ms(300));
      expect(ChairLines.followUnder, .25);
      expect(ChairLines.followAgainAt, .15);
      expect(ChairLines.kneeGap, .8);
    });
  });

  group('the depth, as the squat judge reads it', () {
    /// Standing for 1 s, down over 1.5 s to 0.9, then seated: a frame
    /// every 33 ms, as a phone gives them.
    PoseFrame frameAt(int ms) {
      if (ms <= 1000) return _legs();
      final share = ((ms - 1000) / 1500).clamp(0.0, 1.0);
      return _seated(.9 * share);
    }

    // Read as the 3·2·1 reads them, where the standing thigh follows as the
    // squat judge's does. After GO it does not (the next tests).
    test('the same frames give the squat judge\'s depth, within 12 s', () {
      var now = Duration.zero;
      final squat = SquatRepJudge(clock: () => now);
      final reader = ChairHoldReader();
      var compared = 0;
      for (var ms = 0; ms <= 12000; ms += 33) {
        now = _ms(ms);
        final frame = frameAt(ms);
        final snapshot = squat.update(frame).snapshot;
        reader.read(frame, at: now, counting: true);
        expect(reader.depth, snapshot.depth, reason: 'at $ms ms');
        expect(reader.guide.squatHipY, snapshot.squatHipY);
        expect(reader.guide.squatKneeY, snapshot.squatKneeY);
        if (snapshot.depth != null) compared++;
      }
      expect(compared, greaterThan(300));
      expect(squat.update(frameAt(12000)).snapshot.phase, RepPhase.bottom);
    });

    test('past 12 s down the squat judge drops it; the depth goes on', () {
      var now = Duration.zero;
      final squat = SquatRepJudge(clock: () => now);
      final reader = ChairHoldReader();
      JudgeSnapshot? last;
      var reading = HoldReading.unknown;
      // The 3·2·1 is the first second, standing; GO at 1 s.
      for (var ms = 0; ms <= 45000; ms += 33) {
        now = _ms(ms);
        final frame = frameAt(ms);
        last = squat.update(frame).snapshot;
        reading = reader.read(frame, at: now, counting: ms <= 1000);
      }
      // The squat judge lost the squat and its standing thigh.
      expect(last!.phase, isNot(RepPhase.bottom));
      expect(last.depth, isNull);
      // The reader kept the 3·2·1's standing thigh: the real depth.
      expect(reader.standingThigh, _standingThigh);
      expect(reader.depth, closeTo(.9, 1e-9));
      expect(reading, HoldReading.ok);
      expect(reader.guide.phase, RepPhase.bottom);
    });

    test('a gap in the frames keeps the standing thigh', () {
      final reader = _afterCountdown();
      expect(_feed(reader, _seated(.9), from: 1000, to: 3000), HoldReading.ok);
      // No frame for 2 s: the squat judge would start over.
      expect(_feed(reader, _seated(.9), from: 5000, to: 5100), HoldReading.ok);
      expect(reader.standingThigh, _standingThigh);
    });
  });

  group('the reading', () {
    test('a depth of 0.751 is held, 0.749 is the hips too high', () {
      expect(
        _feed(_afterCountdown(), _seated(.751), from: 1000, to: 3000),
        HoldReading.ok,
      );
      expect(
        _feed(_afterCountdown(), _seated(.749), from: 1000, to: 3000),
        const HoldReading.broken(ChairFaults.low),
      );
    });

    test('standing up is the hips too high', () {
      final reader = _afterCountdown();
      expect(_feed(reader, _seated(.9), from: 1000, to: 3000), HoldReading.ok);
      expect(
        _feed(reader, _legs(), from: 3000, to: 4000),
        const HoldReading.broken(ChairFaults.low),
      );
    });

    test('hips under the knees (a depth over 1) are held', () {
      final reader = _afterCountdown();
      expect(_feed(reader, _seated(1.2), from: 1000, to: 3000), HoldReading.ok);
      expect(reader.depth, closeTo(1.2, 1e-9));
    });

    test('knees at 0.79 of the ankles\' gap are knees in, at 0.81 held', () {
      expect(
        _feed(
          _afterCountdown(),
          _seated(.9, kneeGap: 79),
          from: 1000,
          to: 3000,
        ),
        const HoldReading.broken(ChairFaults.kneesIn),
      );
      final reader = _afterCountdown();
      expect(
        _feed(reader, _seated(.9, kneeGap: 81), from: 1000, to: 3000),
        HoldReading.ok,
      );
      expect(reader.kneeRatio, closeTo(.81, 1e-9));
    });

    test('hips too high and knees in: the hips', () {
      expect(
        _feed(
          _afterCountdown(),
          _seated(.5, kneeGap: 40),
          from: 1000,
          to: 3000,
        ),
        const HoldReading.broken(ChairFaults.low),
      );
    });

    for (final hidden in [
      BodyLandmark.leftKnee,
      BodyLandmark.rightKnee,
      BodyLandmark.leftAnkle,
      BodyLandmark.rightAnkle,
    ]) {
      test('${hidden.name} not seen: the knees are not read', () {
        final reader = _afterCountdown();
        expect(
          _feed(
            reader,
            _seated(.9, kneeGap: 40, hide: {hidden}),
            from: 1000,
            to: 3000,
          ),
          HoldReading.ok,
        );
        // The depth comes from the other leg.
        expect(reader.depth, closeTo(.9, 1e-9));
      });
    }

    test('no leg seen is unknown', () {
      final reader = _afterCountdown();
      expect(
        _feed(
          reader,
          _seated(.9, hide: {BodyLandmark.leftHip, BodyLandmark.rightKnee}),
          from: 1000,
          to: 2000,
        ),
        HoldReading.unknown,
      );
      expect(reader.read(emptyFrame(), at: _ms(2100)), HoldReading.unknown);
      expect(reader.guide.squatHipY, isNull);
    });

    test('a leg whose ankle is not under its knee is no leg', () {
      final reader = _afterCountdown();
      final frame = standingFrame(
        showHips: true,
        move: {
          BodyLandmark.leftAnkle: (530, 690),
          BodyLandmark.rightAnkle: (470, 690),
        },
      );
      expect(reader.read(frame, at: _ms(1100)), HoldReading.unknown);
    });

    test('without the standing thigh it is unknown', () {
      final reader = ChairHoldReader();
      expect(
        _feed(reader, _seated(.9), from: 0, to: 3000),
        HoldReading.unknown,
      );
      expect(reader.standingThigh, isNull);
      expect(reader.depth, isNull);
      expect(reader.guide.phase, RepPhase.idle);
    });
  });

  group('the standing thigh', () {
    test('taken after GO while rising slowly, it rises with the thigh until '
        'the first sit: a true 0.8 is held (PR #92 review)', () {
      final reader = ChairHoldReader();
      _feed(reader, _seated(.9), from: -100, to: 3000, counting: true);
      expect(reader.standingThigh, isNull);
      // Up from 120 px (just standing) to 180 px over 3 s.
      for (var i = 1; i <= 30; i++) {
        reader.read(_legs(thigh: 120 + 2.0 * i), at: _ms(3000 + 100 * i));
      }
      _feed(reader, _legs(), from: 6000, to: 7000);
      expect(reader.standingThigh, closeTo(_standingThigh, 1));
      expect(_feed(reader, _seated(.8), from: 7000, to: 9000), HoldReading.ok);
      expect(reader.depth, closeTo(.8, .01));
    });

    test('taken after GO, a slow sit never lowers it (PR #92 review)', () {
      final reader = ChairHoldReader();
      _feed(reader, _seated(.9), from: -100, to: 3000, counting: true);
      _feed(reader, _legs(), from: 3000, to: 4500);
      expect(reader.standingThigh, closeTo(_standingThigh, 2));
      final taken = reader.standingThigh!;
      // Down from 180 px to 36 px (a true 0.8) over 4 s.
      for (var i = 1; i <= 40; i++) {
        reader.read(_legs(thigh: 180 - 3.6 * i), at: _ms(4500 + 100 * i));
        expect(reader.standingThigh, taken, reason: 'at step $i');
      }
      expect(_feed(reader, _seated(.8), from: 8500, to: 10000), HoldReading.ok);
      // Standing again after the sit does not move it either.
      _feed(reader, _legs(thigh: 190), from: 10000, to: 11000);
      expect(reader.standingThigh, taken);
    });

    test('legs lost before it is taken start its 300 ms over: back in a '
        'shallow bend, it is not taken at once (PR #92 review)', () {
      final reader = ChairHoldReader();
      reader.read(_legs(), at: _ms(0), counting: true);
      final noLegs = _legs(
        hide: const {
          BodyLandmark.leftHip,
          BodyLandmark.rightHip,
          BodyLandmark.leftKnee,
          BodyLandmark.rightKnee,
          BodyLandmark.leftAnkle,
          BodyLandmark.rightAnkle,
        },
      );
      for (final ms in [100, 200, 300]) {
        expect(
          reader.read(noLegs, at: _ms(ms), counting: true),
          HoldReading.unknown,
        );
      }
      // A shallow bend still reads as standing (thigh over 0.7 of the shin).
      reader.read(_seated(.25), at: _ms(400), counting: true);
      expect(reader.standingThigh, isNull);
      expect(reader.depth, isNull);
    });

    test('standing in the 3·2·1 takes it after 300 ms', () {
      final reader = ChairHoldReader();
      for (final ms in [0, 100, 200]) {
        reader.read(_legs(), at: _ms(ms), counting: true);
        expect(reader.standingThigh, isNull, reason: 'at $ms ms');
      }
      reader.read(_legs(), at: _ms(300), counting: true);
      expect(reader.standingThigh, _standingThigh);
      expect(reader.depth, 0);
    });

    test('not standing in the 3·2·1, it is taken after GO', () {
      final reader = ChairHoldReader();
      _feed(reader, _seated(.9), from: -100, to: 3000, counting: true);
      expect(reader.standingThigh, isNull);
      // Smoothed up from the seated thigh: standing from 3.1 s, taken at
      // 3.4 s.
      _feed(reader, _legs(), from: 3000, to: 3300);
      expect(reader.standingThigh, isNull);
      expect(
        _feed(reader, _legs(), from: 3300, to: 3400),
        const HoldReading.broken(ChairFaults.low),
      );
      expect(reader.standingThigh, closeTo(_standingThigh, 2));
      expect(_feed(reader, _seated(.9), from: 3300, to: 5000), HoldReading.ok);
    });

    test('in the 3·2·1 it does not change while seated, nor halfway up', () {
      final reader = _afterCountdown();
      _feed(reader, _seated(.9), from: 1000, to: 11000, counting: true);
      expect(reader.standingThigh, _standingThigh);
      // Up to 0.2, standing by the shin but not yet back at 0.15.
      _feed(reader, _seated(.2), from: 11000, to: 13000, counting: true);
      expect(reader.standingThigh, _standingThigh);
      // Back at 0.1 it follows again, in the 3·2·1.
      _feed(reader, _seated(.1), from: 13000, to: 15000, counting: true);
      expect(reader.standingThigh, lessThan(_standingThigh));
    });

    test('in the 3·2·1, standing, it follows slowly', () {
      final reader = _afterCountdown();
      reader.read(_legs(thigh: 170), at: _ms(1100), counting: true);
      final first = reader.standingThigh!;
      expect(first, lessThan(_standingThigh));
      expect(first, greaterThan(175));
      _feed(reader, _legs(thigh: 170), from: 1100, to: 5000, counting: true);
      expect(reader.standingThigh, closeTo(170, .01));
    });

    test('after GO it never changes: standing, halfway up or seated', () {
      final reader = _afterCountdown();
      // The same frames that moved it in the 3·2·1.
      _feed(reader, _legs(thigh: 170), from: 1000, to: 5000);
      expect(reader.standingThigh, _standingThigh);
      _feed(reader, _seated(.9), from: 5000, to: 8000);
      expect(reader.standingThigh, _standingThigh);
      // Halfway up, then back at 0.1, where the 3·2·1 would follow again.
      _feed(reader, _seated(.2), from: 8000, to: 9000);
      expect(reader.standingThigh, _standingThigh);
      _feed(reader, _seated(.1), from: 9000, to: 11000);
      _feed(reader, _legs(), from: 11000, to: 13000);
      expect(reader.standingThigh, _standingThigh);
    });

    test('taken after GO, it is taken once and not followed', () {
      final reader = ChairHoldReader();
      _feed(reader, _seated(.9), from: -100, to: 3000, counting: true);
      _feed(reader, _legs(), from: 3000, to: 5000);
      final taken = reader.standingThigh!;
      _feed(reader, _legs(thigh: 160), from: 5000, to: 8000);
      expect(reader.standingThigh, taken);
    });
  });

  group('a slow sit after GO (the user\'s decision, 2026-11-24)', () {
    /// After a 3·2·1 of 1 s standing, down to a true [depth] over [ms]
    /// after GO, then seated for 1 s: a frame every 33 ms, with whether it
    /// is a 3·2·1 frame.
    List<(int, PoseFrame, bool)> slowSit(int ms, {double depth = .8}) => [
      for (var t = 0; t <= 1000 + ms + 1000; t += 33)
        (
          t,
          t <= 1000
              ? _legs()
              : _seated(depth * ((t - 1000) / ms).clamp(0.0, 1.0)),
          t <= 1000,
        ),
    ];

    for (final ms in [3000, 4000, 6000]) {
      test('down to 0.8 over ${ms ~/ 1000} s reads 0.8 and is held, where '
          'the squat judge\'s rule reads under 0.75', () {
        var now = Duration.zero;
        final squat = SquatRepJudge(clock: () => now);
        final reader = ChairHoldReader();
        var reading = HoldReading.unknown;
        double? squatDepth;
        for (final (t, frame, counting) in slowSit(ms)) {
          now = _ms(t);
          squatDepth = squat.update(frame).snapshot.depth;
          reading = reader.read(frame, at: now, counting: counting);
        }
        expect(reader.standingThigh, _standingThigh);
        expect(reader.depth, closeTo(.8, 1e-6));
        expect(reading, HoldReading.ok);
        // Why: following the thigh down while it still stands lowers the
        // squat judge's standing thigh, so its depth reads short.
        expect(squatDepth, lessThan(.75));
      });
    }

    test('the entry ends and the time runs, with no warning', () {
      final stage = ArcadeCatalog.stage(5) as ArcadeHoldStage;
      final judge = HoldJudge(definition: chairHold, endsAt: stage.endsAt);
      for (final (t, frame, counting) in slowSit(4000)) {
        if (counting) {
          judge.countdown(frame, _ms(t));
          continue;
        }
        if (!judge.started) judge.go(_ms(1000));
        judge.frame(frame, _ms(t));
      }
      final progress = judge.progress;
      expect(progress.state, HoldState.holding);
      expect(progress.warnings, isEmpty);
      expect(progress.held, greaterThan(Duration.zero));
      expect(judge.lastReading, HoldReading.ok);
    });

    test('sitting again slowly after a warning runs the time again', () {
      final stage = ArcadeCatalog.stage(5) as ArcadeHoldStage;
      final judge = HoldJudge(definition: chairHold, endsAt: stage.endsAt);
      for (var t = 0; t <= 1000; t += 100) {
        judge.countdown(_legs(), _ms(t));
      }
      judge.go(_ms(1000));
      var t = 1000;
      void feed(PoseFrame Function(int t) frame, int until) {
        for (; t < until; t += 33) {
          judge.frame(frame(t), _ms(t));
        }
      }

      feed((_) => _seated(.8), 3000);
      expect(judge.progress.state, HoldState.holding);
      // Up for 1 s: a warning.
      feed((_) => _legs(), 4000);
      expect(judge.progress.warnings, [ChairFaults.low]);
      // Down again over 4 s, then seated for 1 s.
      final from = t;
      feed(
        (t) => _seated(.8 * ((t - from) / 4000).clamp(0.0, 1.0)),
        from + 5000,
      );
      expect(judge.progress.state, HoldState.holding);
      expect(judge.progress.warnings, [ChairFaults.low]);
      expect(judge.lastReading, HoldReading.ok);
    });
  });

  group('the squat guide\'s lines', () {
    test('the hips and knees read, and a green hip line while held', () {
      final reader = _afterCountdown();
      expect(reader.guide.phase, RepPhase.up);
      expect(reader.guide.squatHipY, 700 - _standingThigh);
      expect(reader.guide.squatKneeY, 700);
      reader.read(_seated(.9), at: _ms(1100));
      expect(reader.guide.phase, RepPhase.descending);
      _feed(reader, _seated(.9), from: 1100, to: 2000);
      expect(reader.guide.phase, RepPhase.bottom);
      // Smoothed for 0.9 s: within a thousandth of the seated depth.
      expect(reader.guide.depth, closeTo(.9, 1e-3));
      expect(reader.guide.squatHipY, closeTo(700 - _standingThigh * .1, 1e-9));
      _feed(reader, _seated(.6), from: 2000, to: 3000);
      expect(reader.guide.phase, RepPhase.descending);
      _feed(reader, _legs(), from: 3000, to: 4000);
      expect(reader.guide.phase, RepPhase.up);
    });

    test('a frame without a leg draws no lines', () {
      final reader = _afterCountdown();
      reader.read(emptyFrame(), at: _ms(1100));
      expect(reader.guide.squatHipY, isNull);
      expect(reader.guide.squatKneeY, isNull);
      expect(reader.guide.phase, isNot(RepPhase.lost));
    });
  });

  test('in debug builds it prints its numbers twice a second', () {
    final reader = _afterCountdown();
    expect(printed, hasLength(3)); // At 0, 0.5 and 1 s of the 3·2·1.
    expect(printed.first, startsWith('chair_hold 3-2-1 '));
    printed.clear();
    _feed(reader, _seated(.9), from: 1000, to: 3000);
    expect(printed, hasLength(4)); // At 1.5, 2, 2.5 and 3 s.
    expect(
      printed.last,
      'chair_hold hold depth=0.900 knees=1.000 standingThigh=180.0 '
      'HoldReading.ok',
    );
  });

  group('a chair stage on a fake clock (HoldJudge)', () {
    /// STAGE 5 (10, 15 and 20 s): a 3·2·1 of 3 s standing, GO at 3 s.
    HoldJudge started() {
      final stage = ArcadeCatalog.stage(5) as ArcadeHoldStage;
      final judge = HoldJudge(definition: chairHold, endsAt: stage.endsAt);
      for (var ms = 0; ms <= 3000; ms += 100) {
        judge.countdown(_legs(), _ms(ms));
      }
      judge.go(_ms(3000));
      return judge;
    }

    HoldProgress feed(HoldJudge judge, PoseFrame frame, int from, int to) {
      var progress = judge.progress;
      for (var ms = from + 100; ms <= to; ms += 100) {
        progress = judge.frame(frame, _ms(ms));
      }
      return progress;
    }

    test('standing after GO: the time stays at 0, with no warning', () {
      final judge = started();
      final progress = feed(judge, _legs(), 3000, 13000);
      expect(progress.state, HoldState.entering);
      expect(progress.held, Duration.zero);
      expect(progress.warnings, isEmpty);
      expect(judge.lastReading, const HoldReading.broken(ChairFaults.low));
    });

    test('seated, the time starts 0.6 s after the pose is first held', () {
      final judge = started();
      feed(judge, _legs(), 3000, 5000);
      // 5.1 s: 0.71 deep, still low; 5.2 s: held.
      expect(feed(judge, _seated(.9), 5000, 5100).state, HoldState.entering);
      expect(judge.lastReading, const HoldReading.broken(ChairFaults.low));
      expect(feed(judge, _seated(.9), 5100, 5700).state, HoldState.entering);
      final running = feed(judge, _seated(.9), 5700, 5800);
      expect(running.state, HoldState.holding);
      expect(running.held, Duration.zero);
      expect(feed(judge, _seated(.9), 5800, 6800).held, _ms(1000));
      expect(judge.guide!.phase, RepPhase.bottom);
    });

    test('then a warning is A4\'s: 0.5 s of hips too high, then knees in', () {
      final judge = started();
      feed(judge, _seated(.9), 3000, 6000);
      expect(judge.progress.state, HoldState.holding);
      // Up: low from the first frame, 6.1 s; warned 0.5 s later.
      feed(judge, _legs(), 6000, 6500);
      expect(judge.progress.warnings, isEmpty);
      var progress = feed(judge, _legs(), 6500, 6600);
      expect(progress.warnings, [ChairFaults.low]);
      expect(progress.paused, isTrue);
      // Seated again: 0.6 s held runs the time again.
      progress = feed(judge, _seated(.9), 6600, 7600);
      expect(progress.state, HoldState.holding);
      // Knees in from 7.7 s; 0.5 s later the second warning ends it.
      progress = feed(judge, _seated(.9, kneeGap: 50), 7600, 8100);
      expect(progress.warnings, [ChairFaults.low]);
      progress = feed(judge, _seated(.9, kneeGap: 50), 8100, 8200);
      expect(progress.warnings, [ChairFaults.low, ChairFaults.kneesIn]);
      expect(progress.end, HoldEnd.warnings);
    });

    test('out of the picture for over 1 s is off screen', () {
      final judge = started();
      feed(judge, _seated(.9), 3000, 6000);
      final progress = feed(judge, emptyFrame(), 6000, 7600);
      expect(progress.warnings, [HoldFault.offScreen]);
    });

    test('held to the third star: 20 s, the end', () {
      final judge = started();
      final progress = feed(judge, _seated(.9), 3000, 25000);
      expect(progress.end, HoldEnd.held);
      expect(progress.held, const Duration(seconds: 20));
      expect(progress.warnings, isEmpty);
    });
  });
}
