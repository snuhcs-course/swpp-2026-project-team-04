import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/help_pictures.dart';
import 'package:gymrats_app/widgets/help_rules.dart';
import 'package:gymrats_app/widgets/pose_silhouette_guide.dart';
import 'package:gymrats_app/widgets/pose_silhouette_squat.dart';
import 'package:gymrats_app/widgets/tutorial_figure_painters.dart';
import 'package:gymrats_app/widgets/tutorial_rep_bot.dart';
import 'package:gymrats_app/widgets/tutorial_setup_scenes.dart';

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

  RepBotPainter repBot(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(TutorialRepBot),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as RepBotPainter;

  testWidgets('the grades show RepBot deeper for a better grade', (
    tester,
  ) async {
    for (final (step, label) in [
      (TutorialStep.excellent, 'EXCELLENT +15'),
      (TutorialStep.good, 'GOOD +10'),
      (TutorialStep.average, 'AVERAGE +5'),
      (TutorialStep.fail, 'FAIL 0점'),
    ]) {
      await show(tester, TutorialPage(pushUp, step));
      expect(find.text(label), findsOneWidget);
      expect(repBot(tester).figure, RepBotFigure.pushUpSide);
      expect(repBot(tester).depth, HelpPicture.gradeDepth[step]);
      expect(repBot(tester).passDepth, isNull);
    }
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('a squat grade shows RepBot from the front with the pass line', (
    tester,
  ) async {
    await show(tester, const TutorialPage(squat, TutorialStep.good));
    expect(repBot(tester).figure, RepBotFigure.squatFront);
    expect(repBot(tester).depth, 0.75);
    expect(repBot(tester).passDepth, HelpPicture.squatPassDepth);
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
      expect(find.byType(TutorialRepBot), findsNothing);
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

  testWidgets('the battle pages use the stage\'s characters', (tester) async {
    await show(tester, const TutorialPage(pushUp, TutorialStep.battle));
    final ids = tester
        .widgetList<CharacterFigure>(find.byType(CharacterFigure))
        .map((figure) => figure.characterId);
    expect(ids, ['mouse', 'seal']);
    expect(find.text('+10'), findsOneWidget);

    await show(tester, const TutorialPage(squat, TutorialStep.fever));
    expect(
      tester
          .widgetList<CharacterFigure>(find.byType(CharacterFigure))
          .map((figure) => figure.characterId),
      ['penguin', 'kangaroo'],
    );
    expect(
      find.text('FEVER TIME ×${HelpRules.feverMultiplier}'),
      findsOneWidget,
    );
    expect(find.text('+30'), findsOneWidget);

    await show(tester, const TutorialPage(squat, TutorialStep.ko));
    expect(find.text('K.O.!'), findsOneWidget);
    // The scores are koLead apart, as the label says, and the bar is full.
    expect(find.text('${HelpRules.koLead}점 차'), findsOneWidget);
    expect(find.text('${HelpPicture.koLoserScore}'), findsOneWidget);
    expect(
      find.text('${HelpPicture.koLoserScore + HelpRules.koLead}'),
      findsOneWidget,
    );
    int barFlex(Color color) => tester
        .widget<Expanded>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Expanded &&
                widget.child is ColoredBox &&
                (widget.child as ColoredBox).color == color,
          ),
        )
        .flex;
    expect(barFlex(AppColors.accent), 100);
    expect(barFlex(AppColors.opponent), 0);
  });

  testWidgets('the game page shows RepBot squatting and doing a push-up', (
    tester,
  ) async {
    await show(tester, TutorialPage.welcome);
    final figures = tester
        .widgetList<TutorialRepBot>(find.byType(TutorialRepBot))
        .map((repBot) => repBot.figure);
    expect(figures, [RepBotFigure.squatFront, RepBotFigure.pushUpSide]);
    expect(find.text('1:1 대결'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the combo page adds the bonus to a rep within the window', (
    tester,
  ) async {
    for (final exercise in ExerciseType.values) {
      await show(tester, TutorialPage(exercise, TutorialStep.combo));
      expect(find.text('+${HelpRules.good}'), findsOneWidget);
      expect(find.text('COMBO +${HelpRules.comboBonus}'), findsOneWidget);
      expect(find.text('${HelpRules.comboSeconds}초 안에 다음 동작'), findsOneWidget);
      expect(
        tester
            .widgetList<CharacterFigure>(find.byType(CharacterFigure))
            .map((figure) => figure.characterId),
        [
          HelpPicture.charactersOf(exercise).$1,
          HelpPicture.charactersOf(exercise).$2,
        ],
      );
    }
  });

  testWidgets('the report shows the way to the form feedback', (tester) async {
    await show(tester, const TutorialPage(pushUp, TutorialStep.report));
    expect(find.text('자세 피드백 보기'), findsOneWidget);
    expect(find.text('Average'), findsOneWidget);
    await show(tester, const TutorialPage(squat, TutorialStep.report));
    expect(find.text('Average'), findsNothing);
    expect(find.text('무효'), findsOneWidget);
  });

  test('each exercise has its own pair of characters', () {
    expect(HelpPicture.charactersOf(pushUp), ('mouse', 'seal'));
    expect(HelpPicture.charactersOf(squat), ('penguin', 'kangaroo'));
    expect(HelpPicture.charactersOf(null), ('mouse', 'seal'));
  });
}
