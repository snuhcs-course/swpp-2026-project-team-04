import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/rep_judge_demo.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/push_up_judge_adapter.dart';
import 'package:gymrats_app/services/pose/pose_metrics.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';

import '../../support/pose_fixtures.dart';

void main() {
  _kneeSpecialistIntegrationTests();
  _wideProposalTests();
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
  // Keep old geometric behavior covered only as the explicit comparison mode.
  // The default unified policy is exercised by continuous-observation tests.
  RepJudge legacyJudge({RepJudgeConfig config = fast}) =>
      RepJudge(config: config, clock: () => now, useFrameKnee: false);

  setUp(() => now = Duration.zero);

  RepUpdate at(RepJudge c, int ms, PoseFrame frame) {
    now = Duration(milliseconds: ms);
    return c.update(frame);
  }

  PoseFrame pose({
    double depth = 0,
    double? shoulderDrop,
    double elbow = 178,
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
    double topElbow = 178,
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

  group('continuous knee observations', () {
    late _FrameKneeFake classifier;
    late RepJudge counter;

    setUp(() {
      classifier = _FrameKneeFake();
      counter = RepJudge(
        config: fast,
        clock: () => now,
        useFrameKnee: true,
        kneeClassifier: classifier,
      );
    });

    void ready(KneeFrameState state, [int offset = 0]) {
      classifier.state = state;
      at(counter, offset, pose());
      at(counter, offset + 150, pose());
      at(counter, offset + 300, pose());
    }

    test('touching evidence survives hidden knees during a full rep', () {
      ready(KneeFrameState.touching);
      classifier.state = KneeFrameState.occluded;
      final down = at(counter, 400, pose(depth: .6, elbow: 160));
      expect(down.snapshot.knee.state, KneeFrameState.occluded);
      expect(down.event, isNull);
      at(counter, 700, pose(depth: 1.5, elbow: 150));
      classifier.state = KneeFrameState.touching;
      final result = at(counter, 1000, pose());
      expect(result.snapshot.knee.state, KneeFrameState.touching);
      expect(result.event!.valid, isFalse);
      expect(result.event!.reason, RejectReason.kneesDown);
    });

    test('lifted hidden lifted does not create touching evidence', () {
      ready(KneeFrameState.lifted);
      classifier.state = KneeFrameState.occluded;
      at(counter, 400, pose(depth: .6, elbow: 160));
      at(counter, 700, pose(depth: 1.5, elbow: 150));
      classifier.state = KneeFrameState.lifted;
      final result = at(counter, 1000, pose());
      expect(result.event!.valid, isTrue);
      expect(result.snapshot.knee.state, KneeFrameState.lifted);
    });

    test('confirmed touching persists through an occluded return', () {
      ready(KneeFrameState.touching);
      classifier.state = KneeFrameState.occluded;
      expect(perform(counter, 400).event!.reason, RejectReason.kneesDown);
    });

    test(
      'battle contact takes priority over shallow depth on a completed rep',
      () {
        counter = RepJudge(
          config: fast,
          clock: () => now,
          useFrameKnee: true,
          retainLegacyKnee: true,
          requireBattleDepth: true,
          kneeClassifier: classifier,
        );
        ready(KneeFrameState.touching);
        for (final ms in [400, 500, 600]) {
          expect(
            at(
              counter,
              ms,
              pose(depth: .33, shoulderDrop: .20, elbow: 130),
            ).event,
            isNull,
          );
        }
        expect(at(counter, 850, pose()).event!.reason, RejectReason.kneesDown);
      },
    );

    test('partial-cycle knee feedback also uses the shared support mode', () {
      ready(KneeFrameState.touching);
      for (final ms in [400, 500, 600]) {
        at(counter, ms, pose(depth: .33, shoulderDrop: .20, elbow: 130));
      }
      expect(at(counter, 850, pose()).event!.reason, RejectReason.kneesDown);
    });

    test('unconfirmed partial-cycle support stays a depth fault', () {
      ready(KneeFrameState.lifted);
      for (final ms in [400, 500, 600]) {
        at(counter, ms, pose(depth: .33, shoulderDrop: .20, elbow: 130));
      }
      expect(
        at(counter, 850, pose()).event!.reason,
        RejectReason.insufficientDepth,
      );
    });

    test('touching only during and after a rep cannot supply preparation', () {
      ready(KneeFrameState.lifted);
      classifier.state = KneeFrameState.touching;
      at(counter, 400, pose(depth: .6, elbow: 160));
      at(counter, 500, pose(depth: 1.2, elbow: 150));
      at(counter, 600, pose(depth: 1.5, elbow: 150));
      final event = at(counter, 900, pose()).event!;
      expect(event.valid, isTrue);
    });

    test('touching preparation and a lifted return keep the base result', () {
      ready(KneeFrameState.touching);
      classifier.state = KneeFrameState.lifted;
      expect(perform(counter, 400).event!.valid, isTrue);
    });

    test('a later confirmed lifted preparation clears the previous rep', () {
      ready(KneeFrameState.touching);
      expect(perform(counter, 400).event!.reason, RejectReason.kneesDown);
      ready(KneeFrameState.lifted, 1300);
      final next = perform(counter, 1700).event!;
      expect(next.index, 2);
      expect(next.valid, isTrue);
    });

    test('each input frame has a reading even without a nose or event', () {
      for (final state in KneeFrameState.values) {
        classifier.state = state;
        final result = at(counter, state.index * 50, emptyFrame());
        expect(result.snapshot.knee.state, state);
        expect(result.event, isNull);
      }
      expect(classifier.calls, 3);
    });

    test('MLP path also returns a reading on every input frame', () {
      final mlp = RepJudge(
        useMlp: true,
        useFrameKnee: true,
        clock: () => now,
        kneeClassifier: classifier,
      );
      for (final state in KneeFrameState.values) {
        classifier.state = state;
        final result = at(mlp, state.index * 50, emptyFrame());
        expect(result.snapshot.knee.state, state);
      }
      expect(classifier.calls, 3);
    });

    test('reset and abandon clear confirmed touching history', () {
      for (final reset in [counter.reset, counter.abandon]) {
        ready(KneeFrameState.touching);
        reset();
        ready(KneeFrameState.occluded, 400);
        expect(perform(counter, 800).event!.valid, isTrue);
      }
    });

    test('a camera time gap clears previous touching evidence', () {
      ready(KneeFrameState.touching);
      ready(KneeFrameState.occluded, 10000);
      expect(perform(counter, 10400).event!.valid, isTrue);
    });

    test(
      'continuous unknown frames before descent retain the confirmed mode',
      () {
        ready(KneeFrameState.touching);
        classifier.state = KneeFrameState.occluded;
        for (final ms in [400, 600, 800, 1000]) {
          at(counter, ms, pose());
        }
        at(counter, 1100, pose(depth: .6, elbow: 160));
        at(counter, 1400, pose(depth: 1.5, elbow: 150));
        classifier.state = KneeFrameState.touching;
        expect(at(counter, 1700, pose()).event!.reason, RejectReason.kneesDown);
      },
    );

    test('one lifted observation followed by hidden frames keeps touching', () {
      ready(KneeFrameState.touching);
      classifier.state = KneeFrameState.lifted;
      at(counter, 350, pose());
      classifier.state = KneeFrameState.occluded;
      at(counter, 400, pose(depth: .6, elbow: 160));
      at(counter, 700, pose(depth: 1.5, elbow: 150));
      expect(at(counter, 1000, pose()).event!.reason, RejectReason.kneesDown);
    });

    test(
      'three lifted frames cannot resurrect preparation after occlusion',
      () {
        ready(KneeFrameState.touching);
        classifier.state = KneeFrameState.lifted;
        for (final ms in [320, 340, 360]) {
          at(counter, ms, pose());
        }
        classifier.state = KneeFrameState.occluded;
        at(counter, 400, pose(depth: .6, elbow: 160));
        at(counter, 700, pose(depth: 1.5, elbow: 150));
        classifier.state = KneeFrameState.touching;
        at(counter, 800, pose(depth: .9, elbow: 160));
        at(counter, 850, pose(depth: .7, elbow: 170));
        expect(at(counter, 1000, pose()).event!.valid, isTrue);
      },
    );

    test(
      'third lifted frame at descent invalidates prospective preparation',
      () {
        ready(KneeFrameState.touching);
        classifier.state = KneeFrameState.lifted;
        at(counter, 340, pose());
        at(counter, 370, pose());
        at(counter, 400, pose(depth: .6, elbow: 160));
        at(counter, 700, pose(depth: 1.5, elbow: 150));
        classifier.state = KneeFrameState.touching;
        at(counter, 800, pose(depth: .9, elbow: 160));
        at(counter, 850, pose(depth: .7, elbow: 170));
        expect(at(counter, 1000, pose()).event!.valid, isTrue);
      },
    );

    test(
      'the comparison option controls only the additional endpoint veto',
      () {
        counter = RepJudge(
          config: fast,
          clock: () => now,
          useFrameKnee: false,
          kneeClassifier: classifier,
        );
        ready(KneeFrameState.touching);
        classifier.state = KneeFrameState.occluded;
        at(counter, 400, pose(depth: .6, elbow: 160));
        at(counter, 700, pose(depth: 1.5, elbow: 150));
        classifier.state = KneeFrameState.touching;
        final result = at(counter, 1000, pose());
        expect(result.event!.valid, isTrue);
        expect(result.snapshot.knee.state, KneeFrameState.touching);
      },
    );

    test('an abandoned short dip does not taint the next lifted rep', () {
      ready(KneeFrameState.touching);
      at(counter, 400, pose(depth: .6, elbow: 160));
      expect(at(counter, 450, pose()).event, isNull);
      ready(KneeFrameState.lifted, 600);
      expect(perform(counter, 1000).event!.valid, isTrue);
    });
  });

  PoseFrame fixedHands(double elbowAngle, {double? noseDrop}) {
    final halfAngle = elbowAngle * math.pi / 360;
    final halfHeight = 100 * math.sin(halfAngle);
    final offset = 100 * math.cos(halfAngle);
    return PoseFrame(
      imageWidth: 800,
      imageHeight: 600,
      keypoints: {
        if (noseDrop != null)
          BodyLandmark.nose: kp(BodyLandmark.nose, 400, 180 + noseDrop),
        for (final (s, e, w, x, side) in [
          (
            BodyLandmark.leftShoulder,
            BodyLandmark.leftElbow,
            BodyLandmark.leftWrist,
            300.0,
            -1,
          ),
          (
            BodyLandmark.rightShoulder,
            BodyLandmark.rightElbow,
            BodyLandmark.rightWrist,
            500.0,
            1,
          ),
        ]) ...{
          s: kp(s, x, 400 - 2 * halfHeight),
          e: kp(e, x + side * offset, 400 - halfHeight),
          w: kp(w, x, 400),
        },
      },
    );
  }

  test('MLP judge emits sequential binary verdicts and resets a new round', () {
    final c = RepJudge(useMlp: true, clock: () => now);
    List<RepEvent> run(int offset) {
      final events = <RepEvent>[];
      for (var i = 0; i < 96; i++) {
        final bend = (1 - ((i % 32) - 16).abs() / 8).clamp(0.0, 1.0);
        final event = at(c, offset + i * 60, fixedHands(175 - 85 * bend)).event;
        if (event != null) events.add(event);
      }
      return events;
    }

    final first = run(0);
    expect(first.map((e) => e.index), [1, 2, 3]);
    expect(first.map((e) => e.at.inMilliseconds), [1260, 3180, 5100]);
    // Frozen model output for these visible synthetic arm cycles.
    expect(first.every((e) => !e.valid), isTrue);
    expect(first.every((e) => e.reason != null), isTrue);
    c.abandon();
    expect(run(6000).map((e) => e.index), [4, 5, 6]);
    c.reset();
    expect(run(12000).map((e) => e.index), [1, 2, 3]);
  });

  test('MLP judge cannot turn missing or stationary landmarks into a rep', () {
    final c = RepJudge(useMlp: true, clock: () => now);
    for (var i = 0; i < 50; i++) {
      expect(at(c, i * 60, fixedHands(175)).event, isNull);
    }
    for (var i = 50; i < 100; i++) {
      expect(at(c, i * 60, emptyFrame()).event, isNull);
    }
  });

  test(
    'knee forest enables the model path and keeps causal proposal indexes',
    () {
      final c = RepJudge(useKneeForest: true, clock: () => now);
      expect(c.useMlp, isTrue);
      List<RepEvent> run(int offset) {
        final events = <RepEvent>[];
        for (var i = 0; i < 96; i++) {
          final bend = (1 - ((i % 32) - 16).abs() / 8).clamp(0.0, 1.0);
          final event = at(
            c,
            offset + i * 60,
            fixedHands(175 - 85 * bend),
          ).event;
          if (event != null) events.add(event);
        }
        return events;
      }

      final first = run(0);
      expect(first.map((event) => event.index), [1, 2, 3]);
      expect(first.map((event) => event.at.inMilliseconds), [1260, 3180, 5100]);
      // These arm-only frames supply no lower-body evidence to the forest.
      expect(
        first.every((event) => event.reason != RejectReason.kneesDown),
        isTrue,
      );
      c.abandon();
      expect(run(6000).map((event) => event.index), [4, 5, 6]);
      c.reset();
      expect(run(12000).map((event) => event.index), [1, 2, 3]);
    },
  );

  test('MLP judge discards a half-finished attempt when the camera pauses', () {
    final c = RepJudge(useMlp: true, clock: () => now);
    for (var i = 0; i <= 17; i++) {
      final bend = (1 - (i - 16).abs() / 8).clamp(0.0, 1.0);
      expect(at(c, i * 60, fixedHands(175 - 85 * bend)).event, isNull);
    }
    for (var i = 0; i < 24; i++) {
      expect(at(c, 2000 + i * 60, fixedHands(175)).event, isNull);
    }
  });

  test(
    'a visible partial 2D cycle gives feedback without a head calibration',
    () {
      for (final angle in <double?>[null, 60, 80]) {
        final c = judge();
        final events = <RepEvent>[];
        void frame(int i, double movement) {
          now = Duration(milliseconds: i * 60);
          final sample = fixedHands(153 - 60 * movement);
          final value = c.updateWithPhoneTilt(sample, angle);
          if (value.event != null) events.add(value.event!);
        }

        for (var i = 0; i < 17; i++) {
          final movement = (1 - (i - 7).abs() / 4).clamp(0.0, 1.0);
          frame(i, movement);
        }
        expect(events.map((v) => v.valid), [false], reason: 'tilt $angle');
        expect(events.single.index, 1);
        expect(events.single.reason, RejectReason.insufficientDepth);
        c.abandon();
        // A fresh top cannot finish the already judged movement.
        for (var i = 17; i < 25; i++) {
          frame(i, 0);
        }
        expect(events.length, 1);
      }
    },
  );

  test(
    'one shallow rep gives one verdict when wrists recover before the head',
    () {
      final c = judge(config: const RepJudgeConfig());
      final closed = <int>[];
      for (var i = 0; i < 32; i++) {
        final arm = (1 - (i - 12).abs() / 6).clamp(0.0, 1.0);
        final head = (1 - (i - 13).abs() / 6).clamp(0.0, 1.0);
        final frame = fixedHands(175 - 90 * arm, noseDrop: 68 * head);
        final result = at(c, i * 60, frame);
        if (result.event != null) {
          expect(result.event!.valid, isFalse);
          closed.add(i);
        }
      }
      expect(closed, [19]);
    },
  );

  test('the default judge rejects a small dip once and leaves a full rep to the counter', () {
    final c = judge(config: const RepJudgeConfig());
    calibrate(c);
    final rejected = <RepEvent>[];
    for (final (ms, frame) in [
      (450, pose(depth: .34, shoulderDrop: .22, elbow: 130)),
      (650, pose(depth: .34, shoulderDrop: .22, elbow: 130)),
      (900, pose()),
      (1000, pose()),
    ]) {
      final event = at(c, ms, frame).event;
      if (event != null) rejected.add(event);
    }
    final dip = rejected.single;
    expect(dip.valid, isFalse);
    expect(dip.reason, RejectReason.insufficientDepth);
    expect(dip.index, 1);
    final next = perform(c, 1150).event!;
    expect(next.valid, isTrue);
    expect(next.index, 2);
  });

  test(
    'a small dip needs a visible chest descent, elbow bend and reopening',
    () {
      final c = judge();
      calibrate(c);
      at(c, 450, pose(depth: .33, shoulderDrop: .03, elbow: 132));
      expect(at(c, 650, pose()).event, isNull);
      at(c, 800, pose(depth: .33, shoulderDrop: .21, elbow: 176));
      expect(at(c, 1000, pose()).event, isNull);
      at(c, 1200, pose(depth: .33, shoulderDrop: .21, elbow: 132));
      expect(at(c, 1400, pose(hide: arms)).event, isNull);
    },
  );

  test('legacy comparison: small dips report support or sustained tilt', () {
    RepEvent verdict({required int supportedFrames, required double tilt}) {
      final c = legacyJudge();
      calibrate(c);
      for (var i = 0; i < 3; i++) {
        at(
          c,
          400 + 100 * i,
          pushUpFrame(
            depth: .33,
            shoulderDrop: .20,
            elbowAngle: 130,
            tiltDeg: tilt,
            lowerBody: i < supportedFrames
                ? {
                    BodyLandmark.leftKnee: (405, 690),
                    BodyLandmark.rightKnee: (595, 690),
                    BodyLandmark.leftAnkle: (405, 610),
                    BodyLandmark.rightAnkle: (595, 610),
                  }
                : {},
          ),
        );
      }
      return at(c, 850, pose()).event!;
    }

    expect(verdict(supportedFrames: 3, tilt: 0).reason, RejectReason.kneesDown);
    expect(
      verdict(supportedFrames: 1, tilt: 0).reason,
      RejectReason.insufficientDepth,
    );
    expect(
      verdict(supportedFrames: 0, tilt: 22).reason,
      RejectReason.shouldersNotLevel,
    );
  });

  test('an elevated top calibrates with visible hips and wrists and keeps the grading threshold fixed', () {
    RepUpdate run({
      required double hipY,
      bool hideWrist = false,
      bool hideHips = false,
    }) {
      final c = judge();
      final ui = PushUpJudgeAdapter(c);
      final top = pushUpFrame(
        hide: {
          if (hideWrist) BodyLandmark.leftWrist,
          if (hideHips) ...hipLandmarks,
        },
        lowerBody: {
          BodyLandmark.leftHip: (410, hipY),
          BodyLandmark.rightHip: (590, hipY),
        },
      );
      at(c, 0, top);
      at(c, 300, top);
      at(c, 500, pose(depth: .45, elbow: 146));
      at(c, 650, pose(depth: .85, shoulderDrop: .52, elbow: 135));
      expect(ui.passDepth, 1.1);
      return at(c, 900, pose());
    }

    expect(run(hipY: 470).event?.valid, isTrue);
    expect(run(hipY: 590).event?.reason, RejectReason.insufficientDepth);
    expect(
      run(hipY: 470, hideWrist: true).event?.reason,
      RejectReason.insufficientDepth,
    );
    expect(
      run(hipY: 470, hideHips: true).event?.reason,
      RejectReason.insufficientDepth,
    );
  });

  test('relaxed depth needs both wrists below their shoulders and a fully observed bend and return', () {
    List<RepEvent> replay({
      bool hiddenBottom = false,
      bool hiddenReturn = false,
      bool straight = false,
      bool raisedWrist = false,
      bool full = false,
    }) {
      final c = judge(config: const RepJudgeConfig());
      final top = pushUpFrame(
        lowerBody: {
          BodyLandmark.leftHip: (410, 470),
          BodyLandmark.rightHip: (590, 470),
        },
      );
      if (raisedWrist) {
        final shoulder = top[BodyLandmark.leftShoulder]!;
        for (final joint in [BodyLandmark.leftWrist, BodyLandmark.leftElbow]) {
          final point = top[joint]!;
          top.keypoints[joint] = kp(
            joint,
            point.x,
            shoulder.y - .6 * (point.y - shoulder.y),
          );
        }
      }
      final bottom = pose(
        depth: full ? 1.5 : .85,
        shoulderDrop: full ? .9 : .52,
        elbow: straight ? 178 : 135,
        hide: hiddenBottom
            ? {...arms, BodyLandmark.leftShoulder, BodyLandmark.rightShoulder}
            : {},
      );
      final returned = pose(hide: hiddenReturn ? arms : {});
      final frames = [
        ...List.filled(7, top),
        ...List.filled(6, bottom),
        ...List.filled(6, returned),
      ];
      return [
        for (var i = 0; i < frames.length; i++) ?at(c, 70 * i, frames[i]).event,
      ];
    }

    expect(
      replay(hiddenBottom: true).single.reason,
      RejectReason.insufficientDepth,
    );
    expect(replay(hiddenReturn: true), isEmpty);
    expect(replay(straight: true).single.reason, RejectReason.armsStraight);
    expect(
      replay(raisedWrist: true).single.reason,
      RejectReason.insufficientDepth,
    );
    expect(replay().single.valid, isTrue);
    expect(replay(full: true, hiddenReturn: true).single.valid, isTrue);
  });

  test('moderate shoulder tilt refines feedback on both short and ordinary attempts', () {
    for (final depth in [.33, .90]) {
      final c = judge();
      calibrate(c);
      final dip = pose(
        depth: depth,
        shoulderDrop: depth * .6,
        elbow: 130,
        tilt: 10,
      );
      for (final ms in [440, 530, 640]) {
        expect(at(c, ms, dip).event, isNull);
      }
      final feedback = at(c, 820, pose()).event!;
      expect(feedback.reason, RejectReason.shouldersNotLevel);
      expect(feedback.valid, isFalse);
      expect(feedback.index, 1);
      expect(at(c, 920, pose()).event, isNull);
      final full = perform(c, 1100).event!;
      expect(full.valid, isTrue);
      expect(full.index, 2);
    }
  });

  test('legacy comparison: partial feedback uses support and elbow angle', () {
    RepEvent partial({
      required bool visibleTopHips,
      required bool supported,
      required double elbow,
    }) {
      final c = legacyJudge();
      final top = pushUpFrame(
        lowerBody: {
          if (visibleTopHips) ...{
            BodyLandmark.leftHip: (410, 590),
            BodyLandmark.rightHip: (590, 590),
          },
        },
      );
      for (final ms in [0, 300, 355, 410]) {
        at(c, ms, top);
      }
      final dip = pushUpFrame(
        depth: .90,
        elbowAngle: elbow,
        lowerBody: {
          if (supported) ...{
            BodyLandmark.leftKnee: (410, 750),
            BodyLandmark.rightKnee: (590, 750),
          },
        },
      );
      for (final ms in [500, 610, 720]) {
        at(c, ms, dip);
      }
      return at(c, 900, top).event!;
    }

    // Missing hip observations do not invent knee contact. With real support,
    // the top and bottom hip readings distinguish bent knees from stiff arms.
    expect(
      partial(visibleTopHips: false, supported: false, elbow: 165).reason,
      RejectReason.insufficientDepth,
    );
    expect(
      partial(visibleTopHips: false, supported: true, elbow: 135).reason,
      RejectReason.insufficientDepth,
    );
    expect(
      partial(visibleTopHips: false, supported: true, elbow: 165).reason,
      RejectReason.armsStraight,
    );
    expect(
      partial(visibleTopHips: true, supported: true, elbow: 155).reason,
      RejectReason.kneesDown,
    );
  });

  test('reset and camera tracking loss discard an open short dip', () {
    for (final reset in [true, false]) {
      final c = judge();
      calibrate(c);
      at(c, 500, pose(depth: .33, shoulderDrop: .20, elbow: 130));
      if (reset) {
        c.reset();
      } else {
        c.abandon();
      }
      expect(at(c, 700, pose()).event, isNull);
      expect(at(c, 1000, pose()).event, isNull);
      at(c, 1200, pose(depth: .33, shoulderDrop: .20, elbow: 130));
      final first = at(c, 1450, pose()).event!;
      expect(first.reason, RejectReason.insufficientDepth);
      expect(first.index, 1);
    }
  });

  test('a new setup discards a previous camera height after tracking loss', () {
    final c = judge();
    final elevated = pushUpFrame(
      lowerBody: {
        BodyLandmark.leftHip: (410, 470),
        BodyLandmark.rightHip: (590, 470),
      },
    );
    at(c, 0, elevated);
    at(c, 300, elevated);
    at(c, 550, pose(depth: .85, shoulderDrop: .52, elbow: 135));
    expect(at(c, 800, pose()).event?.valid, isTrue);
    // The gap resets calibration. With the hips now hidden, the ordinary
    // depth target applies to the same movement.
    at(c, 1500, pose());
    at(c, 1800, pose());
    at(c, 2050, pose(depth: .85, shoulderDrop: .52, elbow: 135));
    expect(at(c, 2300, pose()).event?.reason, RejectReason.insufficientDepth);
  });

  test('a 168 degree partial return is never promoted to a valid rep', () {
    PoseFrame frame(double depth, double angle, {double? bodyDepth}) {
      final body = bodyDepth ?? depth;
      final sy = 400 + .6732139131660497 * body * 200;
      final wy = 640 + .06788671109571764 * body * 200;
      final d = (wy - sy).abs();
      final length = d / (2 * math.sin(angle * math.pi / 360));
      final h = math.sqrt(math.max(0, length * length - d * d / 4));
      final positions = <BodyLandmark, (double, double)>{
        BodyLandmark.nose: (500, 360 + depth * 200),
        BodyLandmark.leftShoulder: (400, sy),
        BodyLandmark.rightShoulder: (600, sy),
        BodyLandmark.leftElbow: (400 + h, (sy + wy) / 2),
        BodyLandmark.rightElbow: (600 - h, (sy + wy) / 2),
        BodyLandmark.leftWrist: (400, wy),
        BodyLandmark.rightWrist: (600, wy),
        BodyLandmark.leftHip: (
          400 - .06348361145797995 * 200,
          sy + .1297483602508122 * 200,
        ),
        BodyLandmark.rightHip: (
          600 - .06348361145797995 * 200,
          sy + .1297483602508122 * 200,
        ),
      };
      return PoseFrame(
        imageWidth: 1000,
        imageHeight: 1000,
        keypoints: {
          for (final e in positions.entries)
            e.key: Keypoint(
              landmark: e.key,
              x: e.value.$1,
              y: e.value.$2,
              likelihood: .99,
            ),
        },
      );
    }

    final c = judge(config: const RepJudgeConfig());
    final events = <RepEvent>[];
    for (var i = 0; i < 95; i++) {
      final t = i - 12;
      double depth, angle;
      if (t < 0) {
        depth = 0;
        angle = 178;
      } else if (t < 17) {
        final f = t / 17;
        depth = 1.5685349628609495 * f;
        angle = 178 + (96.91476272478336 - 178) * f;
      } else if (t < 34) {
        final f = (t - 17) / 17;
        depth =
            1.5685349628609495 + (.146102932143259 - 1.5685349628609495) * f;
        angle = 96.91476272478336 + (168.4207876440463 - 96.91476272478336) * f;
      } else if (t < 35) {
        depth = .146102932143259;
        angle = 168.4207876440463;
      } else if (t < 55) {
        depth = .146102932143259 + .5977130317970312 * (t - 35) / 20;
        angle = 168.4207876440463;
      } else {
        depth = .146102932143259 + .5977130317970312;
        angle = 168.4207876440463;
      }
      final event = at(
        c,
        i * 33,
        frame(depth, angle, bodyDepth: t >= 35 ? .146102932143259 : null),
      ).event;
      if (event != null) events.add(event);
    }
    expect(events.where((e) => e.valid), isEmpty);
    expect(
      events.any((e) => e.reason == RejectReason.incompleteExtension),
      isTrue,
    );
  });

  test('a one-second full rep counts with the production smoothing', () {
    final c = judge(config: const RepJudgeConfig());
    calibrate(c);
    final events = <RepEvent>[];
    // 30 Hz samples: 0.4 s down, 0.4 s back up, then hold at the top.
    for (var i = 0; i <= 30; i++) {
      final fraction = i / 30;
      final depth = fraction < 0.4
          ? 1.5 * fraction / 0.4
          : fraction < 0.8
          ? 1.5 * (0.8 - fraction) / 0.4
          : 0.0;
      final update = at(
        c,
        400 + i * 33,
        pose(depth: depth, elbow: 178 - depth * 18),
      );
      if (update.event != null) events.add(update.event!);
    }
    expect(events.where((e) => e.valid), hasLength(1));
    expect(events.where((e) => !e.valid), isEmpty);
  });

  test('a full rep can start after a 250 ms top hold', () {
    final c = judge(config: const RepJudgeConfig());
    at(c, 0, pose());
    expect(at(c, 250, pose()).snapshot.phase, RepPhase.up);
    final events = <RepEvent>[];
    for (var i = 1; i <= 30; i++) {
      final fraction = i / 30;
      final depth = fraction < 0.4
          ? 1.5 * fraction / 0.4
          : fraction < 0.8
          ? 1.5 * (0.8 - fraction) / 0.4
          : 0.0;
      final update = at(
        c,
        250 + i * 33,
        pose(depth: depth, elbow: 178 - depth * 18),
      );
      if (update.event != null) events.add(update.event!);
    }
    expect(events, hasLength(1));
    expect(events.single.valid, isTrue);
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
    final update = perform(c, 400, bottomElbow: 160);
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

  test('elbows bent to 100 degrees reach the bottom with a shallow head', () {
    RepUpdate bottom(double elbow) {
      final c = judge();
      calibrate(c);
      at(c, 400, pose(depth: 0.6, shoulderDrop: 0.3));
      return at(c, 800, pose(depth: 0.9, shoulderDrop: 0.3, elbow: elbow));
    }

    // Head 0.9 and shoulders 0.3 down: short of both lines, so only the
    // elbows can complete the bottom.
    expect(bottom(100).snapshot.phase, RepPhase.bottom);
    expect(bottom(101).snapshot.phase, RepPhase.descending);
  });

  test('bent elbows still need the head 0.8 down', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6, shoulderDrop: 0.3));
    final low = at(c, 800, pose(depth: 0.75, shoulderDrop: 0.3, elbow: 80));
    expect(low.snapshot.phase, RepPhase.descending);
  });

  /// A straight-arm top whose left arm alone is bent to [leftElbow].
  PoseFrame lopsided(double leftElbow) {
    final straight = pose();
    final bent = pose(elbow: leftElbow);
    return PoseFrame(
      imageWidth: straight.imageWidth,
      imageHeight: straight.imageHeight,
      keypoints: {
        ...straight.keypoints,
        BodyLandmark.leftElbow: bent.keypoints[BodyLandmark.leftElbow]!,
        BodyLandmark.leftWrist: bent.keypoints[BodyLandmark.leftWrist]!,
      },
    );
  }

  test('the less extended arm must lock out before the rep closes', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    at(c, 800, pose(depth: 1.5, elbow: 120));
    // Both arms average 171.5°, past topAngle, but the left arm is short.
    final short = at(c, 1200, lopsided(165));
    expect(short.event, isNull);
    expect(short.snapshot.phase, RepPhase.bottom);
    expect(at(c, 1400, pose()).event!.valid, isTrue);
  });

  test('the lockout line sits at 172 degrees for the less extended arm', () {
    RepUpdate top(double leftElbow) {
      final c = judge();
      calibrate(c);
      at(c, 400, pose(depth: 0.6));
      at(c, 800, pose(depth: 1.5, elbow: 120));
      return at(c, 1200, lopsided(leftElbow));
    }

    expect(top(171).event, isNull);
    expect(top(173).event!.valid, isTrue);
  });

  test(
    'coming up short of lockout and going down again is a missed lockout',
    () {
      final c = judge();
      calibrate(c);
      at(c, 400, pose(depth: 0.6));
      at(c, 800, pose(depth: 1.5, elbow: 120));
      expect(at(c, 1200, lopsided(160)).event, isNull);
      final again = at(c, 1500, pose(depth: 1.0, elbow: 120));
      expect(again.event!.reason, RejectReason.incompleteExtension);
    },
  );

  test('a frame without both elbows skips the lockout line', () {
    final c = judge();
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    at(c, 800, pose(depth: 1.5, elbow: 120));
    // Only the left arm is seen, at 165°: past topAngle, short of 172°.
    final frame = lopsided(165);
    final right = frame.keypoints[BodyLandmark.rightElbow]!;
    final top = at(
      c,
      1200,
      PoseFrame(
        imageWidth: frame.imageWidth,
        imageHeight: frame.imageHeight,
        keypoints: {
          ...frame.keypoints,
          BodyLandmark.rightElbow: kp(
            BodyLandmark.rightElbow,
            right.x,
            right.y,
            likelihood: 0.1,
          ),
        },
      ),
    );
    expect(top.event!.valid, isTrue);
  });

  test('a lockout line of 0 lets the arm average decide alone', () {
    final c = judge(
      config: const RepJudgeConfig(
        smoothingTau: Duration.zero,
        lockoutArmAngle: 0,
      ),
    );
    calibrate(c);
    at(c, 400, pose(depth: 0.6));
    at(c, 800, pose(depth: 1.5, elbow: 120));
    expect(at(c, 1200, lopsided(165)).event!.valid, isTrue);
  });

  test('a deep elbow angle of 0 turns the elbow bottom off', () {
    final c = judge(
      config: const RepJudgeConfig(
        smoothingTau: Duration.zero,
        deepElbowAngle: 0,
      ),
    );
    calibrate(c);
    at(c, 400, pose(depth: 0.6, shoulderDrop: 0.3));
    final low = at(c, 800, pose(depth: 0.9, shoulderDrop: 0.3, elbow: 60));
    expect(low.snapshot.phase, RepPhase.descending);
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

  test('a fast partial lockout is rejected when the next descent starts', () {
    final c = judge(config: const RepJudgeConfig());
    at(c, 0, pose());
    at(c, 250, pose());
    final events = <RepEvent>[];
    for (var i = 1; i <= 36; i++) {
      final f = i / 30;
      final depth = f < .4
          ? 1.5 * f / .4
          : f < .8
          ? 1.5 - 1.15 * (f - .4) / .4
          : .35 + 1.15 * (f - .8) / .4;
      final event = at(
        c,
        250 + i * 33,
        pose(depth: depth, elbow: 165 - depth * 15),
      ).event;
      if (event != null) events.add(event);
    }
    expect(events, hasLength(1));
    expect(events.single.reason, RejectReason.incompleteExtension);
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

  group('legacy geometry comparison, judged only when seen', () {
    RepJudge judge({RepJudgeConfig config = fast}) =>
        legacyJudge(config: config);
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

    /// [noBow] with the kneel-before-any-plank check on. It is off by
    /// default; these tests keep the rule itself covered.
    const firstKneel = RepJudgeConfig(
      smoothingTau: Duration.zero,
      bowHipHandGap: double.negativeInfinity,
      bowHipRise: double.negativeInfinity,
      defaultKneeHip: 155,
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
          elbowAngle: bendArms && depth >= 0.8 ? 120 : 178,
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
      elbowAngle: depth >= 0.8 ? 120 : 178,
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
        elbowAngle: depth >= 0.8 ? 120 : 178,
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
        elbowAngle: depth >= 0.8 ? 120 : 178,
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
        elbowAngle: depth >= 0.8 ? 120 : 178,
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
      elbowAngle: depth >= 0.8 ? 120 : 178,
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

    test('250 ms of hidden hips cannot clear a latched knee verdict', () {
      final c = judge(config: const RepJudgeConfig());
      PoseFrame hipFrame(double hipAngle) {
        final r = hipAngle * math.pi / 180;
        final kneeX = 90 * math.sin(r);
        final kneeY = 470 - 90 * math.cos(r);
        return pushUpFrame(
          lowerBody: {
            BodyLandmark.leftHip: (400, 470),
            BodyLandmark.rightHip: (600, 470),
            BodyLandmark.leftKnee: (400 + kneeX, kneeY),
            BodyLandmark.rightKnee: (600 - kneeX, kneeY),
          },
        );
      }

      for (final t in [0, 300, 350, 400]) {
        at(c, t, hipFrame(170));
      }
      at(c, 450, hipFrame(135));
      at(c, 500, pushUpFrame());
      at(c, 750, pushUpFrame());
      at(c, 800, pushUpFrame(depth: .6, elbowAngle: 145));
      at(c, 900, pushUpFrame(depth: 1.5, elbowAngle: 120));
      at(c, 1000, pushUpFrame(depth: 1.5, elbowAngle: 120));
      at(c, 1100, pushUpFrame(depth: .6, elbowAngle: 145));
      final top = at(c, 1200, pushUpFrame()).event;
      final later = at(c, 1250, pushUpFrame()).event;
      expect((top ?? later)?.reason, RejectReason.kneesDown);
    });

    test('a one-second knee push-up is rejected at camera cadence', () {
      final c = judge(config: const RepJudgeConfig());
      PoseFrame frame(double depth) {
        final wrist = wristY(depth);
        return pushUpFrame(
          depth: depth,
          elbowAngle: 178 - depth * 18,
          lowerBody: {
            BodyLandmark.leftHip: (leftX, wrist - 140),
            BodyLandmark.rightHip: (rightX, wrist - 140),
            BodyLandmark.leftKnee: (leftX, wrist),
            BodyLandmark.rightKnee: (rightX, wrist),
          },
        );
      }

      at(c, 0, frame(0));
      at(c, 250, frame(0));
      final events = <RepEvent>[];
      for (var i = 1; i <= 30; i++) {
        final f = i / 30;
        final depth = f < .4
            ? 1.5 * f / .4
            : f < .8
            ? 1.5 * (.8 - f) / .4
            : 0.0;
        final event = at(c, 250 + i * 33, frame(depth)).event;
        if (event != null) events.add(event);
      }
      expect(events, hasLength(1));
      expect(events.single.reason, RejectReason.kneesDown);
    });

    test('a one-second belly-down push-up is rejected at camera cadence', () {
      final c = judge(config: const RepJudgeConfig());
      PoseFrame frame(double depth) => pushUpFrame(
        depth: depth,
        elbowAngle: 178 - depth * 18,
        lowerBody: {
          BodyLandmark.leftHip: (leftX, wristY(depth)),
          BodyLandmark.rightHip: (rightX, wristY(depth)),
        },
      );
      at(c, 0, frame(0));
      at(c, 250, frame(0));
      final events = <RepEvent>[];
      for (var i = 1; i <= 30; i++) {
        final f = i / 30;
        final depth = f < .4
            ? 1.5 * f / .4
            : f < .8
            ? 1.5 * (.8 - f) / .4
            : 0.0;
        final event = at(c, 250 + i * 33, frame(depth)).event;
        if (event != null) events.add(event);
      }
      expect(events, hasLength(1));
      expect(events.single.reason, RejectReason.bellyDown);
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
            elbowAngle: depth >= 0.8 ? 120 : 178,
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
          elbowAngle: depth >= 0.8 ? 120 : 178,
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
        elbowAngle: depth >= 0.8 ? 120 : 178,
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
          elbowAngle: depth >= 0.8 ? 120 : 178,
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

    test(
      'shallow knee push-ups are rejected at both calibrated camera heights',
      () {
        RepEvent kneeDip(double hipY) {
          final c = judge();
          PoseFrame frame(double depth) => pushUpFrame(
            depth: depth,
            lowerBody: {
              BodyLandmark.leftHip: (leftX, hipY),
              BodyLandmark.rightHip: (rightX, hipY),
              BodyLandmark.leftKnee: (leftX, 640),
              BodyLandmark.rightKnee: (rightX, 640),
            },
          );
          at(c, 0, frame(0));
          at(c, 300, frame(0));
          at(c, 500, frame(0.6));
          at(c, 800, frame(0.9));
          return at(c, 1200, frame(0)).event!;
        }

        // At the ordinary depth target .90 is shallow. In the elevated
        // setup it reaches the calibrated bottom, but the arms never bent.
        expect(kneeDip(590).reason, RejectReason.insufficientDepth);
        final elevated = kneeDip(500);
        expect(elevated.valid, isFalse);
        expect(elevated.reason, RejectReason.armsStraight);
      },
    );

    test('an upright body is a wall push-up', () {
      final update = repWithHips(judge(), (d) => 840 + 0.5 * d * 200);
      expect(update.event!.reason, RejectReason.notFloorPushUp);
      expect(update.event!.reason!.message, 'Floor push-up');
    });

    test('knees bent under the hips are a knee push-up', () {
      final update = repWithHips(
        judge(config: firstKneel),
        (d) => 430 + 0.5 * d * 200,
        knee: (80, 10),
      );
      expect(update.event!.reason, RejectReason.kneesDown);
      expect(update.event!.reason!.message, 'Knees up');
    });

    test('knees folded at the top stay folded after the angle opens', () {
      final c = judge(config: firstKneel);
      PoseFrame frame(double depth, {required bool bent}) {
        final y = 430 + 0.5 * depth * 200;
        final kneeY = bent ? y + 10 : y + 80;
        final kneeX = bent ? 80.0 : 0.0;
        return pushUpFrame(
          depth: depth,
          elbowAngle: depth >= 0.8 ? 120 : 178,
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
        judge(config: firstKneel),
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
          elbowAngle: depth >= 0.8 ? 120 : 178,
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
          elbowAngle: depth >= 0.8 ? 120 : 178,
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
          elbowAngle: depth >= 0.8 ? 120 : 178,
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
    PoseFrame hipFrame(double hipDeg, {double depth = 0, double elbow = 178}) {
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
      final c = judge(config: firstKneel);
      at(c, 0, hipFrame(130));
      at(c, 300, hipFrame(130));
      at(c, 500, hipFrame(140, depth: 0.6, elbow: 140));
      at(c, 800, hipFrame(140, depth: 1.4, elbow: 120));
      final update = at(c, 1200, hipFrame(130));
      expect(update.event!.reason, RejectReason.kneesDown);
    });

    test('by default a kneel before any plank top does not latch', () {
      // The same frames as above with the check off: no other knee rule
      // sees these hips, so the rep counts.
      final c = judge(config: noBow);
      at(c, 0, hipFrame(130));
      at(c, 300, hipFrame(130));
      at(c, 500, hipFrame(140, depth: 0.6, elbow: 140));
      at(c, 800, hipFrame(140, depth: 1.4, elbow: 120));
      final update = at(c, 1200, hipFrame(130));
      expect(update.event!.valid, isTrue);
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

    test('unified lifted evidence overrides a legacy one-frame hip latch', () {
      final classifier = _FrameKneeFake()..state = KneeFrameState.lifted;
      final c = RepJudge(
        config: noBow,
        clock: () => now,
        useFrameKnee: true,
        kneeClassifier: classifier,
      );
      at(c, 0, hipFrame(170));
      at(c, 150, hipFrame(170));
      at(c, 300, hipFrame(170));
      at(c, 400, hipFrame(135));
      at(c, 600, hipFrame(160, depth: .6, elbow: 140));
      at(c, 900, hipFrame(160, depth: 1.4, elbow: 120));
      final result = at(c, 1300, hipFrame(170));
      expect(result.event, isNotNull);
      expect(result.event!.valid, isTrue);
      expect(result.event!.reason, isNull);
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
      final c = judge(config: firstKneel);
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

void _kneeSpecialistIntegrationTests() {
  List<({RepEvent event, double baseProbability, double kneeProbability})> run(
    String fileName, {
    bool frameKnee = false,
    bool retainLegacyKnee = false,
    KneeFrameClassifier? classifier,
  }) {
    final recording = PushUpRecording.decode(
      File('test/ai_eval/cases/HSW/$fileName.json').readAsStringSync(),
    );
    var now = Duration.zero;
    Duration? previous;
    // These recorded-model assertions select their intended knee model
    // explicitly, independently of the application comparison build flag.
    final judge = RepJudge(
      useMlp: true,
      useFrameKnee: frameKnee,
      retainLegacyKnee: retainLegacyKnee,
      kneeClassifier: classifier,
      clock: () => now,
    );
    final history = PushupMlpHistory();
    final results =
        <({RepEvent event, double baseProbability, double kneeProbability})>[];
    for (final frame in recording.frames) {
      if (frame.mark == FrameMark.abandon) {
        judge.abandon();
        history.reset();
        previous = null;
        continue;
      }
      final pose = frame.pose;
      if (pose == null) continue;
      now = frame.at;
      if (previous != null &&
          (now <= previous ||
              now - previous > const RepJudgeConfig().maxFrameGap)) {
        history.reset();
      }
      previous = now;
      history.add(pose, now);
      final event = judge.update(pose).event;
      if (event == null) continue;
      final features = history.featuresForProposal(now);
      results.add((
        event: event,
        baseProbability: PushupMlpModel.normalProbability(features),
        kneeProbability: PushupKneeModel.probability(features),
      ));
    }
    return results;
  }

  test(
    'MLP knee specialist vetoes formerly accepted recorded knee motions',
    () {
      // These fitting-data fixtures check wiring, not model generalization.
      final results = run('20261101-204453_SM-S901N_knees');
      final previouslyAccepted = results.where((r) => r.baseProbability > .5);
      expect(previouslyAccepted.length, 5);
      expect(results, isNotEmpty);
      expect(results.every((r) => !r.event.valid), isTrue);
      for (final result in previouslyAccepted) {
        expect(result.kneeProbability, greaterThan(PushupKneeModel.threshold));
        expect(result.event.reason, RejectReason.kneesDown);
      }
    },
  );

  test(
    'MLP knee specialist preserves the recorded normal-motion acceptances',
    () {
      final results = run('20261101-204311_SM-S901N_normal');
      final previouslyAccepted = results.where((r) => r.baseProbability > .5);
      expect(previouslyAccepted.length, 4);
      expect(results.where((r) => r.event.valid).length, 4);
      for (final result in previouslyAccepted) {
        expect(
          result.kneeProbability,
          lessThanOrEqualTo(PushupKneeModel.threshold),
        );
        expect(result.event.valid, isTrue);
        expect(result.event.reason, isNull);
      }
    },
  );

  test('MLP completion also applies the matched knee endpoint sequence', () {
    final classifier = _FrameKneeFake()..state = KneeFrameState.touching;
    final results = run(
      '20261101-204311_SM-S901N_normal',
      frameKnee: true,
      classifier: classifier,
    );
    final acceptedByBinaryModel = results.where((r) => r.baseProbability > .5);
    expect(acceptedByBinaryModel.length, 4);
    for (final result in acceptedByBinaryModel) {
      expect(result.event.valid, isFalse);
      expect(result.event.reason, RejectReason.kneesDown);
    }
  });

  test('additive knee mode retains legacy rejection with lifted evidence', () {
    const clip = '20261101-204453_SM-S901N_knees';
    final baseline = run(clip);
    final additive = run(
      clip,
      frameKnee: true,
      retainLegacyKnee: true,
      classifier: _FrameKneeFake()..state = KneeFrameState.lifted,
    );
    expect(baseline.where((r) => r.baseProbability > .5).length, 5);
    expect(additive.map((r) => r.event.at), baseline.map((r) => r.event.at));
    expect(
      additive.map((r) => (r.event.valid, r.event.reason)),
      baseline.map((r) => (r.event.valid, r.event.reason)),
    );
  });

  test(
    'additive knee mode vetoes normal acceptance with touching evidence',
    () {
      const clip = '20261101-204311_SM-S901N_normal';
      final baseline = run(clip);
      final additive = run(
        clip,
        frameKnee: true,
        retainLegacyKnee: true,
        classifier: _FrameKneeFake()..state = KneeFrameState.touching,
      );
      expect(baseline.where((r) => r.event.valid).length, 4);
      expect(additive.map((r) => r.event.at), baseline.map((r) => r.event.at));
      expect(additive.every((r) => !r.event.valid), isTrue);
      for (final result in additive.where((r) => r.baseProbability > .5)) {
        expect(result.event.reason, RejectReason.kneesDown);
      }
    },
  );

  test('additive knee option leaves frame-disabled MLP unchanged', () {
    const clip = '20261101-204311_SM-S901N_normal';
    final baseline = run(clip);
    final additive = run(clip, retainLegacyKnee: true);
    expect(additive.map((r) => r.event.at), baseline.map((r) => r.event.at));
    expect(
      additive.map((r) => (r.event.valid, r.event.reason)),
      baseline.map((r) => (r.event.valid, r.event.reason)),
    );
  });
}

void _wideProposalTests() {
  group('experimental wide motion proposals', () {
    PoseFrame arm(double angle, {double shift = 0}) {
      final half = angle * math.pi / 360;
      final h = 90 * math.sin(half), dx = 90 * math.cos(half);
      // Only one arm is visible at this confidence. The soft branch can
      // observe it independently of the stricter bilateral span branch.
      return PoseFrame(
        imageWidth: 800,
        imageHeight: 600,
        keypoints: {
          BodyLandmark.leftShoulder: kp(
            BodyLandmark.leftShoulder,
            300 + shift,
            400 - 2 * h + shift,
            likelihood: .57,
          ),
          BodyLandmark.leftElbow: kp(
            BodyLandmark.leftElbow,
            300 - dx + shift,
            400 - h + shift,
            likelihood: .57,
          ),
          BodyLandmark.leftWrist: kp(
            BodyLandmark.leftWrist,
            300 + shift,
            400 + shift,
            likelihood: .57,
          ),
        },
      );
    }

    const empty = PoseFrame.empty(imageWidth: 800, imageHeight: 600);

    test('same-frame primary metadata wins and exact cooldown is 800 ms', () {
      final d = PushupWideProposalDetector();
      RepEvent primary(int ms) =>
          RepEvent(index: 1, at: Duration(milliseconds: ms), valid: true);
      final first = primary(0);
      expect(
        d.update(empty, Duration.zero, primary: first)?.primary,
        same(first),
      );
      expect(
        d.update(
          empty,
          const Duration(milliseconds: 799),
          primary: primary(799),
        ),
        isNull,
      );
      final next = primary(800);
      expect(
        d
            .update(empty, const Duration(milliseconds: 800), primary: next)
            ?.primary,
        same(next),
      );
      d.reset();
      expect(d.update(empty, Duration.zero, primary: first), isNotNull);
    });

    test(
      'a single observed arm flexes and returns without a primary event',
      () {
        final d = PushupWideProposalDetector();
        final at = <int>[];
        for (var i = 0; i < 18; i++) {
          final value = i < 5 || i > 10 ? 175.0 : 90.0;
          final result = d.update(arm(value), Duration(milliseconds: i * 80));
          if (result != null) {
            expect(result.primary, isNull);
            at.add(i);
          }
        }
        expect(at.length, 1);
        expect(at.single, greaterThan(10));
        final fractional = PushupWideProposalDetector();
        PushupWideProposal? completed;
        for (var i = 0; i < 18; i++) {
          final value = i < 5 || i > 10 ? 175.0 : 90.0;
          completed =
              fractional.update(
                arm(value),
                Duration(microseconds: i * 80000 + 500),
              ) ??
              completed;
        }
        expect(completed, isNotNull);
        expect(completed!.start!.inMicroseconds % 1000, 500);
      },
    );

    test(
      'rigid translation and a long occlusion do not manufacture a return',
      () {
        final translated = PushupWideProposalDetector();
        for (var i = 0; i < 24; i++) {
          expect(
            translated.update(
              arm(175, shift: i * 3),
              Duration(milliseconds: i * 80),
            ),
            isNull,
          );
        }
        final gap = PushupWideProposalDetector();
        for (var i = 0; i < 8; i++) {
          expect(
            gap.update(arm(i < 3 ? 175 : 90), Duration(milliseconds: i * 80)),
            isNull,
          );
        }
        expect(gap.update(empty, const Duration(milliseconds: 800)), isNull);
        expect(
          gap.update(arm(175), const Duration(milliseconds: 1200)),
          isNull,
        );
        gap.reset();
        expect(gap.update(arm(175), Duration.zero), isNull);
      },
    );
  });
}

class _FrameKneeFake extends KneeFrameClassifier {
  KneeFrameState state = KneeFrameState.occluded;
  int calls = 0;

  @override
  KneeFrameReading classify(PoseFrame frame) {
    calls++;
    return KneeFrameReading(state: state);
  }
}
