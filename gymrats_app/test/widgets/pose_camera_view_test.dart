import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/widgets/landmark_overlay.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';

import '../support/pose_fixtures.dart';

/// A camera that is running without the platform: its preview is an empty
/// box, so the view and what it draws on it can be checked.
class _RunningCamera extends CameraController {
  _RunningCamera()
    : super(
        const CameraDescription(
          name: 'front',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 270,
        ),
        ResolutionPreset.medium,
      ) {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(640, 480),
    );
  }

  @override
  Widget buildPreview() => const SizedBox.expand();
}

final _frame = PoseFrame(
  imageWidth: 480,
  imageHeight: 640,
  keypoints: {
    BodyLandmark.leftShoulder: kp(BodyLandmark.leftShoulder, 200, 200),
    BodyLandmark.rightShoulder: kp(
      BodyLandmark.rightShoulder,
      300,
      200,
      likelihood: 0.5,
    ),
  },
);

Future<void> _pump(WidgetTester tester, PoseCameraView view) =>
    tester.pumpWidget(
      MaterialApp(
        home: Center(child: SizedBox(width: 300, height: 400, child: view)),
      ),
    );

void main() {
  testWidgets('before the camera runs it is black, with no landmarks', (
    tester,
  ) async {
    await _pump(
      tester,
      PoseCameraView(controller: null, frame: _frame, showLandmarks: true),
    );
    expect(find.byType(CameraPreview), findsNothing);
    expect(find.byType(LandmarkOverlay), findsNothing);
  });

  testWidgets('the bold look is off by default: its own dots, no '
      'LandmarkOverlay (the tutorial and the demos keep their look)', (
    tester,
  ) async {
    await _pump(
      tester,
      PoseCameraView(
        controller: _RunningCamera(),
        frame: _frame,
        showLandmarks: true,
      ),
    );
    expect(find.byType(CameraPreview), findsOneWidget);
    expect(find.byType(LandmarkOverlay), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CameraPreview),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('boldLandmarks draws the landmarks as the bold LandmarkOverlay, '
      'mirrored as the view is, likely as the view says (A9)', (tester) async {
    await _pump(
      tester,
      PoseCameraView(
        controller: _RunningCamera(),
        frame: _frame,
        mirror: true,
        showLandmarks: true,
        boldLandmarks: true,
      ),
    );
    final overlay = tester.widget<LandmarkOverlay>(
      find.byType(LandmarkOverlay),
    );
    expect(overlay.bold, isTrue);
    expect(overlay.mirror, isTrue);
    expect(overlay.frame, same(_frame));
    // The view's default: a likelihood of at least 0.6.
    expect(overlay.isVisible(_frame[BodyLandmark.leftShoulder]!), isTrue);
    expect(overlay.isVisible(_frame[BodyLandmark.rightShoulder]!), isFalse);

    await _pump(
      tester,
      PoseCameraView(
        controller: _RunningCamera(),
        frame: _frame,
        showLandmarks: true,
        boldLandmarks: true,
        isVisible: (keypoint, frame) => true,
      ),
    );
    expect(
      tester
          .widget<LandmarkOverlay>(find.byType(LandmarkOverlay))
          .isVisible(_frame[BodyLandmark.rightShoulder]!),
      isTrue,
    );
  });

  testWidgets('without landmarks or a frame nothing is drawn on the preview', (
    tester,
  ) async {
    for (final view in [
      PoseCameraView(
        controller: _RunningCamera(),
        frame: _frame,
        boldLandmarks: true,
      ),
      PoseCameraView(
        controller: _RunningCamera(),
        showLandmarks: true,
        boldLandmarks: true,
      ),
    ]) {
      await _pump(tester, view);
      expect(find.byType(LandmarkOverlay), findsNothing);
    }
  });
}
