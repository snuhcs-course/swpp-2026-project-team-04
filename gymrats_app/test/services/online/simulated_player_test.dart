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

  test('the payload has the nickname and reps, never the account id', () {
    final payload = SimulatedPlayer.forPlayer(
      index,
      playerId: '3',
      exercise: 'push_up',
    ).toPayload('push_up');
    expect(payload, {
      'exercise': 'push_up',
      'opponent': {'display_name': '쥐돌이', 'expected_reps': 11},
    });
    expect(payload.toString(), isNot(contains('player_id')));
  });
}
