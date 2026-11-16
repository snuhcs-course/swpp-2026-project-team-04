import 'package:flutter/foundation.dart';

import '../../models/pose_frame.dart';
import '../device/phone_tilt.dart';
import 'exercise_judge.dart';
import 'rep_judge.dart';

class PushUpJudgeAdapter implements ExerciseRepJudge {
  PushUpJudgeAdapter(this.judge, {PhoneTiltMonitor? phoneTilt, RepClock? clock})
    : _phone = phoneTilt ?? PhoneTiltMonitor.platform(),
      _clock = clock ?? _now {
    _forgetTilt();
    assert(() {
      if (judge.useMlp) {
        debugPrint(
          judge.useKneeForest
              ? 'GymRats push-up judge: binary MLP + 5-phase knee forest, ML Kit Accurate.'
              : 'GymRats push-up judge: binary MLP 64/32 + knee MLP 32/16, wide proposals.',
        );
      }
      return true;
    }());
  }

  final RepJudge judge;
  // The counter already owns the platform subscription for both battle modes.
  final PhoneTiltMonitor _phone;
  static const _maxAge = Duration(seconds: 1);
  static final _uptime = Stopwatch()..start();
  static Duration _now() => _uptime.elapsed;

  final RepClock _clock;
  GravitySample? _previous;
  Duration? _sampleAt;
  Duration? _frameAt;

  void _forgetTilt() {
    // A shared monitor may still contain its last sample from the previous
    // round. Wait for the next Android sensor callback before using it.
    _previous = _phone.lastSample;
    _sampleAt = null;
    _frameAt = null;
  }

  double? _freshTilt() {
    final sample = _phone.lastSample;
    if (sample == null) return null;
    final now = _clock();
    final lastFrame = _frameAt;
    // When camera delivery resumes, an unread sensor sample may have
    // arrived at any time during the pause.
    if (lastFrame != null && now - lastFrame >= _maxAge) _forgetTilt();
    _frameAt = now;
    if (!identical(sample, _previous)) {
      _previous = sample;
      _sampleAt = now;
    }
    final sampled = _sampleAt;
    if (sampled == null || now - sampled >= _maxAge || _phone.isDisturbed) {
      return null;
    }
    final gravitySquared =
        sample.x * sample.x + sample.y * sample.y + sample.z * sample.z;
    if (!gravitySquared.isFinite || gravitySquared < 1) return null;
    return _phone.tiltDegrees;
  }

  @override
  RepUpdate update(PoseFrame frame) =>
      judge.updateWithPhoneTilt(frame, _freshTilt());

  @override
  void reset() {
    _forgetTilt();
    judge.reset();
  }

  @override
  void abandon() {
    _forgetTilt();
    judge.abandon();
  }

  @override
  double get minLikelihood => judge.config.minLikelihood;
  @override
  double get passDepth => judge.config.bottomDepth;
}
