import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/ranking_standing.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/viewmodels/weekly_rankings_viewmodel.dart';

WeeklyRanking week(
  RankingScope scope, {
  ExerciseType exercise = ExerciseType.pushUp,
  List<RankingEntry> entries = const [],
}) => WeeklyRanking(
  scope: scope,
  exercise: exercise,
  weekStart: DateTime.utc(2026, 11, 22, 15),
  weekEnd: DateTime.utc(2026, 11, 29, 15),
  entries: entries,
  me: null,
);

/// Answers each read with the next completer; [calls] keeps the scopes read
/// and [exercises] their exercises.
class ScriptedRankings implements RankingsRepository {
  final calls = <RankingScope>[];
  final exercises = <ExerciseType>[];
  final pending = <Completer<WeeklyRanking>>[];

  @override
  Future<WeeklyRanking> fetchWeekly(RankingScope scope, ExerciseType exercise) {
    calls.add(scope);
    exercises.add(exercise);
    final answer = Completer<WeeklyRanking>();
    pending.add(answer);
    return answer.future;
  }
}

void main() {
  late ScriptedRankings repo;
  late WeeklyRankingsViewModel vm;
  late int changes;

  setUp(() {
    repo = ScriptedRankings();
    // Wednesday of the week of week(), whatever today is.
    vm = WeeklyRankingsViewModel(
      repository: repo,
      now: () => DateTime.utc(2026, 11, 25),
    );
    changes = 0;
    vm.addListener(() => changes++);
  });

  test('starts on the global ranking of push-ups, loading it', () async {
    expect(vm.scope, RankingScope.global);
    expect(vm.exercise, ExerciseType.pushUp);
    final loading = vm.load();
    expect(vm.loading, isTrue);
    expect(vm.ranking, isNull);
    expect(vm.error, isNull);

    repo.pending.single.complete(week(RankingScope.global));
    await loading;

    expect(vm.loading, isFalse);
    expect(vm.ranking!.scope, RankingScope.global);
    expect(repo.calls, [RankingScope.global]);
    expect(repo.exercises, [ExerciseType.pushUp]);
    expect(changes, 2);
  });

  test(
    'choosing squats reads them in the shown scope and keeps push-ups',
    () async {
      final pushUps = vm.load();
      repo.pending.single.complete(week(RankingScope.global));
      await pushUps;

      final squats = vm.selectExercise(ExerciseType.squat);
      expect(vm.exercise, ExerciseType.squat);
      expect(vm.ranking, isNull);
      expect(vm.loading, isTrue);
      repo.pending.last.complete(
        week(RankingScope.global, exercise: ExerciseType.squat),
      );
      await squats;
      expect(vm.ranking!.exercise, ExerciseType.squat);

      // The friends tab keeps squats.
      final friends = vm.select(RankingScope.friends);
      repo.pending.last.complete(
        week(RankingScope.friends, exercise: ExerciseType.squat),
      );
      await friends;
      expect(vm.ranking!.scope, RankingScope.friends);
      expect(vm.ranking!.exercise, ExerciseType.squat);

      await vm.select(RankingScope.global);
      await vm.selectExercise(ExerciseType.pushUp);
      expect(vm.ranking!.exercise, ExerciseType.pushUp);
      expect(repo.exercises, [
        ExerciseType.pushUp,
        ExerciseType.squat,
        ExerciseType.squat,
      ]);
      expect(repo.calls, [
        RankingScope.global,
        RankingScope.global,
        RankingScope.friends,
      ]);
    },
  );

  test('choosing the shown exercise does nothing', () async {
    await vm.selectExercise(ExerciseType.pushUp);
    expect(repo.calls, isEmpty);
    expect(changes, 0);
  });

  test('a second load while one is on, or after it, reads nothing', () async {
    final first = vm.load();
    unawaited(vm.load());
    repo.pending.single.complete(week(RankingScope.global));
    await first;
    await vm.load();

    expect(repo.calls, [RankingScope.global]);
  });

  test(
    'choosing friends shows and reads them; coming back keeps global',
    () async {
      final global = vm.load();
      repo.pending.single.complete(week(RankingScope.global));
      await global;

      final friends = vm.select(RankingScope.friends);
      expect(vm.scope, RankingScope.friends);
      expect(vm.ranking, isNull);
      expect(vm.loading, isTrue);
      repo.pending.last.complete(week(RankingScope.friends));
      await friends;
      expect(vm.ranking!.scope, RankingScope.friends);

      await vm.select(RankingScope.global);
      expect(vm.ranking!.scope, RankingScope.global);
      expect(repo.calls, [RankingScope.global, RankingScope.friends]);
    },
  );

  test('choosing the shown scope does nothing', () async {
    await vm.select(RankingScope.global);
    expect(repo.calls, isEmpty);
    expect(changes, 0);
  });

  test('a slow scope lands under its own tab, not the shown one', () async {
    unawaited(vm.load());
    final friends = vm.select(RankingScope.friends);
    repo.pending.last.complete(week(RankingScope.friends));
    await friends;
    repo.pending.first.complete(week(RankingScope.global));
    await pumpEventQueue();

    expect(vm.scope, RankingScope.friends);
    expect(vm.ranking!.scope, RankingScope.friends);
    await vm.select(RankingScope.global);
    expect(vm.ranking!.scope, RankingScope.global);
  });

  test('a failed read says why, and retry reads again', () async {
    final first = vm.load();
    repo.pending.single.completeError(const ApiException(ApiErrorKind.network));
    await first;

    expect(vm.error, const ApiException(ApiErrorKind.network).message);
    expect(vm.ranking, isNull);
    expect(vm.loading, isFalse);

    final again = vm.retry();
    expect(vm.error, isNull);
    repo.pending.last.complete(week(RankingScope.global));
    await again;
    expect(vm.ranking, isNotNull);
    expect(repo.calls, [RankingScope.global, RankingScope.global]);
  });

  test('any other failure gets the general message', () async {
    final first = vm.load();
    repo.pending.single.completeError(StateError('boom'));
    await first;
    expect(vm.error, '랭킹을 불러오지 못했어요. 다시 시도해 주세요.');
  });

  test('retry reads a shown ranking again', () async {
    final first = vm.load();
    repo.pending.single.complete(week(RankingScope.global));
    await first;
    final again = vm.retry();
    expect(vm.ranking, isNull);
    repo.pending.last.complete(week(RankingScope.global));
    await again;
    expect(repo.calls, hasLength(2));
  });

  test('an answer after dispose tells no one', () async {
    final loading = vm.load();
    vm.dispose();
    repo.pending.single.complete(week(RankingScope.global));
    await loading;
    expect(changes, 1);
  });

  group('when the week ends', () {
    // The week of week(): it ends on Monday 11.30 00:00 KST.
    final weekEnd = DateTime.utc(2026, 11, 29, 15);
    late DateTime now;

    setUp(() {
      now = weekEnd.subtract(const Duration(hours: 1));
      vm = WeeklyRankingsViewModel(repository: repo, now: () => now);
    });

    Future<void> answer(int index, RankingScope scope) async {
      repo.pending[index].complete(week(scope));
      await pumpEventQueue();
    }

    test('coming back after it reads the shown ranking again', () async {
      unawaited(vm.load());
      await answer(0, RankingScope.global);

      await vm.refreshIfWeekEnded();
      expect(repo.calls, hasLength(1));

      now = weekEnd;
      unawaited(vm.refreshIfWeekEnded());
      expect(vm.ranking, isNull);
      expect(vm.loading, isTrue);
      expect(repo.calls, hasLength(2));
    });

    test('a tab kept from the old week is read again when chosen', () async {
      unawaited(vm.load());
      await answer(0, RankingScope.global);
      unawaited(vm.select(RankingScope.friends));
      await answer(1, RankingScope.friends);

      now = weekEnd.add(const Duration(minutes: 1));
      unawaited(vm.select(RankingScope.global));

      expect(vm.ranking, isNull);
      expect(repo.calls, [
        RankingScope.global,
        RankingScope.friends,
        RankingScope.global,
      ]);
    });

    test('the open screen reads again at the end of the week', () {
      fakeAsync((async) {
        vm = WeeklyRankingsViewModel(
          repository: repo,
          now: () =>
              weekEnd.subtract(const Duration(hours: 1)).add(async.elapsed),
        );
        unawaited(vm.load());
        repo.pending.single.complete(week(RankingScope.global));
        async.flushMicrotasks();
        expect(repo.calls, hasLength(1));

        async.elapse(const Duration(minutes: 59));
        expect(repo.calls, hasLength(1));
        async.elapse(const Duration(minutes: 1));
        expect(repo.calls, hasLength(2));
        vm.dispose();
      });
    });

    test('a week already over by the phone\'s clock is not read on and on', () {
      fakeAsync((async) {
        vm = WeeklyRankingsViewModel(
          repository: repo,
          now: () => weekEnd.add(const Duration(minutes: 5)),
        );
        unawaited(vm.load());
        repo.pending.single.complete(week(RankingScope.global));
        async.flushMicrotasks();

        async.elapse(const Duration(hours: 1));
        expect(repo.calls, hasLength(1));
        expect(vm.ranking, isNotNull);
        vm.dispose();
      });
    });

    test('a timer that fires early by the clock waits again', () {
      fakeAsync((async) {
        var lag = Duration.zero;
        vm = WeeklyRankingsViewModel(
          repository: repo,
          now: () => weekEnd
              .subtract(const Duration(hours: 1))
              .add(async.elapsed)
              .subtract(lag),
        );
        unawaited(vm.load());
        repo.pending.single.complete(week(RankingScope.global));
        async.flushMicrotasks();

        // The clock was set back a minute during the week.
        lag = const Duration(minutes: 1);
        async.elapse(const Duration(hours: 1));
        expect(repo.calls, hasLength(1));
        async.elapse(const Duration(minutes: 1));
        expect(repo.calls, hasLength(2));
        vm.dispose();
      });
    });

    test('a kept tab shown again still reads at the end of the week', () {
      fakeAsync((async) {
        vm = WeeklyRankingsViewModel(
          repository: repo,
          now: () =>
              weekEnd.subtract(const Duration(hours: 1)).add(async.elapsed),
        );
        unawaited(vm.load());
        repo.pending.single.complete(week(RankingScope.global));
        async.flushMicrotasks();
        // Friends fail, which leaves no ranking shown, then back to global.
        unawaited(vm.select(RankingScope.friends));
        repo.pending.last.completeError(StateError('down'));
        async.flushMicrotasks();
        unawaited(vm.select(RankingScope.global));
        async.flushMicrotasks();
        expect(repo.calls, hasLength(2));

        async.elapse(const Duration(hours: 1));
        expect(repo.calls, [
          RankingScope.global,
          RankingScope.friends,
          RankingScope.global,
        ]);
        vm.dispose();
      });
    });

    test('a read that crosses the end of the week reads the new one', () async {
      final loading = vm.load();
      // Monday 00:00 comes while the read is on.
      now = weekEnd.add(const Duration(seconds: 1));
      repo.pending.single.complete(week(RankingScope.global));
      await pumpEventQueue();

      expect(repo.calls, hasLength(2));
      expect(vm.ranking, isNull);
      expect(vm.loading, isTrue);
      final next = WeeklyRanking(
        scope: RankingScope.global,
        weekStart: weekEnd,
        weekEnd: weekEnd.add(const Duration(days: 7)),
        entries: const [],
        me: null,
      );
      repo.pending.last.complete(next);
      await loading;
      expect(vm.ranking, same(next));
    });

    test('an old week again after that is kept, read only twice', () async {
      final loading = vm.load();
      now = weekEnd.add(const Duration(seconds: 1));
      repo.pending.single.complete(week(RankingScope.global));
      await pumpEventQueue();
      // The server still answers the old week: its clock is behind.
      repo.pending.last.complete(week(RankingScope.global));
      await loading;

      expect(repo.calls, hasLength(2));
      expect(vm.ranking!.weekEnd, weekEnd);
    });

    test('dispose stops the end-of-week read', () {
      fakeAsync((async) {
        vm = WeeklyRankingsViewModel(
          repository: repo,
          now: () =>
              weekEnd.subtract(const Duration(hours: 1)).add(async.elapsed),
        );
        unawaited(vm.load());
        repo.pending.single.complete(week(RankingScope.global));
        async.flushMicrotasks();
        vm.dispose();

        async.elapse(const Duration(hours: 2));
        expect(repo.calls, hasLength(1));
      });
    });
  });

  group("the screen's words (A13 spec 3.6)", () {
    RankingEntry e(
      int rank,
      int points, {
      bool me = false,
      int battles = 3,
      String name = '친구',
    }) => RankingEntry(
      rank: rank,
      userId: rank + (me ? 100 : 0),
      nickname: me ? '쥐돌이' : name,
      points: points,
      battles: battles,
      wins: battles == 0 ? 0 : 2,
      koWins: battles == 0 ? 0 : 1,
      isMe: me,
    );

    WeeklyRanking ranking(
      RankingScope scope,
      List<RankingEntry> entries, {
      RankingEntry? me,
    }) => WeeklyRanking(
      scope: scope,
      exercise: ExerciseType.pushUp,
      weekStart: DateTime.utc(2026, 11, 22, 15),
      weekEnd: DateTime.utc(2026, 11, 29, 15),
      entries: entries,
      me: me,
    );

    Future<void> shown(WeeklyRanking answer) async {
      final loading = vm.load();
      repo.pending.last.complete(answer);
      await loading;
    }

    test('nothing to say until read', () {
      expect(vm.weekName, isNull);
      expect(vm.timeLeft, isNull);
      expect(vm.weekProgress, 0);
      expect(vm.myEntry, isNull);
      expect(vm.standing, isNull);
      expect(vm.myRecord, '이번 주 기록 없음');
      expect(vm.noFriends, isFalse);
      expect(vm.listTitle, isNull);
      expect(vm.listNote, isNull);
    });

    test('the week by this clock: its name, the time left, how far it has '
        'gone', () async {
      await shown(ranking(RankingScope.global, const []));
      expect(vm.weekName, '11월 4주차');
      expect(vm.timeLeft, '4일 15시간 남음');
      expect(vm.weekProgress, closeTo(57 / 168, 1e-9));
    });

    test('the clock moves the time left and the bar to their ends', () async {
      var now = DateTime.utc(2026, 11, 22, 15);
      final clocked = WeeklyRankingsViewModel(repository: repo, now: () => now);
      addTearDown(clocked.dispose);
      final loading = clocked.load();
      repo.pending.last.complete(ranking(RankingScope.global, const []));
      await loading;
      expect(clocked.weekProgress, 0);
      expect(clocked.timeLeft, '7일 0시간 남음');
      now = DateTime.utc(2026, 11, 29, 14, 30);
      expect(clocked.timeLeft, '30분 남음');
      now = DateTime.utc(2026, 11, 29, 15);
      expect(clocked.weekProgress, 1);
      expect(clocked.timeLeft, '곧 새로 시작해요');
    });

    test('global: my row from the server, the goal above me, the list '
        'words', () async {
      final mine = e(4, 19, me: true);
      await shown(
        ranking(RankingScope.global, [
          e(1, 31),
          e(2, 23),
          e(3, 22),
          mine,
        ], me: mine),
      );
      expect(vm.myEntry, mine);
      expect(vm.myRecord, '3전 2승 · KO 1');
      expect(vm.standing!.kind, StandingKind.behind);
      expect(vm.standing!.goalLine, '3위까지 3점');
      expect(vm.listTitle, 'TOP 50');
      expect(vm.listNote, '같은 점수는 같은 등수');
      expect(vm.noFriends, isFalse);
    });

    test('global, below the list: the goal at its last row', () async {
      await shown(
        ranking(RankingScope.global, [e(50, 6)], me: e(63, 4, me: true)),
      );
      expect(vm.standing!.kind, StandingKind.outsideList);
      expect(vm.standing!.goalLine, '50위까지 2점');
      expect(vm.listNote, '50위 안에 들면 목록에 나와요');
    });

    test('global, before my first battle: unranked, no note', () async {
      await shown(ranking(RankingScope.global, [e(1, 31)]));
      expect(vm.myEntry, isNull);
      expect(vm.standing!.unranked, isTrue);
      expect(vm.standing!.plainLine, '대결하면 순위에 올라요');
      expect(vm.listNote, isEmpty);
    });

    test('friends: mine among the rows; first, ahead of 2nd', () async {
      final friends = vm.select(RankingScope.friends);
      repo.pending.last.complete(
        ranking(RankingScope.friends, [e(1, 19, me: true), e(2, 15)]),
      );
      await friends;
      expect(vm.myEntry?.nickname, '쥐돌이');
      expect(vm.standing!.kind, StandingKind.first);
      expect(vm.standing!.goalLine, '2위보다 4점 앞섬');
      expect(vm.listTitle, '나와 친구 1명');
      expect(vm.noFriends, isFalse);
    });

    test('friends with only me: the card asking for friends', () async {
      final friends = vm.select(RankingScope.friends);
      repo.pending.last.complete(
        ranking(RankingScope.friends, [e(1, 19, me: true)]),
      );
      await friends;
      expect(vm.noFriends, isTrue);
      expect(vm.standing!.kind, StandingKind.noFriends);
      expect(vm.standing!.goalLine, isNull);
    });

    test('friends, nobody played: – for everyone and the note', () async {
      final friends = vm.select(RankingScope.friends);
      repo.pending.last.complete(
        ranking(RankingScope.friends, [
          e(1, 0, battles: 0),
          e(1, 0, battles: 0, me: true),
        ]),
      );
      await friends;
      expect(vm.myRecord, '이번 주 기록 없음');
      expect(vm.standing!.plainLine, '대결하면 점수가 쌓여요');
      expect(vm.listNote, '이번 주 아직 아무도 대결하지 않았어요');
    });

    test("my name: my row's, else the account's, else 나", () async {
      expect(vm.myName('우현'), '우현');
      expect(vm.myName(null), '나');
      final mine = e(4, 19, me: true);
      await shown(ranking(RankingScope.global, [mine], me: mine));
      expect(vm.myName('우현'), '쥐돌이');
    });

    test("a row's record", () {
      expect(WeeklyRankingsViewModel.recordOf(e(1, 5)), '3전 2승 · KO 1');
      expect(WeeklyRankingsViewModel.recordOf(null), '이번 주 기록 없음');
    });
  });
}
