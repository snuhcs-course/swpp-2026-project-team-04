import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/landmark_overlay.dart';

import '../support/pose_fixtures.dart';

void main() {
  test('places a landmark as PoseCameraView does, mirrored for the front '
      'camera', () {
    final nose = kp(BodyLandmark.nose, 100, 200);
    final frame = PoseFrame(
      imageWidth: 480,
      imageHeight: 640,
      keypoints: {BodyLandmark.nose: nose},
    );
    const size = Size(390, 520);
    // PoseCameraView: sx = width / imageWidth, x = keypoint.x * sx, and
    // width - x when mirrored; y the same way, never mirrored.
    final x = 100 * (390 / 480);
    final y = 200 * (520 / 640);
    expect(
      landmarkPosition(nose, frame, size, mirror: false),
      offsetMoreOrLessEquals(Offset(x, y)),
    );
    expect(
      landmarkPosition(nose, frame, size, mirror: true),
      offsetMoreOrLessEquals(Offset(390 - x, y)),
    );
  });

  test('shows the face, arms, and legs, not fingers, mouth, or feet', () {
    expect(LandmarkOverlay.shown, hasLength(17));
    expect(LandmarkOverlay.shown, isNot(contains(BodyLandmark.leftPinky)));
    expect(LandmarkOverlay.shown, isNot(contains(BodyLandmark.leftMouth)));
    expect(LandmarkOverlay.shown, isNot(contains(BodyLandmark.leftHeel)));
    expect(LandmarkOverlay.shown, contains(BodyLandmark.rightAnkle));
  });

  testWidgets('likely landmarks are filled lime dots, unlikely ones hollow', (
    tester,
  ) async {
    // Twice the box, so every position is exact.
    final frame = PoseFrame(
      imageWidth: 780,
      imageHeight: 1040,
      keypoints: {
        BodyLandmark.nose: kp(BodyLandmark.nose, 500, 100),
        BodyLandmark.leftKnee: kp(
          BodyLandmark.leftKnee,
          400,
          800,
          likelihood: 0.1,
        ),
        BodyLandmark.leftPinky: kp(BodyLandmark.leftPinky, 300, 500),
      },
    );
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 390,
          height: 520,
          child: LandmarkOverlay(
            frame: frame,
            mirror: true,
            isVisible: (keypoint) => keypoint.likelihood >= 0.6,
          ),
        ),
      ),
    );
    final overlay = tester.renderObject(find.byType(CustomPaint));
    expect(
      overlay,
      paints
        // The nose: a small filled dot with a dark rim.
        ..circle(
          x: 140,
          y: 50,
          radius: 3.6,
          color: AppColors.accent,
          style: PaintingStyle.fill,
        )
        ..circle(
          x: 140,
          y: 50,
          radius: 3.6,
          color: AppColors.background,
          style: PaintingStyle.stroke,
        )
        // The knee, hardly seen: a hollow dot.
        ..circle(
          x: 190,
          y: 400,
          radius: 4.5,
          color: AppColors.accent.withValues(alpha: 0.5),
          style: PaintingStyle.stroke,
        ),
    );
    // Nothing for the pinky.
    expect(overlay, paintsExactlyCountTimes(#drawCircle, 3));
  });
}
