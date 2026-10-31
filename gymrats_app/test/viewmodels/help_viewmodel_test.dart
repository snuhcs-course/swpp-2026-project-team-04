import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/viewmodels/help_viewmodel.dart';

import '../support/help_fakes.dart';

void main() {
  late ScriptedRulesSeenStore store;
  late HelpViewModel vm;
  late int notified;

  setUp(() {
    store = ScriptedRulesSeenStore();
    vm = HelpViewModel(store: store);
    notified = 0;
    vm.addListener(() => notified++);
  });

  group('after a login', () {
    test('checks until the account\'s flag is read', () {
      expect(vm.gateFor(1), HelpGate.checking);
    });

    test('no account means home', () {
      expect(vm.gateFor(null), HelpGate.home);
    });

    test(
      'an account without a saved flag goes home (a normal login)',
      () async {
        await vm.load(1);
        expect(vm.gateFor(1), HelpGate.home);
        expect(store.reads, [1]);
        expect(notified, 1);
      },
    );

    test('an account that signed up here and did not start yet sees the '
        'rules', () async {
      store.values[1] = false;
      await vm.load(1);
      expect(vm.gateFor(1), HelpGate.rules);
    });

    test('the flag belongs to its account', () async {
      store.values[1] = false;
      await vm.load(2);
      expect(vm.gateFor(2), HelpGate.home);
      expect(vm.gateFor(1), HelpGate.checking);
      await vm.load(1);
      expect(vm.gateFor(1), HelpGate.rules);
    });

    test('an unreadable flag counts as seen', () async {
      store.readError = Exception('keystore');
      await vm.load(1);
      expect(vm.gateFor(1), HelpGate.home);
    });

    test('logging in again as the same account keeps the decision without '
        'reading again', () async {
      store.values[1] = false;
      await vm.load(1);
      await vm.load(1);
      expect(store.reads, [1]);
      expect(vm.gateFor(1), HelpGate.rules);
    });

    test(
      'a read for an account that logged out meanwhile is dropped',
      () async {
        store.values[1] = false;
        final read = store.holdRead();
        final first = vm.load(1);
        final second = vm.load(2);
        read.complete();
        await Future.wait([first, second]);
        expect(vm.gateFor(2), HelpGate.home);
        expect(vm.gateFor(1), HelpGate.checking);
        expect(notified, 1);
      },
    );
  });

  group('after a sign-up', () {
    test('the rules show at once, before the flag is saved', () async {
      final saved = store.holdWrite();
      final done = vm.signedUp(1);
      expect(vm.gateFor(1), HelpGate.rules);
      expect(notified, 1);
      saved.complete();
      await done;
      expect(store.writes, [(1, false)]);
      expect(store.values[1], isFalse);
    });

    test('a failed save still shows the rules', () async {
      store.writeError = Exception('keystore');
      await vm.signedUp(1);
      expect(vm.gateFor(1), HelpGate.rules);
    });

    test(
      'a read that ends after the sign-up does not hide the rules',
      () async {
        final read = store.holdRead();
        final loading = vm.load(1);
        await vm.signedUp(1);
        read.complete();
        await loading;
        expect(vm.gateFor(1), HelpGate.rules);
      },
    );

    test('a read that ended before the sign-up is overruled', () async {
      await vm.load(1);
      expect(vm.gateFor(1), HelpGate.home);
      await vm.signedUp(1);
      expect(vm.gateFor(1), HelpGate.rules);
    });
  });

  group('시작하기', () {
    test('goes home and saves the rules as seen for later logins', () async {
      await vm.signedUp(1);
      await vm.markSeen();
      expect(vm.gateFor(1), HelpGate.home);
      expect(store.writes, [(1, false), (1, true)]);

      // A restart reads the saved flag.
      final restarted = HelpViewModel(store: store);
      await restarted.load(1);
      expect(restarted.gateFor(1), HelpGate.home);
    });

    test('a failed save still goes home', () async {
      store.values[1] = false;
      await vm.load(1);
      store.writeError = Exception('keystore');
      await vm.markSeen();
      expect(vm.gateFor(1), HelpGate.home);
    });

    test('does nothing while the rules are not showing', () async {
      await vm.markSeen();
      await vm.load(1);
      await vm.markSeen();
      expect(store.writes, isEmpty);
      expect(vm.gateFor(1), HelpGate.home);
    });
  });

  test('a read that ends after dispose changes nothing', () async {
    final read = store.holdRead();
    final loading = vm.load(1);
    vm.dispose();
    read.complete();
    await loading;
    expect(notified, 0);
  });
}
