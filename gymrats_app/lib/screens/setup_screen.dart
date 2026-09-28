import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercise_type.dart';
import '../models/pose_frame.dart';
import '../services/pose/setup_checker.dart';
import '../viewmodels/setup_viewmodel.dart';

const _readyColor = Colors.greenAccent;

/// Guides phone placement and waits until the body is reliably detected.
///
/// Pops with the selected [ExerciseType] when the user presses Start.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.exercise,
    this.showDebugTools = false,
    this.createViewModel,
  });

  final ExerciseType exercise;

  /// Shows a toggle for the landmark and status debug overlay.
  final bool showDebugTools;

  /// Builds the view model; replaces the default one in tests.
  final SetupViewModel Function()? createViewModel;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  late final SetupViewModel _viewModel;
  bool _debugVisible = true;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        SetupViewModel(exercise: widget.exercise);
    WidgetsBinding.instance.addObserver(this);
    _viewModel.start();
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
    _viewModel.dispose();
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
            final showDebug = widget.showDebugTools && _debugVisible && running;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (running)
                  _CameraView(viewModel: vm, showLandmarks: showDebug)
                else
                  _PhaseMessage(viewModel: vm),
                if (running) _ReadyBorder(ready: state.status.isReady),
                SafeArea(
                  child: Column(
                    children: [
                      _TopBar(
                        guideText: vm.guideText,
                        canSwitchCamera: running && vm.canSwitchCamera,
                        onSwitchCamera: vm.switchCamera,
                        showDebugToggle: widget.showDebugTools,
                        debugVisible: _debugVisible,
                        onToggleDebug: () =>
                            setState(() => _debugVisible = !_debugVisible),
                      ),
                      if (showDebug) _DebugPanel(viewModel: vm),
                      const Spacer(),
                      if (running)
                        _BottomPanel(
                          status: state.status,
                          onStart: state.canStart
                              ? () => Navigator.pop(context, widget.exercise)
                              : null,
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

/// Camera preview filling the screen, with optional landmark dots.
class _CameraView extends StatelessWidget {
  const _CameraView({required this.viewModel, required this.showLandmarks});

  final SetupViewModel viewModel;
  final bool showLandmarks;

  @override
  Widget build(BuildContext context) {
    final controller = viewModel.cameraController;
    final previewSize = controller?.value.previewSize;
    if (controller == null ||
        !controller.value.isInitialized ||
        previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }
    final frame = viewModel.state.lastFrame;
    // previewSize is in landscape; the app is portrait.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(
            controller,
            child: showLandmarks && frame != null
                ? CustomPaint(
                    painter: _LandmarkPainter(
                      frame: frame,
                      mirror: viewModel.isFrontCamera,
                      isVisible: (k) => viewModel.isVisible(k, frame),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Draws detected landmarks: green when visible, red otherwise.
class _LandmarkPainter extends CustomPainter {
  _LandmarkPainter({
    required this.frame,
    required this.mirror,
    required this.isVisible,
  });

  final PoseFrame frame;

  /// The front camera preview is mirrored, ML Kit coordinates are not.
  final bool mirror;
  final bool Function(Keypoint keypoint) isVisible;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / frame.imageWidth;
    final sy = size.height / frame.imageHeight;
    final radius = size.shortestSide / 90;
    final visible = Paint()..color = _readyColor;
    final hidden = Paint()..color = Colors.redAccent;
    for (final k in frame.keypoints.values) {
      final x = k.x * sx;
      canvas.drawCircle(
        Offset(mirror ? size.width - x : x, k.y * sy),
        radius,
        isVisible(k) ? visible : hidden,
      );
    }
  }

  @override
  bool shouldRepaint(_LandmarkPainter old) =>
      old.frame != frame || old.mirror != mirror;
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.guideText,
    required this.canSwitchCamera,
    required this.onSwitchCamera,
    required this.showDebugToggle,
    required this.debugVisible,
    required this.onToggleDebug,
  });

  final String guideText;
  final bool canSwitchCamera;
  final VoidCallback onSwitchCamera;
  final bool showDebugToggle;
  final bool debugVisible;
  final VoidCallback onToggleDebug;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              guideText,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          if (canSwitchCamera)
            IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              tooltip: 'Switch camera',
              onPressed: onSwitchCamera,
            ),
          if (showDebugToggle)
            IconButton(
              icon: Icon(
                Icons.bug_report,
                color: debugVisible ? Colors.amberAccent : Colors.white,
              ),
              tooltip: 'Debug overlay',
              onPressed: onToggleDebug,
            ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.status, required this.onStart});

  final SetupStatus status;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black54,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: status.isReady ? _readyColor : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: status.readyProgress,
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
class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.viewModel});

  final SetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final status = state.status;
    final c = viewModel.config;
    String s(Duration d) => '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
    final held = c.readyDelay * status.readyProgress;
    final lines = [
      'reason: ${status.reason.name}',
      'ready: ${status.isReady}  hold: ${s(held)} / ${s(c.readyDelay)}',
      'fps: ${state.fps}',
      'minLikelihood: ${c.minLikelihood}  margin: ${c.frameMargin * 100}%',
      'body size: ${c.minBodySizeRatio * 100}%-${c.maxBodySizeRatio * 100}%',
      'drop: ${s(c.dropDelay)}  detector timeout: '
          '${s(c.detectorFailureTimeout)}',
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        color: Colors.black87,
        child: Text(
          lines.join('\n'),
          style: const TextStyle(
            color: Colors.amberAccent,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
