import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/battle_result.dart';
import '../models/matchup.dart';
import '../models/rep_event.dart';
import '../services/device/device_controls.dart';
import '../services/opponent/opponent_source.dart';
import 'rep_counter_viewmodel.dart';

/// Where the battle is.
enum BattlePhase {
  /// The camera is opening, before the round or after a pause.
  starting,

  /// The round is on.
  playing,

  /// The app is in the background; the round is held.
  paused,

  /// The camera or pose detection failed. Retrying restarts the round.
  failed,

  /// Time ran out; [BattleState.result] is set.
  timeUp,

  /// The user left before the end; nothing is kept.
  left,
}

/// Immutable state rendered by the battle screen.
class BattleState {
  const BattleState({
    this.phase = BattlePhase.starting,
    this.myReps = 0,
    this.myInvalidReps = 0,
    this.opponentReps = 0,
    required this.remaining,
    this.feedback,
    this.feedbackCount = 0,
    this.opponentMoves = 0,
    this.result,
  });

  final BattlePhase phase;

  /// The user's valid reps: their score.
  final int myReps;

  /// The user's reps that did not count.
  final int myInvalidReps;

  /// The opponent's valid reps: their score.
  final int opponentReps;

  /// Time left in the round, from the rep counter.
  final Duration remaining;

  /// The user's latest judged rep, for the banner; null before the first.
  final RepEvent? feedback;

  /// How many of the user's reps were judged, so the banner pops in for
  /// each one, even for two alike in a row.
  final int feedbackCount;

  /// How many reps the opponent made, valid or not. The mannequin dips once
  /// for each.
  final int opponentMoves;

  /// Set once time is up.
  final BattleResult? result;

  /// Whole seconds left, rounded up: 60 at the start, 0 at the end.
  int get secondsLeft =>
      (remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil();

  /// The user's lead; negative while behind.
  int get lead => myReps - opponentReps;

  BattleState copyWith({
    BattlePhase? phase,
    int? myReps,
    int? myInvalidReps,
    int? opponentReps,
    Duration? remaining,
    RepEvent? feedback,
    int? feedbackCount,
    int? opponentMoves,
    BattleResult? result,
  }) => BattleState(
    phase: phase ?? this.phase,
    myReps: myReps ?? this.myReps,
    myInvalidReps: myInvalidReps ?? this.myInvalidReps,
    opponentReps: opponentReps ?? this.opponentReps,
    remaining: remaining ?? this.remaining,
    feedback: feedback ?? this.feedback,
    feedbackCount: feedbackCount ?? this.feedbackCount,
    opponentMoves: opponentMoves ?? this.opponentMoves,
    result: result ?? this.result,
  );
}

/// Runs one battle: the user's reps and round clock from [counter], the
/// opponent's reps from an [OpponentSource], and the end of the round.
///
/// The opponent plays only while the user's round clock runs. It starts
/// when the camera first runs, goes on while the camera reopens, and is
/// held while the app is in the background or the camera has failed.
class BattleViewModel extends ChangeNotifier {
  BattleViewModel({
    required this.matchup,
    required this.counter,
    required this._opponent,
    required this._sound,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _state = BattleState(remaining: counter.roundLength);
    counter.addListener(_onCounterChanged);
    _myReps = counter.reps.listen(_onMyRep);
    _opponentReps = _opponent.reps.listen(_onOpponentRep);
  }

  final Matchup matchup;

  /// The user's camera, reps, and round clock. The screen shows its preview
  /// and landmarks directly.
  final RepCounterViewModel counter;

  final OpponentSource _opponent;
  final RepSound _sound;
  final DateTime Function() _now;
  late final StreamSubscription<RepEvent> _myReps;
  late final StreamSubscription<RepEvent> _opponentReps;

  late BattleState _state;
  bool _opponentStarted = false;
  bool _disposed = false;

  /// Ends the round if no frame does. The rep counter only checks its clock
  /// when a frame is processed, so a stalled camera would never end it.
  Timer? _watchdog;
  static const _watchdogGrace = Duration(seconds: 2);

  BattleState get state => _state;

  bool get _roundOver =>
      _state.phase == BattlePhase.timeUp || _state.phase == BattlePhase.left;

  /// Opens the camera; the round starts when it runs.
  Future<void> start() => counter.start();

  /// App moved to the background: the camera and the round are held.
  Future<void> pause() => counter.pause();

  /// App came back: the camera reopens and the round goes on.
  Future<void> resume() => counter.resume();

  /// Reopens the camera for the new screen orientation, keeping the score.
  Future<void> onScreenRotated() => counter.onScreenRotated();

  /// Restarts the round from zero on both sides after a camera failure.
  Future<void> retry() async {
    if (_state.phase != BattlePhase.failed) return;
    _opponent.stop();
    _opponentStarted = false;
    _setState(BattleState(remaining: counter.roundLength));
    await counter.retry();
  }

  /// Ends the battle early. Nothing is kept.
  void leave() {
    if (_roundOver) return;
    _watchdog?.cancel();
    _opponent.stop();
    _setState(_state.copyWith(phase: BattlePhase.left));
    unawaited(counter.finish(stoppedByUser: true));
  }

  void _onCounterChanged() {
    if (_roundOver) return;
    final counterState = counter.state;
    _syncOpponent(counterState.phase);
    _armWatchdog(counterState);
    switch (counterState.phase) {
      case CounterPhase.starting:
        _follow(counterState, BattlePhase.starting);
      case CounterPhase.running:
        _follow(counterState, BattlePhase.playing);
      case CounterPhase.paused:
        _follow(counterState, BattlePhase.paused);
      case CounterPhase.permissionDenied ||
          CounterPhase.cameraError ||
          CounterPhase.detectorError:
        // A failed counter may report zero counts. They are left as they
        // were, since retrying restarts the round anyway.
        _setState(_state.copyWith(phase: BattlePhase.failed));
      case CounterPhase.finished:
        _finishRound(counterState);
    }
  }

  /// Copies the user's side of the round from the counter.
  void _follow(RepCounterState counterState, BattlePhase phase) {
    _setState(
      _state.copyWith(
        phase: phase,
        myReps: counterState.validReps,
        myInvalidReps: counterState.invalidReps,
        remaining: counterState.remaining,
      ),
    );
  }

  /// Runs the opponent exactly while the counter's round clock runs: the
  /// counter only leaves out the time between pause and resume.
  void _syncOpponent(CounterPhase phase) {
    switch (phase) {
      case CounterPhase.running || CounterPhase.starting:
        if (_opponentStarted) {
          _opponent.resume();
        } else if (phase == CounterPhase.running) {
          _opponentStarted = true;
          _opponent.start();
        }
      case CounterPhase.paused ||
          CounterPhase.permissionDenied ||
          CounterPhase.cameraError ||
          CounterPhase.detectorError:
        _opponent.pause();
      case CounterPhase.finished:
        _opponent.stop();
    }
  }

  /// Rearms the watchdog for the time left, while the round clock runs.
  void _armWatchdog(RepCounterState counterState) {
    _watchdog?.cancel();
    final running =
        counterState.phase == CounterPhase.running ||
        counterState.phase == CounterPhase.starting;
    if (!_opponentStarted || !running) return;
    _watchdog = Timer(
      counterState.remaining + _watchdogGrace,
      () => unawaited(counter.finish()),
    );
  }

  /// Only a round that ran out of time has a result; [leave] stops the
  /// counter too, but marks the battle left first.
  void _finishRound(RepCounterState counterState) {
    _watchdog?.cancel();
    if (counterState.roundEnd != RoundEnd.timeUp) {
      _setState(_state.copyWith(phase: BattlePhase.left));
      return;
    }
    final result = BattleResult(
      matchup: matchup,
      myReps: counterState.validReps,
      myInvalidReps: counterState.invalidReps,
      opponentReps: _state.opponentReps,
      endedAt: _now(),
    );
    _setState(
      _state.copyWith(
        phase: BattlePhase.timeUp,
        myReps: result.myReps,
        myInvalidReps: result.myInvalidReps,
        remaining: counterState.remaining,
        result: result,
      ),
    );
  }

  /// The banner shows every verdict, and a counted rep beeps. The last rep
  /// can arrive just after time is up: it is in the final score already.
  void _onMyRep(RepEvent rep) {
    if (_state.phase == BattlePhase.left) return;
    if (rep.valid) _sound.playRepCounted();
    _setState(
      _state.copyWith(feedback: rep, feedbackCount: _state.feedbackCount + 1),
    );
  }

  void _onOpponentRep(RepEvent rep) {
    if (_roundOver) return;
    _setState(
      _state.copyWith(
        opponentReps: _state.opponentReps + (rep.valid ? 1 : 0),
        opponentMoves: _state.opponentMoves + 1,
      ),
    );
  }

  void _setState(BattleState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    counter.removeListener(_onCounterChanged);
    unawaited(_myReps.cancel());
    unawaited(_opponentReps.cancel());
    _opponent.dispose();
    counter.dispose();
    super.dispose();
  }
}
