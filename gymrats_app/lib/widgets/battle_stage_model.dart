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

/// Where the battle is, as the stage shows it.
enum BattleStagePhase {
  /// Before the start: the players are placing their phones and themselves.
  setup,

  /// Both are ready: counting down to the start.
  countdown,

  /// The round is on.
  playing,

  /// The battle is over; [BattleStageState.end] says how.
  ended,
}

/// Everything the stage shows that is not a one-time event: who plays, the
/// game's standing, and where the battle is. A battle screen builds it from
/// its own state on every change; the stage knows no view model.
class BattleStageState {
  const BattleStageState({
    required this.phase,
    required this.myName,
    required this.opponentName,
    required this.remaining,
    required this.roundLength,
    this.myScore = 0,
    this.opponentScore = 0,
    this.myReps = 0,
    this.opponentReps = 0,
    this.barShare = 0.5,
    this.fever = false,
    this.feverMultiplier = 2,
    this.danger = false,
    this.meReady = false,
    this.opponentReady = false,
    this.countdown,
    this.reconnecting = false,
    this.opponentDisconnected = false,
    this.end,
  });

  final BattleStagePhase phase;
  final String myName;
  final String opponentName;

  /// Time left in the round, and how long the round is.
  final Duration remaining;
  final Duration roundLength;

  final int myScore;
  final int opponentScore;

  /// Valid reps.
  final int myReps;
  final int opponentReps;

  /// The user's share of the health bar, from 0 to 1.
  final double barShare;

  final bool fever;

  /// What fever multiplies points by, for the chip and the band.
  final int feverMultiplier;

  /// Whether the user is far enough behind to lose soon.
  final bool danger;

  /// In [BattleStagePhase.setup]: who has finished setting up.
  final bool meReady;
  final bool opponentReady;

  /// In [BattleStagePhase.countdown]: the time left before the start, exact
  /// to the millisecond.
  final Duration? countdown;

  /// Online: the user's own connection is down and is being restored.
  final bool reconnecting;

  /// Online: the opponent's connection is down, not yet long enough to
  /// count as leaving.
  final bool opponentDisconnected;

  /// How the battle ended; null until it has.
  final BattleStageEnd? end;

  /// The user's lead in points; negative while behind.
  int get lead => myScore - opponentScore;

  /// Whole seconds left, rounded up.
  int get secondsLeft =>
      (remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil();

  /// How much of the round has passed, from 0 to 1.
  double get elapsed {
    if (roundLength <= Duration.zero) return 0;
    final passed = 1 - remaining.inMicroseconds / roundLength.inMicroseconds;
    return passed.clamp(0.0, 1.0);
  }
}

/// What a [BattleStageCue] marks.
enum BattleCueKind {
  /// A blow lands.
  hit,

  /// A swing misses: a rep that earned nothing.
  miss,

  /// The blow that ends the battle by KO lands, or the server reports a KO.
  knockout,

  /// The clock runs out.
  timeUp,

  /// After a time-up, the verdict shows: WIN!, LOSE or DRAW.
  verdict,

  /// A number of the countdown shows: 3, 2, 1.
  countdown,

  /// The round starts: "GO!".
  go,

  /// A player left or stayed disconnected too long.
  playerLeft,
}

/// A moment on the stage that a sound, or a screen reader, can follow. The
/// stage gives each one once, at the moment it shows.
class BattleStageCue {
  const BattleStageCue(this.kind, {this.side, this.grade, this.number});

  final BattleCueKind kind;

  /// Who attacked ([BattleCueKind.hit], [BattleCueKind.miss]) or who won
  /// ([BattleCueKind.knockout], [BattleCueKind.playerLeft],
  /// [BattleCueKind.verdict], where null is a draw); null otherwise.
  final BattleSide? side;

  /// The grade of the rep that landed, for [BattleCueKind.hit], and for a
  /// [BattleCueKind.knockout] that a blow caused.
  final GameGrade? grade;

  /// The number shown, for [BattleCueKind.countdown].
  final int? number;

  @override
  bool operator ==(Object other) =>
      other is BattleStageCue &&
      other.kind == kind &&
      other.side == side &&
      other.grade == grade &&
      other.number == number;

  @override
  int get hashCode => Object.hash(kind, side, grade, number);

  @override
  String toString() => [
    kind.name,
    if (side != null) side!.name,
    if (grade != null) grade!.name,
    if (number != null) '$number',
  ].join(' ');
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
