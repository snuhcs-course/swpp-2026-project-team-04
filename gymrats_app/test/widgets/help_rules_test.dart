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
    expect(HelpRules.of(TutorialPage.welcome).body, '온라인 대결과 아케이드에서 겨뤄요.');
    expect(HelpRules.of(TutorialPage.modes).title, '온라인 대결과 아케이드');
    expect(HelpRules.of(TutorialPage.modes).hasBody, isFalse);
    expect(HelpRules.comboBonus, battleRules.comboBonus);
    expect(HelpRules.secondsText(const Duration(seconds: 2)), '2');
    expect(HelpRules.secondsText(const Duration(milliseconds: 1500)), '1.5');
    expect(HelpRules.comboSeconds, '1.5');
    for (final exercise in ExerciseType.values) {
      expect(
        words(exercise, TutorialStep.combo).body,
        'Good 이상을 1.5초 안에 이어서 하면 +5점.',
      );
    }
  });

  test('the exercises by name', () {
    expect(HelpRules.exerciseName(ExerciseType.pushUp), '푸시업');
    expect(HelpRules.exerciseName(ExerciseType.squat), '스쿼트');
  });

  test('every page has a title and a body but the KO and modes pages, told '
      'by their titles alone; the grades with their points', () {
    for (final exercise in ExerciseType.values) {
      for (final step in TutorialStep.values) {
        final page = words(exercise, step);
        expect(page.title, isNotEmpty, reason: '$exercise $step');
        expect(
          page.hasBody,
          step != TutorialStep.ko && step != TutorialStep.modes,
          reason: '$exercise $step',
        );
        expect(page.body.isNotEmpty, page.hasBody, reason: '$exercise $step');
      }
    }
    expect(words(ExerciseType.pushUp, TutorialStep.ko).body, isEmpty);
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
      '초록 선 안에 몸을 맞춰요',
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

  test('the 23 pages say what the A12 design says (TutX PAGES), with the '
      'A13 page 2', () {
    const design = [
      ('운동으로 겨루는 1:1 대결', '온라인 대결과 아케이드에서 겨뤄요.'),
      ('온라인 대결과 아케이드', ''),
      ('푸시업으로 1:1 대결해요', '30초 동안 상대와 겨뤄요.'),
      ('초록 선 안에 몸을 맞춰요', '선 안에 들어오면 준비 완료예요.'),
      ('점수로 겨루는 대결이에요', '한 번 할 때마다 체력 바가 밀려요.'),
      ('깊게 내려가면 Excellent', '가슴을 바닥 가까이까지 내리면 15점.'),
      ('바른 자세면 Good', '무릎을 떼고 기준 깊이까지 내려가면 10점.'),
      ('조금 얕으면 Average', '기준 깊이에서 조금 모자라면 5점을 줘요.'),
      ('자세가 무너지면 Fail', '무릎을 대거나 너무 얕으면 0점이에요.'),
      ('이어서 하면 콤보', 'Good 이상을 1.5초 안에 이어서 하면 +5점.'),
      ('마지막 10초는 피버 타임', '모든 점수가 2배로 들어와요.'),
      ('100점 앞서면 KO 승리', ''),
      ('끝나면 리포트를 받아요', '캐릭터가 이번 판을 이야기해 줘요.'),
      ('스쿼트로 1:1 대결해요', '30초 대결이에요. Average는 없어요.'),
      ('초록 선 안에 몸을 맞춰요', '두 손을 가슴 앞에 모으고 서요.'),
      ('점수로 겨루는 대결이에요', '한 번 앉을 때마다 체력 바가 밀려요.'),
      ('깊게 앉으면 Excellent', '엉덩이를 충분히 낮추면 15점.'),
      ('바른 자세면 Good', '기준 깊이까지 앉으면 10점.'),
      ('얕게 앉으면 Fail', '기준선보다 얕게 앉으면 0점이에요.'),
      ('이어서 하면 콤보', 'Good 이상을 1.5초 안에 이어서 하면 +5점.'),
      ('마지막 10초는 피버 타임', '모든 점수가 2배로 들어와요.'),
      ('100점 앞서면 KO 승리', ''),
      ('끝나면 리포트를 받아요', '캐릭터가 이번 판을 이야기해 줘요.'),
    ];
    expect(HelpRules.pages, hasLength(design.length));
    expect(
      HelpRules.order.where((p) => p.exercise == ExerciseType.pushUp),
      hasLength(11),
    );
    expect(
      HelpRules.order.where((p) => p.exercise == ExerciseType.squat),
      hasLength(10),
    );
    for (final (index, (title, body)) in design.indexed) {
      expect(
        HelpRules.pages[index].title,
        title,
        reason: '${HelpRules.order[index]}',
      );
      expect(
        HelpRules.pages[index].body,
        body,
        reason: '${HelpRules.order[index]}',
      );
    }
  });

  test(
    'no page names RepBot or the bot (RepBot is one arcade character now)',
    () {
      for (final page in HelpRules.pages) {
        for (final words in [page.title, page.body]) {
          expect(words, isNot(contains('RepBot')), reason: words);
          expect(words, isNot(contains('봇')), reason: words);
        }
      }
    },
  );
}
