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

  group("the setup's guide lies where a cropping camera would show it", () {
    /// Where a camera of [shape] that fills a [box] and crops what does not
    /// fit (BoxFit.cover) shows the picture: the part of it left visible,
    /// in shares of the picture's width and height.
    Rect visibleByCover(double shape, Size box) {
      // Scaled up until both sides fill the box.
      final scale = [
        box.width / shape,
        box.height,
      ].reduce((a, b) => a > b ? a : b);
      final picture = Size(shape * scale, scale);
      final left = (picture.width - box.width) / 2 / picture.width;
      final top = (picture.height - box.height) / 2 / picture.height;
      return Rect.fromLTRB(left, top, 1 - left, 1 - top);
    }

    const guideKey = Key('guide');

    for (final (name, box) in const [
      // S22: the camera area below the line, wider than the picture.
      ('a box wider than the picture (S22, 360 x 387)', Size(360, 387)),
      ('a box narrower than the picture (300 x 600)', Size(300, 600)),
      ('a box of the picture\'s own shape (300 x 400)', Size(300, 400)),
    ]) {
      testWidgets('in $name, the guide covers the part of the picture a '
          'cover-fit camera shows there', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.fromSize(
                size: box,
                child: const Center(
                  child: BattleCameraView(
                    controller: null,
                    guide: SizedBox.expand(key: guideKey),
                  ),
                ),
              ),
            ),
          ),
        );
        final picture = tester.getRect(find.byType(PoseCameraView));
        final guide = tester.getRect(find.byKey(guideKey));
        final share = visibleByCover(3 / 4, box);
        expect(
          guide.left,
          closeTo(picture.left + share.left * picture.width, .01),
        );
        expect(
          guide.right,
          closeTo(picture.left + share.right * picture.width, .01),
        );
        expect(
          guide.top,
          closeTo(picture.top + share.top * picture.height, .01),
        );
        expect(
          guide.bottom,
          closeTo(picture.top + share.bottom * picture.height, .01),
        );
        // The picture itself stays whole: nothing of it is cropped.
        expect(picture.width / picture.height, closeTo(3 / 4, 1e-9));
        expect(
          picture.width == box.width || picture.height == box.height,
          isTrue,
        );
      });
    }

    testWidgets('on the S22 the guide is the picture\'s width and 0.81 of its '
        'height, in the middle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 387,
              child: Center(
                child: BattleCameraView(
                  controller: null,
                  guide: SizedBox.expand(key: guideKey),
                ),
              ),
            ),
          ),
        ),
      );
      final picture = tester.getRect(find.byType(PoseCameraView));
      final guide = tester.getRect(find.byKey(guideKey));
      expect(picture.size.width, closeTo(290.25, .01));
      expect(guide.width, closeTo(290.25, .01));
      // A cover-fit camera scales the picture to 360 x 480 and shows 387 of
      // its 480 rows.
      expect(guide.height, closeTo(387 * 387 / 480, .01));
      expect(guide.center.dy, closeTo(picture.center.dy, .01));
    });

    test('the share follows the box and the shape, and falls back to the '
        'whole picture for a box with no size', () {
      final wide = BattleCameraView.coverShare(3 / 4, const Size(360, 387));
      expect(wide.width, 1);
      expect(wide.height, closeTo(.75 / (360 / 387), 1e-12));
      final narrow = BattleCameraView.coverShare(3 / 4, const Size(300, 600));
      expect(narrow.width, closeTo(.5 / .75, 1e-12));
      expect(narrow.height, 1);
      for (final box in const [
        Size.zero,
        Size(double.infinity, 400),
        Size(300, double.infinity),
      ]) {
        final share = BattleCameraView.coverShare(3 / 4, box);
        expect((share.width, share.height), (1.0, 1.0), reason: '$box');
      }
      final none = BattleCameraView.coverShare(0, const Size(360, 387));
      expect((none.width, none.height), (1.0, 1.0));
    });

    testWidgets('a guide drawn for the whole picture covers it whole', (
      tester,
    ) async {
      await _pump(
        tester,
        const BattleCameraView(
          controller: null,
          guide: SizedBox.expand(key: guideKey),
          guideFit: BoxFit.contain,
        ),
      );
      expect(
        tester.getRect(find.byKey(guideKey)),
        tester.getRect(find.byType(PoseCameraView)),
      );
    });

    testWidgets('without a guide nothing is laid over the picture', (
      tester,
    ) async {
      await _pump(tester, const BattleCameraView(controller: null));
      expect(find.byType(FractionallySizedBox), findsNothing);
    });
  });
}
