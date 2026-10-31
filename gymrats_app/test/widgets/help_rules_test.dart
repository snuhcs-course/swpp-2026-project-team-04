import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/widgets/help_rules.dart';

void main() {
  test('the base time and fever add up to the battle length', () {
    expect(HelpRules.totalSeconds, battleDuration.inSeconds);
    expect(HelpRules.baseSeconds, greaterThan(0));
    expect(
      HelpRules.baseSeconds + HelpRules.feverSeconds,
      battleDuration.inSeconds,
    );
  });

  test('three pages: the health bar, scoring, then winning safely', () {
    expect(HelpRules.pages.map((page) => page.title), [
      '체력 바 줄다리기',
      '점수는 이렇게 쌓여요',
      '끝까지, 안전하게',
    ]);
    expect(HelpRules.reminders.map((rule) => rule.title), [
      '위험 신호',
      '승패',
      '안전하게',
    ]);
    // Only the danger row is a warning (amber).
    expect(HelpRules.reminders.map((rule) => rule.warning), [
      true,
      false,
      false,
    ]);
  });

  test("the numbers are the game's", () {
    expect(HelpRules.feverSeconds, battleRules.feverLength.inSeconds);
    expect(HelpRules.baseSeconds, battleRules.feverStart.inSeconds);
    expect(HelpRules.feverMultiplier, battleRules.feverMultiplier);
    expect(HelpRules.good, battleRules.goodPoints);
    expect(HelpRules.excellent, battleRules.excellentPoints);
    expect(HelpRules.comboBonus, battleRules.comboBonus);
    expect(
      Duration(milliseconds: (HelpRules.comboSeconds * 1000).round()),
      battleRules.comboWindow,
    );
    expect(HelpRules.koLead, battleRules.koLead);
    expect(HelpRules.dangerLead, battleRules.dangerLead);
  });

  test('every number on the pages comes from the constants', () {
    final [bar, score, safety] = HelpRules.pages;
    expect(bar.body, contains('${HelpRules.koLead}점 차이'));
    expect(bar.points, ['KO ${HelpRules.koLead}점 차']);
    expect(HelpRules.barScore, '+${HelpRules.good}');

    expect(score.body, contains('${HelpRules.comboSeconds}초 안에'));
    expect(score.body, contains('마지막 ${HelpRules.feverSeconds}초'));
    expect(score.body, contains('${HelpRules.feverMultiplier}배'));
    expect(score.points, [
      '${HelpRules.baseSeconds}초부터 ×${HelpRules.feverMultiplier}',
    ]);
    expect(HelpRules.scores, [
      ('+${HelpRules.good}', 'Good'),
      ('+${HelpRules.excellent}', 'Excellent'),
      ('+${HelpRules.comboBonus}', '콤보'),
    ]);
    expect(HelpRules.baseLabel, '기본 ${HelpRules.baseSeconds}초');
    expect(HelpRules.feverLabel, 'FEVER ×${HelpRules.feverMultiplier}');

    expect(safety.body, contains('${HelpRules.totalSeconds}초가 끝나면'));
    expect(safety.points, isEmpty);
    expect(
      HelpRules.reminders.first.body,
      contains('${HelpRules.dangerLead}점 이상'),
    );
  });
}
