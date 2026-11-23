import 'arcade_ai_level.dart';
import 'arcade_floor.dart';
import 'arcade_stage.dart';
import 'exercise_type.dart';

/// The arcade's floors and stages (arcade spec 2): the design hand-off
/// `arcade_data.json`, version arcade-1, as Dart constants. Its AI levels
/// are [ArcadeAiLevel]. `test/models/arcade_catalog_test.dart` holds a copy
/// of the JSON and checks every value here against it.
abstract final class ArcadeCatalog {
  /// The version of `arcade_data.json` these constants come from.
  static const version = 'arcade-1';

  /// The floor shown under construction above the last one. It has no
  /// stages.
  static const underConstructionFloor = 5;

  /// The floor of [number], from 1 to 4. Throws a [RangeError] outside that.
  static ArcadeFloor floor(int number) {
    RangeError.checkValueInInterval(number, 1, floors.length, 'number');
    return floors[number - 1];
  }

  /// The stage of [number], from 1 to 24. Throws a [RangeError] outside that.
  static ArcadeStage stage(int number) {
    RangeError.checkValueInInterval(number, 1, stages.length, 'number');
    return stages[number - 1];
  }

  /// The six stages of floor [number], in order. Throws a [RangeError] for a
  /// floor that does not exist.
  static List<ArcadeStage> stagesOn(int number) {
    floor(number);
    return [
      for (final stage in stages)
        if (stage.floor == number) stage,
    ];
  }

  /// The floor [stage] is on.
  static ArcadeFloor floorOf(ArcadeStage stage) => floor(stage.floor);

  static const _win = ArcadeStar(ArcadeStarKind.win, '승리');
  static const _koWin = ArcadeStar(ArcadeStarKind.koWin, 'KO 승리');
  static const _winBothRounds = ArcadeStar(
    ArcadeStarKind.winBothRounds,
    'R1·R2 승리',
  );
  static const _koBothRounds = ArcadeStar(
    ArcadeStarKind.koBothRounds,
    'R1·R2 KO',
  );

  static const floors = <ArcadeFloor>[
    ArcadeFloor(number: 1, name: '동네 체육관', owner: 'seal', ownerName: '물렁범'),
    ArcadeFloor(
      number: 2,
      name: '시립 체육관',
      owner: 'penguin',
      ownerName: '펭뚱이',
      rule: ArcadeFloorRule(ArcadeRuleKind.feverFrom, 15, '피버 15초부터'),
    ),
    ArcadeFloor(
      number: 3,
      name: '복싱장',
      owner: 'kangaroo',
      ownerName: '그루',
      rule: ArcadeFloorRule(ArcadeRuleKind.comboBonusTimes, 2, '콤보 보너스 2배'),
    ),
    ArcadeFloor(
      number: 4,
      name: '국가대표 훈련장',
      owner: 'bear',
      ownerName: '곰탱이',
      rule: ArcadeFloorRule(ArcadeRuleKind.excellentTimes, 2, 'Excellent 2배'),
    ),
  ];

  static const stages = <ArcadeStage>[
    ArcadeFightStage(
      number: 1,
      floor: 1,
      slot: 1,
      character: 'bot',
      exercise: ExerciseType.pushUp,
      aiLevel: ArcadeAiLevel.lv1,
      stars: [
        _win,
        ArcadeStar(ArcadeStarKind.maxRejects, '무효 3회 이하', n: 3),
        _koWin,
      ],
    ),
    ArcadeFightStage(
      number: 2,
      floor: 1,
      slot: 2,
      character: 'penguin',
      exercise: ExerciseType.squat,
      aiLevel: ArcadeAiLevel.lv2,
      stars: [_win, ArcadeStar(ArcadeStarKind.combo, '콤보 4 이상', n: 4), _koWin],
    ),
    ArcadeHoldStage(
      number: 3,
      floor: 1,
      slot: 3,
      character: 'seal',
      pose: HoldPose.plank,
      starSeconds: [15, 20, 30],
      stars: [
        ArcadeStar(ArcadeStarKind.holdSeconds, '15초', n: 15),
        ArcadeStar(ArcadeStarKind.holdSeconds, '20초', n: 20),
        ArcadeStar(ArcadeStarKind.holdSeconds, '30초', n: 30),
      ],
    ),
    ArcadeFightStage(
      number: 4,
      floor: 1,
      slot: 4,
      character: 'mouse',
      exercise: ExerciseType.pushUp,
      aiLevel: ArcadeAiLevel.lv3,
      stars: [
        _win,
        ArcadeStar(ArcadeStarKind.excellent, 'Excellent 2회', n: 2),
        _koWin,
      ],
    ),
    ArcadeHoldStage(
      number: 5,
      floor: 1,
      slot: 5,
      character: 'seal',
      pose: HoldPose.chair,
      starSeconds: [10, 15, 20],
      stars: [
        ArcadeStar(ArcadeStarKind.holdSeconds, '10초', n: 10),
        ArcadeStar(ArcadeStarKind.holdSeconds, '15초', n: 15),
        ArcadeStar(ArcadeStarKind.holdSeconds, '20초', n: 20),
      ],
    ),
    ArcadeBossStage(
      number: 6,
      floor: 1,
      slot: 6,
      character: 'seal',
      aiLevel: ArcadeAiLevel.lv4,
      stars: [
        _winBothRounds,
        ArcadeStar(ArcadeStarKind.bossExcellent, 'Excellent 합계 6회', n: 6),
        _koBothRounds,
      ],
    ),
    ArcadeFightStage(
      number: 7,
      floor: 2,
      slot: 1,
      character: 'kangaroo',
      exercise: ExerciseType.pushUp,
      aiLevel: ArcadeAiLevel.lv5,
      stars: [
        _win,
        ArcadeStar(ArcadeStarKind.maxRejects, '무효 2회 이하', n: 2),
        _koWin,
      ],
    ),
    ArcadeFightStage(
      number: 8,
      floor: 2,
      slot: 2,
      character: 'seal',
      exercise: ExerciseType.squat,
      aiLevel: ArcadeAiLevel.lv6,
      stars: [_win, ArcadeStar(ArcadeStarKind.combo, '콤보 5 이상', n: 5), _koWin],
    ),
    ArcadeHoldStage(
      number: 9,
      floor: 2,
      slot: 3,
      character: 'penguin',
      pose: HoldPose.plank,
      starSeconds: [20, 30, 40],
      stars: [
        ArcadeStar(ArcadeStarKind.holdSeconds, '20초', n: 20),
        ArcadeStar(ArcadeStarKind.holdSeconds, '30초', n: 30),
        ArcadeStar(ArcadeStarKind.holdSeconds, '40초', n: 40),
      ],
    ),
    ArcadeFightStage(
      number: 10,
      floor: 2,
      slot: 4,
      character: 'bear',
      exercise: ExerciseType.pushUp,
      aiLevel: ArcadeAiLevel.lv7,
      stars: [
        _win,
        ArcadeStar(ArcadeStarKind.excellent, 'Excellent 3회', n: 3),
        _koWin,
      ],
    ),
    ArcadeHoldStage(
      number: 11,
      floor: 2,
      slot: 5,
      character: 'penguin',
      pose: HoldPose.chair,
      starSeconds: [15, 20, 30],
      stars: [
        ArcadeStar(ArcadeStarKind.holdSeconds, '15초', n: 15),
        ArcadeStar(ArcadeStarKind.holdSeconds, '20초', n: 20),
        ArcadeStar(ArcadeStarKind.holdSeconds, '30초', n: 30),
      ],
    ),
    ArcadeBossStage(
      number: 12,
      floor: 2,
      slot: 6,
      character: 'penguin',
      aiLevel: ArcadeAiLevel.lv8,
      stars: [
        _winBothRounds,
        ArcadeStar(ArcadeStarKind.bossExcellent, 'Excellent 합계 8회', n: 8),
        _koBothRounds,
      ],
    ),
    ArcadeFightStage(
      number: 13,
      floor: 3,
      slot: 1,
      character: 'bot',
      exercise: ExerciseType.pushUp,
      aiLevel: ArcadeAiLevel.lv9,
      stars: [
        _win,
        ArcadeStar(ArcadeStarKind.maxRejects, '무효 1회 이하', n: 1),
        _koWin,
      ],
    ),
    ArcadeFightStage(
      number: 14,
      floor: 3,
      slot: 2,
      character: 'bear',
      exercise: ExerciseType.squat,
      aiLevel: ArcadeAiLevel.lv10,
      stars: [_win, ArcadeStar(ArcadeStarKind.combo, '콤보 6 이상', n: 6), _koWin],
    ),
    ArcadeHoldStage(
      number: 15,
      floor: 3,
      slot: 3,
      character: 'kangaroo',
      pose: HoldPose.plank,
      starSeconds: [25, 35, 45],
      stars: [
        ArcadeStar(ArcadeStarKind.holdSeconds, '25초', n: 25),
        ArcadeStar(ArcadeStarKind.holdSeconds, '35초', n: 35),
        ArcadeStar(ArcadeStarKind.holdSeconds, '45초', n: 45),
      ],
    ),
    ArcadeFightStage(
      number: 16,
      floor: 3,
      slot: 4,
      character: 'seal',
      exercise: ExerciseType.pushUp,
      aiLevel: ArcadeAiLevel.lv11,
      stars: [
        _win,
        ArcadeStar(ArcadeStarKind.excellent, 'Excellent 4회', n: 4),
        _koWin,
      ],
    ),
    ArcadeHoldStage(
      number: 17,
      floor: 3,
      slot: 5,
      character: 'kangaroo',
      pose: HoldPose.chair,
      starSeconds: [20, 30, 40],
      stars: [
        ArcadeStar(ArcadeStarKind.holdSeconds, '20초', n: 20),
        ArcadeStar(ArcadeStarKind.holdSeconds, '30초', n: 30),
        ArcadeStar(ArcadeStarKind.holdSeconds, '40초', n: 40),
      ],
    ),
    ArcadeBossStage(
      number: 18,
      floor: 3,
      slot: 6,
      character: 'kangaroo',
      aiLevel: ArcadeAiLevel.lv12,
      stars: [
        _winBothRounds,
        ArcadeStar(ArcadeStarKind.bossExcellent, 'Excellent 합계 10회', n: 10),
        _koBothRounds,
      ],
    ),
    ArcadeFightStage(
      number: 19,
      floor: 4,
      slot: 1,
      character: 'penguin',
      exercise: ExerciseType.pushUp,
      aiLevel: ArcadeAiLevel.lv13,
      stars: [
        _win,
        ArcadeStar(ArcadeStarKind.maxRejects, '무효 0회', n: 0),
        _koWin,
      ],
    ),
    ArcadeFightStage(
      number: 20,
      floor: 4,
      slot: 2,
      character: 'mouse',
      exercise: ExerciseType.squat,
      aiLevel: ArcadeAiLevel.lv14,
      stars: [_win, ArcadeStar(ArcadeStarKind.combo, '콤보 7 이상', n: 7), _koWin],
    ),
    ArcadeHoldStage(
      number: 21,
      floor: 4,
      slot: 3,
      character: 'bear',
      pose: HoldPose.plank,
      starSeconds: [30, 45, 60],
      stars: [
        ArcadeStar(ArcadeStarKind.holdSeconds, '30초', n: 30),
        ArcadeStar(ArcadeStarKind.holdSeconds, '45초', n: 45),
        ArcadeStar(ArcadeStarKind.holdSeconds, '60초', n: 60),
      ],
    ),
    ArcadeFightStage(
      number: 22,
      floor: 4,
      slot: 4,
      character: 'kangaroo',
      exercise: ExerciseType.pushUp,
      aiLevel: ArcadeAiLevel.lv15,
      stars: [
        _win,
        ArcadeStar(ArcadeStarKind.excellent, 'Excellent 5회', n: 5),
        _koWin,
      ],
    ),
    ArcadeHoldStage(
      number: 23,
      floor: 4,
      slot: 5,
      character: 'bear',
      pose: HoldPose.chair,
      starSeconds: [25, 35, 45],
      stars: [
        ArcadeStar(ArcadeStarKind.holdSeconds, '25초', n: 25),
        ArcadeStar(ArcadeStarKind.holdSeconds, '35초', n: 35),
        ArcadeStar(ArcadeStarKind.holdSeconds, '45초', n: 45),
      ],
    ),
    ArcadeBossStage(
      number: 24,
      floor: 4,
      slot: 6,
      character: 'bear',
      aiLevel: ArcadeAiLevel.lv16,
      stars: [
        _winBothRounds,
        ArcadeStar(ArcadeStarKind.bossExcellent, 'Excellent 합계 12회', n: 12),
        _koBothRounds,
      ],
    ),
  ];
}
