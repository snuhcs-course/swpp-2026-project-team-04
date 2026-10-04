import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/viewmodels/battle_viewmodel.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';

import '../support/fakes.dart';
import '../support/pose_fixtures.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

final _endedAt = DateTime(2026, 10, 4, 14, 32);

void main() {
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late FakeRepJudge judge;
  late FakeOpponentSource opponent;
  late FakeRepSound sound;
  late FakeUserRepository repository;
  late Duration now;
  late BattleViewModel vm;

  setUp(() {
    camera = FakeCameraService();
    estimator = FakePoseEstimator();
    judge = FakeRepJudge();
    opponent = FakeOpponentSource();
    sound = FakeRepSound();
    repository = FakeUserRepository();
    now = Duration.zero;
    vm = BattleViewModel(
      matchup: _matchup,
      counter: RepCounterViewModel(
        camera: camera,
        estimator: estimator,
        judge: judge,
        clock: () => now,
        roundLength: battleDuration,
      ),
      opponent: opponent,
      repository: repository,
      sound: sound,
      now: () => _endedAt,
    );
  });

  tearDown(() => vm.dispose());

  /// One camera frame [seconds] into the round. It closes the rep queued on
  /// the judge, if any.
  Future<void> frame(double seconds) async {
    now = Duration(milliseconds: (seconds * 1000).round());
    estimator.frames.add(emptyFrame());
    camera.emit();
    await pumpEventQueue();
  }

  /// A frame on which pose detection fails.
  Future<void> failedFrame(double seconds) async {
    now = Duration(milliseconds: (seconds * 1000).round());
    estimator.frames.add(null);
    camera.emit();
    await pumpEventQueue();
  }

  test('the opponent starts when the camera runs, not before', () async {
    camera.startGate = Completer();
    unawaited(vm.start());
    await pumpEventQueue();
    expect(vm.state.phase, BattlePhase.starting);
    expect(opponent.startCount, 0);

    camera.startGate!.complete();
    await pumpEventQueue();
    expect(vm.state.phase, BattlePhase.playing);
    expect(opponent.startCount, 1);
    expect(opponent.running, isTrue);
    expect(vm.state.secondsLeft, 60);
  });

  test('a counted rep raises my score and beeps', () async {
    await vm.start();
    judge.closeRep();
    await frame(2);
    expect(vm.state.myReps, 1);
    expect(vm.state.feedback!.valid, isTrue);
    expect(vm.state.feedbackCount, 1);
    expect(sound.played, 1);
    expect(vm.state.remaining, const Duration(seconds: 58));
  });

  test('a rejected rep shows its reason and stays silent', () async {
    await vm.start();
    judge.closeRep(reason: RejectReason.tooFast);
    await frame(2);
    expect(vm.state.myReps, 0);
    expect(vm.state.myInvalidReps, 1);
    expect(vm.state.feedback!.reason, RejectReason.tooFast);
    expect(vm.state.feedbackCount, 1);
    expect(sound.played, 0);
  });

  test('every opponent rep moves the mannequin; counted ones score', () async {
    await vm.start();
    opponent
      ..emit()
      ..emit(reason: RejectReason.insufficientDepth)
      ..emit();
    await pumpEventQueue();
    expect(vm.state.opponentReps, 2);
    expect(vm.state.opponentMoves, 3);
    expect(vm.state.lead, -2);
  });

  test('the opponent is held while the app is away, and goes on while the '
      'camera reopens', () async {
    await vm.start();
    await frame(10);
    await vm.pause();
    expect(vm.state.phase, BattlePhase.paused);
    expect(opponent.running, isFalse);

    // Away for 15 seconds, which the round does not count.
    now = const Duration(seconds: 25);
    camera.startGate = Completer();
    unawaited(vm.resume());
    await pumpEventQueue();
    expect(vm.state.phase, BattlePhase.starting);
    expect(opponent.running, isTrue);

    camera.startGate!.complete();
    await pumpEventQueue();
    expect(vm.state.phase, BattlePhase.playing);
    expect(vm.state.remaining, const Duration(seconds: 50));
    expect(opponent.startCount, 1);
  });

  test('time up ends the round once, with the final score', () async {
    await vm.start();
    judge.closeRep();
    await frame(5);
    judge.closeRep(reason: RejectReason.shouldersNotLevel);
    await frame(9);
    opponent
      ..emit()
      ..emit();
    await pumpEventQueue();

    await frame(60);
    expect(vm.state.phase, BattlePhase.timeUp);
    expect(vm.state.secondsLeft, 0);
    expect(opponent.stopped, isTrue);
    final result = vm.state.result!;
    expect(result.matchup, same(_matchup));
    expect(result.myReps, 1);
    expect(result.myInvalidReps, 1);
    expect(result.opponentReps, 2);
    expect(result.endedAt, _endedAt);

    // A late opponent rep changes nothing.
    opponent.emit();
    await pumpEventQueue();
    expect(vm.state.opponentReps, 2);
    expect(vm.state.result, same(result));
  });

  test('a battle that runs its full time is saved once', () async {
    await vm.start();
    judge.closeRep();
    await frame(5);
    opponent.emit();
    await pumpEventQueue();
    await frame(60);
    await pumpEventQueue();
    expect(repository.saved, hasLength(1));
    final record = repository.saved.single;
    expect(record.exercise, ExerciseType.pushUp);
    expect(record.opponentName, 'RepBot');
    expect(record.myReps, 1);
    expect(record.opponentReps, 1);
    expect(vm.state.result!.roundLength, battleDuration);
  });

  test('a battle left early is not saved', () async {
    await vm.start();
    judge.closeRep();
    await frame(5);
    vm.leave();
    await pumpEventQueue();
    expect(repository.saved, isEmpty);
  });

  test('a failed save still shows the result', () async {
    repository.saveError = Exception('offline');
    await vm.start();
    await frame(60);
    await pumpEventQueue();
    expect(vm.state.phase, BattlePhase.timeUp);
    expect(vm.state.result, isNotNull);
  });

  test('the rep closed by the last frame counts and still beeps', () async {
    await vm.start();
    judge.closeRep();
    await frame(60);
    expect(vm.state.phase, BattlePhase.timeUp);
    expect(vm.state.result!.myReps, 1);
    expect(vm.state.feedback!.valid, isTrue);
    expect(sound.played, 1);
  });

  test('leaving stops the round and keeps nothing', () async {
    await vm.start();
    judge.closeRep();
    await frame(5);
    vm.leave();
    expect(vm.state.phase, BattlePhase.left);
    expect(vm.state.result, isNull);
    expect(opponent.stopped, isTrue);
    expect(vm.counter.state.roundEnd, RoundEnd.stopped);
    await pumpEventQueue();
    expect(camera.isStreaming, isFalse);

    opponent.emit();
    await pumpEventQueue();
    expect(vm.state.opponentReps, 0);
  });

  test('leaving while the camera opens never starts the opponent', () async {
    camera.startGate = Completer();
    unawaited(vm.start());
    await pumpEventQueue();
    vm.leave();
    camera.startGate!.complete();
    await pumpEventQueue();
    expect(vm.state.phase, BattlePhase.left);
    expect(opponent.startCount, 0);
    expect(camera.isStreaming, isFalse);
  });

  test(
    'a camera failure holds the opponent; retry restarts both sides',
    () async {
      await vm.start();
      judge.closeRep();
      await frame(5);
      opponent.emit();
      await pumpEventQueue();

      // Pose detection keeps failing for 3 seconds.
      await failedFrame(6);
      await failedFrame(9);
      expect(vm.state.phase, BattlePhase.failed);
      expect(opponent.running, isFalse);
      expect(vm.state.myReps, 1);

      await vm.retry();
      expect(vm.state.phase, BattlePhase.playing);
      expect(vm.state.myReps, 0);
      expect(vm.state.opponentReps, 0);
      expect(vm.state.feedback, isNull);
      expect(vm.state.remaining, battleDuration);
      expect(opponent.startCount, 2);
      expect(opponent.running, isTrue);
    },
  );

  test('without frames, the watchdog ends the round 2 seconds late', () {
    fakeAsync((async) {
      final opponent = FakeOpponentSource();
      final battle = BattleViewModel(
        matchup: _matchup,
        counter: RepCounterViewModel(
          camera: FakeCameraService(),
          estimator: FakePoseEstimator(),
          judge: FakeRepJudge(),
          clock: () => async.elapsed,
          roundLength: battleDuration,
        ),
        opponent: opponent,
        repository: FakeUserRepository(),
        sound: FakeRepSound(),
        now: () => _endedAt,
      );
      battle.start();
      async.flushMicrotasks();
      expect(battle.state.phase, BattlePhase.playing);

      // No frame ever comes, so the counter never notices the time.
      async.elapse(battleDuration);
      expect(battle.state.phase, BattlePhase.playing);
      async.elapse(const Duration(seconds: 2));
      expect(battle.state.phase, BattlePhase.timeUp);
      expect(battle.state.remaining, Duration.zero);
      expect(opponent.stopped, isTrue);

      battle.dispose();
      async.flushMicrotasks();
    });
  });
}
