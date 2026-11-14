import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_summary.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/viewmodels/result_viewmodel.dart';

import '../support/feedback_fakes.dart';
import '../support/form_report_fixtures.dart';

final _endedAt = DateTime(2026, 11, 14, 14, 30);

const _bot = Opponent(
  name: 'AI 봇 · 고수',
  isBot: true,
  difficulty: BotDifficulty.expert,
);
const _person = Opponent(name: '우현', isBot: false);

BattleResult _battle({
  Opponent opponent = _bot,
  ExerciseType exercise = ExerciseType.pushUp,
  int myScore = 240,
  bool hasGame = true,
  GameEnd end = GameEnd.ko,
  BattleDeparture departure = BattleDeparture.none,
  bool withForm = true,
}) => BattleResult(
  matchup: Matchup(exercise: exercise, playerName: '진영', opponent: opponent),
  myReps: 12,
  myInvalidReps: 2,
  opponentReps: 5,
  myScore: myScore,
  opponentScore: 125,
  end: end,
  decidedOutcome: hasGame ? MatchOutcome.win : null,
  endedAt: _endedAt,
  roundLength: const Duration(seconds: 25),
  departure: departure,
  form: withForm
      ? (exercise == ExerciseType.squat
            ? squatReport(endedAt: _endedAt)
            : sampleReport(valid: 12, rejected: 2, endedAt: _endedAt))
      : null,
);

/// Battles before the one under test, oldest first, one day apart, with
/// ids from 100.
FakeFeedbackStatsSource _history(
  List<int?> scores, {
  ExerciseType exercise = ExerciseType.pushUp,
}) {
  return FakeFeedbackStatsSource([
    for (var i = 0; i < scores.length; i++)
      statsPoint(
        100 + i,
        _endedAt.subtract(Duration(days: scores.length - i)),
        score: scores[i],
        exercise: exercise,
      ),
  ]);
}

void main() {
  group('a battle just played', () {
    test('fills what the battle already has', () {
      final state = ResultViewModel.battle(
        _battle(),
        history: FakeFeedbackStatsSource(),
      ).state;
      expect(state.endedAt, _endedAt);
      expect(state.outcome, MatchOutcome.win);
      expect(state.end, GameEnd.ko);
      expect(state.exercise, ExerciseType.pushUp);
      expect(state.opponent, same(_bot));
      expect(state.opponentName, 'AI 봇 · 고수');
      expect(state.isOnline, isFalse);
      expect(state.roundLength, const Duration(seconds: 25));
      expect(state.myScore, 240);
      expect(state.opponentScore, 125);
      expect(state.myReps, 12);
      expect(state.myInvalidReps, 2);
      expect(state.opponentLeft, isFalse);
      expect(state.form, isNotNull);
      expect(state.rematch?.difficulty, BotDifficulty.expert);
      expect(state.rematch?.exercise, ExerciseType.pushUp);
    });

    test('starts with the comparison loading and empty', () {
      final state = ResultViewModel.battle(
        _battle(),
        history: FakeFeedbackStatsSource(),
      ).state;
      expect(state.history, ResultHistoryPhase.loading);
      expect(state.previousBest, isNull);
      expect(state.isNewBest, isFalse);
      expect(state.recentScores, isEmpty);
      expect(state.recentFrom, isNull);
      expect(state.recentAverage, isNull);
      expect(state.recentAverageOf, 0);
    });

    test('the next tip is the first issue\'s fix', () {
      final tip = ResultViewModel.battle(
        _battle(),
        history: FakeFeedbackStatsSource(),
      ).state.nextTip!;
      expect(tip.headline, '가슴이 바닥에 가까워질 때까지 내려간 뒤 올라와요.');
      expect(tip.detail, '깊이 부족 2회');
      expect(tip.code, 'reject.insufficientDepth');
    });

    test('a squat battle has its report and a squat tip', () {
      final state = ResultViewModel.battle(
        _battle(exercise: ExerciseType.squat),
        history: FakeFeedbackStatsSource(),
      ).state;
      expect(state.form?.exercise, ExerciseType.squat);
      expect(state.nextTip?.code, 'reject.shallowSquat');
    });

    test('no tip without a report or without an issue', () {
      expect(
        ResultViewModel.battle(
          _battle(withForm: false),
          history: FakeFeedbackStatsSource(),
        ).state.nextTip,
        isNull,
      );
      final clean = BattleResult(
        matchup: const Matchup(
          exercise: ExerciseType.pushUp,
          playerName: '진영',
          opponent: _bot,
        ),
        myReps: 3,
        myInvalidReps: 0,
        opponentReps: 1,
        endedAt: _endedAt,
        form: sampleReport(),
      );
      expect(
        ResultViewModel.battle(
          clean,
          history: FakeFeedbackStatsSource(),
        ).state.nextTip,
        isNull,
      );
    });

    test('online: no rematch, and the opponent leaving is said', () {
      final state = ResultViewModel.battle(
        _battle(
          opponent: _person,
          end: GameEnd.timeUp,
          departure: BattleDeparture.opponentLeft,
        ),
        history: FakeFeedbackStatsSource(),
      ).state;
      expect(state.isOnline, isTrue);
      expect(state.rematch, isNull);
      expect(state.opponentLeft, isTrue);
      expect(state.end, isNull);
    });

    test('online by time keeps its end', () {
      final state = ResultViewModel.battle(
        _battle(opponent: _person, end: GameEnd.timeUp),
        history: FakeFeedbackStatsSource(),
      ).state;
      expect(state.end, GameEnd.timeUp);
      expect(state.opponentLeft, isFalse);
    });
  });

  group('compared with earlier battles', () {
    test('previous best, recent 8 and the 5-battle average', () async {
      // The data list's example: 110 105 130 150 185 before 240.
      final history = _history([90, 100, 110, 105, 130, 150, 185]);
      final model = ResultViewModel.battle(_battle(), history: history);
      await model.load();
      final state = model.state;
      expect(history.calls.single.exercise, ExerciseType.pushUp);
      expect(state.history, ResultHistoryPhase.ready);
      expect(state.previousBest, 185);
      expect(state.isNewBest, isTrue);
      expect(state.recentScores, [90, 100, 110, 105, 130, 150, 185, 240]);
      expect(state.recentFrom, _endedAt.subtract(const Duration(days: 7)));
      expect(state.recentAverage, 136);
      expect(state.recentAverageOf, 5);
    });

    test('only the last 7 earlier battles join this one', () async {
      final model = ResultViewModel.battle(
        _battle(myScore: 50),
        history: _history([1, 2, 3, 4, 5, 6, 7, 8, 9, 300]),
      );
      await model.load();
      expect(model.state.recentScores, [4, 5, 6, 7, 8, 9, 300, 50]);
      expect(
        model.state.recentFrom,
        _endedAt.subtract(const Duration(days: 7)),
      );
      expect(model.state.previousBest, 300);
      expect(model.state.isNewBest, isFalse);
      expect(model.state.recentAverage, 66); // (6+7+8+9+300)/5 = 66
    });

    test('the first battle has no best and no average', () async {
      final model = ResultViewModel.battle(
        _battle(),
        history: FakeFeedbackStatsSource(),
      );
      await model.load();
      expect(model.state.previousBest, isNull);
      expect(model.state.isNewBest, isFalse);
      expect(model.state.recentScores, [240]);
      expect(model.state.recentFrom, _endedAt);
      expect(model.state.recentAverage, isNull);
      expect(model.state.recentAverageOf, 0);
    });

    test('fewer than 5 earlier battles average over what there is', () async {
      final model = ResultViewModel.battle(
        _battle(),
        history: _history([100, 201]),
      );
      await model.load();
      expect(model.state.recentAverage, 151); // 150.5 rounds up
      expect(model.state.recentAverageOf, 2);
    });

    test('this battle, already on the server, is not its own best', () async {
      final history = FakeFeedbackStatsSource([
        statsPoint(100, _endedAt.subtract(const Duration(days: 1)), score: 100),
        // The upload landed, with the server's slightly earlier time.
        statsPoint(
          200,
          _endedAt.subtract(const Duration(seconds: 2)),
          score: 240,
        ),
      ]);
      final model = ResultViewModel.battle(_battle(), history: history);
      await model.load();
      expect(model.state.previousBest, 100);
      expect(model.state.isNewBest, isTrue);
      expect(model.state.recentScores, [100, 240]);
    });

    test(
      'battles without a score, of another exercise or later are left out',
      () async {
        final history = FakeFeedbackStatsSource([
          statsPoint(1, _endedAt.subtract(const Duration(days: 3)), score: 50),
          statsPoint(2, _endedAt.subtract(const Duration(days: 2))),
          statsPoint(
            3,
            _endedAt.subtract(const Duration(days: 1)),
            score: 999,
            exercise: ExerciseType.squat,
          ),
          statsPoint(4, _endedAt.add(const Duration(days: 1)), score: 999),
        ]);
        final model = ResultViewModel.battle(_battle(), history: history);
        await model.load();
        expect(model.state.recentScores, [50, 240]);
        expect(model.state.previousBest, 50);
      },
    );

    test(
      'a battle without a game score compares but is not appended',
      () async {
        final model = ResultViewModel.battle(
          _battle(hasGame: false),
          history: _history([100]),
        );
        await model.load();
        expect(model.state.myScore, 12);
        expect(model.state.previousBest, 100);
        expect(model.state.isNewBest, isFalse);
        expect(model.state.recentScores, [100]);
      },
    );

    test('a failed load leaves that part out', () async {
      final history = FakeFeedbackStatsSource()..error = Exception('offline');
      final model = ResultViewModel.battle(_battle(), history: history);
      await model.load();
      expect(model.state.history, ResultHistoryPhase.failed);
      expect(model.state.recentScores, isEmpty);
      expect(model.state.myScore, 240);
    });

    test('a retry after a failure loads again', () async {
      final history = FakeFeedbackStatsSource()..error = Exception('offline');
      final model = ResultViewModel.battle(_battle(), history: history);
      await model.load();
      history.error = null;
      final phases = <ResultHistoryPhase>[];
      model.addListener(() => phases.add(model.state.history));
      await model.load();
      expect(phases, [ResultHistoryPhase.loading, ResultHistoryPhase.ready]);
      expect(history.calls, hasLength(2));
    });

    test('load while loading fetches only once', () async {
      final history = FakeFeedbackStatsSource()..gate = Completer();
      final model = ResultViewModel.battle(_battle(), history: history);
      final first = model.load();
      final second = model.load();
      history.gate!.complete();
      await Future.wait([first, second]);
      expect(history.calls, hasLength(1));
    });

    test('battles arriving after dispose are dropped', () async {
      final history = _history([100])..gate = Completer();
      final model = ResultViewModel.battle(_battle(), history: history);
      final loading = model.load();
      model.dispose();
      history.gate!.complete();
      await loading;
      expect(model.state.history, ResultHistoryPhase.loading);
      await model.load();
      expect(history.calls, hasLength(1));
    });
  });

  group('a past battle from the archive', () {
    MatchRecord record({
      int? id = 105,
      int? myScore = 130,
      bool feedback = true,
      bool? isOnline = false,
      bool opponentLeft = false,
      GameEnd? gameEnd = GameEnd.timeUp,
      DateTime? playedAt,
    }) => MatchRecord(
      id: id,
      exercise: ExerciseType.pushUp,
      opponentName: 'AI 봇 · 고수',
      myReps: 9,
      opponentReps: 7,
      myScore: myScore,
      opponentScore: myScore == null ? null : 110,
      playedAt: playedAt ?? _endedAt.subtract(const Duration(days: 3)),
      decidedOutcome: MatchOutcome.win,
      gameEnd: gameEnd,
      isOnline: isOnline,
      opponentLeft: opponentLeft,
      feedbackSummary: feedback
          ? const FeedbackSummary(validReps: 9, invalidReps: 1, issueCount: 1)
          : null,
    );

    test('fills what the record has, and no rematch', () {
      final state = ResultViewModel.record(
        record(isOnline: true, opponentLeft: true, gameEnd: null),
        history: FakeFeedbackStatsSource(),
      ).state;
      expect(state.endedAt, _endedAt.subtract(const Duration(days: 3)));
      expect(state.outcome, MatchOutcome.win);
      expect(state.end, isNull);
      expect(state.opponent, isNull);
      expect(state.opponentName, 'AI 봇 · 고수');
      expect(state.isOnline, isTrue);
      expect(state.opponentLeft, isTrue);
      expect(state.myScore, 130);
      expect(state.opponentScore, 110);
      expect(state.myReps, 9);
      expect(state.myInvalidReps, 1);
      expect(state.roundLength, isNull);
      expect(state.form, isNull);
      expect(state.rematch, isNull);
    });

    test('compares only with the battles before it', () async {
      // Ids 100..106, one day apart; the record is id 105 (score 130).
      final history = _history([110, 105, 90, 150, 185, 130, 240]);
      final model = ResultViewModel.record(
        record(playedAt: _endedAt.subtract(const Duration(days: 2))),
        history: history,
      );
      await model.load();
      expect(model.state.previousBest, 185);
      expect(model.state.isNewBest, isFalse);
      expect(model.state.recentScores, [110, 105, 90, 150, 185, 130]);
      expect(model.state.recentAverage, 128); // (110+105+90+150+185)/5
    });

    test('loads its form report for the tip and the round length', () async {
      final repository = FakeStatsUserRepository()
        ..reports = {105: sampleReport(valid: 9, rejected: 1)};
      final model = ResultViewModel.record(
        record(),
        history: repository,
        repository: repository,
      );
      await model.load();
      expect(repository.feedbackRequests, [105]);
      expect(model.state.form, isNotNull);
      expect(model.state.roundLength, const Duration(seconds: 30));
      expect(model.state.nextTip?.code, 'reject.insufficientDepth');
    });

    test('a battle without feedback does not ask for a report', () async {
      final repository = FakeStatsUserRepository();
      final model = ResultViewModel.record(
        record(feedback: false),
        history: repository,
        repository: repository,
      );
      await model.load();
      expect(repository.feedbackRequests, isEmpty);
      expect(model.state.myInvalidReps, isNull);
      expect(model.state.form, isNull);
    });

    test('a report that is gone or fails to load leaves the tip out', () async {
      final repository = FakeStatsUserRepository();
      final missing = ResultViewModel.record(
        record(),
        history: repository,
        repository: repository,
      );
      await missing.load();
      expect(missing.state.form, isNull);
      repository.feedbackError = Exception('offline');
      final failed = ResultViewModel.record(
        record(),
        history: repository,
        repository: repository,
      );
      await failed.load();
      expect(failed.state.form, isNull);
      expect(failed.state.nextTip, isNull);
      expect(failed.state.history, ResultHistoryPhase.ready);
    });

    test('a battle saved before scores shows its reps', () async {
      final model = ResultViewModel.record(
        record(myScore: null),
        history: _history([100, 120, 140, 160]),
      );
      expect(model.state.myScore, 9);
      expect(model.state.opponentScore, 7);
      await model.load();
      expect(model.state.recentScores, [100]);
    });

    test('a record without a time is never dated', () async {
      final model = ResultViewModel.record(
        MatchRecord(
          id: 105,
          exercise: ExerciseType.pushUp,
          opponentName: 'AI 봇 · 고수',
          myReps: 9,
          opponentReps: 7,
          myScore: 130,
          opponentScore: 110,
        ),
        history: _history([100]),
      );
      await model.load();
      expect(model.state.recentScores, [130]);
      expect(model.state.recentFrom, isNull);
      expect(model.state.previousBest, isNull);
    });

    test('a record without a server id compares by time only', () async {
      final model = ResultViewModel.record(
        record(id: null),
        history: _history([100, 120, 140, 160]),
      );
      await model.load();
      // Days 4 and 3 before: only the first battle is before day 3.
      expect(model.state.recentScores, [100, 130]);
    });
  });
}
