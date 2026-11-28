import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/help_pictures.dart';
import 'package:gymrats_app/widgets/pose_silhouette_guide.dart';
import 'package:gymrats_app/widgets/pose_silhouette_squat.dart';
import 'package:gymrats_app/widgets/tutorial_draft.dart';
import 'package:gymrats_app/widgets/tutorial_figure_painters.dart';
import 'package:gymrats_app/widgets/tutorial_game_shot.dart';
import 'package:gymrats_app/widgets/tutorial_setup_scenes.dart';
import 'package:gymrats_app/widgets/tutorial_modes.dart';
import 'package:gymrats_app/widgets/tutorial_welcome.dart';

void main() {
  Future<void> show(WidgetTester tester, TutorialPage page) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(
          child: SizedBox.fromSize(
            size: const Size(HelpPicture.width, HelpPicture.height),
            child: HelpPicture(page: page),
          ),
        ),
      ),
    );
  }

  const pushUp = ExerciseType.pushUp;
  const squat = ExerciseType.squat;

  testWidgets('every page draws without errors and is named for a screen '
      'reader', (tester) async {
    final handle = tester.ensureSemantics();
    for (final exercise in ExerciseType.values) {
      for (final step in TutorialStep.values) {
        final page = TutorialPage(exercise, step);
        await show(tester, page);
        expect(tester.takeException(), isNull, reason: '$page');
        expect(
          find.bySemanticsLabel(HelpPicture.labelOf(page)),
          findsOneWidget,
          reason: '$page',
        );
      }
    }
    handle.dispose();
  });

  testWidgets('push-up setup: outside the line waits, inside is ready', (
    tester,
  ) async {
    await show(tester, const TutorialPage(pushUp, TutorialStep.setup));
    final guides = tester
        .widgetList<PoseSilhouetteGuide>(find.byType(PoseSilhouetteGuide))
        .map((guide) => guide.ready);
    expect(guides, [false, true]);
    expect(find.text('선 밖이면 대기'), findsOneWidget);
    expect(find.text('선 안 = 준비 완료'), findsOneWidget);
  });

  testWidgets('squat setup: the standing guide, outside then inside', (
    tester,
  ) async {
    await show(tester, const TutorialPage(squat, TutorialStep.setup));
    expect(find.byType(PoseSilhouetteGuide), findsNothing);
    expect(
      tester
          .widgetList<StandingSilhouetteGuide>(
            find.byType(StandingSilhouetteGuide),
          )
          .map((guide) => guide.ready),
      [false, true],
    );
    expect(find.byType(TutorialSetupCameras), findsOneWidget);
  });

  testWidgets('page 1 shows a person doing the exercise in front of the '
      'phone on the wall, as a silhouette', (tester) async {
    for (final exercise in ExerciseType.values) {
      await show(tester, TutorialPage(exercise, TutorialStep.intro));
      final scene = tester.widget<TutorialWallScene>(
        find.byType(TutorialWallScene),
      );
      expect(scene.squat, exercise == squat);
      expect(find.byType(TutorialSidePerson), findsOneWidget);
    }
  });

  test('pages 1 and 2 are named as the design names their pictures', () {
    expect(
      HelpPicture.labelOf(const TutorialPage(pushUp, TutorialStep.intro)),
      '벽에 기대어 세운 폰 앞에서 푸시업을 하는 그림',
    );
    expect(
      HelpPicture.labelOf(const TutorialPage(squat, TutorialStep.intro)),
      '벽에 기대어 세운 폰 앞에서 두 손을 모으고 스쿼트를 하는 그림',
    );
    expect(
      HelpPicture.labelOf(const TutorialPage(pushUp, TutorialStep.setup)),
      '왼쪽은 몸이 선 밖이라 흰 선, 오른쪽은 몸이 선 안에 들어와 초록 선이 된 카메라 화면',
    );
    expect(
      HelpPicture.labelOf(const TutorialPage(squat, TutorialStep.setup)),
      '왼쪽은 몸이 선 밖이라 흰 선, 오른쪽은 두 손을 가슴 앞에 모으고 선 안에 '
      '들어와 초록 선이 된 카메라 화면',
    );
  });

  testWidgets('the battle, combo, fever and KO pages are way a: the game '
      'screen on a phone and its marks made large', (tester) async {
    for (final exercise in ExerciseType.values) {
      for (final step in const [
        TutorialStep.battle,
        TutorialStep.combo,
        TutorialStep.fever,
        TutorialStep.ko,
      ]) {
        await show(tester, TutorialPage(exercise, step));
        final zoom = tester.widget<TutorialPhoneZoom>(
          find.byType(TutorialPhoneZoom),
        );
        expect((zoom.exercise, zoom.step), (exercise, step));
        final shot = tester.widget<TutorialGameShot>(
          find.byType(TutorialGameShot),
        );
        expect(shot.scene.squat, exercise == squat, reason: '$step');
        expect(find.byType(TutorialPersonBubble), findsNothing);
      }
    }
  });

  testWidgets('the grade pages are way b: the person at the grade\'s depth '
      'and the game screen in a bubble', (tester) async {
    for (final exercise in ExerciseType.values) {
      for (final step in const [
        TutorialStep.excellent,
        TutorialStep.good,
        TutorialStep.average,
        TutorialStep.fail,
      ]) {
        if (exercise == squat && step == TutorialStep.average) continue;
        await show(tester, TutorialPage(exercise, step));
        final bubble = tester.widget<TutorialPersonBubble>(
          find.byType(TutorialPersonBubble),
        );
        expect((bubble.exercise, bubble.step), (exercise, step));
        expect(find.byType(TutorialGameShot), findsOneWidget);
      }
    }
  });

  test('the battle and grade pages are named as the design names way a and '
      'way b', () {
    expect(
      HelpPicture.labelOf(const TutorialPage(pushUp, TutorialStep.ko)),
      '왼쪽은 그 순간의 게임 화면 전체, 오른쪽은 그 화면에서 눈여겨볼 표시를 크게 보여 줌',
    );
    expect(
      HelpPicture.labelOf(const TutorialPage(squat, TutorialStep.good)),
      '사람이 벽에 기댄 폰 앞에서 스쿼트를 하고, 폰 위 말풍선에 그때의 게임 장면',
    );
    expect(
      HelpPicture.labelOf(const TutorialPage(pushUp, TutorialStep.fail)),
      '사람이 벽에 기댄 폰 앞에서 푸시업을 하고, 폰 위 말풍선에 그때의 게임 장면',
    );
  });

  testWidgets('the game page shows the online battle playing and the arcade '
      'map; the report pages a character talking', (tester) async {
    await show(tester, TutorialPage.welcome);
    expect(find.byType(TutorialWelcome), findsOneWidget);
    expect(find.byType(TutorialOnlineClip), findsOneWidget);
    expect(find.byType(TutorialArcadeShot), findsOneWidget);
    for (final exercise in ExerciseType.values) {
      await show(tester, TutorialPage(exercise, TutorialStep.report));
      expect(find.byType(TutorialCoachTalk), findsOneWidget);
    }
  });

  testWidgets('game page 2 shows the online battle and arcade picture, '
      'named as the A13 design names it, on the taller board', (tester) async {
    await show(tester, TutorialPage.modes);
    expect(find.byType(TutorialModes), findsOneWidget);
    expect(HelpPicture.labelOf(TutorialPage.modes), TutorialModes.label);
    expect(
      HelpPicture.sizeOf(TutorialPage.modes),
      const Size(HelpPicture.width, HelpPicture.welcomeHeight),
    );
  });

  test('the game page and the report are named as the design names them '
      '(the report\'s particle fitted)', () {
    expect(
      HelpPicture.labelOf(TutorialPage.welcome),
      '온라인 대결 게임 중 화면과 아케이드 지도 화면 스크린샷',
    );
    for (final exercise in ExerciseType.values) {
      expect(
        HelpPicture.labelOf(TutorialPage(exercise, TutorialStep.report)),
        startsWith('물렁범이 대화창에서'),
      );
    }
  });

  test('nothing draws the RepBot mannequin any more: its file is gone and '
      'no app file names it', () {
    expect(File('lib/widgets/tutorial_rep_bot.dart').existsSync(), isFalse);
    final users = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            RegExp(
              r'TutorialRepBot|tutorial_rep_bot|RepBotFigure|RepBotPainter',
            ).hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(users, isEmpty);
  });
}
