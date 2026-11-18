import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/models/feedback_goal.dart';
import 'package:gymrats_app/services/feedback/goal_progress.dart';

void main() {
  group('BattleSide', () {
    test('the other side of me is the opponent, and back', () {
      expect(BattleSide.me.other, BattleSide.opponent);
      expect(BattleSide.opponent.other, BattleSide.me);
    });
  });

  group('BattleStageEvent', () {
    test('good and excellent count as valid reps; average and none do not', () {
      BattleStageEvent rep(GameGrade? grade) =>
          BattleStageEvent(side: BattleSide.me, grade: grade);
      expect(rep(GameGrade.good).counted, isTrue);
      expect(rep(GameGrade.excellent).counted, isTrue);
      expect(rep(GameGrade.average).counted, isFalse);
      expect(rep(null).counted, isFalse);
    });

    test('a rep earns nothing and ends nothing unless told', () {
      const rep = BattleStageEvent(side: BattleSide.opponent, grade: null);
      expect(rep.points, 0);
      expect(rep.combo, 0);
      expect(rep.fever, isFalse);
      expect(rep.reason, isNull);
      expect(rep.knockout, isFalse);
    });
  });

  group('BattleStageEnd', () {
    test('is decided, with no winner, unless told', () {
      const end = BattleStageEnd(kind: BattleEndKind.timeUp);
      expect(end.decided, isTrue);
      expect(end.winner, isNull);
    });
  });

  group('the reject sign of a reason', () {
    test('has the design\'s pictogram number and short label', () {
      expect(
        {
          for (final reason in RejectReason.values)
            reason: (reason.signIcon, reason.signLabel),
        },
        {
          RejectReason.insufficientDepth: (0, '더 깊게'),
          RejectReason.incompleteExtension: (1, '팔 펴기'),
          RejectReason.shouldersNotLevel: (2, '어깨 수평'),
          RejectReason.kneesDown: (3, '무릎 떼기'),
          RejectReason.armsStraight: (4, '팔 굽히기'),
          RejectReason.bellyDown: (5, '배 떼기'),
          RejectReason.notFloorPushUp: (6, '바닥에서'),
          RejectReason.phoneMoved: (7, '폰 고정'),
          RejectReason.shallowSquat: (8, '더 앉기'),
          RejectReason.standUpFully: (9, '끝까지 서기'),
          RejectReason.tooFast: (null, '천천히'),
        },
      );
    });

    test('every reason a push-up or squat judge gives now has a picture', () {
      for (final exercise in ExerciseType.values) {
        for (final reason in RejectReason.forExercise(exercise)) {
          if (reason == RejectReason.tooFast) continue;
          expect(reason.signIcon, isNotNull, reason: reason.name);
        }
      }
    });

    test('no two reasons share a picture', () {
      final icons = RejectReason.values.map((r) => r.signIcon).nonNulls;
      expect(icons.toSet(), hasLength(icons.length));
      expect(icons.toSet(), {for (var i = 0; i < 10; i++) i});
    });
  });

  group('BattleStageState', () {
    const state = BattleStageState(
      phase: BattleStagePhase.playing,
      myName: 'A',
      opponentName: 'B',
      remaining: Duration(milliseconds: 7200),
      roundLength: Duration(seconds: 30),
      myScore: 40,
      opponentScore: 55,
    );

    test('the lead is negative while behind', () {
      expect(state.lead, -15);
    });

    test('the seconds left round up, as the clock shows them', () {
      expect(state.secondsLeft, 8);
      expect(
        const BattleStageState(
          phase: BattleStagePhase.playing,
          myName: 'A',
          opponentName: 'B',
          remaining: Duration(seconds: 30),
          roundLength: Duration(seconds: 30),
        ).secondsLeft,
        30,
      );
    });

    test('elapsed runs from 0 to 1 and stays inside', () {
      expect(state.elapsed, closeTo(22.8 / 30, 1e-9));
      BattleStageState at(Duration remaining, Duration length) =>
          BattleStageState(
            phase: BattleStagePhase.playing,
            myName: 'A',
            opponentName: 'B',
            remaining: remaining,
            roundLength: length,
          );
      expect(
        at(const Duration(seconds: 30), const Duration(seconds: 30)).elapsed,
        0,
      );
      expect(at(Duration.zero, const Duration(seconds: 30)).elapsed, 1);
      expect(
        at(const Duration(seconds: 40), const Duration(seconds: 30)).elapsed,
        0,
      );
      expect(at(Duration.zero, Duration.zero).elapsed, 0);
    });

    test('starts level, with nobody ready and no end', () {
      expect(state.barShare, 0.5);
      expect(state.fever, isFalse);
      expect(state.feverMultiplier, 2);
      expect(state.danger, isFalse);
      expect(state.meReady, isFalse);
      expect(state.opponentReady, isFalse);
      expect(state.countdown, isNull);
      expect(state.reconnecting, isFalse);
      expect(state.opponentDisconnected, isFalse);
      expect(state.end, isNull);
    });
  });

  group('BattleStageCue', () {
    test('two cues with the same parts are equal', () {
      const a = BattleStageCue(
        BattleCueKind.hit,
        side: BattleSide.me,
        grade: GameGrade.good,
      );
      const b = BattleStageCue(
        BattleCueKind.hit,
        side: BattleSide.me,
        grade: GameGrade.good,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const BattleStageCue(
            BattleCueKind.hit,
            side: BattleSide.opponent,
            grade: GameGrade.good,
          ),
        ),
      );
      expect(
        const BattleStageCue(BattleCueKind.countdown, number: 3),
        isNot(const BattleStageCue(BattleCueKind.countdown, number: 2)),
      );
    });

    test('reads as its parts', () {
      expect(
        const BattleStageCue(
          BattleCueKind.hit,
          side: BattleSide.me,
          grade: GameGrade.excellent,
        ).toString(),
        'hit me excellent',
      );
      expect(
        const BattleStageCue(BattleCueKind.countdown, number: 3).toString(),
        'countdown 3',
      );
      expect(const BattleStageCue(BattleCueKind.go).toString(), 'go');
    });
  });

  group('the goal (A11 spec 5)', () {
    test('withGoal keeps every other value of the state', () {
      const end = BattleStageEnd(
        kind: BattleEndKind.timeUp,
        winner: BattleSide.me,
        decided: false,
      );
      const state = BattleStageState(
        phase: BattleStagePhase.ended,
        myName: '나',
        opponentName: '너',
        remaining: Duration(seconds: 3),
        roundLength: Duration(seconds: 30),
        myScore: 120,
        opponentScore: 90,
        myReps: 12,
        opponentReps: 9,
        barShare: 0.7,
        fever: true,
        feverMultiplier: 3,
        danger: true,
        meReady: true,
        opponentReady: true,
        countdown: Duration(seconds: 2),
        reconnecting: true,
        opponentDisconnected: true,
        end: end,
      );
      const goal = GoalProgress(kind: GoalKind.reps, target: 20, value: 12);
      final withGoal = state.withGoal(goal);
      expect(withGoal.goal, goal);
      expect(withGoal.phase, state.phase);
      expect(withGoal.myName, state.myName);
      expect(withGoal.opponentName, state.opponentName);
      expect(withGoal.remaining, state.remaining);
      expect(withGoal.roundLength, state.roundLength);
      expect(withGoal.myScore, state.myScore);
      expect(withGoal.opponentScore, state.opponentScore);
      expect(withGoal.myReps, state.myReps);
      expect(withGoal.opponentReps, state.opponentReps);
      expect(withGoal.barShare, state.barShare);
      expect(withGoal.fever, state.fever);
      expect(withGoal.feverMultiplier, state.feverMultiplier);
      expect(withGoal.danger, state.danger);
      expect(withGoal.meReady, state.meReady);
      expect(withGoal.opponentReady, state.opponentReady);
      expect(withGoal.countdown, state.countdown);
      expect(withGoal.reconnecting, state.reconnecting);
      expect(withGoal.opponentDisconnected, state.opponentDisconnected);
      expect(withGoal.end, same(end));
      expect(withGoal.withGoal(null).goal, isNull);
      expect(state.goal, isNull);
    });

    test('reachingGoal marks the rep and keeps the rest of it', () {
      const rep = BattleStageEvent(
        side: BattleSide.me,
        grade: GameGrade.excellent,
        points: 30,
        combo: 4,
        fever: true,
        knockout: true,
      );
      expect(rep.reachesGoal, isFalse);
      final marked = rep.reachingGoal();
      expect(marked.reachesGoal, isTrue);
      expect(marked.side, rep.side);
      expect(marked.grade, rep.grade);
      expect(marked.points, rep.points);
      expect(marked.combo, rep.combo);
      expect(marked.fever, rep.fever);
      expect(marked.knockout, rep.knockout);
      const average = BattleStageEvent(
        side: BattleSide.me,
        grade: GameGrade.average,
        points: 5,
        reason: RejectReason.insufficientDepth,
      );
      expect(average.reachingGoal().reason, RejectReason.insufficientDepth);
    });
  });
}
