import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/squat_demo_judge.dart';

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
