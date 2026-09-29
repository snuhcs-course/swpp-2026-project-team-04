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

    test('size uses the width for a wide, short front-view push-up', () {
      final status = checker(ExerciseType.pushUp).update(pushUpFrontFrame());
      expect(status.reason, SetupReason.ready);
    });

    test('missingParts names the hands when they are out of frame', () {
      final frame = standingFrame(
        move: {for (final l in handLandmarks) l: (500, 995)},
      );
      final status = checker(ExerciseType.pushUp).update(frame);
      expect(status.reason, SetupReason.missingParts);
      expect(status.missingParts, [BodyPart.hands]);
      expect(status.message, 'Hands not visible.');
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
          BodyLandmark.leftElbow,
          BodyLandmark.leftWrist,
          BodyLandmark.rightWrist,
        },
      );
      final status = checker(ExerciseType.pushUp).update(frame);
      expect(status.missingParts, [BodyPart.elbows, BodyPart.hands]);
      expect(status.message, 'Elbows and hands not visible.');
    });

    test('a face above the frame is a missing head, not a turned one', () {
      // Nose and eyes are confidently detected but outside the frame margin.
      final frame = standingFrame(
        move: {
          BodyLandmark.nose: (500, 10),
          BodyLandmark.leftEye: (515, 5),
          BodyLandmark.rightEye: (485, 5),
        },
        hide: {BodyLandmark.leftWrist, BodyLandmark.rightWrist},
      );
      final status = checker(ExerciseType.pushUp).update(frame);
      expect(status.reason, SetupReason.missingParts);
      expect(status.missingParts, [BodyPart.head, BodyPart.hands]);
      expect(status.message, 'Head and hands not visible.');
    });

    test('size checks run before the other checks', () {
      final far = standingFrame(scale: 0.4, hide: faceLandmarks);
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

  group('facing forward', () {
    test('face hidden (back or head turned away) is not facing', () {
      final status = checker(ExerciseType.pushUp)
          .update(standingFrame(hide: faceLandmarks));
      expect(status.reason, SetupReason.notFacingForward);
      expect(status.message, 'Face the camera.');
      expect(status.isReady, isFalse);
    });

    test('one eye hidden is not facing', () {
      final status = checker(ExerciseType.pushUp)
          .update(standingFrame(hide: {BodyLandmark.rightEye}));
      expect(status.reason, SetupReason.notFacingForward);
    });

    test('head turned: both eyes on one side of the nose', () {
      final frame = standingFrame(move: {BodyLandmark.nose: (525, 150)});
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.notFacingForward,
      );
    });

    test('body sideways: shoulders overlap, nose far from their midpoint', () {
      final frame = standingFrame(
        move: {
          BodyLandmark.leftShoulder: (460, 250),
          BodyLandmark.rightShoulder: (440, 250),
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.notFacingForward,
      );
    });

    test('nose offset exactly at the limit still faces forward', () {
      // Shoulders 440-560: midpoint 500, half width 60. 0.5 * 60 = 30.
      final frame = standingFrame(
        move: {
          BodyLandmark.nose: (530, 150),
          BodyLandmark.leftEye: (545, 140),
          BodyLandmark.rightEye: (515, 140),
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.ready,
      );
    });

    test('nose offset just over the limit is not facing', () {
      final frame = standingFrame(
        move: {
          BodyLandmark.nose: (531, 150),
          BodyLandmark.leftEye: (546, 140),
          BodyLandmark.rightEye: (516, 140),
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.notFacingForward,
      );
    });

    test('facing check runs before the missing parts check', () {
      final frame = standingFrame(
        hide: {...faceLandmarks, BodyLandmark.leftWrist},
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.notFacingForward,
      );
    });

    test('without both shoulders, missing parts are reported instead', () {
      final frame = standingFrame(
        hide: {...faceLandmarks, BodyLandmark.leftShoulder},
      );
      final status = checker(ExerciseType.pushUp).update(frame);
      expect(status.reason, SetupReason.missingParts);
      expect(status.missingParts, [BodyPart.head, BodyPart.shoulders]);
    });

    test('mirrored image (left and right swapped) still faces forward', () {
      final c = checker(ExerciseType.pushUp);
      expect(c.update(mirrored(standingFrame())).reason, SetupReason.ready);
      expect(c.update(mirrored(pushUpFrontFrame())).reason, SetupReason.ready);
    });

    test('mirrored sideways body is still not facing', () {
      final frame = standingFrame(
        move: {
          BodyLandmark.leftShoulder: (460, 250),
          BodyLandmark.rightShoulder: (440, 250),
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(mirrored(frame)).reason,
        SetupReason.notFacingForward,
      );
    });

    test('custom nose offset limit is used', () {
      final c = SetupChecker(
        exercise: ExerciseType.pushUp,
        config: const SetupConfig(maxNoseOffsetRatio: 0.1),
        clock: () => now,
      );
      final frame = standingFrame(
        move: {
          BodyLandmark.nose: (510, 150),
          BodyLandmark.leftEye: (525, 140),
          BodyLandmark.rightEye: (495, 140),
        },
      );
      expect(c.update(frame).reason, SetupReason.notFacingForward);
    });
  });

  group('required landmarks (front-view push-up)', () {
    test('push-up is the only exercise for now', () {
      expect(ExerciseType.values, [ExerciseType.pushUp]);
    });

    test('both arms are required', () {
      final frame = standingFrame(
        hide: {BodyLandmark.rightElbow, BodyLandmark.rightWrist},
      );
      final status = checker(ExerciseType.pushUp).update(frame);
      expect(status.reason, SetupReason.missingParts);
      expect(status.missingParts, [BodyPart.elbows, BodyPart.hands]);
    });

    test('both shoulders are required', () {
      final frame = standingFrame(hide: {BodyLandmark.rightShoulder});
      expect(checker(ExerciseType.pushUp).update(frame).missingParts, [
        BodyPart.shoulders,
      ]);
    });

    test('hips, knees, and feet are not required', () {
      final frame = standingFrame(
        hide: {
          BodyLandmark.leftHip,
          BodyLandmark.rightHip,
          BodyLandmark.leftKnee,
          BodyLandmark.rightKnee,
          ...feetLandmarks,
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.ready,
      );
    });
  });

  group('visibility', () {
    test('likelihood exactly at the threshold counts as visible', () {
      final frame = standingFrame(
        likelihoods: {
          BodyLandmark.leftWrist: 0.6,
          BodyLandmark.rightWrist: 0.6,
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
          BodyLandmark.leftWrist: 0.59,
          BodyLandmark.rightWrist: 0.59,
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).message,
        'Hands not visible.',
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
}
