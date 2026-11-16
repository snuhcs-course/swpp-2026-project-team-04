import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/pose_metrics.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../../support/pose_fixtures.dart';

void main() {
  _kneeForestHistoryTests();
  _kneeContactTests();
  _mlpFeatureTests();
  _spanEvidenceTests();
  _spanCycleTests();
  test('straight arms are about 180 degrees on a level shoulder line', () {
    final metrics = measurePose(pushUpFrame(elbowAngle: 180));
    expect(metrics.elbowAngle, closeTo(180, 0.2));
    expect(metrics.shoulderWidth, closeTo(pushUpShoulderWidth, 0.01));
    expect(metrics.tilt, closeTo(0, 0.2));
  });

  test('a right angle is measured on both arms', () {
    final metrics = measurePose(pushUpFrame(elbowAngle: 90, spanRatio: 1));
    expect(metrics.elbowAngle, closeTo(90, 0.2));
  });

  test('the nose moves down with depth', () {
    final top = measurePose(pushUpFrame());
    final down = measurePose(pushUpFrame(depth: 1.5));
    expect(down.noseY! - top.noseY!, closeTo(1.5 * pushUpShoulderWidth, 0.01));
  });

  test('one visible arm is enough', () {
    final metrics = measurePose(
      pushUpFrame(
        elbowAngle: 120,
        spanRatio: 0.8,
        hide: {BodyLandmark.leftElbow, BodyLandmark.leftWrist},
      ),
    );
    expect(metrics.elbowAngle, closeTo(120, 0.2));
  });

  test('hidden wrists leave the head and shoulders', () {
    final metrics = measurePose(
      pushUpFrame(
        depth: 1.5,
        hide: {BodyLandmark.leftWrist, BodyLandmark.rightWrist},
      ),
    );
    expect(metrics.elbowAngle, isNull);
    expect(metrics.noseY, isNotNull);
    expect(metrics.shoulderWidth, isNotNull);
  });

  test('mirroring and tilting do not change the elbow angle', () {
    final frame = pushUpFrame(elbowAngle: 100, spanRatio: 0.75, tiltDeg: 20);
    final straight = measurePose(pushUpFrame(elbowAngle: 100, spanRatio: 0.75));
    final tilted = measurePose(frame);
    final flipped = measurePose(mirrored(frame));

    expect(tilted.elbowAngle, closeTo(straight.elbowAngle!, 0.2));
    expect(tilted.shoulderWidth, closeTo(straight.shoulderWidth!, 0.01));
    expect(tilted.tilt, closeTo(20, 0.2));
    expect(flipped.elbowAngle, closeTo(tilted.elbowAngle!, 0.2));
    expect(flipped.tilt, closeTo(tilted.tilt!, 0.2));
  });

  test('low-likelihood landmarks are ignored', () {
    final metrics = measurePose(pushUpFrame(likelihood: 0.2));
    expect(metrics.elbowAngle, isNull);
    expect(metrics.noseY, isNull);
    expect(metrics.shoulderWidth, isNull);
  });

  test('smoothing follows a time constant instead of the frame count', () {
    final smoother = MetricSmoother(tau: const Duration(milliseconds: 65));
    smoother.update(const PoseMetrics(elbowAngle: 100), Duration.zero);
    final blended = smoother.update(
      const PoseMetrics(elbowAngle: 0),
      const Duration(milliseconds: 65),
    );
    final alpha = 1 - math.exp(-1);
    expect(blended.elbowAngle, closeTo(100 + alpha * (0 - 100), 0.01));
  });

  test('elbow spread and hand span are measured in shoulder widths', () {
    Keypoint at(BodyLandmark landmark, double x, double y) =>
        Keypoint(landmark: landmark, x: x, y: y, likelihood: 1);
    final metrics = measurePose(
      PoseFrame(
        imageWidth: 1000,
        imageHeight: 1000,
        keypoints: {
          BodyLandmark.leftShoulder: at(BodyLandmark.leftShoulder, 400, 400),
          BodyLandmark.rightShoulder: at(BodyLandmark.rightShoulder, 600, 400),
          BodyLandmark.leftElbow: at(BodyLandmark.leftElbow, 200, 420),
          BodyLandmark.rightElbow: at(BodyLandmark.rightElbow, 700, 400),
          BodyLandmark.leftWrist: at(BodyLandmark.leftWrist, 300, 500),
          BodyLandmark.rightWrist: at(BodyLandmark.rightWrist, 700, 500),
          BodyLandmark.nose: at(BodyLandmark.nose, 500, 300),
        },
      ),
    );
    expect(metrics.shoulderY, 400);
    expect(metrics.leftElbowSpread, closeTo(1, 0.01));
    expect(metrics.rightElbowSpread, closeTo(0.5, 0.01));
    expect(metrics.handSpan, closeTo(2, 0.01));

    final tucked = measurePose(
      PoseFrame(
        imageWidth: 1000,
        imageHeight: 1000,
        keypoints: {
          BodyLandmark.leftShoulder: at(BodyLandmark.leftShoulder, 400, 400),
          BodyLandmark.rightShoulder: at(BodyLandmark.rightShoulder, 600, 400),
          BodyLandmark.leftElbow: at(BodyLandmark.leftElbow, 480, 500),
          BodyLandmark.rightElbow: at(BodyLandmark.rightElbow, 250, 500),
        },
      ),
    );
    expect(tucked.leftElbowSpread, 0);
    expect(tucked.rightElbowSpread, 0);
  });

  test('the ankle-knee gap is measured in shoulder widths', () {
    final lifted = measurePose(
      pushUpFrame(
        lowerBody: {
          BodyLandmark.leftKnee: (400, 500),
          BodyLandmark.rightKnee: (600, 500),
          BodyLandmark.leftAnkle: (400, 440),
          BodyLandmark.rightAnkle: (600, 460),
        },
      ),
    );
    // Ankles 50 px above the knees, shoulders 200 px apart.
    expect(lifted.ankleKneeGap, closeTo(-0.25, 0.01));

    final hidden = measurePose(
      pushUpFrame(
        hide: {BodyLandmark.leftAnkle, BodyLandmark.rightAnkle},
        lowerBody: {
          BodyLandmark.leftKnee: (400, 500),
          BodyLandmark.rightKnee: (600, 500),
        },
      ),
    );
    expect(hidden.ankleKneeGap, isNull);
  });

  test('a stick figure keeps visible joints and mirrors the front camera', () {
    Keypoint at(BodyLandmark landmark, double x, double y, [double p = 1]) =>
        Keypoint(landmark: landmark, x: x, y: y, likelihood: p);
    final frame = PoseFrame(
      imageWidth: 1000,
      imageHeight: 1000,
      keypoints: {
        BodyLandmark.leftShoulder: at(BodyLandmark.leftShoulder, 400, 400),
        BodyLandmark.rightShoulder: at(BodyLandmark.rightShoulder, 600, 400),
        BodyLandmark.leftElbow: at(BodyLandmark.leftElbow, 200, 500),
        BodyLandmark.rightWrist: at(BodyLandmark.rightWrist, 800, 500, 0.2),
        BodyLandmark.nose: at(BodyLandmark.nose, 500, 250),
      },
    );
    final plain = FormPose.capture(
      frame,
      at: Duration.zero,
      mirror: false,
      minLikelihood: 0.6,
    )!;
    expect(plain.points['leftShoulder']!.x, -0.5);
    expect(plain.points.containsKey('rightWrist'), isFalse);
    expect(plain.points['nose']!.y, closeTo(-0.75, 0.01));

    final mirrored = FormPose.capture(
      frame,
      at: Duration.zero,
      mirror: true,
      minLikelihood: 0.6,
    )!;
    expect(mirrored.points['leftShoulder']!.x, 0.5);
    expect(mirrored.points['leftElbow']!.x, closeTo(1.5, 0.01));
  });
}

void _kneeForestHistoryTests() {
  for (final label in ['normal', 'kneesDown']) {
    test('knee forest matches exported $label features and probability', () {
      final data = jsonDecode(
        File('test/fixtures/pushup_cases/knee_forest/golden_$label.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final frames = (data['phases'] as List).map<PoseFrame?>((phase) {
        final points = phase['points'] as List;
        return PoseFrame(
          imageWidth: (phase['width'] as num).toDouble(),
          imageHeight: (phase['height'] as num).toDouble(),
          keypoints: {
            for (var i = 0; i < points.length; i++)
              if (points[i] != null)
                BodyLandmark.values[i]: Keypoint(
                  landmark: BodyLandmark.values[i],
                  x: (points[i][0] as num).toDouble(),
                  y: (points[i][1] as num).toDouble(),
                  likelihood: 1,
                ),
          },
        );
      }).toList();
      final actual = KneeForestClassifier.featuresForPhases(frames)!;
      final expected = data['features'] as List;
      for (var i = 0; i < actual.length; i++) {
        expect(actual[i], closeTo(expected[i] as num, 1e-12));
      }
      expect(
        KneeForestClassifier.kneeProbability(frames),
        closeTo(data['knee_probability'] as num, 1e-12),
      );
      frames[0] = null;
      frames[1] = null;
      expect(KneeForestClassifier.kneeProbability(frames), isNotNull);
      frames[2] = null;
      expect(KneeForestClassifier.kneeProbability(frames), isNull);
    });
  }
  test('knee forest enforces the five-phase finite feature contract', () {
    expect(() => KneeForestClassifier.kneeProbability([]), throwsArgumentError);
    expect(
      () => KneeForestClassifier.probabilityFromFeatures([double.nan]),
      throwsArgumentError,
    );
    expect(KneeForestClassifier.kneeProbability(List.filled(5, null)), isNull);
  });
  group('five-phase knee history', () {
    late PushupKneeHistory history;
    late List<PoseFrame> frames;
    setUp(() {
      history = PushupKneeHistory();
      frames = List.generate(11, (i) => pushUpFrame(depth: i / 10));
      for (var i = 0; i < frames.length; i++) {
        history.add(frames[i], Duration(milliseconds: i * 100));
      }
    });
    test('samples ten through ninety percent of the supplied interval', () {
      expect(
        history.phaseFrames(
          start: Duration.zero,
          end: const Duration(seconds: 1),
        ),
        [
          for (final i in [1, 3, 5, 7, 9]) same(frames[i]),
        ],
      );
      expect(
        history.phaseFrames(
          start: const Duration(milliseconds: 200),
          end: const Duration(seconds: 1),
        ),
        [
          for (final i in [3, 4, 6, 8, 9]) same(frames[i]),
        ],
      );
    });
    test('unknown and unavailable boundaries produce five missing samples', () {
      for (final start in <Duration?>[
        null,
        const Duration(milliseconds: -1),
        const Duration(seconds: 1),
      ]) {
        expect(
          history.phaseFrames(start: start, end: const Duration(seconds: 1)),
          everyElement(isNull),
        );
      }
      expect(
        history.phaseFrames(
          start: Duration.zero,
          end: const Duration(seconds: 2),
        ),
        everyElement(isNull),
      );
    });
    test('truncated intervals are not extrapolated', () {
      history.add(pushUpFrame(), const Duration(seconds: 7));
      expect(
        history.phaseFrames(
          start: Duration.zero,
          end: const Duration(seconds: 7),
        ),
        everyElement(isNull),
      );
    });
    test('reset and image-dimension changes discard previous poses', () {
      history.reset();
      expect(
        history.phaseFrames(
          start: Duration.zero,
          end: const Duration(seconds: 1),
        ),
        everyElement(isNull),
      );
      history.add(frames.first, Duration.zero);
      history.add(
        const PoseFrame.empty(imageWidth: 1, imageHeight: 1),
        const Duration(seconds: 1),
      );
      expect(
        history.phaseFrames(
          start: Duration.zero,
          end: const Duration(seconds: 1),
        ),
        everyElement(isNull),
      );
    });
    test(
      'duplicate timestamps are ignored and backward time resets history',
      () {
        history.add(pushUpFrame(depth: 8), const Duration(seconds: 1));
        expect(
          history
              .phaseFrames(
                start: Duration.zero,
                end: const Duration(seconds: 1),
              )
              .last,
          same(frames[9]),
        );
        history.add(pushUpFrame(), const Duration(milliseconds: 500));
        expect(
          history.phaseFrames(
            start: Duration.zero,
            end: const Duration(milliseconds: 500),
          ),
          everyElement(isNull),
        );
      },
    );
    test('a two-frame interval cannot supply five observed phases', () {
      history.reset();
      history.add(frames.first, Duration.zero);
      history.add(frames.last, const Duration(seconds: 1));
      expect(
        history.phaseFrames(
          start: Duration.zero,
          end: const Duration(seconds: 1),
        ),
        everyElement(isNull),
      );
    });
  });
}

void _kneeContactTests() {
  PoseFrame pose({
    bool leftTouching = false,
    bool rightTouching = false,
    Set<BodyLandmark> hide = const {},
    double likelihood = 1,
    double scale = 1,
    double rotation = 0,
    bool mirror = false,
  }) {
    final points = <BodyLandmark, Keypoint>{};
    for (final left in [true, false]) {
      final touching = left ? leftTouching : rightTouching;
      final landmarks = left
          ? [
              BodyLandmark.leftShoulder,
              BodyLandmark.leftWrist,
              BodyLandmark.leftHip,
              BodyLandmark.leftKnee,
              BodyLandmark.leftAnkle,
            ]
          : [
              BodyLandmark.rightShoulder,
              BodyLandmark.rightWrist,
              BodyLandmark.rightHip,
              BodyLandmark.rightKnee,
              BodyLandmark.rightAnkle,
            ];
      final coordinates = <(double, double)>[
        (120, 400),
        (100, 700),
        touching ? (500, 500) : (550, 500),
        touching ? (700, 690) : (750, 625),
        (900, 700),
      ];
      for (var i = 0; i < landmarks.length; i++) {
        final landmark = landmarks[i];
        if (hide.contains(landmark)) continue;
        final (px, py) = coordinates[i];
        final x = (px - 600 + (left ? 0 : 100)) * scale * (mirror ? -1 : 1);
        final y = (py - 500 + (left ? 0 : 15)) * scale;
        points[landmark] = Keypoint(
          landmark: landmark,
          x: 600 + x * math.cos(rotation) - y * math.sin(rotation),
          y: 500 + x * math.sin(rotation) + y * math.cos(rotation),
          likelihood: likelihood,
        );
      }
    }
    return PoseFrame(imageWidth: 1200, imageHeight: 1000, keypoints: points);
  }

  KneeContactReading settle(
    KneeContactTracker tracker,
    PoseFrame frame, {
    int start = 0,
  }) {
    tracker.update(frame, Duration(milliseconds: start));
    tracker.update(frame, Duration(milliseconds: start + 125));
    return tracker.update(frame, Duration(milliseconds: start + 250));
  }

  void capture(KneeContactTracker tracker, PoseFrame frame, int start) {
    for (var i = 0; i < 5; i++) {
      tracker.update(frame, Duration(milliseconds: start + i * 200));
    }
  }

  PoseFrame shiftedPose({
    double kneeY = 0,
    double hipX = 0,
    bool shiftRight = true,
  }) {
    final original = pose();
    final shoulder = original[BodyLandmark.rightShoulder]!;
    final other = original[BodyLandmark.leftShoulder]!;
    final width = math.sqrt(
      math.pow(shoulder.x - other.x, 2) + math.pow(shoulder.y - other.y, 2),
    );
    return PoseFrame(
      imageWidth: original.imageWidth,
      imageHeight: original.imageHeight,
      keypoints: {
        for (final entry in original.keypoints.entries)
          entry.key: Keypoint(
            landmark: entry.key,
            x:
                entry.value.x +
                ((entry.key == BodyLandmark.leftHip ||
                        (shiftRight && entry.key == BodyLandmark.rightHip))
                    ? hipX * width
                    : 0),
            y:
                entry.value.y +
                ((entry.key == BodyLandmark.leftKnee ||
                        (shiftRight && entry.key == BodyLandmark.rightKnee))
                    ? kneeY * width
                    : 0),
            likelihood: 1,
          ),
      },
    );
  }

  KneeContactTracker calibrated({
    double rotation = 0,
    bool mirror = false,
    double scale = 1,
  }) {
    final tracker = KneeContactTracker();
    capture(tracker, pose(rotation: rotation, mirror: mirror, scale: scale), 0);
    expect(tracker.calibrate(KneeContactState.lifted), isTrue);
    capture(
      tracker,
      pose(
        leftTouching: true,
        rightTouching: true,
        rotation: rotation,
        mirror: mirror,
        scale: scale,
      ),
      2000,
    );
    expect(tracker.calibrate(KneeContactState.touching), isTrue);
    tracker.reset();
    return tracker;
  }

  group('live knee contact diagnostic', () {
    test('stays unknown until both user-labelled references exist', () {
      final tracker = KneeContactTracker();
      capture(tracker, pose(), 0);
      expect(tracker.calibrate(KneeContactState.lifted), isTrue);
      expect(tracker.hasLiftedReference, isTrue);
      expect(tracker.hasTouchingReference, isFalse);
      final waiting = settle(tracker, pose(), start: 1000);
      expect(waiting.state, KneeContactState.unknown);
      expect(waiting.left.issue, KneeContactIssue.missingReference);
      expect(waiting.right.issue, KneeContactIssue.missingReference);
    });

    test(
      'short and missing captures fail while identical poses save as ambiguous',
      () {
        final tracker = KneeContactTracker();
        expect(tracker.calibrate(KneeContactState.unknown), isFalse);
        expect(
          tracker.lastCalibrationIssue,
          KneeCalibrationIssue.invalidTarget,
        );
        expect(tracker.calibrate(KneeContactState.lifted), isFalse);
        expect(
          tracker.lastCalibrationIssue,
          KneeCalibrationIssue.noVisiblePose,
        );
        settle(tracker, pose());
        expect(tracker.calibrate(KneeContactState.lifted), isFalse);
        expect(
          tracker.lastCalibrationIssue,
          KneeCalibrationIssue.insufficientSamples,
        );
        capture(tracker, pose(), 500);
        expect(tracker.calibrate(KneeContactState.lifted), isTrue);
        expect(tracker.lastCalibrationIssue, KneeCalibrationIssue.none);
        capture(tracker, pose(), 1500);
        expect(tracker.calibrate(KneeContactState.touching), isTrue);
        expect(tracker.lastCalibrationIssue, KneeCalibrationIssue.none);
        expect(tracker.hasLiftedReference, isTrue);
        expect(tracker.hasTouchingReference, isTrue);
        expect(tracker.hasSeparableReferences, isFalse);
        final ambiguous = settle(tracker, pose(), start: 2400);
        expect(ambiguous.state, KneeContactState.unknown);
        expect(ambiguous.left.issue, KneeContactIssue.ambiguous);
        tracker.update(
          pose(hide: {BodyLandmark.leftKnee}),
          const Duration(milliseconds: 2800),
        );
        expect(tracker.calibrate(KneeContactState.touching), isFalse);
        expect(
          tracker.lastCalibrationIssue,
          KneeCalibrationIssue.noVisiblePose,
        );
      },
    );

    test('small consistent knee displacement is classified despite orthogonal jitter', () {
      final tracker = KneeContactTracker();
      for (final (target, displacement, start) in [
        (KneeContactState.lifted, 0.0, 0),
        (KneeContactState.touching, .06, 2000),
      ]) {
        for (var i = 0; i < 5; i++) {
          tracker.update(
            shiftedPose(kneeY: displacement, hipX: (i - 2) * .08),
            Duration(milliseconds: start + i * 200),
          );
        }
        expect(tracker.calibrate(target), isTrue);
      }
      expect(tracker.hasSeparableReferences, isTrue);
      expect(
        settle(tracker, shiftedPose(), start: 3000).state,
        KneeContactState.lifted,
      );
      expect(
        settle(tracker, shiftedPose(kneeY: .06), start: 3500).state,
        KneeContactState.touching,
      );
      final midpoint = settle(tracker, shiftedPose(kneeY: .03), start: 4000);
      expect(midpoint.state, KneeContactState.unknown);
      expect(midpoint.left.issue, KneeContactIssue.ambiguous);
    });

    test(
      'capture noise along the small knee change prevents false confidence',
      () {
        final tracker = KneeContactTracker();
        for (final (target, displacement, start) in [
          (KneeContactState.lifted, 0.0, 0),
          (KneeContactState.touching, .06, 2000),
        ]) {
          for (var i = 0; i < 5; i++) {
            tracker.update(
              shiftedPose(kneeY: displacement + (i - 2) * .03),
              Duration(milliseconds: start + i * 200),
            );
          }
          expect(tracker.calibrate(target), isTrue);
        }
        expect(tracker.hasSeparableReferences, isFalse);
        final result = settle(tracker, shiftedPose(kneeY: .06), start: 3000);
        expect(result.state, KneeContactState.unknown);
        expect(result.left.issue, KneeContactIssue.ambiguous);
      },
    );

    test('one inseparable side does not block the other side calibration', () {
      final tracker = KneeContactTracker();
      capture(tracker, shiftedPose(), 0);
      expect(tracker.calibrate(KneeContactState.lifted), isTrue);
      capture(tracker, shiftedPose(kneeY: .08, shiftRight: false), 2000);
      expect(tracker.calibrate(KneeContactState.touching), isTrue);
      expect(tracker.hasSeparableReferences, isTrue);
      final down = settle(
        tracker,
        shiftedPose(kneeY: .08, shiftRight: false),
        start: 3000,
      );
      expect(down.left.state, KneeContactState.touching);
      expect(down.right.state, KneeContactState.unknown);
      expect(down.state, KneeContactState.touching);
      final up = settle(tracker, shiftedPose(), start: 3500);
      expect(up.left.state, KneeContactState.lifted);
      expect(up.right.state, KneeContactState.unknown);
      expect(up.state, KneeContactState.unknown);
    });

    test('the full directional noise margin remains ambiguous', () {
      final tracker = KneeContactTracker();
      for (final (target, displacement, start) in [
        (KneeContactState.lifted, 0.0, 0),
        (KneeContactState.touching, .15, 2000),
      ]) {
        for (var i = 0; i < 5; i++) {
          tracker.update(
            shiftedPose(kneeY: displacement + (i - 2) * .02),
            Duration(milliseconds: start + i * 200),
          );
        }
        expect(tracker.calibrate(target), isTrue);
      }
      expect(tracker.hasSeparableReferences, isTrue);
      final uncertain = settle(tracker, shiftedPose(kneeY: .12), start: 3000);
      expect(uncertain.state, KneeContactState.unknown);
      expect(uncertain.left.issue, KneeContactIssue.ambiguous);
      expect(
        settle(tracker, shiftedPose(kneeY: .15), start: 3500).state,
        KneeContactState.touching,
      );
    });

    test('unstable capture preserves existing references', () {
      final tracker = calibrated();
      for (var i = 0; i < 5; i++) {
        tracker.update(
          pose(leftTouching: i.isEven, rightTouching: i.isEven),
          Duration(milliseconds: i * 200),
        );
      }
      expect(tracker.calibrate(KneeContactState.touching), isFalse);
      expect(tracker.lastCalibrationIssue, KneeCalibrationIssue.unstable);
      expect(tracker.hasLiftedReference, isTrue);
      expect(tracker.hasTouchingReference, isTrue);
    });

    test(
      'reset keeps references but calibration reset and size change clear them',
      () {
        final tracker = calibrated();
        tracker.reset();
        expect(tracker.hasTouchingReference, isTrue);
        expect(tracker.hasLiftedReference, isTrue);
        tracker.update(
          PoseFrame(
            imageWidth: 1400,
            imageHeight: 1000,
            keypoints: pose().keypoints,
          ),
          Duration.zero,
        );
        expect(tracker.hasTouchingReference, isFalse);
        expect(tracker.hasLiftedReference, isFalse);
        final another = calibrated();
        another.resetCalibration();
        expect(another.hasLiftedReference, isFalse);
        expect(another.hasTouchingReference, isFalse);
      },
    );

    test('midpoint and distant poses stay unknown after calibration', () {
      final up = pose(), down = pose(leftTouching: true, rightTouching: true);
      PoseFrame blend(double amount) => PoseFrame(
        imageWidth: 1200,
        imageHeight: 1000,
        keypoints: {
          for (final key in up.keypoints.keys)
            key: Keypoint(
              landmark: key,
              x: up[key]!.x + amount * (down[key]!.x - up[key]!.x),
              y: up[key]!.y + amount * (down[key]!.y - up[key]!.y),
              likelihood: 1,
            ),
        },
      );
      final midpoint = settle(calibrated(), blend(.5));
      final distant = settle(calibrated(), blend(3));
      expect(midpoint.state, KneeContactState.unknown);
      expect(midpoint.left.issue, KneeContactIssue.ambiguous);
      expect(distant.state, KneeContactState.unknown);
      expect(distant.left.issue, KneeContactIssue.outsideReference);
    });

    test('requires stable evidence and reports both lifted knees', () {
      final tracker = calibrated();
      final frame = pose();
      final initial = tracker.update(frame, Duration.zero);
      expect(initial.state, KneeContactState.unknown);
      expect(initial.left.issue, KneeContactIssue.stabilizing);
      expect(
        tracker.update(frame, const Duration(milliseconds: 125)).state,
        KneeContactState.unknown,
      );
      final result = tracker.update(frame, const Duration(milliseconds: 250));
      expect(result.state, KneeContactState.lifted);
      expect(result.left.issue, KneeContactIssue.none);
      expect(result.right.issue, KneeContactIssue.none);
      expect(result.left.clearance, closeTo(.09375, 1e-8));
      expect(result.left.kneeAngle, greaterThan(155));
    });

    test('one bent knee near support line is enough to suggest touching', () {
      final result = settle(calibrated(), pose(leftTouching: true));
      expect(result.state, KneeContactState.touching);
      expect(result.left.state, KneeContactState.touching);
      expect(result.right.state, KneeContactState.lifted);
      expect(result.left.clearance, closeTo(.0125, 1e-8));
    });

    test('new state waits for stability without retaining the old verdict', () {
      final tracker = calibrated();
      settle(tracker, pose());
      final contact = pose(leftTouching: true, rightTouching: true);
      expect(
        tracker.update(contact, const Duration(milliseconds: 300)).state,
        KneeContactState.unknown,
      );
      expect(
        settle(tracker, contact, start: 300).state,
        KneeContactState.touching,
      );
    });

    test('missing and low-confidence knees immediately become unknown', () {
      final tracker = calibrated();
      settle(tracker, pose());
      final partial = pose(hide: {BodyLandmark.leftKnee});
      final result = tracker.update(partial, const Duration(milliseconds: 300));
      expect(result.left.state, KneeContactState.unknown);
      expect(result.left.issue, KneeContactIssue.missingJoints);
      expect(result.left.missingJoints, [BodyLandmark.leftKnee]);
      expect(result.right.missingJoints, isEmpty);
      expect(result.left.clearance, isNull);
      expect(result.state, KneeContactState.unknown);
      expect(
        settle(calibrated(), pose(likelihood: .64)).state,
        KneeContactState.unknown,
      );
    });

    test('missing joints are explained before unsaved references', () {
      final tracker = KneeContactTracker();
      final result = tracker.update(
        pose(hide: {BodyLandmark.leftKnee, BodyLandmark.leftAnkle}),
        Duration.zero,
      );
      expect(result.left.issue, KneeContactIssue.missingJoints);
      expect(result.left.missingJoints, [
        BodyLandmark.leftKnee,
        BodyLandmark.leftAnkle,
      ]);
      expect(result.right.issue, KneeContactIssue.missingReference);
    });

    test('reference reset clears the previous calibration failure', () {
      final tracker = KneeContactTracker();
      expect(tracker.calibrate(KneeContactState.lifted), isFalse);
      expect(tracker.lastCalibrationIssue, KneeCalibrationIssue.noVisiblePose);
      tracker.resetCalibration();
      expect(tracker.lastCalibrationIssue, KneeCalibrationIssue.none);
    });

    test(
      'rotation, mirroring and reasonable scale preserve projected geometry',
      () {
        for (final mirror in [false, true]) {
          for (final rotation in [-.4, .4]) {
            final result = settle(
              calibrated(rotation: rotation, mirror: mirror, scale: .5),
              pose(
                leftTouching: true,
                rotation: rotation,
                mirror: mirror,
                scale: .5,
              ),
            );
            expect(result.left.state, KneeContactState.touching);
            expect(result.right.state, KneeContactState.lifted);
            expect(result.left.clearance, closeTo(.0125, 1e-8));
          }
        }
      },
    );

    test('unsupported body size and standing geometry remain unknown', () {
      expect(
        settle(calibrated(), pose(scale: .01)).state,
        KneeContactState.unknown,
      );
      final standing = pose();
      final points = <BodyLandmark, Keypoint>{
        for (final entry in standing.keypoints.entries)
          entry.key: Keypoint(
            landmark: entry.key,
            x: 600,
            y: entry.value.y,
            likelihood: 1,
          ),
      };
      expect(
        settle(
          calibrated(),
          PoseFrame(imageWidth: 1200, imageHeight: 1000, keypoints: points),
        ).state,
        KneeContactState.unknown,
      );
    });

    test('invalid coordinates and degenerate legs do not emit contact', () {
      final frame = pose(leftTouching: true, rightTouching: true);
      for (final invalid in [double.nan, double.infinity, -1.0, 1400.0]) {
        final points = Map<BodyLandmark, Keypoint>.of(frame.keypoints);
        for (final knee in [BodyLandmark.leftKnee, BodyLandmark.rightKnee]) {
          points[knee] = Keypoint(
            landmark: knee,
            x: invalid,
            y: 690,
            likelihood: 1,
          );
        }
        expect(
          settle(
            calibrated(),
            PoseFrame(imageWidth: 1200, imageHeight: 1000, keypoints: points),
          ).state,
          KneeContactState.unknown,
        );
      }
      final points = Map<BodyLandmark, Keypoint>.of(frame.keypoints);
      for (final left in [true, false]) {
        final knee = left ? BodyLandmark.leftKnee : BodyLandmark.rightKnee;
        final ankle =
            frame[left ? BodyLandmark.leftAnkle : BodyLandmark.rightAnkle]!;
        points[knee] = Keypoint(
          landmark: knee,
          x: ankle.x,
          y: ankle.y,
          likelihood: 1,
        );
      }
      expect(
        settle(
          calibrated(),
          PoseFrame(imageWidth: 1200, imageHeight: 1000, keypoints: points),
        ).state,
        KneeContactState.unknown,
      );
    });

    test('empty frames and invalid image dimensions are unknown', () {
      expect(
        settle(
          calibrated(),
          const PoseFrame.empty(imageWidth: 1000, imageHeight: 1000),
        ).state,
        KneeContactState.unknown,
      );
      expect(
        settle(
          calibrated(),
          PoseFrame(
            imageWidth: double.nan,
            imageHeight: 1000,
            keypoints: pose().keypoints,
          ),
        ).state,
        KneeContactState.unknown,
      );
    });

    test('long gaps, backward clock and reset require fresh stability', () {
      final tracker = calibrated();
      final frame = pose();
      settle(tracker, frame);
      expect(
        tracker.update(frame, const Duration(seconds: 2)).state,
        KneeContactState.unknown,
      );
      settle(tracker, frame, start: 2000);
      expect(
        tracker.update(frame, const Duration(milliseconds: 500)).state,
        KneeContactState.unknown,
      );
      settle(tracker, frame, start: 500);
      tracker.reset();
      expect(
        tracker.update(frame, const Duration(milliseconds: 800)).state,
        KneeContactState.unknown,
      );
    });

    test('repeated timestamps cannot supply three independent samples', () {
      final tracker = calibrated();
      final frame = pose();
      tracker.update(frame, Duration.zero);
      for (var i = 0; i < 10; i++) {
        expect(
          tracker.update(frame, const Duration(milliseconds: 300)).state,
          KneeContactState.unknown,
        );
      }
      expect(
        tracker.update(frame, const Duration(milliseconds: 350)).state,
        KneeContactState.lifted,
      );
    });
  });
}

void _mlpFeatureTests() {
  test('knee specialist reproduces fixed exported network probabilities', () {
    final zeros = List<double>.filled(466, 0);
    expect(PushupKneeModel.probability(zeros), closeTo(.009177181, .000001));
    expect(PushupKneeModel.rejects(zeros), isFalse);
    final values = List.generate(466, (i) => math.sin(i / 7));
    expect(PushupKneeModel.probability(values), closeTo(.23005128, .000001));
    // Numeric port fixture, independent of whether a motion is proposed.
    final missing = <double>[...List.filled(434, -7), ...List.filled(32, 0)];
    expect(PushupKneeModel.probability(missing), closeTo(.9859802, .000001));
    expect(PushupKneeModel.rejects(missing), isTrue);
    expect(PushupKneeModel.threshold, .9204565286636353);
    expect(() => PushupKneeModel.probability([1, 2]), throwsArgumentError);
  });

  test('both classifiers share one proposal window and advance it once', () {
    final history = PushupMlpHistory();
    history.add(pushUpFrame(), Duration.zero);
    history.add(pushUpFrame(depth: .8), const Duration(milliseconds: 100));
    final features = history.featuresAt(const Duration(milliseconds: 100));
    final proposal = history.featuresForProposal(
      const Duration(milliseconds: 100),
    );
    expect(proposal, orderedEquals(features));
    expect(PushupMlpModel.normalProbability(proposal), inInclusiveRange(0, 1));
    expect(PushupKneeModel.probability(proposal), inInclusiveRange(0, 1));
    history.add(pushUpFrame(), const Duration(milliseconds: 200));
    expect(history.featuresAt(const Duration(milliseconds: 200))[465], 0);
    history.reset();
    history.add(pushUpFrame(), Duration.zero);
    history.add(pushUpFrame(), const Duration(milliseconds: 100));
    expect(
      history.featuresForProposal(const Duration(milliseconds: 100))[465],
      closeTo(.1, .000001),
    );
  });

  test('embedded MLP reproduces fixed positive and negative Python logits', () {
    expect(
      PushupMlpModel.normalProbability(List.filled(466, 0)),
      closeTo(.86749303, .00001),
    );
    final values = List.generate(466, (i) => math.sin(i / 7));
    expect(
      PushupMlpModel.normalProbability(values),
      closeTo(.38164642, .00001),
    );
    expect(() => PushupMlpModel.normalProbability([1, 2]), throwsArgumentError);
  });

  test(
    'MLP windows use only the trailing time since the previous proposal',
    () {
      final history = PushupMlpHistory();
      for (var i = 0; i <= 20; i++) {
        history.add(
          pushUpFrame(depth: (i % 5) / 5),
          Duration(milliseconds: i * 100),
        );
      }
      final prior = history.featuresAt(const Duration(seconds: 2));
      expect(prior.length, 466);
      expect(prior[465], closeTo(1.6, .000001));
      expect(
        history.classifyAt(const Duration(seconds: 2)),
        inInclusiveRange(0, 1),
      );
      history.add(pushUpFrame(), const Duration(milliseconds: 2100));
      expect(history.featuresAt(const Duration(milliseconds: 2100))[465], 0);
      history.reset();
      history.add(pushUpFrame(), Duration.zero);
      history.add(pushUpFrame(), const Duration(milliseconds: 100));
      expect(
        history.featuresAt(const Duration(milliseconds: 100))[465],
        closeTo(.1, .000001),
      );
    },
  );

  test('MLP ignores nonfinite joints and resets on a backward clock', () {
    final history = PushupMlpHistory();
    final base = pushUpFrame();
    final poisoned = PoseFrame(
      imageWidth: 800,
      imageHeight: 600,
      keypoints: {
        for (final p in base.keypoints.values)
          p.landmark: Keypoint(
            landmark: p.landmark,
            x: p.x,
            y: p.y,
            likelihood: double.nan,
          ),
      },
    );
    history.add(poisoned, const Duration(seconds: 3));
    final empty = history.featuresAt(const Duration(seconds: 3));
    expect(empty.take(434), everyElement(-7));
    expect(empty.skip(434), everyElement(0));
    history.add(base, Duration.zero);
    final recovered = history.featuresAt(Duration.zero);
    expect(recovered.every((v) => v.isFinite), isTrue);
    expect(recovered[465], 0);
    expect(recovered.skip(434).take(31).any((v) => v > 0), isTrue);
  });
}

void _spanCycleTests() {
  test('primary calibration preserves measured scores and protected rejection reasons', () {
    final values = List<double?>.filled(96, null);
    void set(PushupSpanSignal signal, PushupSpanStat stat, double value) =>
        values[signal.index * 6 + stat.index] = value;
    set(PushupSpanSignal.elbow, PushupSpanStat.low, 110);
    set(PushupSpanSignal.elbow, PushupSpanStat.high, 172);
    set(PushupSpanSignal.elbow, PushupSpanStat.bottom, 100);
    set(PushupSpanSignal.weakerElbow, PushupSpanStat.high, 170);
    set(PushupSpanSignal.weakerElbow, PushupSpanStat.finish, 174);
    set(PushupSpanSignal.handShoulderY, PushupSpanStat.high, .8);
    set(PushupSpanSignal.handShoulderY, PushupSpanStat.low, .3);
    set(PushupSpanSignal.handShoulderY, PushupSpanStat.bottom, .4);
    set(PushupSpanSignal.hipShoulderY, PushupSpanStat.middle, .2);
    const prior = RepEvent(
      index: 7,
      valid: false,
      at: Duration(seconds: 9),
      reason: RejectReason.insufficientDepth,
      maxDepth: .48,
      minElbowAngle: 96,
      maxTilt: 8,
      descent: Duration(milliseconds: 420),
    );
    for (final short in [168.0, 171.9]) {
      set(PushupSpanSignal.weakerElbow, PushupSpanStat.finish, short);
      expect(
        calibratePushupPrimary(prior, values, observedReturn: true),
        same(prior),
      );
      const incomplete = RepEvent(
        index: 1,
        valid: false,
        at: Duration.zero,
        reason: RejectReason.incompleteExtension,
      );
      expect(
        calibratePushupPrimary(incomplete, values, observedReturn: true),
        same(incomplete),
      );
    }
    set(PushupSpanSignal.weakerElbow, PushupSpanStat.finish, 171);
    expect(
      calibratePushupPrimary(
        prior,
        values,
        observedReturn: true,
        lockoutAngle: 170,
      ).valid,
      isTrue,
    );
    expect(
      calibratePushupPrimary(
        prior,
        values,
        observedReturn: true,
        lockoutAngle: 0,
      ).valid,
      isTrue,
    );
    set(PushupSpanSignal.weakerElbow, PushupSpanStat.finish, 174);
    final valid = calibratePushupPrimary(prior, values, observedReturn: true);
    expect(valid.valid, isTrue);
    expect(valid.reason, isNull);
    expect(valid.index, prior.index);
    expect(valid.at, prior.at);
    expect(valid.maxDepth, prior.maxDepth);
    expect(valid.minElbowAngle, prior.minElbowAngle);
    expect(valid.maxTilt, prior.maxTilt);
    expect(valid.descent, prior.descent);
    expect(
      calibratePushupPrimary(prior, values, observedReturn: false),
      same(prior),
    );
    for (final reason in [
      RejectReason.kneesDown,
      RejectReason.bellyDown,
      RejectReason.notFloorPushUp,
      RejectReason.phoneMoved,
      RejectReason.armsStraight,
    ]) {
      final rejected = RepEvent(
        index: 8,
        valid: false,
        at: Duration.zero,
        reason: reason,
      );
      expect(
        calibratePushupPrimary(rejected, values, observedReturn: true),
        same(rejected),
      );
    }
    set(PushupSpanSignal.elbow, PushupSpanStat.bottom, 150);
    set(PushupSpanSignal.weakerElbow, PushupSpanStat.start, 170);
    set(PushupSpanSignal.wristWidth, PushupSpanStat.finish, 1);
    set(PushupSpanSignal.shoulderWidth, PushupSpanStat.finish, 1);
    set(PushupSpanSignal.shoulderWidth, PushupSpanStat.middle, .6);
    set(PushupSpanSignal.hipShoulderX, PushupSpanStat.high, .3);
    set(PushupSpanSignal.shoulderTilt, PushupSpanStat.high, 18);
    final rejected = calibratePushupPrimary(
      valid,
      values,
      observedReturn: false,
    );
    expect(rejected.valid, isFalse);
    expect(rejected.reason, RejectReason.shouldersNotLevel);
    expect(rejected.index, valid.index);
  });

  PoseFrame arms(double reach, {double shift = 0, bool hidden = false}) {
    final points = <BodyLandmark, Keypoint>{};
    void add(BodyLandmark key, double x, double y) {
      points[key] = Keypoint(
        landmark: key,
        x: x + shift,
        y: y + shift,
        likelihood: hidden && key == BodyLandmark.leftWrist ? .2 : 1,
      );
    }

    final y = 320 - reach;
    // Two 50px bones: bending shortens the reach without shrinking the arm.
    final bend = math.sqrt(2500 - reach * reach / 4);
    add(BodyLandmark.leftShoulder, 160, y);
    add(BodyLandmark.rightShoulder, 260, y);
    add(BodyLandmark.leftWrist, 160, 320);
    add(BodyLandmark.rightWrist, 260, 320);
    add(BodyLandmark.leftElbow, 160 - bend, (y + 320) / 2);
    add(BodyLandmark.rightElbow, 260 + bend, (y + 320) / 2);
    return PoseFrame(imageWidth: 480, imageHeight: 640, keypoints: points);
  }

  test(
    'span detector preserves slow full cycles and a noisy 70-degree boundary',
    () {
      for (final initialAngle in [60.0, 80.0]) {
        final detector = PushupSpanDetector();
        final cycles = <PushupSpanCycle>[];
        for (var i = 0; i <= 150; i++) {
          final phase = ((i - 10) / 60).clamp(0.0, 2.0);
          final reach = 92 - 38 * (1 - (phase - 1).abs());
          final angle = i == 0
              ? initialAngle
              : i.isEven
              ? 69.0
              : 71.0;
          final event = detector.update(
            arms(reach),
            Duration(milliseconds: i * 20),
            phoneAngleDegrees: angle,
          );
          if (event != null) cycles.add(event);
        }
        expect(cycles, hasLength(1));
        expect(cycles.single.start < cycles.single.bottom, isTrue);
        expect(cycles.single.bottom < cycles.single.end, isTrue);
      }
    },
  );

  test(
    'normal promotion requires a bilateral descent and current visible return',
    () {
      final history = PushupSpanHistory();
      var last = arms(99.5);
      const times = [0, 100, 200, 300, 400, 500, 600];
      const reaches = [99.5, 99.5, 72.0, 45.0, 72.0, 99.5, 99.5];
      for (var i = 0; i < times.length; i++) {
        last = arms(reaches[i]);
        history.add(last, Duration(milliseconds: times[i]));
      }
      const end = Duration(milliseconds: 600);
      expect(history.observedReturn(last, Duration.zero, end), isTrue);
      final hidden = arms(99.5, hidden: true);
      history.add(hidden, const Duration(milliseconds: 650));
      expect(
        history.observedReturn(
          hidden,
          Duration.zero,
          const Duration(milliseconds: 650),
        ),
        isFalse,
      );
      history.reset();
      for (var i = 0; i <= 8; i++) {
        final frame = arms(99.5 - i * 6);
        history.add(frame, Duration(milliseconds: i * 50));
        last = frame;
      }
      expect(
        history.observedReturn(
          last,
          Duration.zero,
          const Duration(milliseconds: 400),
        ),
        isFalse,
      );
    },
  );

  test(
    'a prior completed cycle cannot validate a later straight-arm body bob',
    () {
      final history = PushupSpanHistory();
      final sequence = <PoseFrame>[
        arms(99.5),
        arms(99.5),
        arms(72),
        arms(45),
        arms(72),
        arms(99.5),
        arms(99.5),
        arms(99.5, shift: 3),
        arms(99.5, shift: 6),
        arms(99.5, shift: 9),
        arms(99.5, shift: 12),
        arms(99.5, shift: 9),
        arms(99.5, shift: 6),
        arms(99.5, shift: 3),
        arms(99.5),
      ];
      for (var i = 0; i < sequence.length; i++) {
        history.add(sequence[i], Duration(milliseconds: i * 60));
      }
      expect(
        history.observedReturn(
          sequence.last,
          Duration.zero,
          Duration(milliseconds: (sequence.length - 1) * 60),
        ),
        isFalse,
      );
    },
  );

  test('translating all joints together and occluding one wrist cannot create a cycle', () {
    final detector = PushupSpanDetector();
    for (var i = 0; i < 70; i++) {
      expect(
        detector.update(
          arms(92, shift: 50 * math.sin(i / 10)),
          Duration(milliseconds: i * 30),
        ),
        isNull,
      );
    }
    detector.reset();
    for (var i = 0; i < 70; i++) {
      final down = i > 15 && i < 43;
      expect(
        detector.update(
          arms(down ? 45 : 92, hidden: down),
          Duration(milliseconds: i * 30),
        ),
        isNull,
      );
    }
  });

  test('a real phone angle change starts a new span attempt', () {
    final detector = PushupSpanDetector();
    for (var i = 0; i < 24; i++) {
      final down = i >= 4 && i <= 17;
      expect(
        detector.update(
          arms(down ? 48 : 92),
          Duration(milliseconds: i * 50),
          phoneAngleDegrees: i < 12 ? 60 : 80,
        ),
        isNull,
      );
    }
    expect(detector.band, PushupPhoneBand.near80);
  });

  test(
    'an overlapping primary event wins through the configured delivery grace',
    () {
      const zero = Duration.zero,
          mid = Duration(milliseconds: 300),
          end = Duration(milliseconds: 700);
      const cycle = PushupSpanCycle(zero, mid, end);
      final arbiter = PushupSpanArbiter(
        grace: const Duration(milliseconds: 200),
      );
      expect(
        arbiter.update(
          end,
          primaryEvent: false,
          cycle: cycle,
          reason: RejectReason.kneesDown,
        ),
        isNull,
      );
      expect(
        arbiter.update(const Duration(milliseconds: 850), primaryEvent: true),
        isNull,
      );
      expect(
        arbiter.update(const Duration(milliseconds: 900), primaryEvent: false),
        isNull,
      );
      arbiter.reset();
      arbiter.update(
        end,
        primaryEvent: false,
        cycle: cycle,
        reason: RejectReason.kneesDown,
      );
      final emission = arbiter.update(
        const Duration(milliseconds: 900),
        primaryEvent: false,
      );
      expect(emission?.cycle, same(cycle));
      expect(emission?.reason, RejectReason.kneesDown);
      expect(
        arbiter.update(const Duration(milliseconds: 915), primaryEvent: false),
        isNull,
      );
    },
  );

  test('span feedback defers to an open primary cycle and expires across a camera gap', () {
    final arbiter = PushupSpanArbiter();
    const cycle = PushupSpanCycle(
      Duration(milliseconds: 200),
      Duration(milliseconds: 450),
      Duration(milliseconds: 750),
    );
    expect(
      arbiter.update(
        cycle.end,
        primaryEvent: false,
        cycle: cycle,
        reason: RejectReason.incompleteExtension,
        primaryAttemptStarted: cycle.bottom,
      ),
      isNull,
    );
    expect(
      arbiter.update(
        const Duration(milliseconds: 1700),
        primaryEvent: false,
        cycle: cycle,
        reason: RejectReason.incompleteExtension,
      ),
      isNull,
    );
  });
}

void _spanEvidenceTests() {
  const start = Duration.zero;
  const bottom = Duration(milliseconds: 240);
  const end = Duration(milliseconds: 480);
  PushupSpanHistory track(PoseFrame Function(PoseFrame) transform) {
    final h = PushupSpanHistory();
    for (var i = 0; i <= 8; i++) {
      final down = (4 - (4 - i).abs()) / 4;
      final pose = pushUpFrame(depth: .55 * down, elbowAngle: 170 - 70 * down);
      h.add(transform(pose), Duration(milliseconds: i * 60));
    }
    return h;
  }

  test(
    'span evidence is mirror invariant and only screen y spans depend on pitch',
    () {
      final h = track((f) => f);
      final mirroredHistory = track((f) {
        final flipped = mirrored(f);
        return PoseFrame(
          imageWidth: flipped.imageWidth,
          imageHeight: flipped.imageHeight,
          keypoints: {
            for (final entry in flipped.keypoints.entries)
              entry.key: kp(
                entry.key,
                entry.value.x * .8 + 27,
                entry.value.y * .8 - 14,
                likelihood: entry.value.likelihood,
              ),
          },
        );
      });
      List<double?> values(PushupSpanHistory history, double? angle) =>
          history.evidence(
            start: start,
            bottom: bottom,
            end: end,
            phoneAngleDegrees: angle,
          )!;
      final unknown = values(h, null),
          lower = values(h, 60),
          upright = values(h, 80);
      final reflected = values(mirroredHistory, 60);
      for (var i = 0; i < lower.length; i++) {
        if (lower[i] == null) {
          expect(reflected[i], isNull);
        } else {
          expect(reflected[i], closeTo(lower[i]!, 1e-6));
        }
      }
      int bottomOf(PushupSpanSignal s) =>
          s.index * PushupSpanStat.values.length + PushupSpanStat.bottom.index;
      final y = bottomOf(PushupSpanSignal.handShoulderY);
      expect(lower[y], closeTo(unknown[y]! / math.sin(math.pi / 3), 1e-8));
      expect(
        upright[y],
        closeTo(unknown[y]! / math.sin(math.pi * 80 / 180), 1e-8),
      );
      for (final s in [
        PushupSpanSignal.elbow,
        PushupSpanSignal.handShoulderX,
        PushupSpanSignal.wristWidth,
      ]) {
        expect(lower[bottomOf(s)], unknown[bottomOf(s)]);
      }
    },
  );
  test(
    'the learned partial-cycle leaf requires visible arm and shoulder travel',
    () {
      final seen = PushupSpanHistory();
      final hidden = PushupSpanHistory();
      for (var i = 0; i <= 8; i++) {
        final progress = (4 - (4 - i).abs()) / 4;
        final angle = 153 - 60 * progress;
        final time = Duration(milliseconds: i * 60);
        seen.add(pushUpFrame(depth: .35 * progress, elbowAngle: angle), time);
        hidden.add(
          pushUpFrame(
            depth: .35 * progress,
            elbowAngle: angle,
            hide: {BodyLandmark.leftWrist, BodyLandmark.rightWrist},
          ),
          time,
        );
      }
      expect(
        seen.reasonFor(start: start, bottom: bottom, end: end),
        RejectReason.insufficientDepth,
      );
      expect(hidden.reasonFor(start: start, bottom: bottom, end: end), isNull);
    },
  );
  test(
    'unsupported joints, stale samples and prior cycles do not supply feedback',
    () {
      const empty = PoseFrame.empty(imageWidth: 480, imageHeight: 640);
      final h = track((_) => empty);
      expect(h.reasonFor(start: start, bottom: bottom, end: end), isNull);
      h.add(empty, const Duration(seconds: 2));
      expect(h.evidence(start: start, bottom: bottom, end: end), isNull);
      h.reset();
      expect(h.evidence(start: start, bottom: bottom, end: end), isNull);
    },
  );
}
