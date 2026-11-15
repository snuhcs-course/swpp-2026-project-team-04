import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/viewmodels/tutorial_viewmodel.dart';
import 'package:gymrats_app/widgets/help_rules.dart';

void main() {
  HelpPage words(ExerciseType exercise, TutorialStep step) =>
      HelpRules.of(TutorialPage(exercise, step));

  test('the numbers are the game\'s', () {
    expect(HelpRules.totalSeconds, battleDuration.inSeconds);
    expect(HelpRules.feverSeconds, battleRules.feverLength.inSeconds);
    expect(HelpRules.feverMultiplier, battleRules.feverMultiplier);
    expect(HelpRules.excellent, battleRules.excellentPoints);
    expect(HelpRules.good, battleRules.goodPoints);
    expect(HelpRules.average, battleRules.averagePoints);
    expect(HelpRules.koLead, battleRules.koLead);
    expect(
      HelpRules.feverExcellent,
      battleRules.excellentPoints * battleRules.feverMultiplier,
    );
  });

  test('one set of words per page, in the tutorial\'s order', () {
    expect(HelpRules.order, TutorialViewModel.pagesFor(battleRules));
    expect(HelpRules.pages, hasLength(HelpRules.order.length));
    expect(HelpRules.pages.first.title, '운동으로 겨루는 1:1 대결');
    expect(HelpRules.pages.last.title, '끝나면 리포트를 받아요');
  });

  test('the game page and the combo page, with the rule\'s numbers', () {
    expect(HelpRules.sectionName(null), '게임 소개');
    expect(HelpRules.sectionName(ExerciseType.squat), '스쿼트');
    expect(HelpRules.of(TutorialPage.welcome).body, contains('푸시업이나 스쿼트'));
    expect(HelpRules.comboBonus, battleRules.comboBonus);
    expect(HelpRules.secondsText(const Duration(seconds: 2)), '2');
    expect(HelpRules.secondsText(const Duration(milliseconds: 1500)), '1.5');
    expect(HelpRules.comboSeconds, '1.5');
    for (final exercise in ExerciseType.values) {
      expect(
        words(exercise, TutorialStep.combo).body,
        'Good 이상을 1.5초 안에 이어서 하면 +5점이에요.',
      );
    }
  });

  test('the exercises by name', () {
    expect(HelpRules.exerciseName(ExerciseType.pushUp), '푸시업');
    expect(HelpRules.exerciseName(ExerciseType.squat), '스쿼트');
  });

  test('every page has a title and a body, the grades with their points', () {
    for (final exercise in ExerciseType.values) {
      for (final step in TutorialStep.values) {
        final page = words(exercise, step);
        expect(page.title, isNotEmpty, reason: '$exercise $step');
        expect(page.body, isNotEmpty, reason: '$exercise $step');
      }
    }
    expect(
      words(ExerciseType.pushUp, TutorialStep.excellent).body,
      contains('15점'),
    );
    expect(words(ExerciseType.squat, TutorialStep.good).body, contains('10점'));
    expect(
      words(ExerciseType.pushUp, TutorialStep.average).body,
      contains('5점'),
    );
    expect(
      words(ExerciseType.pushUp, TutorialStep.fever).title,
      '마지막 10초는 피버 타임',
    );
    expect(
      words(ExerciseType.pushUp, TutorialStep.fever).body,
      '모든 점수가 2배로 들어와요.',
    );
    expect(words(ExerciseType.squat, TutorialStep.ko).title, '100점 앞서면 KO 승리');
  });

  test('push-up and squat are told in their own words', () {
    expect(
      words(ExerciseType.squat, TutorialStep.intro).title,
      '스쿼트로 1:1 대결해요',
    );
    expect(
      words(ExerciseType.pushUp, TutorialStep.setup).title,
      '초록 선 안에 몸을 맞춰요',
    );
    expect(
      words(ExerciseType.squat, TutorialStep.setup).title,
      '휴대폰을 보고 서서 준비해요',
    );
    for (final step in [
      TutorialStep.intro,
      TutorialStep.setup,
      TutorialStep.battle,
      TutorialStep.excellent,
      TutorialStep.good,
      TutorialStep.fail,
    ]) {
      expect(
        words(ExerciseType.squat, step),
        isNot(
          predicate<HelpPage>(
            (page) =>
                page.title == words(ExerciseType.pushUp, step).title &&
                page.body == words(ExerciseType.pushUp, step).body,
          ),
        ),
        reason: '$step',
      );
    }
  });
}
