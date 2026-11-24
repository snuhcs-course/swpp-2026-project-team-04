import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_floor.dart';
import 'package:gymrats_app/models/battle_rules.dart';

/// Every value of [rules], to compare two of them.
Map<String, Object> _values(BattleRules rules) => {
  'feverStart': rules.feverStart,
  'feverMultiplier': rules.feverMultiplier,
  'averagePoints': rules.averagePoints,
  'kneeAverageEnabled': rules.kneeAverageEnabled,
  'averageMaxElbowAngle': rules.averageMaxElbowAngle,
  'goodPoints': rules.goodPoints,
  'excellentPoints': rules.excellentPoints,
  'excellentDepthRatio': rules.excellentDepthRatio,
  'comboWindow': rules.comboWindow,
  'comboBonus': rules.comboBonus,
  'koLead': rules.koLead,
  'dangerLead': rules.dangerLead,
};

/// The default rules with [changes] made.
Map<String, Object> _defaultsWith(Map<String, Object> changes) => {
  ..._values(battleRules),
  ...changes,
};

void main() {
  group('the score rules of each floor (spec 4)', () {
    test('1F plays by the default rules', () {
      final rules = ArcadeCatalog.floor(1).rules;
      expect(rules, same(battleRules));
    });

    test('2F: fever from 15 s, the rest as by default', () {
      final rules = ArcadeCatalog.floor(2).rules;
      expect(
        _values(rules),
        _defaultsWith({'feverStart': const Duration(seconds: 15)}),
      );
      expect(rules.isFever(const Duration(seconds: 15)), isTrue);
      expect(rules.isFever(const Duration(milliseconds: 14999)), isFalse);
      expect(rules.feverLength, const Duration(seconds: 15));
    });

    test('3F: combo bonus 10, twice the default, the rest as by default', () {
      final rules = ArcadeCatalog.floor(3).rules;
      expect(_values(rules), _defaultsWith({'comboBonus': 10}));
      expect(rules.comboBonus, battleRules.comboBonus * 2);
    });

    test('4F: excellent 30, twice the default, the rest as by default', () {
      final rules = ArcadeCatalog.floor(4).rules;
      expect(_values(rules), _defaultsWith({'excellentPoints': 30}));
      expect(rules.excellentPoints, battleRules.excellentPoints * 2);
    });
  });

  group('a rule applied to other rules', () {
    const base = BattleRules(
      feverStart: Duration(seconds: 25),
      kneeAverageEnabled: false,
      comboBonus: 7,
      excellentPoints: 20,
      koLead: 80,
    );

    test('times multiply the base\'s own value', () {
      expect(
        const ArcadeFloorRule(
          ArcadeRuleKind.comboBonusTimes,
          2,
          '콤보 보너스 2배',
        ).applyTo(base).comboBonus,
        14,
      );
      expect(
        const ArcadeFloorRule(
          ArcadeRuleKind.excellentTimes,
          3,
          'Excellent 3배',
        ).applyTo(base).excellentPoints,
        60,
      );
    });

    test('fever sets its start, and keeps the base\'s other values', () {
      final rules = const ArcadeFloorRule(
        ArcadeRuleKind.feverFrom,
        15,
        '피버 15초부터',
      ).applyTo(base);
      expect(_values(rules), {
        ..._values(base),
        'feverStart': const Duration(seconds: 15),
      });
    });
  });
}
