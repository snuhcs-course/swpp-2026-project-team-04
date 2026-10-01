import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../../support/pose_fixtures.dart';

void main() {
  late Duration now;

  /// No smoothing, so a frame's value is the value the state machine sees.
  const fast = RepJudgeConfig(smoothingTau: Duration.zero);

  const arms = {
    BodyLandmark.leftElbow,
    BodyLandmark.rightElbow,
    BodyLandmark.leftWrist,
    BodyLandmark.rightWrist,
  };

  RepJudge judge({RepJudgeConfig config = fast}) =>
      RepJudge(config: config, clock: () => now);

  setUp(() => now = Duration.zero);

  RepUpdate at(RepJudge c, int ms, PoseFrame frame) {
    now = Duration(milliseconds: ms);
    return c.update(frame);
  }

  PoseFrame pose({
    double depth = 0,
    double elbow = 170,
    double tilt = 0,
    Set<BodyLandmark> hide = const {},
    bool mirror = false,
  }) {
    final frame = pushUpFrame(
      depth: depth,
      elbowAngle: elbow,
      tiltDeg: tilt,
      hide: hide,
    );
    return mirror ? mirrored(frame) : frame;
  }

  /// Holds extended arms long enough to arm the judge.
  void calibrate(RepJudge c, {bool mirror = false, double tilt = 0}) {
    at(c, 0, pose(mirror: mirror, tilt: tilt));
    final ready = at(c, 300, pose(mirror: mirror, tilt: tilt));
    expect(ready.snapshot.phase, RepPhase.up);
    expect(ready.event, isNull);
  }

  /// One descent and return to the top. Returns the frame that closes it.
  RepUpdate perform(
    RepJudge c,
    int start, {
    double bottom = 1.5,
    double bottomElbow = 150,
    double topElbow = 170,
    double tilt = 0,
    bool mirror = false,
    Set<BodyLandmark> bottomHide = const {},
    int downAt = 400,
    int backAt = 800,
  }) {
    at(c, start, pose(depth: 0.6, elbow: 160, tilt: tilt, mirror: mirror));
    at(
      c,
      start + downAt,
      pose(
        depth: bottom,
        elbow: bottomElbow,
        tilt: tilt,
        mirror: mirror,
        hide: bottomHide,
      ),
    );
    return at(
      c,
      start + backAt,
      pose(elbow: topElbow, tilt: tilt, mirror: mirror),
    );
  }

  test('a full rep counts once the head is back at the top', () {
    final c = judge();
    calibrate(c);
    final update = perform(c, 400);
    expect(update.event, isNotNull);
    expect(update.event!.valid, isTrue);
    expect(update.event!.reason, isNull);
    expect(update.event!.index, 1);
    expect(update.event!.maxDepth, closeTo(1.5, 0.01));
    expect(update.event!.minElbowAngle, closeTo(150, 0.5));
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

  test('elbows that barely bend, as seen from the front, still count', () {
    final c = judge();
    calibrate(c);
    final update = perform(c, 400, bottomElbow: 160, topElbow: 165);
    expect(update.event!.valid, isTrue);
  });

  test('arms hidden at the bottom do not lose the rep', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    final bottom = at(c, 800, pose(depth: 1.5, hide: arms));
    expect(bottom.snapshot.phase, RepPhase.bottom);
    expect(bottom.snapshot.elbowAngle, isNull);
    final update = at(c, 1200, pose());
    expect(update.event!.valid, isTrue);
  });

  test('a rep that stops short of the bottom is rejected for depth', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    at(c, 800, pose(depth: 0.9));
    final update = at(c, 1200, pose());
    expect(update.event!.valid, isFalse);
    expect(update.event!.reason, RejectReason.insufficientDepth);
    expect(update.event!.reason!.message, 'Go lower');
    expect(update.snapshot.phase, RepPhase.up);
  });

  test('a small dip is not a rep at all', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.5));
    final update = at(c, 800, pose());
    expect(update.event, isNull);
    expect(update.snapshot.phase, RepPhase.up);
  });

  test('bent arms at the top wait until they extend', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    at(c, 800, pose(depth: 1.5));
    final bent = at(c, 1200, pose(elbow: 130));
    expect(bent.event, isNull);
    expect(bent.snapshot.phase, RepPhase.bottom);
    final locked = at(c, 1400, pose());
    expect(locked.event!.valid, isTrue);
  });

  test('rising part way and going down again rejects the lockout', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    at(c, 800, pose(depth: 1.5));
    at(c, 1100, pose(depth: 0.5, elbow: 145));
    final bounced = at(c, 1300, pose(depth: 1.0, elbow: 140));
    expect(bounced.event!.reason, RejectReason.incompleteExtension);
    expect(bounced.event!.reason!.message, 'Lock out your arms');
    expect(bounced.snapshot.phase, RepPhase.descending);

    at(c, 1600, pose(depth: 1.5));
    final locked = at(c, 2000, pose());
    expect(locked.event!.valid, isTrue);
    expect(locked.event!.index, 2);
  });

  test('a tilted shoulder line rejects the rep', () {
    final c = judge();
    calibrate(c, tilt: 25);
    final update = perform(c, 400, tilt: 25);
    expect(update.event!.reason, RejectReason.shouldersNotLevel);
  });

  test('a one-frame tilt spike does not reject the rep', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    at(c, 600, pose(depth: 1.5, tilt: 30));
    at(c, 700, pose(depth: 1.5));
    final update = at(c, 900, pose());
    expect(update.event!.valid, isTrue);
  });

  test('a rep faster than 300 ms is rejected', () {
    final c = judge();
    calibrate(c);
    final fastRep = perform(c, 400, downAt: 100, backAt: 299);
    expect(fastRep.event!.reason, RejectReason.tooFast);
    expect(fastRep.event!.reason!.message, 'Slow down');
    expect(perform(c, 800, downAt: 100, backAt: 300).event!.valid, isTrue);
  });

  test('a face missing for a moment keeps the rep', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    final hidden = at(c, 600, pose(depth: 1.2, hide: {BodyLandmark.nose}));
    expect(hidden.event, isNull);
    expect(hidden.snapshot.phase, RepPhase.descending);
    at(c, 800, pose(depth: 1.5));
    expect(at(c, 1200, pose()).event!.valid, isTrue);
  });

  test('a face missing for over 500 ms discards the attempt', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    at(c, 700, pose(depth: 1.5, hide: {BodyLandmark.nose}));
    final lost = at(c, 1000, pose(depth: 1.5, hide: {BodyLandmark.nose}));
    expect(lost.snapshot.phase, RepPhase.lost);

    final back = at(c, 1100, pose(depth: 1.5, elbow: 150));
    expect(back.event, isNull);
    expect(back.snapshot.phase, RepPhase.lost);
    at(c, 1200, pose());
    expect(at(c, 1500, pose()).snapshot.phase, RepPhase.up);
    expect(perform(c, 1600).event!.valid, isTrue);
  });

  test('a frame gap above 500 ms discards the attempt', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    final gap = at(c, 1000, pose(depth: 1.5));
    expect(gap.event, isNull);
    expect(gap.snapshot.phase, RepPhase.lost);
  });

  test('an attempt open for more than 12 s is discarded', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 1.5));
    for (var t = 800; t <= 400 + 12000; t += 400) {
      final held = at(c, t, pose(depth: 1.5, hide: arms));
      expect(held.event, isNull);
      expect(held.snapshot.phase, RepPhase.bottom);
    }
    final expired = at(c, 400 + 12400, pose(depth: 1.5, hide: arms));
    expect(expired.event, isNull);
    expect(expired.snapshot.phase, RepPhase.idle);
  });

  test('a mirrored pose counts the same rep', () {
    final c = judge();
    calibrate(c, mirror: true);
    expect(perform(c, 400, mirror: true).event!.valid, isTrue);
  });

  test('one arm is enough to start counting', () {
    const hide = {BodyLandmark.leftElbow, BodyLandmark.leftWrist};
    final c = judge();
    at(c, 0, pose(hide: hide));
    expect(at(c, 300, pose(hide: hide)).snapshot.phase, RepPhase.up);
    expect(perform(c, 400).event!.valid, isTrue);
  });

  test('counting waits until extended arms are seen', () {
    final c = judge();
    at(c, 0, pose(hide: arms));
    expect(at(c, 400, pose(hide: arms)).snapshot.phase, RepPhase.idle);
    at(c, 500, pose());
    expect(at(c, 800, pose()).snapshot.phase, RepPhase.up);
  });

  test('the top follows the user shifting between reps', () {
    final c = judge();
    calibrate(c);
    var t = 400;
    for (final depth in [0.1, 0.2, 0.3]) {
      expect(at(c, t, pose(depth: depth)).snapshot.phase, RepPhase.up);
      t += 300;
    }
    for (; t <= 3000; t += 300) {
      expect(at(c, t, pose(depth: 0.3)).snapshot.phase, RepPhase.up);
    }
    at(c, t, pose(depth: 0.9));
    at(c, t + 400, pose(depth: 1.8));
    final update = at(c, t + 800, pose(depth: 0.3));
    expect(update.event!.valid, isTrue);
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

  test('the snapshot shows the depth below the top', () {
    final c = judge();
    calibrate(c);
    expect(at(c, 400, pose(depth: 0.6)).snapshot.depth, closeTo(0.6, 0.01));
  });

  test('a one-frame dip does not start a rep while smoothing', () {
    final c = judge(config: const RepJudgeConfig());
    at(c, 0, pose());
    expect(at(c, 300, pose()).snapshot.phase, RepPhase.up);
    final dip = at(c, 310, pose(depth: 1.5));
    expect(dip.event, isNull);
    expect(dip.snapshot.phase, RepPhase.up);
    expect(dip.snapshot.depth, lessThan(0.35));
  });
}
