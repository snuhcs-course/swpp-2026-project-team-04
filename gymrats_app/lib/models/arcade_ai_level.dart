import 'bot_difficulty.dart';

/// How hard the AI plays in an arcade fight or boss stage (arcade spec 2, 3).
///
/// The level only goes up with the stage order: level 1 in the first stage
/// of 1F, level 16 in the 4F boss match. Level 1 plays exactly as
/// [BotDifficulty.beginner]; level 4 counts like [BotDifficulty.intermediate]
/// with a combo chance of 0.10. Each level up adds one rep to both ends of
/// the valid count. The counts are for a round of [BotDifficulty.paceLength],
/// as `BotOpponent.planRound` reads them.
enum ArcadeAiLevel implements BotPace {
  lv1(1, 5, 7, 1, 3, 0, 0),
  lv2(2, 6, 8, 1, 2, 0.05, 0.06),
  lv3(3, 7, 9, 1, 2, 0.05, 0.08),
  lv4(4, 8, 10, 0, 2, 0.1, 0.1),
  lv5(5, 9, 11, 0, 2, 0.1, 0.1),
  lv6(6, 10, 12, 0, 2, 0.15, 0.1),
  lv7(7, 11, 13, 0, 2, 0.15, 0.1),
  lv8(8, 12, 14, 0, 2, 0.2, 0.1),
  lv9(9, 13, 15, 0, 1, 0.2, 0.1),
  lv10(10, 14, 16, 0, 1, 0.25, 0.1),
  lv11(11, 15, 17, 0, 1, 0.25, 0.1),
  lv12(12, 16, 18, 0, 1, 0.3, 0.1),
  lv13(13, 17, 19, 0, 1, 0.3, 0.1),
  lv14(14, 18, 20, 0, 1, 0.35, 0.1),
  lv15(15, 19, 21, 0, 1, 0.35, 0.1),
  lv16(16, 20, 22, 0, 1, 0.4, 0.1);

  const ArcadeAiLevel(
    this.level,
    this.fewestValid,
    this.mostValid,
    this.fewestRejected,
    this.mostRejected,
    this.deepShare,
    this.comboChance,
  );

  /// The level of [level], from 1 to 16. Throws a [RangeError] outside that.
  static ArcadeAiLevel of(int level) {
    RangeError.checkValueInInterval(level, 1, values.length, 'level');
    return values[level - 1];
  }

  /// The number on screen: "LV 1" to "LV 16".
  final int level;

  @override
  final int fewestValid;
  @override
  final int mostValid;
  @override
  final int fewestRejected;
  @override
  final int mostRejected;
  @override
  final double deepShare;
  @override
  final double comboChance;
}
