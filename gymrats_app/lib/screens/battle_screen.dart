import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/exercise_type.dart';
import '../models/character_rig.dart';
import '../models/feedback_goal.dart';
import '../models/matchup.dart';
import '../models/setup_hint_short.dart';
import '../services/device/device_controls.dart';
import '../services/feedback/form_report_store.dart';
import '../services/feedback/goal_progress.dart';
import '../services/feedback/goal_store.dart';
import '../services/opponent/bot_opponent.dart';
import '../services/pose/setup_checker.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/battle_viewmodel.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../widgets/battle_arena.dart';
import '../widgets/battle_camera_view.dart';
import '../widgets/battle_stage_events.dart';
import '../widgets/battle_stage_model.dart';
import '../widgets/character_figure.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/sound_battle.dart';

/// A battle against the bot, from the pose setup to the end: the fighting
/// stage above and the user's camera below (the battle arena).
///
/// It opens on the setup, in the same layout: the user's pose is checked
/// while the bot stands ready, and once the pose holds, the setup's count to
/// the start is the stage's 3, 2, 1 and GO!. The round starts by itself: the
/// setup has no button to press (team decision 2026-11-15). The screen
/// stays upright throughout. Back and the leave button ask before leaving,
/// and leaving keeps nothing. When a KO or the time ends the battle
/// and its ending has played, 결과 보기 opens the result screen in this one's
/// place; back then does the same, and nothing before.
///
/// The user's goal for the exercise (A11 spec 5), when one is saved, shows
/// as a chip under the valid counts from the countdown on, and the rep
/// that first reaches it brings up '미션 성공!'. The screen reads the goal
/// once and never changes it (task.md W11 decision 6).
///
/// Sounds hook in from outside, without changing this screen: [onCue] for
/// the stage's moments and [onSetup] for the setup's hints.
class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.matchup,
    this.myCharacter = CharacterRig.defaultId,
    this.createViewModel,
    this.onCue,
    this.onSetup,
  });

  final Matchup matchup;

  /// The user's character on the stage; RepBot is the opponent's.
  final String myCharacter;

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
  final _sounds = BattleSounds();
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

  /// The user's goal for this exercise and how far this battle has come
  /// on it; null without one, and until it has been read.
  GoalTracker? _goal;

  /// Set once the goal has been asked for: it is read once.
  bool _goalAsked = false;

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
        sound: const NoRepBeep(),
        formReports: context.read<FormReportStore>(),
        // Kept in the battle's report, so 기록보관소 shows it later.
        characterId: widget.myCharacter,
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
    if (!_goalAsked) {
      _goalAsked = true;
      unawaited(_readGoal());
    }
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

  /// Reads the user's goal for this exercise (A11 spec 5): from the app's
  /// goal store, for the signed-in account. Without either, or when the
  /// store cannot be read, the battle has no goal. Setting up takes far
  /// longer than the read, and the chip only shows from the countdown on,
  /// so it never comes in late.
  Future<void> _readGoal() async {
    final store = Provider.of<GoalStore?>(context, listen: false);
    final account = Provider.of<AuthViewModel?>(
      context,
      listen: false,
    )?.account;
    if (store == null || account == null) return;
    final FeedbackGoal? goal;
    try {
      goal = await store.read(account.id, widget.matchup.exercise);
    } on Object {
      return;
    }
    if (goal == null || !mounted) return;
    final tracker = GoalTracker(goal)
      ..count(
        _viewModel.counter.repRecords,
        roundLength: _viewModel.roundLength,
      );
    setState(() => _goal = tracker);
  }

  /// [event], marked as the one that first reached the goal when it is.
  /// The user's reps recount the goal from the counter's records: the
  /// same reps, in round time, that the battle's form report keeps.
  BattleStageEvent _withGoal(BattleStageEvent event) {
    final goal = _goal;
    if (goal == null || event.side != BattleSide.me) return event;
    return goal.count(
          _viewModel.counter.repRecords,
          roundLength: _viewModel.roundLength,
        )
        ? event.reachingGoal()
        : event;
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
    for (final event in events) {
      _stage.rep(_withGoal(event));
    }
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
      // A new try is a new battle: the goal starts over with it.
      if (_goal case final goal?) {
        _goal = GoalTracker(goal.goal);
      }
    });
    unawaited(_viewModel.retry());
  }

  @override
  void dispose() {
    unawaited(keepScreenOn(false));
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _sounds.dispose();
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
    final standing = BattleStageEvents.stateOf(
      state,
      widget.matchup,
      roundLength: viewModel.roundLength,
      rules: viewModel.rules,
    );
    final goal = _goal?.progress;
    final stage = standing.withGoal(
      standing.phase == BattleStagePhase.ended ? goal?.atEnd() : goal,
    );
    _sounds.show(stage);
    final pushUp = widget.matchup.exercise == ExerciseType.pushUp;
    final setup = stage.phase == BattleStagePhase.setup;
    final settingUp = setup || stage.phase == BattleStagePhase.countdown;
    final running = counterState.phase == CounterPhase.running;
    final guide = settingUp && running
        ? BattleCameraView.setupGuide(
            widget.matchup.exercise,
            ready:
                state.setup.isReady &&
                state.guideAligned &&
                state.setup.reason == SetupReason.ready,
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
              if (counterState.trackingPaused &&
                  (state.phase == BattlePhase.setup ||
                      state.phase == BattlePhase.playing))
                PersonTrackingPauseNotice(
                  onConfirm: counter.confirmTrackedPerson,
                  roundStarted: state.started,
                ),
            ],
          );
    return BattleArena(
      key: ValueKey(_try),
      controller: _stage,
      state: stage,
      camera: camera,
      characters: BattleCharacters(
        me: widget.myCharacter,
        opponent: CharacterRig.botId,
      ),
      onCue: widget.onCue ?? _sounds.cue,
      onLeave: () => unawaited(_askToLeave()),
      // While the person check asks for a tap, it is the only thing to do:
      // no board over it, and no cue that says something else.
      setupCue: counterState.trackingPaused
          ? null
          : _setupCue(state, stage.phase),
      onSwitchCamera: setup && running && counter.canSwitchCamera
          ? () => unawaited(counter.switchCamera())
          : null,
      setupProgress: setup
          ? (state.guideAligned ? state.setup.readyProgress : 0)
          : null,
      onShowResult: _openResult,
    );
  }

  /// The setup's short cue before the round (A9): what the setup wants, a
  /// squat that is not in the silhouette yet first. The round has no line
  /// of its own: the camera's frame and the bold lines say how a rep went
  /// (A9 spec 6).
  SetupHintShort? _setupCue(BattleState state, BattleStagePhase phase) {
    if (phase != BattleStagePhase.setup || state.phase != BattlePhase.setup) {
      return null;
    }
    return SetupHintShort.of(
      state.setup,
      outsideSilhouette:
          widget.matchup.exercise == ExerciseType.squat &&
          state.setup.reason == SetupReason.ready &&
          !state.guideAligned,
    );
  }
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

/// An ambiguous pose is never adopted until the player confirms the view.
class PersonTrackingPauseNotice extends StatelessWidget {
  const PersonTrackingPauseNotice({
    super.key,
    required this.onConfirm,
    this.roundStarted = false,
  });
  final VoidCallback onConfirm;
  final bool roundStarted;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '사람을 다시 확인해 주세요. 횟수 기록이 일시 중단됐어요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                roundStarted
                    ? '운동하는 사람만 카메라에 보이도록 해 주세요. 대결 시간은 계속 흘러요.'
                    : '운동하는 사람만 카메라에 보이도록 해 주세요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.s8),
              FilledButton(onPressed: onConfirm, child: const Text('확인 후 계속')),
            ],
          ),
        ),
      ),
    ),
  );
}
