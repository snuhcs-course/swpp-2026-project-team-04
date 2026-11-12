import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/voice_cue.dart';
import 'package:gymrats_app/services/audio/voice_cue_table.dart';
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
      expect(status.message, '카메라 앞에 서 주세요.');
      expect(status.isReady, isFalse);
    });

    test('a flat or shaky phone is not ready', () {
      final flat = checker(ExerciseType.pushUp)
          .update(pushUpFrontFrame(), phonePropped: false);
      expect(flat.reason, SetupReason.phoneTooFlat);
      expect(flat.message, '폰을 더 세워 주세요.');
      expect(flat.isReady, isFalse);

      final shaky = checker(ExerciseType.pushUp)
          .update(pushUpFrontFrame(), phoneStill: false);
      expect(shaky.reason, SetupReason.phoneShaky);
      expect(shaky.isReady, isFalse);
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
      expect(status.message, '조금 뒤로 물러나 주세요.');
    });

    test('tooFar when the body is below 35% of the frame', () {
      final status = checker(ExerciseType.pushUp)
          .update(standingFrame(scale: 0.4));
      expect(status.reason, SetupReason.tooFar);
      expect(status.message, '카메라에 조금 더 가까이 와 주세요.');
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
      expect(status.message, '손이 화면에 안 보여요.');
    });

    test('missingParts names the hands when wrists have low likelihood', () {
      final frame = standingFrame(
        hide: {BodyLandmark.leftWrist, BodyLandmark.rightWrist},
      );
      final status = checker(ExerciseType.pushUp).update(frame);
      expect(status.message, '손이 화면에 안 보여요.');
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
      expect(status.message, '팔꿈치, 손이 화면에 안 보여요.');
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
      expect(status.message, '머리, 손이 화면에 안 보여요.');
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
      expect(status.message, '그대로 잠시 유지하세요.');
    });
  });

  group('facing forward', () {
    test('face hidden (back or head turned away) is not facing', () {
      final status = checker(ExerciseType.pushUp)
          .update(standingFrame(hide: faceLandmarks));
      expect(status.reason, SetupReason.notFacingForward);
      expect(status.message, '카메라를 정면으로 봐 주세요.');
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
    test('push-up and the squat demo are available', () {
      expect(ExerciseType.values, [ExerciseType.pushUp, ExerciseType.squat]);
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

  group('squat setup', () {
    test('requires a standing front-facing full body', () {
      expect(
        checker(ExerciseType.squat)
            .update(standingFrame(showHips: true))
            .reason,
        SetupReason.ready,
      );
      expect(
        checker(ExerciseType.squat)
            .update(
              standingFrame(showHips: true, hide: {BodyLandmark.leftKnee}),
            )
            .reason,
        SetupReason.missingParts,
      );
      expect(
        checker(ExerciseType.squat)
            .update(standingFrame(showHips: true, hide: {BodyLandmark.leftEye}))
            .reason,
        SetupReason.notFacingForward,
      );
      expect(
        checker(ExerciseType.squat)
            .update(
              standingFrame(
                showHips: true,
                move: {
                  BodyLandmark.leftHip: (530, 690),
                  BodyLandmark.rightHip: (470, 690),
                },
              ),
            )
            .reason,
        SetupReason.notStanding,
      );
    });
  });

  group('push-up pose', () {
    test('an upright body with the hips in view is not a push-up', () {
      final status = checker(ExerciseType.pushUp)
          .update(standingFrame(showHips: true));
      expect(status.reason, SetupReason.notInPushUp);
      expect(status.message, '팔을 펴고 푸시업 자세를 잡아 주세요.');
    });

    test('an upright body never becomes Ready', () {
      final c = checker(ExerciseType.pushUp);
      at(c, 0, standingFrame(showHips: true));
      expect(at(c, 3000, standingFrame(showHips: true)).isReady, isFalse);
    });

    test('a plank with the hips 1.2 shoulder widths down is ready', () {
      // Shoulders 120 apart at y 250: hips at 394 drop 1.2 widths.
      final frame = standingFrame(
        showHips: true,
        move: {
          BodyLandmark.leftHip: (530, 394),
          BodyLandmark.rightHip: (470, 394),
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.ready,
      );
    });

    test('hips 1.6 shoulder widths down are upright', () {
      final frame = standingFrame(
        showHips: true,
        move: {
          BodyLandmark.leftHip: (530, 442),
          BodyLandmark.rightHip: (470, 442),
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.notInPushUp,
      );
    });

    test('bent arms are not the top of a push-up', () {
      final frame = standingFrame(
        move: {
          BodyLandmark.leftElbow: (640, 380),
          BodyLandmark.rightElbow: (360, 380),
        },
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.notInPushUp,
      );
    });

    test('a plank with the hips just behind the shoulders is ready', () {
      expect(
        checker(ExerciseType.pushUp)
            .update(pushUpFrontFrame(showHips: true))
            .reason,
        SetupReason.ready,
      );
    });

    test('hidden hips leave the decision to the straight arms', () {
      expect(
        checker(ExerciseType.pushUp).update(pushUpFrontFrame()).reason,
        SetupReason.ready,
      );
    });

    test('missing parts are reported before the pose', () {
      final frame = standingFrame(
        showHips: true,
        hide: {BodyLandmark.leftWrist, BodyLandmark.rightWrist},
      );
      expect(
        checker(ExerciseType.pushUp).update(frame).reason,
        SetupReason.missingParts,
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
        '손이 화면에 안 보여요.',
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
      expect(done.message, '준비 완료!');
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

  group('the words, in Korean, as the setup voice says them', () {
    SetupStatus status(
      SetupReason reason, {
      bool ready = false,
      List<BodyPart> parts = const [],
    }) => SetupStatus(
      reason: reason,
      isReady: ready,
      readyProgress: 0,
      missingParts: parts,
    );

    test('each reason has its line', () {
      const lines = {
        SetupReason.noPerson: '카메라 앞에 서 주세요.',
        SetupReason.tooClose: '조금 뒤로 물러나 주세요.',
        SetupReason.tooFar: '카메라에 조금 더 가까이 와 주세요.',
        SetupReason.notFacingForward: '카메라를 정면으로 봐 주세요.',
        SetupReason.notInPushUp: '팔을 펴고 푸시업 자세를 잡아 주세요.',
        SetupReason.notStanding: '정면을 보고 똑바로 서 주세요.',
        SetupReason.phoneTooFlat: '폰을 더 세워 주세요.',
        SetupReason.phoneShaky: '폰이 흔들리지 않게 두세요.',
        SetupReason.ready: '그대로 잠시 유지하세요.',
      };
      for (final MapEntry(key: reason, value: line) in lines.entries) {
        expect(status(reason).message, line, reason: '$reason');
      }
      // Ready, whatever the latest frame showed.
      for (final reason in SetupReason.values) {
        expect(status(reason, ready: true).message, '준비 완료!');
      }
    });

    test('the screen says what the voice says, but for the missing parts', () {
      for (final ready in [false, true]) {
        for (final reason in SetupReason.values) {
          if (reason == SetupReason.missingParts && !ready) continue;
          final s = status(reason, ready: ready);
          expect(
            s.message,
            VoiceCueTable.forSetup(s).text,
            reason: '$reason, ready $ready',
          );
        }
      }
    });

    test('a missing part is named, with 이 after a final consonant and 가 '
        'after a vowel', () {
      const lines = {
        BodyPart.head: '머리가 화면에 안 보여요.',
        BodyPart.shoulders: '어깨가 화면에 안 보여요.',
        BodyPart.elbows: '팔꿈치가 화면에 안 보여요.',
        BodyPart.hands: '손이 화면에 안 보여요.',
        BodyPart.hips: '엉덩이가 화면에 안 보여요.',
        BodyPart.knees: '무릎이 화면에 안 보여요.',
        BodyPart.ankles: '발목이 화면에 안 보여요.',
      };
      expect(lines.keys, unorderedEquals(BodyPart.values));
      for (final MapEntry(key: part, value: line) in lines.entries) {
        expect(
          status(SetupReason.missingParts, parts: [part]).message,
          line,
          reason: '$part',
        );
      }
    });

    test('several missing parts are listed in order, the marker fitted to '
        'the last', () {
      String words(List<BodyPart> parts) =>
          status(SetupReason.missingParts, parts: parts).message;
      expect(words([BodyPart.hands, BodyPart.ankles]), '손, 발목이 화면에 안 보여요.');
      expect(words([BodyPart.ankles, BodyPart.hands]), '발목, 손이 화면에 안 보여요.');
      expect(words([BodyPart.knees, BodyPart.hips]), '무릎, 엉덩이가 화면에 안 보여요.');
      expect(
        words([BodyPart.head, BodyPart.shoulders, BodyPart.elbows]),
        '머리, 어깨, 팔꿈치가 화면에 안 보여요.',
      );
    });

    test('with no part named, the voice line for the whole body', () {
      expect(
        status(SetupReason.missingParts).message,
        VoiceCue.missingParts.text,
      );
      expect(VoiceCue.missingParts.text, '몸 전체가 화면에 보이게 해 주세요.');
    });

    test('a squat with the feet and knees out of the picture names them', () {
      final c = checker(ExerciseType.squat);
      final cut = standingFrame(
        showHips: true,
        hide: {
          BodyLandmark.leftKnee,
          BodyLandmark.leftAnkle,
          BodyLandmark.rightAnkle,
        },
      );
      final status = c.update(cut);
      expect(status.reason, SetupReason.missingParts);
      expect(status.message, '무릎, 발목이 화면에 안 보여요.');
    });
  });
}
