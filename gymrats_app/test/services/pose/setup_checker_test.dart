import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';

import '../../support/pose_fixtures.dart';

void main() {
  late Duration now;
  SetupChecker checker(ExerciseType exercise) =>
      SetupChecker(exercise: exercise, clock: () => now);

  setUp(() => now = Duration.zero);

  /// Feeds [frame] at [ms] milliseconds.
  SetupStatus at(SetupChecker c, int ms, PoseFrame frame) {
    now = Duration(milliseconds: ms);
    return c.update(frame);
  }

  group('reasons', () {
    test('noPerson when no pose is detected', () {
      final status = checker(ExerciseType.pushUp).update(emptyFrame());
      expect(status.reason, SetupReason.noPerson);
      expect(status.message, 'No one detected. Step into the camera view.');
      expect(status.isReady, isFalse);
    });

    test('noPerson when no landmark passes the likelihood threshold', () {
      final frame = standingFrame(likelihood: 0.2);
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.noPerson,
      );
    });

    test('tooClose when the body is above 90% of the frame', () {
      // Head at 4% and ankles at 96% of the frame height: 92% tall.
      final frame = standingFrame(
        move: {
          BodyLandmark.nose: (500, 40),
          BodyLandmark.leftAnkle: (530, 960),
          BodyLandmark.rightAnkle: (470, 960),
        },
      );
      final status = checker(ExerciseType.pushUp).update(frame);
      expect(status.reason, SetupReason.tooClose);
      expect(status.message, 'Move back a little.');
    });

    test('tooFar when the body is below 35% of the frame', () {
      final status = checker(ExerciseType.pushUp)
          .update(standingFrame(scale: 0.4));
      expect(status.reason, SetupReason.tooFar);
      expect(status.message, 'Move closer to the camera.');
    });

    test('size uses the width for a lying body', () {
      // Lying push-up pose: wide but short.
      final status = checker(ExerciseType.pushUp).update(lyingFrame());
      expect(status.reason, SetupReason.ready);
    });

    test('missingParts names the feet when ankles are out of frame', () {
      final frame = standingFrame(
        move: {for (final l in feetLandmarks) l: (500, 995)},
      );
      final status = checker(ExerciseType.pushUp).update(frame);
      expect(status.reason, SetupReason.missingParts);
      expect(status.missingParts, [BodyPart.feet]);
      expect(status.message, 'Feet not visible.');
    });

    test('missingParts names the hands when wrists have low likelihood', () {
      final frame = standingFrame(
        hide: {BodyLandmark.leftWrist, BodyLandmark.rightWrist},
      );
      final status = checker(ExerciseType.pushUp).update(frame);
      expect(status.message, 'Hands not visible.');
    });

    test('missingParts joins several parts', () {
      final frame = standingFrame(
        hide: {
          BodyLandmark.nose,
          BodyLandmark.leftWrist,
          BodyLandmark.rightWrist,
          BodyLandmark.leftAnkle,
          BodyLandmark.rightAnkle,
        },
      );
      final status = checker(ExerciseType.pushUp).update(frame);
      expect(status.missingParts, [
        BodyPart.head,
        BodyPart.hands,
        BodyPart.feet,
      ]);
      expect(status.message, 'Head, hands and feet not visible.');
    });

    test('size checks run before the missing parts check', () {
      final far = standingFrame(scale: 0.4, hide: {BodyLandmark.nose});
      expect(
        checker(ExerciseType.pushUp).update(far).reason,
        SetupReason.tooFar,
      );
      final close = standingFrame(
        hide: {BodyLandmark.leftWrist, BodyLandmark.rightWrist},
        move: {
          BodyLandmark.nose: (500, 40),
          BodyLandmark.leftAnkle: (530, 960),
          BodyLandmark.rightAnkle: (470, 960),
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(close).reason,
        SetupReason.tooClose,
      );
    });

    test('ready reason when all checks pass, message asks to hold', () {
      final status = checker(ExerciseType.pushUp).update(standingFrame());
      expect(status.reason, SetupReason.ready);
      expect(status.isReady, isFalse);
      expect(status.message, 'Hold still...');
    });
  });

  group('required landmarks', () {
    test('push-up is valid with only the left side visible', () {
      final frame = standingFrame(hide: rightSideLandmarks);
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.ready,
      );
    });

    test('push-up is valid with only the right side visible', () {
      final frame = standingFrame(hide: leftSideLandmarks);
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.ready,
      );
    });

    test('one-side check does not mix sides', () {
      // Left ankle and right wrist missing: neither side is complete.
      final frame = standingFrame(
        hide: {BodyLandmark.leftAnkle, BodyLandmark.rightWrist},
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.missingParts,
      );
    });

    test('sit-up does not need the arms', () {
      final frame = standingFrame(
        hide: {
          BodyLandmark.leftElbow,
          BodyLandmark.rightElbow,
          BodyLandmark.leftWrist,
          BodyLandmark.rightWrist,
        },
      );
      expect(
        checker(ExerciseType.sitUp).update(frame).reason,
        SetupReason.ready,
      );
    });

    test('pull-up needs both sides', () {
      final frame = standingFrame(hide: rightSideLandmarks);
      final status = checker(ExerciseType.pullUp).update(frame);
      expect(status.reason, SetupReason.missingParts);
      expect(status.missingParts, [
        BodyPart.shoulders,
        BodyPart.elbows,
        BodyPart.hands,
        BodyPart.hips,
      ]);
    });

    test('pull-up does not need the legs', () {
      final frame = standingFrame(
        hide: {BodyLandmark.leftKnee, BodyLandmark.rightKnee, ...feetLandmarks},
      );
      expect(
        checker(ExerciseType.pullUp).update(frame).reason,
        SetupReason.ready,
      );
    });

    test('every exercise needs the nose', () {
      for (final exercise in ExerciseType.values) {
        final frame = standingFrame(hide: {BodyLandmark.nose});
        expect(checker(exercise).update(frame).missingParts, [
          BodyPart.head,
        ], reason: exercise.name);
      }
    });
  });

  group('visibility', () {
    test('likelihood exactly at the threshold counts as visible', () {
      final frame = standingFrame(
        likelihoods: {
          BodyLandmark.leftAnkle: 0.6,
          BodyLandmark.rightAnkle: 0.6,
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.ready,
      );
    });

    test('likelihood just below the threshold is not visible', () {
      final frame = standingFrame(
        likelihoods: {
          BodyLandmark.leftAnkle: 0.59,
          BodyLandmark.rightAnkle: 0.59,
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).message,
        'Feet not visible.',
      );
    });

    test('landmark inside the 3% margin is visible', () {
      final c = checker(ExerciseType.pushUp);
      final frame = emptyFrame();
      expect(c.isVisible(kp(BodyLandmark.nose, 31, 31), frame), isTrue);
      expect(c.isVisible(kp(BodyLandmark.nose, 969, 969), frame), isTrue);
    });

    test('landmark within 3% of any edge is not visible', () {
      final c = checker(ExerciseType.pushUp);
      final frame = emptyFrame();
      expect(c.isVisible(kp(BodyLandmark.nose, 29, 500), frame), isFalse);
      expect(c.isVisible(kp(BodyLandmark.nose, 971, 500), frame), isFalse);
      expect(c.isVisible(kp(BodyLandmark.nose, 500, 29), frame), isFalse);
      expect(c.isVisible(kp(BodyLandmark.nose, 500, 971), frame), isFalse);
    });
  });

  group('stability', () {
    test('Ready only after 1.5 s of valid frames', () {
      final c = checker(ExerciseType.pushUp);
      expect(at(c, 0, standingFrame()).isReady, isFalse);
      final mid = at(c, 1000, standingFrame());
      expect(mid.isReady, isFalse);
      expect(mid.readyProgress, closeTo(2 / 3, 1e-9));
      expect(at(c, 1499, standingFrame()).isReady, isFalse);
      final done = at(c, 1500, standingFrame());
      expect(done.isReady, isTrue);
      expect(done.readyProgress, 1);
      expect(done.message, 'Ready! Press Start.');
    });

    test('Ready is time based, not frame-count based', () {
      final c = checker(ExerciseType.pushUp);
      at(c, 0, standingFrame());
      // A single frame after a long gap is enough.
      expect(at(c, 2000, standingFrame()).isReady, isTrue);
    });

    test('an invalid frame restarts the 1.5 s timer', () {
      final c = checker(ExerciseType.pushUp);
      at(c, 0, standingFrame());
      at(c, 1000, standingFrame());
      at(c, 1100, emptyFrame());
      at(c, 1200, standingFrame());
      expect(at(c, 2600, standingFrame()).isReady, isFalse);
      expect(at(c, 2700, standingFrame()).isReady, isTrue);
    });

    test('one bad frame keeps Ready', () {
      final c = checker(ExerciseType.pushUp);
      at(c, 0, standingFrame());
      at(c, 1500, standingFrame());
      final bad = at(c, 1566, emptyFrame());
      expect(bad.isReady, isTrue);
      expect(bad.reason, SetupReason.noPerson);
      expect(at(c, 1633, standingFrame()).isReady, isTrue);
      // The grace timer restarts after a good frame.
      expect(at(c, 1700, emptyFrame()).isReady, isTrue);
      expect(at(c, 2150, emptyFrame()).isReady, isTrue);
    });

    test('0.5 s of invalid frames clears Ready', () {
      final c = checker(ExerciseType.pushUp);
      at(c, 0, standingFrame());
      at(c, 1500, standingFrame());
      expect(at(c, 1600, emptyFrame()).isReady, isTrue);
      expect(at(c, 2000, emptyFrame()).isReady, isTrue);
      final dropped = at(c, 2100, emptyFrame());
      expect(dropped.isReady, isFalse);
      expect(dropped.readyProgress, 0);
      // After dropping, the full 1.5 s is needed again.
      at(c, 2200, standingFrame());
      expect(at(c, 3600, standingFrame()).isReady, isFalse);
      expect(at(c, 3700, standingFrame()).isReady, isTrue);
    });

    test('reset clears Ready and timers', () {
      final c = checker(ExerciseType.pushUp);
      at(c, 0, standingFrame());
      at(c, 1500, standingFrame());
      c.reset();
      final status = at(c, 1600, standingFrame());
      expect(status.isReady, isFalse);
      expect(status.readyProgress, 0);
    });

    test('custom config thresholds are used', () {
      final c = SetupChecker(
        exercise: ExerciseType.pushUp,
        config: const SetupConfig(readyDelay: Duration(milliseconds: 200)),
        clock: () => now,
      );
      at(c, 0, standingFrame());
      expect(at(c, 200, standingFrame()).isReady, isTrue);
    });
  });

  test('placement guide text per exercise', () {
    expect(
      placementGuideFor(ExerciseType.pushUp),
      'Place the phone on the floor, facing your side, about 2 m away.',
    );
    expect(
      placementGuideFor(ExerciseType.sitUp),
      'Place the phone on the floor, facing your side, about 1.5 m away.',
    );
    expect(
      placementGuideFor(ExerciseType.pullUp),
      'Place the phone at chest height, facing you, about 2.5 m away.',
    );
  });
}
