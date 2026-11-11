import '../models/game_score.dart';
import '../models/rep_event.dart';

/// A player on the battle stage. The user stands on the left and faces right.
enum BattleSide {
  me,
  opponent;

  /// The player on the other side.
  BattleSide get other => this == me ? opponent : me;
}

/// One judged rep, as the stage plays it: an attack that lands, or a swing
/// that misses.
///
/// The stage only shows what the game already decided: [points], [combo] and
/// [fever] come from the game's own score of the rep.
class BattleStageEvent {
  const BattleStageEvent({
    required this.side,
    required this.grade,
    this.points = 0,
    this.combo = 0,
    this.fever = false,
    this.reason,
    this.knockout = false,
  });

  /// Who made the rep.
  final BattleSide side;

  /// The rep's grade; null for a rejected rep that earned nothing.
  final GameGrade? grade;

  /// Points the rep earned.
  final int points;

  /// Valid reps in a row, this one included; 0 for a rep that did not count.
  final int combo;

  /// Whether the rep landed in fever time.
  final bool fever;

  /// Why the rep did not count. Only the user's average and rejected reps
  /// carry one.
  final RejectReason? reason;

  /// Whether this rep pushed the lead to a KO: the ring-out starts when it
  /// lands.
  final bool knockout;

  /// Whether the rep counted as a valid rep: good or excellent.
  bool get counted => grade == GameGrade.good || grade == GameGrade.excellent;
}

/// How a battle ended, as the stage shows it.
enum BattleEndKind {
  /// A lead of the KO size: the loser is knocked off the stage.
  knockout,

  /// The clock ran out.
  timeUp,

  /// A player left or stayed disconnected too long; the other one wins.
  playerLeft,
}

/// The end of a battle on the stage.
class BattleStageEnd {
  const BattleStageEnd({required this.kind, this.winner, this.decided = true});

  final BattleEndKind kind;

  /// Who won; null for a draw, or while the result is not [decided].
  final BattleSide? winner;

  /// False while the clock has run out but the server's result has not come:
  /// the stage shows "TIME!" and waits with the verdict.
  final bool decided;
}

/// The reject sign of a [RejectReason]: its pictogram and its short label.
extension BattleRejectSign on RejectReason {
  /// The pictogram's number in the design (FxIcon), or null when the reason
  /// has no picture: the sign then shows only its label.
  int? get signIcon => switch (this) {
    RejectReason.insufficientDepth => 0,
    RejectReason.incompleteExtension => 1,
    RejectReason.shouldersNotLevel => 2,
    RejectReason.kneesDown => 3,
    RejectReason.armsStraight => 4,
    RejectReason.bellyDown => 5,
    RejectReason.notFloorPushUp => 6,
    RejectReason.phoneMoved => 7,
    RejectReason.shallowSquat => 8,
    RejectReason.standUpFully => 9,
    RejectReason.tooFast => null,
  };

  /// The few letters under the pictogram, e.g. "더 깊게".
  String get signLabel => switch (this) {
    RejectReason.insufficientDepth => '더 깊게',
    RejectReason.incompleteExtension => '팔 펴기',
    RejectReason.shouldersNotLevel => '어깨 수평',
    RejectReason.kneesDown => '무릎 떼기',
    RejectReason.armsStraight => '팔 굽히기',
    RejectReason.bellyDown => '배 떼기',
    RejectReason.notFloorPushUp => '바닥에서',
    RejectReason.phoneMoved => '폰 고정',
    RejectReason.shallowSquat => '더 앉기',
    RejectReason.standUpFully => '끝까지 서기',
    RejectReason.tooFast => '천천히',
  };
}
