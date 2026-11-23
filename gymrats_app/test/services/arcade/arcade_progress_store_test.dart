import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_progress.dart';
import 'package:gymrats_app/services/arcade/arcade_progress_store.dart';

List<int> _best([int first = 0]) => [first, ...List.filled(23, 0)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureArcadeProgressStore (spec 7)', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('writes and reads an account\'s progress, as {"v":1,"best":[...]} '
        'under gymrats.arcade.<account>', () async {
      final store = SecureArcadeProgressStore();
      final progress = ArcadeProgress.initial().withStars(1, 3);
      await store.write(7, progress);
      expect(await store.read(7), progress);
      final raw = await const FlutterSecureStorage().read(
        key: 'gymrats.arcade.7',
      );
      expect(jsonDecode(raw!), {'v': 1, 'best': _best(3)});
    });

    test('accounts keep their own progress', () async {
      final store = SecureArcadeProgressStore();
      await store.write(1, ArcadeProgress.initial().withStars(1, 2));
      await store.write(2, ArcadeProgress.initial().withStars(1, 1));
      expect((await store.read(1)).bestOf(1), 2);
      expect((await store.read(2)).bestOf(1), 1);
      expect(await store.read(3), ArcadeProgress.initial());
    });

    test('nothing saved is the first state', () async {
      expect(
        await SecureArcadeProgressStore().read(7),
        ArcadeProgress.initial(),
      );
    });

    test('a broken value, another version, another length or a count '
        'outside 0 to 3 is the first state', () async {
      for (final saved in [
        'not json',
        '[]',
        jsonEncode({'v': 2, 'best': _best(3)}),
        jsonEncode({'v': 1, 'best': List.filled(23, 1)}),
        jsonEncode({'v': 1, 'best': List.filled(25, 1)}),
        jsonEncode({'v': 1, 'best': _best(4)}),
        jsonEncode({'v': 1, 'best': _best(-1)}),
      ]) {
        FlutterSecureStorage.setMockInitialValues({'gymrats.arcade.7': saved});
        expect(
          await SecureArcadeProgressStore().read(7),
          ArcadeProgress.initial(),
          reason: saved,
        );
      }
    });

    test('a store that fails to read is the first state', () async {
      expect(
        await SecureArcadeProgressStore(_BrokenStorage()).read(7),
        ArcadeProgress.initial(),
      );
    });
  });

  group('MemoryArcadeProgressStore', () {
    test('the first state until written; accounts apart', () async {
      final store = MemoryArcadeProgressStore();
      expect(await store.read(1), ArcadeProgress.initial());
      await store.write(1, ArcadeProgress.initial().withStars(1, 3));
      expect((await store.read(1)).bestOf(1), 3);
      expect(await store.read(2), ArcadeProgress.initial());
    });
  });

  group('recordArcadeStage', () {
    test('saves the stage\'s stars and returns the saved progress', () async {
      final store = _CountingStore();
      final saved = await recordArcadeStage(store, 7, 1, 2);
      expect(saved.bestOf(1), 2);
      expect(await store.read(7), saved);
      expect(store.writes, 1);
    });

    test('playing again keeps the most stars, with one write each', () async {
      final store = _CountingStore();
      await recordArcadeStage(store, 7, 1, 3);
      final again = await recordArcadeStage(store, 7, 1, 1);
      expect(again.bestOf(1), 3);
      expect((await store.read(7)).bestOf(1), 3);
      expect(store.writes, 2);
    });

    test('a stage played with no star opens nothing', () async {
      final saved = await recordArcadeStage(_CountingStore(), 7, 1, 0);
      expect(saved.isOpen(2), isFalse);
    });
  });
}

/// Counts the writes, to see that a stage's end writes once.
class _CountingStore extends MemoryArcadeProgressStore {
  var writes = 0;

  @override
  Future<void> write(int accountId, ArcadeProgress progress) {
    writes++;
    return super.write(accountId, progress);
  }
}

/// Secure storage whose reads fail, as a lost key does.
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
}
