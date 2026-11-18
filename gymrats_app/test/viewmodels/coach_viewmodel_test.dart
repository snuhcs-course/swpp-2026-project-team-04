import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_goal.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/feedback/coach_script.dart';
import 'package:gymrats_app/services/feedback/goal_store.dart';
import 'package:gymrats_app/viewmodels/coach_viewmodel.dart';

import '../support/feedback_fakes.dart';
import '../support/goal_fixtures.dart';

/// The design's battle: a squat, 18 counted, 3 shallow late.
final _report = coachReport(
  valid: designPace(),
  rejected: const [
    (19.4, RejectReason.shallowSquat),
    (24.2, RejectReason.shallowSquat),
    (28.8, RejectReason.shallowSquat),
  ],
);

final _setAt = DateTime(2026, 11, 17, 14, 35);

/// Goal writes and clears, and failures on request.
class _Store extends MemoryGoalStore {
  Exception? error;
  final cleared = <(int, ExerciseType)>[];

  @override
  Future<void> write(int accountId, FeedbackGoal goal) async {
    if (error case final e?) throw e;
    return super.write(accountId, goal);
  }

  @override
  Future<void> clear(int accountId, ExerciseType exercise) async {
    cleared.add((accountId, exercise));
    if (error case final e?) throw e;
    return super.clear(accountId, exercise);
  }
}

CoachViewModel _viewModel({
  FormReport? report,
  FakeStatsUserRepository? repository,
  GoalStore? store,
  int? accountId = 7,
  int? matchId,
  String characterId = 'seal',
}) => CoachViewModel(
  report: report ?? _report,
  characterId: characterId,
  summary: '스쿼트 · RepBot 중수 · 승리',
  history: repository?.stats,
  repository: repository,
  goalStore: store,
  accountId: accountId,
  matchId: matchId,
  now: () => _setAt,
);

/// A ready talk, opened at its first line with every letter typed out on
/// each page ([CoachViewModel.setInstant]).
Future<CoachViewModel> _ready({
  GoalStore? store,
  int? accountId = 7,
  bool instant = true,
}) async {
  final viewModel = _viewModel(store: store, accountId: accountId);
  await viewModel.load();
  viewModel
    ..setInstant(instant)
    ..start();
  return viewModel;
}

void main() {
  group('loading the earlier battles (task.md W10 decision 1)', () {
    test('before loading: no script, no line count, nothing to say', () {
      final viewModel = _viewModel();
      expect(viewModel.state.phase, CoachPhase.loading);
      expect(viewModel.lineCount, isNull);
      expect(viewModel.state.line, isNull);
      expect(viewModel.state.shownPieces, isEmpty);
      expect(viewModel.state.fullyShown, isTrue);
      // Nothing happens before the talk is built.
      viewModel
        ..tick()
        ..tap()
        ..skip()
        ..start();
      expect(viewModel.state.phase, CoachPhase.loading);
    });

    test('the newest five of the same exercise, ended before this one, '
        'oldest first; a form report only for those with feedback', () async {
      final repository = FakeStatsUserRepository();
      final end = _report.endedAt;
      repository.stats.points = [
        for (var i = 1; i <= 7; i++)
          statsPoint(
            i,
            end.subtract(Duration(days: 8 - i)),
            reps: 10 + i,
            exercise: ExerciseType.squat,
            hasFeedback: i.isEven,
          ),
        // Another exercise, and this battle itself on the server already.
        statsPoint(20, end.subtract(const Duration(days: 1)), reps: 99),
        statsPoint(
          21,
          end.subtract(const Duration(seconds: 2)),
          reps: 99,
          exercise: ExerciseType.squat,
        ),
      ];
      repository.reports = {
        for (final id in const [4, 6]) id: coachReport(valid: evenly(10)),
      };
      final viewModel = _viewModel(repository: repository);
      await viewModel.load();
      expect(repository.stats.calls.single.exercise, ExerciseType.squat);
      expect(repository.feedbackRequests..sort(), [4, 6]);
      final facts = viewModel.state.script!.facts;
      expect(facts.earlierReps, [13, 14, 15, 16, 17]);
      expect(facts.average, 15);
      expect(facts.usualRates, isNotNull);
      expect(facts.earlierBestCombo, 1);
    });

    test('a past battle leaves out its own record by id and the battles '
        'after it', () async {
      final repository = FakeStatsUserRepository();
      repository.stats.points = [
        statsPoint(
          3,
          _report.endedAt.subtract(const Duration(days: 1)),
          reps: 12,
          exercise: ExerciseType.squat,
        ),
        statsPoint(
          9,
          _report.endedAt.subtract(const Duration(seconds: 1)),
          reps: 18,
          exercise: ExerciseType.squat,
        ),
        // Played after the past battle opened from 기록보관소.
        statsPoint(
          12,
          _report.endedAt.add(const Duration(days: 2)),
          reps: 25,
          exercise: ExerciseType.squat,
        ),
      ];
      final viewModel = _viewModel(repository: repository, matchId: 9);
      await viewModel.load();
      expect(viewModel.state.script!.facts.earlierReps, [12]);
    });

    test(
      'a failed list is a first battle; a failed report keeps the reps',
      (() async {
        final failing = FakeStatsUserRepository();
        failing.stats.error = Exception('offline');
        final first = _viewModel(repository: failing);
        await first.load();
        expect(first.state.phase, CoachPhase.ready);
        expect(first.state.script!.facts.earlierReps, isEmpty);

        final halfway = FakeStatsUserRepository()
          ..feedbackError = Exception('offline');
        halfway.stats.points = [
          statsPoint(
            1,
            _report.endedAt.subtract(const Duration(days: 1)),
            reps: 14,
            exercise: ExerciseType.squat,
            hasFeedback: true,
          ),
        ];
        final second = _viewModel(repository: halfway);
        await second.load();
        expect(second.state.script!.facts.earlierReps, [14]);
        expect(second.state.script!.facts.usualRates, isNull);
      }),
    );

    test('a battle whose report is gone counts its reps only', () async {
      final repository = FakeStatsUserRepository();
      repository.stats.points = [
        statsPoint(
          1,
          _report.endedAt.subtract(const Duration(days: 1)),
          reps: 14,
          exercise: ExerciseType.squat,
          hasFeedback: true,
        ),
      ];
      final viewModel = _viewModel(repository: repository);
      await viewModel.load();
      expect(viewModel.state.script!.facts.earlierReps, [14]);
      expect(viewModel.state.script!.facts.earlierBestCombo, isNull);
    });

    test('no history source: built at once as a first battle; the count '
        'is the talk\'s lines', () async {
      final viewModel = _viewModel();
      var told = 0;
      viewModel.addListener(() => told++);
      await viewModel.load();
      expect(viewModel.state.phase, CoachPhase.ready);
      expect(viewModel.lineCount, viewModel.state.script!.talk.length);
      expect(viewModel.lineCount, 4);
      expect(told, 1);
      // Loading again does nothing.
      await viewModel.load();
      expect(told, 1);
    });

    test(
      'a second load while one runs does nothing; disposing ends it',
      () async {
        final repository = FakeStatsUserRepository();
        repository.stats.gate = Completer<void>();
        final viewModel = _viewModel(repository: repository);
        final first = viewModel.load();
        await viewModel.load();
        expect(repository.stats.calls, hasLength(1));
        viewModel.dispose();
        repository.stats.gate!.complete();
        await first;
        expect(viewModel.state.phase, CoachPhase.loading);
      },
    );
  });

  group('the talk (spec 3)', () {
    test('typing: one letter a tick; a tap shows the rest; the next tap '
        'goes on', () async {
      final viewModel = await _ready(instant: false);
      final first = viewModel.state.line!;
      expect(viewModel.state.revealed, 0);
      viewModel
        ..tick()
        ..tick();
      expect(viewModel.state.revealed, 2);
      expect(viewModel.state.shownPieces.map((p) => p.text).join(), '수고');
      viewModel.tap();
      expect(viewModel.state.fullyShown, isTrue);
      expect(viewModel.state.revealed, first.length);
      // Ticks past the end change nothing.
      viewModel.tick();
      expect(viewModel.state.revealed, first.length);
      viewModel.tap();
      expect(viewModel.state.index, 1);
      expect(viewModel.state.revealed, 0);
    });

    test('the shown pieces keep their marks and cut inside one', () async {
      final viewModel = await _ready(instant: false);
      // "수고했다범! 이번 스쿼트에서 " is 16 letters; then "18번" is marked.
      for (var i = 0; i < 17; i++) {
        viewModel.tick();
      }
      final shown = viewModel.state.shownPieces;
      expect(shown.last, const CoachPiece('1', marked: true));
    });

    test('the question waits for a choice: a tap does not go on', () async {
      final viewModel = await _ready();
      final question = viewModel.state.questionIndex;
      for (var i = 0; i < question; i++) {
        viewModel.tap();
      }
      expect(viewModel.state.onQuestion, isTrue);
      expect(viewModel.state.showsChoices, isTrue);
      viewModel.tap();
      expect(viewModel.state.index, question);
    });

    test('while the question types, its choices wait', () async {
      final viewModel = await _ready(instant: false);
      viewModel.skip();
      expect(viewModel.state.onQuestion, isTrue);
      expect(viewModel.state.showsChoices, isFalse);
      await viewModel.choose(null);
      expect(viewModel.state.answered, isFalse);
    });

    test('건너뛰기 goes to the question, and from there to the end', () async {
      final viewModel = await _ready();
      viewModel.skip();
      expect(viewModel.state.index, viewModel.state.questionIndex);
      viewModel.skip();
      expect(viewModel.state.ended, isTrue);
      expect(viewModel.state.line!.text, startsWith('오늘 이야기는 여기까지!'));
      // The end stays.
      viewModel
        ..skip()
        ..tap();
      expect(viewModel.state.ended, isTrue);
    });

    test('start at the goal ("건너뛰기" on the report) and restart', () async {
      final viewModel = await _ready();
      viewModel.start(atGoal: true);
      expect(viewModel.state.onQuestion, isTrue);
      await viewModel.choose(null);
      viewModel.restart();
      expect(viewModel.state.index, 0);
      expect(viewModel.state.answered, isFalse);
      expect(viewModel.state.ended, isFalse);
    });

    test('the dots count the talk, the question and the answer', () async {
      final viewModel = await _ready();
      expect(viewModel.state.pageCount, viewModel.lineCount! + 2);
    });

    test('reduced motion: every page shows whole, the end too', () async {
      final viewModel = await _ready(instant: false);
      viewModel.setInstant(true);
      expect(viewModel.state.fullyShown, isTrue);
      viewModel.tap();
      expect(viewModel.state.fullyShown, isTrue);
      viewModel
        ..skip()
        ..skip();
      expect(viewModel.state.ended, isTrue);
      expect(viewModel.state.fullyShown, isTrue);
    });

    test('without reduced motion the end types too', () async {
      final viewModel = await _ready(instant: false);
      viewModel
        ..skip()
        ..skip();
      expect(viewModel.state.revealed, 0);
    });
  });

  group('picking the goal (spec 5.2)', () {
    test('a goal is saved over the exercise\'s goal with the character, '
        'and its answer shows; a tap then ends the talk', () async {
      final store = _Store();
      final viewModel = await _ready(store: store);
      viewModel.skip();
      final goal = viewModel.state.script!.suggestions.first;
      await viewModel.choose(goal);
      expect(viewModel.state.choice, same(goal));
      expect(viewModel.state.line!.graphic, isA<CoachGoalGraphic>());
      expect(
        store.goals[(7, ExerciseType.squat)],
        FeedbackGoal(
          exercise: ExerciseType.squat,
          kind: GoalKind.reps,
          target: 20,
          baseline: 18,
          title: '스쿼트 20회 인정받기',
          setAt: _setAt,
          characterId: 'seal',
          fromMatch: _report.id,
        ),
      );
      // Once only.
      await viewModel.choose(viewModel.state.script!.suggestions.last);
      expect(store.goals[(7, ExerciseType.squat)]!.kind, GoalKind.reps);
      viewModel.tap();
      expect(viewModel.state.ended, isTrue);
    });

    test('사양할래 removes the exercise\'s goal', () async {
      final store = _Store();
      await store.write(
        7,
        FeedbackGoal(
          exercise: ExerciseType.squat,
          kind: GoalKind.combo,
          target: 5,
          baseline: 4,
          title: '콤보 5번 이상',
          setAt: _setAt,
          characterId: 'bear',
          fromMatch: '1',
        ),
      );
      final viewModel = await _ready(store: store);
      viewModel.skip();
      await viewModel.choose(null);
      expect(store.cleared, [(7, ExerciseType.squat)]);
      expect(store.goals, isEmpty);
      expect(viewModel.state.line!.text, startsWith('알겠어.'));
    });

    test('a failed save still answers; nothing is saved without an account '
        'or a store', () async {
      final failing = _Store()..error = Exception('locked');
      final viewModel = await _ready(store: failing);
      viewModel.skip();
      await viewModel.choose(viewModel.state.script!.suggestions.first);
      expect(viewModel.state.answered, isTrue);
      await expectLater(() async {
        final none = await _ready(
          store: failing..error = null,
          accountId: null,
        );
        none.skip();
        await none.choose(none.state.script!.suggestions.first);
      }(), completes);
      expect(failing.goals, isEmpty);
      final noStore = await _ready();
      noStore.skip();
      await noStore.choose(null);
      expect(noStore.state.answered, isTrue);
    });

    test('a 사양 that fails to clear still answers', () async {
      final failing = _Store()..error = Exception('locked');
      final viewModel = await _ready(store: failing);
      viewModel.skip();
      await viewModel.choose(null);
      expect(viewModel.state.line!.text, startsWith('알겠어.'));
    });

    test(
      'the voice is the character\'s; an unknown one talks as the mouse',
      () {
        expect(_viewModel(characterId: 'penguin').voice.name, '펭뚱이');
        expect(_viewModel(characterId: 'bot').voice.characterId, 'mouse');
      },
    );

    test('after dispose nothing is told', () async {
      final viewModel = await _ready(instant: false);
      var told = 0;
      viewModel
        ..addListener(() => told++)
        ..dispose();
      viewModel.tick();
      expect(told, 0);
    });
  });
}
