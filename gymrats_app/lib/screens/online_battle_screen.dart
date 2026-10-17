import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/pose_frame.dart';
import '../services/device/device_controls.dart';
import '../services/online/online_battle_session.dart';
import '../services/pose/setup_checker.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../widgets/opponent_avatar_panel.dart';
import '../widgets/pose_avatar_toggle_view.dart';

class OnlineBattleScreen extends StatefulWidget {
  const OnlineBattleScreen({
    super.key,
    required this.session,
    this.createCounter,
  });
  final OnlineBattleSession session;
  final RepCounterViewModel Function()? createCounter;
  @override
  State<OnlineBattleScreen> createState() => _OnlineBattleScreenState();
}

class _OnlineBattleScreenState extends State<OnlineBattleScreen>
    with WidgetsBindingObserver {
  late final RepCounterViewModel _counter;
  StreamSubscription<dynamic>? _reps;
  final _setup = SetupChecker(exercise: ExerciseType.pushUp);
  PoseFrame? _seen;
  bool _setupReady = false,
      _roundStarted = false,
      _stopping = false,
      _asking = false;
  OnlineBattleSession get session => widget.session;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(keepScreenOn(true));
    // Online timing is owned by the server. The counter's offline 60s clock
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
      _counter.reset();
    }
    if (!_stopping &&
        (session.terminal || (_roundStarted && session.remainingMs == 0))) {
      _stopping = true;
      unawaited(_counter.finish(stoppedByUser: session.terminal));
    }
  }

  void _onSession() {
    _syncRound();
    if (mounted) setState(() {});
  }

  void _onCounter() {
    _syncRound();
    final state = _counter.state, frame = state.lastFrame;
    if (state.phase == CounterPhase.running) {
      session.publishPose(frame);
      if (frame != null && !identical(frame, _seen)) {
        _seen = frame;
        _setupReady = _setup.update(frame).isReady;
      }
    } else {
      session.publishPose(null);
      _setup.reset();
      _setupReady = false;
    }
    if (session.canReady &&
        !_setupReady &&
        session.readyPlayers.contains(session.playerId)) {
      session.ready(false);
    }
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
      builder: (context) => AlertDialog(
        title: const Text('온라인 배틀에서 나갈까요?'),
        content: Text(
          session.startAtMs == null
              ? '매칭이 취소됩니다.'
              : '시작 후 나가면 서버 규칙에 따라 기권 처리됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속하기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    _asking = false;
    if (leave != true || !mounted) return;
    await session.leave();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
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
                            switch (session.phase) {
                              OnlinePhase.finished => switch (session.outcome) {
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
                            session.error ??
                                '종료 사유: ${session.result?['reason'] ?? '알 수 없음'}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('로비로 돌아가기'),
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
                    if (!session.connected && !terminal)
                      const Text(
                        '재연결 중 · 경기 시간은 계속 진행됩니다.',
                        style: TextStyle(color: Colors.amber),
                      ),
                    if (session.phase == OnlinePhase.preparing)
                      FilledButton(
                        onPressed: session.canReady && (ready || _setupReady)
                            ? () => session.ready(!ready)
                            : null,
                        child: Text(
                          ready
                              ? '준비 취소 · 상대 대기'
                              : _setupReady
                              ? '준비 완료'
                              : '기존 자세 확인 기준을 맞춰주세요',
                        ),
                      ),
                    if (session.phase == OnlinePhase.scheduled)
                      Text(
                        '${session.countdownSeconds}초 후 함께 시작',
                        style: const TextStyle(fontSize: 22),
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
