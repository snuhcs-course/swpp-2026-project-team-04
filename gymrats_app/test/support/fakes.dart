import 'dart:async';
import 'dart:collection';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/services/device/device_controls.dart';
import 'package:gymrats_app/services/matching/matchmaker.dart';
import 'package:gymrats_app/services/opponent/opponent_source.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/pose_estimator.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/user/user_repository.dart';

import 'pose_fixtures.dart';

class FakeCameraService implements CameraService {
  CameraPermission permission = CameraPermission.granted;
  CameraUnavailableException? startError;
  void Function(CameraImage image)? onImage;
  int startCount = 0;
  int stopCount = 0;
  int switchCount = 0;
  int settingsCount = 0;

  /// When set, stop() waits for it, like a slow controller dispose.
  Completer<void>? stopGate;

  /// When set, start() waits for it, like a slow camera open.
  Completer<void>? startGate;

  // Created on first use, so it belongs to the test's (fake async) zone.
  Future<void>? _lastOperation;

  bool get isStreaming => onImage != null;

  /// Sends one camera frame, like the image stream would.
  void emit() => onImage?.call(fakeCameraImage());

  @override
  CameraLensDirection get preferredLens => CameraLensDirection.front;

  @override
  CameraController? get controller => null;

  @override
  bool get isFrontCamera => true;

  @override
  bool get canSwitchCamera => true;

  @override
  int get rotationDegrees => 270;

  @override
  Future<CameraPermission> requestPermission() async => permission;

  @override
  Future<bool> openSettings() async {
    settingsCount++;
    return true;
  }

  @override
  Future<void> start(void Function(CameraImage image) onImage) =>
      _serialized(() async {
        startCount++;
        this.onImage = null;
        await startGate?.future;
        if (startError != null) throw startError!;
        this.onImage = onImage;
      });

  @override
  void selectNextCamera() => switchCount++;

  @override
  Future<void> stop() => _serialized(() async {
    stopCount++;
    onImage = null;
    await stopGate?.future;
  });

  /// Runs start and stop in call order, like the real CameraService.
  Future<void> _serialized(Future<void> Function() operation) {
    final result = (_lastOperation ?? Future<void>.value()).then(
      (_) => operation(),
    );
    _lastOperation = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}

/// Returns queued frames; a null entry makes ML Kit "fail".
class FakePoseEstimator implements PoseEstimator {
  final Queue<PoseFrame?> frames = Queue();
  int processCount = 0;
  bool closed = false;

  /// When set, process() waits for it, and isBusy is true meanwhile.
  Completer<void>? gate;
  bool _busy = false;

  @override
  bool get isBusy => _busy;

  @override
  Future<PoseFrame?> process(CameraImage image, int rotationDegrees) async {
    processCount++;
    final gate = this.gate;
    if (gate != null) {
      _busy = true;
      await gate.future;
      _busy = false;
    }
    if (frames.isEmpty) return null;
    final frame = frames.removeFirst();
    if (frame == null) throw Exception('ML Kit failed');
    return frame;
  }

  @override
  Future<void> close() async => closed = true;
}

/// Returns [profile], or throws [error] when set, like a server would.
/// Saved battles go to [saved]; [profile] does not change by itself.
class FakeUserRepository implements UserRepository {
  UserProfile profile = const UserProfile(name: '우현');
  Exception? error;
  int fetchCount = 0;

  /// When set, fetchProfile() waits for it, like a slow server.
  Completer<void>? gate;

  /// Battles saved, in order.
  final List<MatchRecord> saved = [];

  /// When set, saveMatch() throws it.
  Exception? saveError;

  @override
  Future<UserProfile> fetchProfile() async {
    fetchCount++;
    await gate?.future;
    if (error != null) throw error!;
    return profile;
  }

  @override
  Future<void> saveMatch(MatchRecord record) async {
    if (saveError != null) throw saveError!;
    saved.add(record);
  }
}

/// Returns [opponent], or throws [error] when set, like a server would.
class FakeMatchmaker implements Matchmaker {
  Opponent opponent = const Opponent(name: 'RepBot', isBot: true);
  Exception? error;

  /// Exercises asked for, in order.
  final List<ExerciseType> requests = [];

  /// When set, findOpponent() waits for it, like a long search.
  Completer<void>? gate;

  @override
  Future<Opponent> findOpponent(ExerciseType exercise) async {
    requests.add(exercise);
    await gate?.future;
    if (error != null) throw error!;
    return opponent;
  }
}

/// Names of the routes pushed or put in place of another, in order.
class PushLog extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      names.add(newRoute?.settings.name);
}

/// Judges nothing itself: each frame closes the next rep queued with
/// [closeRep], if any. Frames still have to come through the camera and
/// estimator fakes.
class FakeRepJudge extends RepJudge {
  final Queue<RepEvent> _verdicts = Queue();
  int _index = 0;

  /// Queues a rep for the next frame: counted, or rejected for [reason].
  void closeRep({RejectReason? reason}) => _verdicts.add(
    RepEvent(
      index: ++_index,
      valid: reason == null,
      reason: reason,
      at: Duration.zero,
    ),
  );

  @override
  RepUpdate update(PoseFrame frame) => RepUpdate(
    snapshot: JudgeSnapshot.initial,
    event: _verdicts.isEmpty ? null : _verdicts.removeFirst(),
  );
}

/// An opponent whose reps the test sends with [emit].
class FakeOpponentSource implements OpponentSource {
  final StreamController<RepEvent> _reps = StreamController.broadcast();
  int startCount = 0;

  /// Whether the round is on: started or resumed, and not paused or stopped.
  bool running = false;
  bool stopped = false;
  bool disposed = false;
  int _index = 0;

  /// Sends one rep: counted, or rejected for [reason].
  void emit({RejectReason? reason}) => _reps.add(
    RepEvent(
      index: ++_index,
      valid: reason == null,
      reason: reason,
      at: Duration.zero,
    ),
  );

  @override
  Stream<RepEvent> get reps => _reps.stream;

  @override
  void start() {
    startCount++;
    running = true;
    stopped = false;
  }

  @override
  void pause() => running = false;

  @override
  void resume() {
    if (startCount > 0 && !stopped) running = true;
  }

  @override
  void stop() {
    running = false;
    stopped = true;
  }

  @override
  void dispose() {
    disposed = true;
    _reps.close();
  }
}

/// Counts the rep sounds instead of playing them.
class FakeRepSound implements RepSound {
  int played = 0;

  @override
  void playRepCounted() => played++;
}
