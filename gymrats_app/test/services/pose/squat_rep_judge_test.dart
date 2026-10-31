import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/pose/exercise_judge.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/squat_rep_judge.dart';

PoseFrame pose(double hip, {bool oneSide = false}) {
  final points = <BodyLandmark, Keypoint>{};
  void add(BodyLandmark id, double y) {
    points[id] = Keypoint(landmark: id, x: 100, y: y, likelihood: .99);
  }

  for (final left in oneSide ? [true] : [true, false]) {
    add(left ? BodyLandmark.leftHip : BodyLandmark.rightHip, hip);
    add(left ? BodyLandmark.leftKnee : BodyLandmark.rightKnee, 300);
    add(left ? BodyLandmark.leftAnkle : BodyLandmark.rightAnkle, 400);
  }
  return PoseFrame(imageWidth: 400, imageHeight: 600, keypoints: points);
}

void main() {
  test('standing, deep squat and standing count exactly one rep', () {
    var now = Duration.zero;
    final judge = SquatRepJudge(clock: () => now);
    judge.update(pose(200));
    now += const Duration(milliseconds: 300);
    expect(judge.update(pose(200)).snapshot.phase, RepPhase.up);
    now += const Duration(milliseconds: 100);
    judge.update(pose(230));
    now += const Duration(milliseconds: 100);
    expect(judge.update(pose(280)).snapshot.phase, RepPhase.bottom);
    now += const Duration(milliseconds: 150);
    final rep = judge.update(pose(200, oneSide: true)).event;
    expect(rep?.valid, isTrue);
    expect(rep?.index, 1);
    expect(rep?.maxDepth, closeTo(.8, .001));
    now += const Duration(milliseconds: 100);
    expect(judge.update(pose(200)).event, isNull);
  });
  test('a shallow squat is rejected and small movement is ignored', () {
    var now = Duration.zero;
    final judge = SquatRepJudge(clock: () => now);
    judge.update(pose(200));
    now += const Duration(milliseconds: 300);
    judge.update(pose(200));
    now += const Duration(milliseconds: 100);
    judge.update(pose(230));
    now += const Duration(milliseconds: 100);
    judge.update(pose(250));
    now += const Duration(milliseconds: 150);
    expect(judge.update(pose(200)).event?.reason, RejectReason.shallowSquat);
  });
  test('long tracking loss abandons the attempt', () {
    var now = Duration.zero;
    final judge = SquatRepJudge(clock: () => now);
    judge.update(pose(200));
    now += const Duration(milliseconds: 300);
    judge.update(pose(200));
    now += const Duration(milliseconds: 100);
    judge.update(pose(280));
    now += const Duration(milliseconds: 600);
    expect(judge.update(pose(200)).event, isNull);
  });

  test('descending again before standing rejects the incomplete rep', () {
    var now = Duration.zero;
    final judge = SquatRepJudge(clock: () => now);
    judge.update(pose(200));
    now += const Duration(milliseconds: 300);
    judge.update(pose(200));
    now += const Duration(milliseconds: 100);
    judge.update(pose(230));
    now += const Duration(milliseconds: 100);
    judge.update(pose(280));
    now += const Duration(milliseconds: 100);
    judge.update(pose(235));
    now += const Duration(milliseconds: 100);
    final event = judge.update(pose(270)).event;
    expect(event?.reason, RejectReason.standUpFully);
    expect(event?.valid, isFalse);
  });

  test('reset and abandon preserve the expected repetition index', () {
    var now = Duration.zero;
    final judge = SquatRepJudge(clock: () => now);
    void advance(int ms) => now += Duration(milliseconds: ms);
    judge.update(pose(200));
    advance(300);
    judge.update(pose(200));
    advance(100);
    judge.update(pose(230));
    advance(100);
    judge.update(pose(280));
    advance(150);
    expect(judge.update(pose(200)).event?.index, 1);
    judge.abandon();
    advance(100);
    judge.update(pose(200));
    advance(300);
    judge.update(pose(200));
    advance(100);
    judge.update(pose(230));
    advance(100);
    judge.update(pose(280));
    advance(150);
    expect(judge.update(pose(200)).event?.index, 2);
    judge.reset();
    advance(100);
    judge.update(pose(200));
    advance(300);
    judge.update(pose(200));
    advance(100);
    judge.update(pose(230));
    advance(100);
    judge.update(pose(280));
    advance(150);
    expect(judge.update(pose(200)).event?.index, 1);
  });
  test(
    'factory and exercise-specific rejection lists preserve push-up defaults',
    () {
      expect(judgeFor(ExerciseType.squat), isA<SquatRepJudge>());
      expect(
        judgeFor(ExerciseType.pushUp).passDepth,
        RepJudge().config.bottomDepth,
      );
      expect(
        RejectReason.forExercise(ExerciseType.pushUp),
        isNot(contains(RejectReason.shallowSquat)),
      );
      expect(
        RejectReason.forExercise(ExerciseType.squat),
        contains(RejectReason.phoneMoved),
      );
    },
  );
}
