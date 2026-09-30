import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../../support/pose_fixtures.dart';

void main() {
  late Duration now;

  /// No smoothing, so a frame's angle is the angle the state machine sees.
  const fast = RepJudgeConfig(smoothingTau: Duration.zero);

  RepJudge judge({RepJudgeConfig config = fast}) =>
      RepJudge(config: config, clock: () => now);

  setUp(() => now = Duration.zero);

  RepUpdate at(RepJudge c, int ms, PoseFrame frame) {
    now = Duration(milliseconds: ms);
    return c.update(frame);
  }

  PoseFrame pose({
    double elbow = 170,
    double span = 1.2,
    double tilt = 0,
    Set<BodyLandmark> hide = const {},
    bool mirror = false,
  }) {
    final frame = pushUpFrame(
      elbowAngle: elbow,
      spanRatio: span,
      tiltDeg: tilt,
      hide: hide,
    );
    return mirror ? mirrored(frame) : frame;
  }

  /// Holds the top pose long enough to arm the judge.
  void calibrate(RepJudge c, {bool mirror = false, double tilt = 0}) {
    at(c, 0, pose(mirror: mirror, tilt: tilt));
    final ready = at(c, 300, pose(mirror: mirror, tilt: tilt));
    expect(ready.snapshot.phase, RepPhase.up);
    expect(ready.event, isNull);
  }

  /// One full descent and lockout. Returns the frame that closes it.
  RepUpdate perform(
    RepJudge c,
    int start, {
    double bottomElbow = 80,
    double bottomSpan = 0.6,
    double tilt = 0,
    bool mirror = false,
    Set<BodyLandmark> hide = const {},
    int downAt = 400,
    int backAt = 800,
  }) {
    PoseFrame frame({required double elbow, required double span}) =>
        pose(elbow: elbow, span: span, tilt: tilt, mirror: mirror, hide: hide);
    at(c, start, frame(elbow: 120, span: 1.0));
    at(c, start + downAt, frame(elbow: bottomElbow, span: bottomSpan));
    return at(c, start + backAt, frame(elbow: 170, span: 1.2));
  }

  test('a full rep counts once the arms extend again', () {
    final c = judge();
    calibrate(c);
    final update = perform(c, 400);
    expect(update.event, isNotNull);
    expect(update.event!.valid, isTrue);
    expect(update.event!.reason, isNull);
    expect(update.event!.index, 1);
    expect(update.snapshot.phase, RepPhase.up);
  });

  test('ten reps in a row each count', () {
    final c = judge();
    calibrate(c);
    for (var i = 0; i < 10; i++) {
      final update = perform(c, 400 + i * 1000);
      expect(update.event?.valid, isTrue);
      expect(update.event?.index, i + 1);
    }
  });

  test('a shallow rep is rejected for depth', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(elbow: 120, span: 1.05));
    final update = at(c, 800, pose());
    expect(update.event!.valid, isFalse);
    expect(update.event!.reason, RejectReason.insufficientDepth);
    expect(update.event!.reason!.message, 'Go lower');
    expect(update.snapshot.phase, RepPhase.up);
  });

  test('rising and bending again rejects an incomplete lockout', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(elbow: 120, span: 1));
    at(c, 800, pose(elbow: 80, span: 0.6));
    at(c, 1100, pose(elbow: 140, span: 0.9));
    final bounced = at(c, 1300, pose(elbow: 110, span: 0.75));
    expect(bounced.event!.reason, RejectReason.incompleteExtension);
    expect(bounced.snapshot.phase, RepPhase.bottom);

    final locked = at(c, 1700, pose());
    expect(locked.event!.valid, isTrue);
    expect(locked.event!.index, 2);
  });

  test('a tilted shoulder line rejects the rep', () {
    final c = judge();
    calibrate(c);
    final update = perform(c, 400, tilt: 25);
    expect(update.event!.reason, RejectReason.shouldersNotLevel);
  });

  test('a rep faster than 650 ms is rejected', () {
    final c = judge();
    calibrate(c);
    final update = perform(c, 400, downAt: 50, backAt: 100);
    expect(update.event!.reason, RejectReason.tooFast);
  });

  test('noise between the enter and top angles does not count', () {
    final c = judge();
    calibrate(c);
    for (final ms in [400, 500, 600, 700]) {
      final update = at(c, ms, pose(elbow: 150, span: 1.1));
      expect(update.event, isNull);
      expect(update.snapshot.phase, RepPhase.up);
    }
    final descending = at(c, 800, pose(elbow: 130, span: 1));
    expect(descending.snapshot.phase, RepPhase.descending);
    final jitter = at(c, 900, pose(elbow: 150, span: 1));
    expect(jitter.event, isNull);
    expect(jitter.snapshot.phase, RepPhase.descending);
  });

  test('span alone reaches the bottom and counts on lockout', () {
    final c = judge();
    at(c, 0, pose(elbow: 170, span: 1));
    at(c, 300, pose(elbow: 170, span: 1));
    final down = at(c, 400, pose(elbow: 120, span: 0.65));
    expect(down.snapshot.phase, RepPhase.bottom);
    at(c, 800, pose(elbow: 120, span: 0.65));
    final update = at(c, 1200, pose(elbow: 170, span: 1));
    expect(update.event!.valid, isTrue);
  });

  test('losing the arms discards the attempt until the top is held again', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(elbow: 120, span: 1));
    final lost = at(
      c,
      500,
      pose(
        hide: {
          BodyLandmark.leftElbow,
          BodyLandmark.rightElbow,
          BodyLandmark.leftWrist,
          BodyLandmark.rightWrist,
        },
      ),
    );
    expect(lost.event, isNull);
    expect(lost.snapshot.phase, RepPhase.lost);

    final tooSoon = at(c, 600, pose(elbow: 80, span: 0.5));
    expect(tooSoon.event, isNull);
    expect(tooSoon.snapshot.phase, RepPhase.lost);

    at(c, 700, pose());
    expect(at(c, 1000, pose()).snapshot.phase, RepPhase.up);
    expect(perform(c, 1100).event!.valid, isTrue);
  });

  test('a frame gap above 500 ms discards the attempt', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(elbow: 120, span: 1));
    final gap = at(c, 1000, pose(elbow: 80, span: 0.5));
    expect(gap.event, isNull);
    expect(gap.snapshot.phase, RepPhase.lost);
  });

  test('an attempt open for more than 12 s is discarded', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(elbow: 120, span: 1));
    for (var t = 800; t <= 400 + 12000; t += 400) {
      final held = at(c, t, pose(elbow: 80, span: 0.5));
      expect(held.event, isNull);
      expect(held.snapshot.phase, RepPhase.bottom);
    }
    final expired = at(c, 400 + 12400, pose(elbow: 80, span: 0.5));
    expect(expired.event, isNull);
    expect(expired.snapshot.phase, RepPhase.idle);
  });

  test('a mirrored pose counts the same rep', () {
    final c = judge();
    calibrate(c, mirror: true);
    expect(perform(c, 400, mirror: true).event!.valid, isTrue);
  });

  test('one arm is enough to count', () {
    const hide = {BodyLandmark.leftElbow, BodyLandmark.leftWrist};
    final c = judge();
    at(c, 0, pose(hide: hide));
    expect(at(c, 300, pose(hide: hide)).snapshot.phase, RepPhase.up);
    expect(perform(c, 400, hide: hide).event!.valid, isTrue);
  });

  test('reset forgets the rep index and requires a new top pose', () {
    final c = judge();
    calibrate(c);
    expect(perform(c, 400).event!.index, 1);
    c.reset();
    expect(at(c, 2000, pose()).snapshot.phase, RepPhase.idle);
    expect(at(c, 2300, pose()).snapshot.phase, RepPhase.up);
    expect(perform(c, 2400).event!.index, 1);
  });

  test('a one-frame dip does not start a rep while smoothing', () {
    final c = judge(config: const RepJudgeConfig());
    at(c, 0, pose());
    expect(at(c, 300, pose()).snapshot.phase, RepPhase.up);
    final dip = at(c, 316, pose(elbow: 90, span: 0.5));
    expect(dip.event, isNull);
    expect(dip.snapshot.phase, RepPhase.up);
    expect(dip.snapshot.elbowAngle, greaterThan(140));
  });
}
