import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/services/game/rep_grade.dart';
import 'package:gymrats_app/services/pose/squat_demo_judge.dart';
import 'package:gymrats_app/services/pose/squat_rep_judge.dart';

PoseFrame pose(double hip, {double knee = 300, double ankle = 400}) {
  final points = <BodyLandmark, Keypoint>{};
  void add(BodyLandmark landmark, double x, double y) {
    points[landmark] = Keypoint(
      landmark: landmark,
      x: x,
      y: y,
      likelihood: .99,
    );
  }

  for (final left in [true, false]) {
    final x = left ? 120.0 : 220.0;
    add(left ? BodyLandmark.leftHip : BodyLandmark.rightHip, x, hip);
    add(left ? BodyLandmark.leftKnee : BodyLandmark.rightKnee, x, knee);
    add(left ? BodyLandmark.leftAnkle : BodyLandmark.rightAnkle, x, ankle);
  }
  return PoseFrame(imageWidth: 400, imageHeight: 600, keypoints: points);
}

void main() {
  test('one rep records peak depth and earns Good or Excellent on its own', () {
    var now = Duration.zero;
    final judge = SquatDemoJudge(clock: () => now);
    void feed(double hip) {
      judge.update(pose(hip));
      now += const Duration(milliseconds: 100);
    }

    feed(220);
    feed(280);
    feed(260);
    final good = judge.update(pose(220)).event!;
    expect(good.maxDepth, closeTo(.75, .001));
    expect(
      battleRules.gradeOf(good, passDepth: judge.passDepth),
      GameGrade.good,
    );
    now += const Duration(milliseconds: 100);
    feed(320);
    feed(280);
    final excellent = judge.update(pose(220)).event!;
    expect(excellent.maxDepth, closeTo(1.25, .001));
    expect(
      battleRules.gradeOf(excellent, passDepth: judge.passDepth),
      GameGrade.excellent,
    );
    now += const Duration(milliseconds: 100);
    feed(280);
    final next = judge.update(pose(220)).event!;
    expect(next.maxDepth, closeTo(.75, .001));
    expect(
      battleRules.gradeOf(next, passDepth: judge.passDepth),
      GameGrade.good,
    );
  });
  test('abandon and reset clear the previous depth and require a fresh standing pose', () {
    var now = Duration.zero;
    final judge = SquatDemoJudge(clock: () => now);
    judge.update(pose(220));
    judge.update(pose(320));
    judge.abandon();
    expect(judge.update(pose(220)).event, isNull);
    now += const Duration(milliseconds: 100);
    judge.update(pose(280));
    final after = judge.update(pose(220)).event!;
    expect(after.maxDepth, closeTo(.75, .001));
    judge.reset();
    expect(judge.update(pose(280)).event, isNull);
    expect(judge.update(pose(220)).event, isNull);
  });
  test('relative depth is unchanged when the image scale changes', () {
    double? measure(double scale) {
      var now = Duration.zero;
      final judge = SquatDemoJudge(clock: () => now);
      PoseFrame at(double hip) =>
          pose(hip * scale, knee: 300 * scale, ankle: 400 * scale);
      judge.update(at(220));
      now += const Duration(milliseconds: 100);
      judge.update(at(320));
      now += const Duration(milliseconds: 100);
      return judge.update(at(220)).event?.maxDepth;
    }

    expect(measure(1), closeTo(1.25, .001));
    expect(measure(2), closeTo(1.25, .001));
  });

  test('demo uses the same scoring threshold as the squat judge', () {
    expect(SquatDemoJudge().passDepth, SquatRepJudge().passDepth);
    expect(SquatDemoJudge().passDepth, .75);
  });
  test('one full squat counts once only after standing up', () {
    var now = Duration.zero;
    final judge = SquatDemoJudge(clock: () => now);
    final standing = judge.update(pose(220));
    expect(standing.event, isNull);
    expect(standing.snapshot.squatHipY, 220);
    expect(standing.snapshot.squatKneeY, 300);
    now += const Duration(milliseconds: 100);
    expect(judge.update(pose(305)).event, isNull);
    now += const Duration(milliseconds: 100);
    expect(judge.update(pose(305)).event, isNull);
    now += const Duration(milliseconds: 100);
    expect(judge.update(pose(220)).event?.index, 1);
    now += const Duration(milliseconds: 100);
    expect(judge.update(pose(220)).event, isNull);
  });

  test('shallow movement and prolonged tracking loss do not count', () {
    var now = Duration.zero;
    final judge = SquatDemoJudge(clock: () => now);
    judge.update(pose(220));
    now += const Duration(milliseconds: 100);
    expect(judge.update(pose(250)).event, isNull);
    now += const Duration(milliseconds: 100);
    expect(judge.update(pose(270)).event, isNull);
    now += const Duration(milliseconds: 100);
    expect(judge.update(pose(220)).event, isNull);
    now += const Duration(milliseconds: 100);
    judge.update(pose(305));
    now += const Duration(milliseconds: 100);
    judge.update(const PoseFrame.empty(imageWidth: 400, imageHeight: 600));
    now += const Duration(milliseconds: 1300);
    expect(judge.update(pose(220)).event, isNull);
  });

  test(
    'a squat near knee height counts without repeated counts at the bottom',
    () {
      var now = Duration.zero;
      final judge = SquatDemoJudge(clock: () => now);
      judge.update(pose(220));
      now += const Duration(milliseconds: 100);
      expect(judge.update(pose(280)).event, isNull);
      now += const Duration(milliseconds: 100);
      expect(judge.update(pose(280)).event, isNull);
      now += const Duration(milliseconds: 100);
      expect(judge.update(pose(220)).event?.index, 1);
    },
  );

  test(
    'one temporarily hidden leg and a brief missing frame preserve the rep',
    () {
      var now = Duration.zero;
      final judge = SquatDemoJudge(clock: () => now);
      judge.update(pose(220));
      now += const Duration(milliseconds: 100);
      final full = pose(305);
      final partial = PoseFrame(
        imageWidth: full.imageWidth,
        imageHeight: full.imageHeight,
        keypoints: Map.of(full.keypoints)..remove(BodyLandmark.leftAnkle),
      );
      judge.update(partial);
      now += const Duration(milliseconds: 100);
      judge.update(const PoseFrame.empty(imageWidth: 400, imageHeight: 600));
      now += const Duration(milliseconds: 100);
      expect(judge.update(pose(220)).event?.index, 1);
    },
  );
}
