import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/user/character_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureCharacterStore', () {
    test(
      'keeps each account\'s character apart, beside the login session',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'gymrats.session': 'existing-login-session',
        });
        await SecureCharacterStore().write(7, 'bear');
        expect(await SecureCharacterStore().read(7), 'bear');
        expect(await SecureCharacterStore().read(8), 'mouse');
        expect(
          await const FlutterSecureStorage().read(key: 'gymrats.character.7'),
          'bear',
        );
        expect(
          await const FlutterSecureStorage().read(key: 'gymrats.session'),
          'existing-login-session',
        );
      },
    );

    test('nothing saved, an unknown value, RepBot or an old avatar id read '
        'as the mouse', () async {
      for (final saved in ['rabbit', 'bot', 'avatar_01', '']) {
        FlutterSecureStorage.setMockInitialValues({
          'gymrats.character.7': saved,
        });
        expect(await SecureCharacterStore().read(7), 'mouse', reason: saved);
      }
      FlutterSecureStorage.setMockInitialValues({});
      expect(await SecureCharacterStore().read(7), 'mouse');
    });

    test('a value that cannot be read is the mouse', () async {
      expect(await SecureCharacterStore(_BrokenStorage()).read(7), 'mouse');
    });

    test('a failed write fails to the caller', () async {
      await expectLater(
        SecureCharacterStore(_BrokenStorage()).write(7, 'seal'),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('MemoryCharacterStore', () {
    test('keeps the choices per account while the app runs', () async {
      final store = MemoryCharacterStore();
      expect(await store.read(1), 'mouse');
      await store.write(1, 'penguin');
      expect(await store.read(1), 'penguin');
      expect(await store.read(2), 'mouse');
      expect(store.values, {1: 'penguin'});
    });

    test('reads an id a person may not pick as the mouse', () async {
      final store = MemoryCharacterStore()..values[1] = 'bot';
      expect(await store.read(1), 'mouse');
    });
  });
}

/// Secure storage whose every call fails, as a lost key does.
class _BrokenStorage extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => Future.error(PlatformException(code: 'read'));

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => Future.error(PlatformException(code: 'write'));
}
