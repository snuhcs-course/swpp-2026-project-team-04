import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/setup_silhouette_alignment.dart';

void main() {
  const matcher = SetupSilhouetteAlignment();
  PoseFrame pose({
    double dx = 0,
    bool missingHand = false,
    double noseY = 140,
    double leftShoulderX = 360,
    double leftHandX = 200,
  }) {
    final points = <BodyLandmark, Offset>{
      BodyLandmark.nose: Offset(500 + dx, noseY),
      BodyLandmark.leftShoulder: Offset(leftShoulderX + dx, 270),
      BodyLandmark.rightShoulder: Offset(640 + dx, 270),
      BodyLandmark.leftWrist: Offset(leftHandX + dx, 850),
      BodyLandmark.rightWrist: Offset(800 + dx, 850),
    };
    if (missingHand) points.remove(BodyLandmark.leftWrist);
    return PoseFrame(
      imageWidth: 1000,
      imageHeight: 1000,
      keypoints: {
        for (final e in points.entries)
          e.key: Keypoint(
            landmark: e.key,
            x: e.value.dx,
            y: e.value.dy,
            likelihood: .95,
          ),
      },
    );
  }

  test('aligned points fit the guide in normal and mirrored previews', () {
    expect(
      matcher.matches(pose(), const Size(1000, 1000), mirror: false),
      isTrue,
    );
    expect(
      matcher.matches(pose(), const Size(1000, 1000), mirror: true),
      isTrue,
    );
  });

  test('an off-guide body or missing hand cannot pass', () {
    expect(
      matcher.matches(pose(dx: 250), const Size(1000, 1000), mirror: false),
      isFalse,
    );
    expect(
      matcher.matches(
        pose(missingHand: true),
        const Size(1000, 1000),
        mirror: false,
      ),
      isFalse,
    );
  });

  test('one misplaced hand cannot be cancelled by the other joints', () {
    expect(
      matcher.matches(
        pose(leftHandX: 480),
        const Size(1000, 1000),
        mirror: false,
      ),
      isFalse,
    );
  });

  test('every push-up landmark region is required independently', () {
    const viewport = Size(1000, 1000);
    for (final outside in [
      pose(noseY: 300),
      pose(leftShoulderX: 190),
      pose(leftHandX: 350),
      // This wrist lies inside the former hand box, in the shaded armpit gap.
      pose(leftHandX: 320),
    ]) {
      expect(matcher.matches(outside, viewport, mirror: false), isFalse);
      expect(matcher.matches(outside, viewport, mirror: true), isFalse);
    }
    expect(
      matcher.matches(
        pose(leftHandX: 250, leftShoulderX: 440),
        viewport,
        mirror: false,
      ),
      isTrue,
    );
  });

  test('uses the visible crop rather than raw full-frame coordinates', () {
    expect(
      matcher.matches(pose(), const Size(1000, 500), mirror: false),
      isFalse,
    );
    expect(matcher.matches(pose(), Size.zero, mirror: false), isFalse);
    expect(
      matcher.matches(pose(), const Size(double.infinity, 500), mirror: false),
      isFalse,
    );
  });

  test('rejects a wrist inside the artwork but clipped by the camera box', () {
    final frame = pose(leftHandX: 180);
    const full = Size(1, 1);
    for (final mirror in [false, true]) {
      expect(
        matcher.matchesImageCrop(frame, (
          guide: full,
          visible: full,
        ), mirror: mirror),
        isTrue,
      );
      expect(
        matcher.matchesImageCrop(frame, (
          guide: full,
          visible: const Size(.62, 1),
        ), mirror: mirror),
        isFalse,
      );
    }
  });
}
