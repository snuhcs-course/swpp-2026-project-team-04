import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/widgets/pose_avatar_toggle_view.dart';

import '../support/pose_fixtures.dart';

void main() {
  const snapshot = JudgeSnapshot(
    phase: RepPhase.descending,
    shoulderDrop: .5,
    topShoulderY: 200,
  );
  testWidgets('height clears immediately when either shoulder is lost', (
    tester,
  ) async {
    Future<void> show(PoseFrame? frame) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChestHeightOverlay(frame: frame, snapshot: snapshot),
        ),
      ),
    );
    await show(standingFrame());
    expect(find.text('하강 50% · 어깨 너비 기준'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ChestHeightGuidePainter,
      ),
      findsOneWidget,
    );
    await show(standingFrame(hide: {BodyLandmark.leftShoulder}));
    expect(find.text('양쪽 어깨가 보이도록 해주세요'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ChestHeightGuidePainter,
      ),
      findsNothing,
    );
    expect(find.textContaining('하강 50%'), findsNothing);
  });
  test('height projection matches cover crop and mirror', () {
    final painter = ChestHeightGuidePainter(
      frame: standingFrame(),
      baselineY: 200,
      mirror: false,
    );
    expect(
      painter.project(const Offset(250, 250), const Size(400, 200)),
      const Offset(100, 0),
    );
    final mirror = ChestHeightGuidePainter(
      frame: standingFrame(),
      baselineY: 200,
      mirror: true,
    );
    expect(
      mirror.project(const Offset(250, 250), const Size(400, 200)),
      const Offset(300, 0),
    );
    expect(
      ChestHeightOverlay.visible(
        const PoseFrame.empty(imageWidth: double.nan, imageHeight: 0),
      ),
      isFalse,
    );
  });
  testWidgets('the camera view keeps the gauge and its camera-space guide', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoseAvatarToggleView(
            controller: null,
            frame: standingFrame(),
            chestSnapshot: snapshot,
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<ChestHeightOverlay>(find.byType(ChestHeightOverlay))
          .drawGuide,
      isTrue,
    );
    // The guide line on the camera, and the words; the bar was the
    // avatar's stand-in for the line.
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ChestHeightGuidePainter,
      ),
      findsOneWidget,
    );
    expect(find.text('하강 50% · 어깨 너비 기준'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
