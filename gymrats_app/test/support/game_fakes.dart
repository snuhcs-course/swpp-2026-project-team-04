import 'dart:async';
import 'dart:collection';

import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/opponent/opponent_source.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

/// A rep of a game test: closed at [seconds], valid unless it has a [reason].
RepEvent gameRep(
  double seconds, {
  double? maxDepth,
  RejectReason? reason,
  double? minElbowAngle,
}) => RepEvent(
  index: 1,
  valid: reason == null,
  reason: reason,
  at: Duration(milliseconds: (seconds * 1000).round()),
  maxDepth: maxDepth,
  minElbowAngle: minElbowAngle,
);

/// A judge whose reps the test queues, with their depth. Its own clock is an
/// hour apart per rep, so a game fed the judge's time instead of round time
/// gets no combo and is always in fever.
class DepthRepJudge extends RepJudge {
  DepthRepJudge({super.config});

  final Queue<RepEvent> _verdicts = Queue();
  int _index = 0;

  /// Queues a rep for the next frame: counted, or rejected for [reason].
  void closeRep({
    double? maxDepth,
    RejectReason? reason,
    double? minElbowAngle,
  }) => _verdicts.add(
    RepEvent(
      index: ++_index,
      valid: reason == null,
      reason: reason,
      at: Duration(hours: _index),
      maxDepth: maxDepth,
      minElbowAngle: minElbowAngle,
    ),
  );

  @override
  RepUpdate update(PoseFrame frame) => RepUpdate(
    snapshot: JudgeSnapshot.initial,
    event: _verdicts.isEmpty ? null : _verdicts.removeFirst(),
  );
}

/// An opponent whose reps the test sends at a round time.
class TimedOpponentSource implements OpponentSource {
  final StreamController<RepEvent> _reps = StreamController.broadcast();
  bool stopped = false;

  /// Sends one rep closed at [seconds].
  void emitAt(double seconds, {double? maxDepth, RejectReason? reason}) =>
      _reps.add(gameRep(seconds, maxDepth: maxDepth, reason: reason));

  @override
  Stream<RepEvent> get reps => _reps.stream;

  @override
  void start() => stopped = false;

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  void stop() => stopped = true;

  @override
  void dispose() => unawaited(_reps.close());
}
