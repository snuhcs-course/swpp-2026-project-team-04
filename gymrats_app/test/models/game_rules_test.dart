import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/game_score.dart';

void main() {
  const rules = BattleRules();

  test('the defaults are the v0.1 numbers in battle-rules.md', () {
    expect(battleDuration, const Duration(seconds: 30));
    expect(battleRules.feverStart, const Duration(seconds: 20));
    expect(battleRules.feverLength, const Duration(seconds: 10));
    expect(battleRules.feverMultiplier, 2);
    expect(battleRules.averagePoints, 5);
    expect(battleRules.averageMaxElbowAngle, 105);
    expect(battleRules.goodPoints, 10);
    expect(battleRules.excellentPoints, 15);
    expect(battleRules.excellentDepthRatio, 1.6);
    expect(battleRules.comboWindow, const Duration(milliseconds: 1500));
    expect(battleRules.comboBonus, 5);
    expect(battleRules.koLead, 100);
    expect(battleRules.dangerLead, 60);
  });

  test(
    'a KO round length is the time played rounded up, at most the round',
    () {
      Duration length(int playedMs) => BattleRules.koRoundLength(
        Duration(milliseconds: playedMs),
        battleDuration,
      );
      expect(length(23400), const Duration(seconds: 24));
      // Exactly on a second still moves past it: the KO rep closed there.
      expect(length(23000), const Duration(seconds: 24));
      expect(length(29500), battleDuration);
      expect(length(30000), battleDuration);
    },
  );

  test('fever begins exactly at its start time', () {
    expect(rules.isFever(const Duration(milliseconds: 19999)), isFalse);
    expect(rules.isFever(const Duration(seconds: 20)), isTrue);
    expect(rules.isFever(const Duration(seconds: 30)), isTrue);
  });

  group('grade', () {
    test('a push-up at 1.6 times the pass depth is excellent', () {
      expect(
        rules.gradeFor(maxDepth: 1.76, passDepth: 1.1),
        GameGrade.excellent,
      );
      expect(rules.gradeFor(maxDepth: 1.75, passDepth: 1.1), GameGrade.good);
    });

    test('a squat is graded by its own pass depth', () {
      expect(
        rules.gradeFor(maxDepth: 1.2, passDepth: 0.75),
        GameGrade.excellent,
      );
      expect(rules.gradeFor(maxDepth: 1.19, passDepth: 0.75), GameGrade.good);
    });

    test('a rep with no measured depth is good', () {
      expect(rules.gradeFor(passDepth: 1.1), GameGrade.good);
    });
  });

  group('average', () {
    test('an elbow angle up to 105 degrees is average', () {
      expect(rules.isAverage(90), isTrue);
      expect(rules.isAverage(91), isTrue);
      expect(rules.isAverage(105), isTrue);
    });

    test('the recorded cheats are not: above 105, or no angle', () {
      expect(rules.isAverage(105.01), isFalse);
      expect(rules.isAverage(109), isFalse);
      expect(rules.isAverage(135), isFalse);
      expect(rules.isAverage(169), isFalse);
      expect(rules.isAverage(null), isFalse);
    });

    test('no points turn it off', () {
      expect(const BattleRules(averagePoints: 0).isAverage(90), isFalse);
    });

    test('its numbers come from the config', () {
      const tuned = BattleRules(averagePoints: 7, averageMaxElbowAngle: 120);
      expect(tuned.isAverage(120), isTrue);
      expect(tuned.pointsFor(GameGrade.average, combo: false, fever: false), 7);
    });
  });

  test('a combo gap includes the window itself', () {
    expect(rules.isCombo(const Duration(milliseconds: 1500)), isTrue);
    expect(rules.isCombo(const Duration(milliseconds: 1501)), isFalse);
  });

  test('points follow the table in battle-rules.md 3.5', () {
    int points(GameGrade grade, bool combo, bool fever) =>
        rules.pointsFor(grade, combo: combo, fever: fever);
    expect(points(GameGrade.average, false, false), 5);
    expect(points(GameGrade.average, false, true), 10);
    expect(points(GameGrade.good, false, false), 10);
    expect(points(GameGrade.good, true, false), 15);
    expect(points(GameGrade.excellent, false, false), 15);
    expect(points(GameGrade.excellent, true, false), 20);
    expect(points(GameGrade.good, false, true), 20);
    expect(points(GameGrade.good, true, true), 30);
    expect(points(GameGrade.excellent, false, true), 30);
    expect(points(GameGrade.excellent, true, true), 40);
  });

  test('the bar moves half a percent a point and stops at its ends', () {
    expect(rules.barShare(0), 0.5);
    expect(rules.barShare(10), closeTo(0.55, 1e-9));
    expect(rules.barShare(-60), closeTo(0.2, 1e-9));
    expect(rules.barShare(100), 1);
    expect(rules.barShare(-125), 0);
  });

  test('a KO needs the full lead, on either side', () {
    expect(rules.isKo(99), isFalse);
    expect(rules.isKo(100), isTrue);
    expect(rules.isKo(-99), isFalse);
    expect(rules.isKo(-100), isTrue);
  });

  test('danger starts at the full deficit, and never while ahead', () {
    expect(rules.inDanger(-59), isFalse);
    expect(rules.inDanger(-60), isTrue);
    expect(rules.inDanger(60), isFalse);
  });

  test('another config changes the game with no other change', () {
    const tuned = BattleRules(
      goodPoints: 20,
      comboBonus: 1,
      koLead: 40,
      dangerLead: 10,
      feverMultiplier: 3,
    );
    expect(tuned.pointsFor(GameGrade.good, combo: true, fever: true), 63);
    expect(tuned.barShare(20), closeTo(0.75, 1e-9));
    expect(tuned.isKo(40), isTrue);
    expect(tuned.inDanger(-10), isTrue);
  });

  test('grades have the labels the battle shows', () {
    expect(GameGrade.average.label, 'Average');
    expect(GameGrade.good.label, 'Good');
    expect(GameGrade.excellent.label, 'Excellent');
  });
}
