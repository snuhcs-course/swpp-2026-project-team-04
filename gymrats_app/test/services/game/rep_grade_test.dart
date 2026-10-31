import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/game/player_game_score.dart';
import 'package:gymrats_app/services/game/rep_grade.dart';

import '../../support/game_fakes.dart';

const _goLower = RejectReason.insufficientDepth;

RepRecord _record({
  RejectReason? reason,
  double? maxDepth,
  double? minElbowAngle,
}) => RepRecord(
  index: 1,
  valid: reason == null,
  at: const Duration(seconds: 3),
  reason: reason,
  maxDepth: maxDepth,
  minElbowAngle: minElbowAngle,
);

void main() {
  group('gradeOf', () {
    GameGrade? grade(RepEvent rep, {double passDepth = 1.1}) =>
        battleRules.gradeOf(rep, passDepth: passDepth);

    test('a valid rep goes by its depth and its pass depth', () {
      expect(grade(gameRep(3, maxDepth: 1.4)), GameGrade.good);
      expect(grade(gameRep(3, maxDepth: 1.76)), GameGrade.excellent);
      expect(
        grade(gameRep(3, maxDepth: 1.2), passDepth: .75),
        GameGrade.excellent,
      );
      expect(grade(gameRep(3)), GameGrade.good);
    });

    test('a valid rep is never average, however bent the elbows', () {
      final rep = gameRep(3, minElbowAngle: 90);
      expect(battleRules.earnsAverage(rep), isFalse);
      expect(grade(rep), GameGrade.good);
    });

    test('Go lower with bent elbows is average; without them, nothing', () {
      expect(
        grade(gameRep(3, reason: _goLower, minElbowAngle: 105)),
        GameGrade.average,
      );
      expect(grade(gameRep(3, reason: _goLower, minElbowAngle: 106)), isNull);
      expect(grade(gameRep(3, reason: _goLower)), isNull);
    });

    test('another reason is nothing', () {
      final rep = gameRep(3, reason: RejectReason.kneesDown, minElbowAngle: 90);
      expect(battleRules.earnsAverage(rep), isFalse);
      expect(grade(rep), isNull);
    });

    test('with Average off it is nothing too', () {
      final rep = gameRep(3, reason: _goLower, minElbowAngle: 90);
      const off = BattleRules(averagePoints: 0);
      expect(off.earnsAverage(rep), isFalse);
      expect(off.gradeOf(rep, passDepth: 1.1), isNull);
    });
  });

  group('addRep', () {
    const at = Duration(seconds: 3);

    test('sends each grade its own way', () {
      final score = PlayerGameScore();
      expect(score.addRep(GameGrade.good, at)!.points, 10);
      expect(score.combo, 1);
      expect(score.addRep(GameGrade.excellent, at)!.points, 20);
      expect(score.combo, 2);
      expect(score.validReps, 2);

      final average = score.addRep(GameGrade.average, at)!;
      expect(average.grade, GameGrade.average);
      expect(average.points, 5);
      expect(score.combo, 0);
      expect(score.validReps, 2);
      expect(score.points, 35);
    });

    test('no grade earns nothing and breaks the combo', () {
      final score = PlayerGameScore();
      score.addRep(GameGrade.good, at);
      expect(score.addRep(null, at), isNull);
      expect(score.combo, 0);
      expect(score.points, 10);
    });
  });

  group('GameGradeCounts', () {
    test('counts each grade, and leaves out reps that earned nothing', () {
      final counts = GameGradeCounts.ofReps([
        _record(maxDepth: 1.9),
        _record(maxDepth: 1.8),
        _record(maxDepth: 1.4),
        _record(),
        _record(maxDepth: 1.4),
        _record(reason: _goLower, minElbowAngle: 90),
        _record(reason: _goLower, minElbowAngle: 120),
        _record(reason: _goLower),
        _record(reason: RejectReason.kneesDown, minElbowAngle: 90),
      ], passDepth: 1.1);
      expect(counts.excellent, 2);
      expect(counts.good, 3);
      expect(counts.average, 1);
    });

    test('goes by the pass depth and the rules it is given', () {
      final reps = [
        _record(maxDepth: 1.2),
        _record(reason: _goLower, minElbowAngle: 90),
      ];
      final squat = GameGradeCounts.ofReps(reps, passDepth: .75);
      expect(squat.excellent, 1);
      final off = GameGradeCounts.ofReps(
        reps,
        passDepth: 1.1,
        rules: const BattleRules(averagePoints: 0),
      );
      expect(off.excellent, 0);
      expect(off.good, 1);
      expect(off.average, 0);
    });

    test('no reps count nothing', () {
      final counts = GameGradeCounts.ofReps(const [], passDepth: 1.1);
      expect((counts.excellent, counts.good, counts.average), (0, 0, 0));
    });
  });
}
