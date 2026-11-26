import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/models/hold_record.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/feedback/hold_record_store.dart';
import 'package:gymrats_app/viewmodels/history_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';

import '../support/fakes.dart';
import '../models/hold_record_test.dart' show holdRecord;
import '../support/feedback_fakes.dart';

MatchRecord _record(int mine, {int? id}) => MatchRecord(
  id: id,
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: mine,
  opponentReps: 10,
);

MatchRecord _played(
  DateTime at, {
  ExerciseType exercise = ExerciseType.pushUp,
  bool? online,
  int reps = 5,
}) => MatchRecord(
  exercise: exercise,
  opponentName: 'RepBot',
  myReps: reps,
  opponentReps: 3,
  playedAt: at,
  isOnline: online,
);

/// Friday 2026-11-13, 21:00 local.
final _now = DateTime(2026, 11, 13, 21);

void main() {
  late FakeUserRepository repository;
  late HistoryViewModel vm;

  setUp(() {
    repository = FakeUserRepository();
    vm = HistoryViewModel(repository: repository);
  });

  test('starts loading', () {
    expect(vm.state.phase, HistoryPhase.loading);
  });

  test('a user without battles sees the empty state', () async {
    await vm.load();
    expect(vm.state.phase, HistoryPhase.empty);
    expect(vm.state.hasMore, isFalse);
  });

  test('shows the first page in the order it came', () async {
    repository.historyPages = [
      [_record(3), _record(2)],
    ];
    await vm.load();
    expect(vm.state.phase, HistoryPhase.ready);
    expect(vm.state.matches.map((m) => m.myReps), [3, 2]);
    expect(vm.state.hasMore, isFalse);
  });

  test('loads older pages until the last one', () async {
    repository.historyPages = [
      [_record(5), _record(4)],
      [_record(3), _record(2)],
      [_record(1)],
    ];
    await vm.load();
    expect(vm.state.hasMore, isTrue);
    await vm.loadMore();
    await vm.loadMore();
    expect(vm.state.matches.map((m) => m.myReps), [5, 4, 3, 2, 1]);
    expect(vm.state.hasMore, isFalse);
    await vm.loadMore();
    expect(repository.historyCursors, [null, '1', '2']);
  });

  test('a failed first page shows the error and can be retried', () async {
    repository.historyError = const ApiException(ApiErrorKind.network);
    await vm.load();
    expect(vm.state.phase, HistoryPhase.failed);
    expect(
      vm.state.errorMessage,
      const ApiException(ApiErrorKind.network).message,
    );
    repository
      ..historyError = null
      ..historyPages = [
        [_record(1)],
      ];
    await vm.load();
    expect(vm.state.phase, HistoryPhase.ready);
  });

  test('an unknown failure shows the generic message', () async {
    repository.historyError = Exception('boom');
    await vm.load();
    expect(vm.state.errorMessage, genericErrorMessage);
  });

  test('a failed next page keeps the list and offers a retry', () async {
    repository.historyPages = [
      [_record(2)],
      [_record(1)],
    ];
    await vm.load();
    repository.historyError = Exception('offline');
    await vm.loadMore();
    expect(vm.state.phase, HistoryPhase.ready);
    expect(vm.state.matches, hasLength(1));
    expect(vm.state.loadMoreFailed, isTrue);
    expect(vm.state.loadingMore, isFalse);

    repository.historyError = null;
    await vm.loadMore();
    expect(vm.state.loadMoreFailed, isFalse);
    expect(vm.state.matches.map((m) => m.myReps), [2, 1]);
  });

  test('ignores loadMore while a page is loading', () async {
    repository.historyPages = [
      [_record(2)],
      [_record(1)],
    ];
    await vm.load();
    repository.historyGate = Completer();
    final first = vm.loadMore();
    expect(vm.state.loadingMore, isTrue);
    await vm.loadMore();
    repository.historyGate!.complete();
    await first;
    expect(repository.historyCursors, [null, '1']);
  });

  test('does nothing after dispose', () async {
    repository.historyGate = Completer();
    final loading = vm.load();
    vm.dispose();
    repository.historyGate!.complete();
    await loading;
  });

  group('archive summary (J3)', () {
    late FakeFeedbackStatsSource stats;

    setUp(() {
      stats = FakeFeedbackStatsSource([
        statsPoint(1, DateTime(2026, 11, 12, 9), reps: 8, score: 100),
        statsPoint(2, DateTime(2026, 11, 13, 9), reps: 12, score: 155),
      ]);
      repository.historyPages = [
        [_record(12, id: 2), _record(8, id: 1)],
      ];
      vm = HistoryViewModel(
        repository: repository,
        stats: stats,
        now: () => _now,
      );
    });

    test('loads after the first page, over every battle', () async {
      await vm.load();
      final archive = vm.state.archive!;
      expect(stats.calls, [(exercise: null, since: null)]);
      expect((archive.weekReps, archive.weekMatches), (20, 2));
      expect(archive.streakDays, 2);
      expect(
        archive.weekDaily.last,
        DayReps(date: DateTime(2026, 11, 13), reps: 12),
      );
      expect(archive.growth[ExerciseType.pushUp]!.bestScore, 155);
      expect(vm.state.statsFailed, isFalse);
    });

    test('the best gain of each row', () async {
      await vm.load();
      final [newer, older] = vm.state.matches;
      expect(vm.state.bestGainOf(newer), 55);
      expect(vm.state.bestGainOf(older), isNull);
    });

    test('the list shows before the summary arrives', () async {
      stats.gate = Completer<void>();
      final loading = vm.load();
      await pumpEventQueue();
      expect(vm.state.phase, HistoryPhase.ready);
      expect(vm.state.archive, isNull);
      expect(vm.state.bestGainOf(vm.state.matches.first), isNull);
      // The next page is not blocked by the summary.
      expect(vm.state.loadingMore, isFalse);
      stats.gate!.complete();
      await loading;
      expect(vm.state.archive, isNotNull);
    });

    test('a failed summary keeps the list; load tries again', () async {
      stats.error = const ApiException(ApiErrorKind.network);
      await vm.load();
      expect(vm.state.phase, HistoryPhase.ready);
      expect(vm.state.matches, hasLength(2));
      expect(vm.state.archive, isNull);
      expect(vm.state.statsFailed, isTrue);
      stats.error = null;
      await vm.load();
      expect(vm.state.archive, isNotNull);
      expect(vm.state.statsFailed, isFalse);
    });

    test('a later page keeps the summary', () async {
      repository.historyPages = [
        [_record(12, id: 2)],
        [_record(8, id: 1)],
      ];
      await vm.load();
      await vm.loadMore();
      expect(vm.state.matches, hasLength(2));
      expect(vm.state.archive!.weekMatches, 2);
    });

    test('no battles: no summary request', () async {
      repository.historyPages = [[]];
      await vm.load();
      expect(vm.state.phase, HistoryPhase.empty);
      expect(stats.calls, isEmpty);
      expect(vm.state.archive, isNull);
    });

    test('a failed first page asks for no summary', () async {
      repository.historyError = Exception('offline');
      await vm.load();
      expect(stats.calls, isEmpty);
    });

    test('a summary from an earlier load is dropped', () async {
      stats.gate = Completer<void>();
      final first = vm.load();
      await pumpEventQueue();
      // The first load's summary is still on its way when the user
      // reloads after the list failed once.
      final oldGate = stats.gate!;
      stats.gate = null;
      stats.points = [statsPoint(9, DateTime(2026, 11, 13, 10), reps: 1)];
      await vm.load();
      expect(vm.state.archive!.weekReps, 1);
      oldGate.complete();
      await first;
      expect(vm.state.archive!.weekReps, 1);
    });

    test('a failure from an earlier load is dropped too', () async {
      stats.gate = Completer<void>();
      final first = vm.load();
      await pumpEventQueue();
      final oldGate = stats.gate!;
      stats.gate = null;
      await vm.load();
      stats.error = Exception('late');
      oldGate.complete();
      await first;
      expect(vm.state.statsFailed, isFalse);
      expect(vm.state.archive, isNotNull);
    });

    test('nothing changes after dispose', () async {
      stats.gate = Completer<void>();
      final loading = vm.load();
      await pumpEventQueue();
      vm.dispose();
      stats.gate!.complete();
      await loading;
    });

    test('a repository that is a statistics source is used', () async {
      final both = FakeStatsUserRepository()
        ..historyPages = [
          [_record(3, id: 1)],
        ];
      both.stats.points = [statsPoint(1, DateTime(2026, 11, 13, 9), reps: 3)];
      final auto = HistoryViewModel(repository: both, now: () => _now);
      await auto.load();
      expect(auto.state.archive!.weekReps, 3);
    });

    test('without a statistics source the summary stays empty', () async {
      repository.historyPages = [
        [_record(3)],
      ];
      final plain = HistoryViewModel(repository: repository);
      await plain.load();
      expect(plain.state.phase, HistoryPhase.ready);
      expect(plain.state.archive, isNull);
      expect(plain.state.statsFailed, isFalse);
    });
  });
  group('운동일지 경기 tab (P13)', () {
    final today = DateTime(2026, 11, 13, 16, 4);
    final todayEarly = DateTime(2026, 11, 13, 9);
    final yesterday = DateTime(2026, 11, 12, 21);

    setUp(() {
      repository.historyPages = [
        [
          _played(today, online: true),
          _played(todayEarly, exercise: ExerciseType.squat, online: false),
          _played(yesterday, online: false),
          _played(DateTime(2026, 11, 10, 8)),
        ],
      ];
    });

    test('the chips keep an exercise, online or arcade battles; 전체 keeps '
        'all', () async {
      await vm.load();
      expect(vm.state.filter, ArchiveFilter.all);
      expect(vm.state.filtered, hasLength(4));
      vm.setFilter(ArchiveFilter.squat);
      expect(vm.state.filtered.single.playedAt, todayEarly);
      vm.setFilter(ArchiveFilter.pushUp);
      expect(vm.state.filtered, hasLength(3));
      vm.setFilter(ArchiveFilter.online);
      expect(vm.state.filtered.single.playedAt, today);
      // A battle whose kind is not known is neither online nor arcade.
      vm.setFilter(ArchiveFilter.arcade);
      expect(vm.state.filtered.map((m) => m.playedAt), [todayEarly, yesterday]);
      expect(ArchiveFilter.values.map((f) => f.label), [
        '전체',
        '푸쉬업',
        '스쿼트',
        '온라인',
        '아케이드',
      ]);
    });

    test('the battles are grouped by their local day, newest first', () async {
      await vm.load();
      final days = vm.state.days;
      expect(days.map((d) => d.date), [
        DateTime(2026, 11, 13),
        DateTime(2026, 11, 12),
        DateTime(2026, 11, 10),
      ]);
      expect(days.first.matches, hasLength(2));
      vm.setFilter(ArchiveFilter.online);
      expect(vm.state.days.single.matches.single.playedAt, today);
    });

    test('a battle without a time goes with the day before it', () {
      const untimed = MatchRecord(
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot',
        myReps: 1,
        opponentReps: 0,
      );
      expect(
        ArchiveDay.of([_played(today), untimed]).single.matches,
        hasLength(2),
      );
      expect(ArchiveDay.of([untimed]).single.matches, hasLength(1));
    });

    test('setting the same chip again tells nobody; a reload keeps the '
        'chip, period and exercise', () async {
      await vm.load();
      var told = 0;
      vm.addListener(() => told++);
      vm.setFilter(ArchiveFilter.all);
      vm.setPeriod(StatsPeriod.week);
      vm.setExercise(ExerciseType.pushUp);
      expect(told, 0);
      vm
        ..setFilter(ArchiveFilter.squat)
        ..setPeriod(StatsPeriod.month)
        ..setExercise(ExerciseType.squat);
      expect(told, 3);
      repository.historyPages = [
        [_played(today)],
      ];
      await vm.load();
      expect(vm.state.filter, ArchiveFilter.squat);
      expect(vm.state.period, StatsPeriod.month);
      expect(vm.state.exercise, ExerciseType.squat);
    });
  });

  group('운동일지 전체 tab (P13)', () {
    late FakeFeedbackStatsSource stats;

    setUp(() {
      stats = FakeFeedbackStatsSource([
        // Last month: only in 전체 기간.
        statsPoint(1, DateTime(2026, 10, 30, 9), reps: 20, score: 200),
        // This week (from Monday 11-09).
        statsPoint(
          2,
          DateTime(2026, 11, 10, 9),
          reps: 4,
          score: 60,
          issues: {'reject.insufficientDepth': 3, 'reject.kneesDown': 1},
        ),
        statsPoint(
          3,
          DateTime(2026, 11, 12, 9),
          reps: 7,
          score: 110,
          issues: {'reject.insufficientDepth': 2},
        ),
        statsPoint(
          4,
          DateTime(2026, 11, 13, 9),
          reps: 9,
          score: 90,
          exercise: ExerciseType.squat,
        ),
        // Not played yet: left out.
        statsPoint(5, DateTime(2026, 11, 14, 9), reps: 99, score: 999),
      ]);
      repository.historyPages = [
        [_record(7, id: 3)],
      ];
      vm = HistoryViewModel(
        repository: repository,
        stats: stats,
        now: () => _now,
      );
    });

    test('nothing to show before the battles load', () {
      expect(vm.growth, isNull);
    });

    test("this week's push-ups: battles, reps per battle, best score and "
        'the chart, oldest first', () async {
      await vm.load();
      final growth = vm.growth!;
      expect(growth.period, StatsPeriod.week);
      expect(growth.exercise, ExerciseType.pushUp);
      expect(growth.matches, 2);
      expect(growth.repsPerMatch, 5.5);
      expect(growth.bestScore, 110);
      expect(growth.points.map((p) => (p.score, p.reps)), [(60, 4), (110, 7)]);
    });

    test('the reject reasons of the period, most first', () async {
      await vm.load();
      expect(vm.growth!.issues.map((i) => (i.reason, i.count)), [
        (RejectReason.insufficientDepth, 5),
        (RejectReason.kneesDown, 1),
      ]);
    });

    test('the bests of every exercise come from all battles played', () async {
      await vm.load();
      final bests = vm.growth!.bests;
      expect(bests.map((b) => (b.exercise, b.score, b.reps)), [
        (ExerciseType.pushUp, 200, 20),
        (ExerciseType.squat, 90, 9),
      ]);
      expect(bests.first.playedAt, DateTime(2026, 10, 30, 9));
    });

    test('전체 기간 and squats', () async {
      await vm.load();
      vm.setPeriod(StatsPeriod.all);
      expect(vm.growth!.matches, 3);
      expect(vm.growth!.bestScore, 200);
      vm.setExercise(ExerciseType.squat);
      expect(vm.growth!.matches, 1);
      expect(vm.growth!.issues, isEmpty);
    });

    test('a period without battles: zeros, no best, no chart', () async {
      stats.points = [statsPoint(1, DateTime(2026, 10, 30, 9), reps: 20)];
      await vm.load();
      final growth = vm.growth!;
      expect(growth.matches, 0);
      expect(growth.repsPerMatch, 0);
      expect(growth.bestScore, isNull);
      expect(growth.points, isEmpty);
      // The October battle kept no score: no best either.
      expect(growth.bests, isEmpty);
    });

    test('the chart keeps the newest ten; the first of equal bests '
        'stays', () async {
      stats.points = [
        for (var i = 0; i < 12; i++)
          statsPoint(i, DateTime(2026, 11, 2 + i % 10, 9 + i), score: 50),
      ];
      await vm.load();
      vm.setPeriod(StatsPeriod.all);
      final growth = vm.growth!;
      expect(growth.points, hasLength(ArchiveGrowth.chartCount));
      expect(growth.bests.single.playedAt, DateTime(2026, 11, 2, 9));
    });
  });
  group('holds in the journal (P13)', () {
    HoldRecord hold(DateTime at, {int heldMs = 20000, HoldPose? pose}) =>
        holdRecord(endedAt: at, heldMs: heldMs, pose: pose ?? HoldPose.plank);

    test('the holds come with the first page and sit between the battles by '
        'time', () async {
      final store = InMemoryHoldRecordStore();
      await store.save(hold(DateTime(2026, 11, 13, 12)));
      await store.save(hold(DateTime(2026, 11, 12, 22)));
      repository.historyPages = [
        [
          _played(DateTime(2026, 11, 13, 16)),
          _played(DateTime(2026, 11, 12, 21)),
        ],
      ];
      vm = HistoryViewModel(repository: repository, holdRecords: store);
      await vm.load();
      expect(vm.state.holds, hasLength(2));
      final days = vm.state.days;
      expect(days.first.entries.map((e) => e.runtimeType), [
        ArchiveMatchEntry,
        ArchiveHoldEntry,
      ]);
      expect(days.last.entries.map((e) => e.runtimeType), [
        ArchiveHoldEntry,
        ArchiveMatchEntry,
      ]);
      expect(days.first.matches, hasLength(1));
      expect(days.first.holds, hasLength(1));
    });

    test('아케이드 lists the arcade battles and the holds, an exercise and '
        '온라인 only battles', () async {
      final store = InMemoryHoldRecordStore();
      await store.save(hold(DateTime(2026, 11, 13, 12)));
      repository.historyPages = [
        [_played(DateTime(2026, 11, 13, 16), online: false)],
      ];
      vm = HistoryViewModel(repository: repository, holdRecords: store);
      await vm.load();
      vm.setFilter(ArchiveFilter.arcade);
      expect(vm.state.days.single.entries, hasLength(2));
      vm.setFilter(ArchiveFilter.pushUp);
      expect(vm.state.days.single.holds, isEmpty);
      vm.setFilter(ArchiveFilter.online);
      expect(vm.state.days, isEmpty);
      expect(ArchiveFilter.values.where((f) => f.keepsHolds), [
        ArchiveFilter.all,
        ArchiveFilter.arcade,
      ]);
    });

    test('holds older than the battles shown wait while older pages are '
        'left', () {
      final days = ArchiveDay.of(
        [_played(DateTime(2026, 11, 13, 16))],
        holds: [
          hold(DateTime(2026, 11, 13, 17)),
          hold(DateTime(2026, 11, 10, 9)),
        ],
        complete: false,
      );
      expect(days.single.holds, hasLength(1));
      expect(
        ArchiveDay.of(
          const [],
          holds: [hold(DateTime(2026, 11, 10, 9))],
          complete: false,
        ),
        isEmpty,
      );
    });

    test(
      'holds alone make the journal ready; a failing store lists none',
      () async {
        final store = InMemoryHoldRecordStore();
        await store.save(hold(DateTime(2026, 11, 13, 12)));
        repository.historyPages = [[]];
        vm = HistoryViewModel(repository: repository, holdRecords: store);
        await vm.load();
        expect(vm.state.phase, HistoryPhase.ready);
        expect(vm.state.days.single.holds, hasLength(1));

        repository.historyPages = [[]];
        final failing = HistoryViewModel(
          repository: repository,
          holdRecords: _FailingHolds(),
        );
        await failing.load();
        expect(failing.state.phase, HistoryPhase.empty);
        expect(failing.state.holds, isEmpty);
      },
    );

    test('the 전체 tab: holds and time held of the period, each pose\'s '
        'longest', () async {
      final store = InMemoryHoldRecordStore();
      await store.save(hold(DateTime(2026, 11, 13, 12), heldMs: 24600));
      await store.save(hold(DateTime(2026, 11, 10, 12), heldMs: 30000));
      await store.save(hold(DateTime(2026, 10, 2, 12), heldMs: 40000));
      await store.save(
        hold(DateTime(2026, 11, 11, 12), heldMs: 15000, pose: HoldPose.chair),
      );
      // Not played yet: left out.
      await store.save(hold(DateTime(2026, 11, 14, 12), heldMs: 99000));
      repository.historyPages = [
        [_played(DateTime(2026, 11, 13, 16))],
      ];
      vm = HistoryViewModel(
        repository: repository,
        holdRecords: store,
        now: () => _now,
      );
      expect(vm.holdSummary, isNull);
      await vm.load();
      final week = vm.holdSummary!;
      expect(week.count, 3);
      expect(week.held, const Duration(milliseconds: 24600 + 30000 + 15000));
      expect(week.bests.map((h) => (h.pose, h.held.inSeconds)), [
        (HoldPose.plank, 40),
        (HoldPose.chair, 15),
      ]);
      vm.setPeriod(StatsPeriod.all);
      expect(vm.holdSummary!.count, 4);
    });
  });
  test('each pose\'s holds of the period in time, the newest ten (P13)', () {
    final now = DateTime(2026, 11, 13, 21);
    HoldRecord at(int day, int hour, {HoldPose pose = HoldPose.plank}) =>
        holdRecord(endedAt: DateTime(2026, 11, day, hour), pose: pose);
    final holds = ArchiveHolds.of(
      [
        for (var i = 0; i < 12; i++) at(9 + i % 4, 8 + i),
        at(12, 9, pose: HoldPose.chair),
        // Last month: not in this week's trend.
        holdRecord(endedAt: DateTime(2026, 10, 1, 9), pose: HoldPose.chair),
      ],
      StatsPeriod.week,
      now,
    );
    final plank = holds.trends[HoldPose.plank]!;
    expect(plank, hasLength(ArchiveHolds.trendCount));
    expect([
      for (var i = 1; i < plank.length; i++)
        !plank[i].endedAt.isBefore(plank[i - 1].endedAt),
    ], everyElement(isTrue));
    expect(holds.trends[HoldPose.chair], hasLength(1));
    expect(ArchiveHolds.of(const [], StatsPeriod.week, now).trends, isEmpty);
  });
}

class _FailingHolds implements HoldRecordStore {
  @override
  Future<void> save(HoldRecord record) async {}

  @override
  Future<List<HoldRecord>> list() async => throw StateError('no files');
}
