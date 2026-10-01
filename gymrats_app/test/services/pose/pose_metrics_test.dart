import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/pose_metrics.dart';

import '../../support/pose_fixtures.dart';

void main() {
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
}
