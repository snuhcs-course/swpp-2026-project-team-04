import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_camera_area.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_reject_sign.dart';
import 'package:gymrats_app/widgets/battle_stage.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/chest_height_overlay.dart';
import 'package:gymrats_app/widgets/squat_height_overlay.dart';
import 'package:gymrats_app/widgets/tutorial_game_shot.dart';

void main() {
  const pushUp = ExerciseType.pushUp;
  const squat = ExerciseType.squat;
  final rules = battleRules;

  Future<void> show(WidgetTester tester, TutorialGameScene scene) async {
    tester.view.physicalSize = TutorialGameShot.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TutorialGameShot(scene: scene),
      ),
    );
  }

  BattleStage stage(WidgetTester tester) =>
      tester.widget<BattleStage>(find.byType(BattleStage));
  BattleCameraArea camera(WidgetTester tester) =>
      tester.widget<BattleCameraArea>(find.byType(BattleCameraArea));
  CustomPainter? lines(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((paint) => paint.painter)
      .firstWhere(
        (painter) =>
            painter is ChestHeightGuidePainter || painter is SquatHeightPainter,
        orElse: () => null,
      );

  group('the scenes are the design\'s table T, the points from the rules', () {
    test('scores, counts, clock and grade per step', () {
      for (final exercise in ExerciseType.values) {
        for (final (step, me, them, reps, clock, grade) in const [
          (TutorialStep.battle, 70, 45, (6, 4), 18, GameGrade.good),
          (TutorialStep.excellent, 85, 45, (7, 4), 16, GameGrade.excellent),
          (TutorialStep.good, 70, 45, (6, 4), 18, GameGrade.good),
          (TutorialStep.fail, 60, 45, (5, 4), 21, null),
          (TutorialStep.combo, 85, 45, (7, 4), 15, GameGrade.good),
          (TutorialStep.fever, 190, 150, (14, 11), 8, GameGrade.excellent),
          (TutorialStep.ko, 245, 145, (17, 11), 12, null),
        ]) {
          final scene = TutorialGameScene.of(exercise, step);
          final reason = '$exercise $step';
          expect(scene.myScore, me, reason: reason);
          expect(scene.opponentScore, them, reason: reason);
          expect((scene.myReps, scene.opponentReps), reps, reason: reason);
          expect(scene.secondsLeft, clock, reason: reason);
          expect(scene.grade, grade, reason: reason);
          expect(scene.squat, exercise == squat, reason: reason);
        }
      }
      final average = TutorialGameScene.of(pushUp, TutorialStep.average);
      expect((average.myScore, average.secondsLeft), (65, 19));
      expect(average.grade, GameGrade.average);
      // The squat has no average: the design shows its good instead.
      expect(
        TutorialGameScene.of(squat, TutorialStep.average).grade,
        GameGrade.good,
      );
    });

    test('the points beside the band come from the rules', () {
      String? points(TutorialStep step) =>
          TutorialGameScene.of(pushUp, step).points;
      expect(points(TutorialStep.good), '+${rules.goodPoints}');
      expect(points(TutorialStep.excellent), '+${rules.excellentPoints}');
      expect(points(TutorialStep.average), '+${rules.averagePoints}');
      expect(
        points(TutorialStep.combo),
        '+${rules.goodPoints} +${rules.comboBonus}',
      );
      expect(
        points(TutorialStep.fever),
        '+${rules.excellentPoints * rules.feverMultiplier}',
      );
      final ko = TutorialGameScene.of(pushUp, TutorialStep.ko);
      expect(ko.myScore - ko.opponentScore, rules.koLead);
      expect(ko.share, 1);
    });

    test('the reject signs and the camera frame (as the real game, user '
        '2026-11-28)', () {
      final kneel = TutorialGameScene.of(pushUp, TutorialStep.fail);
      expect(kneel.sign!.reason, RejectReason.kneesDown);
      expect(kneel.sign!.average, isFalse);
      expect(kneel.frame, BattleFxCameraFrame.rejected);
      final shallow = TutorialGameScene.of(squat, TutorialStep.fail);
      expect(shallow.sign!.reason, RejectReason.shallowSquat);
      expect(shallow.frame, BattleFxCameraFrame.rejected);
      final average = TutorialGameScene.of(pushUp, TutorialStep.average);
      expect(average.sign!.reason, RejectReason.insufficientDepth);
      expect(average.sign!.average, isTrue);
      expect(average.frame, BattleFxCameraFrame.average);
      for (final step in const [
        TutorialStep.battle,
        TutorialStep.excellent,
        TutorialStep.good,
        TutorialStep.combo,
        TutorialStep.fever,
      ]) {
        final scene = TutorialGameScene.of(squat, step);
        expect(scene.frame, BattleFxCameraFrame.good, reason: '$step');
        expect(scene.sign, isNull, reason: '$step');
        expect(scene.bottom, isTrue, reason: '$step');
      }
      expect(TutorialGameScene.of(pushUp, TutorialStep.ko).frame, isNull);
    });

    test('the camera\'s person: at the bottom when counted, half way on '
        'average, knees down or a shallow squat on fail, up on KO', () {
      expect(TutorialGameScene.of(pushUp, TutorialStep.good).camera.lineY, 238);
      expect(
        TutorialGameScene.of(pushUp, TutorialStep.average).camera.lineY,
        moreOrLessEquals(201.1),
      );
      expect(TutorialGameScene.of(pushUp, TutorialStep.ko).camera.lineY, 156);
      expect(TutorialGameScene.of(squat, TutorialStep.good).camera.lineY, 250);
      expect(
        TutorialGameScene.of(squat, TutorialStep.fail).camera.lineY,
        moreOrLessEquals(217),
      );
      expect(TutorialGameScene.of(squat, TutorialStep.ko).camera.lineY, 190);
    });

    test('each exercise has its own pair of characters', () {
      expect(
        TutorialGameScene.charactersOf(pushUp),
        const BattleCharacters(me: 'mouse', opponent: 'seal'),
      );
      expect(
        TutorialGameScene.charactersOf(squat),
        const BattleCharacters(me: 'penguin', opponent: 'kangaroo'),
      );
    });
  });

  group('the shot draws the app\'s own battle screen', () {
    testWidgets('good: GOOD and +10 bands, the lead chip, the star, the '
        'green frame, the shoulder line green, no 인정! pill', (tester) async {
      await show(tester, TutorialGameScene.of(pushUp, TutorialStep.good));
      expect(find.text('GOOD'), findsOneWidget);
      expect(find.text('+${rules.goodPoints}'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('+25 앞섬'), findsOneWidget);
      expect(find.text('0:18'), findsOneWidget);
      expect(find.text('인정!'), findsNothing);
      final frame = stage(tester).frame;
      expect(frame.star, isNotNull);
      expect(frame.me.pose, BattlePose.attack);
      expect(frame.opponent.pose, BattlePose.hit);
      expect(frame.feverOpacity, 0);
      expect(stage(tester).characters, TutorialGameScene.charactersOf(pushUp));
      expect(camera(tester).frame, BattleFxCameraFrame.good);
      final painter = lines(tester)! as ChestHeightGuidePainter;
      expect(painter.phase, RepPhase.bottom);
      expect(painter.baselineY, 156);
      expect(find.byType(BattleRejectSignView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fail (push-up): the real sign 무릎을 바닥에서 떼요, a red frame, the '
        'shoulder line white, no band', (tester) async {
      await show(tester, TutorialGameScene.of(pushUp, TutorialStep.fail));
      final sign = tester.widget<BattleRejectSignView>(
        find.byType(BattleRejectSignView),
      );
      expect(sign.sign.reason, RejectReason.kneesDown);
      expect(find.text('무릎을 바닥에서 떼요'), findsOneWidget);
      expect(find.text('GOOD'), findsNothing);
      expect(camera(tester).frame, BattleFxCameraFrame.rejected);
      expect(
        (lines(tester)! as ChestHeightGuidePainter).phase,
        isNot(RepPhase.bottom),
      );
      expect(stage(tester).frame.star, isNull);
    });

    testWidgets('fail (squat): 더 앉기 over the hip and knee lines', (
      tester,
    ) async {
      await show(tester, TutorialGameScene.of(squat, TutorialStep.fail));
      expect(find.text('더 앉기'), findsOneWidget);
      final painter = lines(tester)! as SquatHeightPainter;
      expect(painter.snapshot.squatHipY, moreOrLessEquals(217));
      expect(painter.snapshot.squatKneeY, moreOrLessEquals(269.7));
      expect(stage(tester).characters, TutorialGameScene.charactersOf(squat));
    });

    testWidgets('average: AVERAGE and +5 in amber, the amber sign 더 깊게', (
      tester,
    ) async {
      await show(tester, TutorialGameScene.of(pushUp, TutorialStep.average));
      expect(find.text('AVERAGE'), findsOneWidget);
      expect(find.text('+${rules.averagePoints}'), findsOneWidget);
      expect(find.text('더 깊게'), findsOneWidget);
      expect(camera(tester).frame, BattleFxCameraFrame.average);
    });

    testWidgets('combo: 2 HIT over the camera, +10 +5 beside GOOD', (
      tester,
    ) async {
      await show(tester, TutorialGameScene.of(pushUp, TutorialStep.combo));
      final combo = camera(tester).combos.single;
      expect(combo.count, 2);
      // At rest as the game draws the user's mark: turned, narrowed.
      expect(combo.rotation, -6);
      expect(combo.scaleX, 0.72);
      expect(combo.scaleY, 1);
      expect(find.text('2 HIT'), findsOneWidget);
      expect(
        find.text('+${rules.goodPoints} +${rules.comboBonus}'),
        findsOneWidget,
      );
    });

    testWidgets('fever: the fever wash, the FEVER chip, EXCELLENT +30', (
      tester,
    ) async {
      await show(tester, TutorialGameScene.of(squat, TutorialStep.fever));
      expect(stage(tester).frame.feverOpacity, 1);
      expect(stage(tester).state.fever, isTrue);
      expect(
        tester
            .widget<BattleStageBackdrop>(find.byType(BattleStageBackdrop))
            .feverOpacity,
        1,
      );
      expect(
        find.text(BattleFx.feverText(rules.feverMultiplier)),
        findsOneWidget,
      );
      expect(find.text('EXCELLENT'), findsOneWidget);
      expect(
        find.text('+${rules.excellentPoints * rules.feverMultiplier}'),
        findsOneWidget,
      );
    });

    testWidgets('KO: K.O. over the stage, the opponent down, the bar all the '
        'user\'s', (tester) async {
      await show(tester, TutorialGameScene.of(pushUp, TutorialStep.ko));
      expect(find.text('K.O.'), findsOneWidget);
      final frame = stage(tester).frame;
      expect(frame.opponent.pose, BattlePose.knockedOut);
      expect(frame.me.pose, BattlePose.win);
      expect(stage(tester).state.barShare, 1);
      // The bar drawn full: lime across its whole inside (312 − 2 × 3), its
      // edge line past the lime outside the clipped inside, so not drawn
      // (the design's KO); the fighters still where they stood (meeting at
      // 220).
      final bar = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '체력 바',
      );
      ColoredBox colored(Color color) => tester.widget<ColoredBox>(
        find.descendant(
          of: bar,
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == color,
          ),
        ),
      );
      Rect rectOf(Widget widget) => tester.getRect(find.byWidget(widget));
      final inside = rectOf(
        tester.widget(
          find.descendant(of: bar, matching: find.byType(ClipRRect)),
        ),
      );
      expect(rectOf(colored(AppColors.accent)).width, 306);
      expect(
        rectOf(colored(AppColors.ink)).left,
        greaterThanOrEqualTo(inside.right),
      );
      expect(frame.me.footX, lessThan(220));
      expect(frame.opponent.footX, greaterThan(220));
      expect(find.text('+${rules.koLead} 앞섬'), findsOneWidget);
      expect(camera(tester).frame, isNull);
    });

    testWidgets('nothing in it takes a tap: the camera area\'s leave button '
        'is held', (tester) async {
      await show(tester, TutorialGameScene.of(pushUp, TutorialStep.good));
      final holds = tester.widgetList<IgnorePointer>(
        find.ancestor(
          of: find.byType(BattleCameraArea),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(holds.any((hold) => hold.ignoring), isTrue);
      // Drawn as in the game, held still.
      expect(camera(tester).onLeave, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the fighters\' poses, feet and star per step, as table T '
      '(xm = 80 + 200 × share; a blow steps 18 in and knocks 12 back)', (
    tester,
  ) async {
    for (final (step, me, them, meX, themX, star) in const [
      (
        TutorialStep.battle,
        BattlePose.attack,
        BattlePose.hit,
        167.0,
        273.0,
        0.75,
      ),
      (
        TutorialStep.excellent,
        BattlePose.attack,
        BattlePose.hit,
        182.0,
        288.0,
        0.95,
      ),
      (
        TutorialStep.average,
        BattlePose.attack,
        BattlePose.idle,
        162.0,
        256.0,
        null,
      ),
      (TutorialStep.fail, BattlePose.idle, BattlePose.idle, 139.0, 251.0, null),
      (
        TutorialStep.combo,
        BattlePose.attack,
        BattlePose.hit,
        182.0,
        288.0,
        0.75,
      ),
      (
        TutorialStep.fever,
        BattlePose.attack,
        BattlePose.hit,
        182.0,
        288.0,
        0.95,
      ),
      (
        TutorialStep.ko,
        BattlePose.win,
        BattlePose.knockedOut,
        164.0,
        296.0,
        null,
      ),
    ]) {
      await show(tester, TutorialGameScene.of(pushUp, step));
      final frame = stage(tester).frame;
      expect(frame.me.pose, me, reason: '$step');
      expect(frame.opponent.pose, them, reason: '$step');
      expect(frame.me.footX, moreOrLessEquals(meX), reason: '$step');
      expect(frame.opponent.footX, moreOrLessEquals(themX), reason: '$step');
      expect(frame.opponent.scaleX, -1, reason: '$step');
      if (star == null) {
        expect(frame.star, isNull, reason: '$step');
      } else {
        expect(
          frame.star!.diameter / BattleStarPainter.width,
          moreOrLessEquals(star),
          reason: '$step',
        );
        expect(frame.star!.rotation, 8, reason: '$step');
      }
    }
  });

  group('the welcome clip (TutShotOnline, 3 s a loop)', () {
    test(
      'down from the top, at the bottom at 950 ms with the blow, back up',
      () {
        final start = TutorialGameScene.online(0);
        expect(start.camera.lineY, 156);
        expect(start.bottom, isFalse);
        expect((start.frame, start.grade, start.myScore), (null, null, 60));
        final bottom = TutorialGameScene.online(950);
        expect(bottom.camera.lineY, 238);
        expect(bottom.bottom, isTrue);
        expect(bottom.frame, BattleFxCameraFrame.good);
        expect((bottom.myScore, bottom.myReps), (60 + rules.goodPoints, 6));
        // The band pops in over 160 ms, the frame stays 720 ms.
        final band = TutorialGameScene.online(950 + 160);
        expect(band.grade, GameGrade.good);
        expect(band.bandOpacity, 1);
        // GOOD alone on the clip's stage.
        expect(band.points, isNull);
        expect(TutorialGameScene.online(950 + 750).frame, isNull);
        // The star shows from 80 ms after the blow.
        expect(TutorialGameScene.online(950 + 100).hit, 1);
        expect(TutorialGameScene.online(950 + 100).starOpacity, 1);
        expect(TutorialGameScene.online(2500).camera.lineY, 156);
      },
    );

    test('the score climbs each loop and starts over every third', () {
      expect(TutorialGameScene.online(3000 + 950).myScore, 80);
      expect(TutorialGameScene.online(6000 + 950).myScore, 90);
      expect(TutorialGameScene.online(9000 + 950).myScore, 70);
      expect(TutorialGameScene.online(0).lead, 15);
    });

    test('the clip\'s own stage (TutShotOnline): GOOD alone at 158, the star '
        'box at 228, the players\' nicknames, the band popping 0.8 wide', () {
      final band = TutorialGameScene.online(950 + 160);
      expect(band.points, isNull);
      expect(band.bandTop, 158);
      expect(band.starTop, 228);
      expect(band.bandNarrow, 0.8);
      expect((band.myName, band.opponentName), ('hellohello', 'squatking'));
      final still = TutorialGameScene.of(pushUp, TutorialStep.good);
      expect((still.bandTop, still.starTop, still.bandNarrow), (150, 222, 1));
      expect((still.myName, still.opponentName), ('나', '상대'));
      // The user attacks from the blow; the opponent is hit from 80 ms.
      final blow = TutorialGameScene.online(950 + 10);
      expect(blow.attacks, isTrue);
      expect(blow.hit, 0);
    });

    testWidgets('drawn: the star from its box at 228, the band narrowed', (
      tester,
    ) async {
      await show(tester, TutorialGameScene.online(950 + 160));
      expect(stage(tester).frame.star!.centerY, 228 + 60);
      expect(stage(tester).state.myName, 'hellohello');
      final narrowed = tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.text('GOOD'),
              matching: find.byType(Transform),
            ),
          )
          .where((t) {
            final m = t.transform.storage;
            return (m[0] - 0.8 * m[5]).abs() < 1e-6 && m[5] != 0;
          });
      expect(narrowed, isNotEmpty);
      expect(find.text('+10'), findsNothing);
    });

    test('the still for reduced motion is just after the blow', () {
      final still = TutorialGameScene.online(TutorialGameScene.welcomeStillMs);
      expect(TutorialGameScene.welcomeStillMs, 1150);
      expect(still.bottom, isTrue);
      expect(still.frame, BattleFxCameraFrame.good);
      expect(still.myScore, 60 + rules.goodPoints);
      // GOOD fully shown and done popping in, the star up at its full size.
      expect(still.grade, GameGrade.good);
      expect(still.bandOpacity, 1);
      expect(still.bandScale, 1);
      expect(still.hit, 1);
      expect(still.starOpacity, 1);
      expect(still.starScale, closeTo(0.9, 1e-9));
      expect(still.attacks, isTrue);
    });
  });
}
