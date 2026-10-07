import 'dart:async';
import 'dart:collection';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/exercise_type.dart';
import '../models/pose_frame.dart';
import '../services/pose/camera_service.dart';
import '../services/pose/pose_estimator.dart';
import '../services/pose/setup_checker.dart';

/// What the setup screen is doing.
enum SetupPhase {
  /// Asking for permission or opening the camera.
  starting,

  /// Camera running, frames are being checked.
  running,

  /// App is in the background, or the screen is closing; the camera is
  /// released.
  paused,

  /// Camera permission was denied.
  permissionDenied,

  /// No camera, or the camera failed to start.
  cameraError,

  /// Pose detection kept failing.
  detectorError,
}

/// Immutable state rendered by the setup screen.
class SetupState {
  const SetupState({
    this.phase = SetupPhase.starting,
    this.status = SetupStatus.initial,
    this.permanentlyDenied = false,
    this.errorMessage,
    this.lastFrame,
    this.fps = 0,
    this.autoStartIn,
    this.autoStarted = false,
  });

  final SetupPhase phase;

  /// Result of the latest checked frame.
  final SetupStatus status;

  /// Whether the permission can only be granted in system settings.
  final bool permanentlyDenied;

  /// Details for [SetupPhase.cameraError] and [SetupPhase.detectorError].
  final String? errorMessage;

  /// Latest detected pose, for the debug overlay.
  final PoseFrame? lastFrame;

  /// Frames processed during the last second.
  final int fps;

  /// Time left before setup finishes by itself; null unless counting down.
  final Duration? autoStartIn;

  /// The user stayed Ready for [SetupConfig.autoStartDelay]: setup is done
  /// without a tap. The screen leaves as if Start was pressed.
  final bool autoStarted;

  bool get canStart => phase == SetupPhase.running && status.isReady;

  /// Message for the user, including the auto start countdown.
  String get message {
    final left = autoStartIn;
    if (left == null) return status.message;
    final seconds = (left.inMilliseconds / 1000).ceil();
    return 'Ready! Starting in $seconds...';
  }

  /// Copies the state. The auto start countdown is always cleared: it is
  /// only valid for the frame that computed it.
  SetupState copyWith({
    SetupPhase? phase,
    SetupStatus? status,
    bool? permanentlyDenied,
    String? errorMessage,
    PoseFrame? lastFrame,
    int? fps,
  }) => SetupState(
    phase: phase ?? this.phase,
    status: status ?? this.status,
    permanentlyDenied: permanentlyDenied ?? this.permanentlyDenied,
    errorMessage: errorMessage ?? this.errorMessage,
    lastFrame: lastFrame ?? this.lastFrame,
    fps: fps ?? this.fps,
    autoStarted: autoStarted,
  );
}

/// Connects the camera and pose pipeline to [SetupChecker] for the setup
/// screen.
class SetupViewModel extends ChangeNotifier {
  SetupViewModel({
    required this.exercise,
    this.config = const SetupConfig(),
    CameraService? camera,
    PoseEstimator? estimator,
    Clock? clock,
  }) : _camera = camera ?? CameraService(),
       _estimator = estimator ?? PoseEstimator(),
       _clock = clock ?? _stopwatchClock() {
    _checker = SetupChecker(exercise: exercise, config: config, clock: _clock);
  }

  final ExerciseType exercise;
  final SetupConfig config;
  final CameraService _camera;
  final PoseEstimator _estimator;
  final Clock _clock;
  late final SetupChecker _checker;

  SetupState _state = const SetupState();

  /// Incremented whenever the camera stops, so late callbacks are ignored.
  int _session = 0;
  bool _disposed = false;
  bool _released = false;
  bool _pausedByLifecycle = false;
  Duration? _failingSince;
  Duration? _readySince;
  final Queue<Duration> _frameTimes = Queue();

  static Clock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  SetupState get state => _state;

  /// Controller for the camera preview; null while the camera is stopped.
  CameraController? get cameraController =>
      _state.phase == SetupPhase.running ? _camera.controller : null;

  bool get isFrontCamera => _camera.isFrontCamera;

  /// Rotation passed to pose detection for the latest frame, in degrees.
  int get frameRotation => _camera.rotationDegrees;

  bool get canSwitchCamera => _camera.canSwitchCamera;

  /// Whether [keypoint] counts as visible, for the debug overlay.
  bool isVisible(Keypoint keypoint, PoseFrame frame) =>
      _checker.isVisible(keypoint, frame);

  /// Asks for permission if needed, then starts the camera and detection.
  Future<void> start() async {
    if (_disposed || _released) return;
    final session = ++_session;
    _resetTracking();
    _setState(const SetupState());

    final permission = await _camera.requestPermission();
    if (session != _session) return;
    if (permission != CameraPermission.granted) {
      _setState(
        SetupState(
          phase: SetupPhase.permissionDenied,
          permanentlyDenied: permission == CameraPermission.permanentlyDenied,
        ),
      );
      return;
    }

    try {
      await _camera.start((image) => _onImage(image, session));
    } on CameraUnavailableException catch (e) {
      if (session == _session) {
        _setState(
          SetupState(phase: SetupPhase.cameraError, errorMessage: e.message),
        );
      }
      return;
    }
    // Paused, disposed, or restarted while the camera was opening. The
    // newer call queued its own stop or start after this one, so stopping
    // here would close the camera that call opens.
    if (session != _session) return;
    _setState(_state.copyWith(phase: SetupPhase.running));
  }

  /// Tries again after an error.
  Future<void> retry() => start();

  /// Reopens the camera after the screen rotated. The camera plugin reads
  /// the orientation when the camera opens, so a rotation during startup
  /// would leave the preview and the frame rotation 90 degrees off. Does
  /// nothing while paused or showing a permission or error message.
  Future<void> onScreenRotated() async {
    if (_state.phase == SetupPhase.starting ||
        _state.phase == SetupPhase.running) {
      await start();
    }
  }

  /// Opens the system settings so the user can allow the camera.
  Future<void> openSettings() => _camera.openSettings();

  /// Switches between the front and back camera.
  Future<void> switchCamera() async {
    if (!_camera.canSwitchCamera) return;
    _camera.selectNextCamera();
    await start();
  }

  /// App moved to the background: stop the stream and release the camera.
  Future<void> pause() async {
    if (_disposed || _pausedByLifecycle) return;
    _pausedByLifecycle = true;
    _session++;
    _resetTracking();
    // Set before awaiting, so a quick resume() still sees it must restart.
    if (_state.phase == SetupPhase.starting ||
        _state.phase == SetupPhase.running) {
      _setState(const SetupState(phase: SetupPhase.paused));
    }
    await _camera.stop();
  }

  /// Releases the camera before the screen closes, so the next screen can
  /// open it. Unlike [pause], [resume] does not restart it.
  Future<void> releaseCamera() async {
    if (_disposed) return;
    _released = true;
    _session++;
    _resetTracking();
    // Drop the preview before its controller is disposed.
    _setState(const SetupState(phase: SetupPhase.paused));
    await _camera.stop();
  }

  /// App came back: restart if the camera was paused or permission may
  /// have been granted in settings.
  Future<void> resume() async {
    if (_disposed || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    if (_state.phase == SetupPhase.paused ||
        _state.phase == SetupPhase.permissionDenied) {
      await start();
    }
  }

  void _onImage(CameraImage image, int session) {
    // Drop the frame while ML Kit is busy instead of queueing it.
    if (session != _session || _estimator.isBusy) return;
    unawaited(_process(image, session));
  }

  Future<void> _process(CameraImage image, int session) async {
    final PoseFrame? frame;
    try {
      frame = await _estimator.process(image, _camera.rotationDegrees);
    } catch (e) {
      if (session == _session) _onDetectorFailure();
      return;
    }
    if (frame == null || session != _session) return;

    _failingSince = null;
    final now = _clock();
    _frameTimes.addLast(now);
    while (now - _frameTimes.first > const Duration(seconds: 1)) {
      _frameTimes.removeFirst();
    }
    final status = _checker.update(frame);
    final (autoStartIn, autoStarted) = _autoStart(status, now);
    _setState(
      SetupState(
        phase: _state.phase,
        status: status,
        lastFrame: frame,
        fps: _frameTimes.length,
        autoStartIn: autoStartIn,
        autoStarted: autoStarted,
      ),
    );
  }

  /// Counts down [SetupConfig.autoStartDelay] while the user stays Ready.
  /// Leaving Ready cancels the countdown.
  (Duration?, bool) _autoStart(SetupStatus status, Duration now) {
    if (_state.autoStarted) return (null, true);
    if (!status.isReady) {
      _readySince = null;
      return (null, false);
    }
    final left = config.autoStartDelay - (now - (_readySince ??= now));
    return left <= Duration.zero ? (null, true) : (left, false);
  }

  void _onDetectorFailure() {
    final now = _clock();
    final failing = now - (_failingSince ??= now);
    if (failing >= config.detectorFailureTimeout) {
      _session++;
      _resetTracking();
      unawaited(_camera.stop());
      _setState(
        const SetupState(
          phase: SetupPhase.detectorError,
          errorMessage: 'Tap Retry to restart the camera.',
        ),
      );
    } else if (failing >= config.dropDelay) {
      // Frames are being skipped, so the pose is no longer confirmed.
      _checker.reset();
      _readySince = null;
      final s = _state.status;
      _setState(
        _state.copyWith(
          status: SetupStatus(
            reason: s.reason,
            isReady: false,
            readyProgress: 0,
            missingParts: s.missingParts,
          ),
        ),
      );
    }
  }

  void _resetTracking() {
    _checker.reset();
    _failingSince = null;
    _readySince = null;
    _frameTimes.clear();
  }

  void _setState(SetupState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    unawaited(_camera.stop());
    unawaited(_estimator.close());
    super.dispose();
  }
}
