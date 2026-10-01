import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/exercise_type.dart';
import '../services/pose/setup_checker.dart';
import '../viewmodels/setup_viewmodel.dart';
import '../widgets/pose_camera_view.dart';

const _readyColor = Colors.greenAccent;

/// Guides phone placement and waits until the body is reliably detected.
///
/// Pops with the selected [ExerciseType] when the user presses Start, or by
/// itself after the user stays Ready for [SetupConfig.autoStartDelay].
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.exercise,
    this.showDebugTools = false,
    this.createViewModel,
    this.exitOrientations = const [DeviceOrientation.portraitUp],
  });

  /// The phone may lie on the floor in either orientation. Upside-down
  /// portrait is left out, like most Android apps.
  static const orientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  final ExerciseType exercise;

  /// Orientations restored when the screen closes. The rest of the app is
  /// portrait only; a screen that keeps the phone on the floor passes
  /// [orientations] instead.
  final List<DeviceOrientation> exitOrientations;

  /// Draws the detected landmarks on the preview and prints the checker
  /// values (reason, fps, hold, auto start, thresholds) to the debug log,
  /// e.g. the `flutter run` terminal or `adb logcat`. Nothing is drawn as
  /// text over the camera. The log is written in every build mode, so only
  /// the demo turns this on.
  final bool showDebugTools;

  /// Builds the view model; replaces the default one in tests.
  final SetupViewModel Function()? createViewModel;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  late final SetupViewModel _viewModel;
  bool _finished = false;
  Orientation? _orientation;
  final Stopwatch _sinceLog = Stopwatch();
  String? _lastLogKey;
  bool _configLogged = false;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        SetupViewModel(exercise: widget.exercise);
    WidgetsBinding.instance.addObserver(this);
    _viewModel.addListener(_onViewModelChanged);
    SystemChrome.setPreferredOrientations(SetupScreen.orientations);
    _viewModel.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    if (_orientation != null && _orientation != orientation) {
      _viewModel.onScreenRotated();
    }
    _orientation = orientation;
  }

  void _onViewModelChanged() {
    if (widget.showDebugTools) _logDebug();
    if (_viewModel.state.autoStarted) _finish();
  }

  /// Logs the live checker values when they change, at most every 250 ms,
  /// and at least once per second while frames arrive. When no frames
  /// arrive (stream stalled), nothing is logged.
  void _logDebug() {
    final state = _viewModel.state;
    if (state.phase != SetupPhase.running) return;
    final c = _viewModel.config;
    if (!_configLogged) {
      _configLogged = true;
      debugPrint(
        'pose_setup config | minLikelihood=${c.minLikelihood} '
        'margin=${c.frameMargin * 100}% '
        'bodySize=${c.minBodySizeRatio * 100}%-${c.maxBodySizeRatio * 100}% '
        'maxNoseOffset=${c.maxNoseOffsetRatio} hold=${_s(c.readyDelay)} '
        'drop=${_s(c.dropDelay)} autoStart=${_s(c.autoStartDelay)} '
        'detectorTimeout=${_s(c.detectorFailureTimeout)}',
      );
    }
    final status = state.status;
    final key =
        '${status.reason.name} ${status.isReady} '
        '${state.autoStartIn?.inSeconds}';
    final elapsed = _sinceLog.elapsedMilliseconds;
    final due =
        !_sinceLog.isRunning ||
        elapsed >= 1000 ||
        (key != _lastLogKey && elapsed >= 250);
    if (!due) return;
    _lastLogKey = key;
    _sinceLog
      ..reset()
      ..start();
    final held = c.readyDelay * status.readyProgress;
    final autoStart = state.autoStartIn == null ? '-' : _s(state.autoStartIn!);
    debugPrint(
      'pose_setup | reason=${status.reason.name} fps=${state.fps} '
      'ready=${status.isReady} hold=${_s(held)}/${_s(c.readyDelay)} '
      'autoStart=$autoStart/${_s(c.autoStartDelay)} '
      '${_orientationInfo()}',
    );
  }

  /// Camera and screen orientation, to debug rotation problems.
  String _orientationInfo() {
    final value = _viewModel.cameraController?.value;
    final screen = MediaQuery.maybeOrientationOf(context)?.name;
    return 'device=${value?.deviceOrientation.name} '
        'sensor=${_viewModel.cameraController?.description.sensorOrientation} '
        'frameRotation=${_viewModel.frameRotation} screen=$screen';
  }

  static String _s(Duration d) =>
      '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';

  /// Leaves the screen with the exercise, once. The camera is released
  /// first: the next screen opens its own camera right away, and this
  /// screen is only disposed after the exit transition.
  Future<void> _finish() async {
    if (_finished || !mounted) return;
    _finished = true;
    await _viewModel.releaseCamera();
    if (mounted) Navigator.pop(context, widget.exercise);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    SystemChrome.setPreferredOrientations(widget.exitOrientations);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SetupViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<SetupViewModel>(
          builder: (context, vm, _) {
            final state = vm.state;
            final running = state.phase == SetupPhase.running;
            final showDebug = widget.showDebugTools && running;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (running)
                  PoseCameraView(
                    controller: vm.cameraController,
                    frame: state.lastFrame,
                    mirror: vm.isFrontCamera,
                    showLandmarks: showDebug,
                    isVisible: vm.isVisible,
                  )
                else
                  _PhaseMessage(viewModel: vm),
                if (running) _ReadyBorder(ready: state.status.isReady),
                SafeArea(
                  child: Column(
                    children: [
                      _TopButtons(
                        canSwitchCamera: running && vm.canSwitchCamera,
                        onSwitchCamera: vm.switchCamera,
                      ),
                      const Spacer(),
                      if (running)
                        _BottomPanel(
                          state: state,
                          autoStartDelay: vm.config.autoStartDelay,
                          onStart: state.canStart ? _finish : null,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReadyBorder extends StatelessWidget {
  const _ReadyBorder({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: ready ? _readyColor : Colors.white24,
            width: ready ? 8 : 2,
          ),
        ),
      ),
    );
  }
}

/// Back and camera switch buttons floating over the preview.
class _TopButtons extends StatelessWidget {
  const _TopButtons({
    required this.canSwitchCamera,
    required this.onSwitchCamera,
  });

  final bool canSwitchCamera;
  final VoidCallback onSwitchCamera;

  @override
  Widget build(BuildContext context) {
    final style = IconButton.styleFrom(backgroundColor: Colors.black45);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back',
            style: style,
            onPressed: () => Navigator.maybePop(context),
          ),
          const Spacer(),
          if (canSwitchCamera)
            IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              tooltip: 'Switch camera',
              style: style,
              onPressed: onSwitchCamera,
            ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.state,
    required this.autoStartDelay,
    required this.onStart,
  });

  final SetupState state;
  final Duration autoStartDelay;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    final left = state.autoStartIn;
    // The bar fills while holding still, then again during the countdown.
    final progress = left == null
        ? status.readyProgress
        : 1 - left.inMicroseconds / autoStartDelay.inMicroseconds;
    return Container(
      width: double.infinity,
      color: Colors.black54,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: status.isReady ? _readyColor : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            color: _readyColor,
            backgroundColor: Colors.white24,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: _readyColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything except the running camera: loading, permission, errors.
class _PhaseMessage extends StatelessWidget {
  const _PhaseMessage({required this.viewModel});

  final SetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final (title, body, actions) = switch (state.phase) {
      SetupPhase.permissionDenied => (
        'Camera access needed',
        'GymRats uses the camera to check that your body is in view. '
            'The video never leaves your phone.'
            '${state.permanentlyDenied ? '\n\nCamera access is turned off. '
                      'Allow it in Settings.' : ''}',
        [
          FilledButton(
            onPressed: viewModel.openSettings,
            child: const Text('Open settings'),
          ),
          if (!state.permanentlyDenied)
            TextButton(
              onPressed: viewModel.retry,
              child: const Text('Try again'),
            ),
        ],
      ),
      SetupPhase.cameraError => (
        'Could not start the camera.',
        state.errorMessage ?? '',
        [FilledButton(onPressed: viewModel.retry, child: const Text('Retry'))],
      ),
      SetupPhase.detectorError => (
        'Pose detection stopped working.',
        state.errorMessage ?? '',
        [FilledButton(onPressed: viewModel.retry, child: const Text('Retry'))],
      ),
      SetupPhase.starting ||
      SetupPhase.paused ||
      SetupPhase.running => (null, null, const <Widget>[]),
    };

    if (title == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Live checker values for manual testing.
