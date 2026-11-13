import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/services/pose/squat_demo_judge.dart';
import 'package:gymrats_app/viewmodels/battle_viewmodel.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';

import '../support/fakes.dart';
import '../support/game_fakes.dart';
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
  late InMemoryFormReportStore reports;
  late Duration now;
  late BattleViewModel vm;

  setUp(() {
    camera = FakeCameraService();
    estimator = FakePoseEstimator();
    judge = FakeRepJudge();
    opponent = FakeOpponentSource();
    sound = FakeRepSound();
    repository = FakeUserRepository();
    reports = InMemoryFormReportStore();
    now = Duration.zero;
    vm = BattleViewModel(
      matchup: _matchup,
      counter: RepCounterViewModel(
        camera: camera,
        estimator: estimator,
        judge: judge,
        clock: () => now,
        roundLength: battleDuration,
        phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
      ),
      opponent: opponent,
      repository: repository,
      sound: sound,
      formReports: reports,
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
    expect(vm.state.secondsLeft, 30);
  });

  test('a counted rep raises my score and beeps', () async {
    await vm.start();
    judge.closeRep();
    await frame(2);
    expect(vm.state.myReps, 1);
    expect(vm.state.feedback!.valid, isTrue);
    expect(vm.state.feedbackCount, 1);
    expect(sound.played, 1);
    expect(vm.state.remaining, const Duration(seconds: 28));
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

  test('every opponent rep swings the opponent; counted ones score', () async {
    await vm.start();
    opponent
      ..emit()
      ..emit(reason: RejectReason.insufficientDepth)
      ..emit();
    await pumpEventQueue();
    expect(vm.state.opponentReps, 2);
    expect(vm.state.opponentMoves, 3);
    expect(vm.state.lead, -20);
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
    expect(vm.state.remaining, const Duration(seconds: 20));
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

  test('a squat bot battle is saved too, with no form report', () async {
    final squat = BattleViewModel(
      matchup: const Matchup(
        exercise: ExerciseType.squat,
        playerName: '우현',
        opponent: Opponent(name: 'AI 봇 · 고수', isBot: true),
      ),
      counter: RepCounterViewModel(
        camera: camera,
        estimator: estimator,
        judge: judge,
        clock: () => now,
        roundLength: battleDuration,
        phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
      ),
      opponent: opponent,
      repository: repository,
      sound: sound,
      formReports: reports,
      now: () => _endedAt,
    );
    addTearDown(squat.dispose);
    await squat.start();
    judge.closeRep();
    await frame(5);
    opponent.emit();
    await pumpEventQueue();
    await frame(60);
    await pumpEventQueue();
    final record = repository.saved.single;
    expect(record.exercise, ExerciseType.squat);
    expect(record.opponentName, 'AI 봇 · 고수');
    expect(record.myReps, 1);
    expect(record.opponentReps, 1);
    expect(record.myScore, greaterThan(0));
    expect(record.opponentScore, greaterThan(0));
    expect(repository.savedReports.single, isNull);
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
    // The game's points go up with the reps, as the result shows them.
    expect(record.myScore, greaterThan(0));
    expect(record.myScore, vm.state.result!.myScore);
    expect(record.opponentScore, vm.state.result!.opponentScore);
    // So is the game's outcome: a saved battle never falls back on its reps.
    expect(record.decidedOutcome, isNotNull);
    expect(record.decidedOutcome, vm.state.result!.outcome);
    expect(vm.state.result!.roundLength, battleDuration);
    // The form report goes up with the battle.
    expect(repository.savedReports.single, same(vm.state.result!.form));
  });

  test('a full battle keeps its form report, with the rep times', () async {
    await vm.start();
    judge.closeRep();
    await frame(5);
    judge.closeRep(reason: RejectReason.tooFast);
    await frame(9);
    await frame(60);
    await pumpEventQueue();

    final form = vm.state.result!.form!;
    expect(form.endedAt, _endedAt);
    expect(form.opponentName, 'RepBot');
    expect(
      [for (final r in form.reps) r.at],
      const [Duration(seconds: 5), Duration(seconds: 9)],
    );
    expect(form.reps.last.reason, RejectReason.tooFast);
    expect(form.samples, isNotEmpty);
    expect(await reports.list(), [same(form)]);
  });

  test('a battle left early is not saved', () async {
    await vm.start();
    judge.closeRep();
    await frame(5);
    vm.leave();
    await pumpEventQueue();
    expect(repository.saved, isEmpty);
    expect(await reports.list(), isEmpty);
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
          phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
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

  group('the game', () {
    late FakeCameraService camera;
    late FakePoseEstimator estimator;
    late DepthRepJudge judge;
    late TimedOpponentSource opponent;
    late FakeUserRepository repository;
    late Duration now;
    late BattleViewModel battle;

    setUp(() {
      camera = FakeCameraService();
      estimator = FakePoseEstimator();
      judge = DepthRepJudge();
      opponent = TimedOpponentSource();
      repository = FakeUserRepository();
      now = Duration.zero;
      battle = BattleViewModel(
        matchup: _matchup,
        counter: RepCounterViewModel(
          camera: camera,
          estimator: estimator,
          judge: judge,
          clock: () => now,
          roundLength: battleDuration,
          phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
        ),
        opponent: opponent,
        repository: repository,
        sound: FakeRepSound(),
        now: () => _endedAt,
      );
    });

    tearDown(() => battle.dispose());

    /// One camera frame [seconds] into the clock.
    Future<void> frame(double seconds) async {
      now = Duration(milliseconds: (seconds * 1000).round());
      estimator.frames.add(emptyFrame());
      camera.emit();
      await pumpEventQueue();
    }

    /// A frame at [seconds] that closes my rep.
    Future<void> myRep(
      double seconds, {
      double? maxDepth,
      RejectReason? reason,
      double? minElbowAngle,
    }) async {
      judge.closeRep(
        maxDepth: maxDepth,
        reason: reason,
        minElbowAngle: minElbowAngle,
      );
      await frame(seconds);
    }

    Future<void> theirRep(double seconds, {RejectReason? reason}) async {
      opponent.emitAt(seconds, reason: reason);
      await pumpEventQueue();
    }

    test("a rep's grade goes by its judge's pass depth", () async {
      final shallowJudge = DepthRepJudge(
        config: const RepJudgeConfig(bottomDepth: .75),
      );
      final other = BattleViewModel(
        matchup: _matchup,
        counter: RepCounterViewModel(
          camera: camera,
          estimator: estimator,
          judge: shallowJudge,
          clock: () => now,
          roundLength: battleDuration,
          phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
        ),
        opponent: TimedOpponentSource(),
        repository: FakeUserRepository(),
        sound: FakeRepSound(),
        now: () => _endedAt,
      );
      addTearDown(other.dispose);
      await other.start();

      // 1.6 x 0.75: a push-up at this depth would only be good.
      shallowJudge.closeRep(maxDepth: 1.2);
      await frame(3);
      expect(other.state.myLastScore!.grade, GameGrade.excellent);

      shallowJudge.closeRep(maxDepth: 1.19);
      await frame(9);
      expect(other.state.myLastScore!.grade, GameGrade.good);
    });

    test('a valid rep pushes the bar and scores by its depth', () async {
      await battle.start();
      expect(battle.state.myBarShare, 0.5);

      await myRep(3, maxDepth: 1.45);
      expect(battle.state.myScore, 10);
      expect(battle.state.myLastScore!.grade, GameGrade.good);
      expect(battle.state.myBarShare, closeTo(0.55, 1e-9));

      await myRep(9, maxDepth: 1.8);
      expect(battle.state.myScore, 25);
      expect(battle.state.myLastScore!.grade, GameGrade.excellent);
      expect(battle.state.myLastScore!.points, 15);
    });

    test('a rep with no depth is good', () async {
      await battle.start();
      await myRep(3);
      expect(battle.state.myLastScore!.grade, GameGrade.good);
    });

    test('the combo goes by round time, not by the judge clock', () async {
      await battle.start();
      await myRep(3);
      await myRep(4.2);
      expect(battle.state.myScore, 25);
      expect(battle.state.myLastScore!.combo, 2);

      await myRep(10);
      expect(battle.state.myLastScore!.combo, 1);
    });

    test(
      'a camera permission lost and back does not lose later reps',
      () async {
        await battle.start();
        await myRep(3);

        camera.permission = CameraPermission.denied;
        await battle.pause();
        await battle.resume();
        await pumpEventQueue();
        expect(battle.state.phase, BattlePhase.failed);

        camera.permission = CameraPermission.granted;
        await battle.pause();
        await battle.resume();
        await pumpEventQueue();
        expect(battle.state.phase, BattlePhase.playing);

        await myRep(8);
        expect(battle.state.myScore, 20);
      },
    );

    test('a rejected rep scores nothing, breaks the combo, and keeps the '
        'last score', () async {
      await battle.start();
      await myRep(3);
      await myRep(3.5, reason: RejectReason.insufficientDepth);
      expect(battle.state.myScore, 10);
      expect(battle.state.myInvalidReps, 1);
      expect(battle.state.myLastScore!.points, 10);

      await myRep(4);
      expect(battle.state.myScore, 20);
      expect(battle.state.myLastScore!.combo, 1);
    });

    test('a Go lower rep with bent elbows reaches the game with its angle: '
        'the score and the bar move, and it stays rejected', () async {
      await battle.start();
      await myRep(3, reason: RejectReason.insufficientDepth, minElbowAngle: 90);
      expect(battle.state.myScore, 5);
      expect(battle.state.myBarShare, closeTo(0.525, 1e-9));
      expect(battle.state.myLastScore!.grade, GameGrade.average);
      expect(battle.state.myLastScore!.points, 5);
      expect(battle.state.myReps, 0);
      expect(battle.state.myInvalidReps, 1);
      expect(battle.state.feedback!.reason, RejectReason.insufficientDepth);
    });

    test(
      'a Go lower rep above the angle, or with none, scores nothing',
      () async {
        await battle.start();
        await myRep(
          3,
          reason: RejectReason.insufficientDepth,
          minElbowAngle: 130,
        );
        await myRep(5, reason: RejectReason.insufficientDepth);
        expect(battle.state.myScore, 0);
        expect(battle.state.myLastScore, isNull);
        expect(battle.state.myInvalidReps, 2);
      },
    );

    test(
      "an average rep is in the final score and not in the valid reps",
      () async {
        await battle.start();
        await myRep(
          21,
          reason: RejectReason.insufficientDepth,
          minElbowAngle: 90,
        );
        await frame(30);
        final result = battle.state.result!;
        expect(result.myScore, 10);
        expect(result.myReps, 0);
        expect(result.myInvalidReps, 1);
      },
    );

    test(
      "the opponent's rejected rep has no angle and scores nothing",
      () async {
        await battle.start();
        await theirRep(3, reason: RejectReason.insufficientDepth);
        expect(battle.state.opponentScore, 0);
        expect(battle.state.opponentLastScore, isNull);
      },
    );

    test('fever turns on at its start and doubles the points', () async {
      await battle.start();
      await frame(19.9);
      expect(battle.state.fever, isFalse);

      await myRep(20);
      expect(battle.state.fever, isTrue);
      expect(battle.state.myScore, 20);
      expect(battle.state.myLastScore!.fever, isTrue);
    });

    test('time in the background does not bring fever closer', () async {
      await battle.start();
      await frame(10);
      await battle.pause();
      now = const Duration(seconds: 25);
      await battle.resume();
      await pumpEventQueue();

      await myRep(27);
      expect(battle.state.remaining, const Duration(seconds: 28 - 10));
      expect(battle.state.fever, isFalse);
      expect(battle.state.myScore, 10);
    });

    test("the opponent's reps push the bar back and bring danger", () async {
      await battle.start();
      for (final seconds in [3.0, 6.0, 9.0, 12.0, 15.0]) {
        await theirRep(seconds);
      }
      expect(battle.state.opponentScore, 50);
      expect(battle.state.opponentLastScore!.points, 10);
      expect(battle.state.danger, isFalse);

      await theirRep(18);
      expect(battle.state.opponentScore, 60);
      expect(battle.state.myBarShare, closeTo(0.2, 1e-9));
      expect(battle.state.danger, isTrue);

      await myRep(19);
      expect(battle.state.danger, isFalse);
    });

    test(
      'a rejected opponent rep swings the opponent and scores nothing',
      () async {
        await battle.start();
        await theirRep(3, reason: RejectReason.bellyDown);
        expect(battle.state.opponentMoves, 1);
        expect(battle.state.opponentScore, 0);
        expect(battle.state.opponentLastScore, isNull);
      },
    );

    test('my KO ends the round at once, and the battle is saved', () async {
      await battle.start();
      await myRep(21, maxDepth: 1.8);
      await myRep(22, maxDepth: 1.8);
      expect(battle.state.phase, BattlePhase.playing);

      await myRep(23, maxDepth: 1.8);
      expect(battle.state.phase, BattlePhase.timeUp);
      final result = battle.state.result!;
      expect(result.end, GameEnd.ko);
      expect(result.myScore, 110);
      expect(result.opponentScore, 0);
      expect(result.myReps, 3);
      expect(result.outcome, MatchOutcome.win);
      expect(battle.state.myBarShare, 1);
      expect(battle.state.remaining, const Duration(seconds: 7));
      expect(opponent.stopped, isTrue);
      expect(battle.counter.state.roundEnd, RoundEnd.timeUp);
      await pumpEventQueue();
      expect(camera.isStreaming, isFalse);
      expect(repository.saved, hasLength(1));
    });

    test(
      'a KO on the last frame keeps the round length to the full round',
      () async {
        await battle.start();
        await myRep(28, maxDepth: 1.8);
        await myRep(29, maxDepth: 1.8);
        await myRep(30, maxDepth: 1.8);
        final ko = battle.state.result!;
        expect(ko.end, GameEnd.ko);
        expect(ko.roundLength, battleDuration);
      },
    );

    test('after a KO the round length is the time played in whole seconds, '
        'rounded up so the KO rep stays inside it; a full round keeps its '
        'full length', () async {
      await battle.start();
      await myRep(21, maxDepth: 1.8);
      await myRep(22, maxDepth: 1.8);
      await myRep(23, maxDepth: 1.8);
      final ko = battle.state.result!;
      expect(ko.roundLength, const Duration(seconds: 24));
      expect(ko.form!.roundLength, const Duration(seconds: 24));
      expect(ko.form!.reps.last.at, lessThan(ko.form!.roundLength));

      final other = BattleViewModel(
        matchup: _matchup,
        counter: RepCounterViewModel(
          camera: camera,
          estimator: estimator,
          judge: judge,
          clock: () => now,
          roundLength: battleDuration,
          phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
        ),
        opponent: TimedOpponentSource(),
        repository: FakeUserRepository(),
        sound: FakeRepSound(),
        now: () => _endedAt,
      );
      addTearDown(other.dispose);
      now = Duration.zero;
      await other.start();
      await frame(30);
      final full = other.state.result!;
      expect(full.end, GameEnd.timeUp);
      expect(full.roundLength, battleDuration);
      expect(full.form!.roundLength, battleDuration);
    });

    test(
      "the opponent's KO ends the round; later reps count for nothing",
      () async {
        await battle.start();
        await myRep(5);
        await frame(24);
        for (final seconds in [21.0, 22.0, 23.0]) {
          await theirRep(seconds);
        }
        expect(battle.state.phase, BattlePhase.playing);

        await theirRep(24);
        expect(battle.state.phase, BattlePhase.timeUp);
        final result = battle.state.result!;
        expect(result.end, GameEnd.ko);
        expect(result.myScore, 10);
        expect(result.opponentScore, 110);
        expect(result.opponentReps, 4);
        expect(result.outcome, MatchOutcome.lose);
        expect(result.record.outcome, MatchOutcome.lose);
        expect(opponent.stopped, isTrue);

        await theirRep(25);
        expect(battle.state.opponentScore, 110);
        expect(battle.state.opponentReps, 4);
        await pumpEventQueue();
        expect(repository.saved, hasLength(1));
      },
    );

    test('at time up the game score decides, not the reps', () async {
      await battle.start();
      await myRep(21, maxDepth: 1.8);
      await theirRep(5);
      await theirRep(10);
      await frame(30);
      final result = battle.state.result!;
      expect(result.end, GameEnd.timeUp);
      expect(result.myReps, lessThan(result.opponentReps));
      expect(result.outcome, MatchOutcome.win);
      expect(result.record.outcome, MatchOutcome.win);
    });

    test('the rep closed by the last frame is in the final score', () async {
      await battle.start();
      await myRep(30);
      final result = battle.state.result!;
      expect(result.myReps, 1);
      expect(result.myScore, 20);
      expect(result.end, GameEnd.timeUp);
    });

    test(
      'a failed counter does not score again; retry starts from zero',
      () async {
        await battle.start();
        await myRep(3);
        await theirRep(4);
        now = const Duration(seconds: 5);
        estimator.frames.add(null);
        camera.emit();
        await pumpEventQueue();
        now = const Duration(seconds: 9);
        estimator.frames.add(null);
        camera.emit();
        await pumpEventQueue();
        expect(battle.state.phase, BattlePhase.failed);
        expect(battle.state.myScore, 10);

        await battle.retry();
        now = const Duration(seconds: 10);
        expect(battle.state.myScore, 0);
        expect(battle.state.opponentScore, 0);
        expect(battle.state.myBarShare, 0.5);
        expect(battle.state.myLastScore, isNull);
        expect(battle.state.opponentLastScore, isNull);

        await myRep(12);
        expect(battle.state.myScore, 10);
        expect(battle.state.myLastScore!.combo, 1);
      },
    );
  });

  group('the setup before the round', () {
    late BattleViewModel battle;
    late RepCounterViewModel counter;
    late PhoneTiltMonitor phone;

    setUp(() {
      phone = PhoneTiltMonitor(samples: const Stream.empty())
        ..isPropped = true
        ..isStill = true;
      counter = RepCounterViewModel(
        camera: camera,
        estimator: estimator,
        judge: judge,
        clock: () => now,
        // As the screen makes it: its clock also runs through the setup.
        roundLength: const Duration(days: 1),
        phoneTilt: phone,
      );
      battle = BattleViewModel(
        matchup: _matchup,
        counter: counter,
        opponent: opponent,
        repository: repository,
        sound: sound,
        formReports: reports,
        setup: SetupChecker(
          exercise: ExerciseType.pushUp,
          config: const SetupConfig(
            readyDelay: Duration.zero,
            dropDelay: Duration.zero,
          ),
          clock: () => now,
        ),
        clock: () => now,
        now: () => _endedAt,
      );
    });

    tearDown(() => battle.dispose());

    /// A camera frame at [seconds], with the setup pose found or not.
    Future<void> pose(double seconds, {bool found = true}) async {
      now = Duration(milliseconds: (seconds * 1000).round());
      estimator.frames.add(found ? standingFrame() : emptyFrame());
      camera.emit();
      await pumpEventQueue();
    }

    /// Sets up and counts down from [seconds]: the round begins 3 s later.
    Future<void> begin(double seconds) async {
      await battle.start();
      await pose(seconds);
      await pose(seconds + 3);
      expect(battle.state.started, isTrue);
    }

    test('the camera runs in the setup: the pose is checked while the '
        'opponent and the round clock wait', () async {
      await battle.start();
      expect(battle.state.phase, BattlePhase.setup);
      expect(battle.state.started, isFalse);
      await pose(1, found: false);
      expect(battle.state.setup.isReady, isFalse);
      expect(battle.state.setup.reason, SetupReason.noPerson);
      expect(battle.state.startIn, isNull);
      expect(battle.state.canStart, isFalse);
      // A minute of setting up takes nothing off the round.
      await pose(61, found: false);
      expect(battle.state.phase, BattlePhase.setup);
      expect(battle.state.remaining, battleDuration);
      expect(opponent.startCount, 0);
      expect(counter.state.phase, CounterPhase.running);
    });

    test('a ready pose counts down 3 seconds, then the round begins: the '
        'opponent starts and the clock runs from 30', () async {
      await battle.start();
      await pose(1);
      expect(battle.state.setup.isReady, isTrue);
      expect(battle.state.startIn, const Duration(seconds: 3));
      expect(battle.state.canStart, isTrue);
      await pose(2.25);
      expect(battle.state.startIn, const Duration(milliseconds: 1750));
      expect(battle.state.started, isFalse);
      expect(opponent.startCount, 0);

      await pose(4);
      expect(battle.state.started, isTrue);
      expect(battle.state.phase, BattlePhase.playing);
      expect(battle.state.startIn, isNull);
      expect(opponent.startCount, 1);
      expect(opponent.running, isTrue);
      expect(battle.state.remaining, battleDuration);
      await pose(14);
      expect(battle.state.remaining, const Duration(seconds: 20));
      // Fever by the round's clock, from 20 s into it: not since the camera.
      await pose(23.9);
      expect(battle.state.fever, isFalse);
      await pose(24);
      expect(battle.state.fever, isTrue);
    });

    test(
      'losing the pose stops the count; found again, it starts over',
      () async {
        await battle.start();
        await pose(1);
        await pose(3);
        expect(battle.state.startIn, const Duration(seconds: 1));
        await pose(3.5, found: false);
        expect(battle.state.startIn, isNull);
        expect(battle.state.setup.isReady, isFalse);
        await pose(5);
        expect(battle.state.startIn, const Duration(seconds: 3));
        await pose(7);
        expect(battle.state.started, isFalse);
        await pose(8);
        expect(battle.state.started, isTrue);
      },
    );

    test(
      'Start begins the round at once, only while the pose is ready',
      () async {
        await battle.start();
        battle.startNow();
        expect(battle.state.started, isFalse);
        await pose(1, found: false);
        battle.startNow();
        expect(battle.state.started, isFalse);
        await pose(2);
        battle.startNow();
        expect(battle.state.started, isTrue);
        expect(battle.state.canStart, isFalse);
        expect(opponent.startCount, 1);
        // Once begun, pressing again changes nothing.
        battle.startNow();
        expect(opponent.startCount, 1);
      },
    );

    test('reps in the setup count for nothing: no score, no banner, no beep; '
        'the round counts from zero', () async {
      await battle.start();
      judge.closeRep();
      await pose(1);
      judge.closeRep(reason: RejectReason.tooFast);
      await pose(2);
      expect(counter.history, hasLength(2));
      expect(battle.state.myReps, 0);
      expect(battle.state.myInvalidReps, 0);
      expect(battle.state.myScore, 0);
      expect(battle.state.feedbackCount, 0);
      expect(sound.played, 0);

      await pose(4);
      expect(battle.state.started, isTrue);
      expect(counter.history, isEmpty);
      judge.closeRep();
      await pose(10);
      expect(battle.state.myReps, 1);
      expect(battle.state.myScore, 10);
      expect(battle.state.feedbackCount, 1);
      expect(sound.played, 1);
    });

    test("the opponent's reps before the round count for nothing", () async {
      await battle.start();
      await pose(1);
      opponent.emit();
      await pumpEventQueue();
      expect(battle.state.opponentReps, 0);
      expect(battle.state.opponentMoves, 0);
      expect(battle.state.opponentScore, 0);
    });

    test("the round ends by its own clock, 30 s after it began, though the "
        "counter's would run a day; the rep times are the round's", () async {
      await begin(1);
      judge.closeRep();
      await pose(10);
      await pose(33.9);
      expect(battle.state.phase, BattlePhase.playing);
      expect(battle.state.remaining, const Duration(milliseconds: 100));
      await pose(34);
      await pumpEventQueue();
      expect(battle.state.phase, BattlePhase.timeUp);
      expect(battle.state.remaining, Duration.zero);
      final result = battle.state.result!;
      expect(result.roundLength, battleDuration);
      expect(result.myReps, 1);
      expect(result.form!.reps.single.at, const Duration(seconds: 6));
      expect(counter.state.phase, CounterPhase.finished);
      expect(opponent.stopped, isTrue);
      expect(repository.saved, hasLength(1));
    });

    test(
      'a KO counts its round length from the start, not from the setup',
      () async {
        await begin(1);
        await pose(9.5);
        for (var i = 0; i < 10; i++) {
          opponent.emit();
        }
        await pumpEventQueue();
        expect(battle.state.phase, BattlePhase.timeUp);
        expect(battle.state.result!.end, GameEnd.ko);
        // 5.5 s into the round, rounded up.
        expect(battle.state.result!.roundLength, const Duration(seconds: 6));
      },
    );

    test('the watchdog ends a round without frames 2 s after its time', () {
      fakeAsync((async) {
        unawaited(battle.start());
        async.flushMicrotasks();
        unawaited(pose(1));
        async.flushMicrotasks();
        unawaited(pose(4));
        async.flushMicrotasks();
        expect(battle.state.started, isTrue);
        // No frames from here: the counter never sees its time run out.
        now = const Duration(seconds: 36);
        async.elapse(const Duration(seconds: 31));
        expect(battle.state.phase, BattlePhase.playing);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(battle.state.phase, BattlePhase.timeUp);
      });
    });

    test('the app in the background starts the setup over', () async {
      await battle.start();
      await pose(1);
      await pose(2);
      expect(battle.state.startIn, const Duration(seconds: 2));
      await battle.pause();
      expect(battle.state.phase, BattlePhase.paused);
      expect(battle.state.startIn, isNull);
      expect(battle.state.setup.isReady, isFalse);
      await battle.resume();
      await pumpEventQueue();
      expect(battle.state.phase, BattlePhase.setup);
      await pose(3);
      expect(battle.state.startIn, const Duration(seconds: 3));
      expect(opponent.startCount, 0);
    });

    test('a camera failure in the round: retry sets up again, then plays '
        'from zero', () async {
      await begin(1);
      judge.closeRep();
      await pose(6);
      expect(battle.state.myScore, 10);
      now = const Duration(seconds: 7);
      estimator.frames.add(null);
      camera.emit();
      await pumpEventQueue();
      now = const Duration(seconds: 11);
      estimator.frames.add(null);
      camera.emit();
      await pumpEventQueue();
      expect(battle.state.phase, BattlePhase.failed);
      expect(opponent.running, isFalse);

      await battle.retry();
      expect(battle.state.started, isFalse);
      expect(battle.state.phase, BattlePhase.setup);
      expect(battle.state.myScore, 0);
      expect(opponent.stopped, isTrue);
      await pose(12);
      await pose(15);
      expect(battle.state.started, isTrue);
      expect(opponent.startCount, 2);
      expect(battle.state.remaining, battleDuration);
    });

    test(
      'leaving in the setup never starts the opponent and keeps nothing',
      () async {
        await battle.start();
        await pose(1);
        battle.leave();
        await pumpEventQueue();
        expect(battle.state.phase, BattlePhase.left);
        await pose(5);
        expect(opponent.startCount, 0);
        expect(battle.state.started, isFalse);
        expect(repository.saved, isEmpty);
      },
    );

    test('a phone that is not propped up keeps the setup waiting', () async {
      phone.isPropped = false;
      await battle.start();
      await pose(1);
      expect(battle.state.setup.reason, SetupReason.phoneTooFlat);
      expect(battle.state.startIn, isNull);
      await pose(5);
      expect(battle.state.started, isFalse);
    });

    test("a rep closed on the frame that ends the count is the setup's: no "
        'banner, no beep, no score', () async {
      await battle.start();
      await pose(1);
      judge.closeRep();
      // This frame ends the count and closes the rep; the rep reaches the
      // view model only after the round has begun.
      await pose(4);
      expect(battle.state.started, isTrue);
      expect(counter.history, isEmpty);
      expect(battle.state.feedbackCount, 0);
      expect(battle.state.feedback, isNull);
      expect(sound.played, 0);
      expect((battle.state.myScore, battle.state.myReps), (0, 0));
    });
  });

  group('BattleViewModel.bot, as the battle screen makes it', () {
    late PhoneTiltMonitor phone;
    late BattleViewModel battle;

    setUp(() {
      phone = PhoneTiltMonitor(samples: const Stream.empty())
        ..isPropped = true
        ..isStill = true;
    });

    tearDown(() => battle.dispose());

    BattleViewModel make(ExerciseType exercise) => BattleViewModel.bot(
      matchup: Matchup(
        exercise: exercise,
        playerName: '우현',
        opponent: const Opponent(name: 'RepBot', isBot: true),
      ),
      counter: BattleViewModel.botCounter(
        exercise,
        camera: camera,
        estimator: estimator,
        phoneTilt: phone,
        clock: () => now,
      ),
      opponent: opponent,
      repository: repository,
      sound: sound,
      formReports: reports,
      clock: () => now,
    );

    Future<void> frameAt(double seconds, PoseFrame pose) async {
      now = Duration(milliseconds: (seconds * 1000).round());
      estimator.frames.add(pose);
      camera.emit();
      await pumpEventQueue();
    }

    test('a push-up battle sets up first with the setup\'s own times: held '
        '1.5 s, then 3, 2, 1; the counter runs a day and the round ends 30 s '
        'after it began', () async {
      battle = make(ExerciseType.pushUp);
      expect(battle.counter.roundLength, BattleViewModel.counterRound);
      expect(battle.counter.exercise, ExerciseType.pushUp);
      expect(battle.roundLength, battleDuration);
      await battle.start();
      expect(battle.state.phase, BattlePhase.setup);
      // Forty seconds of setting up take nothing off the round.
      await frameAt(40, emptyFrame());
      expect(battle.state.started, isFalse);
      expect(battle.state.remaining, battleDuration);
      expect(battle.counter.state.phase, CounterPhase.running);
      expect(opponent.startCount, 0);

      await frameAt(41, standingFrame());
      expect(battle.state.setup.isReady, isFalse);
      await frameAt(42.5, standingFrame());
      expect(battle.state.setup.isReady, isTrue);
      expect(battle.state.startIn, const Duration(seconds: 3));
      await frameAt(45.4, standingFrame());
      expect(battle.state.started, isFalse);
      await frameAt(45.5, standingFrame());
      expect(battle.state.started, isTrue);
      expect(opponent.startCount, 1);

      await frameAt(75.4, standingFrame());
      expect(battle.state.phase, BattlePhase.playing);
      expect(battle.state.remaining, const Duration(milliseconds: 100));
      await frameAt(75.5, standingFrame());
      await pumpEventQueue();
      expect(battle.state.phase, BattlePhase.timeUp);
      expect(battle.state.result!.roundLength, battleDuration);
      // The battle and its form report are kept, as the result screen and
      // the feedback need.
      await pumpEventQueue();
      expect(repository.saved, hasLength(1));
      expect(await reports.list(), hasLength(1));
    });

    test(
      'a squat battle checks the whole body standing and judges squats',
      () async {
        battle = make(ExerciseType.squat);
        expect(battle.counter.exercise, ExerciseType.squat);
        expect(battle.counter.passDepth, SquatDemoJudge().passDepth);
        await battle.start();
        // Legs hidden, as in a push-up seen from the floor: not a squat setup.
        await frameAt(1, standingFrame());
        await frameAt(3, standingFrame());
        expect(battle.state.setup.isReady, isFalse);
        expect(battle.state.setup.reason, SetupReason.missingParts);
        await frameAt(4, standingFrame(showHips: true));
        await frameAt(5.5, standingFrame(showHips: true));
        expect(battle.state.setup.isReady, isTrue);
        await frameAt(8.5, standingFrame(showHips: true));
        expect(battle.state.started, isTrue);
      },
    );

    test('a squat counts by the lenient squat judge of the bot battle, which '
        'a moved phone does not overrule', () async {
      battle = make(ExerciseType.squat);
      await battle.start();
      PoseFrame standing() => standingFrame(showHips: true);
      // The hips down at the knees: the bottom of a squat.
      PoseFrame down() => standingFrame(
        showHips: true,
        move: {
          BodyLandmark.leftHip: (530, 680),
          BodyLandmark.rightHip: (470, 680),
        },
      );
      await frameAt(1, standing());
      await frameAt(2.5, standing());
      await frameAt(5.5, standing());
      expect(battle.state.started, isTrue);
      // Beginning the round took the phone's angle; it moves after that.
      phone.isDisturbed = true;
      await frameAt(6, standing());
      await frameAt(6.8, down());
      await frameAt(7.6, standing());
      expect(battle.state.myReps, 1);
      expect(battle.state.myInvalidReps, 0);
      expect(battle.state.feedback!.valid, isTrue);
    });

    test("the app in the background starts the setup's hold over, with the "
        "setup's own times", () async {
      battle = make(ExerciseType.pushUp);
      await battle.start();
      await frameAt(1, standingFrame());
      await frameAt(2.5, standingFrame());
      expect(battle.state.setup.isReady, isTrue);
      expect(battle.state.startIn, const Duration(seconds: 3));
      await battle.pause();
      await battle.resume();
      await pumpEventQueue();
      expect(battle.state.phase, BattlePhase.setup);
      await frameAt(3, standingFrame());
      // Held again from here: not ready, nothing counting down.
      expect(battle.state.setup.isReady, isFalse);
      expect(battle.state.setup.readyProgress, 0);
      expect(battle.state.startIn, isNull);
      await frameAt(4.5, standingFrame());
      expect(battle.state.setup.isReady, isTrue);
      expect(battle.state.startIn, const Duration(seconds: 3));
    });
  });
}
