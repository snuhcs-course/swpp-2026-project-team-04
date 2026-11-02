/// How hard the AI opponent plays. Home asks for it before a bot battle.
///
/// Every number of a level is here, so a level is tuned in one place. The
/// counts are for a round of [paceLength]; a round of another length scales
/// them.
enum BotDifficulty {
  beginner(
    label: '초보',
    summary: '실수가 잦아요',
    fewestValid: 5,
    mostValid: 7,
    fewestRejected: 1,
    mostRejected: 3,
    deepShare: 0,
  ),
  intermediate(
    label: '중수',
    summary: '가끔 콤보',
    fewestValid: 8,
    mostValid: 10,
    mostRejected: 2,
    deepShare: 0.1,
    comboChance: 0.08,
  ),

  /// The bot from before there were levels.
  expert(
    label: '고수',
    summary: '콤보가 많아요',
    fewestValid: 10,
    mostValid: 14,
    mostRejected: 2,
    deepShare: 0.2,
  );

  const BotDifficulty({
    required this.label,
    required this.summary,
    required this.fewestValid,
    required this.mostValid,
    this.fewestRejected = 0,
    required this.mostRejected,
    required this.deepShare,
    this.comboChance = 0,
  });

  /// The round the counts below are for.
  static const paceLength = Duration(seconds: 30);

  /// The level's name on screen.
  final String label;

  /// One line about how this bot plays.
  final String summary;

  /// How many reps count, at the least and at the most.
  final int fewestValid;
  final int mostValid;

  /// How many reps are mistakes, at the least and at the most.
  final int fewestRejected;
  final int mostRejected;

  /// About this share of the valid reps go deep enough to be excellent.
  final double deepShare;

  /// The chance that a valid rep closes right behind a valid one before it.
  ///
  /// Pace alone gives the expert its combos, and hardly any to the slower
  /// levels: this adds some without changing how many reps there are.
  final double comboChance;

  /// The opponent's name on every screen and in the record, so the history
  /// tab tells the levels apart.
  String get opponentName => 'AI 봇 · $label';

  /// [count], stated for [paceLength], in a round of [roundLength].
  static int atPace(int count, Duration roundLength) =>
      (count * roundLength.inMicroseconds / paceLength.inMicroseconds).round();

  /// The valid reps in a round of [roundLength], e.g. "5~7".
  String validRange(Duration roundLength) =>
      '${atPace(fewestValid, roundLength)}~${atPace(mostValid, roundLength)}';
}
