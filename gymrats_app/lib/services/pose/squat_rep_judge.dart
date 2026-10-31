import 'dart:math' as math;

import '../../models/pose_frame.dart';
import '../../models/rep_event.dart';
import 'exercise_judge.dart';
import 'rep_judge.dart';

/// Experimental frontal squat judge. Depth is relative to the standing thigh.
class SquatRepJudge implements ExerciseRepJudge {
  SquatRepJudge({
    RepClock? clock,
    this.smoothingTau = const Duration(milliseconds: 65),
    this.baselineTau = const Duration(milliseconds: 500),
  }) : _clock = clock ?? _newClock();
  static RepClock _newClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  final RepClock _clock;
  final Duration smoothingTau, baselineTau;
  @override
  double get minLikelihood => .6;
  @override
  double get passDepth => .75;
  RepPhase _phase = RepPhase.idle;
  Duration? _last, _standingSince, _start, _bottomAt;
  double? _top, _smoothedThigh;
  double _max = 0, _lowestAfterBottom = double.infinity;
  int _index = 1;

  @override
  void reset() {
    _index = 1;
    _phase = RepPhase.idle;
    _last = _standingSince = _start = _bottomAt = null;
    _top = _smoothedThigh = null;
    _max = 0;
    _lowestAfterBottom = double.infinity;
  }

  @override
  void abandon() {
    _phase = RepPhase.lost;
    _standingSince = _start = _bottomAt = _last = null;
    _top = _smoothedThigh = null;
    _max = 0;
    _lowestAfterBottom = double.infinity;
  }

  @override
  RepUpdate update(PoseFrame frame) {
    final now = _clock();
    if (_last != null && now - _last! > const Duration(milliseconds: 500)) {
      abandon();
    }
    final measurements = <(double, double)>[];
    for (final (hipId, kneeId, ankleId) in [
      (BodyLandmark.leftHip, BodyLandmark.leftKnee, BodyLandmark.leftAnkle),
      (BodyLandmark.rightHip, BodyLandmark.rightKnee, BodyLandmark.rightAnkle),
    ]) {
      final h = frame[hipId], k = frame[kneeId], a = frame[ankleId];
      if (h == null ||
          k == null ||
          a == null ||
          [h, k, a].any(
            (p) =>
                !p.y.isFinite ||
                !p.likelihood.isFinite ||
                p.likelihood < minLikelihood,
          )) {
        continue;
      }
      final shin = a.y - k.y;
      if (shin > 0) measurements.add((k.y - h.y, shin));
    }
    if (measurements.isEmpty) {
      return RepUpdate(snapshot: JudgeSnapshot(phase: _phase));
    }
    final previousAt = _last;
    _last = now;
    final measuredThigh =
        measurements.map((v) => v.$1).reduce((a, b) => a + b) /
        measurements.length;
    double alpha(Duration tau) => previousAt == null || tau <= Duration.zero
        ? 1
        : 1 - math.exp(-(now - previousAt).inMicroseconds / tau.inMicroseconds);
    _smoothedThigh = _smoothedThigh == null
        ? measuredThigh
        : _smoothedThigh! +
              alpha(smoothingTau) * (measuredThigh - _smoothedThigh!);
    final thigh = _smoothedThigh!;
    final shin =
        measurements.map((v) => v.$2).reduce((a, b) => a + b) /
        measurements.length;
    final standing = thigh >= .7 * shin;
    if (_phase == RepPhase.idle || _phase == RepPhase.lost) {
      if (!standing) {
        _standingSince = null;
      } else {
        _standingSince ??= now;
        if (now - _standingSince! >= const Duration(milliseconds: 300)) {
          _top = thigh;
          _phase = RepPhase.up;
        }
      }
      return RepUpdate(snapshot: JudgeSnapshot(phase: _phase));
    }
    var depth = 1 - thigh / _top!;
    if (_phase == RepPhase.up && depth < .25 && standing) {
      _top = _top! + alpha(baselineTau) * (thigh - _top!);
      depth = 1 - thigh / _top!;
    }
    RepEvent? event;
    if (_start != null && now - _start! > const Duration(seconds: 12)) {
      abandon();
      return RepUpdate(snapshot: JudgeSnapshot(phase: _phase));
    }
    if (_phase == RepPhase.up && depth >= .25) {
      _phase = RepPhase.descending;
      _start = now;
      _max = depth;
      _bottomAt = null;
    }
    if (_phase == RepPhase.descending || _phase == RepPhase.bottom) {
      _max = math.max(_max, depth);
      if (_phase == RepPhase.descending && depth >= passDepth) {
        _phase = RepPhase.bottom;
        _bottomAt = now;
        _lowestAfterBottom = depth;
      }
      if (_phase == RepPhase.bottom) {
        _lowestAfterBottom = math.min(_lowestAfterBottom, depth);
        if (_lowestAfterBottom <= .4 && depth - _lowestAfterBottom >= .3) {
          event = RepEvent(
            index: _index++,
            valid: false,
            reason: RejectReason.standUpFully,
            maxDepth: _max,
            at: now,
          );
          _phase = RepPhase.descending;
          _start = now;
          _max = depth;
          _bottomAt = null;
        }
      }
      if (depth <= .15) {
        if (_start != null &&
            now - _start! >= const Duration(milliseconds: 200) &&
            _max >= .45) {
          final valid = _max >= passDepth;
          event = RepEvent(
            index: _index++,
            valid: valid,
            reason: valid ? null : RejectReason.shallowSquat,
            maxDepth: _max,
            descent: _bottomAt == null ? null : _bottomAt! - _start!,
            at: now,
          );
        }
        _phase = RepPhase.up;
        _start = _bottomAt = null;
        _max = 0;
      }
    }
    return RepUpdate(
      snapshot: JudgeSnapshot(phase: _phase, depth: depth),
      event: event,
    );
  }
}
