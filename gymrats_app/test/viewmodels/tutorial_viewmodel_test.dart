import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/viewmodels/tutorial_viewmodel.dart';

void main() {
  const pushUp = ExerciseType.pushUp;
  const squat = ExerciseType.squat;

  group('pages', () {
    test('every push-up page, then every squat page, in battle order', () {
      final pages = TutorialViewModel().pages;
      expect(pages, [
        for (final step in TutorialStep.values) TutorialPage(pushUp, step),
        for (final step in TutorialStep.values)
          if (step != TutorialStep.average) TutorialPage(squat, step),
      ]);
      expect(pages, hasLength(19));
    });

    test('a squat has no average page: its grade needs the elbow angle', () {
      expect(TutorialViewModel.earnsAverage(pushUp, battleRules), isTrue);
      expect(TutorialViewModel.earnsAverage(squat, battleRules), isFalse);
    });

    test('with Average turned off, push-ups have no average page either', () {
      const rules = BattleRules(averagePoints: 0);
      expect(TutorialViewModel.earnsAverage(pushUp, rules), isFalse);
      final pages = TutorialViewModel(rules: rules).pages;
      expect(pages.where((page) => page.step == TutorialStep.average), isEmpty);
      expect(pages, hasLength(18));
    });
  });

  group('place', () {
    late TutorialViewModel tutorial;
    late int notified;

    setUp(() {
      tutorial = TutorialViewModel();
      notified = 0;
      tutorial.addListener(() => notified++);
    });

    tearDown(() => tutorial.dispose());

    test('starts on the first push-up page', () {
      expect(tutorial.index, 0);
      expect(tutorial.page, const TutorialPage(pushUp, TutorialStep.intro));
      expect(tutorial.exercise, pushUp);
      expect(tutorial.isFirst, isTrue);
      expect(tutorial.isLast, isFalse);
    });

    test('next and previous turn one page and tell the screen', () {
      expect(tutorial.next(), isTrue);
      expect(tutorial.page.step, TutorialStep.setup);
      expect(tutorial.isFirst, isFalse);
      expect(tutorial.previous(), isTrue);
      expect(tutorial.index, 0);
      expect(notified, 2);
    });

    test('stays within the pages and says nothing when it did not move', () {
      expect(tutorial.previous(), isFalse);
      expect(tutorial.goTo(-5), isFalse);
      expect(tutorial.goTo(0), isFalse);
      expect(notified, 0);

      expect(tutorial.goTo(99), isTrue);
      expect(tutorial.index, tutorial.pages.length - 1);
      expect(tutorial.isLast, isTrue);
      expect(tutorial.page, const TutorialPage(squat, TutorialStep.report));
      expect(tutorial.next(), isFalse);
      expect(notified, 1);
    });

    test('an exercise tab jumps to that exercise\'s first page', () {
      expect(tutorial.showExercise(squat), isTrue);
      expect(tutorial.index, 10);
      expect(tutorial.page, const TutorialPage(squat, TutorialStep.intro));
      expect(tutorial.exercise, squat);
      expect(tutorial.showExercise(squat), isFalse);
      expect(tutorial.showExercise(pushUp), isTrue);
      expect(tutorial.index, 0);
    });

    test('counts pages per exercise, as "푸시업 3 / 10" does', () {
      expect(tutorial.firstIndexOf(pushUp), 0);
      expect(tutorial.firstIndexOf(squat), 10);
      expect(tutorial.countOf(pushUp), 10);
      expect(tutorial.countOf(squat), 9);
      expect(tutorial.positionOf(0), (1, 10));
      expect(tutorial.positionOf(9), (10, 10));
      expect(tutorial.positionOf(10), (1, 9));
      expect(tutorial.positionOf(18), (9, 9));
    });
  });
}
