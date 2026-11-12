import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/form_report.dart';
import '../models/pose_frame.dart';
import '../services/device/device_controls.dart';
import '../services/feedback/form_report_store.dart';
import '../services/game/online_battle_result.dart';
import '../services/online/online_battle_session.dart';
import '../services/pose/setup_checker.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/battle_arena.dart';
import '../widgets/battle_camera_view.dart';
import '../widgets/battle_online_events.dart';
import '../widgets/battle_stage_model.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/grid_background.dart';

/// An online battle, from the camera preparation to the end: the fighting
/// stage above and the user's camera below (the battle arena), fed by the
/// session. When the server's result is in and its ending has played,
/// 결과 보기 opens the result screen in its place. A battle that ends
/// without a result (cancelled, void, a connection error) says so here.
class OnlineBattleScreen extends StatefulWidget {
  const OnlineBattleScreen({
    super.key,
    required this.session,
    this.createCounter,
    this.setupConfig = const SetupConfig(),
    this.formReports,
    this.userRepository,
    this.playerName = '나',
  });
  final OnlineBattleSession session;
  final RepCounterViewModel Function()? createCounter;
  final SetupConfig setupConfig;
  final FormReportStore? formReports;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Receives the battle's form report under the server's result id; the
  /// battle itself is stored by the battle server (P11).
  final UserRepository? userRepository;

  /// The user's nickname, for the stage and the result.
  final String playerName;
  @override
  State<OnlineBattleScreen> createState() => _OnlineBattleScreenState();
}

class _OnlineBattleScreenState extends State<OnlineBattleScreen>
    with WidgetsBindingObserver {
  late final RepCounterViewModel _counter;
  StreamSubscription<dynamic>? _reps;
  late final SetupChecker _setup;
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

  /// What the stage has seen of the opponent's reps, to tell a new one by.
  late OnlineOpponentSeen _theirs;

  /// Set once the result screen was asked for, so it opens once.
  bool _resultOpened = false;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Sends ready by itself once the pose has stayed ready for
  /// [SetupConfig.autoStartDelay], like the bot setup's auto start. Losing
  /// the pose before then cancels it; the next ready pose starts it again.
  Timer? _autoReady;
  DateTime? _autoReadyAt;

  /// The user cancelled ready: no auto ready until the pose is lost and
  /// found again, or they press 준비.
  bool _autoReadyPaused = false;

  /// Ready was sent and the server has not confirmed it yet, so it is not
  /// sent again while the confirmation is on its way.
  bool _readySent = false;

  OnlineBattleSession get session => widget.session;
  bool get _iAmReady => session.readyPlayers.contains(session.playerId);

  void _syncAutoReady() {
    if (!_setupReady) _autoReadyPaused = false;
    if (_iAmReady || !_setupReady || !session.canReady) _readySent = false;
    final waiting =
        session.canReady &&
        _setupReady &&
        !_iAmReady &&
        !_autoReadyPaused &&
        !_readySent;
    if (!waiting) {
      _cancelAutoReady();
      return;
    }
    if (_autoReady != null) return;
    final delay = widget.setupConfig.autoStartDelay;
    _autoReadyAt = DateTime.now().add(delay);
    _autoReady = Timer(delay, () {
      _autoReady = null;
      _autoReadyAt = null;
      if (mounted && session.canReady && _setupReady && !_iAmReady) {
        _readySent = true;
        session.ready(true);
      }
    });
  }

  void _cancelAutoReady() {
    _autoReady?.cancel();
    _autoReady = null;
    _autoReadyAt = null;
  }

  /// 준비 or 준비 취소. Cancelling pauses the auto ready.
  void _toggleReady() {
    final cancelling = _iAmReady;
    _autoReadyPaused = cancelling;
    _readySent = !cancelling;
    _cancelAutoReady();
    session.ready(!cancelling);
  }

  /// Whole seconds left before the auto ready; null when not counting.
  int? get _autoReadySeconds {
    final at = _autoReadyAt;
    if (at == null) return null;
    final left = at.difference(DateTime.now()).inMilliseconds;
    return (left / 1000).ceil().clamp(1, 60);
  }

  /// The setup bar: holding the pose, then the auto ready countdown.
  double get _setupProgress {
    final at = _autoReadyAt;
    if (at == null) return _setupStatus.readyProgress;
    final delay = widget.setupConfig.autoStartDelay.inMicroseconds;
    final left = at.difference(DateTime.now()).inMicroseconds;
    return delay == 0 ? 1 : 1 - left / delay;
  }

  @override
  void initState() {
    super.initState();
    _setup = SetupChecker(
      exercise: session.exercise,
      config: widget.setupConfig,
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
    // Reps the server reported before this screen are not played again.
    _theirs = OnlineStageEvents.opponentSeen(session);
    session.addListener(_onSession);
    _reps = _counter.reps.listen((rep) {
      if (_roundStarted && _counter.history.contains(rep)) {
        // The session takes a rep only while the round runs; the stage
        // plays only what the session took.
        final running = session.roundRunning;
        if (rep.valid) const DeviceRepSound().playRepCounted();
        session.submitRep(rep, passDepth: _counter.passDepth);
        if (running) {
          _stage.rep(
            OnlineStageEvents.myRep(
              session,
              rep,
              passDepth: _counter.passDepth,
            ),
          );
        }
      }
    });
    unawaited(_counter.start());
  }

  void _syncRound() {
    if (session.roundRunning && !_roundStarted) {
      _roundStarted = true;
      _counter.reset(restartClock: true);
    }
    if (!_stopping &&
        (session.terminal || (_roundStarted && session.remainingMs == 0))) {
      _stopping = true;
      unawaited(_counter.finish(stoppedByUser: session.terminal));
    }
    final reason = session.result?['reason'];
    if (session.exercise == ExerciseType.pushUp &&
        !_reportCreated &&
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
    _syncAutoReady();
    final theirs = OnlineStageEvents.opponentRep(_theirs, session);
    _theirs = OnlineStageEvents.opponentSeen(session);
    if (theirs != null) _stage.rep(theirs);
    if (mounted) setState(() {});
  }

  void _onCounter() {
    _syncRound();
    final state = _counter.state, frame = state.lastFrame;
    if (state.phase == CounterPhase.running) {
      session.publishPose(frame);
      if (frame != null && !identical(frame, _seen)) {
        _seen = frame;
        _setupStatus = _setup.update(
          frame,
          phonePropped: _counter.isPhonePropped,
          phoneStill: _counter.isPhoneStill,
        );
        _setupReady = _setupStatus.isReady;
      }
    } else {
      session.publishPose(null);
      _setup.reset();
      _setupStatus = SetupStatus.initial;
      _setupReady = false;
    }
    if (session.canReady &&
        !_setupReady &&
        session.readyPlayers.contains(session.playerId)) {
      session.ready(false);
    }
    _syncAutoReady();
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

  /// The camera area's one line before the start: what the setup wants, or
  /// that the user waits for the opponent.
  String? get _setupHint {
    if (!session.connected) return '재연결 중 · 준비 상태 확인 중…';
    if (_iAmReady) return '상대 준비를 기다리는 중…';
    final seconds = _autoReadySeconds;
    if (seconds != null) return '자세 확인! $seconds초 후 자동으로 준비해요';
    return _setupStatus.message;
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
    _cancelAutoReady();
    unawaited(keepScreenOn(false));
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(_onSession);
    _counter.removeListener(_onCounter);
    unawaited(_reps?.cancel());
    _counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_endedWithoutResult) {
      return _Ended(session: session, onHome: () => Navigator.pop(context));
    }
    final counter = _counter.state;
    final running = counter.phase == CounterPhase.running;
    final cameraFailed = {
      CounterPhase.permissionDenied,
      CounterPhase.cameraError,
      CounterPhase.detectorError,
    }.contains(counter.phase);
    final stage = OnlineStageEvents.stateOf(
      session,
      myName: widget.playerName,
      cameraFailed: cameraFailed,
    );
    final setup = stage.phase == BattleStagePhase.setup;
    // The setup's guide stays up to the start, as in the bot battle, and
    // the round's height lines come with the round.
    final settingUp = setup || stage.phase == BattleStagePhase.countdown;
    final pushUp = session.exercise == ExerciseType.pushUp;
    final guide = settingUp && running
        ? BattleCameraView.setupGuide(
            session.exercise,
            ready: _setupStatus.isReady,
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
          camera: cameraFailed
              ? _CameraTrouble(
                  onRetry: counter.phase == CounterPhase.permissionDenied
                      ? _counter.openSettings
                      : _counter.retry,
                )
              : BattleCameraView(
                  controller: _counter.cameraController,
                  frame: running ? counter.lastFrame : null,
                  mirror: _counter.isFrontCamera,
                  chestSnapshot: pushUp && !settingUp ? counter.snapshot : null,
                  squatSnapshot: !pushUp && !settingUp
                      ? counter.snapshot
                      : null,
                  guide: guide?.widget,
                  guideFit: guide?.fit ?? BoxFit.cover,
                ),
          onLeave: () => unawaited(_exit()),
          hint: setup ? _setupHint : _roundHint,
          readyLabel: setup ? (_iAmReady ? '준비 취소' : '준비') : null,
          onReady: setup && session.canReady && (_iAmReady || _setupReady)
              ? _toggleReady
              : null,
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
/// connection error. Nothing was recorded; the user goes home.
class _Ended extends StatelessWidget {
  const _Ended({required this.session, required this.onHome});

  final OnlineBattleSession session;
  final VoidCallback onHome;

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
    final message = session.serverRestarted
        ? '서버가 다시 시작되어 이 경기는 기록되지 않았어요.'
        : session.matchNotFound
        ? '서버에서 이 경기를 찾을 수 없어요.'
        : session.error ?? '종료 사유: ${session.result?['reason'] ?? '알 수 없음'}';
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
