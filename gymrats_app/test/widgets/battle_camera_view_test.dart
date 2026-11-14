import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_camera_view.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';
import 'package:gymrats_app/widgets/pose_silhouette_guide.dart';
import 'package:gymrats_app/widgets/squat_height_overlay.dart';

import '../support/pose_fixtures.dart';
import 'battle_test_support.dart';

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

  group('under the arena\'s layout (W2b 3-B, guide option 가)', () {
    const laidKey = Key('laid guide');
    const setupBox = Size(360, 621);
    const battleBox = Size(360, 387);

    test('the picture fills the setup\'s box, fits whole in the battle\'s, '
        'and its height goes evenly in between', () {
      Size at(double progress, {double shape = 3 / 4}) =>
          BattleCameraView.pictureSize(
            shape,
            setupBox: setupBox,
            battleBox: battleBox,
            progress: progress,
          );
      // Wider than the setup's box: as tall as it, cut at the sides.
      expect(at(0), const Size(621 * 3 / 4, 621));
      // Narrower than the battle's box: as tall as it, whole.
      expect(at(1), const Size(387 * 3 / 4, 387));
      expect(at(0.5).height, closeTo((621 + 387) / 2, 1e-9));
      expect(at(0.5).width, closeTo(at(0.5).height * 3 / 4, 1e-9));
      // A 2 : 3 camera (W2B-SPEC 4.5): 414 x 621 while setting up.
      expect(at(0, shape: 2 / 3).width, closeTo(414, 1e-9));
      // A picture narrower than the setup's box is cut at the top and
      // bottom instead; one wider than the battle's box fits its width.
      final tall = BattleCameraView.pictureSize(
        0.5,
        setupBox: const Size(400, 600),
        battleBox: const Size(400, 300),
        progress: 0,
      );
      expect(tall, const Size(400, 800));
      final wide = BattleCameraView.pictureSize(
        2,
        setupBox: const Size(400, 600),
        battleBox: const Size(400, 300),
        progress: 1,
      );
      expect(wide, const Size(400, 200));
      expect(
        BattleCameraView.pictureSize(
          0,
          setupBox: setupBox,
          battleBox: battleBox,
          progress: 0,
        ),
        Size.zero,
      );
    });

    /// The phone's screen, so the setup's 621-tall box fits.
    Future<void> phone(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    Future<void> pumpLaidOut(
      WidgetTester tester,
      double progress, {
      Widget? guide,
    }) async {
      await phone(tester);
      final box = Size(360, 621 - (621 - 387) * progress);
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: box,
              child: BattleCameraLayout(
                setupBox: setupBox,
                battleBox: battleBox,
                progress: progress,
                child: Center(
                  child: BattleCameraView(controller: null, guide: guide),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('setting up on an S22: the picture covers the box, cut at '
        'the sides, and the guide keeps its share of the picture: '
        '465.75 x 500.7 in the middle', (tester) async {
      await pumpLaidOut(tester, 0, guide: const SizedBox.expand(key: laidKey));
      final picture = tester.getRect(find.byType(PoseCameraView));
      expect(picture.width, closeTo(465.75, 0.01));
      expect(picture.height, closeTo(621, 0.01));
      expect(picture.left, closeTo(-52.875, 0.01));
      expect(picture.top, closeTo(0, 0.01));
      final guide = tester.getRect(find.byKey(laidKey));
      expect(guide.width, closeTo(465.75, 0.01));
      expect(guide.height, closeTo(621 * 387 / 480, 0.01));
      // On the screen, under the line's 159: y 219.2 to 719.8.
      expect(159 + guide.top, closeTo(219.2, 0.1));
      expect(159 + guide.bottom, closeTo(719.8, 0.1));
      // What does not fit the box is cut off.
      final clip = find.ancestor(
        of: find.byType(PoseCameraView),
        matching: find.byType(ClipRect),
      );
      expect(tester.getRect(clip.last), const Rect.fromLTWH(0, 0, 360, 621));
    });

    testWidgets('the guide\'s box keeps its shape all the way, so its '
        'outline is never stretched', (tester) async {
      double shapeAt(double progress) {
        final guide = tester.getRect(find.byKey(laidKey));
        return guide.width / guide.height;
      }

      final shapes = <double>[];
      for (final progress in [0.0, 0.3, 0.7, 1.0]) {
        await pumpLaidOut(
          tester,
          progress,
          guide: const SizedBox.expand(key: laidKey),
        );
        shapes.add(shapeAt(progress));
      }
      for (final shape in shapes) {
        expect(shape, closeTo(shapes.first, 1e-6));
      }
    });

    testWidgets('in the battle\'s layout it is W2\'s picture and guide, to '
        'the point', (tester) async {
      await pumpLaidOut(tester, 1, guide: const SizedBox.expand(key: laidKey));
      final picture = tester.getRect(find.byType(PoseCameraView));
      final guide = tester.getRect(find.byKey(laidKey));
      await tester.pumpWidget(
        const MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              height: 387,
              child: Center(
                child: BattleCameraView(
                  controller: null,
                  guide: SizedBox.expand(key: laidKey),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getRect(find.byType(PoseCameraView)), picture);
      expect(tester.getRect(find.byKey(laidKey)), guide);
    });

    testWidgets('a guide drawn for the whole picture covers it whole there '
        'too', (tester) async {
      await phone(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              height: 621,
              child: BattleCameraLayout(
                setupBox: setupBox,
                battleBox: battleBox,
                progress: 0,
                child: BattleCameraView(
                  controller: null,
                  guide: SizedBox.expand(key: laidKey),
                  guideFit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getRect(find.byKey(laidKey)),
        tester.getRect(find.byType(PoseCameraView)),
      );
    });
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
      expect(find.byType(BattleGuideOverlay), findsNothing);
    });

    testWidgets('a cover guide is laid with the share of its box, and a '
        'whole-picture guide with the whole picture', (tester) async {
      await _pump(
        tester,
        const BattleCameraView(
          controller: null,
          guide: SizedBox.expand(key: guideKey),
        ),
      );
      final share = BattleCameraView.coverShare(3 / 4, const Size(360, 387));
      final overlay = find.byType(BattleGuideOverlay);
      expect(tester.widget<BattleGuideOverlay>(overlay).share, share);
      // It lies over the whole picture: the dimming reaches its edges.
      expect(
        tester.getRect(overlay),
        tester.getRect(find.byType(PoseCameraView)),
      );

      await _pump(
        tester,
        const BattleCameraView(
          controller: null,
          guide: SizedBox.expand(key: guideKey),
          guideFit: BoxFit.contain,
        ),
      );
      expect(tester.widget<BattleGuideOverlay>(overlay).share, (
        width: 1.0,
        height: 1.0,
      ));
    });
  });

  group("the setup's guide for each exercise", () {
    test('push-ups get the silhouette, drawn for a cropping camera box, '
        'ready or not', () {
      for (final ready in [false, true]) {
        final guide = BattleCameraView.setupGuide(
          ExerciseType.pushUp,
          ready: ready,
        )!;
        expect(
          guide.widget,
          isA<PoseSilhouetteGuide>().having((g) => g.ready, 'ready', ready),
        );
        expect(guide.fit, BoxFit.cover);
      }
    });

    test('squats have none yet', () {
      expect(
        BattleCameraView.setupGuide(ExerciseType.squat, ready: false),
        isNull,
      );
    });
  });

  group('around the guide the picture is as dark as outside its outline', () {
    // The S22's picture (290 x 387) and the share a cropping camera shows.
    const picture = Size(290, 387);
    final share = BattleCameraView.coverShare(3 / 4, const Size(360, 387));
    final guideTop = picture.height * (1 - share.height) / 2;

    Widget overlay(Widget guide) => SizedBox.fromSize(
      size: picture,
      child: BattleGuideOverlay(share: share, guide: guide),
    );

    testWidgets("the strips above and below the silhouette's box are the "
        "silhouette's own dimming; inside the outline the picture is clear", (
      tester,
    ) async {
      final painted = await paintPicture(
        tester,
        overlay(const PoseSilhouetteGuide(ready: false)),
        size: picture,
        ground: AppColors.card,
      );
      // Inside the silhouette's box but outside its outline: its dimming.
      final outside = painted.at(5, guideTop + 20);
      expect(outside, isNot(AppColors.card));
      // The strips: the same shade, top and bottom, at both sides.
      for (final (x, y) in [
        (5.0, 2.0),
        (5.0, guideTop - 2),
        (picture.width - 5, 10.0),
        (5.0, picture.height - guideTop + 2),
        (picture.width / 2, picture.height - 2),
      ]) {
        expect(painted.at(x, y), outside, reason: '($x, $y)');
      }
      // The torso inside the outline is not dimmed.
      expect(
        painted.at(picture.width / 2, guideTop + share.height * 387 * .45),
        AppColors.card,
      );
      // The guide's dimming is the token's: white under black at 45%.
      final expected = Color.alphaBlend(
        AppColors.setupGuideScrim,
        AppColors.card,
      );
      expect(outside.r, closeTo(expected.r, 1 / 255));
    });

    testWidgets('where a strip meets the box, no lighter or darker line', (
      tester,
    ) async {
      final painted = await paintPicture(
        tester,
        overlay(const PoseSilhouetteGuide(ready: false)),
        size: picture,
        ground: AppColors.card,
      );
      final outside = painted.at(5, guideTop + 20);
      final bottom = picture.height - guideTop;
      // The box's edges fall inside a pixel row (37.49 and 349.51).
      expect(guideTop % 1, isNot(0));
      for (final edge in [guideTop, bottom]) {
        for (var y = edge.floor() - 3.0; y <= edge.ceil() + 3; y += 1) {
          for (final x in [5.0, picture.width - 5]) {
            expect(painted.at(x, y), outside, reason: '($x, $y)');
          }
        }
      }
    });

    testWidgets('inside its box, past its first point, the silhouette is '
        'drawn as it is alone, outline and all', (tester) async {
      const guide = PoseSilhouetteGuide(ready: true);
      final height = picture.height * share.height;
      final over = await paintPicture(
        tester,
        overlay(guide),
        size: picture,
        ground: AppColors.card,
      );
      final alone = await paintPicture(
        tester,
        SizedBox.fromSize(
          size: picture,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: guideTop,
                width: picture.width,
                height: height,
                child: guide,
              ),
            ],
          ),
        ),
        size: picture,
        ground: AppColors.card,
      );
      var outline = 0;
      // The strips reach 1 point into the box: the rows they touch are left.
      final last = (guideTop + height - 1).floor();
      for (var y = (guideTop + 1).ceil(); y < last; y++) {
        for (var x = 0; x < picture.width; x++) {
          final pixel = alone.at(x.toDouble(), y.toDouble());
          final drawn = over.at(x.toDouble(), y.toDouble());
          // Within rounding: here the guide goes through a layer of its own.
          for (final (a, b) in [
            (drawn.r, pixel.r),
            (drawn.g, pixel.g),
            (drawn.b, pixel.b),
          ]) {
            expect(a, closeTo(b, 2 / 255), reason: '($x, $y)');
          }
          if (pixel.g > pixel.r + .2) outline += 1;
        }
      }
      // The green outline was among what was compared.
      expect(outline, greaterThan(500));
    });

    testWidgets('a guide over the whole picture leaves no strip', (
      tester,
    ) async {
      final painted = await paintPicture(
        tester,
        SizedBox.fromSize(
          size: picture,
          child: const BattleGuideOverlay(
            share: (width: 1, height: 1),
            guide: SizedBox.expand(),
          ),
        ),
        size: picture,
        ground: AppColors.card,
      );
      expect(painted.at(5, 2), AppColors.card);
      expect(painted.at(5, picture.height - 2), AppColors.card);
    });

    testWidgets('a narrower share dims the sides instead', (tester) async {
      final painted = await paintPicture(
        tester,
        const SizedBox(
          width: 300,
          height: 400,
          child: BattleGuideOverlay(
            share: (width: .5, height: 1),
            guide: SizedBox.expand(),
          ),
        ),
        size: const Size(300, 400),
        ground: AppColors.card,
      );
      final dim = Color.alphaBlend(AppColors.setupGuideScrim, AppColors.card);
      expect(painted.at(30, 200).r, closeTo(dim.r, 1 / 255));
      expect(painted.at(270, 200).r, closeTo(dim.r, 1 / 255));
      expect(painted.at(150, 200), AppColors.card);
      expect(painted.at(150, 5), AppColors.card);
    });

    testWidgets('the strips take no taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.fromSize(
              size: picture,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(onTap: () => taps += 1),
                  BattleGuideOverlay(share: share, guide: const SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
      final box = tester.getRect(find.byType(BattleGuideOverlay));
      await tester.tapAt(box.topCenter + const Offset(0, 5));
      await tester.tapAt(box.bottomCenter - const Offset(0, 5));
      expect(taps, 2);
    });
  });
}
