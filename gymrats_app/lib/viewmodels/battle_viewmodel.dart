import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/battle_result.dart';
import '../models/battle_rules.dart';
import '../models/form_report.dart';
import '../models/game_score.dart';
import '../models/matchup.dart';
import '../models/rep_event.dart';
import '../services/device/device_controls.dart';
import '../services/feedback/form_report_store.dart';
import '../services/game/battle_game.dart';
import '../services/opponent/opponent_source.dart';
import '../services/pose/rep_judge.dart';
import '../services/user/user_repository.dart';
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

  /// Time ran out or a KO landed; [BattleState.result] is set.
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
    this.myScore = 0,
    this.opponentScore = 0,
    this.myBarShare = 0.5,
    this.danger = false,
    this.fever = false,
    this.myLastScore,
    this.opponentLastScore,
    required this.remaining,
    this.feedback,
    this.feedbackCount = 0,
    this.opponentMoves = 0,
    this.result,
  });

  final BattlePhase phase;

  /// The user's valid reps.
  final int myReps;

  /// The user's reps that did not count.
  final int myInvalidReps;

  /// The opponent's valid reps.
  final int opponentReps;

  /// The user's game score.
  final int myScore;

  /// The opponent's game score.
  final int opponentScore;

  /// The user's share of the health bar, from 0 to 1.
  final double myBarShare;

  /// Whether the user is about to lose: the screen edge flashes.
  final bool danger;

  /// Whether the round is in fever time.
  final bool fever;

  /// What the user's latest valid rep earned; null before the first.
  final GameRepScore? myLastScore;

  /// What the opponent's latest valid rep earned; null before the first.
  final GameRepScore? opponentLastScore;

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

  /// Whole seconds left, rounded up: the full round at the start, 0 at the end.
  int get secondsLeft =>
      (remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil();

  /// The user's lead; negative while behind.
  int get lead => myReps - opponentReps;

  BattleState copyWith({
    BattlePhase? phase,
    int? myReps,
    int? myInvalidReps,
    int? opponentReps,
    int? myScore,
    int? opponentScore,
    double? myBarShare,
    bool? danger,
    bool? fever,
    GameRepScore? myLastScore,
    GameRepScore? opponentLastScore,
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
    myScore: myScore ?? this.myScore,
    opponentScore: opponentScore ?? this.opponentScore,
    myBarShare: myBarShare ?? this.myBarShare,
    danger: danger ?? this.danger,
    fever: fever ?? this.fever,
    myLastScore: myLastScore ?? this.myLastScore,
    opponentLastScore: opponentLastScore ?? this.opponentLastScore,
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
///
/// Both players' reps also feed a [BattleGame], which keeps the game score,
/// the health bar, and the danger state. A KO ends the round at once.
///
/// A battle that ends by time or KO is saved to the [UserRepository] with
/// its form report, and the report also to the [FormReportStore] on this
/// phone; one left early is not.
class BattleViewModel extends ChangeNotifier {
  BattleViewModel({
    required this.matchup,
    required this.counter,
    required this._opponent,
    required this._repository,
    required this._sound,
    this._formReports,
    this._rules = battleRules,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _game = _newGame();
    _state = BattleState(remaining: counter.roundLength);
    counter.addListener(_onCounterChanged);
    _myRepSubscription = counter.reps.listen(_onMyRep);
    _opponentRepSubscription = _opponent.reps.listen(_onOpponentRep);
  }

  final Matchup matchup;

  /// The user's camera, reps, and round clock. The screen shows its preview
  /// and landmarks directly.
  final RepCounterViewModel counter;

  final OpponentSource _opponent;
  final UserRepository _repository;
  final RepSound _sound;
  final FormReportStore? _formReports;
  final BattleRules _rules;
  final DateTime Function() _now;
  late final StreamSubscription<RepEvent> _myRepSubscription;
  late final StreamSubscription<RepEvent> _opponentRepSubscription;

  late BattleState _state;
  late BattleGame _game;

  /// How many of the user's judged reps the game has seen.
  int _scoredMyReps = 0;

  /// Whether the counter's round clock has started: the camera has run once
  /// since [start] or [retry]. The opponent starts at the same moment.
  bool _roundClockStarted = false;
  bool _disposed = false;

  /// Ends the round if frames stop coming; see [_armWatchdog].
  Timer? _watchdog;

  /// How long past the end of the round the watchdog waits for the counter
  /// to end it by itself.
  static const _watchdogGrace = Duration(seconds: 2);

  BattleState get state => _state;

  /// A game with nobody on the board.
  BattleGame _newGame() => BattleGame(
    rules: _rules,
    // Becomes counter.passDepth when feat/squat_judge merges.
    passDepth: const RepJudgeConfig().bottomDepth,
  );

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
    _roundClockStarted = false;
    _game = _newGame();
    _scoredMyReps = 0;
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

  /// Called on every counter change, up to once a frame. Keeps the opponent
  /// and the watchdog in step with the round clock, scores new reps, then
  /// follows the counter's phase. A KO ends the round last, so this frame's
  /// counts are in the result.
  void _onCounterChanged() {
    if (_roundOver) return;
    final counterState = counter.state;
    _syncOpponent(counterState.phase);
    _armWatchdog(counterState);
    _scoreMyNewReps();
    switch (counterState.phase) {
      case CounterPhase.starting:
        _copyMySide(counterState, BattlePhase.starting);
      case CounterPhase.running:
        _copyMySide(counterState, BattlePhase.playing);
      case CounterPhase.paused:
        _copyMySide(counterState, BattlePhase.paused);
      case CounterPhase.permissionDenied ||
          CounterPhase.cameraError ||
          CounterPhase.detectorError:
        // A failed counter may report zero counts. They are left as they
        // were, since retrying restarts the round anyway.
        _setState(_state.copyWith(phase: BattlePhase.failed));
      case CounterPhase.finished:
        _finishRound(counterState);
    }
    _endRoundOnKo();
  }

  /// Gives the game the reps the counter judged since the last change.
  ///
  /// Read from the counter here, not from its [RepCounterViewModel.reps]
  /// stream: a rep closed on the last frame reaches the stream only after
  /// the round has ended, and it must be in the final score. Each rep's time
  /// is round time, which the judge's own [RepEvent.at] is not.
  void _scoreMyNewReps() {
    if (counter.history.length <= _scoredMyReps) return;
    final records = counter.repRecords;
    for (final record in records.skip(_scoredMyReps)) {
      final score = _game.addMyRep(
        RepEvent(
          index: record.index,
          valid: record.valid,
          at: record.at,
          reason: record.reason,
          maxDepth: record.maxDepth,
        ),
      );
      if (score != null) _state = _state.copyWith(myLastScore: score);
    }
    _scoredMyReps = records.length;
    _state = _withGameStanding(_state);
  }

  /// [state] with the score, the bar, and the danger state from the game.
  BattleState _withGameStanding(BattleState state) => state.copyWith(
    myScore: _game.me.points,
    opponentScore: _game.opponent.points,
    myBarShare: _game.myBarShare,
    danger: _game.inDanger,
  );

  /// Stops the round if the bar reached an end. Ending it this way counts as
  /// time up for the counter, which then follows the normal way to the
  /// result.
  void _endRoundOnKo() {
    if (_game.isKo && !_roundOver) unawaited(counter.finish());
  }

  /// Copies the user's side of the round from the counter: valid and
  /// rejected reps, and the time left.
  void _copyMySide(RepCounterState counterState, BattlePhase phase) {
    _setState(
      _state.copyWith(
        phase: phase,
        myReps: counterState.validReps,
        myInvalidReps: counterState.invalidReps,
        remaining: counterState.remaining,
        fever: _rules.isFever(counter.roundLength - counterState.remaining),
      ),
    );
  }

  /// Keeps the opponent in step with the user's round clock. The counter
  /// starts that clock the first time the camera runs, and from then on
  /// stops it only between [pause] and [resume].
  ///
  /// - starting: before the first run the round has not begun, so the
  ///   opponent waits. After it, the camera is only reopening (after a
  ///   rotation or the background) while the clock runs, so it goes on.
  /// - running: the first run starts the opponent; later ones resume it.
  /// - paused: held, like the clock.
  /// - failed: held. [retry] restarts both sides from zero anyway.
  /// - finished: stopped.
  ///
  /// This runs on every counter change. Resuming a running opponent or
  /// pausing a held one does nothing.
  void _syncOpponent(CounterPhase phase) {
    switch (phase) {
      case CounterPhase.starting:
        if (_roundClockStarted) _opponent.resume();
      case CounterPhase.running:
        if (_roundClockStarted) {
          _opponent.resume();
        } else {
          _roundClockStarted = true;
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

  /// Whether the user's round clock runs in [phase]: it has started, and
  /// the camera is running or only reopening. The same cases in which
  /// [_syncOpponent] keeps the opponent going.
  bool _isRoundClockRunning(CounterPhase phase) =>
      _roundClockStarted &&
      (phase == CounterPhase.running || phase == CounterPhase.starting);

  /// Ends the round in case frames stop coming. The counter checks its
  /// clock only when it processes a frame, so with a stalled camera time
  /// would never run out.
  ///
  /// The timer is set again on every counter change, for the time left plus
  /// [_watchdogGrace]. While frames come, it is replaced before it fires and
  /// the counter ends the round itself. It is off while the clock is held.
  void _armWatchdog(RepCounterState counterState) {
    _watchdog?.cancel();
    if (!_isRoundClockRunning(counterState.phase)) return;
    _watchdog = Timer(
      counterState.remaining + _watchdogGrace,
      () => unawaited(counter.finish()),
    );
  }

  /// Builds the result once time is up or a KO has stopped the counter.
  ///
  /// The counter also finishes when [leave] stops it, but [leave] marks the
  /// battle left first and [_onCounterChanged] then ignores the counter. The
  /// check below is only a guard: a round that ends any other way is left
  /// without a result.
  void _finishRound(RepCounterState counterState) {
    _watchdog?.cancel();
    if (counterState.roundEnd != RoundEnd.timeUp) {
      _setState(_state.copyWith(phase: BattlePhase.left));
      return;
    }
    final endedAt = _now();
    final ko = _game.isKo;
    final played = ko ? _timePlayedToKo(counterState) : counter.roundLength;
    final result = BattleResult(
      matchup: matchup,
      myReps: counterState.validReps,
      myInvalidReps: counterState.invalidReps,
      opponentReps: _state.opponentReps,
      myScore: _game.me.points,
      opponentScore: _game.opponent.points,
      end: ko ? GameEnd.ko : GameEnd.timeUp,
      decidedOutcome: _game.outcome,
      endedAt: endedAt,
      roundLength: played,
      form: FormReport(
        endedAt: endedAt,
        opponentName: matchup.opponent.name,
        roundLength: played,
        reps: counter.repRecords,
        samples: counter.formSamples,
        poses: counter.formPoses,
        leftFlarePose: counter.leftFlarePose,
        rightFlarePose: counter.rightFlarePose,
        handsPose: counter.handsPose,
        headPose: counter.headPose,
      ),
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
    unawaited(_save(result));
  }

  /// How long a round ended by a KO lasted, for the pace in the form report.
  ///
  /// In whole seconds, rounded up past the time played: the KO rep closes at
  /// the very end, and the pace chart only takes reps from before the end.
  Duration _timePlayedToKo(RepCounterState counterState) {
    final played = counter.roundLength - counterState.remaining;
    final roundedUp = Duration(seconds: played.inSeconds + 1);
    return roundedUp < counter.roundLength ? roundedUp : counter.roundLength;
  }

  /// Keeps the battle, with its form report, for the home screen and the
  /// history. A failed upload stays queued in the repository; the result
  /// still shows.
  Future<void> _save(BattleResult result) async {
    try {
      await _repository.saveMatch(result.record, report: result.form);
    } on Exception {
      // The home screen keeps showing the previous record.
    }
    final form = result.form;
    final store = _formReports;
    if (form == null || store == null) return;
    try {
      await store.save(form);
    } on Exception {
      // The feedback still opens from the result screen, just not later.
    }
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
    final score = _game.addOpponentRep(rep);
    _setState(
      _withGameStanding(
        _state.copyWith(
          opponentReps: _state.opponentReps + (rep.valid ? 1 : 0),
          opponentMoves: _state.opponentMoves + 1,
          opponentLastScore: score,
        ),
      ),
    );
    _endRoundOnKo();
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
    unawaited(_myRepSubscription.cancel());
    unawaited(_opponentRepSubscription.cancel());
    _opponent.dispose();
    counter.dispose();
    super.dispose();
  }
}
