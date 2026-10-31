import '../../models/exercise_type.dart';
import '../../models/pose_frame.dart';
import 'rep_judge.dart';
import 'push_up_judge_adapter.dart';
import 'squat_rep_judge.dart';

abstract interface class ExerciseRepJudge {
  RepUpdate update(PoseFrame frame);
  void reset();
  void abandon();
  double get minLikelihood;
  double get passDepth;
}

ExerciseRepJudge judgeFor(ExerciseType exercise, {RepClock? clock}) =>
    switch (exercise) {
      ExerciseType.pushUp => PushUpJudgeAdapter(RepJudge(clock: clock)),
      ExerciseType.squat => SquatRepJudge(clock: clock),
    };
