import '../../models/pose_frame.dart';
import 'exercise_judge.dart';
import 'rep_judge.dart';

class PushUpJudgeAdapter implements ExerciseRepJudge {
  PushUpJudgeAdapter(this.judge);
  final RepJudge judge;
  @override
  RepUpdate update(PoseFrame frame) => judge.update(frame);
  @override
  void reset() => judge.reset();
  @override
  void abandon() => judge.abandon();
  @override
  double get minLikelihood => judge.config.minLikelihood;
  @override
  double get passDepth => judge.config.bottomDepth;
}
