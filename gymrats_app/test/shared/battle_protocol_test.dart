import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/shared/battle_protocol.dart';

void main() {
  group('the setup time (P12)', () {
    test('is 20 seconds, raised from the 10 s trial start (A6)', () {
      expect(battleSetupTimeout, const Duration(seconds: 20));
    });

    test('its cancel reason is setup_timeout, apart from the ready time', () {
      expect(battleSetupTimeoutReason, 'setup_timeout');
      expect(battleSetupTimeoutReason, isNot('ready_timeout'));
      // A reason the app shows and the protocol names, never a rep reason.
      expect(battleReasons, isNot(contains(battleSetupTimeoutReason)));
    });
  });

  group('a simulated opponent (P10)', () {
    test('real players get 15 seconds before one is assigned', () {
      expect(battleVirtualWait, const Duration(seconds: 15));
    });

    test('reads the nickname and the reps to play', () {
      final opponent = battleVirtualOpponent({
        'exercise': 'squat',
        'opponent': {'display_name': '근손실', 'expected_reps': 7},
      });
      expect(opponent.name, '근손실');
      expect(opponent.expectedReps, 7);
    });

    for (final bad in <Map<String, dynamic>>[
      {},
      {'opponent': 'x'},
      {
        'opponent': {'expected_reps': 7},
      },
      {
        'opponent': {'display_name': '', 'expected_reps': 7},
      },
      {
        'opponent': {'display_name': 'x' * 81, 'expected_reps': 7},
      },
      {
        'opponent': {'display_name': '근손실', 'expected_reps': 0},
      },
      {
        'opponent': {'display_name': '근손실', 'expected_reps': 61},
      },
      {
        'opponent': {'display_name': '근손실', 'expected_reps': 7.5},
      },
    ]) {
      test('refuses a malformed one: $bad', () {
        expect(
          () => battleVirtualOpponent(bad),
          throwsA(isA<BattleProtocolError>()),
        );
      });
    }
  });
}
