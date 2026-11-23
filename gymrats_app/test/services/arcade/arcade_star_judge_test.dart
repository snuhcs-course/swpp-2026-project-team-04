import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_ai_level.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/arcade/arcade_star_judge.dart';

ArcadeFightStage _fight(int number) =>
    ArcadeCatalog.stage(number) as ArcadeFightStage;
ArcadeBossStage _boss(int number) =>
    ArcadeCatalog.stage(number) as ArcadeBossStage;
ArcadeHoldStage _hold(int number) =>
    ArcadeCatalog.stage(number) as ArcadeHoldStage;

const _won = ArcadeRound(won: true);
const _lost = ArcadeRound(won: false);
const _ko = ArcadeRound(won: true, wonByKo: true);

ArcadeStars _stars(String lit) =>
    ArcadeStars(lit[0] == '★', lit[1] == '★', lit[2] == '★');

void main() {
  group('a fight (spec 5)', () {
    // Stage 1: 무효 3회 이하. Stage 2: 콤보 4 이상. Stage 4: Excellent 2회.
    test('a loss lights no star, whatever else happened', () {
      expect(
        ArcadeStarJudge.fight(
          _fight(1),
          const ArcadeRound(won: false, rejects: 0, longestCombo: 9),
        ),
        ArcadeStars.none,
      );
      expect(ArcadeStarJudge.fight(_fight(2), _lost), ArcadeStars.none);
    });

    test('a win alone lights the first star', () {
      expect(
        ArcadeStarJudge.fight(_fight(2), const ArcadeRound(won: true)),
        _stars('★☆☆'),
      );
    });

    test('a win that meets the condition lights the second too', () {
      expect(
        ArcadeStarJudge.fight(
          _fight(2),
          const ArcadeRound(won: true, longestCombo: 4),
        ),
        _stars('★★☆'),
      );
    });

    test('a KO win without the condition lights the first and third', () {
      expect(ArcadeStarJudge.fight(_fight(2), _ko), _stars('★☆★'));
    });

    test('a KO win that meets the condition lights all three', () {
      expect(
        ArcadeStarJudge.fight(
          _fight(4),
          const ArcadeRound(won: true, wonByKo: true, excellent: 2),
        ),
        _stars('★★★'),
      );
    });

    test('무효 n회 이하: n and fewer meet it, n + 1 does not', () {
      final stage = _fight(1);
      expect(stage.stars[1].n, 3);
      bool meets(int rejects) => ArcadeStarJudge.fight(
        stage,
        ArcadeRound(won: true, rejects: rejects),
      ).second;
      expect(meets(2), isTrue);
      expect(meets(3), isTrue);
      expect(meets(4), isFalse);
    });

    test('무효 0회 on 4F: no rejected rep at all', () {
      final stage = _fight(19);
      bool meets(int rejects) => ArcadeStarJudge.fight(
        stage,
        ArcadeRound(won: true, rejects: rejects),
      ).second;
      expect(meets(0), isTrue);
      expect(meets(1), isFalse);
    });

    test('콤보 n 이상: n and more meet it, n - 1 does not', () {
      final stage = _fight(2);
      expect(stage.stars[1].n, 4);
      bool meets(int combo) => ArcadeStarJudge.fight(
        stage,
        ArcadeRound(won: true, longestCombo: combo),
      ).second;
      expect(meets(3), isFalse);
      expect(meets(4), isTrue);
      expect(meets(5), isTrue);
    });

    test('Excellent n회: n and more meet it, n - 1 does not', () {
      final stage = _fight(4);
      expect(stage.stars[1].n, 2);
      bool meets(int excellent) => ArcadeStarJudge.fight(
        stage,
        ArcadeRound(won: true, excellent: excellent),
      ).second;
      expect(meets(1), isFalse);
      expect(meets(2), isTrue);
      expect(meets(3), isTrue);
    });

    test('a second star that is not a fight condition throws', () {
      const stage = ArcadeFightStage(
        number: 1,
        floor: 1,
        slot: 1,
        character: 'bot',
        exercise: ExerciseType.pushUp,
        aiLevel: ArcadeAiLevel.lv1,
        stars: [
          ArcadeStar(ArcadeStarKind.win, '승리'),
          ArcadeStar(ArcadeStarKind.holdSeconds, '15초', n: 15),
          ArcadeStar(ArcadeStarKind.koWin, 'KO 승리'),
        ],
      );
      expect(() => ArcadeStarJudge.fight(stage, _won), throwsArgumentError);
    });
  });

  group('a boss match (spec 5)', () {
    // Stage 6: Excellent 합계 6회.
    final stage = _boss(6);

    test('losing R1 lights no star: there is no R2', () {
      expect(ArcadeStarJudge.boss(stage, _lost, null), ArcadeStars.none);
      expect(ArcadeStarJudge.boss(stage, _ko, null), ArcadeStars.none);
    });

    test('losing R2 lights no star', () {
      expect(ArcadeStarJudge.boss(stage, _ko, _lost), ArcadeStars.none);
    });

    test('winning both lights the first star', () {
      expect(ArcadeStarJudge.boss(stage, _won, _won), _stars('★☆☆'));
    });

    test('the excellent reps of both rounds count together, from n', () {
      ArcadeStars play(int first, int second) => ArcadeStarJudge.boss(
        stage,
        ArcadeRound(won: true, excellent: first),
        ArcadeRound(won: true, excellent: second),
      );
      expect(stage.stars[1].n, 6);
      expect(play(3, 2).second, isFalse);
      expect(play(3, 3).second, isTrue);
      expect(play(6, 0).second, isTrue);
      expect(play(4, 3).second, isTrue);
    });

    test('a KO in one round only is no third star', () {
      expect(ArcadeStarJudge.boss(stage, _ko, _won), _stars('★☆☆'));
      expect(ArcadeStarJudge.boss(stage, _won, _ko), _stars('★☆☆'));
    });

    test('KO in both rounds lights the third star', () {
      expect(ArcadeStarJudge.boss(stage, _ko, _ko), _stars('★☆★'));
    });

    test('all three', () {
      const round = ArcadeRound(won: true, wonByKo: true, excellent: 3);
      expect(ArcadeStarJudge.boss(stage, round, round), _stars('★★★'));
    });
  });

  group('a hold (spec 5)', () {
    // Stage 3: 15초, 20초, 30초.
    final stage = _hold(3);
    ArcadeStars held(int milliseconds) =>
        ArcadeStarJudge.hold(stage, Duration(milliseconds: milliseconds));

    test('each star lights at its seconds, not a moment before', () {
      expect(held(14999), ArcadeStars.none);
      expect(held(15000), _stars('★☆☆'));
      expect(held(19999), _stars('★☆☆'));
      expect(held(20000), _stars('★★☆'));
      expect(held(29999), _stars('★★☆'));
      expect(held(30000), _stars('★★★'));
    });

    test('ended by two warnings: the time held so far counts (spec 11.1)', () {
      final cleared = held(17000);
      expect(cleared, _stars('★☆☆'));
      expect(cleared.cleared, isTrue);
      final failed = held(9000);
      expect(failed, ArcadeStars.none);
      expect(failed.cleared, isFalse);
    });

    test('uses each stage\'s own seconds', () {
      final chair = _hold(23); // 25초, 35초, 45초.
      expect(
        ArcadeStarJudge.hold(chair, const Duration(seconds: 30)),
        _stars('★☆☆'),
      );
      expect(ArcadeStarJudge.hold(chair, chair.endsAt), _stars('★★★'));
    });
  });

  group('a round from a battle result', () {
    const passDepth = 1.1;
    final excellentDepth = battleRules.excellentDepthRatio * passDepth;

    RepRecord rep(
      int index,
      int milliseconds, {
      bool valid = true,
      double? depth,
    }) => RepRecord(
      index: index,
      valid: valid,
      at: Duration(milliseconds: milliseconds),
      reason: valid ? null : RejectReason.tooFast,
      maxDepth: valid ? (depth ?? 1.4) : null,
    );

    // A combo of three, a rejected rep, then a combo of two; two excellent.
    final reps = [
      rep(1, 3000, depth: excellentDepth),
      rep(2, 4000),
      rep(3, 5000, depth: excellentDepth),
      rep(4, 6000, valid: false),
      rep(5, 7000),
      rep(6, 8000),
    ];

    BattleResult result({
      MatchOutcome outcome = MatchOutcome.win,
      GameEnd end = GameEnd.timeUp,
      bool withForm = true,
    }) => BattleResult(
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: 'RepBot', isBot: true),
      ),
      myReps: 5,
      myInvalidReps: 1,
      opponentReps: 4,
      endedAt: DateTime(2026, 11, 23),
      end: end,
      decidedOutcome: outcome,
      form: withForm
          ? FormReport(
              endedAt: DateTime(2026, 11, 23),
              opponentName: 'RepBot',
              roundLength: battleDuration,
              reps: reps,
              samples: const [],
            )
          : null,
    );

    test('reads the win, the rejected reps, the combo and excellent reps', () {
      final round = ArcadeRound.fromBattle(
        result(),
        passDepth: passDepth,
        rules: battleRules,
      );
      expect(round.won, isTrue);
      expect(round.wonByKo, isFalse);
      expect(round.rejects, 1);
      expect(round.longestCombo, 3);
      expect(round.excellent, 2);
    });

    test('a win ended by KO is a KO win', () {
      final round = ArcadeRound.fromBattle(
        result(end: GameEnd.ko),
        passDepth: passDepth,
        rules: battleRules,
      );
      expect(round.wonByKo, isTrue);
    });

    test('a loss by KO is no win and no KO win', () {
      final round = ArcadeRound.fromBattle(
        result(outcome: MatchOutcome.lose, end: GameEnd.ko),
        passDepth: passDepth,
        rules: battleRules,
      );
      expect(round.won, isFalse);
      expect(round.wonByKo, isFalse);
      expect(round.rejects, 1);
    });

    test('a draw is no win', () {
      final round = ArcadeRound.fromBattle(
        result(outcome: MatchOutcome.draw),
        passDepth: passDepth,
        rules: battleRules,
      );
      expect(round.won, isFalse);
    });

    test('the floor\'s rules give the same combo and grades on 3F and 4F', () {
      for (final floor in [3, 4]) {
        final round = ArcadeRound.fromBattle(
          result(),
          passDepth: passDepth,
          rules: ArcadeCatalog.floor(floor).rules,
        );
        expect((round.longestCombo, round.excellent), (3, 2));
      }
    });

    test('a result without its reps has no combo and no excellent rep', () {
      final round = ArcadeRound.fromBattle(
        result(withForm: false),
        passDepth: passDepth,
        rules: battleRules,
      );
      expect(round.won, isTrue);
      expect((round.longestCombo, round.excellent), (0, 0));
    });

    test('feeds the stars of the stage it was played in', () {
      final round = ArcadeRound.fromBattle(
        result(),
        passDepth: passDepth,
        rules: battleRules,
      );
      // Stage 4 asks for 2 excellent reps; stage 2 for a combo of 4.
      expect(ArcadeStarJudge.fight(_fight(4), round), _stars('★★☆'));
      expect(ArcadeStarJudge.fight(_fight(2), round), _stars('★☆☆'));
    });
  });
}
