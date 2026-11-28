import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/services/telemetry/telemetry_service.dart';
import 'package:gymrats_app/viewmodels/tutorial_viewmodel.dart';

void main() {
  const pushUp = ExerciseType.pushUp;
  const squat = ExerciseType.squat;

  group('pages', () {
    test('the two game pages, then every push-up page, then every squat '
        'page, in battle order', () {
      final pages = TutorialViewModel().pages;
      const game = [TutorialStep.welcome, TutorialStep.modes];
      expect(pages, [
        TutorialPage.welcome,
        TutorialPage.modes,
        for (final step in TutorialStep.values)
          if (!game.contains(step)) TutorialPage(pushUp, step),
        for (final step in TutorialStep.values)
          if (!game.contains(step) && step != TutorialStep.average)
            TutorialPage(squat, step),
      ]);
      expect(pages, hasLength(23));
      expect(pages[2], const TutorialPage(pushUp, TutorialStep.intro));
      // Combo comes after the grades and before fever, for both.
      for (final exercise in [pushUp, squat]) {
        final steps = [
          for (final page in pages)
            if (page.exercise == exercise) page.step,
        ];
        expect(
          steps.indexOf(TutorialStep.combo),
          steps.indexOf(TutorialStep.fail) + 1,
        );
        expect(
          steps.indexOf(TutorialStep.fever),
          steps.indexOf(TutorialStep.combo) + 1,
        );
      }
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
      expect(pages, hasLength(22));
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

    test('starts on the page about the game, no exercise yet', () {
      expect(tutorial.index, 0);
      expect(tutorial.page, TutorialPage.welcome);
      expect(tutorial.exercise, isNull);
      expect(tutorial.isFirst, isTrue);
      expect(tutorial.isLast, isFalse);
    });

    test('next and previous turn one page and tell the screen', () {
      expect(tutorial.next(), isTrue);
      expect(tutorial.page, TutorialPage.modes);
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
      expect(tutorial.index, 13);
      expect(tutorial.page, const TutorialPage(squat, TutorialStep.intro));
      expect(tutorial.exercise, squat);
      expect(tutorial.showExercise(squat), isFalse);
      expect(tutorial.showExercise(pushUp), isTrue);
      expect(tutorial.index, 2);
    });

    test('counts pages per exercise, as "푸시업 3 / 11" does', () {
      expect(tutorial.firstIndexOf(pushUp), 2);
      expect(tutorial.firstIndexOf(squat), 13);
      expect(tutorial.countOf(pushUp), 11);
      expect(tutorial.countOf(squat), 10);
      expect(tutorial.positionOf(0), (1, 2));
      expect(tutorial.positionOf(1), (2, 2));
      expect(tutorial.positionOf(2), (1, 11));
      expect(tutorial.positionOf(12), (11, 11));
      expect(tutorial.positionOf(13), (1, 10));
      expect(tutorial.positionOf(22), (10, 10));
    });
  });

  group('튜토리얼 텔레메트리 (P17)', () {
    test('opening records the start with the page count, once', () {
      final telemetry = Telemetry();
      final tutorial = TutorialViewModel(telemetry: telemetry)
        ..open()
        ..open();
      final start = telemetry.pending.single;
      expect(start['event'], 'tutorial_started');
      expect(start['pages_total'], tutorial.pages.length);
      expect(start['pages_total'], 23);
    });

    test('완료 on the last page is completed with that page', () {
      final telemetry = Telemetry();
      final tutorial = TutorialViewModel(telemetry: telemetry)..open();
      tutorial.goTo(tutorial.pages.length - 1);
      tutorial.complete();
      final end = telemetry.pending.last;
      expect(end['event'], 'tutorial_finished');
      expect(end['result'], 'completed');
      expect(end['last_page'], tutorial.pages.length);
      expect(end['attempt_id'], telemetry.pending.first['attempt_id']);
    });

    test('skipping is skipped at the page it was on; the end counts once', () {
      final telemetry = Telemetry();
      final tutorial = TutorialViewModel(telemetry: telemetry)..open();
      tutorial.next();
      tutorial.next();
      tutorial.skip();
      tutorial.dispose();
      final ends = telemetry.pending.where(
        (e) => e['event'] == 'tutorial_finished',
      );
      expect(ends.single['result'], 'skipped');
      expect(ends.single['last_page'], 3);
    });

    test('closing it any other way is skipped', () {
      final telemetry = Telemetry();
      TutorialViewModel(telemetry: telemetry)
        ..open()
        ..dispose();
      expect(telemetry.pending.last['result'], 'skipped');
      expect(telemetry.pending.last['last_page'], 1);
    });

    test('without telemetry, or never opened, nothing is recorded', () {
      final telemetry = Telemetry();
      TutorialViewModel(telemetry: telemetry).dispose();
      expect(telemetry.pending, isEmpty);
      final plain = TutorialViewModel()..open();
      plain.complete();
      plain.dispose();
    });
  });
}
