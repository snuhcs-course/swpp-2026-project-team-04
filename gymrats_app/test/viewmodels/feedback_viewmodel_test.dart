// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/feedback/form_analyzer.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/viewmodels/feedback_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';

import '../support/fakes.dart';
import '../support/form_report_fixtures.dart';

final _endedAt = DateTime.utc(2026, 10, 21, 3, 0, 5, 250);

MatchRecord _match({int? id = 7, DateTime? playedAt}) => MatchRecord(
  id: id,
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: 3,
  opponentReps: 1,
  playedAt: playedAt ?? _endedAt.toLocal(),
);

/// A phone store whose reads fail.
class _BrokenStore implements FormReportStore {
  @override
  Future<List<FormReport>> list() => Future.error(Exception('disk'));

  @override
  Future<FormReport?> latest() => Future.error(Exception('disk'));

  @override
  Future<void> save(FormReport report) async {}
}

void main() {
  late FakeUserRepository repository;
  late InMemoryFormReportStore phone;

  setUp(() {
    repository = FakeUserRepository();
    phone = InMemoryFormReportStore();
  });

  FeedbackViewModel vm(MatchRecord match, {FormReportStore? store}) =>
      FeedbackViewModel(
        match: match,
        repository: repository,
        phoneReports: store ?? phone,
      );

  test('starts loading', () {
    expect(vm(_match()).state.phase, FeedbackPhase.loading);
  });

  test("loads the battle's report from the server", () async {
    final report = sampleReport(endedAt: _endedAt);
    repository.reports = {7: report};
    final model = vm(_match());
    await model.load();
    expect(repository.feedbackRequests, [7]);
    expect(model.state.phase, FeedbackPhase.ready);
    expect(model.state.report, same(report));
    expect(model.state.fromPhone, isFalse);
  });

  test('a battle without a stored report is missing', () async {
    final model = vm(_match());
    await model.load();
    expect(model.state.phase, FeedbackPhase.missing);
  });

  test('a battle with no server id is missing without a request', () async {
    final model = vm(_match(id: null));
    await model.load();
    expect(model.state.phase, FeedbackPhase.missing);
    expect(repository.feedbackRequests, isEmpty);
  });

  test("offline, the phone's copy of the same battle is shown", () async {
    final copy = sampleReport(endedAt: _endedAt);
    await phone.save(sampleReport(endedAt: DateTime.utc(2026, 10, 20)));
    await phone.save(copy);
    repository.feedbackError = const ApiException(ApiErrorKind.network);
    final model = vm(_match());
    await model.load();
    expect(model.state.phase, FeedbackPhase.ready);
    expect(model.state.report, same(copy));
    expect(model.state.fromPhone, isTrue);
  });

  test('offline without a phone copy fails with the reason', () async {
    await phone.save(sampleReport(endedAt: DateTime.utc(2026, 10, 20)));
    repository.feedbackError = const ApiException(ApiErrorKind.network);
    final model = vm(_match());
    await model.load();
    expect(model.state.phase, FeedbackPhase.failed);
    expect(
      model.state.errorMessage,
      const ApiException(ApiErrorKind.network).message,
    );
  });

  test('another failure, or an unreadable phone store, fails too', () async {
    repository.feedbackError = Exception('boom');
    final model = vm(_match(), store: _BrokenStore());
    await model.load();
    expect(model.state.phase, FeedbackPhase.failed);
    expect(model.state.errorMessage, genericErrorMessage);
  });

  test('a battle without a time has no phone copy to look for', () async {
    repository.feedbackError = Exception('boom');
    final model = FeedbackViewModel(
      match: const MatchRecord(
        id: 7,
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot',
        myReps: 1,
        opponentReps: 0,
      ),
      repository: repository,
    );
    await model.load();
    expect(model.state.phase, FeedbackPhase.failed);
  });

  test('retry after a failure loads again', () async {
    repository.feedbackError = Exception('boom');
    final model = vm(_match());
    await model.load();
    repository
      ..feedbackError = null
      ..reports = {7: sampleReport()};
    await model.load();
    expect(model.state.phase, FeedbackPhase.ready);
  });

  test('load while loading fetches only once', () async {
    repository.feedbackGate = Completer();
    final model = vm(_match());
    final first = model.load();
    final second = model.load();
    repository.feedbackGate!.complete();
    await Future.wait([first, second]);
    expect(repository.feedbackRequests, [7]);
  });

  test('a report arriving after dispose is dropped', () async {
    repository
      ..feedbackGate = Completer()
      ..reports = {7: sampleReport()};
    final model = vm(_match());
    final loading = model.load();
    model.dispose();
    repository.feedbackGate!.complete();
    await loading;
    expect(model.state.phase, FeedbackPhase.loading);
    await model.load();
    expect(repository.feedbackRequests, [7]);
  });

  group('feedback values the screen shows', () {
    test('a report loaded from the server comes with its feedback', () async {
      repository.reports = {7: sampleReport(valid: 3, rejected: 1)};
      final model = vm(_match());
      await model.load();
      final form = model.state.form!;
      expect(form.findings.first.title, '깊이 부족 1회');
      expect(form.meanDepth, 1.5);
    });

    test('the phone copy comes with its feedback too', () async {
      repository.feedbackError = Exception('offline');
      await phone.save(sampleReport(endedAt: _endedAt));
      final model = vm(_match());
      await model.load();
      expect(model.state.fromPhone, isTrue);
      expect(model.state.form, isNotNull);
    });

    test('a report in hand is ready at once and never loads', () async {
      final report = squatReport();
      final model = FeedbackViewModel.fromReport(report);
      expect(model.state.phase, FeedbackPhase.ready);
      expect(model.state.report, same(report));
      expect(model.match, isNull);
      await model.load();
      expect(model.state.phase, FeedbackPhase.ready);
      expect(repository.feedbackRequests, isEmpty);
    });

    test(
      'UAT-4 squat run: 4 counted, 2 rejected, the issue, a row per rep',
      () {
        final state = FeedbackViewModel.fromReport(squatReport()).state;
        expect(state.report!.validReps, 4);
        expect(state.report!.invalidReps, 2);
        expect(state.report!.reps, hasLength(6));
        final issue = state.form!.findings.first;
        expect(issue.title, '얕은 스쿼트 2회');
        expect(issue.fix, isNotNull);
        expect(state.form!.meanDepth, 0.9);
        expect(state.form!.armBalance, ArmBalance.unknown);
        expect(state.form!.depthTrend, DepthTrend.kept);
      },
    );

    test('mean depth is over counted reps only, null without one', () {
      expect(
        FormFeedback.of(sampleReport(valid: 0, rejected: 2)).meanDepth,
        isNull,
      );
      final report = FormReport(
        endedAt: _endedAt,
        opponentName: 'RepBot',
        roundLength: const Duration(seconds: 30),
        reps: const [
          RepRecord(index: 1, valid: true, at: Duration.zero, maxDepth: 1),
          RepRecord(index: 2, valid: true, at: Duration.zero, maxDepth: 2),
          RepRecord(index: 3, valid: true, at: Duration.zero),
          RepRecord(index: 4, valid: false, at: Duration.zero, maxDepth: 9),
        ],
        samples: const [],
      );
      expect(FormFeedback.of(report).meanDepth, 1.5);
    });

    test('pace: counted reps per 5 s slice of a 30 s round', () {
      final form = FormFeedback.of(sampleReport(valid: 4, rejected: 2));
      // Reps close at 0, 2, 4, 6 s (counted) and 8, 10 s (rejected).
      expect(form.sliceSeconds, 5);
      expect(form.paceBuckets, [3, 1, 0, 0, 0, 0]);
      expect(form.repsPerSecond, closeTo(4 / 30, 1e-9));
    });

    test('a KO round is cut into six shorter slices', () {
      final report = FormReport(
        endedAt: _endedAt,
        opponentName: 'RepBot',
        roundLength: const Duration(seconds: 12),
        reps: const [
          RepRecord(index: 1, valid: true, at: Duration(seconds: 1)),
          RepRecord(index: 2, valid: true, at: Duration(seconds: 11)),
          RepRecord(index: 3, valid: true, at: Duration(seconds: 13)),
        ],
        samples: const [],
      );
      final form = FormFeedback.of(report);
      expect(form.sliceSeconds, 2);
      // The rep at 13 s closed after the 12 s round: still in the last slice.
      expect(form.paceBuckets, [1, 0, 0, 0, 0, 2]);
      expect(form.paceBuckets.length, 6);
    });

    test('a rep closing exactly at the end is in the last slice', () {
      final form = FormFeedback.of(
        FormReport(
          endedAt: _endedAt,
          opponentName: 'RepBot',
          roundLength: const Duration(seconds: 30),
          reps: const [
            RepRecord(index: 1, valid: true, at: Duration(seconds: 29)),
            RepRecord(index: 2, valid: true, at: Duration(seconds: 30)),
            RepRecord(index: 3, valid: false, at: Duration(seconds: 30)),
          ],
          samples: const [],
        ),
      );
      expect(form.paceBuckets, [0, 0, 0, 0, 0, 2]);
      expect(form.paceBuckets.reduce((a, b) => a + b), 2);
    });

    test('a round without length keeps 5 s slices and no rate', () {
      final report = FormReport(
        endedAt: _endedAt,
        opponentName: 'RepBot',
        roundLength: Duration.zero,
        reps: const [RepRecord(index: 1, valid: true, at: Duration.zero)],
        samples: const [],
      );
      final form = FormFeedback.of(report);
      expect(form.sliceSeconds, 5);
      expect(form.repsPerSecond, 0);
      expect(form.paceBuckets.first, 1);
    });

    test('the verdicts use the analyzer the view model was given', () {
      const strict = FormAnalyzer(rules: FormRules(minRepsForTrend: 2));
      final model = FeedbackViewModel.fromReport(
        sampleReport(valid: 2),
        analyzer: strict,
      );
      expect(model.state.form!.depthTrend, DepthTrend.kept);
      expect(
        FeedbackViewModel.fromReport(sampleReport(valid: 2))
            .state
            .form!
            .depthTrend,
        DepthTrend.tooFew,
      );
    });
  });
}
