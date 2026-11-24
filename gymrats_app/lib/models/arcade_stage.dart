import 'arcade_ai_level.dart';
import 'exercise_type.dart';

/// The pose held in a hold stage.
///
/// Not an [ExerciseType]: every switch over the exercises would then need a
/// hold case (arcade spec 1).
enum HoldPose {
  plank('하이 플랭크'),
  chair('의자 자세');

  const HoldPose(this.label);

  final String label;
}

/// What is played in a stage.
enum ArcadeStageKind { fight, hold, boss }

/// What a stage's star asks for. [ArcadeStar.n] holds the number of the
/// ones that have one.
enum ArcadeStarKind {
  /// Fight: win.
  win,

  /// Fight: win by KO.
  koWin,

  /// Fight: win with at most n rejected reps.
  maxRejects,

  /// Fight: win with a longest combo of at least n.
  combo,

  /// Fight: win with at least n excellent reps.
  excellent,

  /// Boss: win both rounds.
  winBothRounds,

  /// Boss: win both rounds with at least n excellent reps in the two.
  bossExcellent,

  /// Boss: win both rounds by KO.
  koBothRounds,

  /// Hold: hold for at least n seconds.
  holdSeconds,
}

/// One of a stage's three stars.
class ArcadeStar {
  const ArcadeStar(this.kind, this.label, {this.n});

  final ArcadeStarKind kind;

  /// The star's number, e.g. 3 for "무효 3회 이하"; null when it has none.
  final int? n;

  /// The star's words on screen.
  final String label;
}

/// One of the 24 arcade stages (arcade spec 2). Each floor plays six, in
/// the same order: fight, fight, hold, fight, hold, boss.
sealed class ArcadeStage {
  const ArcadeStage({
    required this.number,
    required this.floor,
    required this.slot,
    required this.character,
    required this.stars,
  });

  /// From 1 to 24, in the order they open.
  final int number;

  /// From 1 to 4.
  final int floor;

  /// The stage's place on its floor, from 1 to 6.
  final int slot;

  /// The id of the character met there, as in the character rig: the
  /// opponent of a fight, and the floor's owner in a hold or boss stage.
  final String character;

  /// The three stars, from the first.
  final List<ArcadeStar> stars;

  ArcadeStageKind get kind;
}

/// A battle of one exercise against the AI.
final class ArcadeFightStage extends ArcadeStage {
  const ArcadeFightStage({
    required super.number,
    required super.floor,
    required super.slot,
    required super.character,
    required this.exercise,
    required this.aiLevel,
    required super.stars,
  });

  final ExerciseType exercise;

  /// How hard the AI plays: the bot's pace.
  final ArcadeAiLevel aiLevel;

  @override
  ArcadeStageKind get kind => ArcadeStageKind.fight;
}

/// A pose held against the clock, judged by the floor's owner.
final class ArcadeHoldStage extends ArcadeStage {
  const ArcadeHoldStage({
    required super.number,
    required super.floor,
    required super.slot,
    required super.character,
    required this.pose,
    required this.starSeconds,
    required super.stars,
  });

  final HoldPose pose;

  /// The time held that lights each star, from the first, in seconds.
  final List<int> starSeconds;

  /// [starSeconds] as times.
  List<Duration> get starTimes => [
    for (final seconds in starSeconds) Duration(seconds: seconds),
  ];

  /// The stage ends when the time held reaches the third star.
  Duration get endsAt => Duration(seconds: starSeconds.last);

  @override
  ArcadeStageKind get kind => ArcadeStageKind.hold;
}

/// The floor's last stage: two rounds against its owner, at one AI level.
final class ArcadeBossStage extends ArcadeStage {
  const ArcadeBossStage({
    required super.number,
    required super.floor,
    required super.slot,
    required super.character,
    this.rounds = const [ExerciseType.pushUp, ExerciseType.squat],
    required this.aiLevel,
    required super.stars,
  });

  /// The exercise of each round: R1, then R2.
  final List<ExerciseType> rounds;

  /// How hard the AI plays, in both rounds.
  final ArcadeAiLevel aiLevel;

  @override
  ArcadeStageKind get kind => ArcadeStageKind.boss;
}

/// Which of a stage's three stars a play lit. The result shows each one lit
/// or not, so they are kept apart (arcade spec 5).
class ArcadeStars {
  const ArcadeStars(this.first, this.second, this.third);

  /// No star: the stage is not cleared.
  static const none = ArcadeStars(false, false, false);

  final bool first;
  final bool second;
  final bool third;

  /// The three, from the first.
  List<bool> get lit => [first, second, third];

  /// How many are lit, from 0 to 3.
  int get count => lit.where((star) => star).length;

  /// Whether the stage is cleared: one star or more.
  bool get cleared => count > 0;

  @override
  bool operator ==(Object other) =>
      other is ArcadeStars &&
      other.first == first &&
      other.second == second &&
      other.third == third;

  @override
  int get hashCode => Object.hash(first, second, third);

  @override
  String toString() =>
      'ArcadeStars(${[for (final star in lit) star ? '★' : '☆'].join()})';
}
