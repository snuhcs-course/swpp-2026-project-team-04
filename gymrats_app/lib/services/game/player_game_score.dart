import '../../models/battle_rules.dart';
import '../../models/game_score.dart';

/// One player's game score: their points and their combo.
///
/// Rep counts and form feedback stay outside the game; only [validReps] is
/// kept here, to break a tie in points. The battle server scores with this
/// same class from the grades it receives, so it imports only pure Dart.
class PlayerGameScore implements Comparable<PlayerGameScore> {
  PlayerGameScore([this._rules = battleRules]);

  final BattleRules _rules;

  /// Total points.
  int points = 0;

  /// Reps that counted.
  int validReps = 0;

  /// Valid reps in a row so far. 0 before the first and after a rejected rep.
  int combo = 0;

  Duration? _lastValidAt;

  /// Scores a valid rep of [grade] closed at round time [at].
  GameRepScore addValid(GameGrade grade, Duration at) {
    final last = _lastValidAt;
    final isCombo = combo > 0 && last != null && _rules.isCombo(at - last);
    combo = isCombo ? combo + 1 : 1;
    _lastValidAt = at;
    validReps++;
    final fever = _rules.isFever(at);
    final earned = _rules.pointsFor(grade, combo: isCombo, fever: fever);
    points += earned;
    return GameRepScore(
      grade: grade,
      combo: combo,
      fever: fever,
      points: earned,
    );
  }

  /// Scores an average rep closed at round time [at]: it doubles in fever, but
  /// gets no combo bonus, breaks the combo, and is not a valid rep.
  GameRepScore addAverage(Duration at) {
    combo = 0;
    final fever = _rules.isFever(at);
    final earned = _rules.pointsFor(
      GameGrade.average,
      combo: false,
      fever: fever,
    );
    points += earned;
    return GameRepScore(
      grade: GameGrade.average,
      combo: 0,
      fever: fever,
      points: earned,
    );
  }

  /// A rejected rep that is not average scores nothing and breaks the combo.
  void addRejected() => combo = 0;

  /// Scores a judged rep of [grade] closed at round time [at]. A null [grade]
  /// is a rejected rep that earned nothing, and so is its null result.
  GameRepScore? addRep(GameGrade? grade, Duration at) {
    if (grade == null) {
      addRejected();
      return null;
    }
    return grade == GameGrade.average ? addAverage(at) : addValid(grade, at);
  }

  /// Who wins when time is up: more points, then more valid reps. Zero is a
  /// draw.
  @override
  int compareTo(PlayerGameScore other) {
    final byPoints = points.compareTo(other.points);
    return byPoints != 0 ? byPoints : validReps.compareTo(other.validReps);
  }
}
