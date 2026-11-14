import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/help_pictures.dart';
import 'package:gymrats_app/widgets/help_rules.dart';
import 'package:gymrats_app/widgets/pose_silhouette_guide.dart';
import 'package:gymrats_app/widgets/tutorial_rep_bot.dart';

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

  testWidgets('every page draws without errors and is named by its title', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final exercise in ExerciseType.values) {
      for (final step in TutorialStep.values) {
        final page = TutorialPage(exercise, step);
        await show(tester, page);
        expect(tester.takeException(), isNull, reason: '$page');
        expect(
          find.bySemanticsLabel(HelpRules.of(page).title),
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

  testWidgets('squat setup has no guide line', (tester) async {
    await show(tester, const TutorialPage(squat, TutorialStep.setup));
    expect(find.byType(PoseSilhouetteGuide), findsNothing);
    expect(find.text('인식 완료'), findsOneWidget);
    expect(find.text('상대를 기다리는 중…'), findsOneWidget);
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
    expect(find.text('100점 차'), findsOneWidget);
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
  });
}
