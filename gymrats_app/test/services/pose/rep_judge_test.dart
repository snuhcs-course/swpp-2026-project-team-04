import 'dart:math' as math;

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
    double? shoulderDrop,
    double elbow = 170,
    double tilt = 0,
    Set<BodyLandmark> hide = const {},
    bool mirror = false,
  }) {
    final frame = pushUpFrame(
      depth: depth,
      shoulderDrop: shoulderDrop,
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
    expect(update.event!.descent, const Duration(milliseconds: 400));
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

  test('shoulders hidden at the bottom do not hold the rep up', () {
    final c = judge();
    calibrate(c);
    // The last shoulder drop seen is under the line; the hidden shoulders
    // must not keep it.
    at(c, 400, pose(depth: 0.6, shoulderDrop: 0.3));
    final bottom = at(
      c,
      800,
      pose(
        depth: 1.5,
        hide: {BodyLandmark.leftShoulder, BodyLandmark.rightShoulder},
      ),
    );
    expect(bottom.snapshot.phase, RepPhase.bottom);
    expect(at(c, 1200, pose()).event!.valid, isTrue);
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

  test('a head nod with the shoulders kept up is rejected for depth', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6, shoulderDrop: 0.3));
    final bottom = at(c, 800, pose(depth: 1.6, shoulderDrop: 0.6));
    expect(bottom.snapshot.phase, RepPhase.descending);
    expect(bottom.snapshot.shoulderDrop, closeTo(0.6, 0.01));
    final update = at(c, 1200, pose());
    expect(update.event!.reason, RejectReason.insufficientDepth);
    expect(update.event!.maxDepth, closeTo(1.6, 0.01));
  });

  test('the shoulder line sits at 0.68 shoulder widths', () {
    RepUpdate bottom(double drop) {
      final c = judge();
      calibrate(c);
      at(c, 400, pose(depth: 0.6, shoulderDrop: 0.3));
      return at(c, 800, pose(depth: 1.6, shoulderDrop: drop));
    }

    expect(bottom(0.67).snapshot.phase, RepPhase.descending);
    expect(bottom(0.69).snapshot.phase, RepPhase.bottom);
  });

  test('the shoulders reaching the line complete the bottom', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6, shoulderDrop: 0.3));
    at(c, 800, pose(depth: 1.6, shoulderDrop: 0.6));
    final bottom = at(c, 900, pose(depth: 1.6, shoulderDrop: 0.7));
    expect(bottom.snapshot.phase, RepPhase.bottom);
    expect(at(c, 1300, pose()).event!.valid, isTrue);
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

  test('a fast descent still counts and keeps how long it took', () {
    final c = judge();
    calibrate(c);
    final fastRep = perform(c, 400, downAt: 100, backAt: 299);
    expect(fastRep.event!.valid, isTrue);
    expect(fastRep.event!.reason, isNull);
    expect(fastRep.event!.descent, const Duration(milliseconds: 100));
  });

  test('a return to the top within 100 ms is dropped', () {
    final c = judge();
    calibrate(c);
    final noise = perform(c, 400, downAt: 40, backAt: 90);
    expect(noise.event, isNull);
    expect(noise.snapshot.phase, RepPhase.up);
    expect(perform(c, 800).event!.index, 1);
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

  group('cheats, judged only when seen', () {
    // Shoulders of pushUpFrame are at y = 400, 200 px apart.
    const leftX = 400.0;
    const rightX = 600.0;

    /// Wrist height of pushUpFrame at [depth]: 640 at the top, and the arms
    /// drop with the shoulders.
    double wristY(double depth) => 640 + 0.6 * depth * pushUpShoulderWidth;

    /// pushUpFrame keeps the arms 1.2 shoulder widths long at every depth,
    /// so its plank hips, a few pixels below the shoulders, end up far above
    /// the hands at the bottom, as the hips of a kneeling bow do. Tests of
    /// the other lower-body rules, counting or rejecting, turn the bow check
    /// off so they can only pass through their own rule.
    const noBow = RepJudgeConfig(
      smoothingTau: Duration.zero,
      bowHipHandGap: double.negativeInfinity,
      bowHipRise: double.negativeInfinity,
    );

    /// Only the hip rise of the two bow checks.
    const riseOnly = RepJudgeConfig(
      smoothingTau: Duration.zero,
      bowHipHandGap: double.negativeInfinity,
    );

    /// A rep whose hips sit at [hipY] for each head depth, with knees at
    /// [knee] offsets from the hips when given.
    RepUpdate repWithHips(
      RepJudge c,
      double Function(double depth) hipY, {
      (double, double)? knee,
      bool hipsAtBottom = true,
      bool bendArms = true,
    }) {
      PoseFrame frame(double depth, {bool showHips = true}) {
        final y = hipY(depth);
        return pushUpFrame(
          depth: depth,
          elbowAngle: bendArms && depth >= 0.8 ? 120 : 170,
          lowerBody: showHips
              ? {
                  BodyLandmark.leftHip: (leftX, y),
                  BodyLandmark.rightHip: (rightX, y),
                  if (knee != null) ...{
                    BodyLandmark.leftKnee: (leftX + knee.$1, y + knee.$2),
                    BodyLandmark.rightKnee: (rightX - knee.$1, y + knee.$2),
                  },
                }
              : const {},
        );
      }

      at(c, 0, frame(0));
      at(c, 300, frame(0));
      at(c, 400, frame(0.6));
      at(c, 600, frame(1.2, showHips: hipsAtBottom));
      at(c, 700, frame(1.4, showHips: hipsAtBottom));
      at(c, 800, frame(1.5, showHips: hipsAtBottom));
      at(c, 1000, frame(0.6));
      return at(c, 1200, frame(0));
    }

    test('a plank whose hips follow the head counts', () {
      final update = repWithHips(
        judge(config: noBow),
        (d) => 430 + 0.5 * d * 200,
      );
      expect(update.event!.valid, isTrue);
    });

    test('hips that stay up are not called a belly push-up', () {
      // The hips never come down to the hands. From the front they also
      // barely move, which used to be misread as the belly on the floor.
      final update = repWithHips(judge(config: noBow), (_) => 430);
      expect(update.event!.valid, isTrue);
    });

    test('hips sat back over the heels at the bottom are a kneeling bow', () {
      // A plank top (hips 1.05 shoulder widths below the shoulders) whose
      // hips stay put while the head goes down: 0.15 widths below the
      // shoulders and 1.05 above the hands at the bottom. The arms lock out.
      final update = repWithHips(judge(), (_) => 610);
      expect(update.event!.reason, RejectReason.kneesDown);
    });

    test('hips that sink less than the shoulders are not a bow', () {
      // Torso drop 1.05 at the top and 0.45 at the bottom, as on the
      // recorded normal reps: past bowTorsoDrop, so the rep counts.
      final update = repWithHips(judge(), (d) => 610 + 0.2 * d * 200);
      expect(update.event!.valid, isTrue);
    });

    test('a bow with the hips hidden at the bottom is not judged as one', () {
      final update = repWithHips(judge(), (_) => 610, hipsAtBottom: false);
      expect(update.event!.valid, isTrue);
    });

    /// A straight-arm top frame whose ankles sit [shin] shoulder widths
    /// from the knees, far behind the hands, at [depth].
    PoseFrame shinFrame(double shin, {double depth = 0}) => pushUpFrame(
      depth: depth,
      elbowAngle: depth >= 0.8 ? 120 : 170,
      lowerBody: {
        BodyLandmark.leftKnee: (leftX, 450),
        BodyLandmark.rightKnee: (rightX, 450),
        BodyLandmark.leftAnkle: (leftX, 450 + shin * 200),
        BodyLandmark.rightAnkle: (rightX, 450 + shin * 200),
      },
    );

    RepUpdate shinRep(RepJudge c, List<double> topShins) {
      at(c, 0, shinFrame(topShins.first));
      at(c, 300, shinFrame(topShins.first));
      var t = 300;
      for (final shin in topShins) {
        t += 40;
        at(c, t, shinFrame(shin));
      }
      at(c, t + 200, shinFrame(0, depth: 0.6));
      at(c, t + 500, shinFrame(0, depth: 1.5));
      return at(c, t + 900, shinFrame(0));
    }

    test('shins lifted at the top are a knee push-up', () {
      final update = shinRep(judge(), List.filled(10, -0.3));
      expect(update.event!.reason, RejectReason.kneesDown);
    });

    test('straight legs at the top count', () {
      final update = shinRep(judge(), List.filled(10, -0.1));
      expect(update.event!.valid, isTrue);
    });

    test('shins lifted only while moving before the plank still count', () {
      // Walking back from the phone lifts the shins; the last ten top
      // frames before the descent are a flat plank.
      final update = shinRep(judge(), [
        ...List.filled(10, -0.5),
        ...List.filled(10, -0.1),
      ]);
      expect(update.event!.valid, isTrue);
    });

    test('hidden ankles leave the rep alone', () {
      final c = judge();
      PoseFrame frame({double depth = 0}) => pushUpFrame(
        depth: depth,
        elbowAngle: depth >= 0.8 ? 120 : 170,
        hide: {BodyLandmark.leftAnkle, BodyLandmark.rightAnkle},
        lowerBody: {
          BodyLandmark.leftKnee: (leftX, 450),
          BodyLandmark.rightKnee: (rightX, 450),
        },
      );
      at(c, 0, frame());
      at(c, 300, frame());
      at(c, 400, frame());
      at(c, 600, frame(depth: 0.6));
      at(c, 900, frame(depth: 1.5));
      expect(at(c, 1300, frame()).event!.valid, isTrue);
    });

    test('a few lifted frames are not enough', () {
      // Two of the last ten top frames read lifted: under minCheatFrames.
      final update = shinRep(judge(), [
        ...List.filled(8, -0.1),
        ...List.filled(2, -0.3),
      ]);
      expect(update.event!.valid, isTrue);
    });

    test('half of the last top frames lifted are a knee push-up', () {
      final half = shinRep(judge(), [
        ...List.filled(5, -0.1),
        ...List.filled(5, -0.3),
      ]);
      expect(half.event!.reason, RejectReason.kneesDown);
      final fewer = shinRep(judge(), [
        ...List.filled(6, -0.1),
        ...List.filled(4, -0.3),
      ]);
      expect(fewer.event!.valid, isTrue);
    });

    test('ankles hidden in the last plank frames drop older lifted ones', () {
      final c = judge();
      PoseFrame hidden({double depth = 0}) => pushUpFrame(
        depth: depth,
        elbowAngle: depth >= 0.8 ? 120 : 170,
        hide: {BodyLandmark.leftAnkle, BodyLandmark.rightAnkle},
        lowerBody: {
          BodyLandmark.leftKnee: (leftX, 450),
          BodyLandmark.rightKnee: (rightX, 450),
        },
      );
      at(c, 0, shinFrame(-0.5));
      at(c, 300, shinFrame(-0.5));
      var t = 300;
      for (var i = 0; i < 10; i++) {
        at(c, t += 40, shinFrame(-0.5));
      }
      for (var i = 0; i < 10; i++) {
        at(c, t += 40, hidden());
      }
      at(c, t + 200, hidden(depth: 0.6));
      at(c, t + 500, hidden(depth: 1.5));
      expect(at(c, t + 900, hidden()).event!.valid, isTrue);
    });

    test('a missed lockout keeps the lifted shins for the next try', () {
      final c = judge();
      at(c, 0, shinFrame(-0.3));
      at(c, 300, shinFrame(-0.3));
      var t = 300;
      for (var i = 0; i < 10; i++) {
        at(c, t += 40, shinFrame(-0.3));
      }
      at(c, t + 200, shinFrame(0, depth: 0.6));
      at(c, t + 500, shinFrame(0, depth: 1.5));
      at(c, t + 800, shinFrame(0, depth: 0.5));
      final missed = at(c, t + 1100, shinFrame(0, depth: 1.0));
      expect(missed.event!.reason, RejectReason.kneesDown);
      at(c, t + 1400, shinFrame(0, depth: 1.5));
      final next = at(c, t + 1800, shinFrame(0));
      expect(next.event!.reason, RejectReason.kneesDown);
    });

    test('a small torso drop with the hips near the hands is not a bow', () {
      // Hips 0.15 shoulder widths below the shoulders at the bottom, as in
      // a bow, but only 0.5 above the hands: the gap side keeps it a plank.
      final c = judge();
      PoseFrame frame(double depth) => pushUpFrame(
        depth: depth,
        elbowAngle: depth >= 0.8 ? 120 : 170,
        lowerBody: {
          BodyLandmark.leftHip: (leftX, 610),
          BodyLandmark.rightHip: (rightX, 610),
          if (depth >= 0.8) ...{
            BodyLandmark.leftWrist: (leftX, 710),
            BodyLandmark.rightWrist: (rightX, 710),
          },
        },
      );
      at(c, 0, frame(0));
      at(c, 300, frame(0));
      at(c, 400, frame(0.6));
      at(c, 600, frame(1.2));
      at(c, 800, frame(1.5));
      at(c, 1000, frame(0.6));
      expect(at(c, 1200, frame(0)).event!.valid, isTrue);
    });

    /// A rep held at the top for four frames with the hips at 610 (0.15
    /// shoulder widths above the hands), whose hips sit at [bottomHip] at
    /// the deepest frame.
    PoseFrame hipAt(double depth, double hipY) => pushUpFrame(
      depth: depth,
      elbowAngle: depth >= 0.8 ? 120 : 170,
      lowerBody: {
        BodyLandmark.leftHip: (leftX, hipY),
        BodyLandmark.rightHip: (rightX, hipY),
      },
    );

    RepUpdate hipRep(RepJudge c, double bottomHip) {
      for (final t in [0, 300, 340, 380]) {
        at(c, t, hipAt(0, 610));
      }
      at(c, 500, hipAt(0.6, 610));
      at(c, 800, hipAt(1.5, bottomHip));
      at(c, 1000, hipAt(0.6, 610));
      return at(c, 1200, hipAt(0, 610));
    }

    test('hips rising toward the head from the top are a kneeling bow', () {
      // Bottom: hips 1.65 shoulder widths above the hands, a rise of 1.5.
      final update = hipRep(judge(config: riseOnly), 490);
      expect(update.event!.reason, RejectReason.kneesDown);
    });

    test('hips that stay put while the hands drop are not a rise', () {
      // The hands drop 0.9 shoulder widths with the shoulders; the hips
      // stay: a rise of only -0.9.
      final update = hipRep(judge(config: riseOnly), 610);
      expect(update.event!.valid, isTrue);
    });

    test('a rise needs three top frames with the hips seen', () {
      // Two top frames only: no top reading, so the rise cannot reject.
      final c = judge(config: riseOnly);
      at(c, 0, hipAt(0, 610));
      at(c, 300, hipAt(0, 610));
      at(c, 340, hipAt(0, 610));
      at(c, 500, hipAt(0.6, 610));
      at(c, 800, hipAt(1.5, 490));
      at(c, 1000, hipAt(0.6, 610));
      expect(at(c, 1200, hipAt(0, 610)).event!.valid, isTrue);
    });

    test('a missed lockout keeps the top hips for the next try', () {
      final c = judge(config: riseOnly);
      for (final t in [0, 300, 340, 380]) {
        at(c, t, hipAt(0, 610));
      }
      at(c, 500, hipAt(0.6, 610));
      at(c, 800, hipAt(1.5, 610));
      at(c, 1100, hipAt(0.5, 610));
      final missed = at(c, 1400, hipAt(1.0, 610));
      expect(missed.event!.reason, RejectReason.incompleteExtension);
      at(c, 1700, hipAt(1.5, 490));
      final next = at(c, 2100, hipAt(0, 610));
      expect(next.event!.reason, RejectReason.kneesDown);
    });

    test('hips that drop to the hands are a belly push-up', () {
      // The torso sags 1.2 shoulder widths, past minBellyTorsoDrop.
      final update = repWithHips(judge(), wristY);
      expect(update.event!.reason, RejectReason.bellyDown);
      expect(update.event!.reason!.message, 'Hips up');
    });

    test('knees next to the hands are a knee push-up', () {
      // Open hip angle, so only the knee sitting by the wrists gives it away.
      final update = repWithHips(
        judge(),
        (d) => wristY(d) - 140,
        knee: (0, 140),
      );
      expect(update.event!.reason, RejectReason.kneesDown);
    });

    test('knees almost at the hands are a knee push-up', () {
      // gap = -30 / 200 = -0.15. The hip angle stays open.
      final update = repWithHips(
        judge(),
        (d) => wristY(d) - 140,
        knee: (0, 110),
      );
      expect(update.event!.reason, RejectReason.kneesDown);
    });

    test('knees at a plank distance behind the hands still count', () {
      // gap = -80 / 200 = -0.40, where a real plank's knees sat.
      final update = repWithHips(
        judge(),
        (d) => wristY(d) - 140,
        knee: (0, 60),
      );
      expect(update.event!.valid, isTrue);
    });

    test('a belly on the floor is not called knees', () {
      // The knees also sit by the hands; the sagging torso decides.
      final update = repWithHips(judge(), wristY, knee: (0, 0));
      expect(update.event!.reason, RejectReason.bellyDown);
    });

    test('the belly band starts 0.08 shoulder widths above the hands', () {
      // Longer arms keep the torso drop between the belly line (1.1) and
      // an upright body (1.2) for both: 1.25 + gap.
      RepUpdate run(double gap) {
        final c = judge();
        PoseFrame frame(double depth) {
          final y = 400 + 0.6 * depth * 200 + (1.25 + gap) * 200;
          return pushUpFrame(
            depth: depth,
            spanRatio: 1.25,
            elbowAngle: depth >= 0.8 ? 120 : 170,
            lowerBody: {
              BodyLandmark.leftHip: (leftX, y),
              BodyLandmark.rightHip: (rightX, y),
            },
          );
        }

        at(c, 0, frame(0));
        at(c, 300, frame(0));
        at(c, 400, frame(0.6));
        at(c, 600, frame(1.2));
        at(c, 700, frame(1.4));
        at(c, 800, frame(1.5));
        at(c, 1000, frame(0.6));
        return at(c, 1200, frame(0));
      }

      expect(run(-0.07).event!.reason, RejectReason.bellyDown);
      expect(run(-0.09).event!.valid, isTrue);
    });

    test('a belly rep does not carry its torso sag to the next rep', () {
      final c = judge();
      PoseFrame frame(double depth, {required bool belly}) {
        final y = belly ? wristY(depth) : 430 + 0.6 * depth * 200;
        return pushUpFrame(
          depth: depth,
          elbowAngle: depth >= 0.8 ? 120 : 170,
          lowerBody: {
            BodyLandmark.leftHip: (leftX, y),
            BodyLandmark.rightHip: (rightX, y),
          },
        );
      }

      void rep(int start, {required bool belly}) {
        at(c, start, frame(0.6, belly: belly));
        at(c, start + 200, frame(1.2, belly: belly));
        at(c, start + 300, frame(1.4, belly: belly));
        at(c, start + 400, frame(1.5, belly: belly));
        at(c, start + 600, frame(0.6, belly: belly));
      }

      at(c, 0, frame(0, belly: false));
      at(c, 300, frame(0, belly: false));
      rep(400, belly: true);
      final belly = at(c, 1200, frame(0, belly: false));
      expect(belly.event!.reason, RejectReason.bellyDown);
      // Hips only at the hands, no sag: the torso peak was not kept.
      at(c, 1500, frame(0, belly: false));
      at(c, 1700, frame(0.6, belly: false));
      PoseFrame atHands(double depth) => pushUpFrame(
        depth: depth,
        spanRatio: 0.9,
        elbowAngle: depth >= 0.8 ? 120 : 170,
        lowerBody: {
          BodyLandmark.leftHip: (leftX, 400 + 0.6 * depth * 200 + 180),
          BodyLandmark.rightHip: (rightX, 400 + 0.6 * depth * 200 + 180),
        },
      );
      at(c, 1900, atHands(1.2));
      at(c, 2000, atHands(1.4));
      at(c, 2100, atHands(1.5));
      at(c, 2300, frame(0.6, belly: false));
      final next = at(c, 2500, frame(0, belly: false));
      expect(next.event!.valid, isTrue);
    });

    test('hips at the hands without a sagging torso are not a belly', () {
      // Short arms: the hips reach the hands with a torso drop of 0.9.
      final c = judge();
      PoseFrame frame(double depth) {
        final y = 400 + 0.6 * depth * 200 + 0.9 * 200;
        return pushUpFrame(
          depth: depth,
          spanRatio: 0.9,
          elbowAngle: depth >= 0.8 ? 120 : 170,
          lowerBody: {
            BodyLandmark.leftHip: (leftX, y),
            BodyLandmark.rightHip: (rightX, y),
          },
        );
      }

      at(c, 0, frame(0));
      at(c, 300, frame(0));
      at(c, 400, frame(0.6));
      at(c, 600, frame(1.2));
      at(c, 700, frame(1.4));
      at(c, 800, frame(1.5));
      at(c, 1000, frame(0.6));
      expect(at(c, 1200, frame(0)).event!.valid, isTrue);
    });

    test('straight arms with the knees by the hands are not a push-up', () {
      final update = repWithHips(
        judge(),
        (d) => wristY(d) - 140,
        knee: (0, 140),
        bendArms: false,
      );
      expect(update.event!.reason, RejectReason.armsStraight);
    });

    test('a shallow knee push-up is still too shallow', () {
      final c = judge();
      PoseFrame frame(double depth) => pushUpFrame(
        depth: depth,
        lowerBody: {
          BodyLandmark.leftHip: (leftX, 500),
          BodyLandmark.rightHip: (rightX, 500),
          BodyLandmark.leftKnee: (leftX, 640),
          BodyLandmark.rightKnee: (rightX, 640),
        },
      );
      at(c, 0, frame(0));
      at(c, 300, frame(0));
      at(c, 500, frame(0.6));
      at(c, 800, frame(0.9));
      final update = at(c, 1200, frame(0));
      expect(update.event!.reason, RejectReason.insufficientDepth);
    });

    test('an upright body is a wall push-up', () {
      final update = repWithHips(judge(), (d) => 840 + 0.5 * d * 200);
      expect(update.event!.reason, RejectReason.notFloorPushUp);
      expect(update.event!.reason!.message, 'Floor push-up');
    });

    test('knees bent under the hips are a knee push-up', () {
      final update = repWithHips(
        judge(config: noBow),
        (d) => 430 + 0.5 * d * 200,
        knee: (80, 10),
      );
      expect(update.event!.reason, RejectReason.kneesDown);
      expect(update.event!.reason!.message, 'Knees up');
    });

    test('knees folded at the top stay folded after the angle opens', () {
      final c = judge(config: noBow);
      PoseFrame frame(double depth, {required bool bent}) {
        final y = 430 + 0.5 * depth * 200;
        final kneeY = bent ? y + 10 : y + 80;
        final kneeX = bent ? 80.0 : 0.0;
        return pushUpFrame(
          depth: depth,
          elbowAngle: depth >= 0.8 ? 120 : 170,
          lowerBody: {
            BodyLandmark.leftHip: (leftX, y),
            BodyLandmark.rightHip: (rightX, y),
            BodyLandmark.leftKnee: (leftX + kneeX, kneeY),
            BodyLandmark.rightKnee: (rightX - kneeX, kneeY),
          },
        );
      }

      at(c, 0, frame(0, bent: true));
      at(c, 200, frame(0, bent: true));
      at(c, 300, frame(0, bent: true));
      at(c, 500, frame(0.6, bent: false));
      at(c, 800, frame(1.4, bent: false));
      final update = at(c, 1200, frame(0, bent: false));
      expect(update.event!.reason, RejectReason.kneesDown);
    });

    test('a deep rep with straight arms is not a push-up', () {
      final update = repWithHips(
        judge(config: noBow),
        (d) => 430 + 0.5 * d * 200,
        knee: (80, 10),
        bendArms: false,
      );
      expect(update.event!.reason, RejectReason.armsStraight);
    });

    test('bent knees with a straight frame between them still count', () {
      final c = judge(config: noBow);
      PoseFrame frame(double depth, {required bool bent}) {
        final y = 430 + 0.5 * depth * 200;
        // An extended knee stays below the hip. A bent one folds, but not
        // for three frames in a row, so the latch never sets.
        final kneeY = bent ? y + 10 : y + 120;
        final kneeX = bent ? 80.0 : 0.0;
        return pushUpFrame(
          depth: depth,
          lowerBody: {
            BodyLandmark.leftHip: (leftX, y),
            BodyLandmark.rightHip: (rightX, y),
            BodyLandmark.leftKnee: (leftX + kneeX, kneeY),
            BodyLandmark.rightKnee: (rightX - kneeX, kneeY),
          },
        );
      }

      at(c, 0, frame(0, bent: false));
      at(c, 300, frame(0, bent: false));
      at(c, 400, frame(0.6, bent: true));
      at(c, 550, frame(0.9, bent: false));
      at(c, 700, frame(1.2, bent: true));
      at(c, 850, frame(1.4, bent: false));
      at(c, 1000, frame(1.3, bent: true));
      final update = at(c, 1300, frame(0, bent: false));
      expect(update.event!.valid, isTrue);
    });

    test('the optional hip angle rule needs the fold in a row', () {
      // The same bent, straight, bent pattern with the rule turned on.
      final c = judge(
        config: const RepJudgeConfig(
          smoothingTau: Duration.zero,
          kneeBentAngle: 110,
          bowHipHandGap: double.negativeInfinity,
        ),
      );
      PoseFrame frame(double depth, {required bool bent}) {
        final y = 430 + 0.6 * depth * 200;
        final kneeY = bent ? y + 10 : y + 120;
        final kneeX = bent ? 80.0 : 0.0;
        return pushUpFrame(
          depth: depth,
          elbowAngle: depth >= 0.8 ? 120 : 170,
          lowerBody: {
            BodyLandmark.leftHip: (leftX, y),
            BodyLandmark.rightHip: (rightX, y),
            BodyLandmark.leftKnee: (leftX + kneeX, kneeY),
            BodyLandmark.rightKnee: (rightX - kneeX, kneeY),
          },
        );
      }

      at(c, 0, frame(0, bent: false));
      at(c, 300, frame(0, bent: false));
      at(c, 400, frame(0.6, bent: true));
      at(c, 550, frame(0.9, bent: false));
      at(c, 700, frame(1.2, bent: true));
      at(c, 850, frame(1.4, bent: false));
      at(c, 1000, frame(1.3, bent: true));
      expect(at(c, 1300, frame(0, bent: false)).event!.valid, isTrue);

      // Three folded frames in a row in the attempt latch it.
      at(c, 1700, frame(0.6, bent: false));
      at(c, 1850, frame(1.2, bent: true));
      at(c, 2000, frame(1.4, bent: true));
      at(c, 2100, frame(1.5, bent: true));
      final knees = at(c, 2400, frame(0, bent: false));
      expect(knees.event!.reason, RejectReason.kneesDown);
    });

    test('a straight body with the knees far behind the hands counts', () {
      final c = judge(config: noBow);
      PoseFrame frame(double depth) {
        final y = 430 + 0.5 * depth * 200;
        return pushUpFrame(
          depth: depth,
          elbowAngle: depth >= 0.8 ? 120 : 170,
          lowerBody: {
            BodyLandmark.leftHip: (leftX, y),
            BodyLandmark.rightHip: (rightX, y),
            BodyLandmark.leftKnee: (leftX, 450),
            BodyLandmark.rightKnee: (rightX, 450),
          },
        );
      }

      at(c, 0, frame(0));
      at(c, 300, frame(0));
      at(c, 400, frame(0.6));
      at(c, 800, frame(1.5));
      final update = at(c, 1200, frame(0));
      expect(update.event!.valid, isTrue);
    });

    test('a hip angle folded only at the bottom no longer rejects', () {
      // The fold ML Kit guesses for hidden hips at the bottom of normal
      // reps. The knees stay far behind the hands.
      PoseFrame frame(double depth) {
        // The hips stay 30 px below the shoulders.
        final y = 430 + 0.6 * depth * 200;
        final folded = depth >= 1.2;
        return pushUpFrame(
          depth: depth,
          elbowAngle: depth >= 0.8 ? 120 : 170,
          lowerBody: {
            BodyLandmark.leftHip: (leftX, y),
            BodyLandmark.rightHip: (rightX, y),
            BodyLandmark.leftKnee: (leftX + (folded ? 80 : 0), y + 10),
            BodyLandmark.rightKnee: (rightX - (folded ? 80 : 0), y + 10),
          },
        );
      }

      RepUpdate run(RepJudge c) {
        at(c, 0, frame(0));
        at(c, 300, frame(0));
        at(c, 400, frame(0.6));
        at(c, 600, frame(1.2));
        at(c, 700, frame(1.4));
        at(c, 800, frame(1.5));
        at(c, 1000, frame(0.6));
        return at(c, 1200, frame(0));
      }

      expect(run(judge(config: noBow)).event!.valid, isTrue);
      final strict = judge(
        config: const RepJudgeConfig(
          smoothingTau: Duration.zero,
          kneeBentAngle: 110,
          bowHipHandGap: double.negativeInfinity,
        ),
      );
      expect(run(strict).event!.reason, RejectReason.kneesDown);
    });

    test('hips hidden at the bottom cannot reject for the belly', () {
      final update = repWithHips(judge(), (_) => 430, hipsAtBottom: false);
      expect(update.event!.valid, isTrue);
    });

    /// Shoulder–hip–knee angle [hipDeg], with the knee kept behind the hands.
    PoseFrame hipFrame(double hipDeg, {double depth = 0, double elbow = 170}) {
      Offset kneeOf(Offset hip, double turn) {
        final rad = turn * hipDeg * math.pi / 180;
        final vx = 0.0;
        final vy = 400 - hip.dy;
        final rx = vx * math.cos(rad) - vy * math.sin(rad);
        final ry = vx * math.sin(rad) + vy * math.cos(rad);
        final len = math.sqrt(rx * rx + ry * ry);
        return Offset(hip.dx + rx / len * 90, hip.dy + ry / len * 90);
      }

      const leftHip = Offset(leftX, 470);
      const rightHip = Offset(rightX, 470);
      final leftKnee = kneeOf(leftHip, 1);
      final rightKnee = kneeOf(rightHip, -1);
      return pushUpFrame(
        depth: depth,
        elbowAngle: elbow,
        lowerBody: {
          BodyLandmark.leftHip: (leftHip.dx, leftHip.dy),
          BodyLandmark.rightHip: (rightHip.dx, rightHip.dy),
          BodyLandmark.leftKnee: (leftKnee.dx, leftKnee.dy),
          BodyLandmark.rightKnee: (rightKnee.dx, rightKnee.dy),
        },
      );
    }

    test('a kneel from the first frame is knees without a normal plank', () {
      final c = judge(config: noBow);
      at(c, 0, hipFrame(130));
      at(c, 300, hipFrame(130));
      at(c, 500, hipFrame(140, depth: 0.6, elbow: 140));
      at(c, 800, hipFrame(140, depth: 1.4, elbow: 120));
      final update = at(c, 1200, hipFrame(130));
      expect(update.event!.reason, RejectReason.kneesDown);
    });

    test('one normal top uses the wider knee line', () {
      final c = judge(config: noBow);
      at(c, 0, hipFrame(170));
      at(c, 300, hipFrame(164));
      at(c, 400, hipFrame(145));
      at(c, 600, hipFrame(160, depth: 0.6, elbow: 140));
      at(c, 900, hipFrame(160, depth: 1.4, elbow: 120));
      final update = at(c, 1300, hipFrame(170));
      expect(update.event!.valid, isTrue);
    });

    test('one normal top still catches a short kneel flash', () {
      final c = judge(config: noBow);
      at(c, 0, hipFrame(170));
      at(c, 300, hipFrame(167));
      at(c, 400, hipFrame(135));
      at(c, 600, hipFrame(160, depth: 0.6, elbow: 140));
      at(c, 900, hipFrame(160, depth: 1.4, elbow: 120));
      final update = at(c, 1300, hipFrame(170));
      expect(update.event!.reason, RejectReason.kneesDown);
    });

    test('three normal tops tighten the knee line', () {
      final c = judge(config: noBow);
      at(c, 0, hipFrame(170));
      at(c, 300, hipFrame(164));
      at(c, 400, hipFrame(167));
      at(c, 500, hipFrame(170));
      at(c, 600, hipFrame(145));
      at(c, 800, hipFrame(160, depth: 0.6, elbow: 140));
      at(c, 1100, hipFrame(160, depth: 1.4, elbow: 120));
      final update = at(c, 1500, hipFrame(170));
      expect(update.event!.reason, RejectReason.kneesDown);
    });

    test('a plank after a kneel can count again', () {
      final c = judge(config: noBow);
      at(c, 0, hipFrame(130));
      at(c, 300, hipFrame(130));
      at(c, 500, hipFrame(140, depth: 1.4, elbow: 120));
      expect(at(c, 900, hipFrame(130)).event!.reason, RejectReason.kneesDown);
      at(c, 1000, hipFrame(168));
      at(c, 1300, hipFrame(168));
      at(c, 1500, hipFrame(168, depth: 0.6, elbow: 140));
      at(c, 1800, hipFrame(168, depth: 1.4, elbow: 120));
      final update = at(c, 2200, hipFrame(168));
      expect(update.event!.valid, isTrue);
    });

    test('a hidden lower body leaves the rep valid', () {
      final c = judge();
      calibrate(c);
      expect(perform(c, 400).event!.valid, isTrue);
    });
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
