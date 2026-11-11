import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';

import '../support/fakes.dart';

void main() {
  late FakeUserRepository repository;
  late HomeViewModel vm;

  setUp(() {
    repository = FakeUserRepository();
    vm = HomeViewModel(repository: repository);
  });

  test('starts loading with no profile', () {
    expect(vm.state.phase, HomePhase.loading);
    expect(vm.state.profile, isNull);
  });

  test('load shows the profile from the repository', () async {
    await vm.load();
    expect(vm.state.phase, HomePhase.ready);
    expect(vm.state.profile, same(repository.profile));
  });

  test('a failed load shows the failed state and can be retried', () async {
    repository.error = Exception('offline');
    await vm.load();
    expect(vm.state.phase, HomePhase.failed);
    repository.error = null;
    await vm.load();
    expect(vm.state.phase, HomePhase.ready);
    expect(vm.state.profile, same(repository.profile));
  });

  test(
    'a reload keeps the profile on screen until the new one comes',
    () async {
      await vm.load();
      final shown = vm.state.profile;
      repository
        ..profile = const UserProfile(name: '우현', bestReps: 40)
        ..gate = Completer();
      final reloading = vm.load();
      expect(vm.state.phase, HomePhase.ready);
      expect(vm.state.profile, same(shown));

      repository.gate!.complete();
      await reloading;
      expect(vm.state.phase, HomePhase.ready);
      expect(vm.state.profile!.bestReps, 40);
    },
  );

  test('a failed reload keeps the profile', () async {
    await vm.load();
    final shown = vm.state.profile;
    repository.error = Exception('offline');
    await vm.load();
    expect(vm.state.phase, HomePhase.ready);
    expect(vm.state.profile, same(shown));
  });

  test('load while loading fetches only once', () async {
    repository.gate = Completer();
    final first = vm.load();
    final second = vm.load();
    repository.gate!.complete();
    await first;
    await second;
    expect(repository.fetchCount, 1);
    expect(vm.state.phase, HomePhase.ready);
  });

  test('a profile arriving after dispose is dropped', () async {
    repository.gate = Completer();
    final loading = vm.load();
    vm.dispose();
    repository.gate!.complete();
    // Notifying a disposed view model would throw here.
    await expectLater(loading, completes);
    expect(vm.state.profile, isNull);
  });

  test('load reads only the profile, not the recent battles', () async {
    await vm.load();
    expect(repository.fetchCount, 1);
    expect(repository.recentLimits, isEmpty);
  });

  group('the latest setup, to play again', () {
    Future<BattleSetup?> lastSetupAgainst(String opponentName) async {
      repository.profile = UserProfile(
        name: '우현',
        lastMatch: MatchRecord(
          exercise: ExerciseType.squat,
          opponentName: opponentName,
          myReps: 10,
          opponentReps: 8,
        ),
      );
      await vm.load();
      return vm.state.lastSetup;
    }

    test('is none before the first battle', () async {
      await vm.load();
      expect(vm.state.lastSetup, isNull);
    });

    for (final level in BotDifficulty.values) {
      test('a battle with the ${level.label} bot is that bot again', () async {
        expect(
          await lastSetupAgainst(level.opponentName),
          BattleSetup(exercise: ExerciseType.squat, difficulty: level),
        );
      });
    }

    test('the bot from before the levels played like the expert', () async {
      expect(
        await lastSetupAgainst('RepBot'),
        const BattleSetup(
          exercise: ExerciseType.squat,
          difficulty: BotDifficulty.expert,
        ),
      );
    });

    test(
      'a person named like a bot reads as that bot: no mode is kept',
      () async {
        expect(
          (await lastSetupAgainst(BotDifficulty.beginner.opponentName))!
              .isOnline,
          isFalse,
        );
      },
    );

    test('a battle with a person is an online battle', () async {
      final setup = await lastSetupAgainst('민지');
      expect(setup!.isOnline, isTrue);
      expect(setup.difficulty, isNull);
      expect(setup.exercise, ExerciseType.squat);
    });

    test('a reload shows the battle played meanwhile', () async {
      await lastSetupAgainst('민지');
      expect(
        await lastSetupAgainst(BotDifficulty.beginner.opponentName),
        const BattleSetup(
          exercise: ExerciseType.squat,
          difficulty: BotDifficulty.beginner,
        ),
      );
    });
  });

  group('the AI 1v1 choice', () {
    test("starts at push-ups against the 중수 bot, as designed", () {
      expect(
        vm.state.botSetup,
        const BattleSetup(
          exercise: ExerciseType.pushUp,
          difficulty: BotDifficulty.intermediate,
        ),
      );
    });

    test('choosing the exercise keeps the level, and the other way', () {
      var notified = 0;
      vm.addListener(() => notified++);
      vm.chooseBotLevel(BotDifficulty.expert);
      vm.chooseBotExercise(ExerciseType.squat);
      expect(
        vm.state.botSetup,
        const BattleSetup(
          exercise: ExerciseType.squat,
          difficulty: BotDifficulty.expert,
        ),
      );
      expect(notified, 2);
    });

    test('a reload keeps the choice', () async {
      vm.chooseBotLevel(BotDifficulty.beginner);
      await vm.load();
      await vm.load();
      expect(vm.state.botSetup.difficulty, BotDifficulty.beginner);
    });

    test('a choice after dispose is dropped', () {
      vm.dispose();
      // Notifying a disposed view model would throw here.
      vm.chooseBotLevel(BotDifficulty.expert);
      expect(vm.state.botSetup.difficulty, BotDifficulty.intermediate);
    });
  });

  test('two setups are equal by exercise and level', () {
    const online = BattleSetup(exercise: ExerciseType.pushUp);
    expect(online, const BattleSetup(exercise: ExerciseType.pushUp));
    expect(
      online.hashCode,
      const BattleSetup(exercise: ExerciseType.pushUp).hashCode,
    );
    expect(
      online,
      isNot(
        const BattleSetup(
          exercise: ExerciseType.pushUp,
          difficulty: BotDifficulty.beginner,
        ),
      ),
    );
    expect(online, isNot(const BattleSetup(exercise: ExerciseType.squat)));
  });
}
