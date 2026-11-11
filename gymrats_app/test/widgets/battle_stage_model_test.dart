import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';

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
}
