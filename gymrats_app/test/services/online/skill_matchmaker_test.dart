import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../../server/lib/skill_matchmaker.dart';

/// P10: skill estimates (the median of the latest five battles) and the
/// sorted index the simulated opponents are chosen from.
void main() {
  group('medianOf', () {
    test('an odd count takes the middle value', () {
      expect(medianOf([9, 3, 7]), 7);
    });

    test('an even count takes the mean of the two middle values', () {
      expect(medianOf([10, 4, 6, 8]), 7);
    });

    test('only the latest five battles count', () {
      // Newest first: 1, 2, 3, 4, 5 count; the old 100s do not.
      expect(medianOf([1, 2, 3, 4, 5, 100, 100]), 3);
    });

    test('one bad battle hardly moves it', () {
      expect(medianOf([12, 0, 11, 13, 12]), 12);
    });

    test('no battle has no estimate', () {
      expect(medianOf([]), isNull);
    });
  });

  group('SkillRecord.fromJson', () {
    test('reads the player, the nickname and both exercises', () {
      final record = SkillRecord.fromJson({
        'player_id': '7',
        'display_name': '진영',
        'recent': {
          'push_up': [9, 8],
          'squat': [20],
        },
      })!;
      expect(record.id, '7');
      expect(record.name, '진영');
      expect(record.recent, {
        'push_up': [9, 8],
        'squat': [20],
      });
    });

    test('an exercise not sent has no battle', () {
      final record = SkillRecord.fromJson({
        'player_id': '7',
        'display_name': '진영',
        'recent': {
          'push_up': [9],
        },
      })!;
      expect(record.recent.containsKey('squat'), isFalse);
    });

    for (final bad in <Object?>[
      null,
      'x',
      {'display_name': '진영', 'recent': {}},
      {'player_id': '', 'display_name': '진영', 'recent': {}},
      {'player_id': '7', 'display_name': '', 'recent': {}},
      {'player_id': '7', 'display_name': '진영'},
      {
        'player_id': '7',
        'display_name': '진영',
        'recent': {'push_up': 'nine'},
      },
      {
        'player_id': '7',
        'display_name': '진영',
        'recent': {
          'push_up': [-1],
        },
      },
      {
        'player_id': '7',
        'display_name': '진영',
        'recent': {
          'push_up': [1.5],
        },
      },
    ]) {
      test('refuses a malformed record: $bad', () {
        expect(SkillRecord.fromJson(bad), isNull);
      });
    }
  });

  SkillRecord record(String id, String name, List<int> pushUps) =>
      SkillRecord(id, name, {'push_up': pushUps});

  group('SkillIndex', () {
    final index = SkillIndex.build([
      record('1', '초보', [4, 5, 6]),
      record('2', '중수', [9, 10, 11]),
      record('3', '고수', [14, 15, 16]),
      record('4', '근육', [20, 21, 22]),
    ]);

    test('the estimate is the median of the latest battles', () {
      expect(index.estimateOf('2', 'push_up'), 10);
      expect(index.count('push_up'), 4);
    });

    test('finds the account whose estimate is closest', () {
      expect(index.nearest('push_up', 13)!.name, '고수');
      expect(index.nearest('push_up', 7)!.name, '초보');
      expect(index.nearest('push_up', 100)!.name, '근육');
      expect(index.nearest('push_up', 0)!.name, '초보');
    });

    test('never copies the player themself', () {
      expect(index.nearest('push_up', 10, excludeId: '2')!.name, '초보');
      expect(index.nearest('push_up', 15, excludeId: '3')!.name, '중수');
      expect(index.nearest('push_up', 21, excludeId: '4')!.name, '고수');
      expect(index.nearest('push_up', 5, excludeId: '1')!.name, '중수');
    });

    test('a tie goes to the lower estimate', () {
      // 7.5 is 2.5 from both 5 and 10.
      expect(index.nearest('push_up', 7.5)!.name, '초보');
    });

    test('equal estimates go to the smaller id, the same every time', () {
      final twins = SkillIndex.build([
        record('9', '나중', [10]),
        record('8', '먼저', [10]),
      ]);
      expect(twins.nearest('push_up', 10)!.id, '8');
      expect(twins.nearest('push_up', 10, excludeId: '8')!.id, '9');
    });

    test('nobody else to copy is null', () {
      final alone = SkillIndex.build([
        record('1', '혼자', [10]),
      ]);
      expect(alone.nearest('push_up', 10, excludeId: '1'), isNull);
      expect(alone.nearest('squat', 10), isNull);
      expect(SkillIndex.empty().nearest('push_up', 10), isNull);
    });

    test('a player with no battle starts at the average', () {
      expect(index.estimateOf('99', 'push_up'), (5 + 10 + 15 + 21) / 4);
    });

    test('nobody with a battle of it starts at the default', () {
      expect(index.average('squat'), SkillIndex.defaultSkill);
      expect(SkillIndex.empty().estimateOf('1', 'push_up'), 9);
    });

    test('exercises are kept apart', () {
      final both = SkillIndex.build([
        const SkillRecord('1', '쥐돌이', {
          'push_up': [5],
          'squat': [30],
        }),
        const SkillRecord('2', '헬창', {
          'squat': [10],
        }),
      ]);
      expect(both.count('push_up'), 1);
      expect(both.count('squat'), 2);
      expect(both.nearest('squat', 12)!.name, '헬창');
    });

    test('a repeated account keeps its last record', () {
      final again = SkillIndex.build([
        record('1', '옛날', [5]),
        record('1', '지금', [12]),
      ]);
      expect(again.count('push_up'), 1);
      expect(again.estimateOf('1', 'push_up'), 12);
      expect(again.nearest('push_up', 0)!.name, '지금');
    });

    test('a new build takes updated battles', () {
      final before = SkillIndex.build([
        record('1', '쥐돌이', [5, 5, 5]),
      ]);
      final after = SkillIndex.build([
        record('1', '쥐돌이', [12, 12, 12, 5, 5]),
      ]);
      expect(before.estimateOf('1', 'push_up'), 5);
      expect(after.estimateOf('1', 'push_up'), 12);
    });
  });

  test('nearest agrees with a full scan on random data', () {
    final random = Random(10);
    final records = [
      for (var i = 0; i < 300; i++)
        record('$i', 'u$i', [
          for (var j = 0; j < 1 + random.nextInt(7); j++) random.nextInt(40),
        ]),
    ];
    final index = SkillIndex.build(records);
    for (var i = 0; i < 500; i++) {
      final skill = random.nextDouble() * 45;
      final exclude = '${random.nextInt(300)}';
      final found = index.nearest('push_up', skill, excludeId: exclude)!;
      final best = records
          .where((r) => r.id != exclude)
          .map((r) => (medianOf(r.recent['push_up']!)! - skill).abs())
          .reduce(min);
      expect((found.skill - skill).abs(), best);
    }
  });

  test('measures the build apart from the lookups (P20 setup)', () {
    // P20 reproduces this: seed 20, 10 000 accounts with 5 battles of 0-39
    // reps, 10 000 lookups for skills 0-45.
    final random = Random(20);
    final records = [
      for (var i = 0; i < 10000; i++)
        record('$i', 'u$i', [for (var j = 0; j < 5; j++) random.nextInt(40)]),
    ];
    final skills = [for (var i = 0; i < 1000; i++) random.nextDouble() * 45];
    final cost = measureSkillIndex(records, skills, lookups: 10000);
    // Shown in the test output for docs/iteration-5/matchmaking.md.
    // ignore: avoid_print
    print('P10 skill index: $cost');
    expect(cost.accounts, 10000);
    expect(cost.lookups, 10000);
    expect(cost.buildMicros, greaterThan(0));
    expect(cost.microsPerLookup, greaterThan(0));
    expect(cost.toString(), contains('per_lookup='));
  });

  test('no lookup costs nothing per lookup', () {
    final cost = measureSkillIndex([record('1', 'a', [1])], [1], lookups: 0);
    expect(cost.microsPerLookup, 0);
  });
}
