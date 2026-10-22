import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  group('recent battles', () {
    MatchRecord battle(int reps) => MatchRecord(
      id: reps,
      exercise: ExerciseType.pushUp,
      opponentName: 'RepBot',
      myReps: reps,
      opponentReps: 0,
    );

    test('load asks for the newest three after the profile', () async {
      repository.recent = [for (var r = 5; r >= 1; r--) battle(r)];
      await vm.load();
      expect(repository.recentLimits, [HomeViewModel.recentCount]);
      expect(HomeViewModel.recentCount, 3);
      expect(vm.state.recent.map((m) => m.myReps), [5, 4, 3]);
      expect(vm.state.recentIsFallback, isFalse);
    });

    test('a failed recent load falls back to the latest battle', () async {
      final last = battle(9);
      repository
        ..profile = UserProfile(name: '우현', lastMatch: last)
        ..recentError = Exception('offline');
      await vm.load();
      expect(vm.state.phase, HomePhase.ready);
      expect(vm.state.recent, [same(last)]);
      expect(vm.state.recentIsFallback, isTrue);
    });

    test('without any battle the fallback is empty', () async {
      repository.recentError = Exception('offline');
      await vm.load();
      expect(vm.state.recent, isEmpty);
    });

    test('a reload shows the battles saved meanwhile', () async {
      repository.recent = [battle(1)];
      await vm.load();
      repository.recent = [battle(2), battle(1)];
      await vm.load();
      expect(vm.state.recent.map((m) => m.myReps), [2, 1]);
    });
  });
}
