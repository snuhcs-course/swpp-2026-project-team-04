import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/setup_squat_silhouette_alignment.dart';

import '../support/pose_fixtures.dart';

void main() {
  const match = StandingSilhouetteAlignment();
  test('accepts a centered standing body in portrait and landscape, mirrored or not', () {
    final pose = standingFrame(showHips: true);
    for (final size in [
      const Size(400, 800),
      const Size(800, 400),
      const Size(400, 400),
    ]) {
      expect(match.matches(pose, size, mirror: false), isTrue);
      expect(match.matches(pose, size, mirror: true), isTrue);
    }
  });
  test('rejects bodies outside the guide or with missing and low-confidence landmarks', () {
    const size = Size(400, 800);
    expect(
      match.matches(
        standingFrame(showHips: true, move: {BodyLandmark.nose: (100, 150)}),
        size,
        mirror: false,
      ),
      isFalse,
    );
    expect(
      match.matches(
        standingFrame(showHips: true, hide: {BodyLandmark.leftAnkle}),
        size,
        mirror: false,
      ),
      isFalse,
    );
    expect(match.matches(standingFrame(), size, mirror: false), isFalse);
    expect(
      match.matches(standingFrame(showHips: true), Size.zero, mirror: false),
      isFalse,
    );
  });
  test('a wider stance is accepted within the existing ankle height band', () {
    const viewport = Size(400, 800);
    PoseFrame stance(double leftX, double rightX, double y) => standingFrame(
      showHips: true,
      move: {
        BodyLandmark.leftAnkle: (leftX, y),
        BodyLandmark.rightAnkle: (rightX, y),
      },
    );

    for (final mirror in [false, true]) {
      expect(
        match.matches(stance(830, 170, 870), viewport, mirror: mirror),
        isTrue,
      );
      expect(
        match.matches(stance(860, 140, 870), viewport, mirror: mirror),
        isFalse,
      );
      expect(
        match.matches(stance(830, 170, 650), viewport, mirror: mirror),
        isFalse,
      );
      expect(
        match.matches(stance(1020, 170, 870), viewport, mirror: mirror),
        isFalse,
      );
    }
  });

  test(
    'guide uses the contained camera image rather than letterboxed viewport',
    () {
      expect(
        squatPreviewRect(const Size(1000, 1000), const Size(400, 800)),
        const Rect.fromLTWH(0, 200, 400, 400),
      );
      expect(
        squatPreviewRect(const Size(1000, 1000), const Size(800, 400)),
        const Rect.fromLTWH(200, 0, 400, 400),
      );
      final guide = standingGuideRect(const Size(400, 400));
      expect(guide.center, const Offset(200, 200));
      expect(guide.width / guide.height, closeTo(.65, .00001));
    },
  );
}
