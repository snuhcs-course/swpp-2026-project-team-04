import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/widgets/pose_avatar_toggle_view.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';

void main() {
  testWidgets('online preview uses frozen lobby avatar and cannot change it', (
    tester,
  ) async {
    AvatarModel? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoseAvatarToggleView(
            controller: null,
            initialModel: AvatarModel.robot,
            allowAvatarSelection: false,
            avatarBuilder: (_, _, model) {
              seen = model;
              return const Text('avatar');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('avatarCameraToggle')));
    await tester.pump();
    expect(seen, AvatarModel.robot);
    await tester.longPress(find.byKey(const Key('avatarCameraToggle')));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });
  testWidgets(
    'one button toggles camera/avatar and forwards current ML Kit pose',
    (tester) async {
      const first = PoseFrame.empty(imageWidth: 640, imageHeight: 480);
      const second = PoseFrame.empty(imageWidth: 480, imageHeight: 640);
      PoseFrame? rendered;
      bool? mirrored;
      Widget preview(PoseFrame frame) => MaterialApp(
        home: Scaffold(
          body: PoseAvatarToggleView(
            controller: null,
            frame: frame,
            mirror: true,
            cameraOverlay: const Text('camera-only-landmarks'),
            avatarBuilder: (frame, mirror, model) {
              rendered = frame;
              mirrored = mirror;
              return Text('avatar:${model.name}');
            },
          ),
        ),
      );
      await tester.pumpWidget(preview(first));
      expect(find.byType(PoseCameraView), findsOneWidget);
      expect(find.text('camera-only-landmarks'), findsOneWidget);
      expect(find.byKey(const Key('avatarCameraToggle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('avatarCameraToggle')));
      await tester.pump();
      expect(find.byType(PoseCameraView), findsNothing);
      expect(find.text('camera-only-landmarks'), findsNothing);
      expect(find.text('avatar:astronaut'), findsOneWidget);
      expect(identical(rendered, first), true);
      expect(mirrored, true);
      await tester.pumpWidget(preview(second));
      expect(identical(rendered, second), true);
      await tester.tap(find.byKey(const Key('avatarCameraToggle')));
      await tester.pump();
      expect(find.byType(PoseCameraView), findsOneWidget);
    },
  );

  testWidgets('long press selects any of the four real assets', (tester) async {
    AvatarModel? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoseAvatarToggleView(
            controller: null,
            avatarBuilder: (_, _, model) {
              selected = model;
              return const Text('avatar');
            },
          ),
        ),
      ),
    );
    await tester.longPress(find.byKey(const Key('avatarCameraToggle')));
    await tester.pumpAndSettle();
    for (final model in AvatarModel.values) {
      expect(find.text(model.label), findsOneWidget);
    }
    await tester.tap(find.text('XCVG Humanoid'));
    await tester.pumpAndSettle();
    expect(selected, AvatarModel.humanoid);
    expect(find.text('카메라 보기'), findsOneWidget);
  });
}
