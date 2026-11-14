import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/widgets/pose_avatar_toggle_view.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';
import 'package:gymrats_app/widgets/squat_height_overlay.dart';

import '../support/pose_fixtures.dart';

void main() {
  const snapshot = JudgeSnapshot(
    phase: RepPhase.descending,
    shoulderDrop: .5,
    topShoulderY: 200,
  );

  Future<void> pump(WidgetTester tester, PoseAvatarToggleView view) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));

  testWidgets('shows the camera with the pose, as it is given', (tester) async {
    const frame = PoseFrame.empty(imageWidth: 640, imageHeight: 480);
    bool visible(Keypoint keypoint, PoseFrame frame) => true;
    await pump(
      tester,
      PoseAvatarToggleView(
        controller: null,
        frame: frame,
        mirror: true,
        showLandmarks: true,
        cameraFit: BoxFit.contain,
        isVisible: visible,
        cameraOverlay: const Text('silhouette'),
      ),
    );
    final camera = tester.widget<PoseCameraView>(find.byType(PoseCameraView));
    expect(identical(camera.frame, frame), isTrue);
    expect(camera.mirror, isTrue);
    expect(camera.showLandmarks, isTrue);
    expect(camera.fit, BoxFit.contain);
    expect(camera.isVisible, same(visible));
    expect(find.text('silhouette'), findsOneWidget);
  });

  testWidgets('has no avatar button any more (W3): the camera only', (
    tester,
  ) async {
    await pump(tester, const PoseAvatarToggleView(controller: null));
    expect(find.text('아바타 보기'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(PoseCameraView), findsOneWidget);
  });

  testWidgets('draws the push-up height gauge with its guide, or the squat '
      'one, on the frame and snapshot it is given', (tester) async {
    final frame = standingFrame();
    await pump(
      tester,
      PoseAvatarToggleView(
        controller: null,
        frame: frame,
        mirror: true,
        chestSnapshot: snapshot,
      ),
    );
    final chest = tester.widget<ChestHeightOverlay>(
      find.byType(ChestHeightOverlay),
    );
    expect(chest.drawGuide, isTrue);
    expect(chest.mirror, isTrue);
    expect(identical(chest.frame, frame), isTrue);
    expect(identical(chest.snapshot, snapshot), isTrue);
    expect(find.byType(SquatHeightOverlay), findsNothing);

    await pump(
      tester,
      PoseAvatarToggleView(
        controller: null,
        frame: frame,
        squatSnapshot: snapshot,
      ),
    );
    final squat = tester.widget<SquatHeightOverlay>(
      find.byType(SquatHeightOverlay),
    );
    expect(identical(squat.frame, frame), isTrue);
    expect(identical(squat.snapshot, snapshot), isTrue);
    expect(find.byType(ChestHeightOverlay), findsNothing);
  });
}
