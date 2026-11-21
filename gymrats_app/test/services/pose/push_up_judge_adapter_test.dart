import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/pose/exercise_judge.dart';
import 'package:gymrats_app/services/pose/push_up_judge_adapter.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/squat_rep_judge.dart';

const frame = PoseFrame.empty(imageWidth: 640, imageHeight: 480);

GravitySample gravityAt(double degrees) {
  final radians = degrees * math.pi / 180;
  return GravitySample(0, 9.81 * math.sin(radians), 9.81 * math.cos(radians));
}

class RecordingJudge extends RepJudge {
  double? tilt;
  int frames = 0;

  @override
  RepUpdate updateWithPhoneTilt(PoseFrame frame, double? tiltDegrees) {
    tilt = tiltDegrees;
    return super.updateWithPhoneTilt(frame, tiltDegrees);
  }

  @override
  RepUpdate update(PoseFrame frame) {
    frames++;
    return const RepUpdate(snapshot: JudgeSnapshot.initial);
  }
}

void main() {
  test('production push-up factory selects both knee layers with MLP', () {
    final adapter = judgeFor(ExerciseType.pushUp) as PushUpJudgeAdapter;
    expect(
      adapter.judge.useMlp,
      const bool.fromEnvironment('PUSHUP_MLP', defaultValue: true) ||
          const bool.fromEnvironment('PUSHUP_KNEE_FOREST'),
    );
    expect(
      adapter.judge.useFrameKnee,
      const bool.fromEnvironment('PUSHUP_FRAME_KNEE', defaultValue: true),
    );
    expect(
      adapter.judge.retainLegacyKnee,
      const bool.fromEnvironment(
        'PUSHUP_RETAIN_LEGACY_KNEE',
        defaultValue: true,
      ),
    );
    expect(
      adapter.judge.useKneeForest,
      const bool.fromEnvironment('PUSHUP_KNEE_FOREST'),
    );
  });

  test('production squat factory still uses the squat judge', () {
    expect(judgeFor(ExerciseType.squat), isA<SquatRepJudge>());
  });

  test(
    'forwards fresh screen-to-floor tilt from the shared battle monitor',
    () {
      final samples = StreamController<GravitySample>.broadcast(sync: true);
      PhoneTiltMonitor.debugUsePlatformStream(samples.stream);
      final phone = PhoneTiltMonitor.platform()..retain();
      addTearDown(() async {
        phone.release();
        PhoneTiltMonitor.debugUsePlatformStream(null);
        await samples.close();
      });
      samples.add(gravityAt(80)); // The preceding setup screen.
      final judge = RecordingJudge();
      final adapter = PushUpJudgeAdapter(judge);
      adapter.update(frame);
      expect(judge.tilt, isNull);
      samples.add(gravityAt(60));
      adapter.update(frame);
      expect(judge.tilt, closeTo(60, .01));
      adapter.reset();
      adapter.update(frame);
      expect(judge.tilt, isNull);
      samples.add(gravityAt(80));
      adapter.update(frame);
      expect(judge.tilt, closeTo(80, .01));
      adapter.abandon();
      adapter.update(frame);
      expect(judge.tilt, isNull);
      expect(judge.frames, 5); // Preserve injected judges overriding update().
    },
  );

  test('missing, stale, disturbed and invalid gravity use visual judging', () {
    final samples = StreamController<GravitySample>.broadcast(sync: true);
    var now = Duration.zero;
    final phone = PhoneTiltMonitor(samples: samples.stream, clock: () => now)
      ..retain();
    addTearDown(() async {
      phone.release();
      await samples.close();
    });
    final judge = RecordingJudge();
    final adapter = PushUpJudgeAdapter(
      judge,
      phoneTilt: phone,
      clock: () => now,
    );
    adapter.update(frame);
    expect(judge.tilt, isNull);
    samples.add(const GravitySample(0, 0, 0));
    adapter.update(frame);
    expect(judge.tilt, isNull);
    samples.add(const GravitySample(double.nan, 0, 0));
    adapter.update(frame);
    expect(judge.tilt, isNull);
    samples.add(gravityAt(60));
    adapter.update(frame);
    expect(judge.tilt, closeTo(60, .01));
    now += const Duration(milliseconds: 700);
    adapter.update(frame);
    expect(judge.tilt, closeTo(60, .01));
    now += const Duration(milliseconds: 350);
    adapter.update(frame);
    expect(judge.tilt, isNull);
    samples.add(gravityAt(60)); // Arrives before the camera pauses.
    now += const Duration(seconds: 3);
    adapter.update(frame);
    expect(judge.tilt, isNull);
    samples.add(gravityAt(60));
    adapter.update(frame);
    expect(judge.tilt, closeTo(60, .01));
    phone.lock();
    samples.add(gravityAt(80));
    now += placementHold;
    samples.add(gravityAt(80));
    expect(phone.isDisturbed, isTrue);
    adapter.update(frame);
    expect(judge.tilt, isNull);
  });
}
