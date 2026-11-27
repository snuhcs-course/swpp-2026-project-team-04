import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/viewmodels/weekly_rankings_viewmodel.dart';

WeeklyRanking week(
  RankingScope scope, {
  List<RankingEntry> entries = const [],
}) => WeeklyRanking(
  scope: scope,
  weekStart: DateTime.utc(2026, 11, 22, 15),
  weekEnd: DateTime.utc(2026, 11, 29, 15),
  entries: entries,
  me: null,
);

/// Answers each read with the next completer of its scope.
class ScriptedRankings implements RankingsRepository {
  final calls = <RankingScope>[];
  final pending = <Completer<WeeklyRanking>>[];

  @override
  Future<WeeklyRanking> fetchWeekly(RankingScope scope) {
    calls.add(scope);
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
    vm = WeeklyRankingsViewModel(repository: repo);
    changes = 0;
    vm.addListener(() => changes++);
  });

  test('starts on the global ranking, loading it', () async {
    expect(vm.scope, RankingScope.global);
    final loading = vm.load();
    expect(vm.loading, isTrue);
    expect(vm.ranking, isNull);
    expect(vm.error, isNull);

    repo.pending.single.complete(week(RankingScope.global));
    await loading;

    expect(vm.loading, isFalse);
    expect(vm.ranking!.scope, RankingScope.global);
    expect(repo.calls, [RankingScope.global]);
    expect(changes, 2);
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
}
