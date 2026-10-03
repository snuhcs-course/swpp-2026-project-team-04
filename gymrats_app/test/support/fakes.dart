import 'dart:async';
import 'dart:collection';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/services/matching/matchmaker.dart';
import 'package:gymrats_app/services/pose/camera_service.dart';
import 'package:gymrats_app/services/pose/pose_estimator.dart';
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
class FakeUserRepository implements UserRepository {
  UserProfile profile = const UserProfile(name: '우현');
  Exception? error;
  int fetchCount = 0;

  /// When set, fetchProfile() waits for it, like a slow server.
  Completer<void>? gate;

  @override
  Future<UserProfile> fetchProfile() async {
    fetchCount++;
    await gate?.future;
    if (error != null) throw error!;
    return profile;
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

/// Names of the routes pushed, in order.
class PushLog extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);
}
