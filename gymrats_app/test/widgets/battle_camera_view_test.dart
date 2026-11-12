import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/widgets/battle_camera_view.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';
import 'package:gymrats_app/widgets/squat_height_overlay.dart';

import '../support/pose_fixtures.dart';

Future<void> _pump(WidgetTester tester, BattleCameraView view) =>
    tester.pumpWidget(
      MaterialApp(
        // Like the camera area: centered in the room it has.
        home: Center(
          child: SizedBox(width: 360, height: 387, child: Center(child: view)),
        ),
      ),
    );

void main() {
  testWidgets('before the camera runs it is a black picture of the upright '
      '3 : 4 shape, in the middle, whole', (tester) async {
    await _pump(tester, const BattleCameraView(controller: null));
    final box = tester.getSize(find.byType(BattleCameraView));
    expect(box.height, 387);
    expect(box.width, closeTo(387 * 3 / 4, 0.01));
    final camera = tester.widget<PoseCameraView>(find.byType(PoseCameraView));
    expect(camera.controller, isNull);
    expect(camera.showLandmarks, isTrue);
    expect(find.byType(ChestHeightOverlay), findsNothing);
    expect(find.byType(SquatHeightOverlay), findsNothing);
  });

  testWidgets('a push-up shows the chest lines over it, a squat the squat '
      'lines, each with the frame and the mirror', (tester) async {
    final frame = standingFrame();
    const snapshot = JudgeSnapshot(phase: RepPhase.idle);
    await _pump(
      tester,
      BattleCameraView(
        controller: null,
        frame: frame,
        mirror: true,
        chestSnapshot: snapshot,
      ),
    );
    final chest = tester.widget<ChestHeightOverlay>(
      find.byType(ChestHeightOverlay),
    );
    expect(chest.frame, same(frame));
    expect(chest.snapshot, same(snapshot));
    expect(chest.mirror, isTrue);
    expect(
      tester.widget<PoseCameraView>(find.byType(PoseCameraView)).mirror,
      isTrue,
    );
    expect(find.byType(SquatHeightOverlay), findsNothing);

    await _pump(
      tester,
      BattleCameraView(controller: null, frame: frame, squatSnapshot: snapshot),
    );
    expect(find.byType(SquatHeightOverlay), findsOneWidget);
    expect(find.byType(ChestHeightOverlay), findsNothing);
    // The overlays cover the camera's own box.
    expect(
      tester.getRect(find.byType(SquatHeightOverlay)),
      tester.getRect(find.byType(PoseCameraView)),
    );
  });
}
