import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/viewmodels/matching_viewmodel.dart';

import '../support/fakes.dart';

void main() {
  late FakeMatchmaker matchmaker;
  late FakeUserRepository repository;

  setUp(() {
    matchmaker = FakeMatchmaker();
    repository = FakeUserRepository();
  });

  /// A view model whose clock follows the fake time of [async].
  MatchingViewModel create(FakeAsync async) => MatchingViewModel(
    matchmaker: matchmaker,
    repository: repository,
    exercise: ExerciseType.pushUp,
    clock: () => async.elapsed,
  );

  test('starts searching at 0:00 with no name yet', () {
    fakeAsync((async) {
      final vm = create(async);
      expect(vm.state.phase, MatchingPhase.searching);
      expect(vm.state.elapsed, Duration.zero);
      expect(vm.state.playerName, isNull);
      expect(vm.state.matchup, isNull);
      vm.dispose();
    });
  });

  test('counts the elapsed time in whole seconds while searching', () {
    fakeAsync((async) {
      matchmaker.gate = Completer();
      final vm = create(async)..start();
      async.elapse(const Duration(milliseconds: 999));
      expect(vm.state.elapsed, Duration.zero);
      async.elapse(const Duration(milliseconds: 1));
      expect(vm.state.elapsed, const Duration(seconds: 1));
      async.elapse(const Duration(seconds: 7));
      expect(vm.state.elapsed, const Duration(seconds: 8));
      vm.dispose();
    });
  });

  test('shows the name, then the matchup once an opponent is found', () {
    fakeAsync((async) {
      matchmaker.gate = Completer();
      final vm = create(async)..start();
      async.flushMicrotasks();
      expect(vm.state.playerName, '우현');
      expect(vm.state.phase, MatchingPhase.searching);
      expect(matchmaker.requests, [ExerciseType.pushUp]);

      matchmaker.gate!.complete();
      async.flushMicrotasks();
      expect(vm.state.phase, MatchingPhase.found);
      final matchup = vm.state.matchup!;
      expect(matchup.exercise, ExerciseType.pushUp);
      expect(matchup.playerName, '우현');
      expect(matchup.opponent, same(matchmaker.opponent));
      // The clock stops.
      expect(async.periodicTimerCount, 0);
      vm.dispose();
    });
  });

  test('a failed search shows the failed state and stops the clock', () {
    fakeAsync((async) {
      matchmaker.error = Exception('offline');
      final vm = create(async)..start();
      async.flushMicrotasks();
      expect(vm.state.phase, MatchingPhase.failed);
      expect(vm.state.matchup, isNull);
      expect(async.periodicTimerCount, 0);
      vm.dispose();
    });
  });

  test('a failed profile load fails before asking the matchmaker', () {
    fakeAsync((async) {
      repository.error = Exception('offline');
      final vm = create(async)..start();
      async.flushMicrotasks();
      expect(vm.state.phase, MatchingPhase.failed);
      expect(matchmaker.requests, isEmpty);
      vm.dispose();
    });
  });

  test('retry searches again and counts from 0:00', () {
    fakeAsync((async) {
      matchmaker
        ..gate = Completer()
        ..error = Exception('offline');
      final vm = create(async)..start();
      async.elapse(const Duration(seconds: 5));
      matchmaker.gate!.complete();
      async.flushMicrotasks();
      expect(vm.state.phase, MatchingPhase.failed);
      expect(vm.state.elapsed, const Duration(seconds: 5));

      matchmaker
        ..error = null
        ..gate = Completer();
      vm.retry();
      expect(vm.state.phase, MatchingPhase.searching);
      expect(vm.state.elapsed, Duration.zero);
      // The name stays, so the avatar does not flicker.
      expect(vm.state.playerName, '우현');
      async.elapse(const Duration(seconds: 2));
      expect(vm.state.elapsed, const Duration(seconds: 2));

      matchmaker.gate!.complete();
      async.flushMicrotasks();
      expect(vm.state.phase, MatchingPhase.found);
      expect(matchmaker.requests, hasLength(2));
      vm.dispose();
    });
  });

  test('an opponent found after cancel is ignored', () {
    fakeAsync((async) {
      matchmaker.gate = Completer();
      final vm = create(async)..start();
      async.flushMicrotasks();
      vm.cancel();
      expect(async.periodicTimerCount, 0);

      matchmaker.gate!.complete();
      async.flushMicrotasks();
      expect(vm.state.phase, MatchingPhase.searching);
      expect(vm.state.matchup, isNull);
      vm.dispose();
    });
  });

  test('an opponent found after dispose is dropped', () {
    fakeAsync((async) {
      matchmaker.gate = Completer();
      final vm = create(async)..start();
      async.flushMicrotasks();
      vm.dispose();
      expect(async.periodicTimerCount, 0);

      matchmaker.gate!.complete();
      // Notifying a disposed view model would throw here.
      async.flushMicrotasks();
      expect(vm.state.matchup, isNull);
    });
  });
}
