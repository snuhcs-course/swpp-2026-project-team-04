import 'package:flutter/foundation.dart';

import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/tutorial_page.dart';

/// The tutorial's pages and which one shows: every push-up page, then every
/// squat page, each in the order a battle goes (team chat, 2026-11-14).
///
/// The screen turns the pages and words them; this keeps the order and the
/// place, so a swipe, 이전/다음 and the exercise tabs all agree.
class TutorialViewModel extends ChangeNotifier {
  TutorialViewModel({BattleRules rules = battleRules})
    : pages = pagesFor(rules);

  /// The exercises in the order they are told.
  static const exercises = [ExerciseType.pushUp, ExerciseType.squat];

  /// Every page for [rules], push-ups first.
  static List<TutorialPage> pagesFor(BattleRules rules) => [
    for (final exercise in exercises)
      for (final step in TutorialStep.values)
        if (step != TutorialStep.average || earnsAverage(exercise, rules))
          TutorialPage(exercise, step),
  ];

  /// Whether a rep of [exercise] can be graded average under [rules]. Only
  /// a too-shallow push-up is: the grade is read from the elbow angle, which
  /// the squat judge does not measure (`rep_grade.dart`).
  static bool earnsAverage(ExerciseType exercise, BattleRules rules) =>
      exercise == ExerciseType.pushUp && rules.averagePoints > 0;

  final List<TutorialPage> pages;

  int _index = 0;

  /// The page showing, from 0.
  int get index => _index;

  TutorialPage get page => pages[_index];
  ExerciseType get exercise => page.exercise;
  bool get isFirst => _index == 0;
  bool get isLast => _index == pages.length - 1;

  /// Where [exercise]'s pages start.
  int firstIndexOf(ExerciseType exercise) =>
      pages.indexWhere((page) => page.exercise == exercise);

  /// How many pages [exercise] has.
  int countOf(ExerciseType exercise) =>
      pages.where((page) => page.exercise == exercise).length;

  /// Page [index] as its exercise counts it: (number from 1, count), e.g.
  /// (3, 10) for "푸시업 3 / 10".
  (int, int) positionOf(int index) {
    final exercise = pages[index].exercise;
    return (index - firstIndexOf(exercise) + 1, countOf(exercise));
  }

  /// Shows page [index], kept within the pages. True when it changed.
  bool goTo(int index) {
    final target = index.clamp(0, pages.length - 1);
    if (target == _index) return false;
    _index = target;
    notifyListeners();
    return true;
  }

  bool next() => goTo(_index + 1);
  bool previous() => goTo(_index - 1);

  /// The first page of [exercise], as its tab does.
  bool showExercise(ExerciseType exercise) => goTo(firstIndexOf(exercise));
}
