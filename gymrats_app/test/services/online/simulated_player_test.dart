import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../../server/lib/simulated_player.dart';
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/skill_matchmaker.dart';

/// P10: the simulated opponent copies the account closest to the player's
/// own estimate, under its nickname.
void main() {
  SkillRecord record(String id, String name, List<int> pushUps) =>
      SkillRecord(id, name, {'push_up': pushUps});

  final index = SkillIndex.build([
    record('1', '쥐돌이', [10, 11, 12, 11, 10]),
    record('2', '헬창', [20, 22, 21]),
    record('3', '근손실', [3, 4, 5]),
  ]);

  test('copies the account closest to the player, by nickname', () {
    final opponent = SimulatedPlayer.forPlayer(
      index,
      playerId: '3',
      exercise: 'push_up',
    );
    expect(opponent.playerSkill, 4);
    expect(opponent.displayName, '쥐돌이');
    expect(opponent.copiedId, '1');
    expect(opponent.expectedReps, 11);
  });

  test('the player is never their own opponent', () {
    final opponent = SimulatedPlayer.forPlayer(
      index,
      playerId: '2',
      exercise: 'push_up',
    );
    expect(opponent.copiedId, isNot('2'));
    expect(opponent.displayName, '쥐돌이');
  });

  test('a new player is matched from the average estimate', () {
    // (11 + 21 + 4) / 3 = 12: 쥐돌이 (11) is closest.
    final opponent = SimulatedPlayer.forPlayer(
      index,
      playerId: '99',
      exercise: 'push_up',
    );
    expect(opponent.playerSkill, 12);
    expect(opponent.displayName, '쥐돌이');
  });

  test('with nobody to copy it is RepBot at the player\'s own skill', () {
    final opponent = SimulatedPlayer.forPlayer(
      SkillIndex.build([
        record('1', '혼자', [7]),
      ]),
      playerId: '1',
      exercise: 'push_up',
    );
    expect(opponent.displayName, SimulatedPlayer.fallbackName);
    expect(opponent.copiedId, isNull);
    expect(opponent.expectedReps, 7);
  });

  test('plays at least one rep and at most the limit', () {
    final low = SimulatedPlayer.forPlayer(
      SkillIndex.build([
        record('1', '영', [0, 0, 0]),
      ]),
      playerId: '2',
      exercise: 'push_up',
    );
    final high = SimulatedPlayer.forPlayer(
      SkillIndex.build([
        record('1', '괴물', [500]),
      ]),
      playerId: '2',
      exercise: 'push_up',
    );
    expect(low.expectedReps, SimulatedPlayer.minReps);
    expect(high.expectedReps, SimulatedPlayer.maxReps);
  });

  group('planReps', () {
    const player = SimulatedPlayer(
      displayName: '근손실',
      expectedReps: 12,
      playerSkill: 11,
    );

    test('plans the estimate give or take one, and up to two misses', () {
      for (var seed = 0; seed < 50; seed++) {
        final plan = player.planReps(Random(seed), durationMs: 30000);
        final valid = plan.where((r) => r['valid'] == true).length;
        expect(valid, inInclusiveRange(11, 13));
        expect(plan.length - valid, inInclusiveRange(0, 2));
      }
    });

    test('reps are numbered and in order inside the round', () {
      final plan = player.planReps(Random(1), durationMs: 30000);
      for (var i = 0; i < plan.length; i++) {
        expect(plan[i]['rep_seq'], i + 1);
        expect(plan[i]['elapsed_ms'], inInclusiveRange(1500, 29999));
        if (i > 0) {
          expect(
            plan[i]['elapsed_ms'] as int,
            greaterThan(plan[i - 1]['elapsed_ms'] as int),
          );
        }
      }
    });

    test('payloads are what an app sends: valid good or excellent, misses '
        'too shallow', () {
      final plan = player.planReps(Random(2), durationMs: 30000);
      for (final rep in plan) {
        expect(rep.keys.toSet(), {
          'rep_seq',
          'elapsed_ms',
          'valid',
          'reason',
          'grade',
        });
        if (rep['valid'] == true) {
          expect(rep['reason'], isNull);
          expect(rep['grade'], anyOf('good', 'excellent'));
        } else {
          expect(rep['reason'], 'insufficient_depth');
          expect(rep['grade'], isNull);
        }
      }
    });

    test('some valid reps go deep enough to be excellent', () {
      const many = SimulatedPlayer(
        displayName: '헬창',
        expectedReps: 40,
        playerSkill: 40,
      );
      final grades = many
          .planReps(Random(3), durationMs: 30000)
          .map((r) => r['grade']);
      expect(grades, contains('excellent'));
      expect(grades, contains('good'));
    });

    test('a round too short for the margins still fits', () {
      final plan = player.planReps(Random(4), durationMs: 1000);
      expect(plan.last['elapsed_ms'] as int, lessThan(1000));
    });
  });

  test('simulated ids are told apart from account ids', () {
    expect(SimulatedPlayer.isSimulatedId('sim-0a1b2c3d4e5f'), isTrue);
    expect(SimulatedPlayer.isSimulatedId('12'), isFalse);
  });
}
