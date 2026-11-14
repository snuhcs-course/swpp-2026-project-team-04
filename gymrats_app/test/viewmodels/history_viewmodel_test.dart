import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/viewmodels/history_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';

import '../support/fakes.dart';
import '../support/feedback_fakes.dart';

MatchRecord _record(int mine, {int? id}) => MatchRecord(
  id: id,
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: mine,
  opponentReps: 10,
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
}
