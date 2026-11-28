import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/result_scene_demo.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/models/ranking_ladder.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/viewmodels/ranking_ladder_viewmodel.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';

/// [snapshot] as the server's weekly ranking of [exercise].
WeeklyRanking _weekly(
  RankingSnapshot snapshot, {
  ExerciseType exercise = ExerciseType.pushUp,
}) {
  RankingEntry entry(LadderEntry e) => RankingEntry(
    rank: e.rank,
    userId: e.userId,
    nickname: e.nickname,
    points: e.points,
    battles: e.battles,
    wins: 0,
    koWins: 0,
    isMe: e.userId == snapshot.me?.userId,
  );
  return WeeklyRanking(
    scope: RankingScope.global,
    exercise: exercise,
    weekStart: DateTime.utc(2026, 11, 22, 15),
    weekEnd: DateTime.utc(2026, 11, 29, 15),
    entries: [for (final e in snapshot.entries) entry(e)],
    me: switch (snapshot.me) {
      final me? => entry(me),
      null => null,
    },
  );
}

/// Answers each read with the next of [answers] (the last one again when
/// they run out), after [delay]; an answer that is an exception is thrown.
/// Keeps when each read came, from [clock].
class _ScriptedRankings implements RankingsRepository {
  _ScriptedRankings(this.answers, {required this.clock, this.delay});

  final List<Object> answers;
  final Duration Function() clock;
  final Duration? delay;
  final readsAt = <Duration>[];
  final scopes = <RankingKey>[];

  @override
  Future<WeeklyRanking> fetchWeekly(
    RankingScope scope,
    ExerciseType exercise,
  ) async {
    readsAt.add(clock());
    scopes.add((scope, exercise));
    final answer = answers[(readsAt.length - 1).clamp(0, answers.length - 1)];
    if (delay case final wait?) await Future<void>.delayed(wait);
    if (answer is WeeklyRanking) return answer;
    throw answer;
  }
}

/// Never answers.
class _SilentRankings implements RankingsRepository {
  var reads = 0;

  @override
  Future<WeeklyRanking> fetchWeekly(RankingScope scope, ExerciseType exercise) {
    reads++;
    return Completer<WeeklyRanking>().future;
  }
}

final _base = ScoreLadderCase.all['base']!;
final _confirmed = _weekly(_base.after(VictoryResult.koWin));
final _notYet = _weekly(_base.before);

RankingLadderViewModel _viewModel(
  RankingsRepository repository,
  FakeAsync async, {
  bool ranked = true,
  RankingSnapshot? before,
  bool noBefore = false,
  int points = RankingPoints.koWin,
}) => RankingLadderViewModel(
  repository: repository,
  exercise: ExerciseType.pushUp,
  ranked: ranked,
  before: noBefore ? null : before ?? _base.before,
  points: points,
  elapsed: () => async.elapsed,
);

BattleResult _battle(
  MatchOutcome outcome, {
  GameEnd end = GameEnd.timeUp,
  BattleDeparture departure = BattleDeparture.none,
  bool ranked = false,
  RankingSnapshot? before,
}) => BattleResult(
  matchup: const Matchup(
    exercise: ExerciseType.squat,
    playerName: '나',
    opponent: Opponent(name: '상대', isBot: false),
  ),
  myReps: 10,
  myInvalidReps: 0,
  opponentReps: 8,
  myScore: 100,
  opponentScore: 80,
  end: end,
  decidedOutcome: outcome,
  endedAt: DateTime.utc(2026, 11, 29),
  departure: departure,
  ranked: ranked,
  rankingBefore: before,
);

void main() {
  test('takes a confirmed ranking from the first read and reads no more', () {
    fakeAsync((async) {
      final repository = InMemoryRankingsRepository(
        rankings: {(RankingScope.global, ExerciseType.pushUp): _confirmed},
      );
      final viewModel = _viewModel(repository, async);
      var notified = 0;
      viewModel
        ..addListener(() => notified++)
        ..load();
      async.flushMicrotasks();
      expect(viewModel.after, isNotNull);
      expect(notified, 1);
      expect(viewModel.decide(), LadderPath.confirmed);
      expect(viewModel.holds, isTrue);
      final ladder = viewModel.ladder!;
      expect(
        [for (final row in ladder.rows) row.rankAfterText],
        ['1', '3', '4', '2'],
      );
      expect(viewModel.chip, (rank: 2, points: 29, gained: 10));
      async.elapse(const Duration(seconds: 10));
      expect(repository.reads, {(RankingScope.global, ExerciseType.pushUp): 1});
      viewModel.dispose();
    });
  });

  test('reads the global ranking of the battle\'s exercise', () {
    fakeAsync((async) {
      final repository = _ScriptedRankings([
        _confirmed,
      ], clock: () => async.elapsed);
      RankingLadderViewModel(
        repository: repository,
        exercise: ExerciseType.squat,
        ranked: true,
        before: _base.before,
        points: 10,
        elapsed: () => async.elapsed,
      ).load();
      async.flushMicrotasks();
      expect(repository.scopes, [(RankingScope.global, ExerciseType.squat)]);
    });
  });

  test('does not take a ranking without the battle and reads it again at '
      '0.4, 1, 2 and 4 seconds, then stops', () {
    fakeAsync((async) {
      final repository = _ScriptedRankings([
        _notYet,
      ], clock: () => async.elapsed);
      final viewModel = _viewModel(repository, async);
      var notified = 0;
      viewModel
        ..addListener(() => notified++)
        ..load();
      async.elapse(const Duration(seconds: 20));
      expect(repository.readsAt, const [
        Duration.zero,
        Duration(milliseconds: 400),
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ]);
      expect(viewModel.after, isNull);
      expect(viewModel.decide(), LadderPath.late);
      expect(viewModel.ladder, isNull);
      // Never confirmed: nothing is left.
      expect(viewModel.chip, isNull);
      expect(notified, 0);
      expect(async.pendingTimers, isEmpty);
      viewModel.dispose();
    });
  });

  test('a ranking confirmed after the path was chosen gives only the chip', () {
    fakeAsync((async) {
      final repository = _ScriptedRankings([
        _notYet,
        _notYet,
        _notYet,
        _confirmed,
      ], clock: () => async.elapsed);
      final viewModel = _viewModel(repository, async)..load();
      async.elapse(const Duration(milliseconds: 880));
      // The scene chooses its path at 0.88 s, before the ranking has it.
      expect(viewModel.decide(), LadderPath.late);
      expect(viewModel.chip, isNull);
      var notified = 0;
      viewModel.addListener(() => notified++);
      async.elapse(const Duration(seconds: 2));
      expect(repository.readsAt.length, 4);
      expect(notified, 1);
      expect(viewModel.decide(), LadderPath.late);
      expect(viewModel.holds, isFalse);
      expect(viewModel.ladder, isNull);
      expect(viewModel.chip, (rank: 2, points: 29, gained: 10));
      async.elapse(const Duration(seconds: 10));
      expect(repository.readsAt.length, 4);
      viewModel.dispose();
    });
  });

  test('reading the chip, holds or ladder does not choose the path', () {
    fakeAsync((async) {
      final repository = _ScriptedRankings([
        _notYet,
        _confirmed,
      ], clock: () => async.elapsed);
      final viewModel = _viewModel(repository, async)..load();
      // Asked before the ranking has the battle.
      expect(viewModel.chip, isNull);
      expect(viewModel.holds, isFalse);
      expect(viewModel.ladder, isNull);
      expect(viewModel.path, isNull);
      async.elapse(const Duration(milliseconds: 880));
      expect(viewModel.decide(), LadderPath.confirmed);
      expect(viewModel.path, LadderPath.confirmed);
      expect(viewModel.holds, isTrue);
      // Made once and kept.
      final ladder = viewModel.ladder;
      expect(ladder, isNotNull);
      expect(viewModel.ladder, same(ladder));
      viewModel.dispose();
    });
  });

  test('across a week reset: only the chip, with the new week\'s values', () {
    fakeAsync((async) {
      final before = RankingSnapshot(
        weekStart: DateTime.utc(2026, 11, 22, 15),
        entries: _base.before.entries,
        me: _base.before.me,
      );
      final mine = RankingEntry(
        rank: 3,
        userId: ScoreLadderCase.myId,
        nickname: ScoreLadderCase.myName,
        points: 10,
        battles: 1,
        wins: 1,
        koWins: 1,
        isMe: true,
      );
      final newWeek = WeeklyRanking(
        scope: RankingScope.global,
        weekStart: DateTime.utc(2026, 11, 29, 15),
        weekEnd: DateTime.utc(2026, 12, 6, 15),
        entries: [mine],
        me: mine,
      );
      final repository = _ScriptedRankings([
        newWeek,
      ], clock: () => async.elapsed);
      final viewModel = _viewModel(repository, async, before: before)..load();
      async.flushMicrotasks();
      expect(viewModel.after?.weekStart, DateTime.utc(2026, 11, 29, 15));
      async.elapse(const Duration(milliseconds: 880));
      expect(viewModel.decide(), LadderPath.late);
      expect(viewModel.holds, isFalse);
      expect(viewModel.ladder, isNull);
      expect(viewModel.chip, (rank: 3, points: 10, gained: 10));
      // Confirmed: no more reads.
      async.elapse(const Duration(seconds: 7));
      expect(repository.readsAt, hasLength(1));
      viewModel.dispose();
    });
  });

  test('snapshotOf keeps the ranking\'s week', () {
    expect(
      RankingLadderViewModel.snapshotOf(_confirmed).weekStart,
      DateTime.utc(2026, 11, 22, 15),
    );
  });

  test('a ranking confirmed before 0.88 s gives the ladder', () {
    fakeAsync((async) {
      final repository = _ScriptedRankings([
        _notYet,
        _confirmed,
      ], clock: () => async.elapsed);
      final viewModel = _viewModel(repository, async)..load();
      async.elapse(const Duration(milliseconds: 880));
      expect(viewModel.decide(), LadderPath.confirmed);
      expect(viewModel.ladder, isNotNull);
      viewModel.dispose();
    });
  });

  test('takes no answer after 6 seconds', () {
    fakeAsync((async) {
      // The read at 4 s answers 2.5 s later, past 6 s.
      final repository = _ScriptedRankings(
        [_notYet, _notYet, _notYet, _notYet, _confirmed],
        clock: () => async.elapsed,
        delay: const Duration(milliseconds: 2500),
      );
      final viewModel = _viewModel(repository, async);
      var notified = 0;
      viewModel
        ..addListener(() => notified++)
        ..load();
      async.elapse(const Duration(seconds: 10));
      expect(repository.readsAt.length, 5);
      expect(viewModel.after, isNull);
      expect(viewModel.chip, isNull);
      expect(notified, 0);
      viewModel.dispose();
    });
  });

  test('a failed read is read again', () {
    fakeAsync((async) {
      final repository = _ScriptedRankings([
        Exception('offline'),
        _confirmed,
      ], clock: () => async.elapsed);
      final viewModel = _viewModel(repository, async)..load();
      async.elapse(const Duration(milliseconds: 500));
      expect(repository.readsAt.length, 2);
      expect(viewModel.after, isNotNull);
      viewModel.dispose();
    });
  });

  test('the report opens while the ranking is read: nothing waits', () {
    fakeAsync((async) {
      final repository = _SilentRankings();
      final viewModel = _viewModel(repository, async);
      // load() returns at once, and the path is there without an answer.
      viewModel.load();
      expect(repository.reads, 1);
      expect(viewModel.decide(), LadderPath.late);
      expect(viewModel.chip, isNull);
      async.elapse(const Duration(seconds: 7));
      expect(repository.reads, 5);
      expect(viewModel.chip, isNull);
      viewModel.dispose();
    });
  });

  test('closing the report turns the timers off and drops the answer', () {
    fakeAsync((async) {
      final repository = _ScriptedRankings(
        [_confirmed],
        clock: () => async.elapsed,
        delay: const Duration(milliseconds: 300),
      );
      final viewModel = _viewModel(repository, async)..load();
      expect(async.pendingTimers, isNotEmpty);
      viewModel.dispose();
      // The read in flight answers after the screen closed.
      async.elapse(const Duration(seconds: 1));
      expect(async.pendingTimers, isEmpty);
      expect(repository.readsAt.length, 1);
      expect(viewModel.after, isNull);
    });
  });

  test('load reads once however often it is called', () {
    fakeAsync((async) {
      final repository = _ScriptedRankings([
        _confirmed,
      ], clock: () => async.elapsed);
      _viewModel(repository, async)
        ..load()
        ..load();
      async.elapse(const Duration(seconds: 1));
      expect(repository.readsAt.length, 1);
    });
  });

  group('no points layer: nothing is read or shown', () {
    for (final (name, make) in [
      (
        'a battle that is not ranked (a friend battle)',
        (RankingsRepository r, FakeAsync a) => _viewModel(r, a, ranked: false),
      ),
      (
        'no ranking from before the battle',
        (RankingsRepository r, FakeAsync a) => _viewModel(r, a, noBefore: true),
      ),
      (
        'a battle worth no points',
        (RankingsRepository r, FakeAsync a) => _viewModel(r, a, points: 0),
      ),
    ]) {
      test(name, () {
        fakeAsync((async) {
          final repository = _ScriptedRankings([
            _confirmed,
          ], clock: () => async.elapsed);
          final viewModel = make(repository, async)..load();
          async.elapse(const Duration(seconds: 7));
          expect(repository.readsAt, isEmpty);
          expect(viewModel.decide(), LadderPath.none);
          expect(viewModel.holds, isFalse);
          expect(viewModel.ladder, isNull);
          expect(viewModel.chip, isNull);
          viewModel.dispose();
        });
      });
    }
  });

  group('fetchBefore', () {
    test('reads the global ranking as the ladder reads it', () async {
      final repository = InMemoryRankingsRepository(
        rankings: {(RankingScope.global, ExerciseType.squat): _notYet},
      );
      final before = await RankingLadderViewModel.fetchBefore(
        repository,
        ExerciseType.squat,
      );
      expect(before!.me, _base.before.me);
      expect(before.entries, _base.before.entries);
    });

    test('is null when the ranking cannot be read', () async {
      final repository = _ScriptedRankings([
        Exception('offline'),
      ], clock: () => Duration.zero);
      expect(
        await RankingLadderViewModel.fetchBefore(
          repository,
          ExerciseType.pushUp,
        ),
        isNull,
      );
    });

    test('keeps no row of mine before my first battle', () async {
      final before = await RankingLadderViewModel.fetchBefore(
        InMemoryRankingsRepository(),
        ExerciseType.pushUp,
      );
      expect(before!.entries, isEmpty);
      expect(before.me, isNull);
    });
  });

  test('pointsOf counts as the server does', () {
    expect(
      RankingLadderViewModel.pointsOf(
        _battle(MatchOutcome.win, end: GameEnd.ko),
      ),
      10,
    );
    expect(RankingLadderViewModel.pointsOf(_battle(MatchOutcome.win)), 5);
    expect(
      RankingLadderViewModel.pointsOf(
        _battle(MatchOutcome.win, departure: BattleDeparture.opponentLeft),
      ),
      5,
    );
    expect(RankingLadderViewModel.pointsOf(_battle(MatchOutcome.draw)), 3);
    expect(RankingLadderViewModel.pointsOf(_battle(MatchOutcome.lose)), 1);
    expect(
      RankingLadderViewModel.pointsOf(
        _battle(MatchOutcome.lose, end: GameEnd.ko),
      ),
      1,
    );
    expect(
      RankingLadderViewModel.pointsOf(
        _battle(MatchOutcome.lose, departure: BattleDeparture.myConnectionLost),
      ),
      0,
    );
  });

  test('of takes the battle\'s exercise, rank, ranking and points', () {
    fakeAsync((async) {
      final repository = _ScriptedRankings([
        _confirmed,
      ], clock: () => async.elapsed);
      final before = _base.before;
      final viewModel = RankingLadderViewModel.of(
        _battle(MatchOutcome.draw, ranked: true, before: before),
        repository: repository,
        elapsed: () => async.elapsed,
      );
      expect(viewModel.exercise, ExerciseType.squat);
      expect(viewModel.ranked, isTrue);
      expect(viewModel.before, same(before));
      expect(viewModel.points, 3);
      // A result made elsewhere does not count.
      final other = RankingLadderViewModel.of(
        _battle(MatchOutcome.win),
        repository: repository,
      );
      expect(other.ranked, isFalse);
      expect(other.before, isNull);
      expect(other.decide(), LadderPath.none);
    });
  });
}
