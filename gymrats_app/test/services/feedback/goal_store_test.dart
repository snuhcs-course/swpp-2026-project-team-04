import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_goal.dart';
import 'package:gymrats_app/services/feedback/goal_store.dart';

FeedbackGoal _goal({
  ExerciseType exercise = ExerciseType.squat,
  int target = 20,
  String characterId = 'seal',
}) => FeedbackGoal(
  exercise: exercise,
  kind: GoalKind.reps,
  target: target,
  baseline: 18,
  title: '${exercise == ExerciseType.squat ? '스쿼트' : '푸쉬업'} $target회 인정받기',
  setAt: DateTime(2026, 11, 17, 14, 31),
  characterId: characterId,
  fromMatch: '1795412345678',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureGoalStore (spec 5.2)', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('writes and reads an account\'s goal per exercise, under '
        'gymrats.goal.<account>.<exercise>', () async {
      final store = SecureGoalStore();
      await store.write(7, _goal());
      expect(await store.read(7, ExerciseType.squat), _goal());
      expect(await store.read(7, ExerciseType.pushUp), isNull);
      final raw = await const FlutterSecureStorage().read(
        key: 'gymrats.goal.7.squat',
      );
      expect(jsonDecode(raw!), _goal().toJson());
    });

    test('a new goal for the exercise replaces the old one', () async {
      final store = SecureGoalStore();
      await store.write(7, _goal());
      await store.write(7, _goal(target: 22, characterId: 'bear'));
      expect(
        await store.read(7, ExerciseType.squat),
        _goal(target: 22, characterId: 'bear'),
      );
    });

    test('사양할래 removes the exercise\'s goal only', () async {
      final store = SecureGoalStore();
      await store.write(7, _goal());
      await store.write(7, _goal(exercise: ExerciseType.pushUp));
      await store.clear(7, ExerciseType.squat);
      expect(await store.read(7, ExerciseType.squat), isNull);
      expect(await store.read(7, ExerciseType.pushUp), isNotNull);
    });

    test('accounts keep their own goals', () async {
      final store = SecureGoalStore();
      await store.write(1, _goal(target: 20));
      await store.write(2, _goal(target: 30));
      expect((await store.read(1, ExerciseType.squat))!.target, 20);
      expect((await store.read(2, ExerciseType.squat))!.target, 30);
      expect(await store.read(3, ExerciseType.squat), isNull);
    });

    test('a value that cannot be read is no goal', () async {
      FlutterSecureStorage.setMockInitialValues({
        'gymrats.goal.7.squat': 'not json',
        'gymrats.goal.7.pushUp': jsonEncode({'kind': 'reps'}),
      });
      final store = SecureGoalStore();
      expect(await store.read(7, ExerciseType.squat), isNull);
      expect(await store.read(7, ExerciseType.pushUp), isNull);
    });

    test('a goal of another exercise under this key is no goal', () async {
      FlutterSecureStorage.setMockInitialValues({
        'gymrats.goal.7.pushUp': jsonEncode(_goal().toJson()),
      });
      expect(await SecureGoalStore().read(7, ExerciseType.pushUp), isNull);
    });

    test('a store that fails to read is no goal', () async {
      expect(
        await SecureGoalStore(_BrokenStorage()).read(7, ExerciseType.squat),
        isNull,
      );
    });
  });

  group('MemoryGoalStore', () {
    test(
      'writes, replaces, reads and clears per account and exercise',
      () async {
        final store = MemoryGoalStore();
        await store.write(1, _goal());
        await store.write(1, _goal(target: 25));
        await store.write(2, _goal(exercise: ExerciseType.pushUp));
        expect((await store.read(1, ExerciseType.squat))!.target, 25);
        expect(await store.read(1, ExerciseType.pushUp), isNull);
        await store.clear(1, ExerciseType.squat);
        expect(await store.read(1, ExerciseType.squat), isNull);
        expect(await store.read(2, ExerciseType.pushUp), isNotNull);
      },
    );
  });
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
