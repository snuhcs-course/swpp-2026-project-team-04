import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/arcade_viewmodel.dart';
import 'package:gymrats_app/widgets/arcade_map.dart';
import 'package:gymrats_app/widgets/battle_camera_area.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/widgets/tutorial_game_shot.dart';
import 'package:gymrats_app/widgets/tutorial_welcome.dart';

void main() {
  /// [child] on its own, with reduced motion when [still].
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    bool still = false,
  }) async {
    if (still) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(child: child),
      ),
    );
  }

  TutorialGameScene scene(WidgetTester tester) =>
      tester.widget<TutorialGameShot>(find.byType(TutorialGameShot)).scene;

  /// The shoulder line's height on the clip's camera.
  double shoulder(WidgetTester tester) =>
      (tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((paint) => paint.painter)
              .whereType<ChestHeightGuidePainter>()
              .single
              .frame
              .keypoints
              .values
              .first)
          .y;

  testWidgets('the game page: the online battle and the arcade, each a '
      'screenshot over its name', (tester) async {
    await show(tester, const TutorialWelcome(), still: true);
    expect(find.byType(TutorialScreenshot), findsNWidgets(2));
    expect(find.text('온라인 대결'), findsOneWidget);
    expect(find.text('아케이드'), findsWidgets);
    final frame = tester.getRect(find.byType(TutorialScreenshot).first);
    expect(frame.size, const Size(130, 277));
    // The screen inside the 2 ink edge, 0.35 of 360×780.
    final screen = tester.getRect(find.byType(TutorialOnlineClip));
    expect(screen.left - frame.left, moreOrLessEquals(2));
    expect(screen.top - frame.top, moreOrLessEquals(2));
    expect(screen.width, moreOrLessEquals(126));
    expect(screen.height, moreOrLessEquals(273));
    expect(TutorialWelcome.label, '온라인 대결 게임 중 화면과 아케이드 지도 화면 스크린샷');
    expect(tester.takeException(), isNull);
  });

  group('the online clip (TutShotOnline)', () {
    testWidgets('as time runs the shoulder line goes down; at the bottom the '
        'frame turns green and GOOD comes up; then it loops', (tester) async {
      await show(tester, const TutorialOnlineClip());
      expect(shoulder(tester), 156);
      expect(scene(tester).frame, isNull);
      await tester.pump(const Duration(milliseconds: 600));
      final halfWay = shoulder(tester);
      expect(halfWay, greaterThan(156));
      expect(halfWay, lessThan(238));
      await tester.pump(const Duration(milliseconds: 400));
      expect(shoulder(tester), 238);
      expect(scene(tester).bottom, isTrue);
      expect(
        tester.widget<BattleCameraArea>(find.byType(BattleCameraArea)).frame,
        BattleFxCameraFrame.good,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('GOOD'), findsOneWidget);
      // GOOD alone on the clip's stage, and the players' nicknames.
      expect(find.text('+10'), findsNothing);
      expect(find.text('hellohello'), findsOneWidget);
      expect(find.text('squatking'), findsOneWidget);
      // GYM마우스 against 펭뚱이 (A12 spec 1).
      expect(
        tester
            .widget<TutorialGameShot>(find.byType(TutorialGameShot))
            .characters,
        TutorialGameScene.welcomeCharacters,
      );
      // One loop is 3 s: back at the top.
      await tester.pump(const Duration(milliseconds: 1800));
      expect(shoulder(tester), 156);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with reduced motion it is one still, just after the blow', (
      tester,
    ) async {
      await show(tester, const TutorialOnlineClip(), still: true);
      expect(shoulder(tester), 238);
      final still = scene(tester);
      expect(still.frame, BattleFxCameraFrame.good);
      expect(still.attacks, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(shoulder(tester), 238);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  testWidgets('the arcade shot: the map at stage 8 with 17 of 72 stars, its '
      'header and 도전 bar drawn as the arcade screen; still, no taps', (
    tester,
  ) async {
    await show(
      tester,
      const SizedBox(width: 360, height: 780, child: TutorialArcadeShot()),
    );
    final map = tester.widget<ArcadeMap>(find.byType(ArcadeMap));
    expect(map.progress.currentStage, 8);
    expect(map.progress.totalStars, 17);
    expect(map.myCharacter, 'mouse');
    expect(find.text('PLAY / ARCADE'), findsOneWidget);
    // The header's stars: 17 beside "/ 72" (17 is also a stage's number).
    expect(find.text('/ 72'), findsOneWidget);
    expect(
      find.descendant(
        of: find
            .ancestor(of: find.text('/ 72'), matching: find.byType(Row))
            .first,
        matching: find.text('17'),
      ),
      findsOneWidget,
    );
    expect(find.text('도전'), findsOneWidget);
    expect(
      find.text(ArcadeWords.stageTag(ArcadeCatalog.stage(8))),
      findsOneWidget,
    );
    final still = tester.widget<TickerMode>(
      find
          .descendant(
            of: find.byType(TutorialArcadeShot),
            matching: find.byType(TickerMode),
          )
          .first,
    );
    expect(still.enabled, isFalse);
    final held = tester.widget<IgnorePointer>(
      find
          .descendant(
            of: find.byType(TutorialArcadeShot),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(held.ignoring, isTrue);
    // The header leaves the status bar's room on top, as the design does;
    // the map is seen from 1076 down.
    final shot = tester.getRect(find.byType(TutorialArcadeShot));
    expect(
      tester.getTopLeft(find.text('PLAY / ARCADE')).dy - shot.top,
      greaterThanOrEqualTo(28),
    );
    final view = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(view.controller!.offset, TutorialArcadeShot.mapTop);
    expect(view.physics, isA<NeverScrollableScrollPhysics>());
    expect(map.scroll, view.controller);
    // Nothing moves: no frame waits.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
