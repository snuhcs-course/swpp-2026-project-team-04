import 'battle_rules.dart';

/// What a floor's rule changes in the score rules.
enum ArcadeRuleKind {
  /// Fever starts this many seconds into the round.
  feverFrom,

  /// A combo rep's bonus points are this many times the default.
  comboBonusTimes,

  /// An excellent rep's points are this many times the default.
  excellentTimes,
}

/// A floor's rule. It only applies to its fight and boss stages, never to a
/// hold stage (arcade spec 1).
class ArcadeFloorRule {
  const ArcadeFloorRule(this.kind, this.value, this.label);

  final ArcadeRuleKind kind;

  /// Seconds for [ArcadeRuleKind.feverFrom], times for the others.
  final int value;

  /// The rule's words on screen, e.g. "피버 15초부터".
  final String label;

  /// [base] with this rule applied; every other value stays as it is. The
  /// times multiply [base]'s own value, so "2배" stays twice the default
  /// when the default changes (arcade spec 4).
  BattleRules applyTo(BattleRules base) => switch (kind) {
    ArcadeRuleKind.feverFrom => _rules(
      base,
      feverStart: Duration(seconds: value),
    ),
    ArcadeRuleKind.comboBonusTimes => _rules(
      base,
      comboBonus: base.comboBonus * value,
    ),
    ArcadeRuleKind.excellentTimes => _rules(
      base,
      excellentPoints: base.excellentPoints * value,
    ),
  };

  static BattleRules _rules(
    BattleRules base, {
    Duration? feverStart,
    int? comboBonus,
    int? excellentPoints,
  }) => BattleRules(
    feverStart: feverStart ?? base.feverStart,
    feverMultiplier: base.feverMultiplier,
    averagePoints: base.averagePoints,
    kneeAverageEnabled: base.kneeAverageEnabled,
    averageMaxElbowAngle: base.averageMaxElbowAngle,
    goodPoints: base.goodPoints,
    excellentPoints: excellentPoints ?? base.excellentPoints,
    excellentDepthRatio: base.excellentDepthRatio,
    comboWindow: base.comboWindow,
    comboBonus: comboBonus ?? base.comboBonus,
    koLead: base.koLead,
    dangerLead: base.dangerLead,
  );
}

/// One arcade floor: a gym with its owner, who judges its two hold stages
/// and plays its boss match (arcade spec 1, 2).
class ArcadeFloor {
  const ArcadeFloor({
    required this.number,
    required this.name,
    required this.owner,
    required this.ownerName,
    this.rule,
  });

  /// From 1 to 4.
  final int number;

  /// The gym's name on screen, e.g. "동네 체육관".
  final String name;

  /// The owner's character id, as in the character rig.
  final String owner;

  /// The owner's name on screen.
  final String ownerName;

  /// The floor's rule; null on 1F, which plays by the default rules.
  final ArcadeFloorRule? rule;

  /// The score rules of the floor's fight and boss stages, for
  /// `BattleViewModel(rules: ...)`.
  BattleRules get rules => rule?.applyTo(battleRules) ?? battleRules;
}
