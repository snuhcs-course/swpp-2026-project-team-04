import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/widgets/tutorial_person.dart';

/// The expected numbers come from the A12 design's own engine
/// (`figcore_c.js`, `cam3.js`), run with node on 2026-11-28.
void main() {
  Matcher near(Offset expected, {double within = 1e-3}) => predicate<Offset>(
    (p) =>
        (p.dx - expected.dx).abs() <= within &&
        (p.dy - expected.dy).abs() <= within,
    'within $within of $expected',
  );

  SideJoints side(TutorialSidePose pose, double k) =>
      TutorialSide.joints(pose, k);

  group('side view joints match the design\'s engine', () {
    test('a push-up at the top and the bottom', () {
      final top = side(TutorialSidePose.push, 0);
      expect(top.shoulder, near(const Offset(0.4, -33.2)));
      expect(top.hip, near(const Offset(27.552, -23.013)));
      expect(top.knee, near(const Offset(50.959, -14.231)));
      expect(top.ankle, near(const Offset(73.429, -5.8)));
      expect(top.elbow, near(const Offset(4.398, -16.163)));
      expect(top.head, near(const Offset(-7.839, -37.874)));
      expect(top.farShoulder, near(const Offset(3, -34.1)));
      final bottom = side(TutorialSidePose.push, 1);
      expect(bottom.shoulder, near(const Offset(-4.429, -10.5)));
      expect(bottom.elbow, near(const Offset(13.051, -9.662)));
      expect(bottom.head, near(const Offset(-13.678, -12.543)));
      expect(bottom.fist, isNull);
    });

    test('the grade pages\' push-ups (k 0.72, 0.95) and the knee push-up '
        '(k 0.9)', () {
      expect(
        side(TutorialSidePose.push, 0.72).shoulder,
        near(const Offset(-3.783, -16.856)),
      );
      expect(
        side(TutorialSidePose.push, 0.95).shoulder,
        near(const Offset(-4.352, -11.635)),
      );
      final knee = side(TutorialSidePose.kneel, 0.9);
      expect(knee.shoulder, near(const Offset(-7.856, -14.57)));
      expect(knee.hip, near(const Offset(20.398, -8.034)));
      expect(knee.knee, near(const Offset(44.755, -2.4)));
      expect(knee.ankle, near(const Offset(63.667, -17.176)));
      expect(knee.toe, near(const Offset(66.033, -12.726)));
      expect(knee.heel, near(const Offset(62.935, -18.553)));
    });

    test('a squat standing, half way, sitting and past it (k 1.12)', () {
      final stand = side(TutorialSidePose.squat, 0);
      expect(stand.shoulder, near(const Offset(-1.901, -81.912)));
      expect(stand.hip, near(const Offset(-0.384, -52.952)));
      expect(stand.wrist, near(const Offset(-20.457, -72.929)));
      expect(stand.elbow, near(const Offset(-7.032, -65.181)));
      expect(stand.farElbow, near(const Offset(-5.976, -66.558)));
      final half = side(TutorialSidePose.squat, 0.5);
      expect(half.hip, near(const Offset(9.634, -45.109)));
      expect(half.knee, near(const Offset(-7.416, -26.825)));
      final sit = side(TutorialSidePose.squat, 1);
      expect(sit.shoulder, near(const Offset(-7.234, -48.628)));
      expect(sit.hip, near(const Offset(11.792, -26.741)));
      expect(sit.head, near(const Offset(-11.3, -57.183)));
      final deep = side(TutorialSidePose.squat, 1.12);
      expect(deep.hip, near(const Offset(10.634, -21.593)));
      expect(deep.wrist, near(const Offset(-17.662, -22.731)));
    });
  });

  group('the poses behave', () {
    test('a push-up: the further down, the lower the shoulder; the hand '
        'stays planted', () {
      var last = double.negativeInfinity;
      for (var k = 0.0; k <= 1.0001; k += 0.1) {
        final joints = side(TutorialSidePose.push, k);
        expect(joints.shoulder.dy, greaterThan(last), reason: 'k $k');
        last = joints.shoulder.dy;
        expect(joints.wrist, near(const Offset(0, -1.3)));
        // The arm keeps its length: upper arm and forearm.
        expect(
          (joints.elbow - joints.shoulder).distance,
          moreOrLessEquals(TutorialBody.upperArm, epsilon: 1e-6),
        );
        expect(
          (joints.wrist - joints.elbow).distance,
          moreOrLessEquals(TutorialBody.forearm, epsilon: 1e-6),
        );
      }
    });

    test('a knee push-up: the knee is on the floor and the feet are up', () {
      for (final k in const [0.0, 0.5, 0.9, 1.0]) {
        final joints = side(TutorialSidePose.kneel, k);
        // The floor is y 0; the knee's round end (5.8 wide at the 1.75
        // scale, 3.3 units) reaches it.
        expect(joints.knee.dy, moreOrLessEquals(-2.4, epsilon: 1e-9));
        expect(joints.knee.dy + 5.8 / 2, greaterThanOrEqualTo(0.5));
        expect(joints.ankle.dy, lessThan(joints.knee.dy - 10), reason: 'k $k');
        expect(joints.toe.dy, lessThan(joints.knee.dy), reason: 'k $k');
      }
    });

    test('a squat: the further down, the lower the hips; the hands meet '
        'in front of the chest, the fist held', () {
      var last = double.negativeInfinity;
      for (var k = 0.0; k <= 1.12001; k += 0.08) {
        final joints = side(TutorialSidePose.squat, k);
        expect(joints.hip.dy, greaterThan(last), reason: 'k $k');
        last = joints.hip.dy;
        final fist = joints.fist!;
        expect(joints.clasp, isTrue);
        // In front of (left of) the shoulder, between shoulder and hip
        // height: at the chest.
        expect(fist.dx, lessThan(joints.shoulder.dx), reason: 'k $k');
        expect(fist.dy, greaterThan(joints.shoulder.dy), reason: 'k $k');
        expect(fist.dy, lessThan(joints.hip.dy), reason: 'k $k');
        // Both hands at the fist: the far wrist a step behind the near one.
        expect((joints.farWrist - joints.wrist).distance, lessThan(2));
        expect((fist - joints.wrist).distance, lessThan(2));
      }
    });
  });

  test('the loop: push-up 2000 ms, squat 2400 ms, always from 0 to 1', () {
    for (final (ms, k) in const [
      (0.0, 0.0),
      (200.0, 0.0),
      (575.0, 0.5),
      (950.0, 1.0),
      (1100.0, 1.0),
      (1475.0, 0.5),
      (1850.0, 0.0),
      (2575.0, 0.5),
    ]) {
      expect(
        TutorialSide.phase(ms, squat: false),
        moreOrLessEquals(k, epsilon: 1e-6),
        reason: '$ms',
      );
    }
    for (final (ms, k) in const [
      (250.0, 0.0),
      (675.0, 0.5),
      (1100.0, 1.0),
      (1725.0, 0.5),
      (2150.0, 0.0),
    ]) {
      expect(
        TutorialSide.phase(ms, squat: true),
        moreOrLessEquals(k, epsilon: 1e-6),
        reason: '$ms',
      );
    }
    for (var ms = -500.0; ms < 6000; ms += 37) {
      for (final squat in const [false, true]) {
        final k = TutorialSide.phase(ms, squat: squat);
        expect(k, inInclusiveRange(0, 1), reason: '$ms $squat');
      }
    }
    expect(
      TutorialSide.loopOf(squat: false),
      const Duration(milliseconds: 2000),
    );
    expect(
      TutorialSide.loopOf(squat: true),
      const Duration(milliseconds: 2400),
    );
  });

  test('placing: the width\'s middle at the given x, the floor at the given '
      'y, scaled', () {
    final top = side(TutorialSidePose.push, 0);
    expect(TutorialSide.middleOf(top), moreOrLessEquals(30.665, epsilon: 1e-3));
    expect(
      TutorialSide.middleOf(side(TutorialSidePose.squat, 0)),
      moreOrLessEquals(-8.832, epsilon: 1e-3),
    );
    final placed = TutorialSide.place(
      top,
      scale: 1.75,
      centerX: 110,
      floorY: 186,
    );
    expect(
      placed.ankle,
      near(Offset(110 + (73.429 - 30.665) * 1.75, 186 - 5.8 * 1.75)),
    );
    expect(placed.look, top.look);
    // A given middle (page 1 keeps the top pose's) wins over the pose's own.
    final bottom = TutorialSide.place(
      side(TutorialSidePose.push, 1),
      scale: 1,
      centerX: 0,
      floorY: 0,
      middle: 30.665,
    );
    expect(bottom.ankle.dx, moreOrLessEquals(73.429 - 30.665, epsilon: 1e-3));
  });

  test('the silhouette: pieces for each part, the clasp drawn as a fist', () {
    final push = TutorialSide.shapes(side(TutorialSidePose.push, 0), 1.75);
    // Hip-knee-ankle: two bars and three ends; heel-toe: one and two.
    expect(push.leg, hasLength(2 + 3 + 1 + 2));
    expect(push.farArm, hasLength(2 + 3 + 1 + 2));
    // Shoulder-elbow-wrist, wrist-fingertip, the shoulder's round.
    expect(push.arm, hasLength(2 + 3 + 1 + 2 + 1));
    expect(push.torso, hasLength(1));
    expect(
      push.head.single.getBounds().width,
      moreOrLessEquals(2 * TutorialBody.headRadius * 1.75, epsilon: 1e-6),
    );
    final squat = TutorialSide.shapes(side(TutorialSidePose.squat, 1), 1.75);
    // The hands held: the far arm ends at the wrist, the near one in a fist.
    expect(squat.farArm, hasLength(2 + 3));
    expect(squat.arm, hasLength(2 + 3 + 1 + 1));
    // The torso spans the shoulder to the hip.
    final joints = side(TutorialSidePose.squat, 1);
    final torso = squat.torso.single.getBounds();
    expect(
      torso.contains(Offset.lerp(joints.shoulder, joints.hip, 0.5)!),
      isTrue,
    );
  });

  group('the camera\'s front view', () {
    test('a push-up\'s shoulder line goes from 156 down to 238, as in the '
        'design (201.1 half way, k 0.55)', () {
      expect(TutorialFront.push(0).lineY, 156);
      expect(TutorialFront.push(0.55).lineY, moreOrLessEquals(201.1));
      expect(TutorialFront.push(1).lineY, 238);
      expect(TutorialFront.push(1, knee: true).lineY, 238);
      expect(TutorialFront.push(1).kneeY, isNull);
      // The knees down: the shins and feet lift behind the hips, above
      // where the straight legs' feet are.
      final kneeFeet = TutorialFront.push(1, knee: true).far;
      final legFeet = TutorialFront.push(1).far;
      double top(List<Path> pieces) =>
          pieces.map((p) => p.getBounds().top).reduce((a, b) => a < b ? a : b);
      expect(top(kneeFeet), lessThan(top(legFeet)));
    });

    test('a squat\'s hip and knee lines, as in the design: standing 190 / '
        '258, half way (k 0.45) 217 / 269.7, sitting 250 / 284', () {
      for (final (k, hip, knee) in const [
        (0.0, 190.0, 258.0),
        (0.45, 217.0, 269.7),
        (1.0, 250.0, 284.0),
      ]) {
        final figure = TutorialFront.squat(k);
        expect(figure.lineY, moreOrLessEquals(hip, epsilon: 1e-9));
        expect(figure.kneeY, moreOrLessEquals(knee, epsilon: 1e-9));
        expect(figure.arms, isNotEmpty);
        expect(figure.clasp, isNotNull);
      }
    });

    test('the setup\'s two people fill the camera box', () {
      for (final figure in [
        TutorialFront.setupPush(),
        TutorialFront.setupStand(),
      ]) {
        final all = [...figure.far, ...figure.belly, ...figure.body];
        final bounds = all
            .map((p) => p.getBounds())
            .reduce((a, b) => a.expandToInclude(b));
        expect(
          (Offset.zero & TutorialFront.box).contains(bounds.center),
          isTrue,
        );
        expect(bounds.height, greaterThan(TutorialFront.box.height * 0.7));
      }
      expect(TutorialFront.setupStand().clasp, isNotNull);
      expect(TutorialFront.setupPush().lineY, isNull);
    });
  });
}
