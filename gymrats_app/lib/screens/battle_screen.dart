import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/matchup.dart';
import '../services/device/device_controls.dart';
import '../services/opponent/bot_opponent.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/battle_viewmodel.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../widgets/battle_score_panel.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/landmark_overlay.dart';
import '../widgets/opponent_window.dart';
import '../widgets/pose_camera_view.dart';
import '../widgets/time_up_overlay.dart';

/// The 60-second battle: the user's camera on top, the opponent in a small
/// window, and the scores below.
///
/// The round starts once the camera runs in portrait. Back asks before
/// leaving, and leaving keeps nothing. When time is up, a TIME UP overlay
/// leads to the result screen, which replaces this one; back then goes
/// home.
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, required this.matchup, this.createViewModel});

  final Matchup matchup;

  /// Builds the view model; replaces the default one in tests.
  final BattleViewModel Function()? createViewModel;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with WidgetsBindingObserver {
  late final BattleViewModel _viewModel;
  bool _cameraStarted = false;
  Orientation? _orientation;

  /// True while the leave dialog is open. Time running out closes it.
  bool _askingToLeave = false;

  /// Set once 결과 보기 is pressed, so a second tap does nothing.
  bool _openedResult = false;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        BattleViewModel(
          matchup: widget.matchup,
          counter: RepCounterViewModel(roundLength: battleDuration),
          opponent: BotOpponent(),
          repository: context.read<UserRepository>(),
          sound: const DeviceRepSound(),
        );
    _viewModel.addListener(_onViewModelChanged);
    WidgetsBinding.instance.addObserver(this);
    // Setup may have turned the screen sideways, and it restores portrait
    // only once it is gone, after this screen has opened.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    unawaited(keepScreenOn(true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    if (!_cameraStarted && orientation == Orientation.portrait) {
      // The camera reads the orientation when it opens, so the round waits
      // for portrait.
      _cameraStarted = true;
      _viewModel.start();
    } else if (_cameraStarted && orientation != _orientation) {
      _viewModel.onScreenRotated();
    }
    _orientation = orientation;
  }

  void _onViewModelChanged() {
    // The battle is over, so the question no longer applies.
    if (_askingToLeave && _viewModel.state.phase == BattlePhase.timeUp) {
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

  /// Asks before leaving, on a back attempt during the round.
  Future<void> _askToLeave() async {
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
      child: Selector<BattleViewModel, bool>(
        selector: (_, vm) => vm.state.phase == BattlePhase.timeUp,
        builder: (context, timeUp, _) => PopScope<Object?>(
          // Once time is up nothing can be lost: back goes home.
          canPop: timeUp,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _askToLeave();
          },
          child: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                _BattleLayout(matchup: widget.matchup),
                if (timeUp)
                  TimeUpOverlay(
                    result: _viewModel.state.result!,
                    onShowResult: _openResult,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The camera on top and the score panel below.
///
/// The camera box keeps the preview's own shape, so the picture is neither
/// cropped nor stretched. On a short screen the panel keeps its room, the
/// box narrows, and its sides stay dark.
class _BattleLayout extends StatefulWidget {
  const _BattleLayout({required this.matchup});

  final Matchup matchup;

  @override
  State<_BattleLayout> createState() => _BattleLayoutState();
}

class _BattleLayoutState extends State<_BattleLayout> {
  /// Width over height of the portrait preview. Kept while the camera
  /// reopens; 3:4 until the camera first reports its size.
  double _aspectRatio = 3 / 4;

  /// The least height the panel needs, besides the bottom inset.
  static const _minPanelHeight = 260.0;

  @override
  Widget build(BuildContext context) {
    final previewSize = context.select<RepCounterViewModel, Size?>(
      (counter) => counter.cameraController?.value.previewSize,
    );
    // previewSize is landscape; in portrait the preview is its swap, as in
    // PoseCameraView.
    if (previewSize != null) {
      _aspectRatio = previewSize.height / previewSize.width;
    }
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cameraSize = _cameraSize(constraints.biggest, bottomInset);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: cameraSize.height,
              child: _CameraArea(
                cameraSize: cameraSize,
                matchup: widget.matchup,
              ),
            ),
            Expanded(
              child: BattleScorePanel(
                opponentName: widget.matchup.opponent.name,
              ),
            ),
          ],
        );
      },
    );
  }

  /// The camera box in [area]: full width in the preview's shape, or
  /// shorter and narrower when the panel below would get less than
  /// [_minPanelHeight].
  Size _cameraSize(Size area, double bottomInset) {
    final fullWidthHeight = area.width / _aspectRatio;
    final heightAbovePanel = area.height - _minPanelHeight - bottomInset;
    final height = math.max(0.0, math.min(fullWidthHeight, heightAbovePanel));
    return Size(math.min(area.width, height * _aspectRatio), height);
  }
}

/// The camera box, with the user's name chip and the opponent's window over
/// its top corners.
class _CameraArea extends StatelessWidget {
  const _CameraArea({required this.cameraSize, required this.matchup});

  /// The camera box's size, at most the area's.
  final Size cameraSize;

  final Matchup matchup;

  /// Camera height in the design, where the opponent window is full size.
  static const _designHeight = 520.0;

  @override
  Widget build(BuildContext context) {
    final moves = context.select<BattleViewModel, int>(
      (vm) => vm.state.opponentMoves,
    );
    final live = context.select<BattleViewModel, bool>(
      (vm) => vm.state.phase == BattlePhase.playing,
    );
    final top = MediaQuery.paddingOf(context).top + 16;
    return Stack(
      children: [
        Center(
          child: SizedBox.fromSize(size: cameraSize, child: const _CameraBox()),
        ),
        Positioned(
          left: 16,
          top: top,
          child: _NameChip(name: matchup.playerName),
        ),
        Positioned(
          right: 16,
          top: top,
          child: OpponentWindow(
            opponent: matchup.opponent,
            moves: moves,
            live: live,
            // Smaller with a short camera, down to three quarters.
            scale: (cameraSize.height / _designHeight).clamp(0.75, 1.0),
          ),
        ),
      ],
    );
  }
}

/// The preview with the landmark dots while the round runs, a spinner while
/// the camera opens, or what went wrong.
class _CameraBox extends StatelessWidget {
  const _CameraBox();

  @override
  Widget build(BuildContext context) {
    final counter = context.watch<RepCounterViewModel>();
    final state = counter.state;
    final frame = state.lastFrame;
    final Widget? overlay = switch (state.phase) {
      CounterPhase.running when frame != null => LandmarkOverlay(
        frame: frame,
        mirror: counter.isFrontCamera,
        isVisible: counter.isVisible,
      ),
      CounterPhase.starting ||
      CounterPhase.paused => const Center(child: CircularProgressIndicator()),
      CounterPhase.permissionDenied ||
      CounterPhase.cameraError ||
      CounterPhase.detectorError => _CameraFailed(state: state),
      CounterPhase.running || CounterPhase.finished => null,
    };
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          PoseCameraView(
            controller: counter.cameraController,
            mirror: counter.isFrontCamera,
          ),
          ?overlay,
        ],
      ),
    );
  }
}

/// Why the camera stopped, and the way back: retrying restarts the round
/// on both sides.
class _CameraFailed extends StatelessWidget {
  const _CameraFailed({required this.state});

  final RepCounterState state;

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
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (needsSettings)
                FilledButton(
                  onPressed: context.read<RepCounterViewModel>().openSettings,
                  child: const Text('설정 열기'),
                )
              else
                FilledButton(
                  onPressed: context.read<BattleViewModel>().retry,
                  child: const Text('다시 시도'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "● 나 · 우현" on a dark pill with a lime edge.
class _NameChip extends StatelessWidget {
  const _NameChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      // Leaves room for the opponent window on a narrow phone.
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: ShapeDecoration(
        color: AppColors.background.withValues(alpha: 0.78),
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '나 · $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
