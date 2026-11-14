import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/battle_result.dart';
import '../models/battle_rules.dart';
import '../models/form_report.dart';
import '../models/exercise_type.dart';
import '../models/game_score.dart';
import '../models/matchup.dart';
import '../models/pose_frame.dart';
import '../models/rep_event.dart';
import '../services/device/device_controls.dart';
import '../services/feedback/form_report_store.dart';
import '../services/game/battle_game.dart';
import '../services/device/phone_tilt.dart';
import '../services/opponent/opponent_source.dart';
import '../services/pose/camera_service.dart';
import '../services/pose/pose_estimator.dart';
import '../services/pose/setup_checker.dart';
import '../services/pose/squat_demo_judge.dart';
import '../services/user/user_repository.dart';
import 'rep_counter_viewmodel.dart';

/// Where the battle is.
enum BattlePhase {
  /// The camera is opening, before the round or after a pause.
  starting,

  /// Before the round, with the camera running: the user's pose is checked,
  /// and while it stays ready [BattleState.startIn] counts down to the start.
  setup,

  /// The round is on.
  playing,

  /// The app is in the background; the round, or the setup, is held.
  paused,

  /// The camera or pose detection failed. Retrying sets up again and
  /// restarts the round from zero.
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
    this.started = false,
    this.setup = SetupStatus.initial,
    this.startIn,
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

  /// How many reps the opponent made, valid or not. The opponent on the
  /// stage swings once for each.
  final int opponentMoves;

  /// Set once time is up.
  final BattleResult? result;

  /// Whether the round has begun: the countdown has ended. Before it the
  /// screen shows the setup, and the round's clock waits.
  final bool started;

  /// The latest check of the user's pose, before the round.
  final SetupStatus setup;

  /// Before the round, while the pose stays ready: the time left before the
  /// round starts by itself. Null while not counting down.
  final Duration? startIn;

  /// Whether the setup's 시작 button may begin the round now: before it,
  /// with the camera running and the pose ready.
  bool get canStart => !started && phase == BattlePhase.setup && setup.isReady;

  /// Whole seconds left, rounded up: the full round at the start, 0 at the end.
  int get secondsLeft =>
      (remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil();

  /// The user's lead in points; negative while behind.
  int get lead => myScore - opponentScore;

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
    bool? started,
    SetupStatus? setup,
    Duration? startIn,
    bool clearStartIn = false,
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
    started: started ?? this.started,
    setup: setup ?? this.setup,
    startIn: clearStartIn ? null : startIn ?? this.startIn,
  );
}

/// Runs one battle: the setup before it, the user's reps and round clock
/// from [counter], the opponent's reps from an [OpponentSource], and the end
/// of the round.
///
/// Before the round a [SetupChecker] checks the user's pose on the camera's
/// frames. Once it is ready and stays so for the setup's auto start delay,
/// the round begins (the setup's 시작 button begins it at once): the
/// counter's reps and clock start from zero, and the opponent starts.
/// Without a setup check the round begins as soon as the camera runs.
///
/// The opponent plays only while the round's clock runs. It goes on while
/// the camera reopens, and is held while the app is in the background or the
/// camera has failed.
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
    this.rules = battleRules,
    this.roundLength = battleDuration,
    this._setup,
    Clock? clock,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _clock = clock ?? _stopwatchClock() {
    assert(
      counter.roundLength >= roundLength,
      "The counter's round must last at least as long as the battle's.",
    );
    assert(
      _setup == null || counter.roundLength > roundLength,
      "With a setup the counter's round must outlast the battle's: its "
      'clock runs through the setup too.',
    );
    _game = _newGame();
    _state = BattleState(remaining: roundLength);
    counter.addListener(_onCounterChanged);
    _myRepSubscription = counter.reps.listen(_onMyRep);
    _opponentRepSubscription = _opponent.reps.listen(_onOpponentRep);
  }

  /// A battle against the bot as the app plays it: [counter] from
  /// [botCounter], the bot as [opponent], and the pose setup of [matchup]'s
  /// exercise before the round, which ends [battleDuration] after it began.
  ///
  /// The clock stands in for the phone's own in tests.
  factory BattleViewModel.bot({
    required Matchup matchup,
    required RepCounterViewModel counter,
    required OpponentSource opponent,
    required UserRepository repository,
    required RepSound sound,
    FormReportStore? formReports,
    Clock? clock,
  }) => BattleViewModel(
    matchup: matchup,
    counter: counter,
    opponent: opponent,
    repository: repository,
    sound: sound,
    formReports: formReports,
    setup: SetupChecker(exercise: matchup.exercise, clock: clock),
    clock: clock,
  );

  /// The user's camera and judge for a bot battle of [exercise] (the squat
  /// judge for squats), for [BattleViewModel.bot]. Its own round lasts
  /// [counterRound], as its clock runs through the setup too.
  ///
  /// The camera, the pose estimator, the phone's tilt and the clock stand in
  /// for the phone's own in tests.
  static RepCounterViewModel botCounter(
    ExerciseType exercise, {
    CameraService? camera,
    PoseEstimator? estimator,
    PhoneTiltMonitor? phoneTilt,
    Clock? clock,
  }) => RepCounterViewModel(
    camera: camera,
    estimator: estimator,
    phoneTilt: phoneTilt,
    clock: clock,
    roundLength: counterRound,
    exercise: exercise,
    exerciseJudge: exercise == ExerciseType.squat
        ? SquatDemoJudge(clock: clock)
        : null,
  );

  /// How long the counter's own round lasts in [botCounter]: far beyond any
  /// setup and round, as online.
  static const counterRound = Duration(days: 1);

  final Matchup matchup;

  /// The user's camera, reps, and round clock. The screen shows its preview
  /// and landmarks directly.
  ///
  /// With a setup check its own round must be far longer than [roundLength]
  /// (a day, as online): its clock also runs while the user sets up, and
  /// this view model ends the round itself once [roundLength] has passed.
  final RepCounterViewModel counter;

  final OpponentSource _opponent;
  final UserRepository _repository;
  final RepSound _sound;
  final FormReportStore? _formReports;

  /// The numbers of this battle's game, also for what the screen says.
  final BattleRules rules;

  /// How long the round lasts once it has begun.
  final Duration roundLength;

  /// Checks the user's pose before the round; null begins the round as soon
  /// as the camera runs.
  final SetupChecker? _setup;

  /// Times the countdown to the start.
  final Clock _clock;

  final DateTime Function() _now;
  late final StreamSubscription<RepEvent> _myRepSubscription;
  late final StreamSubscription<RepEvent> _opponentRepSubscription;

  late BattleState _state;
  late BattleGame _game;

  /// How many of the user's judged reps the game has seen.
  int _scoredMyReps = 0;

  /// Whether the round has begun since [start] or [retry]; see
  /// [BattleState.started]. The opponent starts at the same moment.
  bool _begun = false;

  /// The frame the setup checked last, so that each is checked once.
  PoseFrame? _checked;

  /// When the pose became ready, for the countdown to the start.
  Duration? _readySince;

  /// The counter's time left as the setup last saw it, until the counter
  /// works out its time again after the round began: restarting its clock
  /// does not update the time it shows.
  Duration? _setupRemaining;

  bool _disposed = false;

  /// Ends the round if frames stop coming; see [_armWatchdog].
  Timer? _watchdog;

  /// How long past the end of the round the watchdog waits for the counter
  /// to end it by itself.
  static const _watchdogGrace = Duration(seconds: 2);

  BattleState get state => _state;

  static Clock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  /// A game with nobody on the board.
  BattleGame _newGame() =>
      BattleGame(rules: rules, passDepth: counter.passDepth);

  bool get _roundOver =>
      _state.phase == BattlePhase.timeUp || _state.phase == BattlePhase.left;

  /// Opens the camera; the setup, then the round, begin when it runs.
  Future<void> start() => counter.start();

  /// Begins the round now, as the setup's 시작 button does; only while
  /// [BattleState.canStart].
  void startNow() {
    if (_state.canStart) _beginRound();
  }

  /// App moved to the background: the camera and the round are held.
  Future<void> pause() => counter.pause();

  /// App came back: the camera reopens and the round goes on.
  Future<void> resume() => counter.resume();

  /// Reopens the camera for the new screen orientation, keeping the score.
  Future<void> onScreenRotated() => counter.onScreenRotated();

  /// After a camera failure: sets up again, then plays the round from zero
  /// on both sides.
  Future<void> retry() async {
    if (_state.phase != BattlePhase.failed) return;
    _opponent.stop();
    _begun = false;
    _setupRemaining = null;
    _game = _newGame();
    _scoredMyReps = 0;
    _resetSetup();
    _setState(BattleState(remaining: roundLength));
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

  /// Called on every counter change, up to once a frame. Before the round it
  /// runs the setup. In the round it keeps the opponent and the watchdog in
  /// step with the round clock, scores new reps, then follows the counter's
  /// phase. A KO or the time running out ends the round last, so this
  /// frame's counts are in the result.
  void _onCounterChanged() {
    if (_roundOver) return;
    if (!_begun) {
      _setUp(counter.state);
      if (!_begun) return;
    }
    // Read again: beginning the round may have reset the counter.
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
    _endRoundOnTime(counterState);
  }

  /// Before the round: follows the camera, checks the pose on each new
  /// frame, and counts down while it stays ready. Opening, pausing or losing
  /// the camera starts the setup over.
  void _setUp(RepCounterState counterState) {
    switch (counterState.phase) {
      case CounterPhase.starting:
        _holdSetup(BattlePhase.starting);
      case CounterPhase.paused:
        _holdSetup(BattlePhase.paused);
      case CounterPhase.permissionDenied ||
          CounterPhase.cameraError ||
          CounterPhase.detectorError:
        _holdSetup(BattlePhase.failed);
      case CounterPhase.finished:
        // Only [leave] stops the camera before the round, and it has marked
        // the battle left already.
        break;
      case CounterPhase.running:
        _checkPose(counterState);
    }
  }

  void _holdSetup(BattlePhase phase) {
    _resetSetup();
    _setState(
      _state.copyWith(
        phase: phase,
        setup: SetupStatus.initial,
        clearStartIn: true,
      ),
    );
  }

  void _resetSetup() {
    _setup?.reset();
    _checked = null;
    _readySince = null;
  }

  /// Checks the latest frame's pose and counts down to the start while it
  /// stays ready, as the setup screen's auto start did; losing the pose
  /// stops the count. The round begins when the count ends.
  void _checkPose(RepCounterState counterState) {
    final setup = _setup;
    if (setup == null) {
      _beginRound();
      return;
    }
    var status = _state.setup;
    final frame = counterState.lastFrame;
    if (frame != null && !identical(frame, _checked)) {
      _checked = frame;
      status = setup.update(
        frame,
        phonePropped: counter.isPhonePropped,
        phoneStill: counter.isPhoneStill,
      );
    }
    if (!status.isReady) {
      _readySince = null;
      _setState(
        _state.copyWith(
          phase: BattlePhase.setup,
          setup: status,
          clearStartIn: true,
        ),
      );
      return;
    }
    final now = _clock();
    final left = setup.config.autoStartDelay - (now - (_readySince ??= now));
    if (left <= Duration.zero) {
      _beginRound();
      return;
    }
    _setState(
      _state.copyWith(phase: BattlePhase.setup, setup: status, startIn: left),
    );
  }

  /// Begins the round: from zero on both sides, with the opponent and the
  /// round's clock from this moment.
  void _beginRound() {
    _begun = true;
    _resetSetup();
    _game = _newGame();
    _scoredMyReps = 0;
    _opponent.start();
    _setState(
      _state.copyWith(
        phase: BattlePhase.playing,
        started: true,
        remaining: roundLength,
        clearStartIn: true,
      ),
    );
    // The reps and the time of the setup are not the round's. The counter's
    // change this makes comes back to [_onCounterChanged], in the round now.
    if (_setup != null) {
      _setupRemaining = counter.state.remaining;
      counter.reset(restartClock: true);
    }
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
          minElbowAngle: record.minElbowAngle,
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

  /// Stops the round once [roundLength] has passed. With a setup check the
  /// counter's own round is longer, so it would not stop by itself.
  void _endRoundOnTime(RepCounterState counterState) {
    if (!_roundOver &&
        counterState.phase == CounterPhase.running &&
        _remainingOf(counterState) == Duration.zero) {
      unawaited(counter.finish());
    }
  }

  /// Time left in the round by the counter's clock, which started over when
  /// the round began. Until the counter next works out its time (on the
  /// next frame, pause, reopening or end) it still shows the setup's: the
  /// round has only just begun then, so all of it is left.
  Duration _remainingOf(RepCounterState counterState) {
    final setupRemaining = _setupRemaining;
    if (setupRemaining != null) {
      if (counterState.remaining == setupRemaining) return roundLength;
      _setupRemaining = null;
    }
    final elapsed = counter.roundLength - counterState.remaining;
    final left = roundLength - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Copies the user's side of the round from the counter: valid and
  /// rejected reps, and the time left.
  void _copyMySide(RepCounterState counterState, BattlePhase phase) {
    final remaining = _remainingOf(counterState);
    _setState(
      _state.copyWith(
        phase: phase,
        myReps: counterState.validReps,
        myInvalidReps: counterState.invalidReps,
        remaining: remaining,
        fever: rules.isFever(roundLength - remaining),
      ),
    );
  }

  /// Keeps the opponent in step with the round's clock, in the round. The
  /// round's beginning starts the opponent; from then on the clock stops
  /// only between [pause] and [resume].
  ///
  /// - starting: the camera is only reopening (after a rotation or the
  ///   background) while the clock runs, so it goes on.
  /// - running: goes on.
  /// - paused: held, like the clock.
  /// - failed: held. [retry] restarts both sides from zero anyway.
  /// - finished: stopped.
  ///
  /// This runs on every counter change in the round. Resuming a running
  /// opponent or pausing a held one does nothing.
  void _syncOpponent(CounterPhase phase) {
    switch (phase) {
      case CounterPhase.starting || CounterPhase.running:
        _opponent.resume();
      case CounterPhase.paused ||
          CounterPhase.permissionDenied ||
          CounterPhase.cameraError ||
          CounterPhase.detectorError:
        _opponent.pause();
      case CounterPhase.finished:
        _opponent.stop();
    }
  }

  /// Whether the round's clock runs in [phase]: the round has begun, and the
  /// camera is running or only reopening. The same cases in which
  /// [_syncOpponent] keeps the opponent going.
  bool _isRoundClockRunning(CounterPhase phase) =>
      _begun &&
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
      _remainingOf(counterState) + _watchdogGrace,
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
    final remaining = _remainingOf(counterState);
    final played = ko
        ? BattleRules.koRoundLength(roundLength - remaining, roundLength)
        : roundLength;
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
        exercise: matchup.exercise,
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
        remaining: remaining,
        result: result,
      ),
    );
    unawaited(_save(result));
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
  /// A rep of the setup is not the round's: the counter forgot it when the
  /// round began, though its stream may still bring it.
  void _onMyRep(RepEvent rep) {
    if (_state.phase == BattlePhase.left) return;
    if (!_begun || !counter.history.contains(rep)) return;
    if (rep.valid) _sound.playRepCounted();
    _setState(
      _state.copyWith(feedback: rep, feedbackCount: _state.feedbackCount + 1),
    );
  }

  void _onOpponentRep(RepEvent rep) {
    if (_roundOver || !_begun) return;
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
