import '../../models/battle_rules.dart';
import '../../models/game_score.dart';
import '../../models/match_record.dart';
import '../../models/rep_event.dart';
import 'player_game_score.dart';
import 'rep_grade.dart';

/// The game of one battle: the score on each side, the health bar, the KO,
/// and the danger state.
///
/// Feed it each player's judged reps with [RepEvent.at] set to round time
/// (docs/iteration-3/battle-rules.md section 2). The judge's own stopwatch
/// is not round time. Once a KO lands, it takes no more reps.
class BattleGame {
  BattleGame({required this.passDepth, this.rules = battleRules})
    : me = PlayerGameScore(rules),
      opponent = PlayerGameScore(rules);

  /// Depth a valid rep must reach, in the units of [RepEvent.maxDepth].
  final double passDepth;

  final BattleRules rules;
  final PlayerGameScore me;
  final PlayerGameScore opponent;

  /// Scores the user's [rep]. Null when it earned nothing.
  GameRepScore? addMyRep(RepEvent rep) => _add(me, rep);

  /// Scores the opponent's [rep]. Null when it earned nothing.
  GameRepScore? addOpponentRep(RepEvent rep) => _add(opponent, rep);

  GameRepScore? _add(PlayerGameScore player, RepEvent rep) {
    if (isKo) return null;
    return player.addRep(rules.gradeOf(rep, passDepth: passDepth), rep.at);
  }

  /// The user's lead in points; negative while behind.
  int get lead => me.points - opponent.points;

  /// The user's share of the health bar, from 0 to 1.
  double get myBarShare => rules.barShare(lead);

  /// Whether the bar reached an end, which ends the battle.
  bool get isKo => rules.isKo(lead);

  /// Whether the user is about to lose.
  bool get inDanger => rules.inDanger(lead);

  /// How the battle stands for the user: the leader wins.
  MatchOutcome get outcome => switch (me.compareTo(opponent)) {
    > 0 => MatchOutcome.win,
    < 0 => MatchOutcome.lose,
    _ => MatchOutcome.draw,
  };
}
