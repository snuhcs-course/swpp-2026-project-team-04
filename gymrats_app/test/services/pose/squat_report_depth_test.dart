import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/squat_rep_judge.dart';

PoseFrame pose(double hip, {bool oneSide = false}) => PoseFrame(
  imageWidth: 400,
  imageHeight: 600,
  keypoints: {
    for (final left in oneSide ? [true] : [true, false])
      for (final (id, y) in [
        (left ? BodyLandmark.leftHip : BodyLandmark.rightHip, hip),
        (left ? BodyLandmark.leftKnee : BodyLandmark.rightKnee, 300.0),
        (left ? BodyLandmark.leftAnkle : BodyLandmark.rightAnkle, 400.0),
      ])
        id: Keypoint(landmark: id, x: left ? 120 : 220, y: y, likelihood: .99),
  },
);

void main() {
  test('squat snapshots expose current depth and visible hip/knee guides', () {
    var now = Duration.zero;
    final judge = SquatRepJudge(
      clock: () => now,
      smoothingTau: Duration.zero,
      baselineTau: Duration.zero,
    );
    JudgeSnapshot feed(double hip, {bool oneSide = false}) {
      final result = judge.update(pose(hip, oneSide: oneSide));
      now += const Duration(milliseconds: 100);
      return result.snapshot;
    }

    final initial = feed(200);
    expect(initial.depth, isNull);
    expect(initial.squatHipY, 200);
    expect(initial.squatKneeY, 300);
    feed(200);
    feed(200);
    expect(feed(200).depth, 0);
    expect(feed(250).depth, closeTo(.5, .001));
    final bottom = feed(280, oneSide: true);
    expect(bottom.phase, RepPhase.bottom);
    expect(bottom.depth, closeTo(.8, .001));
    expect(bottom.squatHipY, 280);
    expect(bottom.squatKneeY, 300);
    expect(feed(250).depth, closeTo(.5, .001));
    expect(feed(200).depth, 0);
    final missing = judge.update(
      const PoseFrame.empty(imageWidth: 400, imageHeight: 600),
    );
    expect(missing.snapshot.depth, isNull);
    expect(missing.snapshot.squatHipY, isNull);
    expect(missing.snapshot.squatKneeY, isNull);
    judge.abandon();
    expect(feed(280).depth, isNull);
    judge.reset();
    expect(feed(280).depth, isNull);
  });
}
