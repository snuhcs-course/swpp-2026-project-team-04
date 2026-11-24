import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/character_rig.dart';
import '../models/exercise_type.dart';
import '../models/feedback_goal.dart';
import '../models/form_report.dart';
import '../models/pose_frame.dart';
import '../models/setup_hint_short.dart';
import '../models/setup_silhouette_alignment.dart';
import '../models/setup_squat_silhouette_alignment.dart';
import '../services/device/device_controls.dart';
import '../services/feedback/form_report_store.dart';
import '../services/feedback/goal_progress.dart';
import '../services/feedback/goal_store.dart';
import '../services/game/online_battle_result.dart';
import '../services/online/online_battle_session.dart';
import '../services/pose/setup_checker.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/battle_arena.dart';
import '../widgets/battle_camera_view.dart';
import '../widgets/battle_online_events.dart';
import '../widgets/battle_stage_model.dart';
import '../widgets/character_figure.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/grid_background.dart';
import '../widgets/sound_battle.dart';
import 'battle_screen.dart'
    show BattleScreen, BattleSetupListener, PersonTrackingPauseNotice;

/// An online battle, from the camera preparation to the end: the fighting
/// stage above and the user's camera below (the battle arena), fed by the
/// session. When the server's result is in and its ending has played,
/// 결과 보기 opens the result screen in its place. A battle that ends
/// without a result (cancelled, void, a connection error) says so here.
///
/// Sounds hook in from outside, as on the bot's [BattleScreen], without
/// changing this screen: [onCue] for the stage's moments and [onSetup] for
/// the setup's hints.
class OnlineBattleScreen extends StatefulWidget {
  const OnlineBattleScreen({
    super.key,
    required this.session,
    this.createCounter,
    this.setupConfig = const SetupConfig(),
    this.setupClock,
    this.formReports,
    this.userRepository,
    this.playerName = '나',
    this.onCue,
    this.onSetup,
    this.offerRematch = false,
  });

  /// Whether a battle cancelled before its start (the setup time ran out,
  /// the opponent left) offers 다시 매칭: the screen then closes with
  /// `true`, and whoever opened it searches again (P12).
  final bool offerRematch;
  final OnlineBattleSession session;
  final RepCounterViewModel Function()? createCounter;
  final SetupConfig setupConfig;
  final Clock? setupClock;
  final FormReportStore? formReports;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Receives the battle's form report under the server's result id; the
  /// battle itself is stored by the battle server (P11).
  final UserRepository? userRepository;

  /// The user's nickname, for the stage and the result.
  final String playerName;

  /// Called once for each moment of the stage a sound can follow, as it
  /// shows ([BattleArena.onCue]), as on [BattleScreen.onCue].
  final ValueChanged<BattleStageCue>? onCue;

  /// Called before the round on every change while the pose is checked,
  /// as on [BattleScreen.onSetup]: the setup's latest status, and the time
  /// left before the round starts (the server's start, once both are
  /// ready), null while not counting down. Unlike the bot's, the count
  /// does not stop when the pose is lost: once the server has set the
  /// start, ready cannot be taken back, so the status may say what to fix
  /// while the time counts.
  final BattleSetupListener? onSetup;

  @override
  State<OnlineBattleScreen> createState() => _OnlineBattleScreenState();
}

class _OnlineBattleScreenState extends State<OnlineBattleScreen>
    with WidgetsBindingObserver {
  late final RepCounterViewModel _counter;
  final _sounds = BattleSounds();
  StreamSubscription<dynamic>? _reps;
  late final StreamSubscription<void> _poseFailureSubscription;
  late final SetupChecker _setup;
  late final Clock _setupClock;
  SetupStatus _setupStatus = SetupStatus.initial;
  PoseFrame? _seen;
  FormReport? _formReport;
  bool _reportCreated = false;
  bool _setupReady = false,
      _roundStarted = false,
      _stopping = false,
      _asking = false;

  /// The stage's clock and what plays on it.
  final _stage = BattleStageController();

  /// The user's goal for this exercise and how far this battle has come
  /// on it (A11 spec 5); null without one, and until it has been read.
  GoalTracker? _goal;

  /// Set once the goal has been asked for: it is read once.
  bool _goalAsked = false;

  /// What the stage has seen of the opponent's reps, to tell a new one by.
  late OnlineOpponentSeen _theirs;

  /// Set once the result screen was asked for, so it opens once.
  bool _resultOpened = false;

  Timer? _setupFrameWatchdog;
  Duration? _lastSetupFrameAt;
  Duration? _setupHoldSince;
  Duration? _autoReadyIn;
  SetupCameraCrop? _pushUpGuideCrop;

  /// Most recent ready request awaiting confirmation from the server.
  bool? _readyRequest;
  bool _readyHoldComplete = false;

  OnlineBattleSession get session => widget.session;
  bool get _iAmReady => session.readyPlayers.contains(session.playerId);

  void _syncReady({bool allowReady = false}) {
    if (!session.canReady) {
      _setupHoldSince = null;
      _autoReadyIn = null;
      _readyRequest = null;
      _readyHoldComplete = false;
      return;
    }
    if (_readyRequest == _iAmReady) _readyRequest = null;
    if (allowReady) _readyHoldComplete = true;
    if (!_setupReady || !_readyHoldComplete) {
      if ((_iAmReady || _readyRequest == true) && _readyRequest != false) {
        _readyRequest = false;
        session.ready(false);
      }
      return;
    }
    if (allowReady && !_iAmReady && _readyRequest != true) {
      _autoReadyIn = null;
      _readyRequest = true;
      session.ready(true);
    }
  }

  /// The last seconds of the setup time, which the setup cue counts; the
  /// server cancels the match when they are over (P12).
  static const _setupWarningSeconds = 5;

  /// Seconds of the setup time left, once few enough to warn about.
  int? get _setupWarning {
    final left = session.setupSecondsLeft;
    return left != null && left <= _setupWarningSeconds ? left : null;
  }

  /// Whole seconds left before the local hold ends.
  int? get _autoReadySeconds {
    final left = _autoReadyIn;
    if (left == null || _iAmReady || _readyRequest == true) return null;
    return (left.inMilliseconds / 1000).ceil().clamp(1, 60);
  }

  double get _setupProgress {
    final left = _autoReadyIn;
    if (left == null) return _setupStatus.readyProgress;
    final delay = widget.setupConfig.autoStartDelay.inMicroseconds;
    return delay == 0 ? 1 : 1 - left.inMicroseconds / delay;
  }

  @override
  void initState() {
    super.initState();
    final stopwatch = Stopwatch()..start();
    _setupClock = widget.setupClock ?? (() => stopwatch.elapsed);
    _setup = SetupChecker(
      exercise: session.exercise,
      config: widget.setupConfig,
      clock: _setupClock,
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(keepScreenOn(true));
    // Online timing is owned by the server. The counter's offline round clock
    // must not start/finish a different round during camera preparation.
    _counter =
        widget.createCounter?.call() ??
        RepCounterViewModel(
          roundLength: const Duration(days: 1),
          exercise: session.exercise,
        );
    _counter.addListener(_onCounter);
    _poseFailureSubscription = _counter.poseDetectionFailures.listen((_) {
      if (mounted && !_roundStarted && _lastSetupFrameAt != null) {
        _invalidateSetupPose();
      }
    });
    // Reps the server reported before this screen are not played again.
    _theirs = OnlineStageEvents.opponentSeen(session);
    session.addListener(_onSession);
    _reps = _counter.reps.listen((rep) {
      if (_roundStarted && _counter.history.contains(rep)) {
        // The session takes a rep only while the round runs; the stage
        // plays only what the session took.
        final running = session.roundRunning;
        session.submitRep(rep, passDepth: _counter.passDepth);
        if (running) {
          _stage.rep(
            _withGoal(
              OnlineStageEvents.myRep(
                session,
                rep,
                passDepth: _counter.passDepth,
              ),
            ),
          );
        }
      }
    });
    unawaited(_counter.start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_goalAsked) {
      _goalAsked = true;
      unawaited(_readGoal());
    }
  }

  /// Reads the user's goal for this exercise (A11 spec 5), as the bot
  /// battle does: once, only reading (task.md W11 decision 6). The chip
  /// shows from the countdown on, long after the read.
  Future<void> _readGoal() async {
    final store = Provider.of<GoalStore?>(context, listen: false);
    final account = Provider.of<AuthViewModel?>(
      context,
      listen: false,
    )?.account;
    if (store == null || account == null) return;
    final FeedbackGoal? goal;
    try {
      goal = await store.read(account.id, session.exercise);
    } on Object {
      return;
    }
    if (goal == null || !mounted) return;
    final tracker = GoalTracker(goal)
      ..count(_counter.repRecords, roundLength: _roundLength);
    setState(() => _goal = tracker);
  }

  /// The round's full length, as the server set it.
  Duration get _roundLength => Duration(milliseconds: session.durationMs);

  /// [event], my rep, marked as the one that first reached the goal when
  /// it is. The goal is counted from the counter's records: the same reps,
  /// in round time, that the battle's form report keeps.
  BattleStageEvent _withGoal(BattleStageEvent event) {
    final goal = _goal;
    if (goal == null) return event;
    return goal.count(_counter.repRecords, roundLength: _roundLength)
        ? event.reachingGoal()
        : event;
  }

  void _syncRound() {
    if (session.roundRunning && !_roundStarted) {
      _roundStarted = true;
      _resetSetupPose();
      _counter.reset(restartClock: true);
    }
    if (!_stopping &&
        (session.terminal || (_roundStarted && session.remainingMs == 0))) {
      _stopping = true;
      unawaited(_counter.finish(stoppedByUser: session.terminal));
    }
    final reason = session.result?['reason'];
    if (!_reportCreated &&
        _roundStarted &&
        session.phase == OnlinePhase.finished &&
        (reason == 'time_up' || reason == 'ko')) {
      _reportCreated = true;
      final endedAt =
          (session.result?['ended_at_ms'] as int?) ?? session.serverNow;
      final fullRound = Duration(milliseconds: session.durationMs);
      final report = FormReport(
        endedAt: DateTime.fromMillisecondsSinceEpoch(endedAt),
        opponentName: session.opponent!.name,
        exercise: session.exercise,
        roundLength: reason == 'ko'
            ? BattleRules.koRoundLength(
                Duration(milliseconds: endedAt - session.startAtMs!),
                fullRound,
              )
            : fullRound,
        reps: _counter.repRecords,
        samples: _counter.formSamples,
        poses: _counter.formPoses,
        leftFlarePose: _counter.leftFlarePose,
        rightFlarePose: _counter.rightFlarePose,
        handsPose: _counter.handsPose,
        headPose: _counter.headPose,
        // Mine as sent, so 기록보관소 shows it later.
        characterId: session.character,
      );
      _formReport = report;
      unawaited(_saveReport(report));
    }
  }

  Future<void> _saveReport(FormReport report) async {
    try {
      await (widget.formReports ?? FileFormReportStore()).save(report);
    } on Exception {
      // The report remains available on this result screen if saving fails.
    }
    // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
    final resultId = session.result?['result_id'];
    final repository = widget.userRepository;
    if (resultId is! String || repository == null) return;
    try {
      await repository.saveFeedback(resultId, report);
    } on Exception {
      // Queued in the repository and sent again with the next load.
    }
  }

  void _onSession() {
    _syncRound();
    _syncReady();
    final theirs = OnlineStageEvents.opponentRep(_theirs, session);
    _theirs = OnlineStageEvents.opponentSeen(session);
    if (theirs != null) _stage.rep(theirs);
    _tellSetup();
    if (mounted) setState(() {});
  }

  /// Gives [OnlineBattleScreen.onSetup] the setup's status and the time to
  /// the start while the pose is checked before the round, as the bot
  /// screen does: through the setup and the countdown, not after the start.
  void _tellSetup() {
    final listen = widget.onSetup;
    if (listen == null || _roundStarted || session.terminal) return;
    if (_counter.state.phase != CounterPhase.running) return;
    if (session.phase != OnlinePhase.preparing &&
        session.phase != OnlinePhase.scheduled) {
      return;
    }
    listen(_setupStatus, _startIn);
  }

  /// The time left before the round starts, once both are ready and the
  /// server has set the start; null before that.
  Duration? get _startIn {
    final at = session.startAtMs;
    if (session.phase != OnlinePhase.scheduled || at == null) return null;
    final left = at - session.serverNow;
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  void _setPushUpGuideCrop(SetupCameraCrop crop) {
    if (_roundStarted || session.terminal || _pushUpGuideCrop == crop) return;
    _pushUpGuideCrop = crop;
    _invalidateSetupPose();
  }

  void _resetSetupPose() {
    _setup.reset();
    _setupFrameWatchdog?.cancel();
    _setupFrameWatchdog = null;
    _lastSetupFrameAt = null;
    _setupHoldSince = null;
    _autoReadyIn = null;
    _setupStatus = SetupStatus.initial;
    _setupReady = false;
    _readyHoldComplete = false;
  }

  void _invalidateSetupPose() {
    _resetSetupPose();
    _syncReady();
    _tellSetup();
    if (mounted) setState(() {});
  }

  void _checkSetupPose(PoseFrame frame) {
    final now = _setupClock();
    final last = _lastSetupFrameAt;
    if (last != null &&
        (now < last || now - last > SetupConfig.maxPoseFrameGap)) {
      _resetSetupPose();
      _syncReady();
    }
    _seen = frame;
    _lastSetupFrameAt = now;
    _setupFrameWatchdog?.cancel();
    _setupFrameWatchdog = Timer(SetupConfig.maxPoseFrameGap, () {
      if (mounted && !_roundStarted && !session.terminal) {
        _invalidateSetupPose();
      }
    });

    final status = _setup.update(
      frame,
      phonePropped: _counter.isPhonePropped,
      phoneStill: _counter.isPhoneStill,
    );
    final crop = _pushUpGuideCrop;
    final aligned = switch (session.exercise) {
      ExerciseType.pushUp =>
        crop != null &&
            SetupSilhouetteAlignment(
              minLikelihood: widget.setupConfig.minLikelihood,
            ).matchesImageCrop(frame, crop, mirror: _counter.isFrontCamera),
      ExerciseType.squat =>
        StandingSilhouetteAlignment(
          minLikelihood: widget.setupConfig.minLikelihood,
        ).matches(
          frame,
          Size(frame.imageWidth, frame.imageHeight),
          mirror: _counter.isFrontCamera,
        ),
    };
    _setupReady = status.reason == SetupReason.ready && aligned;
    _setupStatus = _setupReady
        ? status
        : SetupStatus(
            reason: status.reason,
            isReady: false,
            readyProgress: 0,
            missingParts: status.missingParts,
          );
    if (!_setupReady || !session.canReady) {
      _readyHoldComplete = false;
      _setupHoldSince = null;
      _autoReadyIn = null;
      _syncReady();
      return;
    }
    if (status.isReady) {
      _counter.lockTrackedPerson();
      if (_counter.state.trackingPaused) return;
    }
    final left =
        widget.setupConfig.autoStartDelay - (now - (_setupHoldSince ??= now));
    _autoReadyIn = left.isNegative ? Duration.zero : left;
    _syncReady(allowReady: left <= Duration.zero && status.isReady);
  }

  void _onCounter() {
    _syncRound();
    final state = _counter.state;
    final frame = state.lastFrame;
    final usable = state.phase == CounterPhase.running && !state.trackingPaused;
    session.publishPose(
      usable && frame != null && frame.hasPerson ? frame : null,
    );
    if (!_roundStarted &&
        !session.terminal &&
        state.phase == CounterPhase.running) {
      // The setup camera is on: the setup time may count (P12).
      session.setupOpened();
    }
    if (!_roundStarted && !session.terminal) {
      if (!usable || frame == null) {
        _invalidateSetupPose();
        return;
      }
      if (!identical(frame, _seen)) {
        _checkSetupPose(frame);
      }
    }
    _tellSetup();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_counter.pause());
    }
    if (state == AppLifecycleState.resumed && !session.terminal) {
      unawaited(_counter.resume());
    }
  }

  /// Whether the battle ended without a result to show: cancelled, void, a
  /// connection error, or a battle the server no longer knows.
  bool get _endedWithoutResult =>
      session.terminal &&
      (session.phase != OnlinePhase.finished || session.matchUnconfirmed);

  /// The setup's short cue before the start (A9): that the connection is
  /// being checked, that the user waits for the opponent, a pose that is
  /// not in the silhouette yet, the count to the auto ready, or what the
  /// setup wants.
  SetupHintShort get _setupCue {
    if (!session.connected) return const SetupHintShort.reconnecting();
    final warning = _setupWarning;
    if (_iAmReady && _setupReady && _readyHoldComplete) {
      const waiting = SetupHintShort.waitingForOpponent();
      if (warning == null) return waiting;
      return SetupHintShort(
        first: waiting.first,
        second: waiting.second,
        icon: waiting.icon,
        state: waiting.state,
        message: '${waiting.message} $warning초 안에 상대가 준비하지 않으면 경기가 취소돼요.',
      );
    }
    final outside = _setupStatus.reason == SetupReason.ready && !_setupReady;
    final seconds = _autoReadySeconds;
    // The auto ready, unless the setup time ends before it would.
    if (!outside && seconds != null && (warning == null || warning > seconds)) {
      return SetupHintShort.autoReady(seconds);
    }
    final cue = SetupHintShort.of(_setupStatus, outsideSilhouette: outside);
    if (warning == null) return cue;
    return SetupHintShort(
      first: '$warning초 후',
      second: '취소돼요',
      icon: cue.icon,
      state: SetupCueState.notice,
      message: '$warning초 안에 준비하지 않으면 경기가 취소돼요. ${cue.message}',
    );
  }

  /// The camera area's one line once the setup is over.
  String? get _roundHint {
    if (session.phase == OnlinePhase.scheduled) {
      // The reconnect band is the round's; before it, the hint says so.
      if (!session.connected) return '재연결 중 · 준비 상태 확인 중…';
      // Until the stage counts 3, 2, 1 itself.
      final seconds = session.countdownSeconds;
      return seconds > 3 ? '$seconds초 후 함께 시작' : null;
    }
    if (session.terminal) return null;
    if (session.phase == OnlinePhase.awaitingResult) {
      return '서버의 최종 결과를 기다리는 중…';
    }
    return session.error;
  }

  /// Set once the ended screen was closed: a second tap during the pop
  /// would otherwise close the screen under it too.
  bool _closed = false;

  /// Closes the ended screen once; with [rematch], asks for a new search.
  void _close({bool rematch = false}) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.pop(context, rematch ? true : null);
  }

  /// Opens the result in this screen's place, once the server's result is
  /// in. The lobby under this screen closes itself under the result.
  void _showResult() {
    if (_resultOpened || !mounted) return;
    final result = onlineBattleResult(
      session,
      playerName: widget.playerName,
      report: _formReport,
    );
    if (result == null) return;
    _resultOpened = true;
    unawaited(
      Navigator.pushReplacementNamed(
        context,
        GymRatsApp.resultRoute,
        arguments: result,
      ),
    );
  }

  /// The system's back gesture: asks to leave while the battle is on;
  /// once a result is in it opens the result after its ending has played,
  /// as 결과 보기 does, and does nothing before.
  void _back() {
    if (session.phase == OnlinePhase.finished && !session.matchUnconfirmed) {
      if (_stage.resultReady) _showResult();
      return;
    }
    unawaited(_exit());
  }

  Future<void> _exit() async {
    if (_asking) return;
    if (session.terminal) {
      if (mounted) Navigator.pop(context);
      return;
    }
    _asking = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => ExitDialog(
        title: '게임에서 나갈까요?',
        message: session.startAtMs == null
            ? ExitDialog.gameMessage(session.opponent!.name)
            : '시작 후 나가면 서버 규칙에 따라\n기권 처리됩니다.',
        leaveLabel: '게임 나가기',
      ),
    );
    _asking = false;
    if (leave != true || !mounted) return;
    await session.leave();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _setupFrameWatchdog?.cancel();
    unawaited(keepScreenOn(false));
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(_onSession);
    _counter.removeListener(_onCounter);
    unawaited(_reps?.cancel());
    unawaited(_poseFailureSubscription.cancel());
    _counter.dispose();
    _sounds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_endedWithoutResult) {
      _sounds.ended();
      return _Ended(
        session: session,
        onHome: _close,
        onRematch: widget.offerRematch && session.phase == OnlinePhase.cancelled
            ? () => _close(rematch: true)
            : null,
      );
    }
    final counter = _counter.state;
    final running = counter.phase == CounterPhase.running;
    final cameraFailed = {
      CounterPhase.permissionDenied,
      CounterPhase.cameraError,
      CounterPhase.detectorError,
    }.contains(counter.phase);
    final standing = OnlineStageEvents.stateOf(
      session,
      myName: widget.playerName,
      cameraFailed: cameraFailed,
    );
    final goal = _goal?.progress;
    final stage = standing.withGoal(
      standing.phase == BattleStagePhase.ended ? goal?.atEnd() : goal,
    );
    _sounds.show(stage);
    final setup = stage.phase == BattleStagePhase.setup;
    // The setup's guide stays up to the start, as in the bot battle, and
    // the round's height lines come with the round.
    final settingUp = setup || stage.phase == BattleStagePhase.countdown;
    final pushUp = session.exercise == ExerciseType.pushUp;
    final guide = settingUp && running
        ? BattleCameraView.setupGuide(
            session.exercise,
            ready: _setupReady && _setupStatus.isReady,
          )
        : null;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BattleArena(
          controller: _stage,
          state: stage,
          // Mine as sent; theirs as the server passed it on (the mouse
          // when it is missing or not one a person may pick).
          characters: BattleCharacters(
            me: session.character,
            opponent: session.opponent?.character ?? CharacterRig.defaultId,
          ),
          onCue: widget.onCue ?? _sounds.cue,
          camera: cameraFailed
              ? _CameraTrouble(
                  onRetry: counter.phase == CounterPhase.permissionDenied
                      ? _counter.openSettings
                      : _counter.retry,
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    BattleCameraView(
                      controller: _counter.cameraController,
                      frame: running ? counter.lastFrame : null,
                      mirror: _counter.isFrontCamera,
                      chestSnapshot: pushUp && !settingUp
                          ? counter.snapshot
                          : null,
                      squatSnapshot: !pushUp && !settingUp
                          ? counter.snapshot
                          : null,
                      guide: guide?.widget,
                      guideFit: guide?.fit ?? BoxFit.cover,
                      onGuideCrop: pushUp && guide != null
                          ? _setPushUpGuideCrop
                          : null,
                    ),
                    if (counter.trackingPaused && !session.terminal)
                      PersonTrackingPauseNotice(
                        onConfirm: _counter.confirmTrackedPerson,
                        roundStarted: _roundStarted,
                      ),
                    if (setup && !session.terminal)
                      if (session.setupSecondsLeft case final left?)
                        Positioned(
                          top: AppSpacing.s12,
                          child: _SetupTimeLeft(
                            seconds: left,
                            urgent: left <= _setupWarningSeconds,
                          ),
                        ),
                  ],
                ),
          onLeave: () => unawaited(_exit()),
          hint: setup ? null : _roundHint,
          // Not while the person check asks for a tap (as in the AI battle).
          setupCue: setup && !counter.trackingPaused ? _setupCue : null,
          // No ready button (team decision 2026-11-15): ready is sent by
          // itself once the pose holds, and taken back when it is lost.
          onSwitchCamera: setup && running && _counter.canSwitchCamera
              ? () => unawaited(_counter.switchCamera())
              : null,
          setupProgress: setup ? _setupProgress : null,
          onShowResult: _showResult,
        ),
      ),
    );
  }
}

/// The setup time left, on top of the camera once both setups are open
/// (P12): "남은 시간: 8초", the number large, on white, on the warning
/// color in the last seconds before the server cancels the match.
class _SetupTimeLeft extends StatelessWidget {
  const _SetupTimeLeft({required this.seconds, required this.urgent});

  final int seconds;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      label: '자세 세팅 남은 시간 $seconds초',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: urgent ? AppColors.warning : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: AppColors.ink),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s4,
            ),
            child: Text.rich(
              TextSpan(
                text: '남은 시간: ',
                style: text.stageName,
                children: [
                  TextSpan(
                    text: '$seconds',
                    style: text.stageClock.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const TextSpan(text: '초'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The camera could not start, or the pose could not be read: says so where
/// the camera would be, with a way to try again.
class _CameraTrouble extends StatelessWidget {
  const _CameraTrouble({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '카메라 권한 또는 자세 인식을 확인해주세요.',
            textAlign: TextAlign.center,
            style: text.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.s8),
          TextButton(onPressed: onRetry, child: const Text('카메라 다시 준비')),
        ],
      ),
    );
  }
}

/// A battle that ended without a result: cancelled, void, or lost to a
/// connection error. Nothing was recorded; the user goes home, or, after a
/// cancel, searches again when [onRematch] is given.
class _Ended extends StatelessWidget {
  const _Ended({required this.session, required this.onHome, this.onRematch});

  final OnlineBattleSession session;
  final VoidCallback onHome;
  final VoidCallback? onRematch;

  /// Why [session] ended, in the user's words, never the server's code: who
  /// was not ready in time, that the opponent left, or that a connection
  /// dropped. A reason this version does not know still reads as a sentence.
  static String messageFor(OnlineBattleSession session) {
    if (session.serverRestarted) {
      return '서버가 다시 시작되어 이 경기는 기록되지 않았어요.';
    }
    if (session.matchNotFound) return '서버에서 이 경기를 찾을 수 없어요.';
    final reason = session.result?['reason'];
    if (session.setupTimedOut || reason == 'ready_timeout') {
      final me = session.readyPlayers.contains(session.playerId);
      final them = session.readyPlayers.any((id) => id != session.playerId);
      return switch ((me, them)) {
        (false, true) => '내가 제한 시간 안에 준비하지 못해 경기가 취소됐어요.',
        (true, false) => '상대가 제한 시간 안에 준비하지 못해 경기가 취소됐어요.',
        (false, false) => '두 사람 모두 제한 시간 안에 준비하지 못해 경기가 취소됐어요.',
        (true, true) => '준비 시간이 지나 경기가 취소됐어요.',
      };
    }
    return switch (reason) {
      'user_exit' || 'player_left_before_start' => '상대가 경기에서 나가 취소됐어요.',
      'disconnected_before_start' => '시작 전에 연결이 끊겨 경기가 취소됐어요.',
      'both_disconnected' => '두 사람의 연결이 모두 끊겨 이 경기는 무효가 됐어요.',
      // An error shown during the match may be stale or carry a code, so
      // only a battle that ended by the error itself says it.
      _ => switch (session.phase) {
        OnlinePhase.voided => '이 경기는 무효가 됐어요.',
        OnlinePhase.cancelled => '경기가 시작되기 전에 취소됐어요.',
        _ => session.error ?? '연결에 문제가 생겨 경기를 이어갈 수 없어요.',
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = session.matchUnconfirmed
        ? '경기를 확인할 수 없어요'
        : switch (session.phase) {
            OnlinePhase.voided => '경기 무효',
            OnlinePhase.cancelled => '경기 취소',
            _ => '연결 오류',
          };
    final message = messageFor(session);
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  if (onRematch case final rematch?) ...[
                    AccentButton(title: '다시 매칭', onPressed: rematch),
                    const SizedBox(height: AppSpacing.s8),
                    TextButton(
                      onPressed: onHome,
                      child: const Text('홈으로 돌아가기'),
                    ),
                  ] else
                    AccentButton(title: '홈으로 돌아가기', onPressed: onHome),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
