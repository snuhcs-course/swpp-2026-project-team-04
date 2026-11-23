import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/hold_reading.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/high_plank_hold.dart';
import 'package:gymrats_app/services/pose/hold_judge.dart';
import 'package:gymrats_app/services/pose/hold_poses.dart';
import 'package:gymrats_app/services/pose/pose_metrics.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';

import '../../support/pose_fixtures.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

/// A knee classifier that reads every frame it can classify as [p] touching.
KneeFrameClassifier _classifier(double p) =>
    KneeFrameClassifier(probability: (_) => p, threshold: .5);

/// A reader whose knee classifier never reads touching, so a test sees one
/// rule at a time.
HighPlankReader _reader({KneeFrameClassifier? knees}) =>
    HighPlankReader(kneeClassifier: knees ?? _classifier(0));

const _broken = HoldReading.broken;

/// [frame] with [points] moved, the rest as they were.
PoseFrame _moved(PoseFrame frame, Map<BodyLandmark, (double, double)> points) =>
    PoseFrame(
      imageWidth: frame.imageWidth,
      imageHeight: frame.imageHeight,
      keypoints: {
        ...frame.keypoints,
        for (final MapEntry(key: landmark, value: (x, y)) in points.entries)
          landmark: kp(landmark, x, y),
      },
    );

/// The plank of [pushUpFrame] with hips 50 px under the shoulders and the
/// knees [legLength] from the hips, folded to [hipDeg] at the hips. The
/// knees sit far behind the hands, out of the judge's knee-beside-hands
/// range.
PoseFrame _withLegs(double hipDeg, {double legLength = 500, double depth = 0}) {
  final frame = pushUpFrame(depth: depth, shoulderDrop: 0);
  final radians = hipDeg * math.pi / 180;
  (double, double) knee(double hipX, double side) => (
    hipX + side * legLength * math.sin(radians),
    450 - legLength * math.cos(radians),
  );
  final leftKnee = knee(400, -1);
  final rightKnee = knee(600, 1);
  return _moved(frame, {
    BodyLandmark.leftHip: (400, 450),
    BodyLandmark.rightHip: (600, 450),
    BodyLandmark.leftKnee: leftKnee,
    BodyLandmark.rightKnee: rightKnee,
    BodyLandmark.leftAnkle: (leftKnee.$1, leftKnee.$2 + 40),
    BodyLandmark.rightAnkle: (rightKnee.$1, rightKnee.$2 + 40),
  });
}

/// Reads [frame] as held from GO for the head's place: [HighPlankReader]
/// takes it over its first 0.5 s.
void _takeHead(HighPlankReader reader, {PoseFrame? frame}) {
  for (var t = 0; t <= 500; t += 50) {
    expect(
      reader.read(frame ?? pushUpFrame(), at: _ms(t)),
      HoldReading.ok,
      reason: 'at $t ms',
    );
  }
}

void main() {
  group('the high plank bundle', () {
    test('is set up as a push-up, held from GO, with its own words', () {
      final plank = HoldPoses.of(HoldPose.plank);
      expect(plank, same(highPlankHold));
      expect(plank.pose, HoldPose.plank);
      expect(plank.setupExercise, ExerciseType.pushUp);
      expect(plank.entry, isFalse);
      expect(plank.checks, ['팔 펴기', '무릎 떼기', '머리 들기']);
      expect(plank.silhouette, HoldSilhouette.plank);
      expect(plank.guide, HoldGuide.chestHeight);
      expect(plank.createReader(), isA<HighPlankReader>());
      expect(plank.faults.map((f) => f.cue), [
        ('팔', '펴요'),
        ('무릎', '떼요'),
        ('머리', '들어요'),
      ]);
      expect(plank.faults.map((f) => f.icon), [
        HoldIcon.blank,
        HoldIcon.knee,
        HoldIcon.blank,
      ]);
    });

    test('the chair pose is stopped until A5', () {
      expect(
        () => HoldPoses.of(HoldPose.chair),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('HighPlankReader: lines from the judge and the setup', () {
    test('the numbers are the current judge and setup ones', () {
      final reader = HighPlankReader();
      expect(reader.setup.pushUpArmAngle, 155);
      expect(reader.judge.topAngle, 155);
      expect(reader.judge.enterDepth, .35);
      expect(reader.judge.minLikelihood, .6);
      expect(reader.baselineFor, HoldTiming.warn);
      expect(const SetupConfig().pushUpArmAngle, reader.judge.topAngle);
    });

    test('a straight-arm plank is held', () {
      expect(_reader().read(pushUpFrame(), at: Duration.zero), HoldReading.ok);
    });

    test('arms at 156° are held, at 154° bent', () {
      final reader = _reader();
      expect(
        reader.read(pushUpFrame(elbowAngle: 156), at: Duration.zero),
        HoldReading.ok,
      );
      expect(
        reader.read(pushUpFrame(elbowAngle: 154), at: Duration.zero),
        _broken(HighPlankFaults.armBent),
      );
    });

    test('hands above the shoulders read as off screen: the user stood up', () {
      final frame = _moved(pushUpFrame(), {
        BodyLandmark.leftWrist: (380, 300),
        BodyLandmark.rightWrist: (620, 300),
      });
      expect(
        _reader().read(frame, at: Duration.zero),
        _broken(HoldFault.offScreen),
      );
    });

    test('one hand not seen never reads as standing up', () {
      final frame = _moved(pushUpFrame(), {BodyLandmark.leftWrist: (380, 300)});
      final hidden = PoseFrame(
        imageWidth: frame.imageWidth,
        imageHeight: frame.imageHeight,
        keypoints: {
          ...frame.keypoints,
          BodyLandmark.leftWrist: kp(
            BodyLandmark.leftWrist,
            380,
            300,
            likelihood: .1,
          ),
        },
      );
      expect(_reader().read(hidden, at: Duration.zero), HoldReading.ok);
    });

    test('an upright body with the hands down reads as off screen', () {
      final standing = standingFrame(showHips: true);
      expect(measurePose(standing).handsBelowShoulders, isTrue);
      expect(
        _reader().read(standing, at: Duration.zero),
        _broken(HoldFault.offScreen),
      );
    });
  });

  group('HighPlankReader: unknown', () {
    test('a frame without the shoulders is unknown', () {
      final frame = pushUpFrame(
        hide: {BodyLandmark.leftShoulder, BodyLandmark.rightShoulder},
      );
      expect(_reader().read(frame, at: Duration.zero), HoldReading.unknown);
    });

    test('a frame with one shoulder is unknown', () {
      final frame = pushUpFrame(hide: {BodyLandmark.rightShoulder});
      expect(_reader().read(frame, at: Duration.zero), HoldReading.unknown);
    });

    test('a frame without an arm to read is unknown', () {
      final frame = pushUpFrame(
        hide: {BodyLandmark.leftElbow, BodyLandmark.rightWrist},
      );
      expect(_reader().read(frame, at: Duration.zero), HoldReading.unknown);
    });

    test('a frame under the judge\'s likelihood is unknown', () {
      final frame = pushUpFrame(likelihood: .59);
      expect(_reader().read(frame, at: Duration.zero), HoldReading.unknown);
    });

    test('an empty frame is unknown', () {
      expect(
        _reader().read(emptyFrame(), at: Duration.zero),
        HoldReading.unknown,
      );
    });

    test('one arm seen is enough', () {
      final frame = pushUpFrame(hide: {BodyLandmark.leftElbow});
      expect(_reader().read(frame, at: Duration.zero), HoldReading.ok);
    });
  });

  group('HighPlankReader: head', () {
    test(
      'the head\'s place is taken from the held frames of the first 0.5 s',
      () {
        final reader = _reader();
        _takeHead(reader);
        expect(reader.baseNoseY, 300);
        expect(reader.baseShoulderWidth, pushUpShoulderWidth);
      },
    );

    test('0.349 shoulder widths lower is held, 0.351 is the head down', () {
      final reader = _reader();
      _takeHead(reader);
      expect(
        reader.read(pushUpFrame(depth: .349, shoulderDrop: 0), at: _ms(600)),
        HoldReading.ok,
      );
      expect(
        reader.read(pushUpFrame(depth: .351, shoulderDrop: 0), at: _ms(650)),
        _broken(HighPlankFaults.headDown),
      );
    });

    test('a low head before its place is taken is not the head down', () {
      final reader = _reader();
      expect(
        reader.read(pushUpFrame(depth: .8, shoulderDrop: 0), at: Duration.zero),
        HoldReading.ok,
      );
    });

    test('frames of the 3·2·1 do not take the head\'s place', () {
      final reader = _reader();
      for (var t = 0; t <= 3000; t += 100) {
        reader.read(
          pushUpFrame(depth: .5, shoulderDrop: 0),
          at: _ms(t),
          counting: true,
        );
      }
      expect(reader.baseNoseY, isNull);
      _takeHead(reader);
      expect(reader.baseNoseY, 300);
    });

    test('only held frames count, and the window starts at the first', () {
      final reader = _reader();
      // Bent arms first: not held, so no window yet.
      reader.read(pushUpFrame(elbowAngle: 120), at: Duration.zero);
      reader.read(pushUpFrame(), at: _ms(1000));
      expect(reader.baseNoseY, isNull);
      reader.read(pushUpFrame(depth: .1, shoulderDrop: 0), at: _ms(1200));
      reader.read(pushUpFrame(), at: _ms(1500));
      // (300 + 320) / 2: the frame at 1.5 s closes the window.
      expect(reader.baseNoseY, 310);
    });

    test('a window without the nose waits for the first one', () {
      final reader = _reader();
      reader.read(pushUpFrame(hide: {BodyLandmark.nose}), at: Duration.zero);
      reader.read(pushUpFrame(hide: {BodyLandmark.nose}), at: _ms(600));
      expect(reader.baseNoseY, isNull);
      reader.read(pushUpFrame(), at: _ms(700));
      expect(reader.baseNoseY, 300);
    });

    test('the head\'s place is never taken again in a play', () {
      final reader = _reader();
      _takeHead(reader);
      for (var t = 600; t <= 3000; t += 100) {
        reader.read(pushUpFrame(depth: .3, shoulderDrop: 0), at: _ms(t));
      }
      expect(reader.baseNoseY, 300);
    });

    test('a head not seen is not the head down', () {
      final reader = _reader();
      _takeHead(reader);
      expect(
        reader.read(pushUpFrame(hide: {BodyLandmark.nose}), at: _ms(600)),
        HoldReading.ok,
      );
    });
  });

  group('HighPlankReader: knees, from the judge\'s parts', () {
    test('the knee classifier reading touching is knees down', () {
      final frame = _withLegs(175);
      expect(
        _reader(knees: _classifier(.99)).read(frame, at: Duration.zero),
        _broken(HighPlankFaults.kneeDown),
      );
      expect(
        _reader(knees: _classifier(.01)).read(frame, at: Duration.zero),
        HoldReading.ok,
      );
    });

    test('a classifier that cannot see the legs never reads knees down', () {
      // The lower body is hidden, as usual from the front.
      expect(
        _reader(knees: _classifier(.99)).read(pushUpFrame(), at: Duration.zero),
        HoldReading.ok,
      );
    });

    test('knees beside the hands are knees down, far behind them not', () {
      final hidden = measurePose(pushUpFrame()).kneeHandGap;
      expect(hidden, isNull);
      PoseFrame kneesAt(double y) => _moved(pushUpFrame(), {
        BodyLandmark.leftKnee: (380, y),
        BodyLandmark.rightKnee: (620, y),
      });
      final handY =
          (pushUpFrame()[BodyLandmark.leftWrist]!.y +
              pushUpFrame()[BodyLandmark.rightWrist]!.y) /
          2;
      const config = RepJudgeConfig();
      final reader = _reader();
      // Just inside each end of the judge's range, and just outside.
      for (final (gap, down) in [
        (config.minKneeHandGap + .01, true),
        (config.maxKneeHandGap - .01, true),
        (config.minKneeHandGap - .01, false),
        (config.maxKneeHandGap + .01, false),
      ]) {
        final frame = kneesAt(handY + gap * pushUpShoulderWidth);
        expect(
          reader.read(frame, at: Duration.zero),
          down ? _broken(HighPlankFaults.kneeDown) : HoldReading.ok,
          reason: 'gap $gap',
        );
      }
    });

    test('hips folded 25° from the first plank angle are knees down', () {
      final reader = _reader();
      reader.read(_withLegs(175), at: Duration.zero, counting: true);
      expect(reader.plankHipAngle, closeTo(175, .01));
      expect(reader.read(_withLegs(151), at: _ms(100)), HoldReading.ok);
      expect(
        reader.read(_withLegs(149), at: _ms(200)),
        _broken(HighPlankFaults.kneeDown),
      );
    });

    test('after three plank angles the fold line is 20°', () {
      final reader = _reader();
      for (final (i, deg) in [172.0, 176.0, 174.0].indexed) {
        reader.read(_withLegs(deg), at: _ms(i * 100), counting: true);
      }
      expect(reader.plankHipAngle, closeTo(174, .01));
      // A later straighter plank does not move it.
      reader.read(_withLegs(179), at: _ms(400));
      expect(reader.plankHipAngle, closeTo(174, .01));
      expect(reader.read(_withLegs(155), at: _ms(500)), HoldReading.ok);
      expect(
        reader.read(_withLegs(153), at: _ms(600)),
        _broken(HighPlankFaults.kneeDown),
      );
    });

    test('two plank angles are kept as their mean', () {
      final reader = _reader();
      reader.read(_withLegs(170), at: Duration.zero, counting: true);
      reader.read(_withLegs(178), at: _ms(100), counting: true);
      expect(reader.plankHipAngle, closeTo(174, .01));
    });

    test('a kneeling start never becomes the plank angle', () {
      final reader = _reader();
      reader.read(_withLegs(150), at: Duration.zero, counting: true);
      expect(reader.plankHipAngle, isNull);
      // Without a plank angle the judge's default line is off.
      expect(reader.read(_withLegs(150), at: _ms(100)), HoldReading.ok);
    });

    test('bent arms are read as bent arms, not as a fold', () {
      final reader = _reader();
      reader.read(_withLegs(175), at: Duration.zero, counting: true);
      final bent = _moved(_withLegs(145), {
        for (final MapEntry(key: landmark, value: point) in pushUpFrame(
          elbowAngle: 120,
        ).keypoints.entries)
          if (landmark.name.contains('Elbow') ||
              landmark.name.contains('Wrist'))
            landmark: (point.x, point.y),
      });
      expect(reader.read(bent, at: _ms(100)), _broken(HighPlankFaults.armBent));
    });

    test('knees down comes before bent arms, standing up before both', () {
      final reader = _reader(knees: _classifier(.99));
      final kneeling = _moved(_withLegs(175), {
        for (final MapEntry(key: landmark, value: point) in pushUpFrame(
          elbowAngle: 152,
        ).keypoints.entries)
          if (landmark.name.contains('Elbow') ||
              landmark.name.contains('Wrist'))
            landmark: (point.x, point.y),
      });
      expect(
        reader.read(kneeling, at: Duration.zero),
        _broken(HighPlankFaults.kneeDown),
      );
      final standing = _moved(kneeling, {
        BodyLandmark.leftWrist: (380, 300),
        BodyLandmark.rightWrist: (620, 300),
      });
      expect(
        reader.read(standing, at: Duration.zero),
        _broken(HoldFault.offScreen),
      );
    });
  });

  group('HighPlankReader in a HoldJudge', () {
    test('a plank held from GO runs to its third star', () {
      final judge = HoldJudge(
        definition: highPlankHold,
        endsAt: const Duration(seconds: 2),
      );
      judge.countdown(pushUpFrame(), Duration.zero);
      judge.go(_ms(100));
      for (var t = 150; t <= 2300; t += 50) {
        judge.frame(pushUpFrame(), _ms(t));
      }
      expect(judge.progress.ended, isTrue);
      expect(judge.progress.warnings, isEmpty);
    });
  });
}
