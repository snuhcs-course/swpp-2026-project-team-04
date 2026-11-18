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

  group('the bold look (A9 spec 4, the battle camera)', () {
    // A box 290 wide, the design's battle camera, and a frame twice its size,
    // so every size is the design's and every position exact.
    final frame = PoseFrame(
      imageWidth: 580,
      imageHeight: 774,
      keypoints: {
        BodyLandmark.leftShoulder: kp(BodyLandmark.leftShoulder, 200, 200),
        BodyLandmark.rightShoulder: kp(BodyLandmark.rightShoulder, 380, 200),
        BodyLandmark.leftElbow: kp(BodyLandmark.leftElbow, 180, 400),
        // Hardly seen: no bone reaches it.
        BodyLandmark.leftWrist: kp(
          BodyLandmark.leftWrist,
          170,
          560,
          likelihood: 0.1,
        ),
      },
    );

    Future<RenderObject> pump(WidgetTester tester, {required bool bold}) async {
      await tester.pumpWidget(
        Center(
          child: SizedBox(
            width: 290,
            height: 387,
            child: LandmarkOverlay(
              frame: frame,
              mirror: false,
              isVisible: (keypoint) => keypoint.likelihood >= 0.6,
              bold: bold,
            ),
          ),
        ),
      );
      return tester.renderObject(find.byType(CustomPaint));
    }

    testWidgets('the bones between likely joints: white 5 over 10 of ink, '
        'all the ink first', (tester) async {
      final overlay = await pump(tester, bold: true);
      const shoulders = (Offset(100, 100), Offset(190, 100));
      const upperArm = (Offset(100, 100), Offset(90, 200));
      expect(
        overlay,
        paints
          ..line(
            p1: shoulders.$1,
            p2: shoulders.$2,
            color: AppColors.ink,
            strokeWidth: 10,
          )
          ..line(
            p1: upperArm.$1,
            p2: upperArm.$2,
            color: AppColors.ink,
            strokeWidth: 10,
          )
          ..line(
            p1: shoulders.$1,
            p2: shoulders.$2,
            color: AppColors.card,
            strokeWidth: 5,
          )
          ..line(
            p1: upperArm.$1,
            p2: upperArm.$2,
            color: AppColors.card,
            strokeWidth: 5,
          ),
      );
      // Nothing to the wrist, which is hardly seen.
      expect(overlay, paintsExactlyCountTimes(#drawLine, 4));
    });

    testWidgets('likely joints are white dots of 8 with a 2.5 ink edge; an '
        'unlikely one stays hollow', (tester) async {
      final overlay = await pump(tester, bold: true);
      expect(
        overlay,
        paints
          ..circle(
            x: 100,
            y: 100,
            radius: 8,
            color: AppColors.card,
            style: PaintingStyle.fill,
          )
          ..circle(
            x: 100,
            y: 100,
            radius: 8,
            color: AppColors.ink,
            style: PaintingStyle.stroke,
            strokeWidth: 2.5,
          ),
      );
      // Three likely joints, two circles each, and the hollow wrist.
      expect(overlay, paintsExactlyCountTimes(#drawCircle, 7));
    });

    testWidgets('off, as for the tutorial and the demos, no bones and the '
        'lime dots as before', (tester) async {
      final overlay = await pump(tester, bold: false);
      expect(overlay, paintsExactlyCountTimes(#drawLine, 0));
      expect(
        overlay,
        paints..circle(
          x: 100,
          y: 100,
          color: AppColors.accent,
          style: PaintingStyle.fill,
        ),
      );
    });

    test('the bones join the arms, the trunk and the legs', () {
      expect(LandmarkOverlay.bones, hasLength(12));
      expect(
        LandmarkOverlay.bones,
        contains((BodyLandmark.rightKnee, BodyLandmark.rightAnkle)),
      );
      expect(
        LandmarkOverlay.bones,
        contains((BodyLandmark.leftHip, BodyLandmark.rightHip)),
      );
    });
  });
}
