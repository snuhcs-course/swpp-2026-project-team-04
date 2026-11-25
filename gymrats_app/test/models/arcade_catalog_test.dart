import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_ai_level.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_floor.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/models/exercise_type.dart';

/// A copy of the design hand-off `arcade_data.json` (version arcade-1,
/// 2026-11-23), the source of every value in [ArcadeCatalog] and
/// [ArcadeAiLevel]. Only the line breaks differ from the file: one line per
/// floor, stage and AI level.
const _arcadeDataJson = r'''
{
 "version": "arcade-1",
 "date": "2026-11-23",
 "characters": {"bot": "RepBot", "seal": "물렁범", "penguin": "펭뚱이", "mouse": "GYM마우스", "kangaroo": "그루", "bear": "곰탱이"},
 "floors": [
  {"floor": 1, "name": "동네 체육관", "owner": "seal", "ownerName": "물렁범", "rule": null},
  {"floor": 2, "name": "시립 체육관", "owner": "penguin", "ownerName": "펭뚱이", "rule": {"kind": "feverFrom", "seconds": 15, "label": "피버 15초부터"}},
  {"floor": 3, "name": "복싱장", "owner": "kangaroo", "ownerName": "그루", "rule": {"kind": "comboBonusTimes", "times": 2, "label": "콤보 보너스 2배"}},
  {"floor": 4, "name": "국가대표 훈련장", "owner": "bear", "ownerName": "곰탱이", "rule": {"kind": "excellentTimes", "times": 2, "label": "Excellent 2배"}}
 ],
 "underConstructionFloor": 5,
 "stages": [
  {"stage": 1, "floor": 1, "slot": 1, "kind": "fight", "character": "bot", "exercise": "pushUp", "aiLevel": 1, "stars": [{"kind": "win", "label": "승리"}, {"kind": "maxRejects", "n": 3, "label": "무효 3회 이하"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 2, "floor": 1, "slot": 2, "kind": "fight", "character": "penguin", "exercise": "squat", "aiLevel": 2, "stars": [{"kind": "win", "label": "승리"}, {"kind": "combo", "n": 4, "label": "콤보 4 이상"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 3, "floor": 1, "slot": 3, "kind": "hold", "character": "seal", "hold": "plank", "starSeconds": [15, 20, 30], "stars": [{"kind": "holdSeconds", "n": 15, "label": "15초"}, {"kind": "holdSeconds", "n": 20, "label": "20초"}, {"kind": "holdSeconds", "n": 30, "label": "30초"}]},
  {"stage": 4, "floor": 1, "slot": 4, "kind": "fight", "character": "mouse", "exercise": "pushUp", "aiLevel": 3, "stars": [{"kind": "win", "label": "승리"}, {"kind": "excellent", "n": 2, "label": "Excellent 2회"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 5, "floor": 1, "slot": 5, "kind": "hold", "character": "seal", "hold": "chair", "starSeconds": [10, 15, 20], "stars": [{"kind": "holdSeconds", "n": 10, "label": "10초"}, {"kind": "holdSeconds", "n": 15, "label": "15초"}, {"kind": "holdSeconds", "n": 20, "label": "20초"}]},
  {"stage": 6, "floor": 1, "slot": 6, "kind": "boss", "character": "seal", "rounds": ["pushUp", "squat"], "aiLevel": 4, "stars": [{"kind": "winBothRounds", "label": "R1·R2 승리"}, {"kind": "bossExcellent", "n": 6, "label": "Excellent 합계 6회"}, {"kind": "koBothRounds", "label": "R1·R2 KO"}]},
  {"stage": 7, "floor": 2, "slot": 1, "kind": "fight", "character": "kangaroo", "exercise": "pushUp", "aiLevel": 5, "stars": [{"kind": "win", "label": "승리"}, {"kind": "maxRejects", "n": 2, "label": "무효 2회 이하"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 8, "floor": 2, "slot": 2, "kind": "fight", "character": "seal", "exercise": "squat", "aiLevel": 6, "stars": [{"kind": "win", "label": "승리"}, {"kind": "combo", "n": 5, "label": "콤보 5 이상"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 9, "floor": 2, "slot": 3, "kind": "hold", "character": "penguin", "hold": "plank", "starSeconds": [20, 30, 40], "stars": [{"kind": "holdSeconds", "n": 20, "label": "20초"}, {"kind": "holdSeconds", "n": 30, "label": "30초"}, {"kind": "holdSeconds", "n": 40, "label": "40초"}]},
  {"stage": 10, "floor": 2, "slot": 4, "kind": "fight", "character": "bear", "exercise": "pushUp", "aiLevel": 7, "stars": [{"kind": "win", "label": "승리"}, {"kind": "excellent", "n": 3, "label": "Excellent 3회"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 11, "floor": 2, "slot": 5, "kind": "hold", "character": "penguin", "hold": "chair", "starSeconds": [15, 20, 30], "stars": [{"kind": "holdSeconds", "n": 15, "label": "15초"}, {"kind": "holdSeconds", "n": 20, "label": "20초"}, {"kind": "holdSeconds", "n": 30, "label": "30초"}]},
  {"stage": 12, "floor": 2, "slot": 6, "kind": "boss", "character": "penguin", "rounds": ["pushUp", "squat"], "aiLevel": 8, "stars": [{"kind": "winBothRounds", "label": "R1·R2 승리"}, {"kind": "bossExcellent", "n": 8, "label": "Excellent 합계 8회"}, {"kind": "koBothRounds", "label": "R1·R2 KO"}]},
  {"stage": 13, "floor": 3, "slot": 1, "kind": "fight", "character": "bot", "exercise": "pushUp", "aiLevel": 9, "stars": [{"kind": "win", "label": "승리"}, {"kind": "maxRejects", "n": 1, "label": "무효 1회 이하"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 14, "floor": 3, "slot": 2, "kind": "fight", "character": "bear", "exercise": "squat", "aiLevel": 10, "stars": [{"kind": "win", "label": "승리"}, {"kind": "combo", "n": 6, "label": "콤보 6 이상"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 15, "floor": 3, "slot": 3, "kind": "hold", "character": "kangaroo", "hold": "plank", "starSeconds": [25, 35, 45], "stars": [{"kind": "holdSeconds", "n": 25, "label": "25초"}, {"kind": "holdSeconds", "n": 35, "label": "35초"}, {"kind": "holdSeconds", "n": 45, "label": "45초"}]},
  {"stage": 16, "floor": 3, "slot": 4, "kind": "fight", "character": "seal", "exercise": "pushUp", "aiLevel": 11, "stars": [{"kind": "win", "label": "승리"}, {"kind": "excellent", "n": 4, "label": "Excellent 4회"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 17, "floor": 3, "slot": 5, "kind": "hold", "character": "kangaroo", "hold": "chair", "starSeconds": [20, 30, 40], "stars": [{"kind": "holdSeconds", "n": 20, "label": "20초"}, {"kind": "holdSeconds", "n": 30, "label": "30초"}, {"kind": "holdSeconds", "n": 40, "label": "40초"}]},
  {"stage": 18, "floor": 3, "slot": 6, "kind": "boss", "character": "kangaroo", "rounds": ["pushUp", "squat"], "aiLevel": 12, "stars": [{"kind": "winBothRounds", "label": "R1·R2 승리"}, {"kind": "bossExcellent", "n": 10, "label": "Excellent 합계 10회"}, {"kind": "koBothRounds", "label": "R1·R2 KO"}]},
  {"stage": 19, "floor": 4, "slot": 1, "kind": "fight", "character": "penguin", "exercise": "pushUp", "aiLevel": 13, "stars": [{"kind": "win", "label": "승리"}, {"kind": "maxRejects", "n": 0, "label": "무효 0회"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 20, "floor": 4, "slot": 2, "kind": "fight", "character": "mouse", "exercise": "squat", "aiLevel": 14, "stars": [{"kind": "win", "label": "승리"}, {"kind": "combo", "n": 7, "label": "콤보 7 이상"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 21, "floor": 4, "slot": 3, "kind": "hold", "character": "bear", "hold": "plank", "starSeconds": [30, 45, 60], "stars": [{"kind": "holdSeconds", "n": 30, "label": "30초"}, {"kind": "holdSeconds", "n": 45, "label": "45초"}, {"kind": "holdSeconds", "n": 60, "label": "60초"}]},
  {"stage": 22, "floor": 4, "slot": 4, "kind": "fight", "character": "kangaroo", "exercise": "pushUp", "aiLevel": 15, "stars": [{"kind": "win", "label": "승리"}, {"kind": "excellent", "n": 5, "label": "Excellent 5회"}, {"kind": "koWin", "label": "KO 승리"}]},
  {"stage": 23, "floor": 4, "slot": 5, "kind": "hold", "character": "bear", "hold": "chair", "starSeconds": [25, 35, 45], "stars": [{"kind": "holdSeconds", "n": 25, "label": "25초"}, {"kind": "holdSeconds", "n": 35, "label": "35초"}, {"kind": "holdSeconds", "n": 45, "label": "45초"}]},
  {"stage": 24, "floor": 4, "slot": 6, "kind": "boss", "character": "bear", "rounds": ["pushUp", "squat"], "aiLevel": 16, "stars": [{"kind": "winBothRounds", "label": "R1·R2 승리"}, {"kind": "bossExcellent", "n": 12, "label": "Excellent 합계 12회"}, {"kind": "koBothRounds", "label": "R1·R2 KO"}]}
 ],
 "aiLevels": [
  {"level": 1, "fewestValid": 5, "mostValid": 7, "fewestRejected": 1, "mostRejected": 3, "deepShare": 0, "comboChance": 0},
  {"level": 2, "fewestValid": 6, "mostValid": 8, "fewestRejected": 1, "mostRejected": 2, "deepShare": 0.05, "comboChance": 0.06},
  {"level": 3, "fewestValid": 7, "mostValid": 9, "fewestRejected": 1, "mostRejected": 2, "deepShare": 0.05, "comboChance": 0.08},
  {"level": 4, "fewestValid": 8, "mostValid": 10, "fewestRejected": 0, "mostRejected": 2, "deepShare": 0.1, "comboChance": 0.1},
  {"level": 5, "fewestValid": 9, "mostValid": 11, "fewestRejected": 0, "mostRejected": 2, "deepShare": 0.1, "comboChance": 0.1},
  {"level": 6, "fewestValid": 10, "mostValid": 12, "fewestRejected": 0, "mostRejected": 2, "deepShare": 0.15, "comboChance": 0.1},
  {"level": 7, "fewestValid": 11, "mostValid": 13, "fewestRejected": 0, "mostRejected": 2, "deepShare": 0.15, "comboChance": 0.1},
  {"level": 8, "fewestValid": 12, "mostValid": 14, "fewestRejected": 0, "mostRejected": 2, "deepShare": 0.2, "comboChance": 0.1},
  {"level": 9, "fewestValid": 13, "mostValid": 15, "fewestRejected": 0, "mostRejected": 1, "deepShare": 0.2, "comboChance": 0.1},
  {"level": 10, "fewestValid": 14, "mostValid": 16, "fewestRejected": 0, "mostRejected": 1, "deepShare": 0.25, "comboChance": 0.1},
  {"level": 11, "fewestValid": 15, "mostValid": 17, "fewestRejected": 0, "mostRejected": 1, "deepShare": 0.25, "comboChance": 0.1},
  {"level": 12, "fewestValid": 16, "mostValid": 18, "fewestRejected": 0, "mostRejected": 1, "deepShare": 0.3, "comboChance": 0.1},
  {"level": 13, "fewestValid": 17, "mostValid": 19, "fewestRejected": 0, "mostRejected": 1, "deepShare": 0.3, "comboChance": 0.1},
  {"level": 14, "fewestValid": 18, "mostValid": 20, "fewestRejected": 0, "mostRejected": 1, "deepShare": 0.35, "comboChance": 0.1},
  {"level": 15, "fewestValid": 19, "mostValid": 21, "fewestRejected": 0, "mostRejected": 1, "deepShare": 0.35, "comboChance": 0.1},
  {"level": 16, "fewestValid": 20, "mostValid": 22, "fewestRejected": 0, "mostRejected": 1, "deepShare": 0.4, "comboChance": 0.1}
 ],
 "battleRuleDefaults": {"feverStartSeconds": 20, "comboBonus": 5, "excellentPoints": 15, "goodPoints": 10, "averagePoints": 5, "koLead": 100, "comboWindowMs": 1500},
 "currentBotDifficulties": {"beginner": {"level": 1}, "intermediate": {"level": 4}, "expert": {"note": "10~14회. LV 7(11~13회)과 LV 8(12~14회) 사이"}}
}
''';

final _data = jsonDecode(_arcadeDataJson) as Map<String, dynamic>;

List<Map<String, dynamic>> _items(String key) => [
  for (final item in _data[key] as List) item as Map<String, dynamic>,
];

Map<String, Object?> _floorJson(ArcadeFloor floor) => {
  'floor': floor.number,
  'name': floor.name,
  'owner': floor.owner,
  'ownerName': floor.ownerName,
  'rule': switch (floor.rule) {
    null => null,
    final rule => {
      'kind': rule.kind.name,
      rule.kind == ArcadeRuleKind.feverFrom ? 'seconds' : 'times': rule.value,
      'label': rule.label,
    },
  },
};

Map<String, Object?> _stageJson(ArcadeStage stage) => {
  'stage': stage.number,
  'floor': stage.floor,
  'slot': stage.slot,
  'kind': stage.kind.name,
  'character': stage.character,
  ...switch (stage) {
    ArcadeFightStage() => {
      'exercise': stage.exercise.name,
      'aiLevel': stage.aiLevel.level,
    },
    ArcadeHoldStage() => {
      'hold': stage.pose.name,
      'starSeconds': stage.starSeconds,
    },
    ArcadeBossStage() => {
      'rounds': [for (final round in stage.rounds) round.name],
      'aiLevel': stage.aiLevel.level,
    },
  },
  'stars': [
    for (final star in stage.stars)
      {'kind': star.kind.name, 'n': ?star.n, 'label': star.label},
  ],
};

Map<String, Object?> _levelJson(BotPace pace, int level) => {
  'level': level,
  'fewestValid': pace.fewestValid,
  'mostValid': pace.mostValid,
  'fewestRejected': pace.fewestRejected,
  'mostRejected': pace.mostRejected,
  'deepShare': pace.deepShare,
  'comboChance': pace.comboChance,
};

void main() {
  group('the same values as arcade_data.json', () {
    test('version arcade-1, and 5F under construction', () {
      expect(ArcadeCatalog.version, _data['version']);
      expect(
        ArcadeCatalog.underConstructionFloor,
        _data['underConstructionFloor'],
      );
    });

    test('the four floors: name, owner and rule', () {
      expect([
        for (final floor in ArcadeCatalog.floors) _floorJson(floor),
      ], _items('floors'));
    });

    test('the 24 stages, every field and star', () {
      final stages = _items('stages');
      expect(ArcadeCatalog.stages, hasLength(stages.length));
      for (final (i, stage) in ArcadeCatalog.stages.indexed) {
        expect(_stageJson(stage), stages[i], reason: 'stage ${i + 1}');
      }
    });

    test('the 16 AI levels', () {
      expect([
        for (final level in ArcadeAiLevel.values)
          _levelJson(level, level.level),
      ], _items('aiLevels'));
    });

    test('the characters are the rig\'s, with the same names', () {
      final names = (_data['characters'] as Map).cast<String, String>();
      for (final MapEntry(key: id, value: name) in names.entries) {
        expect(CharacterRig.standard.characters[id]?.name, name, reason: id);
      }
      final met = {for (final stage in ArcadeCatalog.stages) stage.character};
      expect(met, names.keys.toSet());
      for (final floor in ArcadeCatalog.floors) {
        expect(names[floor.owner], floor.ownerName);
      }
    });

    test('the default score rules are the game\'s', () {
      final defaults = _data['battleRuleDefaults'] as Map<String, dynamic>;
      expect({
        'feverStartSeconds': battleRules.feverStart.inSeconds,
        'comboBonus': battleRules.comboBonus,
        'excellentPoints': battleRules.excellentPoints,
        'goodPoints': battleRules.goodPoints,
        'averagePoints': battleRules.averagePoints,
        'koLead': battleRules.koLead,
        'comboWindowMs': battleRules.comboWindow.inMilliseconds,
      }, defaults);
    });

    test('초보 is LV 1, 중수 counts like LV 4, 고수 has no level', () {
      final current = _data['currentBotDifficulties'] as Map<String, dynamic>;
      int levelOf(String name) =>
          (current[name] as Map<String, dynamic>)['level'] as int;

      final beginner = ArcadeAiLevel.of(levelOf('beginner'));
      expect(_levelJson(beginner, 1), _levelJson(BotDifficulty.beginner, 1));

      final middle = ArcadeAiLevel.of(levelOf('intermediate'));
      const intermediate = BotDifficulty.intermediate;
      expect(
        (middle.fewestValid, middle.mostValid),
        (intermediate.fewestValid, intermediate.mostValid),
      );
      expect(
        (middle.fewestRejected, middle.mostRejected),
        (intermediate.fewestRejected, intermediate.mostRejected),
      );
      expect(middle.deepShare, intermediate.deepShare);
      expect((middle.comboChance, intermediate.comboChance), (0.1, 0.08));

      expect(current['expert'], isNot(contains('level')));
    });
  });

  group('the rules of the arcade (spec 1, 9)', () {
    final fights = ArcadeCatalog.stages.whereType<ArcadeFightStage>().toList();

    test('six stages on each of four floors, numbered in order', () {
      expect([
        for (final stage in ArcadeCatalog.stages) stage.number,
      ], List.generate(24, (i) => i + 1));
      for (final floor in ArcadeCatalog.floors) {
        expect(
          [
            for (final stage in ArcadeCatalog.stagesOn(floor.number))
              stage.slot,
          ],
          [1, 2, 3, 4, 5, 6],
        );
      }
    });

    test('every floor plays push-up, squat, plank, push-up, chair, boss', () {
      for (final floor in ArcadeCatalog.floors) {
        final stages = ArcadeCatalog.stagesOn(floor.number);
        expect(
          [
            for (final stage in stages)
              switch (stage) {
                ArcadeFightStage() => stage.exercise.name,
                ArcadeHoldStage() => stage.pose.name,
                ArcadeBossStage() => 'boss',
              },
          ],
          ['pushUp', 'squat', 'plank', 'pushUp', 'chair', 'boss'],
        );
      }
    });

    test('the six characters each fight twice in the twelve fights', () {
      expect(fights, hasLength(12));
      final times = <String, int>{};
      for (final fight in fights) {
        times[fight.character] = (times[fight.character] ?? 0) + 1;
      }
      expect(times, {
        for (final id in CharacterRig.standard.characters.keys) id: 2,
      });
    });

    test('no character fights twice on a floor, nor on its own floor', () {
      for (final floor in ArcadeCatalog.floors) {
        final onFloor = [
          for (final fight in fights)
            if (fight.floor == floor.number) fight.character,
        ];
        expect(onFloor.toSet(), hasLength(onFloor.length));
        expect(onFloor, isNot(contains(floor.owner)));
      }
    });

    test('no character fights in two fights in a row', () {
      for (var i = 1; i < fights.length; i++) {
        expect(
          fights[i].character,
          isNot(fights[i - 1].character),
          reason: 'stage ${fights[i].number}',
        );
      }
    });

    test('the AI goes up one level per fight and boss stage, 1 to 16', () {
      expect([
        for (final stage in ArcadeCatalog.stages)
          if (stage case ArcadeFightStage(:final aiLevel))
            aiLevel.level
          else if (stage case ArcadeBossStage(:final aiLevel))
            aiLevel.level,
      ], List.generate(16, (i) => i + 1));
    });

    test('the floor\'s owner judges its holds and plays its boss match', () {
      for (final stage in ArcadeCatalog.stages) {
        if (stage is ArcadeFightStage) continue;
        expect(
          stage.character,
          ArcadeCatalog.floorOf(stage).owner,
          reason: 'stage ${stage.number}',
        );
      }
    });

    test('a boss match is push-up, then squat', () {
      for (final boss in ArcadeCatalog.stages.whereType<ArcadeBossStage>()) {
        expect(boss.rounds, [ExerciseType.pushUp, ExerciseType.squat]);
      }
    });

    test('the stars of each kind of stage', () {
      for (final stage in ArcadeCatalog.stages) {
        final kinds = [for (final star in stage.stars) star.kind];
        switch (stage) {
          case ArcadeFightStage():
            expect(kinds.first, ArcadeStarKind.win);
            expect(
              kinds[1],
              isIn(const [
                ArcadeStarKind.maxRejects,
                ArcadeStarKind.combo,
                ArcadeStarKind.excellent,
              ]),
            );
            expect(kinds.last, ArcadeStarKind.koWin);
            expect(stage.stars[1].n, isNotNull);
          case ArcadeHoldStage():
            expect(kinds, everyElement(ArcadeStarKind.holdSeconds));
            expect([for (final star in stage.stars) star.n], stage.starSeconds);
          case ArcadeBossStage():
            expect(kinds, const [
              ArcadeStarKind.winBothRounds,
              ArcadeStarKind.bossExcellent,
              ArcadeStarKind.koBothRounds,
            ]);
        }
      }
    });

    test('the star numbers get harder by one step on each floor', () {
      for (var slot = 1; slot <= 6; slot++) {
        final column = [
          for (final stage in ArcadeCatalog.stages)
            if (stage.slot == slot) stage,
        ];
        for (var i = 1; i < column.length; i++) {
          final before = column[i - 1], after = column[i];
          if (after is ArcadeHoldStage) {
            final earlier = before as ArcadeHoldStage;
            for (var star = 0; star < 3; star++) {
              expect(
                after.starSeconds[star],
                greaterThan(earlier.starSeconds[star]),
                reason: 'stage ${after.number}',
              );
            }
            continue;
          }
          final n = after.stars[1].n!, nBefore = before.stars[1].n!;
          expect(after.stars[1].kind, before.stars[1].kind);
          if (after.stars[1].kind == ArcadeStarKind.maxRejects) {
            expect(n, nBefore - 1, reason: 'stage ${after.number}');
          } else {
            expect(n, greaterThan(nBefore), reason: 'stage ${after.number}');
          }
        }
      }
    });

    test('4F asks for no rejected rep at all in its first stage', () {
      final first = ArcadeCatalog.stage(19);
      expect(first.stars[1].kind, ArcadeStarKind.maxRejects);
      expect(first.stars[1].n, 0);
    });
  });

  group('lookups', () {
    test('a floor and a stage by number', () {
      expect(ArcadeCatalog.floor(3).name, '복싱장');
      expect(ArcadeCatalog.stage(24), isA<ArcadeBossStage>());
      expect(ArcadeCatalog.stage(1).character, 'bot');
      expect(ArcadeCatalog.floorOf(ArcadeCatalog.stage(13)).number, 3);
      expect(ArcadeCatalog.stagesOn(2).map((stage) => stage.number), [
        7,
        8,
        9,
        10,
        11,
        12,
      ]);
    });

    test('numbers that do not exist throw', () {
      expect(() => ArcadeCatalog.floor(0), throwsRangeError);
      expect(() => ArcadeCatalog.floor(5), throwsRangeError);
      expect(() => ArcadeCatalog.stage(0), throwsRangeError);
      expect(() => ArcadeCatalog.stage(25), throwsRangeError);
      expect(() => ArcadeCatalog.stagesOn(5), throwsRangeError);
    });
  });
}
