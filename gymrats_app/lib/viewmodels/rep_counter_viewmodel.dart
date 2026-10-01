import 'dart:async';
import 'dart:collection';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/pose_frame.dart';
import '../models/rep_event.dart';
import '../services/pose/camera_service.dart';
import '../services/pose/pose_estimator.dart';
import '../services/pose/rep_judge.dart';

/// What the rep counter is doing with the camera.
enum CounterPhase {
  /// Asking for permission or opening the camera.
  starting,

  /// Camera running, reps are being judged.
  running,

  /// App is in the background; the camera is released.
  paused,

  /// Camera permission was denied.
  permissionDenied,

  /// No camera, or the camera failed to start.
  cameraError,

  /// Pose detection kept failing.
  detectorError,

  /// The round was stopped, or the time limit ran out. The camera is off.
  finished,
}

/// How a finished round ended. [none] while the round is still open.
enum RoundEnd { none, stopped, timeUp }

/// Immutable state rendered by the rep counter.
class RepCounterState {
  const RepCounterState({
    this.phase = CounterPhase.starting,
    this.validReps = 0,
    this.invalidReps = 0,
    this.lastEvent,
    this.snapshot = JudgeSnapshot.initial,
    this.permanentlyDenied = false,
    this.errorMessage,
    this.lastFrame,
    this.fps = 0,
    this.remaining = const Duration(seconds: 60),
    this.roundEnd = RoundEnd.none,
  });

  final CounterPhase phase;
  final int validReps;
  final int invalidReps;

  /// The rep that just closed, if any. Cleared by [RepCounterViewModel.reset].
  final RepEvent? lastEvent;

  final JudgeSnapshot snapshot;
  final bool permanentlyDenied;
  final String? errorMessage;

  /// Latest detected pose, for the debug overlay.
  final PoseFrame? lastFrame;

  /// Frames processed during the last second.
  final int fps;

  /// Time left in the round. Frozen once the round ends.
  final Duration remaining;

  /// Why the round ended. [RoundEnd.none] until then.
  final RoundEnd roundEnd;

  RepCounterState copyWith({
    CounterPhase? phase,
    int? validReps,
    int? invalidReps,
    RepEvent? lastEvent,
    bool clearLastEvent = false,
    JudgeSnapshot? snapshot,
    bool? permanentlyDenied,
    String? errorMessage,
    PoseFrame? lastFrame,
    int? fps,
    Duration? remaining,
    RoundEnd? roundEnd,
  }) => RepCounterState(
    phase: phase ?? this.phase,
    validReps: validReps ?? this.validReps,
    invalidReps: invalidReps ?? this.invalidReps,
    lastEvent: clearLastEvent ? null : lastEvent ?? this.lastEvent,
    snapshot: snapshot ?? this.snapshot,
    permanentlyDenied: permanentlyDenied ?? this.permanentlyDenied,
    errorMessage: errorMessage ?? this.errorMessage,
    lastFrame: lastFrame ?? this.lastFrame,
    fps: fps ?? this.fps,
    remaining: remaining ?? this.remaining,
    roundEnd: roundEnd ?? this.roundEnd,
  );
}

/// Connects the camera and pose pipeline to [RepJudge].
///
/// [reps] emits each judged rep. A battle screen can listen to that stream
/// without owning the camera.
class RepCounterViewModel extends ChangeNotifier {
  RepCounterViewModel({
    CameraService? camera,
    PoseEstimator? estimator,
    RepJudge? judge,
    RepClock? clock,
    this.roundLength = const Duration(seconds: 60),
    this.detectorFailureTimeout = const Duration(seconds: 3),
    this.dropDelay = const Duration(milliseconds: 500),
  }) : _camera = camera ?? CameraService(),
       _estimator = estimator ?? PoseEstimator(),
       _clock = clock ?? _stopwatchClock() {
    // One clock drives both fps and judging, unless a judge is injected.
    _judge = judge ?? RepJudge(clock: _clock);
  }

  final CameraService _camera;
  final PoseEstimator _estimator;
  late final RepJudge _judge;
  final RepClock _clock;

  /// How long a round lasts once the camera is running. Stop ends it sooner.
  final Duration roundLength;

  /// How long pose detection may keep failing before an error is shown.
  final Duration detectorFailureTimeout;

  /// How long detection may fail before the attempt in progress is dropped.
  final Duration dropDelay;

  final StreamController<RepEvent> _reps = StreamController.broadcast();

  RepCounterState _state = const RepCounterState();
  final List<RepEvent> _history = [];
  int _session = 0;
  bool _disposed = false;
  bool _finishing = false;
  bool _pausedByLifecycle = false;
  Duration? _failingSince;
  Duration? _roundStartedAt;
  Duration _pausedAccumulated = Duration.zero;
  Duration? _pauseBegan;
  final Queue<Duration> _frameTimes = Queue();

  static RepClock _stopwatchClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  RepCounterState get state => _state;

  /// Every rep judged in this round, including rejected ones.
  List<RepEvent> get history => List.unmodifiable(_history);

  /// Judged reps, valid and rejected. Does not replay reps from before the
  /// listener subscribed.
  Stream<RepEvent> get reps => _reps.stream;

  /// Controller for the camera preview; null while the camera is stopped.
  CameraController? get cameraController =>
      _state.phase == CounterPhase.running ? _camera.controller : null;

  bool get isFrontCamera => _camera.isFrontCamera;

  /// Rotation passed to pose detection for the latest frame, in degrees.
  int get frameRotation => _camera.rotationDegrees;

  bool get canSwitchCamera => _camera.canSwitchCamera;

  /// Whether [keypoint] is reliable enough to draw as visible.
  bool isVisible(Keypoint keypoint) =>
      keypoint.likelihood >= _judge.config.minLikelihood;

  /// Asks for permission if needed, then starts the camera and judging.
  ///
  /// [keepScore] retains the rep counts, used when the camera is switched.
  Future<void> start({bool keepScore = false}) async {
    if (_disposed || _state.phase == CounterPhase.finished) return;
    final session = ++_session;
    _failingSince = null;
    _frameTimes.clear();
    if (!keepScore) {
      _history.clear();
      _roundStartedAt = null;
      _pausedAccumulated = Duration.zero;
      _pauseBegan = null;
    }
    _setState(
      RepCounterState(
        validReps: keepScore ? _state.validReps : 0,
        invalidReps: keepScore ? _state.invalidReps : 0,
        remaining: keepScore ? _state.remaining : roundLength,
      ),
    );

    final permission = await _camera.requestPermission();
    if (session != _session) return;
    if (permission != CameraPermission.granted) {
      _setState(
        RepCounterState(
          phase: CounterPhase.permissionDenied,
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
          RepCounterState(
            phase: CounterPhase.cameraError,
            errorMessage: e.message,
          ),
        );
      }
      return;
    }
    if (session != _session) return;
    _roundStartedAt ??= _clock();
    _setState(
      _state.copyWith(phase: CounterPhase.running, remaining: _remaining()),
    );
    if (_remaining() == Duration.zero) unawaited(finish());
  }

  /// Tries again after an error.
  Future<void> retry() => start();

  /// Opens the system settings so the user can allow the camera.
  Future<void> openSettings() => _camera.openSettings();

  /// Switches between the front and back camera.
  Future<void> switchCamera() async {
    if (!_camera.canSwitchCamera) return;
    _camera.selectNextCamera();
    _judge.abandon();
    await start(keepScore: true);
  }

  /// Reopens the camera after the screen rotated, keeping the score. The
  /// camera plugin reads the orientation when the camera opens, so the
  /// preview and the frame rotation would otherwise be 90 degrees off. The
  /// rep in progress is dropped. Does nothing while paused or showing a
  /// message.
  Future<void> onScreenRotated() async {
    if (_state.phase != CounterPhase.starting &&
        _state.phase != CounterPhase.running) {
      return;
    }
    _judge.abandon();
    await start(keepScore: true);
  }

  /// Ends the round, releases the camera, and keeps the counts.
  ///
  /// [stoppedByUser] is false when [roundLength] runs out. An in-progress
  /// attempt is dropped and is not added to [history].
  Future<void> finish({bool stoppedByUser = false}) async {
    if (_disposed ||
        _finishing ||
        _state.phase == CounterPhase.finished ||
        _state.phase == CounterPhase.permissionDenied ||
        _state.phase == CounterPhase.cameraError ||
        _state.phase == CounterPhase.detectorError) {
      return;
    }
    _finishing = true;
    _session++;
    _failingSince = null;
    _frameTimes.clear();
    _pauseBegan = null;
    _judge.abandon();
    _setState(
      _state.copyWith(
        phase: CounterPhase.finished,
        roundEnd: stoppedByUser ? RoundEnd.stopped : RoundEnd.timeUp,
        remaining: _remaining(),
        snapshot: JudgeSnapshot.initial,
      ),
    );
    await _camera.stop();
  }

  /// Zeroes the counts and the judge. The camera and the round clock keep running.
  void reset() {
    _judge.reset();
    _history.clear();
    _setState(
      _state.copyWith(
        validReps: 0,
        invalidReps: 0,
        clearLastEvent: true,
        snapshot: JudgeSnapshot.initial,
      ),
    );
  }

  /// App moved to the background: stop the stream and release the camera.
  Future<void> pause() async {
    if (_disposed ||
        _pausedByLifecycle ||
        _state.phase == CounterPhase.finished) {
      return;
    }
    _pausedByLifecycle = true;
    _session++;
    _failingSince = null;
    _frameTimes.clear();
    if (_roundStartedAt != null && _pauseBegan == null) {
      _pauseBegan = _clock();
    }
    if (_state.phase == CounterPhase.starting ||
        _state.phase == CounterPhase.running) {
      _setState(
        _state.copyWith(phase: CounterPhase.paused, remaining: _remaining()),
      );
    }
    await _camera.stop();
  }

  /// App came back: restart if the camera was paused or permission may
  /// have been granted in settings.
  Future<void> resume() async {
    if (_disposed || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    if (_pauseBegan != null) {
      _pausedAccumulated += _clock() - _pauseBegan!;
      _pauseBegan = null;
    }
    if (_roundElapsed() case final elapsed? when elapsed >= roundLength) {
      await finish();
      return;
    }
    if (_state.phase == CounterPhase.paused ||
        _state.phase == CounterPhase.permissionDenied) {
      await start(keepScore: true);
    }
  }

  void _onImage(CameraImage image, int session) {
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
    while (_frameTimes.isNotEmpty &&
        now - _frameTimes.first > const Duration(seconds: 1)) {
      _frameTimes.removeFirst();
    }
    final update = _judge.update(frame);
    final event = update.event;
    if (event != null) {
      _history.add(event);
      if (!_reps.isClosed) _reps.add(event);
    }
    final remaining = _remaining();
    _setState(
      _state.copyWith(
        phase: _state.phase,
        validReps: _state.validReps + (event != null && event.valid ? 1 : 0),
        invalidReps:
            _state.invalidReps + (event != null && !event.valid ? 1 : 0),
        lastEvent: event,
        snapshot: update.snapshot,
        lastFrame: frame,
        fps: _frameTimes.length,
        remaining: remaining,
      ),
    );
    if (remaining == Duration.zero) unawaited(finish());
  }

  void _onDetectorFailure() {
    final now = _clock();
    final failing = now - (_failingSince ??= now);
    if (failing >= detectorFailureTimeout) {
      _session++;
      _failingSince = null;
      _frameTimes.clear();
      _judge.abandon();
      unawaited(_camera.stop());
      _setState(
        _state.copyWith(
          phase: CounterPhase.detectorError,
          errorMessage: 'Tap Retry to restart the camera.',
          snapshot: JudgeSnapshot.initial,
        ),
      );
    } else if (failing >= dropDelay) {
      _judge.abandon();
      _setState(
        _state.copyWith(snapshot: const JudgeSnapshot(phase: RepPhase.lost)),
      );
    }
  }

  Duration? _roundElapsed() {
    final started = _roundStartedAt;
    if (started == null) return null;
    var elapsed = _clock() - started - _pausedAccumulated;
    if (_pauseBegan != null) elapsed -= _clock() - _pauseBegan!;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration _remaining() {
    final elapsed = _roundElapsed();
    if (elapsed == null) return roundLength;
    final left = roundLength - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void _setState(RepCounterState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    unawaited(_reps.close());
    unawaited(_camera.stop());
    unawaited(_estimator.close());
    super.dispose();
  }
}
