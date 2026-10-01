// Standalone demo for checking push-up rep judging on a phone.
//
// Run from gymrats_app/:
//   flutter run -t lib/demo/rep_judge_demo.dart -d <device-id>
//
// Needs no login, server, or battle screen. Setup runs first, then the
// counter. Checker values and each rep are printed to the debug log.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise_type.dart';
import '../screens/setup_screen.dart';
import '../services/pose/rep_judge.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../viewmodels/setup_viewmodel.dart';
import '../widgets/pose_camera_view.dart';

/// Keys the widget tests look up.
const validRepsKey = Key('validReps');
const invalidRepsKey = Key('invalidReps');
const repPhaseKey = Key('repPhase');
const repFlashKey = Key('repFlash');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const RepJudgeDemoApp());
}

class RepJudgeDemoApp extends StatelessWidget {
  const RepJudgeDemoApp({super.key, this.createSetup, this.createCounter});

  /// Builds the setup view model; replaces the default one in tests.
  final SetupViewModel Function(ExerciseType exercise)? createSetup;

  /// Builds the rep counter; replaces the default one in tests.
  final RepCounterViewModel Function()? createCounter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Push-up rep judge',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _ExercisePicker(
        createSetup: createSetup,
        createCounter: createCounter,
      ),
    );
  }
}

class _ExercisePicker extends StatelessWidget {
  const _ExercisePicker({this.createSetup, this.createCounter});

  final SetupViewModel Function(ExerciseType exercise)? createSetup;
  final RepCounterViewModel Function()? createCounter;

  Future<void> _open(BuildContext context, ExerciseType exercise) async {
    final result = await Navigator.push<ExerciseType>(
      context,
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          exercise: exercise,
          showDebugTools: true,
          createViewModel: switch (createSetup) {
            final create? => () => create(exercise),
            null => null,
          },
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _CounterPage(exercise: result, createViewModel: createCounter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push-up rep judge')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose an exercise',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 24),
              for (final exercise in ExerciseType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton(
                    onPressed: () => _open(context, exercise),
                    child: Text(exercise.label),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterPage extends StatefulWidget {
  const _CounterPage({required this.exercise, this.createViewModel});

  final ExerciseType exercise;
  final RepCounterViewModel Function()? createViewModel;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage>
    with WidgetsBindingObserver {
  late final RepCounterViewModel _viewModel;
  Timer? _flashTimer;
  String? _flash;
  bool _flashValid = false;
  final Stopwatch _sinceLog = Stopwatch();
  String? _lastLogKey;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.createViewModel?.call() ?? RepCounterViewModel();
    WidgetsBinding.instance.addObserver(this);
    _viewModel.addListener(_onViewModel);
    _viewModel.start();
  }

  void _onViewModel() {
    final event = _viewModel.state.lastEvent;
    if (event == null || event.at == _shownAt) {
      _log(false);
      return;
    }
    _shownAt = event.at;
    _log(true);
    if (!mounted) return;
    _flashTimer?.cancel();
    setState(() {
      _flash = event.valid ? '+1' : event.reason!.message;
      _flashValid = event.valid;
    });
    _flashTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Duration? _shownAt;

  /// Logs the live judge values when they change, at most every 250 ms.
  void _log(bool freshRep) {
    final state = _viewModel.state;
    if (state.phase != CounterPhase.running) return;
    final snap = state.snapshot;
    final key = '${snap.phase.name} ${state.validReps} ${state.invalidReps}';
    final elapsed = _sinceLog.elapsedMilliseconds;
    final due =
        !_sinceLog.isRunning ||
        elapsed >= 1000 ||
        (key != _lastLogKey && elapsed >= 250);
    if (due) {
      _lastLogKey = key;
      _sinceLog
        ..reset()
        ..start();
      debugPrint(
        'rep_judge | phase=${snap.phase.name} '
        'depth=${_n(snap.depth, 2)} elbow=${_n(snap.elbowAngle)} '
        'tilt=${_n(snap.tilt)} fps=${state.fps} '
        'valid=${state.validReps} invalid=${state.invalidReps}',
      );
    }
    final event = state.lastEvent;
    if (freshRep && event != null) {
      debugPrint(
        'rep_judge rep | #${event.index} '
        'valid=${event.valid} reason=${event.reason?.name ?? '-'} '
        'maxDepth=${_n(event.maxDepth, 2)} '
        'minElbow=${_n(event.minElbowAngle)} maxTilt=${_n(event.maxTilt)}',
      );
    }
  }

  static String _n(double? value, [int digits = 1]) =>
      value?.toStringAsFixed(digits) ?? '-';

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
    _flashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_onViewModel);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;
        final running = state.phase == CounterPhase.running;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (running)
                PoseCameraView(
                  controller: _viewModel.cameraController,
                  frame: state.lastFrame,
                  mirror: _viewModel.isFrontCamera,
                  showLandmarks: true,
                  isVisible: (keypoint, _) => _viewModel.isVisible(keypoint),
                )
              else
                _CounterMessage(viewModel: _viewModel),
              SafeArea(
                child: Column(
                  children: [
                    _CounterTopBar(
                      exercise: widget.exercise,
                      onBack: () => Navigator.maybePop(context),
                      onReset: running ? _viewModel.reset : null,
                      onSwitch: running && _viewModel.canSwitchCamera
                          ? _viewModel.switchCamera
                          : null,
                    ),
                    _Scoreboard(state: state),
                    const Spacer(),
                    if (_flash != null)
                      _Flash(text: _flash!, valid: _flashValid),
                    if (running) _DebugPanel(state: state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.state});

  final RepCounterState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${state.validReps}',
            key: validRepsKey,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 64,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Invalid ${state.invalidReps}',
            key: invalidRepsKey,
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _Flash extends StatelessWidget {
  const _Flash({required this.text, required this.valid});

  final String text;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        key: repFlashKey,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: valid ? Colors.greenAccent : Colors.redAccent,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.state});

  final RepCounterState state;

  @override
  Widget build(BuildContext context) {
    final snap = state.snapshot;
    String n(double? value) => value?.toStringAsFixed(0) ?? '-';
    return Container(
      width: double.infinity,
      color: Colors.black54,
      padding: const EdgeInsets.all(12),
      child: Text(
        '${_phaseLabel(snap.phase)}  '
        'depth ${snap.depth?.toStringAsFixed(2) ?? '-'}  '
        'elbow ${n(snap.elbowAngle)}°  '
        'tilt ${n(snap.tilt)}°  '
        '${state.fps} fps',
        key: repPhaseKey,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

class _CounterTopBar extends StatelessWidget {
  const _CounterTopBar({
    required this.exercise,
    required this.onBack,
    required this.onReset,
    required this.onSwitch,
  });

  final ExerciseType exercise;
  final VoidCallback onBack;
  final VoidCallback? onReset;
  final VoidCallback? onSwitch;

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
            onPressed: onBack,
          ),
          const Spacer(),
          Text(exercise.label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          TextButton(onPressed: onReset, child: const Text('Reset')),
          if (onSwitch != null)
            IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              tooltip: 'Switch camera',
              style: style,
              onPressed: onSwitch,
            ),
        ],
      ),
    );
  }
}

class _CounterMessage extends StatelessWidget {
  const _CounterMessage({required this.viewModel});

  final RepCounterViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final (title, body, actions) = switch (state.phase) {
      CounterPhase.permissionDenied => (
        'Camera access needed',
        state.permanentlyDenied
            ? 'Camera access is turned off. Allow it in Settings.'
            : 'GymRats uses the camera to count push-ups. '
                  'The video never leaves your phone.',
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
      CounterPhase.cameraError => (
        'Could not start the camera.',
        state.errorMessage ?? '',
        [FilledButton(onPressed: viewModel.retry, child: const Text('Retry'))],
      ),
      CounterPhase.detectorError => (
        'Pose detection stopped working.',
        state.errorMessage ?? '',
        [FilledButton(onPressed: viewModel.retry, child: const Text('Retry'))],
      ),
      CounterPhase.starting ||
      CounterPhase.paused ||
      CounterPhase.running => (null, null, const <Widget>[]),
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

String _phaseLabel(RepPhase phase) => switch (phase) {
  RepPhase.idle => 'IDLE',
  RepPhase.up => 'UP',
  RepPhase.descending || RepPhase.bottom => 'DOWN',
  RepPhase.lost => 'LOST',
};
