import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/viewmodels/history_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';

import '../support/fakes.dart';

MatchRecord _record(int mine) => MatchRecord(
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: mine,
  opponentReps: 10,
);

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
}
