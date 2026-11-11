import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/device/phone_tilt.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/viewmodels/battle_viewmodel.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_events.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';

import '../support/fakes.dart';
import '../support/game_fakes.dart';
import '../support/pose_fixtures.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'AI 봇 · 고수', isBot: true),
);

/// The pass depth of the push-up judge the battles below use.
final _passDepth = const RepJudgeConfig().bottomDepth;

/// A depth that grades good, and one that grades excellent.
final _good = _passDepth * 1.2;
final _excellent = _passDepth * 1.7;

const _playing = BattleState(remaining: Duration(seconds: 20));

String _show(BattleStageEvent e) => [
  e.side.name,
  e.grade?.name ?? 'miss',
  '+${e.points}',
  'combo ${e.combo}',
  if (e.fever) 'fever',
  if (e.reason != null) e.reason!.name,
  if (e.knockout) 'KO',
].join(' ');

void main() {
  group('a real bot battle, change by change', () {
    late FakeCameraService camera;
    late FakePoseEstimator estimator;
    late DepthRepJudge judge;
    late TimedOpponentSource opponent;
    late Duration now;
    late BattleViewModel battle;
    late BattleState seen;

    /// Every stage event the battle gave, in order, as text.
    late List<String> events;

    setUp(() {
      camera = FakeCameraService();
      estimator = FakePoseEstimator();
      judge = DepthRepJudge();
      opponent = TimedOpponentSource();
      now = Duration.zero;
      battle = BattleViewModel(
        matchup: _matchup,
        counter: RepCounterViewModel(
          camera: camera,
          estimator: estimator,
          judge: judge,
          clock: () => now,
          roundLength: battleDuration,
          phoneTilt: PhoneTiltMonitor(samples: const Stream.empty()),
        ),
        opponent: opponent,
        repository: FakeUserRepository(),
        sound: FakeRepSound(),
        now: () => DateTime(2026, 11, 11, 20),
      );
      seen = battle.state;
      events = [];
      // As a battle screen does: on every change, the events since the last.
      battle.addListener(() {
        events.addAll(
          BattleStageEvents.between(
            seen,
            battle.state,
            passDepth: battle.counter.passDepth,
          ).map(_show),
        );
        seen = battle.state;
      });
    });

    tearDown(() => battle.dispose());

    Future<void> frame(double seconds) async {
      now = Duration(milliseconds: (seconds * 1000).round());
      estimator.frames.add(emptyFrame());
      camera.emit();
      await pumpEventQueue();
    }

    Future<void> myRep(
      double seconds, {
      double? maxDepth,
      RejectReason? reason,
      double? minElbowAngle,
    }) async {
      judge.closeRep(
        maxDepth: maxDepth,
        reason: reason,
        minElbowAngle: minElbowAngle,
      );
      await frame(seconds);
    }

    Future<void> theirRep(double seconds, {RejectReason? reason}) async {
      opponent.emitAt(seconds, reason: reason);
      await pumpEventQueue();
    }

    test('my good rep is one hit with the game\'s points', () async {
      await battle.start();
      await myRep(3, maxDepth: _good);
      expect(events, ['me good +10 combo 1']);
      expect(battle.state.myScore, 10);
    });

    test('a deep rep within the combo window is excellent, combo 2, with the '
        'bonus', () async {
      await battle.start();
      await myRep(3, maxDepth: _good);
      await myRep(4, maxDepth: _excellent);
      expect(events, ['me good +10 combo 1', 'me excellent +20 combo 2']);
    });

    test('a half rep is an average hit with its reason and no combo', () async {
      await battle.start();
      await myRep(
        3,
        reason: RejectReason.insufficientDepth,
        minElbowAngle: 100,
      );
      expect(events, ['me average +5 combo 0 insufficientDepth']);
      expect(battle.state.myReps, 0);
    });

    test('a rejected rep is a miss with its reason, also right after a hit '
        'whose score is still the latest', () async {
      await battle.start();
      await myRep(3, maxDepth: _good);
      await myRep(5, reason: RejectReason.kneesDown);
      expect(events, ['me good +10 combo 1', 'me miss +0 combo 0 kneesDown']);
    });

    test(
      'a too shallow rep with straight arms earns nothing: a miss',
      () async {
        await battle.start();
        await myRep(
          3,
          reason: RejectReason.insufficientDepth,
          minElbowAngle: 150,
        );
        expect(events, ['me miss +0 combo 0 insufficientDepth']);
      },
    );

    test('the opponent\'s rep is a hit; their rejected rep a miss', () async {
      await battle.start();
      await frame(1);
      await theirRep(2);
      await theirRep(6, reason: RejectReason.tooFast);
      expect(events, ['opponent good +10 combo 1', 'opponent miss +0 combo 0']);
    });

    test('in fever a rep says so and earns double', () async {
      await battle.start();
      await myRep(21, maxDepth: _good);
      await theirRep(22);
      expect(events, [
        'me good +20 combo 1 fever',
        'opponent good +20 combo 1 fever',
      ]);
    });

    test('the rep that takes me 100 ahead is the knockout blow', () async {
      await battle.start();
      // Excellent with the combo bonus: 15, then 20 each.
      var at = 1.0;
      while (battle.state.myScore < 80) {
        await myRep(at, maxDepth: _excellent);
        at += 1;
      }
      expect(events.where((e) => e.contains('KO')), isEmpty);
      await myRep(at, maxDepth: _excellent);
      expect(events.last, 'me excellent +20 combo ${events.length} KO');
      expect(battle.state.result!.end, GameEnd.ko);
      // The ending the stage is told afterwards agrees with the blow.
      final end = BattleStageEvents.endOf(battle.state)!;
      expect(end.kind, BattleEndKind.knockout);
      expect(end.winner, BattleSide.me);
    });

    test('my knockout is reported before its blow is heard of: played in '
        'that order, the stage still shows the blow', () async {
      // As a battle screen would at worst: on every change, first the reps,
      // then the end, on the stage's clock.
      final fx = BattleFxTimeline();
      final order = <String>[];
      var clock = 1000.0;
      var before = battle.state;
      battle.addListener(() {
        for (final event in BattleStageEvents.between(
          before,
          battle.state,
          passDepth: battle.counter.passDepth,
        )) {
          order.add(event.knockout ? 'blow' : 'rep');
          fx.rep(event, clock);
        }
        final end = BattleStageEvents.endOf(battle.state);
        if (end != null &&
            order.lastOrNull != 'end' &&
            !order.contains('end')) {
          order.add('end');
        }
        if (end != null) fx.finish(end, clock);
        before = battle.state;
      });
      await battle.start();
      var at = 1.0;
      while (battle.state.result == null) {
        clock = 1000 + at * 1000;
        await myRep(at, maxDepth: _excellent);
        at += 1;
      }
      // The game ends the round before the last rep reaches the screen.
      expect(order.sublist(order.length - 2), ['end', 'blow']);
      final frame = fx.frame(clock + 40);
      expect(frame.me.pose, BattlePose.attack);
      final cues = fx.takeCues(clock + 5000);
      expect(cues.last.kind, BattleCueKind.knockout);
      expect(cues.last.grade, GameGrade.excellent);
      expect(cues.where((c) => c.kind == BattleCueKind.knockout), hasLength(1));
      expect(fx.frame(clock + 80 + 1300).banners.single.text, 'K.O.');
    });

    test(
      'the opponent\'s rep that takes them 100 ahead knocks me out',
      () async {
        await battle.start();
        await frame(1);
        var at = 1.2;
        while (battle.state.opponentScore < 90) {
          await theirRep(at);
          at += 1;
        }
        await theirRep(at);
        expect(events.last, startsWith('opponent good'));
        expect(events.last, endsWith('KO'));
        expect(events.where((e) => e.endsWith('KO')), hasLength(1));
        expect(
          BattleStageEvents.endOf(battle.state)!.winner,
          BattleSide.opponent,
        );
      },
    );

    test('time running out is a time-up won by the higher score', () async {
      await battle.start();
      await myRep(3, maxDepth: _good);
      await frame(30);
      final end = BattleStageEvents.endOf(battle.state)!;
      expect(end.kind, BattleEndKind.timeUp);
      expect(end.winner, BattleSide.me);
      expect(end.decided, isTrue);
      expect(events, ['me good +10 combo 1']);
    });

    test('leaving ends nothing on the stage', () async {
      await battle.start();
      battle.leave();
      await pumpEventQueue();
      expect(BattleStageEvents.endOf(battle.state), isNull);
    });
  });

  group('BattleStageEvents.between', () {
    const good = GameRepScore(
      grade: GameGrade.good,
      combo: 3,
      fever: false,
      points: 15,
    );

    test('nothing changed, nothing happened', () {
      expect(
        BattleStageEvents.between(_playing, _playing, passDepth: _passDepth),
        isEmpty,
      );
    });

    test('a score or clock change alone is no event', () {
      final after = _playing.copyWith(
        myScore: 10,
        remaining: const Duration(seconds: 19),
        myLastScore: good,
      );
      expect(
        BattleStageEvents.between(_playing, after, passDepth: _passDepth),
        isEmpty,
      );
    });

    test('my rep and the opponent\'s in one change: mine first', () {
      final after = _playing.copyWith(
        feedback: gameRep(5, maxDepth: _good),
        feedbackCount: 1,
        myLastScore: good,
        opponentMoves: 1,
        opponentLastScore: good,
        myScore: 15,
        opponentScore: 15,
      );
      final events = BattleStageEvents.between(
        _playing,
        after,
        passDepth: _passDepth,
      );
      expect(events.map((e) => e.side), [BattleSide.me, BattleSide.opponent]);
      expect(events.first.combo, 3);
      expect(events.first.points, 15);
    });

    test(
      'a hit whose score has not been kept yet takes the rules\' points',
      () {
        final after = _playing.copyWith(
          feedback: gameRep(5, maxDepth: _excellent),
          feedbackCount: 1,
          fever: true,
        );
        final event = BattleStageEvents.between(
          _playing,
          after,
          passDepth: _passDepth,
        ).single;
        expect(event.grade, GameGrade.excellent);
        expect(event.points, 30);
        expect(event.combo, 1);
        expect(event.fever, isTrue);
      },
    );

    test(
      'the opponent\'s same score object again is a miss, a new one a hit',
      () {
        final before = _playing.copyWith(opponentLastScore: good);
        final missed = before.copyWith(opponentMoves: 1);
        expect(
          BattleStageEvents.between(
            before,
            missed,
            passDepth: _passDepth,
          ).single.grade,
          isNull,
        );
        // The game makes a new score for every rep that earns something,
        // also when its numbers are the same as the last one's.
        final again = GameRepScore(
          grade: good.grade,
          combo: good.combo,
          fever: good.fever,
          points: good.points,
        );
        expect(identical(again, good), isFalse);
        final hit = before.copyWith(opponentMoves: 1, opponentLastScore: again);
        expect(
          BattleStageEvents.between(
            before,
            hit,
            passDepth: _passDepth,
          ).single.grade,
          GameGrade.good,
        );
      },
    );

    test('a lead of the KO size the other way is not my knockout', () {
      final after = _playing.copyWith(
        feedback: gameRep(5, maxDepth: _good),
        feedbackCount: 1,
        myLastScore: good,
        myScore: 15,
        opponentScore: 115,
      );
      expect(
        BattleStageEvents.between(
          _playing,
          after,
          passDepth: _passDepth,
        ).single.knockout,
        isFalse,
      );
    });

    test('a miss never knocks out, whatever the lead', () {
      final after = _playing.copyWith(
        feedback: gameRep(5, reason: RejectReason.kneesDown),
        feedbackCount: 1,
        myScore: 120,
      );
      expect(
        BattleStageEvents.between(
          _playing,
          after,
          passDepth: _passDepth,
        ).single.knockout,
        isFalse,
      );
    });
  });

  group('BattleStageEvents.endOf', () {
    BattleState ended({
      required int mine,
      required int theirs,
      GameEnd end = GameEnd.timeUp,
      required MatchOutcome outcome,
    }) => _playing.copyWith(
      phase: BattlePhase.timeUp,
      result: BattleResult(
        matchup: _matchup,
        myReps: 3,
        myInvalidReps: 0,
        opponentReps: 3,
        myScore: mine,
        opponentScore: theirs,
        end: end,
        decidedOutcome: outcome,
        endedAt: DateTime(2026, 11, 11),
      ),
    );

    test('a draw has no winner', () {
      final end = BattleStageEvents.endOf(
        ended(mine: 30, theirs: 30, outcome: MatchOutcome.draw),
      )!;
      expect(end.kind, BattleEndKind.timeUp);
      expect(end.winner, isNull);
    });

    test('a loss by KO names the opponent', () {
      final end = BattleStageEvents.endOf(
        ended(
          mine: 0,
          theirs: 100,
          end: GameEnd.ko,
          outcome: MatchOutcome.lose,
        ),
      )!;
      expect(end.kind, BattleEndKind.knockout);
      expect(end.winner, BattleSide.opponent);
    });

    test('a battle still running has no end', () {
      expect(BattleStageEvents.endOf(_playing), isNull);
    });
  });

  group('BattleStageEvents.stateOf', () {
    test('carries the names, the standing and the clock', () {
      final state = BattleStageEvents.stateOf(
        _playing.copyWith(
          myScore: 60,
          opponentScore: 45,
          myReps: 5,
          opponentReps: 4,
          myBarShare: 0.575,
          fever: true,
          danger: true,
          remaining: const Duration(milliseconds: 7200),
        ),
        _matchup,
        roundLength: battleDuration,
      );
      expect(state.phase, BattleStagePhase.playing);
      expect(state.myName, '우현');
      expect(state.opponentName, 'AI 봇 · 고수');
      expect(state.myScore, 60);
      expect(state.opponentScore, 45);
      expect(state.lead, 15);
      expect(state.myReps, 5);
      expect(state.opponentReps, 4);
      expect(state.barShare, 0.575);
      expect(state.fever, isTrue);
      expect(state.feverMultiplier, battleRules.feverMultiplier);
      expect(state.danger, isTrue);
      expect(state.secondsLeft, 8);
      expect(state.elapsed, closeTo(22.8 / 30, 1e-9));
      expect(state.end, isNull);
    });

    test('an ended battle is in the ended phase with its end', () {
      final state = BattleStageEvents.stateOf(
        _playing.copyWith(
          phase: BattlePhase.timeUp,
          remaining: Duration.zero,
          result: BattleResult(
            matchup: _matchup,
            myReps: 3,
            myInvalidReps: 0,
            opponentReps: 2,
            myScore: 30,
            opponentScore: 20,
            decidedOutcome: MatchOutcome.win,
            endedAt: DateTime(2026, 11, 11),
          ),
        ),
        _matchup,
        roundLength: battleDuration,
      );
      expect(state.phase, BattleStagePhase.ended);
      expect(state.end!.winner, BattleSide.me);
      expect(state.secondsLeft, 0);
      expect(state.elapsed, 1);
    });
  });
}
