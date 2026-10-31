import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/user/rules_seen_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureRulesSeenStore', () {
    test('an account without a saved flag counts as seen', () async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await SecureRulesSeenStore().read(7), isTrue);
    });

    test('the flag survives a new store and is kept per account, '
        'apart from the session', () async {
      FlutterSecureStorage.setMockInitialValues({
        'gymrats.session': 'existing-login-session',
      });
      await SecureRulesSeenStore().write(7, seen: false);
      expect(await SecureRulesSeenStore().read(7), isFalse);
      expect(await SecureRulesSeenStore().read(8), isTrue);
      expect(
        await const FlutterSecureStorage().read(key: 'gymrats.rules_seen.7'),
        'false',
      );
      expect(
        await const FlutterSecureStorage().read(key: 'gymrats.session'),
        'existing-login-session',
      );

      await SecureRulesSeenStore().write(7, seen: true);
      expect(await SecureRulesSeenStore().read(7), isTrue);
    });

    test('only a saved "false" means not seen', () async {
      FlutterSecureStorage.setMockInitialValues({
        'gymrats.rules_seen.7': 'unexpected',
      });
      expect(await SecureRulesSeenStore().read(7), isTrue);
    });
  });

  test('MemoryRulesSeenStore keeps the flag per account; none saved counts '
      'as seen', () async {
    final store = MemoryRulesSeenStore();
    expect(await store.read(1), isTrue);
    await store.write(1, seen: false);
    expect(await store.read(1), isFalse);
    expect(await store.read(2), isTrue);
    await store.write(1, seen: true);
    expect(await store.read(1), isTrue);
  });
}
