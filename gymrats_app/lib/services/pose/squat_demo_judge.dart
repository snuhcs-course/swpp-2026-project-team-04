import '../../models/pose_frame.dart';
import '../../models/rep_event.dart';
import 'rep_judge.dart';

import 'package:flutter/foundation.dart';

/// Lenient prototype: one standing → lowered hips → standing cycle.
/// This intentionally does not claim to check squat form or calibrated accuracy.
class SquatDemoJudge extends RepJudge {
  SquatDemoJudge({super.clock}) : _clock = clock ?? _newClock();

  final RepClock _clock;
  RepPhase _phase = RepPhase.idle;
  Duration? _lastAt;
  Duration? _lastLogAt;
  int _index = 1;
  static const _trackingGrace = Duration(milliseconds: 1200);

  static RepClock _newClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  @override
  void reset() {
    _phase = RepPhase.idle;
    _lastAt = null;
    _lastLogAt = null;
    _index = 1;
  }

  @override
  void abandon() {
    _phase = RepPhase.lost;
    _lastAt = null;
  }

  @override
  RepUpdate update(PoseFrame frame) {
    final now = _clock();
    if (_lastAt != null && now - _lastAt! > _trackingGrace) abandon();
    (double, double, double, double)? side(
      BodyLandmark hipId,
      BodyLandmark kneeId,
      BodyLandmark ankleId,
    ) {
      final hip = frame[hipId], knee = frame[kneeId], ankle = frame[ankleId];
      if ([hip, knee, ankle].any(
        (p) =>
            p == null || p.likelihood < config.minLikelihood || !p.y.isFinite,
      )) {
        return null;
      }
      final lowerLeg = ankle!.y - knee!.y;
      if (lowerLeg <= 0) return null;
      return (hip!.y - knee.y, lowerLeg, hip.y, knee.y);
    }

    final sides = [
      side(BodyLandmark.leftHip, BodyLandmark.leftKnee, BodyLandmark.leftAnkle),
      side(
        BodyLandmark.rightHip,
        BodyLandmark.rightKnee,
        BodyLandmark.rightAnkle,
      ),
    ].whereType<(double, double, double, double)>().toList();
    if (sides.isEmpty) {
      _log(now, 'tracking=missing phase=${_phase.name}');
      return const RepUpdate(snapshot: JudgeSnapshot(phase: RepPhase.lost));
    }
    _lastAt = now;
    final gap =
        sides.map((p) => p.$1 / p.$2).reduce((a, b) => a + b) / sides.length;
    // Require distinct standing and seated positions, with a generous margin
    // above the knees at the bottom to accommodate pose-estimation noise.
    final standing = gap <= -.60;
    final bottom = gap >= -.25;
    RepEvent? event;
    if (_phase == RepPhase.idle || _phase == RepPhase.lost) {
      if (standing) _phase = RepPhase.up;
    } else if (_phase == RepPhase.up && bottom) {
      _phase = RepPhase.bottom;
    } else if (_phase == RepPhase.bottom && standing) {
      _phase = RepPhase.up;
      event = RepEvent(index: _index++, valid: true, at: now);
    }
    _log(
      now,
      'phase=${_phase.name} sides=${sides.length} hipKneeGap=${gap.toStringAsFixed(2)} rep=${event?.index ?? "-"}',
    );
    return RepUpdate(
      snapshot: JudgeSnapshot(
        phase: _phase,
        squatHipY:
            sides.map((p) => p.$3).reduce((a, b) => a + b) / sides.length,
        squatKneeY:
            sides.map((p) => p.$4).reduce((a, b) => a + b) / sides.length,
      ),
      event: event,
    );
  }

  void _log(Duration now, String message) {
    if (_lastLogAt != null &&
        now - _lastLogAt! < const Duration(milliseconds: 500)) {
      return;
    }
    _lastLogAt = now;
    debugPrint('squat_demo $message');
  }
}
