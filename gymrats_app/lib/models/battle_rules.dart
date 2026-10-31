import 'game_score.dart';

/// Length of one battle. Screens show it in seconds, e.g. "30초".
const battleDuration = Duration(seconds: 30);

/// Pace bars and time-axis gaps in one round. A 30 s round is 5 s each.
/// A saved 60 s round stays 10 s each, so the bar and tick count holds.
const battleTimeSlices = 6;

/// Every number of the battle game, in one place. To tune the game, change
/// the defaults here. The round length is [battleDuration], above: it stays
/// a constant because other classes use it as a default value.
///
/// The values are the v0.1 proposal in docs/iteration-3/battle-rules.md.
class BattleRules {
  const BattleRules({
    this.feverStart = const Duration(seconds: 20),
    this.feverMultiplier = 2,
    this.averagePoints = 5,
    this.averageMaxElbowAngle = 105,
    this.goodPoints = 10,
    this.excellentPoints = 15,
    this.excellentDepthRatio = 1.6,
    this.comboWindow = const Duration(milliseconds: 1500),
    this.comboBonus = 5,
    this.koLead = 100,
    this.dangerLead = 60,
  });

  /// Round time at which fever begins. It lasts until the end.
  final Duration feverStart;

  /// What fever multiplies a rep's points by.
  final int feverMultiplier;

  /// Points for a [GameGrade.average] rep. 0 turns Average off: an older
  /// server does not know it.
  final int averagePoints;

  /// The most a rep rejected as too shallow may keep of its elbow angle, in
  /// degrees, and still be average. Recorded reps: 90-91 for a normal rep
  /// rejected anyway, 109-135 for going halfway and dropping the head, 169-175
  /// for dropping the head with straight arms (battle-rules.md 3.6).
  final double averageMaxElbowAngle;

  /// Points for a [GameGrade.good] rep.
  final int goodPoints;

  /// Points for a [GameGrade.excellent] rep.
  final int excellentPoints;

  /// How many times the pass depth a rep must reach to be excellent.
  final double excellentDepthRatio;

  /// Longest gap after the last valid rep that still makes a combo.
  final Duration comboWindow;

  /// Extra points for a combo rep, however long the combo is.
  final int comboBonus;

  /// The score lead that pushes the bar to its end and ends the battle.
  final int koLead;

  /// How far behind a player is in danger.
  final int dangerLead;

  /// Lets a depth exactly at the threshold pass: 1.6 x 1.1 is a hair above
  /// 1.76 in floating point.
  static const _depthTolerance = 1e-9;

  /// How long fever lasts.
  Duration get feverLength => battleDuration - feverStart;

  /// Whether round time [at] is in fever.
  bool isFever(Duration at) => at >= feverStart;

  /// The grade of a valid rep. A rep with no measured depth is good.
  GameGrade gradeFor({double? maxDepth, required double passDepth}) {
    if (maxDepth == null) return GameGrade.good;
    return maxDepth >= excellentDepthRatio * passDepth - _depthTolerance
        ? GameGrade.excellent
        : GameGrade.good;
  }

  /// Whether a rep rejected as too shallow is average, by the smallest elbow
  /// angle it reached. An attempt with no measured angle is not.
  bool isAverage(double? minElbowAngle) =>
      averagePoints > 0 &&
      minElbowAngle != null &&
      minElbowAngle <= averageMaxElbowAngle;

  /// Whether a valid rep [gap] after the last valid one is a combo.
  bool isCombo(Duration gap) => gap <= comboWindow;

  /// Points of a rep with a grade.
  int pointsFor(GameGrade grade, {required bool combo, required bool fever}) {
    final base = switch (grade) {
      GameGrade.average => averagePoints,
      GameGrade.good => goodPoints,
      GameGrade.excellent => excellentPoints,
    };
    return (base + (combo ? comboBonus : 0)) * (fever ? feverMultiplier : 1);
  }

  /// The share of the bar on the side of a player leading by [lead], from 0
  /// to 1. Half and half when level.
  double barShare(int lead) => 0.5 + 0.5 * (lead / koLead).clamp(-1.0, 1.0);

  /// Whether [lead], for either side, ends the battle.
  bool isKo(int lead) => lead.abs() >= koLead;

  /// Whether a player leading by [lead] is about to lose.
  bool inDanger(int lead) => lead <= -dangerLead;

  /// How long a round of [roundLength] lasted when a KO ended it after
  /// [played], for the pace in the form report.
  ///
  /// In whole seconds, rounded up past [played]: the KO rep closes at the very
  /// end, and the pace chart only takes reps from before the end.
  static Duration koRoundLength(Duration played, Duration roundLength) {
    final roundedUp = Duration(seconds: played.inSeconds + 1);
    return roundedUp < roundLength ? roundedUp : roundLength;
  }
}

/// The rules every battle plays by.
const battleRules = BattleRules();
