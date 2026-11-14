import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_stats.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/viewmodels/feedback_stats_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';

import '../support/feedback_fakes.dart';

/// Friday 2026-11-13, 21:00 local.
final _now = DateTime(2026, 11, 13, 21);

void main() {
  late FakeFeedbackStatsSource source;
  late FeedbackStatsViewModel vm;
  late int notified;

  setUp(() {
    source = FakeFeedbackStatsSource([
      statsPoint(1, DateTime(2026, 10, 20, 9), reps: 20),
      statsPoint(
        2,
        DateTime(2026, 11, 3, 9),
        reps: 6,
        exercise: ExerciseType.squat,
        issues: {'reject.shallowSquat': 2},
      ),
      statsPoint(
        3,
        DateTime(2026, 11, 10, 9),
        reps: 10,
        issues: {'elbow_flare': 1},
      ),
      statsPoint(4, DateTime(2026, 11, 13, 9), reps: 14),
    ]);
    vm = FeedbackStatsViewModel(source: source, now: () => _now);
    notified = 0;
    vm.addListener(() => notified++);
  });

  test('starts loading on this week, both exercises', () {
    expect(vm.state.phase, FeedbackStatsPhase.loading);
    expect(vm.state.period, StatsPeriod.week);
    expect(vm.state.exercise, isNull);
    expect(vm.state.stats, isNull);
  });

  test("loads every battle once and shows this week's values", () async {
    await vm.load();
    expect(source.calls, [(exercise: null, since: null)]);
    final week = vm.state.stats!;
    expect(vm.state.phase, FeedbackStatsPhase.ready);
    expect(week.period, StatsPeriod.week);
    expect(week.matches, 2);
    expect(week.averageReps, 12);
    expect(week.daily, hasLength(7));
    expect(week.issues, const [IssueCount(code: 'elbow_flare', count: 1)]);
  });

  test('switching the period needs no new request (UAT-4 AC3)', () async {
    await vm.load();
    vm.selectPeriod(StatsPeriod.month);
    expect(vm.state.stats!.period, StatsPeriod.month);
    expect(vm.state.stats!.matches, 3);
    expect(vm.state.stats!.averageReps, 10);
    expect(vm.state.stats!.daily, hasLength(13));
    vm.selectPeriod(StatsPeriod.all);
    expect(vm.state.stats!.matches, 4);
    expect(vm.state.stats!.averageReps, 12.5);
    expect(vm.state.stats!.issues.map((i) => i.code), [
      'reject.shallowSquat',
      'elbow_flare',
    ]);
    expect(source.calls, hasLength(1));
  });

  test('choosing an exercise keeps the period', () async {
    await vm.load();
    vm.selectPeriod(StatsPeriod.all);
    vm.selectExercise(ExerciseType.squat);
    expect(vm.state.exercise, ExerciseType.squat);
    expect(vm.state.period, StatsPeriod.all);
    expect(vm.state.stats!.matches, 1);
    expect(vm.state.stats!.issues.single.rejectReason, isNotNull);
    vm.selectExercise(null);
    expect(vm.state.stats!.matches, 4);
  });

  test('choosing the same tab again changes nothing', () async {
    await vm.load();
    final before = notified;
    vm.selectPeriod(StatsPeriod.week);
    vm.selectExercise(null);
    expect(notified, before);
  });

  test('a tab chosen while loading is kept for the result', () async {
    source.gate = Completer<void>();
    final loading = vm.load();
    vm.selectPeriod(StatsPeriod.all);
    vm.selectExercise(ExerciseType.pushUp);
    expect(vm.state.phase, FeedbackStatsPhase.loading);
    expect(vm.state.stats, isNull);
    expect(vm.state.period, StatsPeriod.all);
    source.gate!.complete();
    await loading;
    expect(vm.state.stats!.period, StatsPeriod.all);
    expect(vm.state.stats!.matches, 3);
  });

  test('the first tab and exercise can be given', () async {
    final month = FeedbackStatsViewModel(
      source: source,
      now: () => _now,
      period: StatsPeriod.month,
      exercise: ExerciseType.squat,
    );
    await month.load();
    expect(month.state.stats!.period, StatsPeriod.month);
    expect(month.state.stats!.matches, 1);
  });

  test('a user without battles sees zeros, not an error', () async {
    source.points = const [];
    await vm.load();
    expect(vm.state.phase, FeedbackStatsPhase.ready);
    expect(vm.state.stats!.matches, 0);
    expect(vm.state.stats!.averageReps, isNull);
  });

  test('a failure shows the message and can be retried', () async {
    source.error = const ApiException(ApiErrorKind.network);
    await vm.load();
    expect(vm.state.phase, FeedbackStatsPhase.failed);
    expect(
      vm.state.errorMessage,
      const ApiException(ApiErrorKind.network).message,
    );
    // A tab change while failed only moves the tab.
    vm.selectPeriod(StatsPeriod.month);
    expect(vm.state.phase, FeedbackStatsPhase.failed);
    expect(vm.state.period, StatsPeriod.month);
    expect(vm.state.stats, isNull);
    source.error = null;
    await vm.load();
    expect(vm.state.phase, FeedbackStatsPhase.ready);
    expect(vm.state.stats!.period, StatsPeriod.month);
    expect(vm.state.errorMessage, isNull);
  });

  test('an unknown failure shows the generic message', () async {
    source.error = Exception('boom');
    await vm.load();
    expect(vm.state.errorMessage, genericErrorMessage);
  });

  test('ignores load while one is running', () async {
    source.gate = Completer<void>();
    final first = vm.load();
    await vm.load();
    source.gate!.complete();
    await first;
    expect(source.calls, hasLength(1));
  });

  test('does nothing after dispose', () async {
    source.gate = Completer<void>();
    final loading = vm.load();
    vm.dispose();
    source.gate!.complete();
    await loading;
    await vm.load();
    expect(source.calls, hasLength(1));
  });

  test('uses the clock at each computation', () async {
    var now = _now;
    final moving = FeedbackStatsViewModel(source: source, now: () => now);
    await moving.load();
    expect(moving.state.stats!.matches, 2);
    // The next Monday: this week starts over.
    now = DateTime(2026, 11, 16, 8);
    moving.selectPeriod(StatsPeriod.month);
    moving.selectPeriod(StatsPeriod.week);
    expect(moving.state.stats!.matches, 0);
  });
}
