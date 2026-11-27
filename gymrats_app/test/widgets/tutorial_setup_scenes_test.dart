import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/help_rules.dart';
import 'package:gymrats_app/widgets/pose_silhouette_guide.dart';
import 'package:gymrats_app/widgets/pose_silhouette_squat.dart';
import 'package:gymrats_app/widgets/tutorial_figure_painters.dart';
import 'package:gymrats_app/widgets/tutorial_person.dart';
import 'package:gymrats_app/widgets/tutorial_setup_scenes.dart';

void main() {
  /// [child] on its own, with reduced motion when [still].
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    bool still = true,
  }) async {
    if (still) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(child: child),
      ),
    );
  }

  TutorialSidePainter sidePainter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(TutorialSidePerson),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as TutorialSidePainter;

  /// Where the drawn shoulder is: the near arm's first piece starts there.
  double shoulderY(WidgetTester tester) =>
      sidePainter(tester).shapes.arm.last.getBounds().center.dy;

  group('page 1: the person in front of the phone on the wall', () {
    for (final squat in const [false, true]) {
      final name = squat ? 'squat' : 'push-up';
      testWidgets('the $name person does the exercise over and over: down, '
          'and back up in one loop', (tester) async {
        await show(tester, TutorialWallScene(squat: squat), still: false);
        final loop = TutorialSide.loopOf(squat: squat);
        final top = shoulderY(tester);
        // Half way through the loop the person is at the bottom.
        await tester.pump(loop * 0.5);
        expect(shoulderY(tester), greaterThan(top + 5));
        // A whole loop later, back at the top.
        await tester.pump(loop * 0.5);
        expect(shoulderY(tester), moreOrLessEquals(top, epsilon: 0.5));
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('with reduced motion the person holds still at the top of '
        'the rep', (tester) async {
      await show(tester, const TutorialWallScene(squat: false));
      final top = shoulderY(tester);
      await tester.pump(const Duration(milliseconds: 950));
      expect(shoulderY(tester), top);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(
        sidePainter(tester).shapes.arm,
        hasLength(
          TutorialSide.shapes(
            TutorialSide.joints(TutorialSidePose.push, 0),
            1,
          ).arm.length,
        ),
      );
    });

    testWidgets('the battle\'s tag says 1:1 and the round\'s length', (
      tester,
    ) async {
      await show(tester, const TutorialWallScene(squat: true));
      expect(find.text('1:1 · ${HelpRules.totalSeconds}초'), findsOneWidget);
      expect(
        tester.getSize(find.byType(TutorialWallScene)),
        TutorialWallScene.size,
      );
      final painter = sidePainter(tester);
      // The squat's hands are held: a fist, not two hands.
      expect(painter.shapes.farArm, hasLength(5));
      expect(painter.armEdge, 3);
      expect(painter.mirrored, isFalse);
    });

    test('the loop\'s shapes follow the phase, the person\'s middle kept '
        'where the top pose has it', () {
      final top = TutorialSidePerson.shapesAt(0, squat: false);
      final bottom = TutorialSidePerson.shapesAt(950, squat: false);
      final feet = top.leg.last.getBounds().center;
      // The feet stay planted while the shoulders go down.
      expect(bottom.leg.last.getBounds().center.dx, moreOrLessEquals(feet.dx));
      expect(
        bottom.arm.last.getBounds().center.dy,
        greaterThan(top.arm.last.getBounds().center.dy),
      );
    });
  });

  group('page 2: the setup\'s camera, outside and inside the guide', () {
    testWidgets('push-up: the app\'s guide, white outside and green inside; '
        'the person moved aside outside', (tester) async {
      await show(tester, const TutorialSetupCameras(squat: false));
      expect(
        tester
            .widgetList<PoseSilhouetteGuide>(find.byType(PoseSilhouetteGuide))
            .map((guide) => guide.ready),
        [false, true],
      );
      expect(find.byType(StandingSilhouetteGuide), findsNothing);
      expect(find.text('선 밖이면 대기'), findsOneWidget);
      expect(find.text('선 안 = 준비 완료'), findsOneWidget);
      expect(find.byType(TutorialArrowDisc), findsOneWidget);
      final cameras = find.byType(TutorialSetupCamera);
      expect(tester.getSize(cameras.first), const Size(132, 175));
      // Outside the line the person stands aside, smaller (the design's
      // figT); inside, where the guide is.
      Matrix4 personAt(Finder camera) => tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.descendant(
                    of: camera,
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is CustomPaint &&
                          widget.painter is TutorialFrontPainter,
                    ),
                  ),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;
      expect(
        personAt(cameras.first),
        Matrix4.translationValues(
          78,
          70,
          0,
        ).multiplied(Matrix4.diagonal3Values(0.74, 0.74, 1)),
      );
      expect(personAt(cameras.last), Matrix4.identity());
    });

    testWidgets('squat: the standing guide, both hands held in front of the '
        'chest', (tester) async {
      await show(tester, const TutorialSetupCameras(squat: true));
      expect(
        tester
            .widgetList<StandingSilhouetteGuide>(
              find.byType(StandingSilhouetteGuide),
            )
            .map((guide) => guide.ready),
        [false, true],
      );
      expect(find.byType(PoseSilhouetteGuide), findsNothing);
      final person = tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find
                      .byWidgetPredicate(
                        (widget) =>
                            widget is CustomPaint &&
                            widget.painter is TutorialFrontPainter,
                      )
                      .first,
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;
      expect(
        person,
        Matrix4.translationValues(
          96,
          54,
          0,
        ).multiplied(Matrix4.diagonal3Values(0.8, 0.8, 1)),
      );
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<TutorialFrontPainter>();
      expect(painters, hasLength(2));
      for (final painter in painters) {
        expect(painter.figure.clasp, isNotNull);
        expect(painter.figure.arms, isNotEmpty);
      }
      expect(tester.takeException(), isNull);
    });
  });

  test('the painters repaint only when what they draw changes', () {
    final shapes = TutorialSidePerson.shapesAt(0, squat: false);
    final painter = TutorialSidePainter(shapes: shapes, armEdge: 3);
    expect(
      painter.shouldRepaint(TutorialSidePainter(shapes: shapes, armEdge: 3)),
      isFalse,
    );
    expect(
      painter.shouldRepaint(
        TutorialSidePainter(shapes: shapes, armEdge: 3, mirrored: true),
      ),
      isTrue,
    );
    final figure = TutorialFront.setupPush();
    expect(
      TutorialFrontPainter(figure).shouldRepaint(TutorialFrontPainter(figure)),
      isFalse,
    );
    expect(
      TutorialFrontPainter(figure)
          .shouldRepaint(TutorialFrontPainter(TutorialFront.setupStand())),
      isTrue,
    );
    expect(
      const TutorialCameraBackdropPainter().shouldRepaint(
        const TutorialCameraBackdropPainter(),
      ),
      isFalse,
    );
    expect(
      const TutorialGridPainter(background: AppColors.card)
          .shouldRepaint(const TutorialGridPainter(background: AppColors.card)),
      isFalse,
    );
    expect(
      const TutorialArrowPainter().shouldRepaint(
        const TutorialArrowPainter(width: 2),
      ),
      isTrue,
    );
  });

  testWidgets('a mirrored person is drawn turned about its axis', (
    tester,
  ) async {
    const key = Key('person');
    await show(
      tester,
      SizedBox(
        width: 220,
        height: 200,
        child: CustomPaint(
          key: key,
          painter: TutorialSidePainter(
            shapes: TutorialSidePerson.shapesAt(0, squat: true),
            armEdge: 2.6,
            mirrored: true,
            mirrorAxis: 110,
          ),
        ),
      ),
    );
    expect(
      tester.renderObject(find.byKey(key)),
      paints
        ..save()
        ..translate(x: 220, y: 0)
        ..scale(x: -1, y: 1),
    );
    expect(tester.takeException(), isNull);
  });
}
