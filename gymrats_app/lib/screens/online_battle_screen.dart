import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/form_report.dart';
import '../models/pose_frame.dart';
import '../services/device/device_controls.dart';
import '../services/feedback/form_report_store.dart';
import '../services/online/online_battle_session.dart';
import '../services/pose/setup_checker.dart';
import '../services/user/user_repository.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../widgets/opponent_avatar_panel.dart';
import '../widgets/pose_avatar_toggle_view.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/exit_game_button.dart';
import '../widgets/battle_score_balance.dart';
import 'setup_screen.dart';
import 'feedback_screen.dart';

class OnlineBattleScreen extends StatefulWidget {
  const OnlineBattleScreen({
    super.key,
    required this.session,
    this.createCounter,
    this.setupConfig = const SetupConfig(),
    this.formReports,
    this.userRepository,
  });
  final OnlineBattleSession session;
  final RepCounterViewModel Function()? createCounter;
  final SetupConfig setupConfig;
  final FormReportStore? formReports;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Receives the battle's form report under the server's result id; the
  /// battle itself is stored by the battle server (P11).
  final UserRepository? userRepository;
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

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// Sends ready by itself once the pose has stayed ready for
  /// [SetupConfig.autoStartDelay], like the bot setup's auto start. Losing
  /// the pose before then cancels it; the next ready pose starts it again.
  Timer? _autoReady;
  DateTime? _autoReadyAt;

  /// The user cancelled ready: no auto ready until the pose is lost and
  /// found again, or they press Start.
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

  /// Start or 준비 취소. Cancelling pauses the auto ready.
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
      exercise: ExerciseType.pushUp,
      config: widget.setupConfig,
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(keepScreenOn(true));
    // Online timing is owned by the server. The counter's offline round clock
    // must not start/finish a different round during camera preparation.
    _counter =
        widget.createCounter?.call() ??
        RepCounterViewModel(roundLength: const Duration(days: 1));
    _counter.addListener(_onCounter);
    session.addListener(_onSession);
    _reps = _counter.reps.listen((rep) {
      if (_roundStarted && _counter.history.contains(rep)) {
        if (rep.valid) const DeviceRepSound().playRepCounted();
        session.submitRep(rep);
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
    if (!_reportCreated &&
        _roundStarted &&
        session.phase == OnlinePhase.finished &&
        session.result?['reason'] == 'time_up') {
      _reportCreated = true;
      final report = FormReport(
        endedAt: DateTime.fromMillisecondsSinceEpoch(
          (session.result?['ended_at_ms'] as int?) ?? session.serverNow,
        ),
        opponentName: session.opponent!.name,
        roundLength: Duration(milliseconds: session.durationMs),
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
            ? '${session.opponent!.name}과의 대결이 취소되고\n홈으로 돌아가요.'
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
    final opponent = session.opponent!, counter = _counter.state;
    final terminal = session.terminal;
    final ready = session.readyPlayers.contains(session.playerId);
    final cameraFailed = {
      CounterPhase.permissionDenied,
      CounterPhase.cameraError,
      CounterPhase.detectorError,
    }.contains(counter.phase);
    if (!terminal &&
        (session.phase == OnlinePhase.preparing ||
            session.phase == OnlinePhase.scheduled)) {
      final scheduled = session.phase == OnlinePhase.scheduled;
      return PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_exit());
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (counter.phase == CounterPhase.running)
                PoseAvatarToggleView(
                  initialModel: session.avatar,
                  allowAvatarSelection: false,
                  controller: _counter.cameraController,
                  frame: counter.lastFrame,
                  mirror: _counter.isFrontCamera,
                )
              else if (cameraFailed)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('카메라 권한 또는 자세 인식을 확인해주세요.'),
                        TextButton(
                          onPressed:
                              counter.phase == CounterPhase.permissionDenied
                              ? _counter.openSettings
                              : _counter.retry,
                          child: const Text('카메라 다시 준비'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              PoseReadyBorder(ready: _setupReady),
              SafeArea(
                child: Column(
                  children: [
                    PoseSetupTopButtons(
                      canSwitchCamera:
                          counter.phase == CounterPhase.running &&
                          _counter.canSwitchCamera &&
                          !scheduled,
                      onSwitchCamera: () => unawaited(_counter.switchCamera()),
                      onBack: () => unawaited(_exit()),
                      center: ExitGameButton(
                        onPressed: () => unawaited(_exit()),
                      ),
                    ),
                    const Spacer(),
                    PoseSetupPanel(
                      message: scheduled
                          ? '${session.countdownSeconds}초 후 함께 시작'
                          : ready
                          ? '상대 준비를 기다리는 중…'
                          : _autoReadySeconds != null
                          ? '자세 확인! $_autoReadySeconds초 후 자동으로 준비해요'
                          : _setupStatus.message,
                      ready: _setupReady,
                      progress: _setupProgress,
                      buttonLabel: scheduled
                          ? '경기 시작 대기'
                          : ready
                          ? '준비 취소'
                          : 'Start',
                      onStart: session.canReady && (ready || _setupReady)
                          ? _toggleReady
                          : null,
                      notice: Text(
                        !session.connected
                            ? '재연결 중 · 준비 상태를 확인하고 있어요.'
                            : session.readyPlayers.contains(opponent.id)
                            ? '${opponent.name} · 준비 완료'
                            : '${opponent.name} · 자세 세팅 중',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return PopScope(
      canPop: terminal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('온라인 1v1'),
          leading: IconButton(
            onPressed: _exit,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: OpponentAvatarPanel(
                  name: opponent.name,
                  model: opponent.avatar,
                  frame: session.opponentFrame,
                  connected: session.connected && session.opponentConnected,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '나  ${session.myReps}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(session.remainingMs / 1000).ceil()}초',
                      style: const TextStyle(fontSize: 20),
                    ),
                    Text(
                      '${session.opponentReps}  상대',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (terminal)
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            session.matchUnconfirmed
                                ? '경기를 확인할 수 없어요'
                                : switch (session.phase) {
                                    OnlinePhase.finished =>
                                      switch (session.outcome) {
                                        'win' => '승리',
                                        'loss' => '패배',
                                        'draw' => '무승부',
                                        _ => '서버 결과 확인 중',
                                      },
                                    OnlinePhase.voided => '경기 무효',
                                    OnlinePhase.cancelled => '경기 취소',
                                    _ => '연결 오류',
                                  },
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            session.serverRestarted
                                ? '서버가 다시 시작되어 이 경기는 기록되지 않았어요.'
                                : session.matchNotFound
                                ? '서버에서 이 경기를 찾을 수 없어요.'
                                : session.error ??
                                      '종료 사유: ${session.result?['reason'] ?? '알 수 없음'}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (_formReport case final report?)
                            TextButton(
                              onPressed: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FeedbackScreen(report: report),
                                ),
                              ),
                              child: const Text('자세 피드백 보기'),
                            ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('홈으로 돌아가기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  flex: 4,
                  child: cameraFailed
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('카메라 권한 또는 자세 인식을 확인해주세요.'),
                              TextButton(
                                onPressed:
                                    counter.phase ==
                                        CounterPhase.permissionDenied
                                    ? _counter.openSettings
                                    : _counter.retry,
                                child: const Text('카메라 다시 준비'),
                              ),
                            ],
                          ),
                        )
                      : PoseAvatarToggleView(
                          chestSnapshot: counter.snapshot,
                          initialModel: session.avatar,
                          allowAvatarSelection: false,
                          controller: _counter.cameraController,
                          frame: counter.phase == CounterPhase.running
                              ? counter.lastFrame
                              : null,
                          mirror: _counter.isFrontCamera,
                          showLandmarks: true,
                        ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BattleScoreBalance(
                      mine: session.myReps,
                      theirs: session.opponentReps,
                    ),
                    const SizedBox(height: 8),
                    if (!session.connected && !terminal)
                      const Text(
                        '재연결 중 · 경기 시간은 계속 진행됩니다.',
                        style: TextStyle(color: Colors.amber),
                      ),
                    if (session.phase == OnlinePhase.awaitingResult)
                      const Text('서버의 최종 결과를 기다리는 중…'),
                    if (session.roundRunning && counter.lastEvent != null)
                      Text(
                        counter.lastEvent!.valid
                            ? '+1'
                            : counter.lastEvent!.reason?.message ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (session.error != null && !terminal)
                      Text(
                        session.error!,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.amber),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
