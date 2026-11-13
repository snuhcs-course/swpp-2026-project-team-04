import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/exercise_type.dart';
import '../models/matchup.dart';
import '../services/device/device_controls.dart';
import '../services/feedback/form_report_store.dart';
import '../services/opponent/bot_opponent.dart';
import '../services/pose/rep_judge.dart';
import '../services/pose/setup_checker.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/battle_viewmodel.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../widgets/battle_arena.dart';
import '../widgets/battle_camera_view.dart';
import '../widgets/battle_stage_events.dart';
import '../widgets/battle_stage_model.dart';
import '../widgets/exit_dialog.dart';

/// A battle against the bot, from the pose setup to the end: the fighting
/// stage above and the user's camera below (the battle arena).
///
/// It opens on the setup, in the same layout: the user's pose is checked
/// while the bot stands ready, and once the pose holds, the setup's count to
/// the start is the stage's 3, 2, 1 and GO!. 시작 begins the round at once.
/// The screen stays upright throughout. Back and the leave button ask before
/// leaving, and leaving keeps nothing. When a KO or the time ends the battle
/// and its ending has played, 결과 보기 opens the result screen in this one's
/// place; back then does the same, and nothing before.
///
/// Sounds hook in from outside, without changing this screen: [onCue] for
/// the stage's moments and [onSetup] for the setup's hints.
class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.matchup,
    this.createViewModel,
    this.onCue,
    this.onSetup,
  });

  final Matchup matchup;

  /// Builds the view model; replaces the default one in tests.
  final BattleViewModel Function()? createViewModel;

  /// Called once for each moment of the stage a sound can follow, as it
  /// shows: a blow, a miss, 3, 2, 1, GO!, the KO, time-up and its verdict
  /// ([BattleArena.onCue]). The battle's sound effects come in here.
  final ValueChanged<BattleStageCue>? onCue;

  /// Called before the round on every change while the pose is checked,
  /// with the setup's latest status and the time left before the round
  /// starts by itself (null while not counting down). The setup's voice
  /// lines come in here (J1's `VoiceCueTable.forSetup` and `forCountdown`
  /// take these two as they are).
  final BattleSetupListener? onSetup;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

/// Hears the setup before the round: the pose check's latest [status], and
/// the time left before the round starts by itself, null while not counting
/// down. See [BattleScreen.onSetup].
typedef BattleSetupListener = void Function(
  SetupStatus status,
  Duration? startIn,
);

class _BattleScreenState extends State<BattleScreen>
    with WidgetsBindingObserver {
  late final BattleViewModel _viewModel;
  bool _cameraStarted = false;
  Orientation? _orientation;

  /// True while the leave dialog is open. The battle ending closes it.
  bool _askingToLeave = false;

  /// Set once the result was asked for, so it opens once.
  bool _openedResult = false;

  /// The stage's clock and what plays on it: a new one for every try after
  /// a camera failure, with [_try] telling the arena to start over.
  BattleStageController _stage = BattleStageController();
  int _try = 0;

  /// The state the stage was last given, to tell the new reps by.
  late BattleState _shown;

  @override
  void initState() {
    super.initState();
    final createViewModel = widget.createViewModel;
    if (createViewModel != null) {
      _viewModel = createViewModel();
    } else {
      final counter = BattleViewModel.botCounter(widget.matchup.exercise);
      _viewModel = BattleViewModel.bot(
        matchup: widget.matchup,
        counter: counter,
        opponent: BotOpponent.forMatchup(
          widget.matchup,
          passDepth: counter.passDepth,
        ),
        repository: context.read<UserRepository>(),
        sound: const DeviceRepSound(),
        formReports: context.read<FormReportStore>(),
      );
    }
    _shown = _viewModel.state;
    _viewModel.addListener(_onViewModelChanged);
    WidgetsBinding.instance.addObserver(this);
    // The setup and the battle are upright: the camera's frames and the
    // stage assume it.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    unawaited(keepScreenOn(true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    if (!_cameraStarted && orientation == Orientation.portrait) {
      // The camera reads the orientation when it opens, so the setup waits
      // for portrait.
      _cameraStarted = true;
      _viewModel.start();
    } else if (_cameraStarted && orientation != _orientation) {
      _viewModel.onScreenRotated();
    }
    _orientation = orientation;
  }

  /// Gives the stage every rep at once, on every change: the game reports
  /// a KO one change before the rep that caused it.
  void _onViewModelChanged() {
    final state = _viewModel.state;
    final events = BattleStageEvents.between(
      _shown,
      state,
      passDepth: _viewModel.counter.passDepth,
      rules: _viewModel.rules,
    );
    events.forEach(_stage.rep);
    if (state.started && !_shown.started) _stage.go();
    _shown = state;
    if (!state.started && state.phase == BattlePhase.setup) {
      widget.onSetup?.call(state.setup, state.startIn);
    }
    // The battle is over, so the question no longer applies.
    if (_askingToLeave && state.phase == BattlePhase.timeUp) {
      _askingToLeave = false;
      Navigator.pop(context);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _viewModel.pause();
      case AppLifecycleState.resumed:
        _viewModel.resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// The system's back gesture: asks to leave while the battle is on. Once
  /// it has ended, it opens the result after the ending has played, as
  /// 결과 보기 does, and does nothing before.
  void _back() {
    if (_viewModel.state.result != null) {
      if (_stage.resultReady) _openResult();
      return;
    }
    unawaited(_askToLeave());
  }

  /// Asks before leaving, from back or the leave button.
  Future<void> _askToLeave() async {
    if (_askingToLeave) return;
    _askingToLeave = true;
    final leave = await confirmExit(
      context,
      ExitDialog.game(opponentName: widget.matchup.opponent.name),
    );
    _askingToLeave = false;
    if (!mounted) return;
    if (leave) _leave();
  }

  /// Goes home and keeps nothing. The round stops first, so time cannot run
  /// out while this screen slides away.
  void _leave() {
    _viewModel.leave();
    popToHome(context);
  }

  /// Replaces this screen with the result screen.
  void _openResult() {
    final result = _viewModel.state.result;
    if (_openedResult || result == null) return;
    _openedResult = true;
    Navigator.pushReplacementNamed(
      context,
      GymRatsApp.resultRoute,
      arguments: result,
    );
  }

  /// After a camera failure: the setup again, then the round from zero, on
  /// a stage that starts over.
  void _retry() {
    setState(() {
      _try += 1;
      _stage = BattleStageController();
    });
    unawaited(_viewModel.retry());
  }

  @override
  void dispose() {
    unawaited(keepScreenOn(false));
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BattleViewModel>.value(value: _viewModel),
        ChangeNotifierProvider<RepCounterViewModel>.value(
          value: _viewModel.counter,
        ),
      ],
      child: Consumer2<BattleViewModel, RepCounterViewModel>(
        builder: (context, viewModel, counter, _) => PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: _arena(viewModel, counter),
          ),
        ),
      ),
    );
  }

  Widget _arena(BattleViewModel viewModel, RepCounterViewModel counter) {
    final state = viewModel.state;
    final counterState = counter.state;
    final stage = BattleStageEvents.stateOf(
      state,
      widget.matchup,
      roundLength: viewModel.roundLength,
      rules: viewModel.rules,
    );
    final pushUp = widget.matchup.exercise == ExerciseType.pushUp;
    final setup = stage.phase == BattleStagePhase.setup;
    final settingUp = setup || stage.phase == BattleStagePhase.countdown;
    final running = counterState.phase == CounterPhase.running;
    final guide = settingUp && running
        ? BattleCameraView.setupGuide(
            widget.matchup.exercise,
            ready: state.setup.isReady,
          )
        : null;
    final Widget camera = state.phase == BattlePhase.failed
        ? _CameraFailed(
            state: counterState,
            onRetry: _retry,
            onOpenSettings: counter.openSettings,
          )
        : Stack(
            alignment: Alignment.center,
            children: [
              BattleCameraView(
                controller: counter.cameraController,
                frame: running ? counterState.lastFrame : null,
                mirror: counter.isFrontCamera,
                chestSnapshot: pushUp && state.started
                    ? counterState.snapshot
                    : null,
                squatSnapshot: !pushUp && state.started
                    ? counterState.snapshot
                    : null,
                guide: guide?.widget,
                guideFit: guide?.fit ?? BoxFit.cover,
              ),
              if (state.phase == BattlePhase.starting ||
                  state.phase == BattlePhase.paused)
                const CircularProgressIndicator(),
            ],
          );
    return BattleArena(
      key: ValueKey(_try),
      controller: _stage,
      state: stage,
      camera: camera,
      onCue: widget.onCue,
      onLeave: () => unawaited(_askToLeave()),
      hint: _hint(state, counterState, stage.phase),
      readyLabel: settingUp ? '시작' : null,
      onReady: settingUp && state.canStart ? viewModel.startNow : null,
      onSwitchCamera: setup && running && counter.canSwitchCamera
          ? () => unawaited(counter.switchCamera())
          : null,
      setupProgress: setup ? state.setup.readyProgress : null,
      onShowResult: _openResult,
    );
  }

  /// The camera area's one line: what the setup wants before the round,
  /// and for squats in the round, where the user is in the rep.
  String? _hint(
    BattleState state,
    RepCounterState counterState,
    BattleStagePhase phase,
  ) => switch (phase) {
    BattleStagePhase.setup =>
      state.phase == BattlePhase.setup ? state.setup.message : null,
    BattleStagePhase.playing
        when widget.matchup.exercise == ExerciseType.squat &&
            state.phase == BattlePhase.playing =>
      switch (counterState.snapshot.phase) {
        RepPhase.up || RepPhase.descending => '일어선 상태 · 무릎 가까이 앉아 주세요',
        RepPhase.bottom => '앉은 상태 · 이제 일어서세요',
        RepPhase.idle || RepPhase.lost => '정면에서 전신이 보이도록 서 주세요',
      },
    _ => null,
  };
}

/// Why the camera stopped, where the camera would be, and the way back:
/// retrying sets up again and restarts the round on both sides.
class _CameraFailed extends StatelessWidget {
  const _CameraFailed({
    required this.state,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final RepCounterState state;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  static const _restartNote = '다시 시도하면 경기가 처음부터 시작돼요.';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final needsSettings =
        state.phase == CounterPhase.permissionDenied && state.permanentlyDenied;
    final (title, detail) = switch (state.phase) {
      CounterPhase.cameraError => ('카메라를 켜지 못했어요', _restartNote),
      CounterPhase.detectorError => ('자세 인식이 멈췄어요', _restartNote),
      _ when needsSettings => ('카메라 권한이 꺼져 있어요', '설정에서 카메라를 허용해 주세요.'),
      _ => ('카메라 권한이 필요해요', '횟수를 세려면 카메라가 필요해요.'),
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s16),
          FilledButton(
            onPressed: needsSettings ? onOpenSettings : onRetry,
            child: Text(needsSettings ? '설정 열기' : '다시 시도'),
          ),
        ],
      ),
    );
  }
}
