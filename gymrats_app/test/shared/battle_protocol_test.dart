import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/shared/battle_protocol.dart';

void main() {
  group('the setup time (P12)', () {
    test('starts at 10 seconds, the Iteration 5 trial value', () {
      expect(battleSetupTimeout, const Duration(seconds: 10));
    });

    test('its cancel reason is setup_timeout, apart from the ready time', () {
      expect(battleSetupTimeoutReason, 'setup_timeout');
      expect(battleSetupTimeoutReason, isNot('ready_timeout'));
      // A reason the app shows and the protocol names, never a rep reason.
      expect(battleReasons, isNot(contains(battleSetupTimeoutReason)));
    });
  });
}
